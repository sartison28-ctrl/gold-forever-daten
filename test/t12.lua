dofile("/home/claude/test/t11.lua")
local GF = GoldForever
-- Lachs: üblich 955, verkauft 700, Angebot 698 -> kein Treffer mehr
GoldForeverRealm.i[13889] = { 955, 6, 960, 1, 0, 3840, 700, 6974 }; GoldForeverRealm.t = GoldForeverRealm.t + 1
GF.live[13889] = { t = JETZT, p = 698, st = { { p = 698, q = 25 }, { p = 950, q = 100 } }, rohstoff = true }
GF.sniper.hits = {}; GF.sniper.skip = {}
zeige("Lachs: " .. tostring(GF.sniperBewerten(13889)))
-- Knaller: Wuttrank-artig, aber 300 Stück zu 20c bei Verkauf 50c, nächstes 65c
GoldForeverRealm.i[5631] = { 67, 6, 67, -1, 0, 1219, 50, 861 }; GoldForeverRealm.t = GoldForeverRealm.t + 1
GF.live[5631] = { t = JETZT, p = 20, st = { { p = 20, q = 300 }, { p = 65, q = 50 } }, rohstoff = true }
GF.sniper.hits = {}
local t = GF.sniperBewerten(5631); zeige("Knaller: " .. tostring(t and (t.n .. "x neu " .. t.neu .. " gewinn " .. t.gewinn .. " knaller " .. tostring(t.knaller))))
assert(t and t.knaller and t.n == 300)
GF.sniper.treffer = t; GF.sniperZeigen(); zeige("Knopf: " .. GoldForeverSniperKnopf.t:GetText())
zeige("Ende 2.58.3 ok")
