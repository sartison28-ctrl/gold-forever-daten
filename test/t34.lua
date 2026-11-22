dofile("/home/claude/test/t33.lua")
local GF = GoldForever
local S = GF.sniper
local B = GoldForeverSniperKnopf
KAEUFE = {}
C_AuctionHouse.StartCommoditiesPurchase = function(id, n) KAEUFE[#KAEUFE + 1] = "start" .. n end
C_AuctionHouse.ConfirmCommoditiesPurchase = function(id, n) KAEUFE[#KAEUFE + 1] = "ok" .. n end
GoldForeverDB.sniper.express = true; GoldForeverDB.sniper.fokusEins = 5631; GoldForeverDB.sniper.fokusAus = nil
S.modus = "fokus"; S.an = true; GF.kaufLauf = nil; S.sperreBis = nil; S.ausstehend = nil
-- Leiter: 30x zu 25c (Treffer), danach 50x zu 45c; Verkauf 60c -> netto 57 -> schlechtester Fall 45 <= 57 -> Express
GF.live[5631] = { t = JETZT, p = 25, st = { { p = 25, q = 30 }, { p = 45, q = 50 } } }
S.treffer = { id = 5631, n = 20, max = 25, neu = 60, gewinn = 640, kosten = 500, R = 60, abw = 30, t = time(), risiko = "sicher", zeigGT = GT }
B._scripts.OnClick(B, "LeftButton", true)
zeige("Express (sicher, ohne Sperre): " .. table.concat(KAEUFE, ",") .. " ausstehend " .. tostring(S.ausstehend and S.ausstehend.kk.express))
GF.sniperKaufErgebnis(true)
zeige("Ergebnis ok: " .. tostring(GF.sniperDiag().expressOk))
-- schlechtester Fall mit Verlust -> normaler Ablauf (nur Start)
KAEUFE = {}; GF.kaufLauf = nil; S.sperreBis = nil
GF.live[5631] = { t = JETZT, p = 25, st = { { p = 25, q = 30 }, { p = 70, q = 50 } } }
S.treffer = { id = 5631, n = 20, max = 25, neu = 60, gewinn = 640, kosten = 500, R = 60, abw = 30, t = time(), risiko = "sicher", zeigGT = GT }
B._scripts.OnClick(B, "LeftButton", true)
zeige("Verlustrisiko -> nur Start: " .. table.concat(KAEUFE, ","))
-- ohne Antwort -> nach 5 s abgeschlossen
GF.kaufLauf = nil; S.treffer = nil
S.ausstehend = { t = { id = 5631, n = 20, max = 25, neu = 60, gewinn = 640, kosten = 500 }, kk = { n = 20, unit = 25, express = true }, name = "Magiestoff", zeit = time() - 6 }
GF.sniperSchritt()
zeige("still: " .. tostring(GF.sniperDiag().expressStill) .. " ausstehend weg " .. tostring(S.ausstehend == nil))
-- Alt+Klick
IsAltKeyDown = function() return true end
GF.ah = GF.ah or {}
if HandleModifiedItemClick then HandleModifiedItemClick("|cffffffff|Hitem:8170::::::::|h[Leder]|h|r") end
zeige("Alt-Klick Hook vorhanden: " .. tostring(HandleModifiedItemClick ~= nil) .. " fokusEins " .. tostring(GoldForeverDB.sniper.fokusEins))
zeige("Ende 2.74 ok")
