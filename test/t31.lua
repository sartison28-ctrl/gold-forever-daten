dofile("/home/claude/test/t28.lua")
local GF = GoldForever
local S = GF.sniper
local B = GoldForeverSniperKnopf
KAEUFE = {}
C_AuctionHouse.StartCommoditiesPurchase = function(id, n) KAEUFE[#KAEUFE + 1] = "start" .. n end
C_AuctionHouse.ConfirmCommoditiesPurchase = function(id, n) KAEUFE[#KAEUFE + 1] = "ok" .. n end
C_AuctionHouse.CancelCommoditiesPurchase = function() KAEUFE[#KAEUFE + 1] = "abbruch" end
S.modus = "fokus"; S.an = true; GF.kaufLauf = nil; S.sperreBis = nil
S.treffer = { id = 5631, n = 40, max = 280, neu = 423, gewinn = 4800, kosten = 11200, R = 420, abw = 30, t = time(), risiko = "sicher", zeigGT = GT - 1 }
B._scripts.OnClick(B, "LeftButton", true); GF.kaufPreisDa(390, 15600)
zeige("teurer -> " .. tostring(S.treffer and S.treffer.n) .. "× halb " .. tostring(S.treffer and S.treffer.halb) .. " | " .. table.concat(KAEUFE, ","))
GT = GT + 0.2; B._scripts.OnClick(B, "LeftButton", true)
zeige("nächster Druck: " .. table.concat(KAEUFE, ","))
GF.kaufPreisDa(390, 7800)
zeige("wieder teurer -> " .. tostring(S.treffer and S.treffer.n))
GF.kaufPreisDa = GF.kaufPreisDa
-- weg nach Bestaetigen
GF.kaufLauf = nil; S.sperreBis = nil
local t = { id = 5631, n = 20, max = 280, neu = 423, gewinn = 2400, kosten = 5600, R = 420, abw = 30, t = time(), risiko = "sicher" }
S.treffer = nil
S.ausstehend = { t = t, kk = { n = 20, unit = 280, total = 5600 }, name = "Magiestoff", zeit = time() }
GF.sniperKaufErgebnis(false)
zeige("weg -> " .. tostring(S.treffer and S.treffer.n) .. "×")
-- Portion
S.treffer = nil; S.hits = {}; S.rest = {}
GF.live[5631] = { t = JETZT, p = 30, st = { { p = 30, q = 90 }, { p = 60, q = 50 } } }
S.suche = 5631; S.sucheFokus = nil; GF.sniperErgebnis(5631)
zeige("Portion: " .. tostring(S.treffer and S.treffer.n) .. " von " .. tostring(S.treffer and S.treffer.nVoll))
zeige("Ende 2.73 ok")
