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


def _z(x):
    try:
        return float(x)
    except (TypeError, ValueError):
        return None


def laden(ordner, ids, tage=8):
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


def rechnen(ordner, ids, kenn, namen=None):
    """kenn = kennzahlen.json['items'] (vt = Verkäufe/Tag, sta = üblicher Bestand)."""
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
    verpasst.sort(key=lambda x: -x["gewinn"])
    blick.sort(key=lambda x: -x["wert"])
    auftrag.sort(key=lambda x: -x["wert"])
    # Verkaufs-Hochs: mehr behalten – das Addon filtert auf die eigene Ware
    vk = [x for x in verpasst if x["art"] == "kauf"][:25] + [x for x in verpasst if x["art"] == "verk"][:80]
    return {"stand": jetzt, "verpasst": vk, "blick": blick[:25], "auftrag": auftrag[:10],
            "regel": {"kaufTief": KAUF_TIEF, "verkHoch": VERK_HOCH, "minUmsatz": MIN_UMSATZ, "flut": FLUT}}
