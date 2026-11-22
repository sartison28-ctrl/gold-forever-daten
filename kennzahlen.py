#!/usr/bin/env python3
"""Gold Forever – Kennzahlen je Item aus den stündlichen Tagesdateien (läuft nach sammeln.py).

Ausgabe daten/<haus>/kennzahlen.json, rollende 24-Std.-Fenster (Fenster 0 = letzte 24 Std.),
damit der Tagesrhythmus (Tageshoch/-tief) keinen Trend vortäuscht:

  stand        Zeitpunkt der neuesten Stunde (UTC)
  stunden      je Fenster: Anzahl Stunden mit Verkaufsvergleich (für Hochrechnung)
  items[id]:
    m   Median des günstigsten Angebots (min) je Fenster, neueste zuerst (bis 14 Werte, null = keine Daten)
    st  Stück im AH (neueste Stunde)
    vt  geschätzte Verkäufe pro Tag (Ø der letzten 7 Fenster mit ≥ 12 Vergleichsstunden, auf 24 Std. hochgerechnet;
        erst ab Daten mit Spalte „zurueckgezogen“, d. h. ab 17.11.2026 abends)
    vt1 geschätzte Verkäufe in den letzten 24 Std.
    vp  Median-Stückpreis der geschätzten Verkäufe, letzte 7 Tage (mengengewichtet, seit 17.11.)
    vpn Stück, aus denen vp berechnet ist
    vpmin schlechtester Tages-Verkaufspreis der letzten 7 Tage (Tage mit ≥ 20 verkauften Stück; ab 4 Tagen) – Addon 2.75 Sniper
    sp  Wochen-Spanne der Tages-Verkaufspreise: max/min × 100 (135 = 1,35×) – Addon 2.75 Sniper
    vh  Verkäufe je Stunde (UTC 0–23), letzte 7 Tage – nur ab 10 Stück
    tr1 Trend in %: Fenster 0 gegen Fenster 1
    tr3 Trend in %: Fenster 0 gegen Fenster 3
    fall Anzahl Fenster in Folge mit fallendem Median (0 = nicht fallend)
"""
import csv
import datetime as dt
import glob
import json
import os
import sys

BASIS = os.path.dirname(os.path.abspath(__file__))
DATEN = os.path.join(BASIS, "daten")
FENSTER = 14


def zahl(x):
    if x is None or x == "":
        return None
    try:
        return int(float(x))
    except ValueError:
        return None


def median(werte):
    w = sorted(werte)
    n = len(w)
    if not n:
        return None
    return w[n // 2] if n % 2 else (w[n // 2 - 1] + w[n // 2]) // 2


def gew_median(paare):
    paare = sorted(p for p in paare if p[1] > 0)
    gesamt = sum(m for _, m in paare)
    if not gesamt:
        return None
    lauf = 0
    for preis, m in paare:
        lauf += m
        if lauf >= gesamt / 2:
            return preis
    return paare[-1][0]


def prozent(a, b):
    if a is None or not b:
        return None
    return round((a - b) * 100 / b)


def haus_auswerten(ordner):
    dateien = sorted(glob.glob(os.path.join(ordner, "20*.csv")))[-(FENSTER + 1):]
    if not dateien:
        return None
    zeilen = []
    for d in dateien:
        with open(d, newline="", encoding="utf-8") as f:
            zeilen.extend(csv.DictReader(f))
    if not zeilen:
        return None
    def zeitpunkt(s):
        return dt.datetime.strptime(s, "%Y-%m-%dT%H:%MZ").replace(tzinfo=dt.timezone.utc)
    neueste = max(z["zeit_utc"] for z in zeilen)
    ende = zeitpunkt(neueste) + dt.timedelta(minutes=1)

    vergleich = [set() for _ in range(FENSTER)]  # Stunden mit Verkaufsvergleich je Fenster
    mins = {}       # item -> [ [min je Stunde] je Fenster ]
    verk = {}       # item -> [Stück je Fenster]
    preise = {}     # item -> [[preis, stück]] (7 Tage)
    tagpreise = {}  # item -> [ [[preis, stück]] je Fenster ] (7 Tage) – für vpmin/sp
    stunden = {}    # item -> [24] (7 Tage)
    stueck = {}
    for z in zeilen:
        t = zeitpunkt(z["zeit_utc"])
        k = int((ende - t).total_seconds() // 86400)
        if k < 0 or k >= FENSTER:
            continue
        item = z["item_id"]
        mn = zahl(z.get("min"))
        if mn is not None:
            mins.setdefault(item, [[] for _ in range(FENSTER)])[k].append(mn)
        # Verkäufe erst ab dem Filter „zurückgezogen“ (17.11.2026) zählen – ältere Schätzungen sind viel zu hoch
        vs = zahl(z.get("verkauf_schaetzung")) if z.get("zurueckgezogen") not in (None, "") else None
        if vs is not None:
            vergleich[k].add(z["zeit_utc"])
            if vs > 0:
                verk.setdefault(item, [0] * FENSTER)[k] += vs
                if k < 7:
                    stunden.setdefault(item, [0] * 24)[t.hour] += vs
                    vp = zahl(z.get("verkauf_preis_median"))
                    if vp is not None:
                        preise.setdefault(item, []).append([vp, vs])
                        tagpreise.setdefault(item, [[] for _ in range(7)])[k].append([vp, vs])
        if z["zeit_utc"] == neueste:
            stueck[item] = zahl(z.get("stueck")) or 0
    std = [len(s) for s in vergleich]

    items = {}
    for item in set(mins) | set(verk):
        m = [median(x) for x in mins.get(item, [[]] * FENSTER)]
        while m and m[-1] is None:
            m.pop()
        e = {"m": m, "st": stueck.get(item, 0)}
        v = verk.get(item)
        if v:
            tage = [(v[k], std[k]) for k in range(7) if std[k] >= 12]
            if tage:
                e["vt"] = round(sum(n * 24 / h for n, h in tage) / len(tage), 1)
            if std[0] >= 12:
                e["vt1"] = round(v[0] * 24 / std[0], 1)
        if item in preise:
            e["vp"] = gew_median(preise[item])
            e["vpn"] = sum(n for _, n in preise[item])
        if item in tagpreise:
            tp = [gew_median(x) for x in tagpreise[item] if x and sum(n for _, n in x) >= 20]
            tp = [x for x in tp if x]
            if len(tp) >= 4:
                e["vpmin"] = min(tp)
                e["sp"] = round(max(tp) / min(tp) * 100)
        if item in stunden and sum(stunden[item]) >= 10:
            e["vh"] = stunden[item]
        if m:
            e["tr1"] = prozent(m[0], m[1] if len(m) > 1 else None)
            e["tr3"] = prozent(m[0], m[3] if len(m) > 3 else None)
            fall = 0
            for k in range(len(m) - 1):
                if m[k] is not None and m[k + 1] is not None and m[k] < m[k + 1]:
                    fall += 1
                else:
                    break
            e["fall"] = fall
        items[item] = {k2: w for k2, w in e.items() if w is not None}
    return {"stand": neueste, "fenster_std": 24, "stunden": std, "items": items}


def realm_lua(erg, pfad):
    """Kompakte Realm-Datei fürs Addon (GoldForever_Realm.lua, ab 2.52).

    GoldForeverRealm = {stand = "...", t = <Unixzeit>, i = {[id] = {m, n, m0, tr3, fall, vt, vp, st, vpmin, sp}}}
      m    Median der Tagesmediane (bis 7 Tage) = „üblicher“ Realm-Preis
      n    Anzahl Tage mit Median
      m0   Median der letzten 24 Std.
      tr3, fall, vt, vp, st wie in kennzahlen.json (fehlende Werte = 0 bzw. weggelassen)
    Nur Items mit mindestens 2 Tagesmedianen oder geschätzten Verkäufen.
    """
    stand = erg["stand"]
    t = int(dt.datetime.strptime(stand, "%Y-%m-%dT%H:%MZ").replace(tzinfo=dt.timezone.utc).timestamp())
    zeilen = []
    for item, e in sorted(erg["items"].items(), key=lambda x: int(x[0])):
        ms = [x for x in (e.get("m") or [])[:7] if x is not None]
        if len(ms) < 2 and not e.get("vt"):
            continue
        werte = [median(ms) or 0, len(ms), (e.get("m") or [None])[0] or 0, e.get("tr3") or 0, e.get("fall") or 0,
                 e.get("vt") or 0, e.get("vp") or 0, e.get("st") or 0, e.get("vpmin") or 0, e.get("sp") or 0]
        zeilen.append("[%s]={%s}," % (item, ",".join(str(int(round(w))) if isinstance(w, (int, float)) else "0" for w in werte)))
    with open(pfad, "w", encoding="utf-8") as f:
        f.write("-- Gold Forever Realm-Daten (GitHub, automatisch) – Felder: m, n, m0, tr3, fall, vt, vp, st, vpmin, sp\n")
        f.write('GoldForeverRealm = {stand = "%s", t = %d, i = {\n' % (stand, t))
        f.write("\n".join(zeilen))
        f.write("\n}}\n")
    return len(zeilen)


def main():
    for ordner in sorted(glob.glob(os.path.join(DATEN, "*"))):
        if not os.path.isdir(ordner):
            continue
        erg = haus_auswerten(ordner)
        if not erg:
            continue
        with open(os.path.join(ordner, "kennzahlen.json"), "w", encoding="utf-8") as f:
            json.dump(erg, f, separators=(",", ":"))
        n_lua = realm_lua(erg, os.path.join(ordner, "GoldForever_Realm.lua"))
        print(f"{os.path.basename(ordner)}: {len(erg['items'])} Items ({n_lua} in GoldForever_Realm.lua), Stand {erg['stand']}, Vergleichsstunden {erg['stunden']}", flush=True)


if __name__ == "__main__":
    sys.exit(main())
