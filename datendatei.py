#!/usr/bin/env python3
"""Gold Forever – Datendatei GoldForever_Daten.lua aus den GitHub-Stundendaten (ersetzt gf_addon.py + TSM auf dem PC).

Läuft im Workflow nach kennzahlen.py. Grundlage:
  daten/<haus>/20*.csv            stündliche Auktionsdaten (Blizzard-API)
  daten/<haus>/kennzahlen.json    Realm-Kennzahlen (Trend, Verkäufe, Verkaufspreis, Verkaufsstunden)
  daten/<haus>/basis/items.json   feste Item-Liste aus der alten TSM-Datei {id: [Name, Warengruppe]}
  daten/<haus>/basis/gf_katalog.json  Raid-Katalog, Events, Raidstart, Reset-Tag
Ausgabe daten/<haus>/GoldForever_Daten.lua – gleiches Format wie früher (GoldForeverData), damit das Addon unverändert liest:
  items[id] = {Name, Preis jetzt, Verkaufspreis (statt Regions-Ø), üblicher Preis (statt TSM-Marktwert), Verkäufe/Tag,
               Auktionen jetzt, nil, Warengruppe}
  zeit[id]  = Zeitfenster wie gf_addon.py (t, ph, h, d, dip, erh, rs, am, m, q1, q3, n, tn, hn, tl, bv, bk) +
              Realm-Kennzahlen (rm, rst, rvt, rvt1, rvp, rvpn, rvh, rtr1, rtr3, rfall)
  tag, gruppen, raid, events, raidstart, reset, budget
Phasen (hoch/tief) messen gegen den Realm-Median der letzten 7 Tage (früher gegen den Regions-Ø von TSM).
"""
import csv, datetime as dt, glob, json, math, os, statistics, sys
from collections import defaultdict
from zoneinfo import ZoneInfo

BASIS = os.path.dirname(os.path.abspath(__file__))
BERLIN = ZoneInfo("Europe/Berlin")
WT = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]


def lua(v):
    if v is None:
        return "nil"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return str(int(v)) if float(v).is_integer() else ("%.2f" % v)
    if isinstance(v, str):
        return '"' + v.replace('\\', '\\\\').replace('"', '\\"').replace('\n', ' ') + '"'
    if isinstance(v, (list, tuple)):
        return "{" + ",".join(lua(x) for x in v) + "}"
    if isinstance(v, dict):
        teile = []
        for k, x in v.items():
            if isinstance(k, int) or (isinstance(k, str) and k.isdigit()):
                teile.append("[%s]=%s" % (int(k), lua(x)))
            else:
                teile.append("[%s]=%s" % (lua(str(k)), lua(x)))
        return "{" + ",".join(teile) + "}"
    return "nil"


def zahl(x):
    try:
        return int(float(x)) if x not in (None, "") else None
    except ValueError:
        return None


def reihen_laden(ordner, ids):
    """Je Item [(unix, min, auktionen, stunde_berlin, wochentag, datum_berlin)] der letzten 15 Tage."""
    dateien = sorted(glob.glob(os.path.join(ordner, "20*.csv")))[-15:]
    reihen = defaultdict(list)
    jetzt = None
    for d in dateien:
        with open(d, newline="", encoding="utf-8") as f:
            for z in csv.DictReader(f):
                iid = zahl(z.get("item_id"))
                if iid not in ids:
                    continue
                p = zahl(z.get("min"))
                if not p or p <= 0:
                    continue
                t = dt.datetime.strptime(z["zeit_utc"], "%Y-%m-%dT%H:%MZ").replace(tzinfo=dt.timezone.utc)
                lok = t.astimezone(BERLIN)
                u = int(t.timestamp())
                reihen[iid].append((u, p, zahl(z.get("auktionen")) or 0, lok.hour, WT[lok.weekday()], lok.strftime("%Y-%m-%d")))
                jetzt = u if jetzt is None or u > jetzt else jetzt
    for v in reihen.values():
        v.sort()
    return reihen, jetzt


def zeitfenster(pkt):
    """Wie gf_addon.py, Phasen gegen den Realm-Median (7 Tage) statt Regions-Ø."""
    if len(pkt) < 4:
        return None
    ts = [a[0] for a in pkt]
    jetzt = ts[-1]
    woche_alle = [a[1] for a in pkt if a[0] >= jetzt - 7 * 86400]
    ref = statistics.median(woche_alle) if woche_alle else statistics.median(a[1] for a in pkt)
    roh = [a[1] / ref for a in pkt]
    q = [statistics.median(roh[max(0, k - 1):k + 2]) for k in range(len(roh))]
    letzte = [a[1] for a in pkt if a[0] >= jetzt - 3 * 3600]
    davor = [a[1] for a in pkt if jetzt - 9 * 3600 <= a[0] < jetzt - 3 * 3600]
    t = round((statistics.median(letzte) / statistics.median(davor) - 1) * 100) if letzte and davor else 0
    phase = ["hoch" if v >= 1.15 else "tief" if v <= 0.9 else "normal" for v in q]
    ph = phase[-1]
    k = len(phase) - 1
    while k > 0 and phase[k - 1] == ph:
        k -= 1
    h = round((jetzt - ts[k]) / 3600)
    dauer, start = [], None
    for j in range(k):
        if phase[j] == ph and start is None:
            start = j
        if start is not None and phase[j] != ph:
            if start > 0:
                dauer.append((ts[j] - ts[start]) / 3600)
            start = None
    z = {"t": t, "ph": ph, "h": h}
    mall = statistics.median(a[1] for a in pkt)
    dips = erh = 0
    k = 0
    while k < len(pkt):
        if pkt[k][1] <= 0.85 * mall:
            dips += 1
            t0 = pkt[k][0]
            if any(a[1] >= 0.95 * mall for a in pkt[k + 1:] if a[0] - t0 <= 12 * 3600):
                erh += 1
            while k < len(pkt) and pkt[k][1] <= 0.85 * mall:
                k += 1
        k += 1
    if dips:
        z["dip"], z["erh"] = dips, erh
    # Aufkaeufer (Reset anderer Spieler): Sprung auf >= 2x des ruhigen Vorher-Niveaus, Angebote fast weg, bleibt oben
    rs_t = rs_v = None
    for k2 in range(1, len(pkt)):
        a = pkt[k2]
        if a[0] < jetzt - 72 * 3600:
            continue
        vor = [b for b in pkt if a[0] - 27 * 3600 <= b[0] <= a[0] - 1800]
        if len(vor) < 4:
            continue
        sv = sorted(b[1] for b in vor)
        vm = statistics.median(sv)
        vc = statistics.median(b[2] for b in vor)
        ruhig = sv[(len(sv) * 3) // 4] <= 1.5 * sv[len(sv) // 4]
        scharf = pkt[k2 - 1][1] < 1.5 * vm
        leer = min(b[2] for b in pkt[max(0, k2 - 1):k2 + 2]) <= 0.35 * vc
        haelt = min(b[1] for b in pkt[k2:k2 + 3]) >= 1.5 * vm
        if ruhig and scharf and leer and haelt and a[1] >= 2 * vm and vc >= 10:
            rs_t, rs_v = a[0], int(vm)
            break
    if rs_t and pkt[-1][1] >= 1.4 * rs_v:
        z["rs"] = {"v": rs_v, "t": rs_t}
    ana = [a[2] for a in pkt[:-1] if a[0] >= jetzt - 7 * 86400 and a[2] > 0]
    if len(ana) >= 6:
        z["am"] = int(statistics.median(ana))
    woche = [a[1] for a in pkt if a[0] >= jetzt - 7 * 86400 and not (z.get("rs") and a[0] >= rs_t)]
    if len(woche) >= 6:
        sw = sorted(woche)
        z["m"] = int(statistics.median(sw))
        z["q1"] = sw[len(sw) // 4]
        z["q3"] = sw[(len(sw) * 3) // 4]
        z["n"] = len(sw)
        tn = 0
        for a in reversed(pkt):
            if a[1] <= z["m"] * 0.85:
                tn += 1
            else:
                break
        hn = 0
        for a in reversed(pkt):
            if a[1] >= z["m"] * 1.25:
                hn += 1
            else:
                break
        z["tn"], z["hn"] = tn, hn
    neu24 = [a[1] for a in pkt if a[0] >= jetzt - 86400]
    alt24 = [a[1] for a in pkt if jetzt - 2 * 86400 <= a[0] < jetzt - 86400]
    if len(neu24) >= 4 and len(alt24) >= 4:
        z["tl"] = round((statistics.median(neu24) / statistics.median(alt24) - 1) * 100)
    if ph != "normal" and len(dauer) >= 2:
        z["d"] = round(statistics.median(dauer))
    if (ts[-1] - ts[0]) / 86400 >= 4:
        je = defaultdict(list)
        for a in pkt:
            je[a[3]].append(a[1] / ref)
        mittel = {s: statistics.median(v) for s, v in je.items() if len(v) >= 3}
        if len(mittel) >= 12:
            z["bv"] = max(mittel, key=mittel.get)
            z["bk"] = min(mittel, key=mittel.get)
    return z


def tagesprofil(reihen):
    """Tagesrhythmus ueber alle Items (14 Tage): je Stunde Preis-/Angebotsabweichung in %, Tage mit Messung."""
    if not reihen:
        return {}
    jetzt = max(v[-1][0] for v in reihen.values() if v)
    sammel = {"alle": defaultdict(lambda: [[], [], set()]), "we": defaultdict(lambda: [[], [], set()]),
              "wt": defaultdict(lambda: [[], [], set()])}
    for vs in reihen.values():
        vs = [v for v in vs if v[0] >= jetzt - 14 * 86400]
        if len(vs) < 10:
            continue
        mp = statistics.median(v[1] for v in vs)
        ma = statistics.median(v[2] for v in vs) or 1
        for v in vs:
            lp = max(-0.5, min(0.5, math.log(v[1] / mp)))
            la = max(-1.0, min(1.0, math.log(max(v[2], 1) / ma)))
            for k in ("alle", "we" if v[4] in ("Sa", "So") else "wt"):
                s = sammel[k][v[3]]
                s[0].append(lp); s[1].append(la); s[2].add(v[5])
    out = {}
    for k, std in sammel.items():
        prof = {h: {"p": round((math.exp(statistics.mean(lp)) - 1) * 100, 1),
                    "a": round((math.exp(statistics.mean(la)) - 1) * 100), "n": len(tage)}
                for h, (lp, la, tage) in std.items()}
        if prof:
            out[k] = prof
    return out


def realm_kennzahlen(pfad, ids, zeit):
    if not os.path.exists(pfad):
        return {}
    k = json.load(open(pfad, encoding="utf-8"))
    versatz = int(dt.datetime.now(BERLIN).utcoffset().total_seconds() // 3600)
    kurz = {}
    for sid, e in (k.get("items") or {}).items():
        iid = int(sid)
        if iid not in ids:
            continue
        kurz[iid] = e
        z = zeit.setdefault(iid, {})
        if e.get("m"):
            z["rm"] = e["m"][:7]
        for quelle, ziel in (("st", "rst"), ("vt", "rvt"), ("vt1", "rvt1"), ("vp", "rvp"), ("vpn", "rvpn"),
                             ("tr1", "rtr1"), ("tr3", "rtr3"), ("fall", "rfall")):
            if e.get(quelle) is not None:
                z[ziel] = e[quelle]
        if e.get("vh"):
            z["rvh"] = [e["vh"][(h - versatz) % 24] for h in range(24)]
    return kurz


def haus(ordner):
    basis = os.path.join(ordner, "basis")
    if not os.path.exists(os.path.join(basis, "items.json")):
        return None
    namen = {int(k): v for k, v in json.load(open(os.path.join(basis, "items.json"), encoding="utf-8")).items()}
    kat = json.load(open(os.path.join(basis, "gf_katalog.json"), encoding="utf-8"))
    ids = set(namen) | {int(k) for k in kat.get("raid", {})}
    reihen, jetzt = reihen_laden(ordner, ids)
    if not jetzt:
        return None
    zeit = {}
    for iid, pkt in reihen.items():
        z = zeitfenster(pkt)
        if z:
            zeit[iid] = z
    kenn = realm_kennzahlen(os.path.join(ordner, "kennzahlen.json"), ids, zeit)
    items = {}
    for iid in sorted(ids):
        pkt = reihen.get(iid)
        e = kenn.get(iid, {})
        z = zeit.get(iid, {})
        if not pkt and not e:
            continue
        nm, gruppe = namen.get(iid, ["Item %d" % iid, ""])
        p = pkt[-1][1] if pkt and pkt[-1][0] >= jetzt - 3 * 3600 else None
        auk = pkt[-1][2] if pkt else None
        items[iid] = [nm, p, e.get("vp"), z.get("m"), e.get("vt"), auk, None, gruppe or None]
    gq = defaultdict(lambda: [0, 0])
    for iid, z in zeit.items():
        g = items.get(iid, [None] * 8)[7]
        if g and z.get("dip"):
            gq[g][0] += z["dip"]; gq[g][1] += z["erh"]
    gruppen = {g: {"dip": v[0], "q": round(v[1] / v[0], 2)} for g, v in gq.items() if v[0] >= 5}
    stand = dt.datetime.fromtimestamp(jetzt, dt.timezone.utc)
    doc = {
        "stand": jetzt, "standText": stand.astimezone(BERLIN).strftime("%a %d.%m. %H:%M").replace("Mon", "Mo").replace("Tue", "Di")
        .replace("Wed", "Mi").replace("Thu", "Do").replace("Fri", "Fr").replace("Sat", "Sa").replace("Sun", "So"),
        "quelle": "github",
        "raidstart": kat.get("raidstart"), "reset": kat.get("reset", 3), "budget": kat.get("budget", 0.7),
        "items": items, "raid": kat.get("raid", {}), "events": kat.get("events", []), "rez": [],
        "chars": {}, "bestand": {}, "zeit": zeit, "tag": tagesprofil(reihen), "gruppen": gruppen,
    }
    pfad = os.path.join(ordner, "GoldForever_Daten.lua")
    with open(pfad, "w", encoding="utf-8", newline="\n") as f:
        f.write('-- Gold Forever Datendatei (GitHub, automatisch, ersetzt TSM/gf_addon.py) – stand = "%s"\n' % stand.strftime("%Y-%m-%dT%H:%MZ"))
        f.write("GoldForeverData = " + lua(doc) + "\n")
    return len(items), len(zeit), len(doc["raid"])


def main():
    for ordner in sorted(glob.glob(os.path.join(BASIS, "daten", "*"))):
        if os.path.isdir(ordner):
            r = haus(ordner)
            if r:
                print(f"{os.path.basename(ordner)}: Datendatei {r[0]} Items, {r[1]} Zeitfenster, {r[2]} Raid-Items", flush=True)


if __name__ == "__main__":
    sys.exit(main())
