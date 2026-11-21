dofile("/home/claude/test/t22.lua")
local GF = GoldForever
local S = GF.sniper
local alt = C_Item.GetItemInfo
C_Item.GetItemInfo = function(id) local a, b, c, d, e, f, g, h, i2, j, k, l2, m, n2 = alt(id); if tonumber(id) == 5631 and KISTE then a = KISTE end; return a, b, c, d, e, f, g, h, i2, j, k, l2, m, n2 end
KISTE = "Abgefangene Kiste: Kräuter des Gesellen"
GoldForeverDB.kisten = nil
S.hits = {}; S.rest = {}
GF.live[5631] = { t = JETZT, p = 30, st = { { p = 30, q = 40 }, { p = 60, q = 50 } } }
ANZAHL[5631] = 0
local t = GF.sniperBewerten(5631)
zeige("Kiste, nichts da: n=" .. tostring(t and t.n) .. " " .. tostring(S.letzterGrund))
ANZAHL[5631] = 7; S.hits = {}
t = GF.sniperBewerten(5631)
zeige("Kiste, 7 da: n=" .. tostring(t and t.n) .. " " .. tostring(S.letzterGrund))
ANZAHL[5631] = 100; S.hits = {}; S.letzterGrund = nil
t = GF.sniperBewerten(5631)
zeige("Kiste, 100 da: " .. tostring(t) .. " " .. tostring(S.letzterGrund))
KISTE = nil; GoldForeverDB.kisten = nil; ANZAHL[5631] = 0; S.hits = {}
t = GF.sniperBewerten(5631)
zeige("keine Kiste: n=" .. tostring(t and t.n))
zeige("Ende 2.66.1 ok")
