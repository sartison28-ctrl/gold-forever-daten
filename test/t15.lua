dofile("/home/claude/test/t14.lua")
local GF = GoldForever
-- Sniper: AH zu und auf
SNS2 = 0
C_AuctionHouse.SendBrowseQuery = function() SNS2 = SNS2 + 1 end
C_Timer.After = function(_, f) end -- Timer nicht sofort
GF.sniper.an = false; GF.sniper.laeuft = false
fire("AUCTION_HOUSE_SHOW"); GF.sniperUmschalten(true)
local a = SNS2
fire("AUCTION_HOUSE_CLOSED")
GF.sniper.laeuft = false -- Tick endet, wenn AH zu (naechster Tick sieht GF.ah = nil)
fire("AUCTION_HOUSE_SHOW")
zeige("Sniper nach Wiederöffnen: an " .. tostring(GF.sniper.an) .. " läuft " .. tostring(GF.sniper.laeuft) .. " Anfragen " .. a .. " -> " .. SNS2)
assert(SNS2 > a)
-- Baganator
REG = nil
Baganator = { API = { RegisterCornerWidget = function(label, id, upd, init, pos) REG = { upd = upd, init = init, pos = pos } end, RequestItemButtonsRefresh = function() REFR = (REFR or 0) + 1 end } }
GF.baganatorAnmelden()
local t = REG.init({ CreateTexture = function() return CreateFrame("Frame"):CreateTexture() end })
zeige("Baganator registriert: " .. tostring(REG ~= nil) .. " Ecke " .. REG.pos.corner .. " Ergebnis Golderz: " .. tostring(REG.upd(t, { itemID = 9100 })) .. " leer: " .. tostring(REG.upd(t, {})))
-- Wecker: Swarley hat 20 Golderz, ziel 999, Markt?
GF.live[9100] = { t = JETZT, p = 1200, st = { { p = 1200, q = 50 } } }
GoldForeverRealm.i[9100] = { 1100, 6, 1100, 0, 0, 500, 1100, 300 }; GoldForeverRealm.t = GoldForeverRealm.t + 1
JETZT = JETZT + 2; GF.positionen()
GoldForeverDB.wecker = {}
GF.weckerCheck()
zeige("Wecker: " .. tostring(GoldForeverDB.wecker["Ser Swarley"] and GoldForeverDB.wecker["Ser Swarley"].sig))
zeige("Ende 2.60 ok")
