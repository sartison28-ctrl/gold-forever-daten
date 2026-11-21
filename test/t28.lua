dofile("/home/claude/test/t27.lua")
local GF = GoldForever
local S = GF.sniper
local B = GoldForeverSniperKnopf
KAEUFE = {}
C_AuctionHouse.StartCommoditiesPurchase = function(id, n) KAEUFE[#KAEUFE + 1] = "start" end
C_AuctionHouse.ConfirmCommoditiesPurchase = function(id, n) KAEUFE[#KAEUFE + 1] = "ok" end
C_AuctionHouse.CancelCommoditiesPurchase = function() KAEUFE[#KAEUFE + 1] = "abbruch" end
-- 1) Sperre 0,1 s im Fokus
S.modus = "fokus"; S.an = true; GF.kaufLauf = nil; S.sperreBis = nil
S.treffer = { id = 5631, n = 50, max = 280, neu = 423, gewinn = 6000, kosten = 14000, R = 420, abw = 30, t = time(), risiko = "sicher", zeigGT = GT }
GT = GT + 0.12; B._scripts.OnClick(B, "LeftButton", true)
zeige("Fokus 0,12 s: " .. table.concat(KAEUFE, ","))
-- 2) teurer, lohnt noch: 50x, Netto 401.85, max 280 -> Grenze 340
GF.kaufPreisDa(300, 15000)
zeige("teurer 300: kaufLauf " .. tostring(GF.kaufLauf ~= nil) .. " gewinn " .. tostring(S.treffer and S.treffer.gewinn) .. " zs " .. tostring(S.treffer and S.treffer.zs))
GT = GT + 0.5; B._scripts.OnClick(B, "LeftButton", true)
zeige("bestätigt: " .. table.concat(KAEUFE, ","))
-- 3) teurer, lohnt nicht
KAEUFE = {}; GF.kaufLauf = nil; S.sperreBis = nil
S.treffer = { id = 5631, n = 50, max = 280, neu = 423, gewinn = 6000, kosten = 14000, R = 420, abw = 30, t = time(), risiko = "sicher", zeigGT = GT - 1 }
B._scripts.OnClick(B, "LeftButton", true); GF.kaufPreisDa(380, 19000)
zeige("teurer 380: " .. table.concat(KAEUFE, ",") .. " treffer " .. tostring(S.treffer ~= nil))
-- 4) gebremst -> Timer
C_AuctionHouse.IsThrottledMessageSystemReady = function() return false end
S.treffer = nil; GF.kaufLauf = nil; S.suche = nil
local d0 = GF.sniperDiag().gebremst or 0
GF.sniperSchritt()
zeige("gebremst gezählt: " .. tostring((GF.sniperDiag().gebremst or 0) > d0))
C_AuctionHouse.IsThrottledMessageSystemReady = function() return true end
-- 5) Fokus-Timeout 0,6 s
S.suche = 6000; S.sucheGT = GT; S.fokusT = 0
GT = GT + 0.3; SUCHEN = {}; GF.sniperSchritt(); zeige("0,3 s warten: " .. #SUCHEN)
GT = GT + 0.4; GF.sniperSchritt(); zeige("0,7 s neue Suche: " .. #SUCHEN .. " ohne Antwort " .. tostring(GF.sniperDiag().fokusOhneAntwort))
zeige("Ende 2.70 ok")
