dofile("stub36.lua")
GoldForever = {}
GoldForeverDB = { bilanz = { buch = {} }, sniper = { log = {} } }
GoldForeverData = { stand = JETZT - 3600, items = {}, zeit = {}, raid = {}, events = {}, gruppen = {} }
GoldForeverRealm = { stand = "x", t = JETZT - 3600, i = {} }
local ok, e = pcall(dofile, "../addon/Core.lua")
print("Core geladen:", ok, e); assert(ok, e)
local GF = GoldForever
assert(GF and GF.sniperBewerten, "GF fehlt")
-- Testwelt: Items [id] = {name, klasse, unter, R(üblich), u(Umsatz), Realm {m,n,m0,tr3,fall,vt,vp,st,vpmin,sp}}
local W = {
  [12184] = { "Raptorfleisch", 7, 8, 316, 7300, { 310, 7, 316, 2, 0, 7300, 316, 400, 285, 117 } },
  [3827]  = { "Manatrank", 0, 1, 184, 2200, { 180, 7, 184, 0, 0, 2200, 184, 300, 165, 115 } },
  [249429]= { "Makellose Schuppe", 7, 6, 2988, 936, { 2988, 7, 1500, -66, 4, 936, 2988, 500, 1000, 293 } },
  [249399]= { "Gekräuselte Flechte", 7, 9, 4145, 1845, { 4145, 7, 4145, 40, 0, 1845, 4145, 200, 3000, 145 } },
  [248706]= { "Abgefangene Kiste: Barren des Gesellen", 7, 7, 2450, 400, { 2450, 7, 2450, 0, 0, 400, 2450, 50, 2400, 110 } },
  [6362]  = { "Roher Steinschuppenkabeljau", 7, 8, 5, 12000, { 5, 7, 5, 0, 0, 12000, 5, 9000, 5, 100 } },
  [4338]  = { "Magiestoff", 7, 5, 401, 23800, { 400, 7, 401, 0, 0, 23800, 401, 5000, 399, 101 } },
}
for id, w in pairs(W) do
  NAMEN[id] = w[1]; KLASSE[id] = { w[2], w[3] }
  GoldForeverData.items[id] = { w[1], w[4], w[4], w[4], w[5], 50 }
  GoldForeverData.zeit[id] = { m = w[4], n = 50 }
  GoldForeverRealm.i[id] = w[6]
end
GF.anzahl = function() return 0 end; GF.imAH = function() return 0 end
GF.raid = function() return false end
local function lauf(titel, id, stufen)
  GF.live[id] = { t = JETZT, st = stufen }
  local t = GF.sniperBewerten(id)
  local grund = GF.sniper.letzterGrund
  print(string.format("%-28s -> %s", titel, t and string.format("TREFFER %d× je bis %s, Kosten %s, Gewinn %s (%d %%), Verkauf je %s", t.n, GF.geld(t.max), GF.geld(t.kosten), GF.geld(t.gewinn), math.floor(t.gewinn / t.kosten * 100), GF.geld(t.neu)) or ("nein: " .. tostring(grund))))
  return t
end
print("--- Sicherheitsregel ---")
local s1 = lauf("Raptorfleisch billig", 12184, { { p = 200, q = 40 }, { p = 300, q = 200 } })
assert(s1 and s1.n <= 730, "Raptor sollte Treffer sein")
assert(s1.gewinn >= s1.kosten * 0.15)
lauf("Raptorfleisch nur 10 % drunter", 12184, { { p = 280, q = 40 }, { p = 300, q = 200 } })
local m = lauf("Manatrank billig", 3827, { { p = 120, q = 30 }, { p = 180, q = 100 } }); assert(m)
assert(not lauf("Makellose Schuppe (Trend)", 249429, { { p = 900, q = 50 }, { p = 2800, q = 100 } }))
assert(not lauf("Flechte (Trend +40)", 249399, { { p = 2000, q = 50 }, { p = 4000, q = 100 } }))
assert(not lauf("Kiste", 248706, { { p = 1000, q = 20 }, { p = 2400, q = 100 } }))
assert(not lauf("Kabeljau 5c", 6362, { { p = 2, q = 600 }, { p = 5, q = 1000 } }))
assert(not lauf("Raptor ohne Angebot darüber", 12184, { { p = 200, q = 40 } }))
-- Menge: 10 % vom Umsatz inkl. Bestand
GF.anzahl = function(id) return id == 3827 and 200 or 0 end
local m2 = lauf("Manatrank, 200 schon da", 3827, { { p = 120, q = 15 }, { p = 125, q = 300 }, { p = 180, q = 100 } }); assert(not m2 or m2.n <= 20, "Menge mit Bestand"); local m3 = lauf("Manatrank, 200 da, kleiner Rest", 3827, { { p = 120, q = 15 }, { p = 180, q = 300 } }); assert(m3 and m3.n == 15)
GF.anzahl = function() return 0 end
-- Magiestoff: grosser Stapel, Gewinn klein -> Mindestgewinn
lauf("Magiestoff 3s 30c", 4338, { { p = 330, q = 5 }, { p = 400, q = 100 } })
lauf("Magiestoff 3s 20c viel", 4338, { { p = 320, q = 300 }, { p = 400, q = 100 } })
print("--- Kategorien ---")
for id, w in pairs(W) do print(w[1], GF.sniperKatVon(id)) end
GF.alleIds = function() local t = {} for id in pairs(W) do t[id] = true end return t end
for _, k in ipairs({ "alle", "fleisch", "traenke", "leder", "kraeuter", "erz", "stoffe" }) do
  local ids = GF.sniperFokusKandidaten(nil, k); local n = {} for _, x in ipairs(ids) do n[#n + 1] = NAMEN[x] end
  print(k, table.concat(n, ", "))
end
print("--- Befehle ---")
GF.sniperBefehl("sicher"); GF.sniperBefehl("sicher marge 20"); GF.sniperBefehl("sicher reset")
GF.sniperBefehl("fokus fleisch"); print("fokusKat =", GoldForeverDB.sniper.fokusKat)
GF.sniperBefehl("fokus 3827"); print("fokusEins =", GoldForeverDB.sniper.fokusEins)
GF.sniperBefehl("fokus alle"); print("fokusKat =", GoldForeverDB.sniper.fokusKat, "eins", GoldForeverDB.sniper.fokusEins)
GF.sniperBefehl("")
