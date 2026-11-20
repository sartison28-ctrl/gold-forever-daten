dofile("/home/claude/test/t4.lua")
local GF = GoldForever
local function ohne(x) return (x or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "¤") end
-- Position Makelloses Leder: gekauft vor 30 Std. zu 320c, jetzt 270 -> 20 % Verlust
NAMEN[6000] = "Makelloses Leder"; GoldForeverData.items[6000] = { "Makelloses Leder", 270, 300, 310, 500, 60 }
GoldForeverRealm.i[6000] = { 320, 7, 300, 0, 0, 900, 320, 2000 }
table.insert(GoldForeverDB.bilanz.buch, { t = JETZT - 30 * 3600, art = "kauf", id = 6000, n = 66, betrag = -66 * 320, v = true, ziel = 340, char = "Dolche" })
ANZAHL[6000] = 66
GF.live[6000] = { t = JETZT - 60, p = 270, st = { { p = 270, q = 200 } } }
-- Verlauf: gestern gleiche Zeit 330, vorgestern 340 -> faellt ueber Tage
GoldForeverDB.posVerlauf = GoldForeverDB.posVerlauf or {}
GoldForeverDB.posVerlauf[6000] = { { t = JETZT - 48 * 3600, p = 340 }, { t = JETZT - 24 * 3600, p = 330 }, { t = JETZT - 3600, p = 280 }, { t = JETZT - 600, p = 270 } }
local function plan() for _, p in ipairs(GF.positionen()) do if p.id == 6000 then return GF.verkaufsPlan(p), p end end end
local orig = GF.imTageshoch
GF.imTageshoch = function() return false, 11, 15 end
local pl = plan(); zeige("Abend: " .. tostring(pl and pl.art) .. " | " .. ohne(pl and pl.kurz) .. " | " .. ohne(pl and pl.lang)); assert(pl.art == "halt")
GF.imTageshoch = function() return true, 11, 0 end
local pl = plan(); zeige("Hoch: " .. tostring(pl and pl.art) .. " | " .. ohne(pl and pl.lang)); assert(pl.stop)
GoldForeverDB.zielGemeldet = {}; GF.zieleCheck(); zeige("gemeldet sofort: " .. tostring(GoldForeverDB.zielGemeldet[6000]))
assert(GoldForeverDB.zielGemeldet[6000] == nil)
GoldForeverDB.bremseSeit[6000] = JETZT - 6000; GF.zieleCheck(); zeige("gemeldet nach 100 Min.: " .. tostring(GoldForeverDB.zielGemeldet[6000]))
-- nur Abendtief ohne Fall über Tage (gestern höher? nein: gestern 275)
GoldForeverDB.posVerlauf[6000] = { { t = JETZT - 24 * 3600, p = 275 }, { t = JETZT - 3600, p = 300 }, { t = JETZT - 1800, p = 285 }, { t = JETZT - 600, p = 270 } }
GoldForeverDB.bremseSeit = {}
local pl = plan(); zeige("ohne Tages-Fall: " .. tostring(pl and pl.art) .. " | " .. ohne(pl and pl.lang))
-- jung (10 Std.)
GoldForeverDB.bilanz.buch[#GoldForeverDB.bilanz.buch].t = JETZT - 10 * 3600
local pl = plan(); zeige("10 Std. alt: " .. tostring(pl and pl.art) .. " | " .. ohne(pl and pl.kurz))
zeige("Ende 2.55.1 ok")
for _, p in ipairs(GoldForever.positionen()) do if p.id == 6000 then zeige("seit vor " .. math.floor((JETZT - p.seit) / 3600) .. " Std.") end end
for _, p in ipairs(GoldForever.positionen()) do if p.id == 6000 then p.seit = JETZT - 10 * 3600; local pl = GoldForever.verkaufsPlan(p); zeige("jung: " .. tostring(pl and pl.art) .. " " .. tostring(pl and pl.kurz)) end end
