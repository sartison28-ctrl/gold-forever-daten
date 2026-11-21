dofile("/home/claude/test/t25.lua")
local GF = GoldForever
local S = GF.sniper
S.treffer = nil; GF.kaufLauf = nil; S.suche = nil; S.an = false
GF.sniperUmschalten(nil, "fokus")
zeige("Modus " .. tostring(S.modus) .. " an " .. tostring(S.an) .. " Knopf " .. tostring(GoldForeverSniper and true))
SUCHEN = {}; BROWSE = 0
S.suche = nil; S.fokusT = 0; S.fokusI = 0; S.queue = { 7777 }
GT = GT + 5; GF.sniperSchritt()
zeige("Fokus-Modus sucht " .. tostring(SUCHEN[#SUCHEN]) .. " Browse " .. BROWSE .. " Queue unberührt " .. tostring(S.queue[1]))
GF.live[5631] = { t = JETZT, p = 59, st = { { p = 59, q = 50 } } }
GF.sniperErgebnis(SUCHEN[#SUCHEN])
GT = GT + 0.05; local n0 = #SUCHEN; GF.sniperSchritt()
zeige("nach 0,05 s neue Suche? " .. tostring(#SUCHEN > n0))
GT = GT + 0.2; S.fokusGeplant = nil; GF.sniperSchritt()
zeige("nach 0,25 s: " .. tostring(SUCHEN[#SUCHEN]) .. " (" .. #SUCHEN .. " Suchen)")
GF.sniperZeigen()
zeige("Leiste: " .. tostring(GoldForeverSniper and GoldForeverSniper.info and GoldForeverSniper.info._text or ""):gsub("|c%x+", ""):gsub("|r", ""))
zeige("Ende 2.68 ok")
