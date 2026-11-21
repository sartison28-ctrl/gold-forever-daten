dofile("/home/claude/test/t11.lua")
local GF = GoldForever
local S = GF.sniper
-- 1) Nein-Merker: Preis-Grund -> gleicher Preis wird nicht erneut gesucht, billigerer schon
S.an = true; S.modus = "alle"; S.hits = {}; S.skip = {}; S.nein = {}
GF.live[5631] = { t = JETZT, p = 59, st = { { p = 59, q = 50 }, { p = 60, q = 50 } } }
S.suche = 5631; GF.sniperErgebnis(5631)
zeige("Nein-Merker: " .. tostring(S.nein[5631] and S.nein[5631].p) .. " Grund " .. tostring(S.letzterGrund))
-- 2) Bestaetigen: blau ohne Sperre, orange mit Sperre
KAEUFE = {}
C_AuctionHouse.StartCommoditiesPurchase = function(id, n) KAEUFE[#KAEUFE + 1] = "start" end
C_AuctionHouse.ConfirmCommoditiesPurchase = function(id, n) KAEUFE[#KAEUFE + 1] = "ok" end
for _, rk in ipairs({ "ok", "risiko" }) do
  KAEUFE = {}; GF.kaufLauf = nil
  S.treffer = { id = 5631, n = 5, max = 40, neu = 69, gewinn = 100, kosten = 200, R = 60, Rv = 60, abw = 30, t = time(), risiko = rk }
  GF.kaufStarten(5631, 5, 40); GF.kaufPreisDa(40, 200)
  GoldForeverSniperKnopf._scripts.OnClick(GoldForeverSniperKnopf, "LeftButton")
  zeige(rk .. " sofort bestätigt: " .. tostring(KAEUFE[#KAEUFE] == "ok"))
end
-- 3) zu teuer -> zu spaet
GF.kaufLauf = nil
S.treffer = { id = 5631, n = 5, max = 40, neu = 69, gewinn = 100, kosten = 200, R = 60, t = time(), risiko = "ok" }
GF.kaufStarten(5631, 5, 40); GF.kaufPreisDa(55, 275)
zeige("Preis gestiegen -> log " .. GoldForeverDB.sniper.log[#GoldForeverDB.sniper.log].aus .. " zuspaet " .. tostring(S.zuspaet and S.zuspaet.name))
-- 4) Stapel-Auktion: ganzer Stapel, Betrag = Rohwert
GoldForeverDB.einzelItem = GoldForeverDB.einzelItem or {}; GoldForeverDB.einzelItem[5631] = true
S.hits = {}; S.treffer = nil; GF.kaufLauf = nil; S.sperreBis = nil
GF.live[5631] = { t = JETZT, p = 30, einzel = true, st = { { p = 30, q = 40, a = 201, roh = 1200 }, { p = 31, q = 1, a = 202, roh = 31 }, { p = 70, q = 1, a = 203, roh = 70 } } }
local t = GF.sniperBewerten(5631)
zeige("Stapel-Treffer n=" .. tostring(t and t.n) .. " grund " .. tostring(S.letzterGrund))
BIDS = {}
C_AuctionHouse.PlaceBid = function(a, p) BIDS[#BIDS + 1] = a .. "@" .. p end
if t then
  S.treffer = t
  GoldForeverSniperKnopf._scripts.OnClick(GoldForeverSniperKnopf, "LeftButton")
  GoldForeverSniperKnopf._scripts.OnClick(GoldForeverSniperKnopf, "LeftButton")
end
zeige("Gebote: " .. table.concat(BIDS, ", ") .. " offen " .. tostring(S.treffer ~= nil))
-- 5) heiß
GoldForeverDB.sniper.log[#GoldForeverDB.sniper.log + 1] = { t = time(), id = 4242, aus = "gekauft" }
S.heiss = nil
zeige("heiß 4242: " .. tostring(GF.sniperHeiss(4242)) .. " 1: " .. tostring(GF.sniperHeiss(1)))
GF.sniperWarum()
zeige("Ende 2.65 ok")
