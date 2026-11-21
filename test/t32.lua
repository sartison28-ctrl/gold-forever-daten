dofile("/home/claude/test/t29.lua")
local GF = GoldForever
local S = GF.sniper
AuctionHouseFrame.CommoditiesBuyFrame = false; AuctionHouseFrame.ItemBuyFrame = false
AuctionHouseFrame.SearchBar = { SearchBox = { GetText = function() return "" end } }
S.modus = "sicher"; S.an = true; S.treffer = nil; S.suche = nil
C_AuctionHouse.IsThrottledMessageSystemReady = function() return true end
-- haengender Kauf ohne Treffer, 10 s alt -> wird aufgeloest
GF.kaufLauf = { id = 2453, n = 5, t = time() - 10 }
GF.sniperSchritt()
zeige("alter Kauf aufgelöst: " .. tostring(GF.kaufLauf == nil))
-- Fokus-Item gewaehlt, Sicher-Modus: Durchsuche muss drankommen
GoldForeverDB.sniper.fokusEins = 2453; GoldForeverDB.sniper.fokusAus = nil
BROWSE = 0; SUCHEN = {}
C_AuctionHouse.SendBrowseQuery = function() BROWSE = BROWSE + 1 end
C_AuctionHouse.SendSearchQuery = function(k) SUCHEN[#SUCHEN + 1] = k.itemID end
C_AuctionHouse.MakeItemKey = function(id) return { itemID = id } end
GT = 9000; GetTime = function() return GT end
S.fokusT = 0; S.browseLaeuft = false; S.queue = {}
GF.sniperSchritt()          -- Fokus-Suche
S.suche = nil; GT = GT + 0.6
GF.sniperSchritt()          -- jetzt Durchsuche, nicht wieder Fokus
zeige("dbg fz " .. tostring(S.fokusWarZuletzt) .. " fT " .. tostring(S.fokusT) .. " suche " .. tostring(S.suche) .. " fk " .. table.concat(GF.sniperFokus(), ","))
S.suche = nil; GT = GT + 0.6; GF.sniperSchritt()
zeige("Fokus-Suchen " .. #SUCHEN .. " Durchsuche " .. BROWSE .. " Zyklus " .. tostring(S.zyklus))
-- Suchtext im AH-Suchfeld
AuctionHouseFrame.SearchBar = { SearchBox = { GetText = function() return "Magiestoff" end } }
S.suche = nil; GF.sniperSchritt(); GF.sniperZeigen()
zeige("Grund: " .. tostring(S.pauseGrund))
-- Menue: Fokus aus
local F = GoldForeverSniper
F.pfeil._scripts.OnClick(F.pfeil)
F.wahl.zeilen[1]._scripts.OnClick(F.wahl.zeilen[1])
zeige("Fokus aus: " .. tostring(GoldForeverDB.sniper.fokusAus) .. " eins " .. tostring(GoldForeverDB.sniper.fokusEins) .. " Zeile1 " .. tostring(F.wahl.zeilen[1].fs._text))
zeige("Ende 2.73.2 ok")
