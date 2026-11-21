dofile("/home/claude/test/t24.lua")
local GF = GoldForever
local S = GF.sniper
local alt = C_Item.GetItemInfo
C_Item.GetItemInfo = function(id) local a, b, c, d, e, f, g, h, i2, j, k, l2, m, n2 = alt(id); if tonumber(id) == 5631 then a = "Magiestoff" end; return a, b, c, d, e, f, g, h, i2, j, k, l2, m, n2 end
GoldForeverDB.sniper.fokusAus = nil
local fk = GF.sniperFokus(true)
zeige("Fokus-Liste: " .. table.concat(fk, ","))
-- Ablauf: Fokus-Suche kommt vor der Durchsuche
GT = 5000; GetTime = function() return GT end
SUCHEN = {}
C_AuctionHouse.SendSearchQuery = function(key) SUCHEN[#SUCHEN + 1] = key.itemID end
C_AuctionHouse.MakeItemKey = function(id) return { itemID = id } end
S.an = true; S.treffer = nil; S.suche = nil; S.queue = {}; GF.kaufLauf = nil; S.fokusT = 0; S.skip = {}
GF.sniperSchritt()
zeige("1. Schritt sucht: " .. tostring(SUCHEN[1]) .. " fokus " .. tostring(S.sucheFokus))
-- Ergebnis ohne Treffer -> nicht in Diagnose
local D2 = GF.sniperDiag(); local vor = D2.kand
GF.live[5631] = { t = JETZT, p = 59, st = { { p = 59, q = 50 } } }
GF.sniperErgebnis(5631)
zeige("Diagnose unverändert: " .. tostring(D2.kand == vor) .. " Fokus-Suchen " .. tostring(D2.fokusN))
-- naechster Schritt innerhalb 0,5 s -> kein Fokus
GT = GT + 0.2; SUCHEN = {}; GF.sniperSchritt()
zeige("nach 0,2 s Fokus? " .. tostring(SUCHEN[1] == 5631))
-- Treffer per Fokus
GT = GT + 0.5; S.suche = nil; SUCHEN = {}; S.hits = {}; S.fokusI = 0; GF.sniperSchritt()
GF.live[5631] = { t = JETZT, p = 30, st = { { p = 30, q = 30 }, { p = 60, q = 50 } } }
GF.sniperErgebnis(5631)
zeige("Fokus-Treffer: " .. tostring(S.treffer and S.treffer.n) .. " fokus " .. tostring(S.treffer and S.treffer.fokus))
-- Mausrad
KAEUFE = {}
C_AuctionHouse.StartCommoditiesPurchase = function(id, n) KAEUFE[#KAEUFE + 1] = "start" end
C_AuctionHouse.ConfirmCommoditiesPurchase = function(id, n) KAEUFE[#KAEUFE + 1] = "ok" end
S.treffer.risiko = "sicher"; S.treffer.zeigGT = GT - 1; S.sperreBis = nil
local B = GoldForeverSniperKnopf
B:Show()
local rad = B._scripts.OnMouseWheel
rad(B, -1); GF.kaufPreisDa(30, 900); rad(B, -1)
zeige("Mausrad: " .. table.concat(KAEUFE, ","))
GF.sniperWarum()
zeige("Ende 2.67 ok")
