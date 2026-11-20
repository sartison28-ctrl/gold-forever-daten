dofile("/home/claude/test/t8.lua")
local GF = GoldForever
GoldForeverRealm.i[8800] = { 7000, 6, 7000, 0, 0, 40, 7000, 30 }; GoldForeverRealm.t = GoldForeverRealm.t + 1
NAMEN[8800] = "Cuergos Schatzkarte"
local alt = C_Item.GetItemInfo
C_Item.GetItemInfo = function(id) if tonumber(id) == 8800 then return "Cuergos Schatzkarte", "|Hitem:8800|h", 1, 1, 1, "x", "y", 200, "", 0, 0, 0 end return alt(id) end
GF.live[8800] = { t = JETZT - 30, p = 4900, st = { { p = 4900, q = 4 }, { p = 10000, q = 3 }, { p = 10500, q = 5 } }, rohstoff = true }
local T = GF.treppe(8800, 7000, 5600, 40, 1e9)
zeige("Treppe: " .. T.n .. "x bis " .. T.max .. " neu " .. T.neu .. " gewinn " .. T.gewinn .. " naechster " .. tostring(T.naechster))
assert(T.n == 4 and T.neu == 9100)
GF.planNeu(); local P = GF.budgetPlan()
for _, d in ipairs(P.deals) do if d.id == 8800 then zeige("Plan: " .. d.menge .. "x bis " .. d.maxKauf .. " ziel " .. d.ziel .. " gewinn " .. d.gewinn) end end
zeige("Grund 8800: " .. tostring(P.grund[8800]))
-- Sniper
GF.sniper.an = true; GF.sniper.treffer = nil; GF.sniper.suche = 8800; GF.sniperErgebnis(8800)
local t = GF.sniper.treffer; zeige("Sniper: " .. tostring(t and (t.n .. "x neu " .. t.neu .. " gewinn " .. t.gewinn)))
GoldForeverSniperKnopf._scripts.OnClick(GoldForeverSniperKnopf, "RightButton")
local L = GoldForeverDB.sniper.log; zeige("Log: " .. #L .. " letzter " .. L[#L].aus)
zeige("Ende 2.57.1 ok")
