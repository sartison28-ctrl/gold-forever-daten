dofile("/home/claude/test/t31.lua")
local GF = GoldForever
local S = GF.sniper
if AuctionHouseFrame then AuctionHouseFrame.SearchBar = { SearchBox = { GetText = function() return "" end } } end
GoldForeverDB.sniper.halbieren = nil
GoldForeverDB.sniper.fokusAus = nil; GoldForeverDB.sniper.fokusEins = 5631
S.modus = "fokus"; S.an = true; S.treffer = nil; GF.kaufLauf = nil; S.sperreBis = nil
-- viele nicht gekaufte Treffer -> trotzdem keine Hektik-Sperre im Fokus
S.hits = { [5631] = { time(), time(), time(), time() } }
GF.live[5631] = { t = JETZT, p = 30, st = { { p = 30, q = 30 }, { p = 60, q = 50 } } }
S.suche = 5631; S.sucheFokus = true; GF.sniperErgebnis(5631)
zeige("Treffer trotz vieler Treffer: " .. tostring(S.treffer and S.treffer.n) .. " Grund " .. tostring(S.letzterGrund))
-- Rechtsklick im Fokus: nur Angebot, nicht Item
local B = GoldForeverSniperKnopf
B._scripts.OnClick(B, "RightButton", false)
zeige("skip Item " .. tostring(S.skip and S.skip[5631]) .. " skipPreis " .. tostring(S.skipPreis and S.skipPreis[5631] and S.skipPreis[5631].p))
S.suche = 5631; S.sucheFokus = true; GF.sniperErgebnis(5631)
zeige("gleicher Preis wieder? " .. tostring(S.treffer ~= nil) .. " Grund " .. tostring(S.letzterGrund))
GF.live[5631] = { t = JETZT, p = 25, st = { { p = 25, q = 30 }, { p = 60, q = 50 } } }
S.hits = {}
S.suche = 5631; S.sucheFokus = true; GF.sniperErgebnis(5631)
zeige("billiger -> Treffer " .. tostring(S.treffer ~= nil))
S.treffer = nil; GF.sniperZeigen()
zeige("Leiste: " .. tostring(GoldForeverSniper.info._text):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("\n", " / "))
zeige("Ende 2.73.3 ok")
