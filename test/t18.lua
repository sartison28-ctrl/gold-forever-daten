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
-- 2.62.2 Befund 64
local tt = { id = 5631, n = 5, max = 40, neu = 69, gewinn = 100, R = 60, t = JETZT }
GF.sniper.ausstehend = { t = tt, kk = { n = 5, unit = 40, total = 200 }, name = "Wuttrank", zeit = time() }
GF.sniperKaufErgebnis(false)
local lg = GoldForeverDB.sniper.log[#GoldForeverDB.sniper.log]
zeige("Fehlkauf: log=" .. lg.aus .. " zuletzt=" .. tostring(GF.sniper.zuletzt and GF.sniper.zuletzt.id) .. " zuspaet=" .. tostring(GF.sniper.zuspaet and GF.sniper.zuspaet.name))
local tt2 = { id = 5631, n = 5, max = 40, neu = 69, gewinn = 100, R = 60, t = JETZT }
GF.sniper.zuletzt = nil
GF.sniper.ausstehend = { t = tt2, kk = { n = 5, unit = 40, total = 200 }, name = "Wuttrank", zeit = time() }
GF.sniperKaufErgebnis(true)
zeige("Kauf ok: log=" .. GoldForeverDB.sniper.log[#GoldForeverDB.sniper.log].aus .. " zuletzt=" .. tostring(GF.sniper.zuletzt and GF.sniper.zuletzt.n))
-- 2.64 grün = 1 Tastendruck, Modus Sicher
KAEUFE = {}
C_AuctionHouse.StartCommoditiesPurchase = function(id, n) KAEUFE[#KAEUFE + 1] = { "start", id, n } end
C_AuctionHouse.ConfirmCommoditiesPurchase = function(id, n) KAEUFE[#KAEUFE + 1] = { "ok", id, n } end
GF.kaufLauf = nil
local tg = { id = 5631, n = 5, max = 40, neu = 69, gewinn = 100, kosten = 200, R = 60, Rv = 60, abw = 30, t = time(), risiko = "sicher" }
GF.sniper.treffer = tg; GF.kaufStarten(5631, 5, 40); GF.kaufPreisDa(40, 200)
GoldForeverSniperKnopf._scripts.OnClick(GoldForeverSniperKnopf, "LeftButton")
zeige("Grün 1 Druck: " .. tostring(KAEUFE[#KAEUFE] and KAEUFE[#KAEUFE][1]))
GF.sniper.modus = "sicher"; GF.sniper.treffer = nil; GF.kaufLauf = nil
GF.live[5631] = { t = JETZT, p = 40, st = { { p = 40, q = 50 }, { p = 70, q = 50 } } }
GoldForeverDB.einzelItem[5631] = nil; GF.sniper.hits = {}
GF.sniper.suche = 5631; GF.sniperErgebnis(5631)
zeige("Modus Sicher, oranger Treffer: " .. tostring(GF.sniper.treffer))
