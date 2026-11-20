dofile("/home/claude/test/t5.lua")
local GF = GoldForever
-- Realm-Item ohne Datendatei: 7777 "Seltenkraut", üblich 1000c, 300/Tag
GoldForeverRealm.i[7777] = { 1000, 6, 1000, 0, 0, 300, 1000, 500 }
GoldForeverRealm.i[7778] = { 1000, 6, 1000, 0, 0, 5, 1000, 500 } -- zu wenig Umsatz
GoldForeverRealm.t = GoldForeverRealm.t + 1 -- Cache neu
NAMEN[7777] = "Seltenkraut"
local alt = C_Item.GetItemInfo
C_Item.GetItemInfo = function(id) if tonumber(id) == 7777 then return "Seltenkraut", "|Hitem:7777|h", 1, 1, 1, "x", "y", 200, "", 0, 5, 7 end return alt(id) end
local ids = GF.alleIds(); zeige("alleIds 7777: " .. tostring(ids[7777]) .. " 7778: " .. tostring(ids[7778]))
assert(ids[7777] == "realm" and not ids[7778])
assert(not GF.alleIds(true)[7777]) -- ohne Live-Preis nicht
GF.live[7777] = { t = JETZT - 60, p = 820, st = { { p = 820, q = 100 } } }
local i = GF.info(7777); zeige("info: " .. tostring(i.n) .. " u " .. tostring(i.u) .. " nurRealm " .. tostring(i.nurRealm))
local e = GF.empfehlung(7777, i, true); zeige("18 %: " .. e.text); assert(e.art ~= "kauf")
GF.live[7777] = { t = JETZT - 60, p = 750, st = { { p = 750, q = 100 } } }
GF.planNeu()
local e = GF.empfehlung(7777, GF.info(7777), true); zeige("25 %: " .. e.text); assert(e.art == "kauf")
local P = GF.budgetPlan(); local drin = false; for _, d in ipairs(P.deals) do if d.id == 7777 then drin = true end end
zeige("im Plan: " .. tostring(drin) .. " / Grund " .. tostring(P.grund[7777]))
zeige("Ende 2.56 ok")
