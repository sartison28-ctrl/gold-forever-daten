dofile("/home/claude/test/t26.lua")
local GF = GoldForever
local S = GF.sniper
local F = GoldForeverSniper
S.an = false
F.pfeil._scripts.OnClick(F.pfeil)
local W = F.wahl
local n = 0; for _, z in ipairs(W.zeilen) do if z:IsShown() then n = n + 1 end end
zeige("Auswahl offen: " .. tostring(W:IsShown()) .. " Zeilen " .. n .. " erste: " .. tostring(W.zeilen[1].fs._text) .. " zweite: " .. tostring(W.zeilen[2] and W.zeilen[2].fs._text))
W.zeilen[3]._scripts.OnClick(W.zeilen[3])
zeige("gewählt: " .. tostring(GoldForeverDB.sniper.fokusEins) .. " Modus " .. tostring(S.modus) .. " an " .. tostring(S.an) .. " Liste " .. table.concat(GF.sniperFokus(), ","))
SUCHEN = {}; S.suche = nil; S.fokusT = 0; S.treffer = nil; GF.kaufLauf = nil
for k = 1, 3 do GT = GT + 0.3; S.suche = nil; S.fokusGeplant = nil; GF.sniperSchritt() end
zeige("Suchen: " .. table.concat(SUCHEN, ","))
F.fokusK._scripts.OnClick(F.fokusK, "RightButton")
zeige("Rechtsklick öffnet Auswahl: " .. tostring(W:IsShown()))
W.zeilen[1]._scripts.OnClick(W.zeilen[1])
zeige("alle: " .. tostring(GoldForeverDB.sniper.fokusEins) .. " Liste " .. table.concat(GF.sniperFokus(), ","))
zeige("Ende 2.69 ok")
