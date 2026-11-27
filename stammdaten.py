"""Stammdaten je Item (Name, Warenklasse, Unterklasse) aus der Blizzard-API – für Namen ohne „Item 12345“ und für
Markt-Segmente (Kräuter, Tränke, Leder …) im Wächter. Läuft stündlich im Workflow, holt je Lauf höchstens MAX neue Items
(meistgehandelte zuerst) und merkt sich, was es nicht gibt. Fehler brechen nie den Workflow ab.
Ergebnis: daten/<haus>/basis/stamm.json = {id: {"n": Name, "k": Klasse, "u": Unterklasse, "kid": .., "uid": ..}}
"""
import glob
import json
import os
import sys

MAX = 150
KANDIDATEN_NS = ["static-forever-{r}", "static-classic1x-{r}", "static-classic-{r}", "static-{r}"]


def main():
    try:
        import sammeln as S
    except SystemExit:
        return 0
    api = S.Api(S.token_holen())
    for ordner in sorted(glob.glob(os.path.join(S.DATEN, "*"))):
        basis = os.path.join(ordner, "basis")
        if not os.path.isdir(basis):
            continue
        pfad = os.path.join(basis, "stamm.json")
        stamm = json.load(open(pfad, encoding="utf-8")) if os.path.exists(pfad) else {}
        meta = stamm.pop("_meta", {"ns": None, "fehlt": []})
        fehlt = set(meta.get("fehlt", []))
        kpf = os.path.join(ordner, "kennzahlen.json")
        kenn = json.load(open(kpf, encoding="utf-8")).get("items", {}) if os.path.exists(kpf) else {}
        offen = [i for i in sorted(kenn, key=lambda k: -(kenn[k].get("vt") or 0)) if i not in stamm and i not in fehlt][:MAX]
        if not offen:
            continue
        ns = meta.get("ns")
        if not ns:
            for k in KANDIDATEN_NS:
                kand = k.format(r=S.REGION)
                try:
                    d, _ = api.get("/data/wow/item/2589", namespace=kand, erlaubt_404=True)
                except Exception:
                    d = None
                if d:
                    ns = kand
                    break
            if not ns:
                S.log("Stammdaten: kein statischer Namespace gefunden – übersprungen")
                return 0
            meta["ns"] = ns
        neu = 0
        for i in offen:
            try:
                d, _ = api.get(f"/data/wow/item/{int(i)}", namespace=ns, erlaubt_404=True)
            except Exception as e:
                S.log(f"Stammdaten {i}: {e}")
                break
            if not d:
                fehlt.add(i)
                continue
            stamm[i] = {"n": S.name_text(d.get("name")),
                        "k": S.name_text((d.get("item_class") or {}).get("name")), "kid": (d.get("item_class") or {}).get("id"),
                        "u": S.name_text((d.get("item_subclass") or {}).get("name")), "uid": (d.get("item_subclass") or {}).get("id")}
            neu += 1
        meta["fehlt"] = sorted(fehlt)
        stamm["_meta"] = meta
        with open(pfad, "w", encoding="utf-8") as f:
            json.dump(stamm, f, ensure_ascii=False, separators=(",", ":"))
        S.log(f"Stammdaten {os.path.basename(ordner)}: +{neu} (gesamt {len(stamm) - 1}, ns {ns})")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as e:  # nie den Workflow stoppen
        print("Stammdaten fehlgeschlagen:", e)
        sys.exit(0)
