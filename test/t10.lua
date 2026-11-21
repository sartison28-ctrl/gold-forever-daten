dofile("/home/claude/test/t9.lua")
local GF = GoldForever
BROWSE = 0
C_AuctionHouse.SendBrowseQuery = function(q) BROWSE = BROWSE + 1; BQ = q end
RES = {
  { itemKey = { itemID = 7777 }, minPrice = 600, totalQuantity = 20 },   -- Seltenkraut üblich 1000, 300/Tag -> Kandidat
  { itemKey = { itemID = 8800 }, minPrice = 4900, totalQuantity = 4 },  -- Schatzkarte 40/Tag -> kein Sniper
  { itemKey = { itemID = 99999 }, minPrice = 1, totalQuantity = 1 },    -- unbekannt
}
C_AuctionHouse.GetBrowseResults = function() return RES end
C_AuctionHouse.HasFullBrowseResults = function() return true end
GF.sniper.an = false; GF.sniper.treffer = nil; GF.sniper.queue = {}; GF.sniper.suche = nil; GF.sniper.browseLaeuft = false; GF.sniper.laeuft = false; GF.sniper.zyklus = 0
GF.sniperUmschalten(true)
zeige("Browse gesendet: " .. BROWSE .. " Klassen " .. #BQ.itemClassFilters)
fire("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
local q = {}; for _, x in ipairs(GF.sniper.queue) do q[#q + 1] = x end
zeige("Queue: " .. table.concat(q, ",") .. " Kandidaten " .. tostring(GF.sniper.kandidaten))
assert(q[1] == 7777)
for _, x in ipairs(q) do assert(x ~= 8800) end
zeige("Ende 2.58 ok")
