dofile("/home/claude/test/t1.lua")
local GF = GoldForever
local i = GF.info(2453); local R = GF.referenz(2453, i)
GF.marktEreignis(2453, math.floor(R * 0.5), 20)
JETZT = JETZT + 60; GF.marktEreignis(2453, math.floor(R * 0.4), 25)
JETZT = JETZT + 60; GF.marktEreignis(2453, R, 30)
local M = GoldForeverDB.markt
zeige("Ereignisse: " .. #M.log .. " art " .. M.log[1].art .. " dauer " .. (M.log[1].bis - M.log[1].von) .. " p " .. M.log[1].p .. " offen " .. tostring(M.offen[2453]))
assert(#M.log == 1 and M.log[1].art == "tief" and M.log[1].bis - M.log[1].von == 60)
