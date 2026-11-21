dofile("/home/claude/test/t11.lua")
local GF = GoldForever
GF.sniper.hits = {}; GF.sniper.skip = {}
GF.live[5631] = { t = JETZT, p = 40, st = { { p = 40, q = 50 }, { p = 70, q = 50 } } }
local t = GF.sniperBewerten(5631)
zeige("Wuttrank Risiko: " .. tostring(t and t.risiko) .. " " .. tostring(t and t.risikoGrund))
GF.sniper.treffer = t; GF.sniperZeigen()
zeige("Knopf: " .. GoldForeverSniperKnopf.t._text:gsub("|c%x+", ""):gsub("|r", ""):gsub("|T.-|t", "¤"))
-- Einzel-Auktion
GoldForeverDB.einzelItem = GoldForeverDB.einzelItem or {}; GoldForeverDB.einzelItem[5631] = true
GF.sniper.hits = {}
GF.live[5631] = { t = JETZT, p = 40, st = { { p = 30, q = 1, a = 111 }, { p = 31, q = 1, a = 112 }, { p = 32, q = 1, a = 114 }, { p = 33, q = 1, a = 115 }, { p = 34, q = 1, a = 116 }, { p = 35, q = 1, a = 117 }, { p = 36, q = 1, a = 118 }, { p = 37, q = 1, a = 119 }, { p = 38, q = 1, a = 120 }, { p = 39, q = 1, a = 121 }, { p = 70, q = 1, a = 113 } } }
local t2 = GF.sniperBewerten(5631)
zeige("Einzel: n=" .. tostring(t2 and t2.n) .. " risiko " .. tostring(t2 and t2.risiko))
BIDS = {}
C_AuctionHouse.PlaceBid = function(a, p) BIDS[#BIDS + 1] = a .. "@" .. p end
GF.sniper.treffer = t2; GF.sniperZeigen()
GoldForeverSniperKnopf._scripts.OnClick(GoldForeverSniperKnopf, "LeftButton")
GoldForeverSniperKnopf._scripts.OnClick(GoldForeverSniperKnopf, "LeftButton")
zeige("Gebote: " .. table.concat(BIDS, ", ") .. " Treffer offen: " .. tostring(GF.sniper.treffer ~= nil))
-- kein Budget mehr
local P = GF.budgetPlan(); zeige("Plan-Budget = Gold: " .. tostring(P.budget == GetMoney()))
local D2 = GF.sniperDiag(); local f = D2.faelle[#D2.faelle]; zeige("Grund: " .. tostring(f and f.g) .. " p " .. tostring(f and f.p) .. " gew " .. tostring(f and f.gewinn))
