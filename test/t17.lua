dofile("/home/claude/test/t16.lua")
local GF = GoldForever
local function zeigeTT(id, titel)
  TT = {}; TTF(GameTooltip, { id = id })
  zeige("== " .. titel)
  for _, l in ipairs(TT) do zeige("  " .. l:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|TInterface\\MoneyFrame\\UI%-(%a)%a+Icon.-|t", function(c) return ({ G = "g", S = "s", C = "c" })[c] end):gsub("|T.-|t", "¤")) end
end
zeigeTT(5003, "Position Halten")
zeigeTT(765, "Position Snipe")
zeigeTT(2453, "Kein Einkauf")
IsShiftKeyDown = function() return true end
zeigeTT(5003, "Halten mit Shift")
IsShiftKeyDown = function() return false end
