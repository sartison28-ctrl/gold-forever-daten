dofile("/home/claude/test/t7.lua")
local GF = GoldForever
-- Mocks fuer Sniper
SetOverrideBindingClick = function(o, p, k, b) BIND = k .. ">" .. b end
ClearOverrideBindings = function() BIND = nil end
InCombatLockdown = function() return false end
PlaySound = function() TON = (TON or 0) + 1 end
C_AuctionHouse.SendSearchQuery = function(key) SNS = (SNS or 0) + 1; LETZTE = key end
C_Timer.After = function(_, f) if not SNTIEF then SNTIEF = true; f(); SNTIEF = nil end end
C_AuctionHouse.MakeItemKey = function(id) return id end
fire("AUCTION_HOUSE_SHOW")
zeige("Sniper-Leiste da: " .. tostring(GoldForeverSniper ~= nil) .. " ah " .. tostring(GF.ah))
SlashCmdList.GOLDFOREVER("sniper")
zeige("an: " .. tostring(GF.sniper.an) .. " Liste " .. #GF.sniper.liste .. " Suchen " .. tostring(SNS))
-- Treffer simulieren: Golderz-artig – Item 2771 Zinnerz? nimm Seltenkraut 7777 (üblich 1000, 300/Tag)
GF.sniper.treffer = nil
GF.sniper.suche = 7777
GF.sniperLeise = true
GF.live[7777] = { t = JETZT, p = 600, st = { { p = 600, q = 20 }, { p = 980, q = 200 } }, rohstoff = true }
GF.sniperLeise = nil
GF.sniperErgebnis(7777)
local t = GF.sniper.treffer
zeige("Treffer: " .. tostring(t and (t.n .. "x bis " .. t.max .. " neu " .. t.neu .. " gewinn " .. t.gewinn)) .. " Ton " .. tostring(TON) .. " Taste " .. tostring(BIND))
zeige("Knopf: " .. tostring(GoldForeverSniperKnopf.t:GetText()))
assert(t and t.n == 20)
KAEUFE = {}
GoldForeverSniperKnopf._scripts.OnClick(GoldForeverSniperKnopf, "LeftButton")
zeige("nach Klick 1: " .. tostring(KAEUFE[#KAEUFE] and KAEUFE[#KAEUFE][1]) .. " | " .. tostring(GoldForeverSniperKnopf.t:GetText()))
fire("COMMODITY_PRICE_UPDATED", 600, 12000)
zeige("Preis da: " .. tostring(GoldForeverSniperKnopf.t:GetText()))
GoldForeverSniperKnopf._scripts.OnClick(GoldForeverSniperKnopf, "LeftButton")
zeige("nach Klick 2: " .. tostring(KAEUFE[#KAEUFE] and KAEUFE[#KAEUFE][1]) .. " Treffer weg " .. tostring(GF.sniper.treffer == nil))
-- zu teuer: Preis höher als max -> Abbruch
GF.sniper.suche = 7777; GF.sniperErgebnis(7777)
GoldForeverSniperKnopf._scripts.OnClick(GoldForeverSniperKnopf, "LeftButton")
fire("COMMODITY_PRICE_UPDATED", 900, 18000)
zeige("teurer: " .. tostring(KAEUFE[#KAEUFE] and KAEUFE[#KAEUFE][1]))
SlashCmdList.GOLDFOREVER("sniper aus")
zeige("Ende 2.57 ok")
