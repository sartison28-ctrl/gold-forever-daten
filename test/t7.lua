dofile("/home/claude/test/t6.lua")
local GF = GoldForever
-- b) eingebrochener Markt
GoldForeverRealm.i[13546] = { 8350, 6, 300, -97, 5, 331, 388, 510 }; GoldForeverRealm.t = GoldForeverRealm.t + 1
local R, q, _, e = GF.referenz(13546, { id = 13546 }); zeige("13546 üblich " .. R .. " eingebrochen " .. tostring(e)); assert(R == 300 and e)
-- a) 30/Tag, 30 % unter üblich -> kaufen; 15 % -> nicht
GoldForeverRealm.i[7790] = { 1000, 6, 1000, 0, 0, 30, 1000, 50 }; GoldForeverRealm.t = GoldForeverRealm.t + 1
local alt = C_Item.GetItemInfo
C_Item.GetItemInfo = function(id) if tonumber(id) == 7790 then return "Hopfen", "|Hitem:7790|h", 1, 1, 1, "x", "y", 200, "", 0, 0, 7 end return alt(id) end
GF.live[7790] = { t = JETZT - 60, p = 700, st = { { p = 700, q = 50 } } }
local e1 = GF.empfehlung(7790, GF.info(7790), true); zeige("Hopfen -30 %: " .. e1.text); assert(e1.art == "kauf")
GF.live[7790] = { t = JETZT - 60, p = 850, st = { { p = 850, q = 50 } } }
local e2 = GF.empfehlung(7790, GF.info(7790), true); zeige("Hopfen -15 %: " .. e2.text); assert(e2.art ~= "kauf")
local liste, gr = GF.kaufDiagnose(); for _, g in ipairs(gr) do zeige("  " .. g.g .. " " .. g.n) end
zeige("Ende 2.56.1 ok")
for _, x in ipairs((GF.kaufDiagnose())) do if x.gruppe == "sonstiges" then zeige("  S: " .. x.n .. ": " .. x.grund) end end
