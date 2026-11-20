dofile("/home/claude/test/t10.lua")
local GF = GoldForever
-- Wuttrank: üblich 60c, 2000/Tag laut Realm, 600 Stück zu 40c, danach 70c
GoldForeverRealm.i[5631] = { 60, 6, 60, 0, 0, 2000, 60, 300 }; GoldForeverRealm.t = GoldForeverRealm.t + 1
local alt = C_Item.GetItemInfo
C_Item.GetItemInfo = function(id) if tonumber(id) == 5631 then return "Wuttrank", "|Hitem:5631|h", 1, 1, 1, "x", "y", 20, "", 0, 0, 0 end return alt(id) end
GF.live[5631] = { t = JETZT, p = 40, st = { { p = 40, q = 600 }, { p = 70, q = 50 } }, rohstoff = true }
GF.sniper.hits = {}; GF.sniper.skip = {}
local t = GF.sniperBewerten(5631); zeige("Wuttrank: " .. tostring(t and (t.n .. "x kosten " .. t.kosten .. " gewinn " .. t.gewinn .. " umsatz " .. t.umsatz)))
assert(t == nil or t.n <= 200)
GF.sniperBewerten(5631)
local t3 = GF.sniperBewerten(5631); zeige("3. Treffer in 10 Min.: " .. tostring(t3) .. " skip " .. tostring(GF.sniper.skip[5631] ~= nil)); assert(t3 == nil)
-- Anzeige
GF.live[5631] = { t = JETZT, p = 40, st = { { p = 40, q = 150 }, { p = 70, q = 50 } }, rohstoff = true }; GF.sniper.hits = {}; GF.sniper.skip = {}; t = GF.sniperBewerten(5631); zeige("150 Stück: " .. tostring(t and (t.n .. "x neu " .. t.neu .. " gewinn " .. t.gewinn))); GF.sniper.treffer = t; GF.sniperZeigen()
zeige("Knopf: " .. GoldForeverSniperKnopf.t:GetText()); zeige("Info: " .. GoldForeverSniper.info:GetText()); zeige("Name: " .. GoldForeverSniper.name:GetText())
zeige("Ende 2.58.2 ok")
