"""Wächter-Vorarbeit (stündlich auf GitHub, ohne Tokens) – Wunsch Alex 27.11.:
„der Wächter soll unser Gehirn sein … aus den letzten 24 Std. lernen … mir Items zum Scannen vorschlagen“.

Rechnet aus den stündlichen AH-Daten je Item:
  verpasst – Kauf-Tiefs und Verkaufs-Hochs der letzten 24 Std. (auch wenn Alex offline war)
  blick    – Items, die gerade in Bewegung sind (Tief, fällt, steigt, geflutet, leergekauft)
  auftrag  – Items, die Alex im Spiel einmal suchen soll (Tief jetzt oder wiederkehrendes Muster)
Ergebnis landet als GoldForeverData.waechter in der Datendatei (datendatei.py) und als waechter.json.
"""
import csv
import datetime as dt
import glob
import json
import os
from collections import defaultdict
from statistics import median

try:
    from zoneinfo import ZoneInfo
    BERLIN = ZoneInfo("Europe/Berlin")
except Exception:  # pragma: no cover
    BERLIN = dt.timezone(dt.timedelta(hours=1))

# Schwellen (Startwerte; der Cloud-Wächter/die Wochenanalyse können sie über die Lern-Datei regel.waechter anpassen –
# das Addon nutzt dort eigene Werte, dieses Skript bleibt bewusst einfach)
KAUF_TIEF = 0.85      # Preis <= 85 % von üblich = Kauf-Tief
VERK_HOCH = 1.15      # Preis >= 115 % von üblich = Verkaufs-Hoch
MIN_UMSATZ = 20       # Verkäufe/Tag, darunter uninteressant
MIN_GEWINN = 5000     # 50s möglicher Gewinn, sonst nicht melden
FLUT = 2.0            # Stück im AH >= 2x üblich
LEER = 0.35           # Stück im AH <= 35 % von üblich


def regeln_laden(ordner):
    """basis/waechter_regel.json (schreibt die Wochenanalyse) überschreibt die Startwerte."""
    g = globals()
    try:
        r = json.load(open(os.path.join(ordner, "basis", "waechter_regel.json"), encoding="utf-8"))
    except Exception:
        return
    for k, v in r.items():
        if k.isupper() and k in g and isinstance(v, (int, float)):
            g[k] = v


def _z(x):
    try:
        return float(x)
    except (TypeError, ValueError):
        return None


def laden(ordner, ids, tage=15):
    """Je Item [(unix, min, stueck, bis5, verkaufspreis, verkauft)] der letzten <tage> Tage (stündlich)."""
    dateien = sorted(glob.glob(os.path.join(ordner, "20*.csv")))[-tage:]
    r = defaultdict(list)
    jetzt = 0
    for d in dateien:
        with open(d, newline="", encoding="utf-8") as f:
            for z in csv.DictReader(f):
                try:
                    iid = int(z["item_id"])
                except (KeyError, ValueError):
                    continue
                if iid not in ids:
                    continue
                p = _z(z.get("min"))
                if not p or p <= 0:
                    continue
                u = int(dt.datetime.strptime(z["zeit_utc"], "%Y-%m-%dT%H:%MZ").replace(tzinfo=dt.timezone.utc).timestamp())
                r[iid].append((u, int(p), int(_z(z.get("stueck")) or 0), int(_z(z.get("stueck_bis_5pct")) or 0),
                               int(_z(z.get("verkauf_preis_median")) or 0), int(_z(z.get("verkauf_umsatz")) or 0)))
                jetzt = max(jetzt, u)
    for v in r.values():
        v.sort()
    return r, jetzt


def _std(u):
    return dt.datetime.fromtimestamp(u, dt.timezone.utc).astimezone(BERLIN).hour


def rechnen(ordner, ids, kenn, namen=None, stamm=None):
    """kenn = kennzahlen.json['items'] (vt = Verkäufe/Tag, sta = üblicher Bestand)."""
    regeln_laden(ordner)
    namen, stamm = namen or {}, stamm or {}
    # ganzer Markt (für Segmente): alle Items mit genug Umsatz
    ids = set(ids) | {int(k) for k, v in kenn.items() if k.isdigit() and (v.get("vt") or 0) >= MIN_UMSATZ}
    reihen, jetzt = laden(ordner, ids)
    if not jetzt:
        return None
    ab24, ab6 = jetzt - 24 * 3600, jetzt - 6 * 3600
    verpasst, blick, auftrag = [], [], []
    for iid, pkt in reihen.items():
        k = kenn.get(str(iid)) or {}
        vt = k.get("vt") or 0
        if vt < MIN_UMSATZ or len(pkt) < 48:
            continue
        woche = [p for (u, p, *_r) in pkt if u < ab24]
        if len(woche) < 24:
            continue
        R = median(woche)                      # üblich = Median der stündlichen Mindestpreise vor den letzten 24 Std.
        sta = k.get("sta") or median([x[2] for x in pkt]) or 1
        heute = [x for x in pkt if x[0] >= ab24]
        if not heute:
            continue
        menge = max(1, int(vt * 0.1))          # was man realistisch kaufen/verkaufen kann: 10 % vom Tagesumsatz
        # --- verpasst: tiefster Preis (Kauf) und höchster Preis (Verkauf) der letzten 24 Std.
        tief = min(heute, key=lambda x: x[1])
        if tief[1] <= R * KAUF_TIEF:
            n = min(menge, max(tief[3], 1))
            g = int((R * 0.95 - tief[1]) * n)
            if g >= MIN_GEWINN:
                verpasst.append({"id": iid, "art": "kauf", "p": tief[1], "R": int(R), "t": tief[0], "h": _std(tief[0]), "n": n, "gewinn": g})
        # Verkaufs-Hoch nur mit echten Verkäufen (geschätzter Verkaufspreis der Stunde >= 115 % und Stück verkauft)
        hochs = [x for x in heute if x[4] >= R * VERK_HOCH and x[5] > 0]
        if hochs:
            n = min(menge, sum(x[5] for x in hochs))
            vp = int(median([x[4] for x in hochs]))
            g = int((vp * 0.95 - R) * n)
            if g >= MIN_GEWINN:
                bst = max(hochs, key=lambda x: x[5])
                verpasst.append({"id": iid, "art": "verk", "p": vp, "R": int(R), "t": bst[0], "h": _std(bst[0]), "n": n, "gewinn": g})
        # --- im Blick: Zustand jetzt
        u, p, q, b5 = pkt[-1][:4]
        vor6 = [x[1] for x in pkt if ab6 - 3600 <= x[0] <= ab6 + 3600]
        tr6 = (p / median(vor6) - 1) * 100 if vor6 else 0
        art = None
        if q >= sta * FLUT and p < R:
            art, txt = "flut", "Markt geflutet (%.1fx üblich) – nicht kaufen" % (q / sta)
        elif p <= R * KAUF_TIEF:
            art, txt = "tief", "%d %% unter üblich – Kaufchance" % round((1 - p / R) * 100)
        elif q <= sta * LEER and p >= R:
            art, txt = "leer", "fast leergekauft (%d statt %d) – Preis kann steigen" % (q, sta)
        elif tr6 <= -15:
            art, txt = "faellt", "fällt seit 6 Std. (%d %%)" % round(tr6)
        elif tr6 >= 15:
            art, txt = "steigt", "steigt seit 6 Std. (+%d %%)" % round(tr6)
        if art:
            wert = int(abs(R - p) * menge)
            if wert >= MIN_GEWINN or art in ("flut", "leer"):
                blick.append({"id": iid, "art": art, "text": txt, "p": p, "R": int(R), "wert": wert})
        # --- Scan-Auftrag: Tief jetzt, oder Tief kam an >= 3 der letzten 7 Tage zur selben Stunde wieder
        if art == "tief":
            auftrag.append({"id": iid, "text": "jetzt suchen – Kaufchance", "wann": "jetzt", "wert": int((R * 0.95 - p) * menge)})
        else:
            tage = defaultdict(lambda: 10 ** 12)
            for (uu, pp, *_r) in pkt:
                if pp <= R * KAUF_TIEF:
                    tag = dt.datetime.fromtimestamp(uu, dt.timezone.utc).astimezone(BERLIN).strftime("%Y-%m-%d")
                    tage[(tag, _std(uu))] = min(tage[(tag, _std(uu))], pp)
            je_std = defaultdict(set)
            for (tag, h) in tage:
                je_std[h].add(tag)
            if je_std:
                h, tg = max(je_std.items(), key=lambda kv: len(kv[1]))
                if len(tg) >= 3:
                    auftrag.append({"id": iid, "text": "oft billig um %d Uhr (%d von 7 Tagen)" % (h, len(tg)), "wann": "%d Uhr" % h,
                                    "h": h, "wert": int(R * (1 - KAUF_TIEF) * menge)})
    seg, zus = segmente(reihen, jetzt, kenn, namen, stamm)
    verpasst.sort(key=lambda x: -x["gewinn"])
    blick.sort(key=lambda x: -x["wert"])
    auftrag.sort(key=lambda x: -x["wert"])
    # Verkaufs-Hochs: mehr behalten – das Addon filtert auf die eigene Ware
    vk = [x for x in verpasst if x["art"] == "kauf"][:25] + [x for x in verpasst if x["art"] == "verk"][:80]
    return {"stand": jetzt, "verpasst": vk, "segmente": seg, "zusammenhang": zus, "blick": blick[:25], "auftrag": auftrag[:10],
            "regel": {"kaufTief": KAUF_TIEF, "verkHoch": VERK_HOCH, "minUmsatz": MIN_UMSATZ, "flut": FLUT}}


# ---------------------------------------------------------------- Märkte und Zusammenhänge (Wunsch Alex 27.11. 21:27:
# „wo wächst gerade was, in welchem Bereich Kräuter, ob Tränke dadurch steigen – Zusammenhänge erkennen“)
KRAEUTER = ("friedensblume silberblatt erdwurzel maguskönigskraut wilddornrose flitzdistel beulengras wildstahlblume königsblut "
            "lebenswurz golddorn khadgars grabmoos würgetang blassblatt winterbiss feuerblüte sonnengras blindkraut "
            "bergsilberweisling traumblatt gromsblut pestblüte eiskappe lotus sansam geisterpilz arthas").split()
EDEL = "jade citrin aquamarin sternrubin tigerauge schattenedelstein moosachat mondstein smaragd saphir diamant azerothischer opal perle".split()
UNTERKLASSE = {"Kräuter": "Kräuter", "Kraut": "Kräuter", "Leder": "Leder", "Stoff": "Stoff", "Fleisch": "Fleisch", "Elementar": "Elementar",
               "Verzauberkunst": "Verzauberung", "Trank": "Tränke", "Elixier": "Elixiere", "Fläschchen": "Fläschchen",
               "Essen & Trinken": "Speisen", "Verband": "Verbände", "Schriftrolle": "Schriftrollen", "Edelstein": "Edelsteine"}
# bekannte Ketten Rohstoff -> Produkt (werden mit den Daten geprüft)
KETTEN = [("Kräuter", "Tränke"), ("Kräuter", "Elixiere"), ("Kräuter", "Fläschchen"), ("Erz", "Barren"), ("Leder", "Lederrüstung"),
          ("Stoff", "Verbände"), ("Stoff", "Stoffrüstung"), ("Fleisch", "Speisen"), ("Barren", "Ingenieurskunst"),
          ("Elementar", "Tränke"), ("Verzauberung", "Schriftrollen")]


def segment(iid, name, stamm):
    st = stamm.get(str(iid)) or {}
    n = (name or st.get("n") or "").lower()
    u = st.get("u") or ""
    if u in UNTERKLASSE:
        return UNTERKLASSE[u]
    if u == "Metall & Stein":
        return "Barren" if "barren" in n else ("Erz" if "erz" in n else None)
    if any(k in n for k in KRAEUTER) or n.endswith(("kraut", "blatt", "blüte", "wurz", "moos")):
        return "Kräuter"
    if "fläschchen" in n:
        return "Fläschchen"
    if "elixier" in n:
        return "Elixiere"
    if "trank" in n:
        return "Tränke"
    if "verband" in n:
        return "Verbände"
    if "schriftrolle" in n or n.startswith("rolle der"):
        return "Schriftrollen"
    if n.endswith("barren"):
        return "Barren"
    if n.endswith("erz"):
        return "Erz"
    if "leder" in n or "balg" in n:
        return "Leder" if not any(k in n for k in ("weste", "hose", "handschuh", "gürtel", "stiefel", "umhang", "schultern")) else "Lederrüstung"
    if n.endswith("stoff") or "stoffballen" in n:
        return "Stoff"
    if any(k in n for k in EDEL):
        return "Edelsteine"
    if "elementar" in n or "herz des feuers" in n:
        return "Elementar"
    if any(k in n for k in ("essenz", "staub", "splitter", "scherbe")):
        return "Verzauberung"
    if any(k in n for k in ("fleisch", "flanke", "rippchen", "lunge", "schenkel")):
        return "Fleisch"
    if any(k in n for k in ("steak", "eintopf", "kebab", "suppe", "braten", "kuchen", "omelett")):
        return "Speisen"
    return None


def _tag(u):
    return dt.datetime.fromtimestamp(u, dt.timezone.utc).astimezone(BERLIN).strftime("%Y-%m-%d")


def _korr(a, b):
    n = len(a)
    if n < 5:
        return None
    ma, mb = sum(a) / n, sum(b) / n
    va = sum((x - ma) ** 2 for x in a)
    vb = sum((y - mb) ** 2 for y in b)
    if va <= 0 or vb <= 0:
        return None
    return sum((x - ma) * (y - mb) for x, y in zip(a, b)) / (va * vb) ** 0.5


def segmente(reihen, jetzt, kenn, namen, stamm):
    """Preis-Index je Markt-Segment (100 = eigener 14-Tage-Median der Items) + Ketten Rohstoff -> Produkt."""
    heute = _tag(jetzt)
    je = defaultdict(lambda: defaultdict(list))   # seg -> tag -> [verhältnis]
    items = defaultdict(list)
    for iid, pkt in reihen.items():
        vt = (kenn.get(str(iid)) or {}).get("vt") or 0
        if vt < MIN_UMSATZ:
            continue
        sg = segment(iid, namen.get(iid), stamm)
        if not sg:
            continue
        tage = defaultdict(list)
        for x in pkt:
            tage[_tag(x[0])].append(x[1])
        tm = {t: median(v) for t, v in tage.items() if len(v) >= 4}
        if len(tm) < 7:
            continue
        basis = median(tm.values())
        if basis <= 0:
            continue
        for t, v in tm.items():
            je[sg][t].append(v / basis)
        items[sg].append(iid)
    idx = {}
    for sg, tg in je.items():
        if len(items[sg]) < 3:
            continue
        idx[sg] = {t: median(v) * 100 for t, v in tg.items() if len(v) >= 3}
    tage_alle = sorted({t for v in idx.values() for t in v})
    seg = []
    for sg, s in idx.items():
        if heute not in s:
            continue
        ts = sorted(s)
        jetzt_i = s[heute]
        vor3 = s.get(ts[-4]) if len(ts) >= 4 else None
        tr3 = round((jetzt_i / vor3 - 1) * 100) if vor3 else 0
        seg.append({"name": sg, "n": len(items[sg]), "index": round(jetzt_i), "tr3": tr3,
                    "verlauf": [round(s[t]) for t in ts[-7:]]})
    seg.sort(key=lambda x: -abs(x["tr3"]))
    # Zusammenhänge: Tagesänderung Rohstoff am Tag t gegen Produkt am Tag t+1 (Folgt das Produkt?)
    zus = []
    def aend(sg):
        s = idx[sg]
        return {t2: s[t2] / s[t1] - 1 for t1, t2 in zip(tage_alle, tage_alle[1:]) if t1 in s and t2 in s}
    for a, b in KETTEN:
        if a not in idx or b not in idx:
            continue
        da, db = aend(a), aend(b)
        paare = [(da[t1], db[t2]) for t1, t2 in zip(tage_alle, tage_alle[1:]) if t1 in da and t2 in db]
        r_folge = _korr([p[0] for p in paare], [p[1] for p in paare])
        gleich = [(da[t], db[t]) for t in da if t in db]
        r_gleich = _korr([p[0] for p in gleich], [p[1] for p in gleich])
        sa = next((x for x in seg if x["name"] == a), None)
        sb = next((x for x in seg if x["name"] == b), None)
        if not sa or not sb:
            continue
        r = max([x for x in (r_folge, r_gleich) if x is not None] or [0])
        text = "%s %+d %% in 3 Tagen, %s %+d %%" % (a, sa["tr3"], b, sb["tr3"])
        if abs(sa["tr3"]) >= 8 and r >= 0.4 and abs(sb["tr3"]) < abs(sa["tr3"]) / 2:
            text += " – %s folgt meist %s: %s jetzt %s" % (b, "einen Tag später" if (r_folge or 0) >= (r_gleich or 0) else "am selben Tag",
                                                          b, "kaufen/halten" if sa["tr3"] > 0 else "nicht kaufen")
            stufe = "chance" if sa["tr3"] > 0 else "achtung"
        elif r >= 0.4:
            stufe, text = "info", text + " – laufen meist zusammen"
        else:
            stufe, text = "info", text + " – noch kein klarer Zusammenhang"
        zus.append({"von": a, "zu": b, "r": round(r, 2), "rFolge": round(r_folge, 2) if r_folge is not None else None,
                    "tage": len(paare), "stufe": stufe, "text": text})
    zus.sort(key=lambda x: (x["stufe"] == "info", -x["r"]))
    return seg, zus
