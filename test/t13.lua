dofile("/home/claude/test/t12.lua")
local GF = GoldForever
GoldForeverRealm.i[248698] = { 246, 6, 103, -73, 1, 894, 197, 445 }; GoldForeverRealm.t = GoldForeverRealm.t + 1
C_AuctionHouse.GetItemCommodityStatus = nil
local RES = { { buyoutAmount = 3785, quantity = 36, containsOwnerItem = false }, { buyoutAmount = 4400, quantity = 11, containsOwnerItem = true }, { buyoutAmount = 150, quantity = 1 } }
C_AuctionHouse.GetNumItemSearchResults = function() return #RES end
C_AuctionHouse.GetItemSearchResultInfo = function(_, k) return RES[k] end
fire("ITEM_SEARCH_RESULTS_UPDATED", { itemID = 248698 })
local l = GF.live[248698]; zeige("Kiste live p " .. tostring(l and l.p) .. " eigen " .. tostring(l and l.eigen) .. " st1 " .. tostring(l and l.st[1] and l.st[1].p))
assert(l.p == 150)
zeige("Massenware? " .. tostring(GF.istMassenware(248698, 4400, 11)))
zeige("Ende 2.58.4 ok")
