dofile("/home/claude/test/t10.lua")
local GF = GoldForever
local S = GF.sniper
local function lauf(preis)
  RES[1].minPrice = preis
  S.queue = {}; S.browseLaeuft = true; S.bIdx = 0; S.geprueft[7777] = time()
  fire("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
  local drin = false; for _, x in ipairs(S.queue) do if x == 7777 then drin = true end end
  return drin
end
S.nein = { [7777] = { p = 600, t = time() } }
zeige("gleicher Preis, Nein-Merker: in Queue " .. tostring(lauf(600)) .. " gespart " .. tostring(GF.sniperDiag().gespart))
zeige("billiger (550), trotz 60-s-Sperre: in Queue " .. tostring(lauf(550)))
S.nein = {}
zeige("ohne Merker, 60-s-Sperre: in Queue " .. tostring(lauf(600)))
zeige("Ende 2.65 Browse ok")
