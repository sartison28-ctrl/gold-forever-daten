#!/usr/bin/env python3
"""Gold Forever – stündliche Auktionshaus-Sammlung (Blizzard Game Data API, WoW: Forever).

Ablauf: OAuth-Token holen -> Ruleset + Häuser finden -> Auktionen je Haus holen ->
je Item kompakt zusammenfassen -> Verkäufe aus dem Vergleich zur Vorstunde schätzen.

Nur Python-Standardbibliothek. Zugangsdaten kommen aus den Umgebungsvariablen
BLIZZARD_CLIENT_ID / BLIZZARD_CLIENT_SECRET (GitHub-Secrets).

Ausgaben (siehe README.md):
  daten/haeuser.json                 Ruleset- und Haus-Übersicht (Entdeckung)
  daten/status.json                  letzter Lauf je Haus
  daten/<haus>/aktuell.csv           neueste Stunde
  daten/<haus>/<JJJJ-MM-TT>.csv      alle Stunden eines Tages (UTC)
  zustand/<haus>.json.gz             Auktionsliste der Vorstunde (nicht im Git, Actions-Cache)
"""
import base64
import csv
import datetime as dt
import gzip
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

BASIS = os.path.dirname(os.path.abspath(__file__))
KONFIG = json.load(open(os.path.join(BASIS, "konfig.json"), encoding="utf-8"))
DATEN = os.path.join(BASIS, "daten")
ZUSTAND = os.path.join(BASIS, "zustand")

REGION = KONFIG.get("region", "eu")
NAMESPACE = KONFIG.get("namespace", f"dynamic-forever-{REGION}")
API = f"https://{REGION}.api.blizzard.com"

SPALTEN = [
    "zeit_utc", "item_id", "stueck", "auktionen", "stueck_ohne_sofortkauf",
    "min", "p10", "p25", "median", "stueck_bis_5pct",
    "weg_lang", "weg_mittel", "weg_kurz", "teilverkauf", "verkauf_schaetzung", "neu_stueck",
    "umgestellt",
]
GESPEICHERT_TIME_LEFT = {"SHORT": "S", "MEDIUM": "M", "LONG": "L", "VERY_LONG": "V"}


def log(*a):
    print(*a, flush=True)


# ---------------------------------------------------------------- HTTP

def http(url, daten=None, kopf=None, versuche=4):
    kopf = dict(kopf or {})
    kopf.setdefault("Accept-Encoding", "gzip")
    kopf.setdefault("User-Agent", "gold-forever-daten/1.0")
    for n in range(versuche):
        try:
            req = urllib.request.Request(url, data=daten, headers=kopf)
            with urllib.request.urlopen(req, timeout=120) as r:
                roh = r.read()
                if r.headers.get("Content-Encoding") == "gzip":
                    roh = gzip.decompress(roh)
                return r.status, dict(r.headers), roh
        except urllib.error.HTTPError as e:
            if e.code in (429, 500, 502, 503, 504) and n < versuche - 1:
                time.sleep(5 * (n + 1))
                continue
            return e.code, dict(e.headers or {}), e.read() or b""
        except (urllib.error.URLError, TimeoutError) as e:
            if n < versuche - 1:
                time.sleep(5 * (n + 1))
                continue
            raise RuntimeError(f"Netzwerkfehler {url}: {e}")


def token_holen():
    cid = os.environ.get("BLIZZARD_CLIENT_ID", "").strip()
    sec = os.environ.get("BLIZZARD_CLIENT_SECRET", "").strip()
    if not cid or not sec:
        sys.exit("FEHLER: BLIZZARD_CLIENT_ID / BLIZZARD_CLIENT_SECRET fehlen (Repo-Secrets prüfen).")
    auth = base64.b64encode(f"{cid}:{sec}".encode()).decode()
    status, _, roh = http(
        "https://oauth.battle.net/token",
        daten=b"grant_type=client_credentials",
        kopf={"Authorization": f"Basic {auth}", "Content-Type": "application/x-www-form-urlencoded"},
    )
    if status != 200:
        sys.exit(f"FEHLER: Token-Abruf HTTP {status}: {roh[:300]!r} (Client-ID/Secret prüfen)")
    return json.loads(roh)["access_token"]


class Api:
    def __init__(self, token):
        self.token = token

    def get(self, pfad, namespace=NAMESPACE, erlaubt_404=False):
        q = urllib.parse.urlencode({"namespace": namespace, "locale": KONFIG.get("locale", "de_DE")})
        url = f"{API}{pfad}?{q}"
        status, kopf, roh = http(url, kopf={"Authorization": f"Bearer {self.token}"})
        if status == 404 and erlaubt_404:
            return None, kopf
        if status != 200:
            raise RuntimeError(f"HTTP {status} für {pfad}: {roh[:200]!r}")
        return json.loads(roh), kopf


def name_text(n):
    if isinstance(n, dict):
        return n.get("de_DE") or n.get("en_GB") or n.get("en_US") or next(iter(n.values()), "")
    return n or ""


# ---------------------------------------------------------------- Entdeckung

def ruleset_waehlen(api):
    idx, _ = api.get("/data/wow/ruleset/index")
    rulesets = []
    for r in idx.get("rulesets", idx.get("ruleset", [])) or []:
        rulesets.append({"id": r.get("id"), "name": name_text(r.get("name"))})
    gewuenscht = KONFIG.get("ruleset", "auto")
    if gewuenscht != "auto":
        return int(gewuenscht), rulesets
    for r in rulesets:  # PvP, aber nicht Rollenspiel-PvP
        n = r["name"].lower()
        if "pvp" in n.replace(" ", "") and "rolle" not in n and "role" not in n:
            return r["id"], rulesets
    return 1, rulesets


def haeuser_waehlen(api, ruleset):
    idx, _ = api.get(f"/data/wow/ruleset/{ruleset}/auctions/")  # Schrägstrich ist Pflicht
    alle = [{"id": h.get("id"), "name": name_text(h.get("name")), "key": h.get("key")}
            for h in idx.get("auctions", [])]
    wahl = KONFIG.get("haeuser", "Horde")
    if isinstance(wahl, list):
        gewaehlt = [h for h in alle if h["id"] in wahl]
    else:
        gewaehlt = [h for h in alle if wahl.lower() in h["name"].lower()]
    return alle, gewaehlt


# ---------------------------------------------------------------- Abruf

def auktionen_holen(api, ruleset, haus_id):
    """Liefert (liste, last_modified). Eintrag: (id, item, menge, stueckpreis|None, time_left)."""
    daten, kopf = api.get(f"/data/wow/ruleset/{ruleset}/auctions/{haus_id}")
    lm = kopf.get("Last-Modified") or kopf.get("last-modified") or ""
    liste = []
    for a in daten.get("auctions") or []:
        menge = int(a.get("quantity") or 1)
        if a.get("unit_price") is not None:
            preis = int(a["unit_price"])
        elif a.get("buyout"):
            preis = int(a["buyout"]) // max(menge, 1)
        else:
            preis = None  # nur Gebot
        liste.append((a["id"], a["item"]["id"], menge, preis, a.get("time_left", "")))
    com = daten.get("commodities")
    if isinstance(com, list):
        com_liste = com
    elif com:  # Verweis -> eigener Abruf
        cd, _ = api.get(f"/data/wow/ruleset/{ruleset}/auctions/{haus_id}/commodities", erlaubt_404=True)
        com_liste = (cd or {}).get("auctions") or []
    else:
        com_liste = []
    for a in com_liste:
        liste.append((a["id"], a["item"]["id"], int(a.get("quantity") or 1),
                      int(a["unit_price"]), a.get("time_left", "")))
    return liste, lm


# ---------------------------------------------------------------- Auswertung

def gewichtetes_perzentil(paare, p):
    """paare: sortierte Liste (preis, menge). Mengengewichtet."""
    gesamt = sum(m for _, m in paare)
    ziel = gesamt * p
    lauf = 0
    for preis, m in paare:
        lauf += m
        if lauf >= ziel:
            return preis
    return paare[-1][0]


def zusammenfassen(liste, vorher, zeit, luecke):
    items = {}
    for aid, item, menge, preis, _ in liste:
        e = items.setdefault(item, {"stueck": 0, "auktionen": 0, "ohne": 0, "preise": []})
        e["stueck"] += menge
        e["auktionen"] += 1
        if preis is None:
            e["ohne"] += menge
        else:
            e["preise"].append((preis, menge))

    # Verkaufsschätzung aus dem Vergleich mit der Vorstunde
    # Zurückgezogen + neu eingestellt (Unterbieten) darf nicht als Verkauf zählen:
    # Verschwundene Auktion und neue Auktion desselben Items mit gleicher Stückzahl
    # gelten als Paar "umgestellt" (zuerst gegen LONG, dann MEDIUM, dann SHORT).
    weg = {}
    neu = {}
    if vorher is not None and not luecke:
        jetzt_ids = {a[0]: a for a in liste}
        verschwunden = {}  # item -> {menge: {"L": n, "M": n, "S": n}}
        for aid, (item, menge, tl) in vorher.items():
            akt = jetzt_ids.get(aid)
            w = weg.setdefault(item, {"L": 0, "M": 0, "S": 0, "T": 0, "U": 0})
            if akt is None:
                klasse = "S" if tl == "S" else ("M" if tl == "M" else "L")
                w[klasse] += menge
                k = verschwunden.setdefault(item, {}).setdefault(menge, {"L": 0, "M": 0, "S": 0})
                k[klasse] += 1
            elif akt[2] < menge:  # Teilverkauf (Rohstoffe)
                w["T"] += menge - akt[2]
        for aid, item, menge, _, _ in liste:
            if aid not in vorher:
                neu[item] = neu.get(item, 0) + menge
                k = verschwunden.get(item, {}).get(menge)
                if k:
                    for klasse in ("L", "M", "S"):
                        if k[klasse]:
                            k[klasse] -= 1
                            w = weg[item]
                            w[klasse] -= menge
                            w["U"] += menge
                            break

    zeilen = []
    for item in sorted(set(items) | set(weg)):
        e = items.get(item, {"stueck": 0, "auktionen": 0, "ohne": 0, "preise": []})
        p = sorted(e["preise"])
        w = weg.get(item, {"L": 0, "M": 0, "S": 0, "T": 0, "U": 0})
        schaetz = w["L"] + w["T"] + w["M"] // 2 if (vorher is not None and not luecke) else ""
        if p:
            mn = p[0][0]
            bis5 = sum(m for pr, m in p if pr <= mn * 1.05)
            werte = [mn, gewichtetes_perzentil(p, .10), gewichtetes_perzentil(p, .25),
                     gewichtetes_perzentil(p, .50), bis5]
        else:
            werte = ["", "", "", "", 0]
        hat_vergleich = vorher is not None and not luecke
        zeilen.append([zeit, item, e["stueck"], e["auktionen"], e["ohne"], *werte,
                       w["L"] if hat_vergleich else "", w["M"] if hat_vergleich else "",
                       w["S"] if hat_vergleich else "", w["T"] if hat_vergleich else "",
                       schaetz, neu.get(item, 0) if hat_vergleich else "",
                       w["U"] if hat_vergleich else ""])
    return zeilen


# ---------------------------------------------------------------- Zustand / Dateien

def zustand_laden(haus_id):
    pfad = os.path.join(ZUSTAND, f"{haus_id}.json.gz")
    if not os.path.exists(pfad):
        return None
    with gzip.open(pfad, "rt", encoding="utf-8") as f:
        z = json.load(f)
    z["auktionen"] = {int(k): tuple(v) for k, v in z["auktionen"].items()}
    return z


def zustand_speichern(haus_id, liste, zeit, lm):
    os.makedirs(ZUSTAND, exist_ok=True)
    z = {"zeit": zeit, "last_modified": lm,
         "auktionen": {str(a[0]): [a[1], a[2], GESPEICHERT_TIME_LEFT.get(a[4], "?")] for a in liste}}
    with gzip.open(os.path.join(ZUSTAND, f"{haus_id}.json.gz"), "wt", encoding="utf-8") as f:
        json.dump(z, f, separators=(",", ":"))


def csv_schreiben(haus_id, zeilen, tag):
    ordner = os.path.join(DATEN, str(haus_id))
    os.makedirs(ordner, exist_ok=True)
    tagdatei = os.path.join(ordner, f"{tag}.csv")
    neu = not os.path.exists(tagdatei)
    if not neu:  # Spalten geändert -> bestehende Zeilen auffüllen
        with open(tagdatei, newline="", encoding="utf-8") as f:
            alt = list(csv.reader(f))
        if alt and alt[0] != SPALTEN:
            with open(tagdatei, "w", newline="", encoding="utf-8") as f:
                w = csv.writer(f)
                w.writerow(SPALTEN)
                w.writerows(z + [""] * (len(SPALTEN) - len(z)) for z in alt[1:])
    with open(tagdatei, "a", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        if neu:
            w.writerow(SPALTEN)
        w.writerows(zeilen)
    with open(os.path.join(ordner, "aktuell.csv"), "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(SPALTEN)
        w.writerows(zeilen)


def json_schreiben(pfad, obj):
    os.makedirs(os.path.dirname(pfad), exist_ok=True)
    with open(pfad, "w", encoding="utf-8") as f:
        json.dump(obj, f, ensure_ascii=False, indent=1)


# ---------------------------------------------------------------- Hauptablauf

def main():
    jetzt = dt.datetime.now(dt.timezone.utc).replace(second=0, microsecond=0)
    zeit = jetzt.strftime("%Y-%m-%dT%H:%MZ")
    tag = jetzt.strftime("%Y-%m-%d")
    api = Api(token_holen())

    ruleset, rulesets = ruleset_waehlen(api)
    alle, gewaehlt = haeuser_waehlen(api, ruleset)
    log(f"Ruleset {ruleset}; {len(alle)} Häuser, gewählt: {[h['id'] for h in gewaehlt]}")
    if not gewaehlt:
        sys.exit("FEHLER: kein Haus passt zu konfig.json 'haeuser'.")

    statuspfad = os.path.join(DATEN, "status.json")
    status = json.load(open(statuspfad, encoding="utf-8")) if os.path.exists(statuspfad) else {}
    status["letzter_lauf"] = zeit
    status["ruleset"] = ruleset
    status.setdefault("haeuser", {})
    uebersicht = {"stand": zeit, "namespace": NAMESPACE, "rulesets": rulesets,
                  "ruleset_gewaehlt": ruleset, "haeuser": []}
    fehler = 0

    for h in gewaehlt:
        hid = h["id"]
        try:
            liste, lm = auktionen_holen(api, ruleset, hid)
        except Exception as e:  # ein Haus darf die anderen nicht blockieren
            fehler += 1
            log(f"Haus {hid}: FEHLER {e}")
            status["haeuser"][str(hid)] = {**status["haeuser"].get(str(hid), {}), "fehler": str(e)[:200], "zeit": zeit}
            continue
        vorher = zustand_laden(hid)
        if vorher and lm and vorher.get("last_modified") == lm:
            log(f"Haus {hid}: Daten unverändert seit {lm} – übersprungen")
            status["haeuser"].setdefault(str(hid), {}).update({"zeit": zeit, "hinweis": "unverändert"})
            continue
        luecke = True
        if vorher:
            alt = dt.datetime.strptime(vorher["zeit"], "%Y-%m-%dT%H:%MZ").replace(tzinfo=dt.timezone.utc)
            luecke = (jetzt - alt) > dt.timedelta(minutes=KONFIG.get("max_abstand_min", 100))
        zeilen = zusammenfassen(liste, vorher["auktionen"] if vorher else None, zeit, luecke)
        csv_schreiben(hid, zeilen, tag)
        zustand_speichern(hid, liste, zeit, lm)
        stueck = sum(a[2] for a in liste)
        verkauft = sum(z[14] for z in zeilen if z[14] != "")
        status["haeuser"][str(hid)] = {"name": h["name"], "zeit": zeit, "last_modified": lm,
                                      "auktionen": len(liste), "stueck": stueck,
                                      "items": len(zeilen), "verkauf_schaetzung": verkauft if not luecke else None}
        uebersicht["haeuser"].append({**h, "auktionen": len(liste), "items": len(zeilen), "stueck": stueck})
        log(f"Haus {hid} ({h['name']}): {len(liste)} Auktionen, {len(zeilen)} Items, "
            f"Verkauf geschätzt {verkauft if not luecke else '– (erste Stunde/Lücke)'}")

    uebersicht["alle_haeuser"] = alle
    json_schreiben(os.path.join(DATEN, "haeuser.json"), uebersicht)
    json_schreiben(statuspfad, status)
    if fehler == len(gewaehlt):
        sys.exit("FEHLER: kein Haus abrufbar.")


if __name__ == "__main__":
    main()
