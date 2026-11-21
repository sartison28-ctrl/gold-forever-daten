dofile("/home/claude/test/mock.lua")
local function it(n, p, r, mw, u, a) return { n, p, r, mw, u, a } end
NAMEN = { [2453] = "Beulengras", [765] = "Silberblatt", [250065] = "Pikante Hirschfrikadelle", [9999] = "Tüpfelgelbschwanz", [3355] = "Wildstahlblume" }
for k = 1, 9 do NAMEN[5000 + k] = "Halteware" .. k end
GoldForeverData = { stand = JETZT - 3600, budget = 0.7, raidstart = "2026-12-09", items = {
  [2453] = it("Beulengras", 79, 100, 120, 500, 50),
  [765] = it("Silberblatt", 1000, 1700, 1600, 400, 50),
  [250065] = it("Pikante Hirschfrikadelle", 2096, 939, 1119, 30, 1),
  [9999] = it("Tüpfelgelbschwanz", 116, 120, 120, 300, 30),
  [3355] = it("Wildstahlblume", 113, 100, 169, 300, 40),
}, zeit = {
  [2453] = { m = 95, n = 50, am = 40, t = 0, tl = 0 }, [765] = { m = 1500, n = 50, am = 40, t = 0, tl = 0 },
  [250065] = { m = 955, n = 50 }, [9999] = { m = 110, n = 50 }, [3355] = { m = 97, n = 50 },
}, raid = {}, events = {}, gruppen = {} }
GoldForeverDB = { bilanz = { buch = {
  { t = JETZT - 86400, art = "kauf", id = 250065, n = 6, betrag = -4782, v = true, ziel = 955, char = "Dolche" },
  { t = JETZT - 86400, art = "kauf", id = 9999, n = 36, betrag = -2016, v = true, ziel = 116, char = "Dolche" },
}, inserat = {}, post = {}, start = JETZT - 9e5 },
  imAHc = { Dolche = { t = JETZT - 60, items = { [250065] = { n = 6, preis = 2096 }, [9999] = { n = 20, preis = 116 } } } } }
for k = 1, 9 do
  local id = 5000 + k
  GoldForeverData.items[id] = it(NAMEN[id], 800, 1000, 1000, 300, 30); GoldForeverData.zeit[id] = { m = 1000, n = 50 }
  table.insert(GoldForeverDB.bilanz.buch, { t = JETZT - 3600 * k, art = "kauf", id = id, n = 3, betrag = -1800, v = true, ziel = 1000 + k * 50, char = "Dolche" })
  ANZAHL[id] = 3
end

-- 2.51-Mocks
POSTS, CANCELS = {}, {}
ItemLocation = { CreateFromBagAndSlot = function(_, b, sl) return { b = b, s = sl } end }
Enum = Enum or {}; Enum.ItemCommodityStatus = { Item = 1, Commodity = 2 }
TASCHE = { [0] = { [1] = { itemID = 3355, stackCount = 5 } } }
C_Container = { GetContainerNumSlots = function(b) return TASCHE[b] and 4 or 0 end,
  GetContainerItemInfo = function(b, sl) return TASCHE[b] and TASCHE[b][sl] end }
C_AuctionHouse.GetItemCommodityStatus = function() return 2 end
C_AuctionHouse.GetAvailablePostCount = function() return 5 end
C_AuctionHouse.PostCommodity = function(loc, d, n, p) POSTS[#POSTS + 1] = { loc = loc, d = d, n = n, p = p }; return false end
C_AuctionHouse.CancelAuction = function(id) CANCELS[#CANCELS + 1] = id end
C_AuctionHouse.CanCancelAuction = function() return true end
C_AuctionHouse.QueryOwnedAuctions = function() end
C_AuctionHouse.GetNumOwnedAuctions = function() return 2 end
C_AuctionHouse.GetOwnedAuctionInfo = function(k)
  if k == 1 then return { auctionID = 777, itemKey = { itemID = 250065 }, status = 0, quantity = 6, buyoutAmount = 2096 } end
  return { auctionID = 778, itemKey = { itemID = 9999 }, status = 0, quantity = 20, buyoutAmount = 116 } end
ANZAHL[3355] = 5
lade("Core.lua"); lade("UI.lua")
local GF = GoldForever
fire("PLAYER_LOGIN")
-- Trend: Beulengras faellt seit 2 Tagen, Tuepfel auch
GoldForeverData.zeit[2453].rfall = 2
GoldForeverData.zeit[9999].rfall = 2
GF.live[250065] = { t = JETZT - 60, eigen = 2096, st = {} }
GF.live[9999] = { t = JETZT - 60, p = 100, st = { { p = 100, q = 50 } } }
-- 2.52: Realm-Daten (GitHub)
GoldForeverRealm = { stand = "x", t = JETZT - 3600, i = {
  [2453] = { 80, 5, 70, -20, 2, 900, 85, 3000 },     -- Beulengras: üblich 80c, fällt seit 2 Tagen
  [765] = { 1300, 5, 1250, 0, 0, 300, 1290, 500 },    -- Silberblatt: üblich 13s
  [3355] = { 100, 5, 100, 0, 0, 800, 100, 2000 },
} }
-- COMMODITY-Kauf-Mocks
KAEUFE = {}
C_AuctionHouse.StartCommoditiesPurchase = function(id, n) KAEUFE[#KAEUFE + 1] = { "start", id, n } end
C_AuctionHouse.ConfirmCommoditiesPurchase = function(id, n) KAEUFE[#KAEUFE + 1] = { "ok", id, n } end
C_AuctionHouse.CancelCommoditiesPurchase = function() KAEUFE[#KAEUFE + 1] = { "abbruch" } end
GetItemInfo = GetItemInfo or function() end
local altInfo = C_Item and C_Item.GetItemInfo
lade("Core.lua"); lade("UI.lua")
local GF = GoldForever
fire("PLAYER_LOGIN")
local function ohne(x) return (x or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "¤") end
-- Referenz aus Realm
local R, q = GF.referenz(2453); zeige("Referenz Beulengras " .. tostring(R) .. " " .. tostring(q))
assert(R == 80 and q == "realm")
zeige("faelltTage Beulengras: " .. tostring(GF.faelltTage(2453)))
assert(GF.faelltTage(2453))
local pr, dauer = GF.einstellen(GF.info(3355)); zeige("Einstellen Wildstahl " .. tostring(pr) .. " " .. tostring(dauer))
assert(dauer == "24 Std.")
-- Unterbieter: Silberblatt üblich 1300, jemand bietet 2 Stück für 800, Rest 1290
GF.live[765] = { t = JETZT - 60, p = 800, st = { { p = 800, q = 2 }, { p = 1290, q = 100 } }, rohstoff = true }
local u = GF.unterbieter(765); zeige("Unterbieter: " .. (u and (u.n .. " x bis " .. u.max .. " neu " .. u.neu .. " gewinn " .. u.gewinn) or "nil"))
assert(u and u.n == 2)
fire("AUCTION_HOUSE_SHOW")
fire("OWNED_AUCTIONS_UPDATED")
local v = GoldForeverFenster.ansichten.standard
for k, b in ipairs(v.unter.b) do
  b._scripts.OnClick(b)
  local s = ({ v.jetzt, v.herst, v.spaeter, v.ah, v.kauf })[k]
  zeige("== Reiter " .. b.key .. " Badge " .. ohne(b.zahl:GetText()) .. " | " .. ohne(s.titel:GetText()) .. " " .. ohne(s.zahl:GetText()) .. " " .. ohne(s.rechts:GetText()))
  for _, z in ipairs(s.karten) do if z:IsShown() then
    zeige("   " .. ohne(z.name:GetText()) .. " | " .. ohne(z.zeile2:GetText()) .. " | " .. ohne(z.betrag:GetText()) .. (z.aktion:IsShown() and (" [" .. ohne(z.aktion.t:GetText()) .. "]") or ""))
  end end
end
zeige("Halten-Zeile2: " .. ohne(v.spaeter.z2.info:GetText()) .. " | Pruef: " .. ohne(v.spaeter.z2.pruef.t:GetText()))
-- Kopfzahlen
zeige("Kopf: Gold " .. ohne(GoldForeverFenster.k.gold.wert:GetText()) .. " Budget " .. ohne(GoldForeverFenster.k.budget.wert:GetText()) .. " Ein " .. ohne(GoldForeverFenster.k.ein.wert:GetText()) .. " Profit " .. ohne(GoldForeverFenster.k.profit.wert:GetText()))
-- Kaufen-Knopf: Unterbieter Silberblatt
v.unter.b[5]._scripts.OnClick(v.unter.b[5])
local knopf
for _, z in ipairs(v.kauf.karten) do if z:IsShown() and z.aktion:IsShown() then knopf = z.aktion; break end end
assert(knopf, "kein Kaufen-Knopf")
knopf._scripts.OnClick(knopf)
fire("COMMODITY_PRICE_UPDATED", 800, 1600)
zeige("Knopf nach Preis: " .. ohne(knopf.t:GetText()))
knopf._scripts.OnClick(knopf)
for _, k in ipairs(KAEUFE) do zeige("KAUF " .. table.concat(k, " ")) end
assert(KAEUFE[#KAEUFE][1] == "ok")
-- Preis zu hoch -> Abbruch
GF.kaufStarten(765, 2, 800); fire("COMMODITY_PRICE_UPDATED", 1200, 2400)
assert(KAEUFE[#KAEUFE][1] == "abbruch"); zeige("Abbruch bei zu hohem Preis ok")
-- Vollscan-Abklingzeit
GoldForeverDB.vollscanZeit = JETZT - 60
GF.vollscanStarten()
-- Post: verarbeitete Ware (Position ohne Ware) wird geschlossen
GoldForeverDB.bilanz.buch[#GoldForeverDB.bilanz.buch + 1] = { t = JETZT - 7200, art = "kauf", id = 21071, n = 120, betrag = -4440, v = true, ziel = 52, char = "Dolche" }
GoldForeverDB.postWare = { Dolche = { t = JETZT - 60, items = {} } }
local gefunden = false
for _, p in ipairs(GF.positionen()) do if p.id == 21071 then gefunden = true end end
zeige("Roher Weisenfisch offen? " .. tostring(gefunden)); assert(not gefunden)
-- Gewinn verkaufter Position mit echtem Preis
GoldForeverDB.imAHc.Dolche.verkauft = { [9999] = 36 }; GoldForeverDB.imAHc.Dolche.vpreis = { [9999] = 40 }; GoldForeverDB.imAHc.Dolche.items[9999] = nil
ANZAHL[9999] = 0
for _, p in ipairs(GF.positionen()) do if p.id == 9999 then zeige("Tüpfel verkauft: Preis " .. tostring(p.verkauftPreis) .. " Gewinn " .. GF.erwartGewinn(p, GF.verkaufsPlan(p))) end end
zeige("Ende ok")
-- 2.53: Im AH prüfen + Bank + Herstellen + Geld
SUCHEN = {}
C_AuctionHouse.MakeItemKey = function(id) return { itemID = id } end
C_AuctionHouse.SendSearchQuery = function(key) SUCHEN[#SUCHEN + 1] = key.itemID end
GF.pruefen({ 3355, 765 })
zeige("Suche 1: " .. tostring(SUCHEN[1]) .. " Stand " .. tostring((GF.pruefStand())))
GF.live[3355] = { t = JETZT, p = 105, st = { { p = 105, q = 50 } }, rohstoff = true }
fire("COMMODITY_SEARCH_RESULTS_UPDATED", 3355)

zeige("Suchen gesamt: " .. #SUCHEN .. " frisch 3355: " .. tostring(GF.frisch(3355)))
-- Bank
GF.bankOffen = true
BENUTZT = {}
C_Container.UseContainerItem = function(b, sl) BENUTZT[#BENUTZT + 1] = b .. "/" .. sl end
local n = GF.bankVerschieben("haltRein"); zeige("Bank haltRein: " .. tostring(n) .. " (" .. table.concat(BENUTZT, ",") .. ")")
-- Herstellen: eigenes Rezept Silberblatt x2 -> Produkt 9998
NAMEN[9998] = "Heiltrank"
GoldForeverData.items[9998] = { "Heiltrank", 5000, 5000, 5000, 300, 30 }
GoldForeverDB.rezepte = { Dolche = { [1] = { 9998, 1, "Alchemie", 0, { { 765, 2 } }, name = "Heiltrank" } } }
GF.rezepteNeu()
local eig, kauf = GF.herstellenListe()
zeige("Herstellen: eigen " .. #eig .. " kauf " .. #kauf .. (kauf[1] and (" Gewinn " .. kauf[1].gewinn) or ""))
-- Geld-Herkunft
GOLD_IM_BEUTEL = 400000; fire("PLAYER_MONEY"); fire("LOOT_OPENED"); GOLD_IM_BEUTEL = 401000; fire("PLAYER_MONEY"); fire("LOOT_CLOSED")
local h = GF.geldHerkunft(86400); zeige("Geld loot " .. tostring(h.loot))
GoldForeverFenster.ansicht = "standard"; GF.aktualisieren()
zeige("Ende 2.53 ok")
-- Bilanz
table.insert(GoldForeverDB.bilanz.buch, { t = JETZT - 100, art = "verk", id = 765, n = 2, betrag = 2400, char = "Dolche" })
GF.zeigeAnsicht("bilanz")
local b = GoldForeverFenster.ansichten.bilanz
local function ohne(x) return (x or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "¤") end
zeige("Gold-Diagramm: " .. ohne(b.diaGold.wert:GetText()) .. " | Vermögen: " .. ohne(b.diaVerm.wert:GetText()) .. " | " .. ohne(b.jeReiter:GetText()))
for _, z in ipairs(b.tabGold.zeilen) do if z:IsShown() then zeige("  G: " .. ohne(z.l:GetText()) .. " = " .. ohne(z.c[1]:GetText())) end end
for _, z in ipairs(b.tabVerm.zeilen) do if z:IsShown() then zeige("  V: " .. ohne(z.l:GetText()) .. " = " .. ohne(z.c[1]:GetText()) .. " " .. ohne(z.c[2]:GetText())) end end
for _, z in ipairs(b.zeilen) do if z:IsShown() then zeige("  Zeile: " .. ohne(z.name:GetText()) .. " | " .. ohne(z.mitte:GetText()) .. " | " .. ohne(z.betrag:GetText())) end end
b.tabGold.zeilen[1]._scripts.OnClick(b.tabGold.zeilen[1])
for _, z in ipairs(b.zeilen) do if z:IsShown() then zeige("  Filter Verkauft: " .. ohne(z.name:GetText()) .. " | " .. ohne(z.betrag:GetText())) end end
zeige("Ende Bilanz ok")
-- 2.53.3: Herstellen nach Vorschlag buchen + Rückgängig
GF.herstellMerken(9998, GoldForeverDB.rezepte.Dolche[1], 5000)
ANZAHL[9998] = 0
fire("TRADE_SKILL_SHOW")
ANZAHL[9998] = 2; TASCHE[0][2] = { itemID = 9998, stackCount = 2 }
fire("BAG_UPDATE_DELAYED")
local gef
for _, p in ipairs(GF.positionen()) do if p.id == 9998 then gef = p end end
zeige("Hergestellt-Position: " .. tostring(gef and gef.n) .. " ek " .. tostring(gef and gef.ek) .. " herg " .. tostring(gef and gef.hergestellt))
GF.live[9998] = { t = JETZT, p = 5000, st = { { p = 5000, q = 10 } }, rohstoff = true }
local e = GF.empfehlung(9998); zeige("Empfehlung Heiltrank: " .. tostring(e and e.text))
GF.ausblenden(765)
GoldForeverFenster.ansicht = "standard"; GF.zeigeAnsicht("standard")
local v = GoldForeverFenster.ansichten.standard
zeige("Undo sichtbar: " .. tostring(v.undo:IsShown()))
GF.einblenden(765); zeige("765 ausgeblendet? " .. tostring(GF.ausgeblendet(765)))
GF.ausblenden(765); GF.ausblenden(3355); GF.ausListeOffen = true; GF.aktualisieren()
zeige("Liste sichtbar: " .. tostring(v.aus:IsShown()) .. " Zeile1 " .. tostring(v.aus.zeilen[1].itemId))
v.aus.zeilen[1]._scripts.OnClick(v.aus.zeilen[1]); zeige("nach Klick noch ausgeblendet: " .. GF.anzahlAusgeblendet())
zeige("Ende 2.53.3 ok")
-- 2.53.4: gemischte Zutaten + aufklappen
NAMEN[3371] = "Leere Phiole"; GoldForeverDB.haendler = { [3371] = 4 }
GoldForeverData.items[3371] = { "Leere Phiole", 5, 5, 5, 2000, 30 }
GoldForeverDB.rezepte = { Dolche = { [2] = { 9998, 1, "Alchemie", 0, { { 765, 2 }, { 3355, 1 }, { 3371, 1 } }, name = "Heiltrank" } } }
GF.rezepteNeu(); GoldForeverDB.ignor = {}
ANZAHL[765] = 4; ANZAHL[3355] = 0; ANZAHL[3371] = 0
GF.live[3355] = { t = JETZT, p = 100, st = { { p = 100, q = 50 } }, rohstoff = true }
local _, liste = GF.herstellenListe()
local k = liste[1]
zeige("Rezept: " .. tostring(k and k.menge) .. "× · eigen " .. tostring(k and k.eigen) .. " · Gewinn " .. tostring(k and k.gewinn) .. " · fehlt " .. tostring(k and #k.fehlt))
for _, f in ipairs(k and k.fehlt or {}) do zeige("   fehlt " .. f.n .. "× " .. f.id .. " " .. f.quelle .. " " .. f.preis) end
GF.zeigeAnsicht("standard")
local v = GoldForeverFenster.ansichten.standard
v.unter.b[2]._scripts.OnClick(v.unter.b[2])
local function ohne(x) return (x or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "¤") end
local function liste2() for _, z in ipairs(v.herst.karten) do if z:IsShown() then zeige("  " .. ohne(z.name:GetText()) .. " | " .. ohne(z.zeile2:GetText()) .. (z.aktion:IsShown() and (" [" .. ohne(z.aktion.t:GetText()) .. "]") or "")) end end end
liste2()
local kz = v.herst.karten[1]; kz.aktion._scripts.OnClick(kz.aktion)
zeige("-- aufgeklappt"); liste2()
zeige("Ende 2.53.4 ok")
-- 2.54 Lernsystem
local buch = GoldForeverDB.bilanz.buch
for k = 1, 3 do
  table.insert(buch, { t = JETZT - 50000 + k * 1000, art = "kauf", id = 2453, n = 10, betrag = -600, v = true, char = "Dolche" })
  table.insert(buch, { t = JETZT - 40000 + k * 1000, art = "verk", id = 2453, n = 10, betrag = 900, char = "Dolche" })
end
local e = GF.erfahrung(2453); zeige("Beulengras: " .. GF.erfahrungText(e) .. " bewaehrt " .. tostring(e.bewaehrt))
zeige("Quote " .. tostring((GF.trefferQuote(2453, GF.info(2453)))))
GF.zeigeAnsicht("bilanz"); zeige("Lern-Zeile: " .. ohne(GoldForeverFenster.ansichten.bilanz.lern:GetText()))
zeige("Ende 2.54 ok")
