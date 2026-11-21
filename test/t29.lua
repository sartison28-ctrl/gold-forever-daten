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
AuctionHouseFrame = CreateFrame("Frame", "AuctionHouseFrame", UIParent)
lade("Core.lua"); lade("UI.lua")
local GF = GoldForever
fire("PLAYER_LOGIN")
-- Live: Frikadelle nur eigene Auktion
GF.live[250065] = { t = JETZT - 60, eigen = 2096, st = {} }
GoldForever_Toggle()
local v = GoldForeverFenster.ansichten.standard
local function karten(s, titel)
  zeige("== " .. titel .. " (sichtbar=" .. tostring(s:IsShown()) .. ")")
  for _, z in ipairs(s.karten) do if z:IsShown() then zeige("  " .. z.name._text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") .. " | " .. (z.zeile2._text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) .. " | " .. (z.betrag._text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "¤"))) end end
  if s.mehrLink:IsShown() then zeige("  [Link] " .. s.mehrLink.t._text) end
  if s.leer:IsShown() then zeige("  (leer) " .. s.leer.t._text) end
end
local function badges() local t = {} for _, b in ipairs(v.unter.b) do t[#t + 1] = b.key .. "=" .. b.zahl._text .. (b.strich._shown and "*" or "") end zeige("Unter-Reiter: " .. table.concat(t, "  ")) end
badges(); karten(v.jetzt, "Verkaufen")
v.unter.b[3]._scripts.OnClick(v.unter.b[3]); badges(); karten(v.spaeter, "Halten")
v.spaeter.mehrLink._scripts.OnClick(v.spaeter.mehrLink); karten(v.spaeter, "Halten aufgeklappt")
v.unter.b[3]._scripts.OnClick(v.unter.b[3]); badges(); karten(v.kauf, "Kaufen")
v.unter.b[4]._scripts.OnClick(v.unter.b[4]); karten(v.aufk, "Preissprung")
zeige("Logo-Schriftzug sichtbar: " .. tostring(GoldForeverFenster.titel:IsShown()) .. ", Logo: " .. tostring(GoldForeverFenster.logo:IsShown()))
SlashCmdList.GOLDFOREVER("logo"); zeige("nach /gf logo: Schriftzug " .. tostring(GoldForeverFenster.titel:IsShown()))
SlashCmdList.GOLDFOREVER("logo")
-- Tooltip
local tt = { AddLine = GameTooltip.AddLine, AddDoubleLine = GameTooltip.AddDoubleLine }
local function tip(id) TT = {}; local e = GF.entscheidung(id); zeige("-- Tooltip " .. NAMEN[id] .. ": " .. tostring(e and e.text)) end
tip(2453); tip(765); tip(3355)
local P = GF.planFuer(); zeige("Plan-Deals: " .. #P.deals)
-- echter Tooltip-Text
for _, f in ipairs({ 2453, 250065 }) do
  TT = {}
  local hook
  TooltipDataProcessor = nil
end
for _, x in ipairs(LOG) do zeige("LOG " .. x) end
local function echtTip(id) TT = {}; TTF(GameTooltip, { id = id }); zeige("-- echter Tooltip " .. NAMEN[id]); for _, l in ipairs(TT) do zeige("   " .. l:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end end
echtTip(2453); echtTip(250065); echtTip(765)
-- Loot-Hinweis: Wildstahlblume eben gelootet (noch nicht in der Tasche)
LOG = {}
fire("CHAT_MSG_LOOT", "Ihr erhaltet Beute: |cffffffff|Hitem:3355::|h[Wildstahlblume]|h|r", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, "G")
ANZAHL[3355] = 5; local e = GF.entscheidung(3355); zeige("Tooltip-Entscheidung mit 5 in der Tasche: " .. e.text)
-- Vollscan am AH
fire("AUCTION_HOUSE_SHOW")
zeige("Plan beim Öffnen: " .. #GF.ah.plan.deals .. " Deals, Unter-Reiter=" .. tostring(GoldForeverDB.unter))
local rep = { { 3355, 70, 50 }, { 3355, 75, 100 }, { 2453, 60, 200 }, { 765, 1600, 5 } }
C_AuctionHouse.GetNumReplicateItems = function() return #rep end
C_AuctionHouse.GetReplicateItemInfo = function(k) local r = rep[k + 1]; return "n", 1, r[3], 1, true, 1, 1, 0, 0, r[2] * r[3], 0, false, nil, nil, nil, 0, r[1], true end
fire("REPLICATE_ITEM_LIST_UPDATE")
zeige("Plan nach Vollscan: " .. #GF.ah.plan.deals .. " Deals; live 3355=" .. tostring(GF.live[3355] and GF.live[3355].p) .. " stufen=" .. #(GF.live[3355].st))
for _, d in ipairs(GF.ah.plan.deals) do zeige("  Deal " .. NAMEN[d.id] .. " " .. d.menge .. "x") end
for _, x in ipairs(LOG) do zeige("LOG " .. x:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
-- Raid-Event Abschnitt aufklappbar
local r = GoldForeverFenster.ansichten.raid
zeige("Event-Abschnitt max=" .. tostring(r.event.max) .. " Link=" .. tostring(r.event.mehrLink ~= nil))
GF.zeigeAnsicht("raid"); GF.zeigeAnsicht("bilanz"); GF.zeigeAnsicht("test"); GF.zeigeAnsicht("standard")
fire("AUCTION_HOUSE_CLOSED")
local GF = GoldForever
local S = GF.sniper
GF.ah = true
S.laeuft = true; local CT = C_Timer; C_Timer = nil; GF.sniperUmschalten(true, "fokus"); C_Timer = CT
S.treffer = { id = 2453, n = 20, max = 100, neu = 150, gewinn = 800, kosten = 2000, R = 150, abw = 30, t = time(), risiko = "sicher", zeigGT = 0 }
GF.sniperZeigen()
local F = GoldForeverSniperFeld
zeige("Feld da: " .. tostring(F ~= nil) .. " sichtbar " .. tostring(F and F:IsShown()) .. " Text " .. tostring(F and F.t._text))
KAEUFE = {}
C_AuctionHouse.StartCommoditiesPurchase = function(id, n) KAEUFE[#KAEUFE + 1] = "start" .. n end
F._scripts.OnMouseWheel(F, -1)
zeige("Rad übers AH: " .. table.concat(KAEUFE, ","))
GF.kaufLauf = nil
F._scripts.OnClick(F, "RightButton", false)
zeige("Rechtsklick: Treffer weg " .. tostring(S.treffer == nil) .. " Feld zu " .. tostring(not F:IsShown()))
S.modus = "alle"; S.treffer = { id = 2453, n = 20, max = 100, neu = 150, gewinn = 800, kosten = 2000, R = 150, abw = 30, t = time(), risiko = "sicher", zeigGT = 0 }
GF.sniperZeigen()
zeige("Modus Alle: Feld " .. tostring(F:IsShown()))
zeige("Ende 2.71 ok")
