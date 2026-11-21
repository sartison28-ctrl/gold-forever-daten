dofile("/home/claude/test/t1.lua")
local GF = GoldForever
M_CreateLine = function(s) local o = CreateFrame("Line", nil, s); o.SetStartPoint = function() end; o.SetEndPoint = function() end; o.SetThickness = function() end; o.SetColorTexture = function() end; LINES = (LINES or 0) + 1; return o end
-- Grenze
local i = GF.info(2453)
zeige("Grenze u500: " .. GF.sniperGrenze(2453, i, 100, 600) .. "  u300: " .. GF.sniperGrenze(2453, i, 100, 300) .. "  u40: " .. GF.sniperGrenze(2453, i, 100, 40))
assert(GF.sniperGrenze(2453, i, 100, 600) > 0.87 and GF.sniperGrenze(2453, i, 100, 300) == 0.85)
-- InfoInstant
C_Item.GetItemInfoInstant = function(id) return id, "x", "y", "", 1, 7, 1 end
GoldForeverRealm = GoldForeverRealm or { t = JETZT, i = {} }
GoldForeverRealm.i[77777] = { 500, 6, 500, 0, 0, 300, 500, 300 }; GoldForeverRealm.t = (GoldForeverRealm.t or JETZT) + 1
local ri = GF.info(77777)
zeige("Realm-Item Klasse: " .. tostring(ri and ri.kl) .. " handelbar: " .. tostring(ri and GF.handelbar(ri)))
-- Halten mit Verlauf
local id = 5003
GoldForeverDB.posVerlauf = GoldForeverDB.posVerlauf or {}
local v = {}
for k = 0, 40 do v[#v + 1] = { t = JETZT - (40 - k) * 3600, p = 800 + k * 3 } end
GoldForeverDB.posVerlauf[id] = v
local kurs = GF.kursVerlauf(id)
zeige("Kurs Punkte " .. #kurs.pts .. " Trend " .. kurs.trend .. " %")
zeige("Wann: " .. GF.haltenWann({ id = id, ziel = 1150 }, kurs) .. " | nah: " .. GF.haltenWann({ id = id, ziel = 805 }, kurs))
GF.aktualisieren()
local s = GoldForeverFenster.ansichten.standard.spaeter
for _, z in ipairs(s.karten) do if z:IsShown() and z.itemId == id then zeige("Karte: " .. z.zeile2._text:gsub("|c%x+", ""):gsub("|r", "") .. " | Kurs sichtbar " .. tostring(z.kurs._shown) .. " " .. z.kurs.txt._text:gsub("|c%x+", ""):gsub("|r", "")) end end
-- Snipe-Position sofort einstellen
table.insert(GoldForeverDB.bilanz.buch, { t = JETZT - 600, art = "kauf", id = 765, n = 10, betrag = -8000, v = true, ziel = 1500, char = "Dolche", sn = true })
ANZAHL[765] = 10
GF.live[765] = { t = JETZT, p = 1000, st = { { p = 1000, q = 5 } } }
JETZT = JETZT + 1
for _, p in ipairs(GF.positionen()) do if p.id == 765 then local pl = GF.verkaufsPlan(p); zeige("Snipe-Plan: " .. pl.art .. " – " .. pl.lang) end end
zeige("Linien erzeugt: " .. tostring(LINES))
