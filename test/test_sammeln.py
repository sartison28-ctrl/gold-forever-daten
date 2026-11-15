"""Offline-Test: simuliert die Forever-API und lässt sammeln.py zwei Stunden laufen.
Aufruf: python test/test_sammeln.py
"""
import csv
import importlib.util
import json
import os
import shutil
import sys

HIER = os.path.dirname(os.path.abspath(__file__))
WURZEL = os.path.dirname(HIER)
AUS = os.path.join(HIER, "ausgabe")

spec = importlib.util.spec_from_file_location("sammeln", os.path.join(WURZEL, "sammeln.py"))
s = importlib.util.module_from_spec(spec)
spec.loader.exec_module(s)
shutil.rmtree(AUS, ignore_errors=True)
s.DATEN = os.path.join(AUS, "daten")
s.ZUSTAND = os.path.join(AUS, "zustand")
s.KONFIG["haeuser"] = "Horde"
os.environ["BLIZZARD_CLIENT_ID"] = "x"
os.environ["BLIZZARD_CLIENT_SECRET"] = "y"

STUNDE = {"n": 0}


def auktionen():
    if STUNDE["n"] == 0:
        return [
            {"id": 1, "item": {"id": 13423}, "quantity": 20, "buyout": 2000, "time_left": "VERY_LONG"},
            {"id": 2, "item": {"id": 13423}, "quantity": 10, "buyout": 1050, "time_left": "LONG"},
            {"id": 3, "item": {"id": 13423}, "quantity": 5, "buyout": 1000, "time_left": "SHORT"},
            {"id": 4, "item": {"id": 720}, "quantity": 1, "bid": 500, "time_left": "MEDIUM"},
            {"id": 7, "item": {"id": 999}, "quantity": 5, "buyout": 500, "time_left": "VERY_LONG"},
        ], [{"id": 10, "item": {"id": 2589}, "quantity": 200, "unit_price": 30, "time_left": "LONG"}]
    return [
        {"id": 1, "item": {"id": 13423}, "quantity": 20, "buyout": 2000, "time_left": "VERY_LONG"},
        {"id": 5, "item": {"id": 13423}, "quantity": 8, "buyout": 880, "time_left": "VERY_LONG"},
        {"id": 8, "item": {"id": 999}, "quantity": 5, "buyout": 450, "time_left": "VERY_LONG"},
    ], [{"id": 10, "item": {"id": 2589}, "quantity": 150, "unit_price": 30, "time_left": "LONG"}]


def fake_http(url, daten=None, kopf=None, versuche=4):
    if "oauth" in url:
        return 200, {}, b'{"access_token":"t"}'
    pfad = url.split("api.blizzard.com")[1].split("?")[0]
    if pfad == "/data/wow/ruleset/index":
        body = {"rulesets": [{"id": 1, "name": "PvP"}, {"id": 2, "name": "Normal"}, {"id": 15, "name": "Rollenspiel-PvP"}]}
    elif pfad == "/data/wow/ruleset/1/auctions/":
        body = {"auctions": [{"id": 110, "name": "Allianz-Auktionshaus"}, {"id": 111, "name": "Horde-Auktionshaus"}]}
    elif pfad == "/data/wow/ruleset/1/auctions/111":
        a, _ = auktionen()
        body = {"id": 111, "auctions": a, "commodities": {"href": "x"}}
    elif pfad == "/data/wow/ruleset/1/auctions/111/commodities":
        body = {"auctions": auktionen()[1]}
    else:
        return 404, {}, b"{}"
    return 200, {"Last-Modified": f"T{STUNDE['n']}"}, json.dumps(body).encode()


s.http = fake_http
s.main()
# eine Stunde später
z = s.zustand_laden(111)
z["zeit"] = "2000-01-01T00:00Z"
import datetime as dt
alt = (dt.datetime.now(dt.timezone.utc) - dt.timedelta(minutes=60)).strftime("%Y-%m-%dT%H:%MZ")
z["zeit"] = alt
s.zustand_speichern(111, [(k, v[0], v[1], None, {"S": "SHORT", "M": "MEDIUM", "L": "LONG", "V": "VERY_LONG"}[v[2]])
                         for k, v in z["auktionen"].items()], alt, "T0")
STUNDE["n"] = 1
s.main()

zeilen = list(csv.DictReader(open(os.path.join(s.DATEN, "111", "aktuell.csv"))))
r = {z["item_id"]: z for z in zeilen}
for z in zeilen:
    print(z)
o = r["13423"]
assert o["stueck"] == "28" and o["min"] == "100" and o["median"] == "100", o
assert o["weg_lang"] == "10" and o["weg_kurz"] == "5" and o["verkauf_schaetzung"] == "10", o
assert o["neu_stueck"] == "8"
assert r["2589"]["teilverkauf"] == "50" and r["2589"]["verkauf_schaetzung"] == "50"
assert r["720"]["stueck"] == "0" and r["720"]["weg_mittel"] == "1"
u = r["999"]
assert u["umgestellt"] == "5" and u["weg_lang"] == "0" and u["verkauf_schaetzung"] == "0", u
assert o["umgestellt"] == "0"
print(json.load(open(os.path.join(s.DATEN, "status.json"))))
print("OK")
