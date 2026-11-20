-- Gold Forever: Fenster (/gf), Design v2 (Regeln: claude/ui-designregeln.md, Teil B)
--   Reiter      : Standard · Qualität · Raid & Events · Risiko   (je 103 breit, Lücke 8)
--   Titelzeile  : Bilanz [B] und Test [T] als Symbol-Knöpfe
--   Raster      : Fenster 468, Rand 16, innen 436, alles auf 4er-Schritten
--   Minimap-Knopf: Linksklick Fenster, Rechtsklick Einstellungen (unten in dieser Datei)
local GF = GoldForever
local ENDE = "|r"

-- ---------------------------------------------------------------- Farben: jede Farbe genau eine Bedeutung
local F = {
  gold = { 0.96, 0.77, 0.32 },   -- Marke, aktiver Reiter, klickbare Links
  gruen = { 0.29, 0.87, 0.50 },  -- verkaufen / einstellen, Gewinn
  blau = { 0.38, 0.65, 0.98 },   -- halten / warten
  lila = { 0.75, 0.52, 0.99 },   -- kaufen, nach Vorschlag gekauft
  orange = { 0.98, 0.57, 0.24 }, -- eingreifen
  rot = { 0.97, 0.44, 0.44 },    -- Verlust, zu teuer
  hell = { 0.90, 0.91, 0.92 },   -- Text, Item-Namen, neutrale Beträge
  gelb = { 0.98, 0.80, 0.08 },   -- herstellen (2.53)
  grau = { 0.55, 0.58, 0.65 },   -- Gründe, Bezeichnungen, Mengen
}
local H = {
  gold = "|cfff5c452", gruen = "|cff4ade80", blau = "|cff60a5fa", lila = "|cffc084fc",
  orange = "|cfffb923c", rot = "|cfff87171", hell = "|cffe5e7eb", grau = "|cff8c94a6", gelb = "|cfffacc15",
}

-- ---------------------------------------------------------------- Raster (UI-Einheiten)
local BREITE, RAND = 468, 16
local INNEN = BREITE - 2 * RAND        -- 436
local KOPF, FUSS = 156, 40             -- Kopf fest (Logo-Zeile 48 hoch); Fuß = 12 + 16 + 12
local KARTE_H, KARTE_TAKT = 36, 40
local LISTE_H = 24
local ABSTAND = 20                     -- zwischen Abschnitten
local KACHEL, KACHEL_TAKT, KACHEL_REIHE, KACHEL_PRO_REIHE = 36, 48, 56, 9 -- 2.52: breiter, damit „Preis tief“/„ab 9 Uhr“ passen
local BETRAG_B = 88                    -- Betragsspalte 340–428 (8 Innenabstand rechts)
local MIN_H, MAX_H = 400, 1400 -- Höhe: praktisch nur durch 85 % des Bildschirms begrenzt (720 schnitt den Abschnitt „Preissprung“ ab)

local fenster

-- ---------------------------------------------------------------- Schrift: Expressway (wie EllesmereUI), 16 / 12 / 10
local SCHRIFT = {}
local function schriftenBauen()
  if SCHRIFT[12] then return end
  local pfade = {}
  local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
  if lsm then local ok, p = pcall(lsm.Fetch, lsm, "font", "Expressway", true); if ok and p then pfade[#pfade + 1] = p end end
  for _, p in ipairs({ "Interface\\AddOns\\EllesmereUI\\media\\fonts\\Expressway.ttf", "Interface\\AddOns\\EllesmereUI\\Media\\Fonts\\Expressway.ttf",
    "Interface\\AddOns\\EllesmereUI\\media\\Expressway.ttf" }) do pfade[#pfade + 1] = p end
  pfade[#pfade + 1] = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
  for _, g in ipairs({ 16, 14, 12, 11, 10 }) do -- 2.53.1: 14 und 11 fehlten (leeres Fenster)
    local f = CreateFont("GoldForeverSchrift" .. g)
    for _, p in ipairs(pfade) do
      local ok, gut = pcall(f.SetFont, f, p, g, "")
      if ok and gut ~= false then break end
    end
    f:SetShadowOffset(1, -1); f:SetShadowColor(0, 0, 0, 0.9)
    f:SetTextColor(F.hell[1], F.hell[2], F.hell[3])
    SCHRIFT[g] = f
  end
end
local function text(parent, groesse, farbe)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  fs:SetFontObject(SCHRIFT[groesse or 12] or SCHRIFT[12])
  fs:SetJustifyH("LEFT"); fs:SetWordWrap(false)
  if farbe then fs:SetTextColor(farbe[1], farbe[2], farbe[3]) end
  return fs
end
local function flaeche(parent, a, ebene)
  local t = parent:CreateTexture(nil, ebene or "BACKGROUND"); t:SetAllPoints(); t:SetColorTexture(1, 1, 1, a); return t
end
-- 1-Pixel-Rahmen aus 4 Linien
local function rahmen(f)
  local r = {}
  for _, s in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
    local t = f:CreateTexture(nil, "BORDER")
    if s == "TOP" or s == "BOTTOM" then t:SetPoint(s .. "LEFT"); t:SetPoint(s .. "RIGHT"); t:SetHeight(1)
    else t:SetPoint("TOP" .. s); t:SetPoint("BOTTOM" .. s); t:SetWidth(1) end
    r[#r + 1] = t
  end
  function r.farbe(_, c, a) for _, t in ipairs(r) do t:SetColorTexture(c[1], c[2], c[3], a or 1) end end
  function r.zeigen(_, an) for _, t in ipairs(r) do t:SetShown(an) end end
  return r
end
local function ohneFarbe(s) return ((s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function grau(s) s = ohneFarbe(s); return s ~= "" and (H.grau .. s .. ENDE) or "" end

-- ---------------------------------------------------------------- Beträge
-- Unter 10g mit Silber und Kupfer, ab 10g ohne Kupfer, ab 1.000g nur Gold mit Tausenderpunkt
local MZ = {
  g = "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t",
  s = "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t",
  c = "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t",
}
local function tausender(n)
  local s = tostring(n):reverse():gsub("(%d%d%d)", "%1."):reverse()
  return (s:gsub("^%.", ""))
end
local function betrag(c)
  if not c then return "—" end
  c = math.floor(math.abs(c) + 0.5)
  local g, s, k = math.floor(c / 10000), math.floor(c / 100) % 100, c % 100
  if g >= 1000 then return tausender(g) .. MZ.g end
  local t = {}
  if g > 0 then t[#t + 1] = g .. MZ.g end
  if s > 0 then t[#t + 1] = s .. MZ.s end
  if g < 10 and (k > 0 or #t == 0) then t[#t + 1] = k .. MZ.c end
  return table.concat(t, " ")
end
-- Kopf-Kacheln (2.53, Befund 30): kürzer – ab 1g ohne Kupfer, ab 100g nur Gold
local function betragKurz(c)
  if not c then return "—" end
  local a = math.floor(math.abs(c) + 0.5)
  if a >= 1000000 then return betrag(math.floor(a / 10000) * 10000) end
  if a >= 10000 then return betrag(math.floor(a / 100) * 100) end
  return betrag(a)
end
local function plusMinusKurz(c)
  if c >= 0 then return H.gruen .. "+" .. betragKurz(c) .. ENDE end
  return H.rot .. "-" .. betragKurz(c) .. ENDE
end
local function plusMinus(c)
  if c >= 0 then return H.gruen .. "+" .. betrag(c) .. ENDE end
  return H.rot .. "-" .. betrag(c) .. ENDE
end
local function datum(s) local _, m, d = string.match(s or "", "(%d+)-(%d+)-(%d+)"); return d and (tonumber(d) .. "." .. tonumber(m) .. ".") or "?" end
local function itemName(id, i) return ((C_Item and C_Item.GetItemInfo or GetItemInfo)(id)) or (i and i.n) or ("Item " .. id) end
local function itemIcon(id) return id and ((C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)) or (GetItemIcon and GetItemIcon(id))) or 134400 end
local function qualitaet(id)
  local _, _, q = (C_Item and C_Item.GetItemInfo or GetItemInfo)(id)
  local c = q and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
  if c then return { c.r, c.g, c.b } end
  return { 0.4, 0.42, 0.46 }
end

-- ---------------------------------------------------------------- Suchen im Auktionshaus
local function istSuchfeld(fokus) return fokus and fokus.SetText and not (fokus.GetName and fokus:GetName() and string.find(fokus:GetName(), "^ChatFrame")) end
local function insSuchfeld(id)
  local name, link = (C_Item and C_Item.GetItemInfo or GetItemInfo)(id)
  if not name then local i = GF.info(id); name = i and i.n end
  if not name then return end
  local blizz = AuctionHouseFrame and AuctionHouseFrame:IsShown() and AuctionHouseFrame.SearchBar
  local fokus = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
  if istSuchfeld(fokus) then
    fokus:SetText(name); fokus:SetCursorPosition(0)
    local tc = fokus.GetScript and fokus:GetScript("OnTextChanged"); if tc then pcall(tc, fokus, true) end
    if fokus.GetScript and fokus:GetScript("OnEnterPressed") then pcall(fokus:GetScript("OnEnterPressed"), fokus) end
    return
  end
  if blizz and blizz.SearchBox then
    blizz.SearchBox:SetText(name)
    if blizz.StartSearch then pcall(blizz.StartSearch, blizz) end
    return
  end
  if link and ChatEdit_InsertLink and ChatEdit_InsertLink(link) then return end
  print(H.gold .. "Gold Forever:" .. ENDE .. " Klick zuerst ins Suchfeld des Auktionshauses, dann auf die Karte.")
end

local kopierFenster
local function zeigeKopieren(t)
  if not kopierFenster then
    local f = CreateFrame("Frame", "GoldForeverKopieren", UIParent, "BackdropTemplate")
    tinsert(UISpecialFrames, "GoldForeverKopieren")
    f:SetSize(BREITE, 72); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG")
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    f:SetBackdropColor(0.055, 0.063, 0.082, 0.98); f:SetBackdropBorderColor(F.gold[1], F.gold[2], F.gold[3], 0.35)
    f.t = text(f, 10, F.grau); f.t:SetPoint("TOPLEFT", RAND, -12)
    f.t:SetText("Strg+C, dann ins TSM-Suchfeld (Strg+V). Tipp: einmal ins TSM-Suchfeld klicken – danach trägt Gold Forever direkt ein.")
    f.t:SetWidth(INNEN - 28); f.t:SetWordWrap(false)
    local zu = CreateFrame("Button", nil, f); zu:SetSize(20, 20); zu:SetPoint("TOPRIGHT", -RAND + 4, -6)
    zu.i = zu:CreateTexture(nil, "ARTWORK"); zu.i:SetSize(16, 16); zu.i:SetPoint("CENTER")
    zu.i:SetTexture("Interface\\Buttons\\UI-StopButton"); zu.i:SetDesaturated(true); zu.i:SetVertexColor(F.grau[1], F.grau[2], F.grau[3])
    zu:SetScript("OnClick", function() f:Hide() end)
    zu:SetScript("OnEnter", function(self) self.i:SetVertexColor(F.hell[1], F.hell[2], F.hell[3]) end)
    zu:SetScript("OnLeave", function(self) self.i:SetVertexColor(F.grau[1], F.grau[2], F.grau[3]) end)
    f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
    local e = CreateFrame("EditBox", nil, f); e:SetSize(INNEN, 24); e:SetPoint("TOPLEFT", RAND, -32)
    e:SetFontObject(SCHRIFT[12]); e:SetTextInsets(8, 8, 0, 0); e:SetAutoFocus(false)
    flaeche(e, 0.06); rahmen(e):farbe(F.gold, 0.5)
    e:SetScript("OnEscapePressed", function() f:Hide() end)
    e:SetScript("OnEnterPressed", function() f:Hide() end)
    f:SetScript("OnHide", function() e:ClearFocus() end)
    f.e = e
    kopierFenster = f
  end
  kopierFenster.e:SetText(t); kopierFenster:Show(); kopierFenster.e:SetFocus(); kopierFenster.e:SetCursorPosition(0); kopierFenster.e:HighlightText()
end
-- Text in das Suchfeld, das gerade den Cursor hat (TSM), sonst Kopier-Fenster
-- Das zuletzt angeklickte Suchfeld (TSM oder Blizzard-AH) merken: Danach trägt Gold Forever Suchen direkt
-- dort ein, auch wenn der Cursor gerade woanders ist. (In die Zwischenablage dürfen Addons nicht schreiben.)
local merkFeld
local eigeneFelder = {}
local function feldMerken()
  local f = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
  if istSuchfeld(f) and not eigeneFelder[f] and f ~= (kopierFenster and kopierFenster.e) then merkFeld = f end
end
local merker = CreateFrame("Frame")
merker:RegisterEvent("GLOBAL_MOUSE_UP")
merker:SetScript("OnEvent", function()
  if GF.ah and C_Timer then C_Timer.After(0.05, function() pcall(feldMerken) end) end
end)
-- TSM übernimmt Text nur als „Benutzereingabe“ (OnTextChanged mit userInput = true); nach reinem SetText
-- sucht TSM sonst mit leerem Feld = alles (15.11.: „In TSM suchen“ zeigte beliebige Items)
local function alsEingabe(feld)
  local tc = feld.GetScript and feld:GetScript("OnTextChanged")
  if tc then pcall(tc, feld, true) end
end
local function eintragen(feld, t)
  feld:SetText(t); feld:SetCursorPosition(0); alsEingabe(feld)
  if feld.GetScript and feld:GetScript("OnEnterPressed") then pcall(feld:GetScript("OnEnterPressed"), feld) end
end
local function sucheText(t)
  local fokus = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
  if istSuchfeld(fokus) and not eigeneFelder[fokus] and fokus ~= (kopierFenster and kopierFenster.e) then
    merkFeld = fokus; eintragen(fokus, t); return
  end
  if merkFeld and merkFeld.IsVisible and merkFeld:IsVisible() then eintragen(merkFeld, t); return end
  zeigeKopieren(t)
end
local function namenListe(ids)
  local teile, gesehen = {}, {}
  for _, id in ipairs(ids) do
    if not gesehen[id] then
      local n = itemName(id); if n then gesehen[id] = true; teile[#teile + 1] = n end
    end
  end
  return table.concat(teile, ";"), #teile
end
-- Genau die Einkaufsliste des sichtbaren Reiters (Standard: Budget-Plan, Raid: Raid-Vorrat)
function GF.tsmSuche()
  local ids = {}
  for _, d in ipairs(GF.angezeigteKaeufe or {}) do ids[#ids + 1] = d.id end
  if #ids == 0 then
    local P = (GF.ah and GF.ah.plan) or GF.budgetPlan()
    for _, d in ipairs(P.deals) do ids[#ids + 1] = d.id end
  end
  return namenListe(ids)
end
local function inTsmSuchen()
  local t, n = GF.tsmSuche()
  if n == 0 then print(H.gold .. "Gold Forever:" .. ENDE .. " Im Einkaufsplan steht gerade nichts."); return end
  sucheText(t)
end

-- ---------------------------------------------------------------- Lagerorte
local ORTE = {
  { k = "tasche", tex = "Interface\\Icons\\INV_Misc_Bag_08", titel = "in der Tasche" },
  { k = "bank", tex = "Interface\\Icons\\INV_Box_01", titel = "in der Bank" },
  { k = "kriegsmeute", tex = "Interface\\Icons\\INV_Crate_02", titel = "in der Kriegsmeute-Bank" },
  { k = "post", tex = "Interface\\Icons\\INV_Letter_15", titel = "im Briefkasten" },
  { k = "ah", tex = "Interface\\Icons\\INV_Misc_Coin_02", titel = "im Auktionshaus" },
  { k = "char", tex = "Interface\\Icons\\INV_Misc_GroupNeedMore", titel = "bei anderem Charakter" },
}
local function zaehle(id, bank, konto)
  local f = (C_Item and C_Item.GetItemCount) or GetItemCount
  local ok, n = pcall(f, id, bank, false, bank, konto)
  return (ok and n) or 0
end
local function angelegt(id)
  local n = 0
  if GetInventoryItemID then
    for slot = 1, 19 do local ok, sid = pcall(GetInventoryItemID, "player", slot); if ok and sid == id then n = n + 1 end end
  end
  return n
end
function GF.lagerorte(id, extra)
  id = tonumber(id)
  local o = {}
  local nur = zaehle(id, false, false)
  local bank = zaehle(id, true, false)
  local konto = zaehle(id, true, true)
  o.tasche = math.max(0, nur - angelegt(id))
  o.bank = math.max(0, bank - nur)
  o.kriegsmeute = math.max(0, konto - bank)
  o.ah = (GF.imAH and (GF.imAH(id))) or 0
  for k, v in pairs(extra or {}) do o[k] = v end
  return o
end
local function nurBank(o) return (o.tasche or 0) == 0 and ((o.bank or 0) + (o.kriegsmeute or 0)) > 0 end

-- ---------------------------------------------------------------- Prognose (Uhr-Symbol bei „Halten")
-- Schätzung aus dem Preisverlauf: Wann steigt der Preis, wann ist das beste Verkaufsfenster?
-- Quelle: Datendatei zeit[id] (ph/h/d = Phase und typische Dauer, t = Trend, bv = beste Stunde, n = Messungen)
-- und Tagesrhythmus (GF.tagesfenster). Liefert Zeilen für den Tooltip.
local function naechstesFenster(stunde, dauer)
  local jetzt = time()
  local t = date("*t", jetzt)
  local a = time({ year = t.year, month = t.month, day = t.day, hour = stunde, min = 0, sec = 0 })
  if a + dauer * 3600 <= jetzt then a = a + 86400 end
  return a, a + dauer * 3600
end
local function fensterText(a, b)
  return GF.WT[tonumber(date("%w", a)) + 1] .. " " .. date("%d.%m.%Y", a) .. " · " .. tonumber(date("%H", a)) .. "–" .. tonumber(date("%H", b)) .. " Uhr"
end
function GF.prognose(id, p)
  local z = GF.zeit(id) or {}
  local tf = GF.tagesfenster()
  local i = GF.info(id)
  local jetzt = time()
  local zeilen = {}
  -- Raid-Ware vor Raidstart: Verkauf erst ab Raidstart
  local rs = GoldForeverData and GoldForeverData.raidstart
  if GF.raid(id) and not GF.raidLaeuft() and rs then
    local tage = GF.tageBis(rs)
    zeilen[#zeilen + 1] = { "Verkaufen ab", datum(rs) .. (tage and (" (in " .. tage .. " Tagen)") or "") }
  end
  -- Preis steigt?
  local steigt
  if (z.t or 0) >= 10 then steigt = "steigt bereits"
  elseif z.ph == "tief" and z.d and z.h then
    local rest = math.max(1, math.floor(z.d - z.h + 0.5))
    steigt = "in ca. " .. rest .. " Std. (Tief dauert meist ~" .. math.floor(z.d + 0.5) .. " Std.)"
  elseif (z.t or 0) <= -10 then steigt = "fällt noch – frühestens morgen"
  else steigt = "keine klare Richtung" end
  zeilen[#zeilen + 1] = { "Preis steigt", steigt }
  -- Bestes Verkaufsfenster (eigene beste Stunde des Items, sonst Tageshoch aller Items)
  local std = z.bv or (tf and tf.vVon)
  if std then
    local a, b = naechstesFenster(std, 3)
    zeilen[#zeilen + 1] = { "Bester Verkauf", fensterText(a, b) }
    zeilen[#zeilen + 1] = { "Noch", (a <= jetzt) and "jetzt" or ("ca. " .. math.max(1, math.floor((a - jetzt) / 3600 + 0.5)) .. " Std.") }
  else
    zeilen[#zeilen + 1] = { "Bester Verkauf", "noch zu wenig Daten" }
  end
  if i and i.p then zeilen[#zeilen + 1] = { "Preis jetzt", GF.geld(i.p) } end
  if p and p.ziel then zeilen[#zeilen + 1] = { "Ziel", GF.geld(p.ziel) } end
  local tempo = i and GF.tempo(i)
  if tempo then zeilen[#zeilen + 1] = { "Verkauf dauert", tempo } end
  local unsicher = (z.n or 0) < 24
  return { zeilen = zeilen, unsicher = unsicher }
end
local function prognoseTooltip(pr)
  if not pr then return end
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine("Prognose", F.gold[1], F.gold[2], F.gold[3])
  for _, z in ipairs(pr.zeilen) do GameTooltip:AddDoubleLine(z[1], z[2], F.grau[1], F.grau[2], F.grau[3], F.hell[1], F.hell[2], F.hell[3]) end
  GameTooltip:AddLine(pr.unsicher and "Schätzung – noch wenig Preisverlauf für dieses Item." or "Schätzung aus dem Preisverlauf der letzten Tage.", F.grau[1], F.grau[2], F.grau[3], true)
end

-- ---------------------------------------------------------------- Karte (Handlungs-Zeile, 436 × 36)
local function karteKlick(self, taste)
  if not self.itemId or self.platzhalter then return end
  if taste == "RightButton" then if self.weg then GF.ausblenden(self.itemId) end; return end
  if IsShiftKeyDown() or (GF.ah and not (IsModifiedClick and IsModifiedClick())) then pcall(insSuchfeld, self.itemId)
  elseif IsModifiedClick and IsModifiedClick() then
    local _, link = (C_Item and C_Item.GetItemInfo or GetItemInfo)(self.itemId)
    if link and HandleModifiedItemClick then HandleModifiedItemClick(link) end
  end
end
local function karteTooltip(self)
  self.hl:Show()
  if not self.itemId then return end
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetItemByID(self.itemId)
  if self.hinweis then GameTooltip:AddLine(self.hinweis, F.gold[1], F.gold[2], F.gold[3], true) end
  prognoseTooltip(self.prognose)
  if not self.platzhalter then
    GameTooltip:AddLine("Klick: im AH suchen" .. (self.weg and "  ·  Rechtsklick: ausblenden" or ""), F.grau[1], F.grau[2], F.grau[3])
  end
  GameTooltip:Show()
end
-- Klick auf „Einstellen“ / „Abbrechen“ (2.51): ein Klick = eine Auktion
local function aktionKlick(self)
  local a = self.a; if not a or not self:IsEnabled() then return end
  local name = itemName(a.id)
  if a.art == "post" then
    local ok, err, n = GF.einstellenJetzt(a.id, a.preis, a.n, a.dauer)
    if ok then print(H.gold .. "Gold Forever:" .. ENDE .. " " .. (n or 1) .. "× " .. name .. " für je " .. GF.geld(a.preis) .. " eingestellt (" .. (a.dauer or "24 Std.") .. ").")
    else print(H.gold .. "Gold Forever:" .. ENDE .. H.orange .. " Einstellen ging nicht – " .. tostring(err) .. ENDE) end
  elseif a.art == "check" then
    GF.pruefen({ a.id }); self.t:SetText("prüfe …"); return
  elseif a.art == "buy" then
    local k = GF.kaufLauf
    if k and k.id == a.id and k.unit then
      local ok, err, kk = GF.kaufBestaetigen()
      if ok then print(H.gold .. "Gold Forever:" .. ENDE .. " " .. kk.n .. "× " .. name .. " gekauft für " .. GF.geld(kk.total or kk.unit * kk.n) .. " (je " .. GF.geld(kk.unit) .. ") – liegt gleich im Briefkasten.")
      else print(H.gold .. "Gold Forever:" .. ENDE .. H.orange .. " Kauf ging nicht – " .. tostring(err) .. ENDE) end
    else
      local ok, err = GF.kaufStarten(a.id, a.n, a.max)
      if not ok then print(H.gold .. "Gold Forever:" .. ENDE .. H.orange .. " Kaufen ging nicht – " .. tostring(err) .. ENDE)
      else self.t:SetText("Preis …"); return end
    end
  elseif a.art == "cancel" then
    local ok, err, auk = GF.abbrechenJetzt(a.id)
    if ok then print(H.gold .. "Gold Forever:" .. ENDE .. " Auktion " .. name .. (auk and auk.p and (" (" .. GF.geld(auk.p) .. ")") or "") .. " abgebrochen – die Ware kommt per Post zurück, dann neu einstellen.")
    else print(H.gold .. "Gold Forever:" .. ENDE .. H.orange .. " Abbrechen ging nicht – " .. tostring(err) .. ENDE) end
  end
  self:Disable(); self.t:SetTextColor(F.grau[1], F.grau[2], F.grau[3])
  if C_Timer then C_Timer.After(1.5, function() self:Enable(); if GF.aktualisieren then GF.aktualisieren() end end) end
end

local function karte(parent)
  local z = CreateFrame("Button", nil, parent)
  z:SetSize(INNEN, KARTE_H)
  z.bg = z:CreateTexture(nil, "BACKGROUND"); z.bg:SetAllPoints()
  z.hl = flaeche(z, 0.03, "BACKGROUND"); z.hl:Hide()
  z.q = z:CreateTexture(nil, "BORDER"); z.q:SetSize(28, 28); z.q:SetPoint("TOPLEFT", 4, -4)
  z.icon = z:CreateTexture(nil, "ARTWORK"); z.icon:SetSize(26, 26); z.icon:SetPoint("CENTER", z.q, "CENTER")
  z.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  z.punkt = z:CreateTexture(nil, "OVERLAY"); z.punkt:SetSize(6, 6); z.punkt:SetPoint("TOPRIGHT", z.q, "TOPRIGHT", 2, 2)
  z.punkt:SetColorTexture(0.976, 0.451, 0.086, 1) -- #F97316, F.orange wirkte im Spiel gelb
  z.haken = z:CreateTexture(nil, "OVERLAY"); z.haken:SetSize(10, 10); z.haken:SetPoint("BOTTOMLEFT", z.q, "BOTTOMLEFT", -2, -2)
  z.haken:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready"); z.haken:SetDesaturated(true); z.haken:SetVertexColor(F.lila[1], F.lila[2], F.lila[3])
  z.name = text(z, 12); z.name:SetPoint("TOPLEFT", 40, -5)
  z.betrag = text(z, 12); z.betrag:SetPoint("TOPRIGHT", -8, -5); z.betrag:SetJustifyH("RIGHT"); z.betrag:SetWidth(BETRAG_B)
  z.zeile2 = text(z, 10); z.zeile2:SetPoint("TOPLEFT", 40, -21); z.zeile2:SetWidth(INNEN - 48)
  -- Aktions-Knopf rechts unten (2.51)
  z.aktion = CreateFrame("Button", nil, z); z.aktion:SetSize(80, 16); z.aktion:SetPoint("BOTTOMRIGHT", -8, 3)
  z.aktion.bg = z.aktion:CreateTexture(nil, "BACKGROUND"); z.aktion.bg:SetAllPoints()
  z.aktion.t = text(z.aktion, 10); z.aktion.t:SetPoint("CENTER"); z.aktion.t:SetJustifyH("CENTER")
  z.aktion:SetScript("OnClick", aktionKlick)
  z.aktion:SetScript("OnEnter", function(self)
    z.hl:Show(); if not self.a then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:AddLine(self.a.text)
    GameTooltip:AddLine(self.a.tipp or "", F.grau[1], F.grau[2], F.grau[3], true); GameTooltip:Show()
  end)
  z.aktion:SetScript("OnLeave", function() z.hl:Hide(); GameTooltip:Hide() end)
  z.aktion:Hide()
  z.orte = {}
  for k = 1, #ORTE do
    -- 2.52: Lagerort-Symbole größer (16) mit hellem Rand, besser sichtbar (Wunsch Alex)
    local o = CreateFrame("Frame", nil, z); o:SetSize(16, 16)
    o.r = o:CreateTexture(nil, "BORDER"); o.r:SetPoint("TOPLEFT", -1, 1); o.r:SetPoint("BOTTOMRIGHT", 1, -1); o.r:SetColorTexture(F.hell[1], F.hell[2], F.hell[3], 0.55)
    o.t = o:CreateTexture(nil, "ARTWORK"); o.t:SetAllPoints(); o.t:SetTexCoord(0.08, 0.92, 0.08, 0.92); o.t:SetDesaturated(false); o:SetAlpha(1)
    o:EnableMouse(true)
    if o.SetPropagateMouseClicks then pcall(o.SetPropagateMouseClicks, o, true) end
    o:SetScript("OnEnter", function(self)
      karteTooltip(z)
      if self.zeile then GameTooltip:AddLine(self.zeile, F.hell[1], F.hell[2], F.hell[3], true); GameTooltip:Show() end
    end)
    o:SetScript("OnLeave", function() z.hl:Hide(); GameTooltip:Hide() end)
    o:Hide(); z.orte[k] = o
  end
  -- Uhr-Symbol (nur bei „Halten"): Tooltip mit Prognose
  z.uhr = CreateFrame("Frame", nil, z); z.uhr:SetSize(16, 16); z.uhr:EnableMouse(true)
  z.uhr.t = z.uhr:CreateTexture(nil, "ARTWORK"); z.uhr.t:SetAllPoints(); z.uhr.t:SetTexture("Interface\\Icons\\INV_Misc_PocketWatch_01"); z.uhr.t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  if z.uhr.SetPropagateMouseClicks then pcall(z.uhr.SetPropagateMouseClicks, z.uhr, true) end
  z.uhr:SetScript("OnEnter", function() z.hl:Show(); GameTooltip:SetOwner(z.uhr, "ANCHOR_RIGHT"); GameTooltip:AddLine(itemName(z.itemId or 0)); prognoseTooltip(z.prognose); GameTooltip:Show() end)
  z.uhr:SetScript("OnLeave", function() z.hl:Hide(); GameTooltip:Hide() end)
  z.uhr:Hide()
  z:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  z:SetScript("OnClick", karteKlick)
  z:SetScript("OnEnter", karteTooltip)
  z:SetScript("OnLeave", function(self) self.hl:Hide(); GameTooltip:Hide() end)
  return z
end

-- e = {id, n, name, zeile2, betrag, ton, scan, gekauft, weg, hinweis, orte, grau, platzhalter}
local function setzeKarte(z, e)
  z.itemId, z.hinweis, z.weg, z.platzhalter = e.id, e.hinweis, e.weg, e.platzhalter
  if e.ton then z.bg:SetColorTexture(e.ton[1], e.ton[2], e.ton[3], 0.12) else z.bg:SetColorTexture(1, 1, 1, 0.03) end
  local q = e.grau and { 0.3, 0.32, 0.36 } or (e.id and qualitaet(e.id)) or { 0.4, 0.42, 0.46 }
  z.q:SetColorTexture(q[1], q[2], q[3], 1)
  z.icon:SetTexture(e.icon or itemIcon(e.id)); z.icon:SetDesaturated(e.grau and true or false)
  z.punkt:SetShown(e.scan and true or false)
  z.haken:SetShown(e.gekauft and true or false)
  local farbe = e.grau and H.grau or H.hell
  z.name:SetWidth(0)
  z.name:SetText((e.n and (H.grau .. e.n .. "× " .. ENDE) or "") .. farbe .. (e.name or (e.id and itemName(e.id)) or "") .. ENDE)
  -- Lagerort-Symbole direkt hinter dem Namen; zu lange Namen werden gekürzt, Symbole bleiben sichtbar
  local sym = {}
  for k, o in ipairs(ORTE) do
    local n = e.orte and e.orte[o.k] or 0
    if n > 0 then sym[#sym + 1] = { o = o, n = n } end
  end
  local symbole = #sym + (e.prognose and 1 or 0)
  local platz = 292 - (symbole > 0 and (4 + symbole * 19 - 2) or 0)
  local breit = (z.name.GetUnboundedStringWidth and z.name:GetUnboundedStringWidth()) or z.name:GetStringWidth() or platz
  z.name:SetWidth(math.min(platz, math.ceil(breit) + 1))
  for k, rf in ipairs(z.orte) do
    local s = sym[k]
    if s then
      rf.t:SetTexture(s.o.tex)
      rf.zeile = s.n .. " " .. s.o.titel
      rf:ClearAllPoints(); rf:SetPoint("LEFT", z.name, "RIGHT", 5 + (k - 1) * 19, 0); rf:Show()
    else rf:Hide() end
  end
  z.prognose = e.prognose
  if e.prognose then
    z.uhr:ClearAllPoints(); z.uhr:SetPoint("LEFT", z.name, "RIGHT", 5 + #sym * 19, 0); z.uhr:Show()
  else z.uhr:Hide() end
  z.betrag:SetText(e.betrag or "")
  z.zeile2:SetText(e.zeile2 or "")
  -- Aktions-Knopf nur am offenen AH und nur, wenn die Ware da ist (Einstellen: in der Tasche)
  local a = e.aktion
  if a and GF.ah and (a.art ~= "post" or (GF.inTasche and GF.inTasche(a.id))) then
    -- 2.53 (Befund 32): Einstellen nur mit frisch geprüftem Preis – sonst erst „Preis prüfen“
    if a.art == "post" and not GF.frisch(a.id) then
      a = { art = "check", id = a.id, text = "Preis prüfen", tipp = "Der Preis ist nicht frisch geprüft. Klick: Gold Forever sucht das Item im AH; danach steht hier „Einstellen“ mit dem echten Preis." }
    end
    local c = (a.art == "cancel" and F.orange) or (a.art == "buy" and F.lila) or (a.art == "check" and F.gold) or F.gruen
    local txt = a.text
    -- Kaufen: nach Klick 1 steht der echte Preis da -> Klick 2 bestaetigt
    local k = GF.kaufLauf
    if a.art == "buy" and k and k.id == a.id and k.unit then txt = "OK " .. GF.geld(k.total or k.unit * k.n); c = F.gold end
    z.aktion.a = a; z.aktion.t:SetText(txt); z.aktion.t:SetTextColor(c[1], c[2], c[3])
    z.aktion.bg:SetColorTexture(c[1], c[2], c[3], 0.18); z.aktion:Show()
    z.zeile2:SetWidth(INNEN - 48 - 88)
  else
    z.aktion.a = nil; z.aktion:Hide(); z.zeile2:SetWidth(INNEN - 48)
  end
  z:Show()
end

-- ---------------------------------------------------------------- Icon-Kachel (36 × 36, Text darunter)
local function kachel(parent, farbe)
  local kn = CreateFrame("Button", nil, parent); kn:SetSize(KACHEL, 52)
  kn.rand = kn:CreateTexture(nil, "BACKGROUND"); kn.rand:SetSize(KACHEL, KACHEL); kn.rand:SetPoint("TOP")
  kn.rand:SetColorTexture(farbe[1], farbe[2], farbe[3], 0.9)
  kn.icon = kn:CreateTexture(nil, "ARTWORK"); kn.icon:SetSize(32, 32); kn.icon:SetPoint("CENTER", kn.rand, "CENTER")
  kn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  kn.n = text(kn, 10); kn.n:SetPoint("BOTTOMRIGHT", kn.rand, "BOTTOMRIGHT", -3, 3); kn.n:SetJustifyH("RIGHT")
  kn.plus = text(kn, 12); kn.plus:SetPoint("CENTER", kn.rand, "CENTER")
  kn.x = text(kn, 10, farbe); kn.x:SetPoint("TOP", kn.rand, "BOTTOM", 0, -4); kn.x:SetWidth(KACHEL_TAKT); kn.x:SetJustifyH("CENTER")
  kn.haken = kn:CreateTexture(nil, "OVERLAY"); kn.haken:SetSize(10, 10); kn.haken:SetPoint("BOTTOMLEFT", kn.rand, "BOTTOMLEFT", -2, -2)
  kn.haken:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready"); kn.haken:SetDesaturated(true); kn.haken:SetVertexColor(F.lila[1], F.lila[2], F.lila[3]); kn.haken:Hide()
  kn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  kn:SetScript("OnClick", function(self, taste)
    -- „+N“-Kachel: alle Kacheln zeigen (2.50, Befund 17)
    if self.plusTile then local s = self:GetParent(); s.kachelnOffen = true; GF.aktualisieren(); return end
    karteKlick(self, taste)
  end)
  kn:SetScript("OnEnter", function(self)
    if self.plusTile then GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:AddLine("Klick: alle zeigen"); GameTooltip:Show(); return end
    if not self.itemId then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetItemByID(self.itemId)
    if self.hinweis then GameTooltip:AddLine(self.hinweis, F.gold[1], F.gold[2], F.gold[3], true) end
    prognoseTooltip(self.prognose)
    GameTooltip:AddLine("Klick: im AH suchen" .. (self.weg and "  ·  Rechtsklick: ausblenden" or ""), F.grau[1], F.grau[2], F.grau[3])
    GameTooltip:Show()
  end)
  kn:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return kn
end

-- ---------------------------------------------------------------- Text-Link (gold) und Knopf (flach)
local function link(parent, groesse, onClick, tipp)
  local b = CreateFrame("Button", nil, parent); b:SetHeight(16)
  b.t = text(b, groesse or 10, F.gold); b.t:SetPoint("RIGHT")
  function b:Text(s) self.t:SetText(s); self:SetWidth(math.max(8, math.ceil(self.t:GetStringWidth() or 40) + 2)) end
  b:SetScript("OnClick", onClick)
  b:SetScript("OnEnter", function(self)
    self.t:SetTextColor(1, 0.88, 0.55)
    if tipp then GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:AddLine(tipp[1]); if tipp[2] then GameTooltip:AddLine(tipp[2], F.grau[1], F.grau[2], F.grau[3], true) end; GameTooltip:Show() end
  end)
  b:SetScript("OnLeave", function(self) self.t:SetTextColor(F.gold[1], F.gold[2], F.gold[3]); GameTooltip:Hide() end)
  return b
end
local function knopf(parent, breite, beschriftung, onClick, tipp)
  local b = CreateFrame("Button", nil, parent); b:SetSize(breite, 24)
  flaeche(b, 0.06)
  b.r = rahmen(b); b.r:farbe({ 1, 1, 1 }, 0.12)
  b.t = text(b, 12); b.t:SetPoint("CENTER"); b.t:SetText(beschriftung)
  b:SetScript("OnClick", onClick)
  b:SetScript("OnEnter", function(self)
    self.r:farbe(F.gold, 0.8)
    if tipp then GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:AddLine(tipp[1]); if tipp[2] then GameTooltip:AddLine(tipp[2], F.grau[1], F.grau[2], F.grau[3], true) end; GameTooltip:Show() end
  end)
  b:SetScript("OnLeave", function(self) self.r:farbe({ 1, 1, 1 }, 0.12); GameTooltip:Hide() end)
  return b
end
-- Kennzahl-Kachel: Bezeichnung oben (10, grau), Wert darunter (16), beides mittig
local function kennzahl(parent, w, h)
  local k = CreateFrame("Button", nil, parent); k:SetSize(w, h or 44)
  k.bg = flaeche(k, 0.03)
  k.r = rahmen(k); k.r:zeigen(false)
  k.oben = text(k, 10, F.grau); k.oben:SetPoint("TOP", 0, -6); k.oben:SetJustifyH("CENTER")
  k.wert = text(k, 14); k.wert:SetPoint("TOP", 0, -21); k.wert:SetJustifyH("CENTER"); k.wert:SetWidth(w - 6); k.wert:SetWordWrap(false)
  return k
end

-- ---------------------------------------------------------------- Abschnitt: Kopf (20) + Hinweis + Karten + Kacheln
local function abschnitt(parent, farbe, anzahlKarten, kachelFarbe, anzahlKacheln)
  local s = CreateFrame("Frame", nil, parent); s:SetWidth(INNEN)
  s.balken = s:CreateTexture(nil, "ARTWORK"); s.balken:SetSize(4, 16); s.balken:SetPoint("TOPLEFT", 0, -2)
  s.balken:SetColorTexture(farbe[1], farbe[2], farbe[3], 1)
  s.titel = text(s, 12); s.titel:SetPoint("TOPLEFT", 12, -4)
  s.zahl = text(s, 12, F.grau); s.zahl:SetPoint("LEFT", s.titel, "RIGHT", 8, 0)
  s.rechts = text(s, 10, F.grau); s.rechts:SetPoint("TOPRIGHT", 0, -5); s.rechts:SetJustifyH("RIGHT")
  -- Scan-Hinweis (20 hoch)
  s.hinweis = CreateFrame("Frame", nil, s); s.hinweis:SetSize(INNEN, 20)
  s.hinweis.t = text(s.hinweis, 10, { 0.976, 0.451, 0.086 }); s.hinweis.t:SetPoint("LEFT", 0, 0)
  s.hinweis.l = link(s.hinweis, 10, function() if s.scanIds then sucheText((namenListe(s.scanIds))) end end,
    { "Diese Items im AH suchen", "Zuerst ins TSM-Suchfeld klicken, dann hier. Danach stimmen die Preise (Live-Preis aus der Suche)." })
  s.hinweis.l:SetPoint("LEFT", s.hinweis.t, "RIGHT", 4, 0); s.hinweis.l:Text("Jetzt suchen"); s.hinweis:Hide()
  -- Leere Karte
  s.leer = CreateFrame("Frame", nil, s); s.leer:SetSize(INNEN, KARTE_H); flaeche(s.leer, 0.02)
  s.leer.t = text(s.leer, 10, F.grau); s.leer.t:SetPoint("CENTER"); s.leer.t:SetJustifyH("CENTER"); s.leer.t:SetWidth(INNEN - 16)
  s.leer:Hide()
  s.mehr = text(s, 10, F.grau)
  -- „+ N weitere“ aufklappen / zuklappen (2.50, Befund 1/17); Karten werden bei Bedarf nachgebaut
  s.mehrLink = link(s, 10, function() s.offen = not s.offen; GF.aktualisieren() end, { "Alle zeigen / zuklappen" })
  s.mehrLink:Hide()
  s.max, s.kMax, s.kachelFarbe = anzahlKarten, anzahlKacheln or 0, kachelFarbe or farbe
  s.karten = {}
  for k = 1, anzahlKarten do s.karten[k] = karte(s); s.karten[k]:Hide() end
  s.kacheln = {}
  for k = 1, (anzahlKacheln or 0) do s.kacheln[k] = kachel(s, kachelFarbe or farbe); s.kacheln[k]:Hide() end
  -- Zeile 2 (2.53): Werkzeuge – links „Im AH prüfen“ + Info, rechts eigene Links (Befund 31/33)
  s.z2 = CreateFrame("Frame", nil, s); s.z2:SetSize(INNEN, 16); s.z2:SetPoint("TOPLEFT", 0, -22); s.z2:Hide()
  s.z2.pruef = link(s.z2, 10, function() if s.pruefIds then GF.pruefen(s.pruefIds) end end,
    { "Im AH prüfen", "Gold Forever sucht die Items dieses Abschnitts selbst im AH (etwa 2 Sek. je Item). Danach stimmen die Preise." })
  s.z2.pruef:SetPoint("LEFT", 0, 0)
  s.z2.info = text(s.z2, 10, F.grau); s.z2.info:SetPoint("LEFT", 0, 0)
  s.hoehe = 20
  return s
end
-- Zeile 2 setzen: ids = Items für „Im AH prüfen“ (nur am AH), info = Text, rechts = true, wenn rechts Links stehen
local function zeile2(s, ids, info, rechts)
  local zeigeLink = GF.ah ~= nil and ids and #ids > 0
  s.pruefIds = ids
  local an = zeigeLink or (info and info ~= "") or rechts
  s.z2:SetShown(an and true or false)
  s.oben = an and 44 or 28
  s.z2.pruef:SetShown(zeigeLink and true or false)
  if zeigeLink then
    local k, n = GF.pruefStand()
    s.z2.pruef:Text(k and ("prüfe " .. k .. "/" .. n .. " …") or ("Im AH prüfen (" .. #ids .. ")"))
  end
  s.z2.info:ClearAllPoints()
  if zeigeLink then s.z2.info:SetPoint("LEFT", s.z2.pruef, "RIGHT", 12, 0) else s.z2.info:SetPoint("LEFT", 0, 0) end
  s.z2.info:SetText(info or "")
end
local function idsVon(liste) local t = {}; for _, e in ipairs(liste or {}) do if e.id and not e.grau then t[#t + 1] = e.id end end; return t end
-- titel, zahl (oder nil), rechts (Text oder nil)
local function kopfSetzen(s, titel, zahl, rechts)
  s.titel:SetText(titel)
  s.zahl:SetText((zahl and zahl > 0) and tostring(zahl) or "")
  s.rechts:SetText(rechts or "")
end
-- liste: Karten-Einträge; opt = {leer = Text, scan = {ids}, scanText}
local function fuelle(s, liste, opt)
  opt = opt or {}
  local y = s.oben or 28
  s.scanIds = opt.scan
  if opt.scan and #opt.scan > 0 then
    s.hinweis:ClearAllPoints(); s.hinweis:SetPoint("TOPLEFT", 0, -y)
    s.hinweis.t:SetText(opt.scanText or ""); s.hinweis:Show()
    y = y + 24
  else s.hinweis:Hide() end
  local max = s.offen and #liste or (s.max or #s.karten)
  local n = math.min(#liste, max)
  for k = #s.karten + 1, n do s.karten[k] = karte(s); s.karten[k]:Hide() end
  for k, z in ipairs(s.karten) do
    if k <= n then
      setzeKarte(z, liste[k]); z:ClearAllPoints(); z:SetPoint("TOPLEFT", 0, -(y + (k - 1) * KARTE_TAKT))
    else z:Hide() end
  end
  s.leer:Hide(); s.mehr:SetText(""); s.mehrLink:Hide()
  if n > 0 then
    y = y + n * KARTE_TAKT - 4
    if #liste > n or (s.offen and #liste > (s.max or 0)) then
      s.mehrLink:ClearAllPoints(); s.mehrLink:SetPoint("TOPLEFT", 0, -(y + 4))
      s.mehrLink:Text(#liste > n and ("+ " .. (#liste - n) .. " weitere  ·  aufklappen") or "zuklappen")
      s.mehrLink:Show()
      y = y + 20
    end
  elseif opt.leer then
    s.leer:ClearAllPoints(); s.leer:SetPoint("TOPLEFT", 0, -y); s.leer.t:SetText(opt.leer); s.leer:Show()
    y = y + KARTE_H
  else
    y = y - 8 -- nur Kopf
  end
  s.hoehe = y
  s:SetHeight(y)
end
-- kacheln: {id, n, x (Kurztext), haken, weg, hinweis}
local function fuelleKacheln(s, liste)
  if #liste == 0 then for _, kn in ipairs(s.kacheln) do kn:Hide() end; return end
  local start = s.hoehe + 8
  local platz = s.kachelnOffen and #liste or (s.kMax or #s.kacheln)
  for k = #s.kacheln + 1, math.min(#liste, platz) do s.kacheln[k] = kachel(s, s.kachelFarbe); s.kacheln[k]:Hide() end
  local zeigen = math.min(#liste, platz)
  local plus = #liste > platz
  for k, kn in ipairs(s.kacheln) do
    local e = liste[k]
    if k <= zeigen and e then
      local r, sp = math.floor((k - 1) / KACHEL_PRO_REIHE), (k - 1) % KACHEL_PRO_REIHE
      kn:ClearAllPoints(); kn:SetPoint("TOPLEFT", sp * KACHEL_TAKT, -(start + r * KACHEL_REIHE))
      if plus and k == zeigen then
        kn.itemId = nil; kn.icon:Hide(); kn.n:SetText(""); kn.x:SetText(""); kn.haken:Hide(); kn.plusTile = true
        kn.plus:SetText("+" .. (#liste - zeigen + 1))
      else
        kn.plusTile = nil
        kn.itemId, kn.weg, kn.hinweis, kn.prognose = e.id, e.weg, e.hinweis, e.prognose
        kn.icon:Show(); kn.icon:SetTexture(itemIcon(e.id)); kn.plus:SetText("")
        kn.n:SetText(e.n and tostring(e.n) or ""); kn.x:SetText(e.x or "")
        kn.haken:SetShown(e.haken and true or false)
      end
      kn:Show()
    else kn:Hide() end
  end
  local reihen = math.ceil(zeigen / KACHEL_PRO_REIHE)
  s.hoehe = start + reihen * KACHEL_REIHE - 4
  s:SetHeight(s.hoehe)
end
-- Abschnitte untereinander, 20 Abstand; liefert die Gesamthöhe
local function stapeln(view, teile)
  local y = 0
  for _, t in ipairs(teile) do
    if t:IsShown() then
      if y > 0 then y = y + ABSTAND end
      t:ClearAllPoints(); t:SetPoint("TOPLEFT", view, "TOPLEFT", 0, -y)
      y = y + (t.hoehe or t:GetHeight() or 0)
    end
  end
  return y
end

-- ---------------------------------------------------------------- Daten: Gründe kurz und grau
local function kurzGrund(e)
  if e.reset then return H.orange .. "Preissprung " .. GF.faktor(e.faktor) .. ENDE end
  local g = e.grund or ""
  if g:find("fällt") then return grau("Preis fällt") end
  if g:find("erst morgen") then return grau("Tageshoch erst morgen") end
  if g:find("Tageshoch") then return grau("Tageshoch") end
  if g:find("über") then return grau("über üblich") end
  return ""
end
local function wannKurz(e)
  local g = e.grund or ""
  if g:find("steigt") then return "steigt" end
  if g:find("fällt") then return "fällt" end
  if g:find("unter") then return "Preis tief" end
  local tf = GF.tagesfenster()
  if tf then local h = tonumber(date("%H")); return (h < tf.vVon and "ab " or "mrg ") .. tf.vVon .. " Uhr" end
  return ""
end
local function zeitKurz(id, art)
  local z = GF.zeit(id) or {}
  local t = z.t or 0
  local phase = (art == "verk") and "hoch" or "tief"
  if z.ph == phase and z.d and z.h then
    local rest = math.floor(z.d - z.h + 0.5)
    return rest >= 1 and ("noch ~" .. rest .. " Std.") or "endet bald"
  end
  if art == "verk" then
    if t <= -10 then return "fällt – heute" end
    if t >= 10 then return "steigt noch" end
  else
    if t >= 10 then return "steigt – bald" end
    if t <= -10 then return "fällt noch" end
  end
  if z.ph == phase and (z.h or 0) >= 1 then return "seit " .. z.h .. " Std." end
  local tf = GF.tagesfenster()
  if tf then
    if art == "verk" then return tf.jetztVerk and "jetzt Tageshoch" or ("hoch " .. tf.vVon .. "–" .. tf.vBis .. " Uhr") end
    return tf.jetztKauf and "jetzt Tagestief" or ("billiger " .. tf.kVon .. "–" .. tf.kBis .. " Uhr")
  end
  return ""
end
local function verb(farbe, s) return H[farbe] .. s .. ENDE end
local function mit(a, b) if not b or b == "" then return a end; if not a or a == "" then return b end; return a .. H.grau .. "  ·  " .. ENDE .. b end
local function keinKaufText()
  local tf = GF.tagesfenster()
  return "Gerade ist nichts deutlich unter dem üblichen Preis." .. (tf and (" Meist am günstigsten " .. tf.kVon .. "–" .. tf.kBis .. " Uhr.") or "")
end

-- ---------------------------------------------------------------- Daten: Reiter „Standard"
-- Jedes Item genau einmal. Raid-Ware (GoldForeverData.raid) steht nur im Reiter „Raid & Events".
-- Qualität und Risiko haben noch keine Regeln: bis dahin landet alles hier.
local function standardDaten()
  local verkauftGesehen = {}
  local d = { jetzt = {}, spaeter = {}, warte = {}, kauf = {}, aufk = {}, scan = {}, ahL = {}, ahWert = 0, ahGewinn = 0, haltWert = 0 }
  local posN = {}
  for _, p in ipairs(GF.positionen()) do
    posN[p.id] = p.n
    if not GF.raid(p.id) then
      local pl = GF.verkaufsPlan(p) or { art = "halt", kurz = "", lang = "" }
      local gewinn, best = GF.erwartGewinn(p, pl)
      local orte = GF.lagerorte(p.id, { post = (p.post or 0), ah = p.imAH or 0 })
      local e = { id = p.id, n = p.n, gekauft = true, betrag = plusMinus(gewinn), wert = gewinn, orte = orte }
      if best and best ~= gewinn then
        e.hinweis = "Erwarteter Gewinn mit realistischem Verkaufspreis (üblich bzw. Marktwert). Bestfall zu deinem Preis: " .. (best >= 0 and "+" or "-") .. GF.geld(math.abs(best)) .. "."
      end
      -- Ware im Briefkasten (gekauft oder zurückgekommen): eigene Aufgabe unter „Verkaufen“ (2.50, Befund 19)
      local postWare = math.max(0, (p.post or 0) - (p.verkauftPost or 0))
      if postWare > 0 and not pl.verkauft then
        local danach = (p.imAH or 0) > 0 or pl.art == "verk"
        local pw = math.floor(gewinn * postWare / math.max(1, p.n))
        d.jetzt[#d.jetzt + 1] = { id = p.id, n = postWare, gekauft = true, orte = { post = postWare }, wert = pw, betrag = plusMinus(pw),
          zeile2 = mit(verb("gruen", danach and "Aus der Post holen und einstellen" or "Aus der Post holen"), danach and "" or grau("danach plant Gold Forever")),
          hinweis = postWare .. " Stück liegen im Briefkasten. Abholen" .. (danach and " und wie die übrige Ware einstellen." or " – danach erscheint der Verkaufsplan.") }
      end
      if pl.post then
        -- alles liegt im Briefkasten: steht schon oben als Aufgabe
      elseif pl.art == "verk" then
        local warum = (pl.abbrechen and (pl.lang:find("fällt") and verb("orange", "unterboten, Preis fällt seit Tagen") or verb("orange", "dein Preis zu hoch")))
          or pl.stop and verb("orange", "Verlust begrenzen") or pl.spitze and grau("Preisspitze")
          or (pl.lang:find("Ziel erreicht") and grau("Ziel erreicht")) or (pl.lang:find("30 %%") and grau("+30 % Gewinn drin"))
          or (pl.lang:find("Tagen") and grau("liegt zu lange")) or (pl.abbrechen and verb("orange", "dein Preis zu hoch")) or ""
        local li = GF.info(p.id)
        if not (li and li.ahGeprueft) and not pl.stop then e.scan = true; d.scan[#d.scan + 1] = p.id end
        if nurBank(orte) then warum = mit(warum, grau("erst aus der Bank holen")) end
        if pl.abbrechen then
          e.aktion = { art = "cancel", id = p.id, text = "Abbrechen", tipp = (pl.lang or "") .. ". Gold Forever bricht die Auktion ab; die Ware kommt per Post zurück und erscheint dann hier zum Einstellen." }
          if pl.lang then e.hinweis = pl.lang end
        else
          e.aktion = { art = "post", id = p.id, preis = pl.preis, n = p.da, dauer = select(2, GF.einstellen(li or {})), text = "Einstellen", tipp = "Gold Forever stellt diese Ware jetzt selbst für " .. GF.geld(pl.preis) .. " je Stück ein (" .. (select(2, GF.einstellen(li or {})) or "24 Std.") .. "). TSM wird nicht gebraucht. Ein Klick = eine Auktion." }
        end
        e.ton = (pl.stop or pl.abbrechen) and F.orange or nil
        e.zeile2 = mit(verb((pl.stop or pl.abbrechen) and "orange" or "gruen", (pl.abbrechen and "Abbrechen, neu für " or "Einstellen für ") .. GF.geld(pl.preis)), warum)
        if pl.abbrechen then
          -- 2.52: Ware im AH steht im Unter-Reiter „Auktionshaus“
          e.orte = { ah = p.imAH or p.n }
          d.ahL[#d.ahL + 1] = e; d.ahWert = d.ahWert + math.floor((p.ahPreis or 0) * 0.95 * (p.imAH or 0)); d.ahGewinn = d.ahGewinn + gewinn
        else
          d.jetzt[#d.jetzt + 1] = e
        end
      elseif pl.verkauft then
        -- Verkauft: Das Gold kommt erst ca. 1 Std. nach dem Verkauf in den Briefkasten. Bis dahin nichts anzeigen,
        -- danach als Aufgabe unter „Verkaufen“. Zeitpunkt = erstes Mal als verkauft gesehen (je Charakter + Item).
        GoldForeverDB.verkauftSeit = GoldForeverDB.verkauftSeit or {}
        local key = GF.charKey() .. ":" .. p.id
        local seit = GoldForeverDB.verkauftSeit[key] or time()
        GoldForeverDB.verkauftSeit[key] = seit
        verkauftGesehen[key] = true
        if time() - seit >= 3600 then
          e.zeile2 = mit(verb("gruen", "Briefkasten leeren"), grau("Gold ist da"))
          e.hinweis = "Verkauft – das Gold liegt im Briefkasten. Erst nach dem Abholen zählt es in der Bilanz."
          d.jetzt[#d.jetzt + 1] = e
        end
      else
        if pl.post then e.zeile2 = mit(verb("blau", "Im Briefkasten"), grau("abholen"))
        elseif pl.imAH or pl.kurz == "im AH, unterboten" then
          e.zeile2 = mit(verb("blau", "Liegt im AH" .. (p.ahPreis and (" für " .. GF.geld(p.ahPreis)) or "")),
            pl.imAH and grau("warten, bis verkauft") or verb("orange", "unterboten – nach Ablauf neu einstellen"))
        else e.zeile2 = mit(verb("blau", "Halten bis " .. GF.geld(p.ziel)), grau("Gold Forever meldet sich")) end
        if not pl.post then e.prognose = GF.prognose(p.id, p) end
        if pl.imAH or pl.kurz == "im AH, unterboten" then
          if pl.kurz == "im AH, unterboten" then e.ton = F.orange end
          if (p.imAH or 0) > 0 then e.n = p.imAH; e.orte = { ah = p.imAH } end
          d.ahL[#d.ahL + 1] = e; d.ahWert = d.ahWert + math.floor((p.ahPreis or 0) * 0.95 * (p.imAH or 0)); d.ahGewinn = d.ahGewinn + gewinn
        else
          local li2 = p.i or GF.info(p.id)
          e.aktWert = math.floor((GF.wert(li2) or 0) * p.n); d.haltWert = d.haltWert + e.aktWert
          d.spaeter[#d.spaeter + 1] = e
        end
      end
    end
  end
  -- Alte „verkauft seit“-Merker dieses Charakters aufräumen (Briefkasten geleert)
  local ich = GF.charKey() .. ":"
  for key in pairs(GoldForeverDB.verkauftSeit or {}) do
    if key:sub(1, #ich) == ich and not verkauftGesehen[key] and not GF.raid(tonumber(key:sub(#ich + 1))) then GoldForeverDB.verkauftSeit[key] = nil end
  end
  -- Gekaufte Ware eines anderen Charakters: nur zur Info
  for _, p in ipairs(GF.fremdePos or {}) do
    if not GF.raid(p.id) then
      local wer = (p.char == "?" and "anderem Charakter" or p.char)
      d.spaeter[#d.spaeter + 1] = { id = p.id, n = p.n, grau = true, gekauft = true, wert = -1, orte = { char = p.n },
        zeile2 = grau("bei " .. wer .. " · dort erledigen"),
        hinweis = "Diese Ware hat ein anderer Charakter gekauft. Der Verkaufsplan erscheint, wenn du mit " .. (p.char == "?" and "ihm" or p.char) .. " online bist." }
    end
  end
  -- Eigene Auktionen (nicht nach Vorschlag gekauft), deutlich unterboten: abbrechen, neu einstellen
  local A = GF.ahDaten()
  for id, x in pairs((A and A.items) or {}) do
    id = tonumber(id)
    if not posN[id] and not GF.raid(id) and x.preis and x.n and x.n > 0 then
      local i = GF.info(id)
      local z = GF.zeit(id) or {}
      local tf = GF.tagesfenster()
      local grenze = i and i.p and math.max(i.p * 1.15, i.p * (1 + ((tf and tf.spanne) or 0) / 100) * 1.05, z.q3 or 0)
      local erl = math.floor(x.preis * 0.95 * x.n)
      d.ahWert = d.ahWert + erl; d.ahGewinn = d.ahGewinn + erl
      if not (i and i.p and i.p > 0 and x.preis > grenze) then
        -- liegt normal im AH
        d.ahL[#d.ahL + 1] = { id = id, n = x.n, wert = erl, betrag = H.hell .. betrag(erl) .. ENDE, orte = { ah = x.n },
          zeile2 = mit(verb("blau", "Liegt im AH für " .. GF.geld(x.preis)), grau("warten, bis verkauft")),
          hinweis = x.n .. " Stück im AH für je " .. GF.geld(x.preis) .. ". Nach Gebühr ca. " .. GF.geld(erl) .. "." }
      end
      if i and i.p and i.p > 0 and x.preis > grenze then
        local neu = math.max(1, i.p - 1)
        local e = { id = id, n = x.n, wert = math.floor(neu * 0.95 * x.n), betrag = H.hell .. betrag(math.floor(neu * 0.95 * x.n)) .. ENDE,
          ton = F.orange, orte = { ah = x.n },
          zeile2 = mit(verb("orange", "Abbrechen, neu für " .. GF.geld(neu)), grau("dein Preis " .. GF.geld(x.preis) .. " – unterboten")),
          aktion = { art = "cancel", id = id, text = "Abbrechen", tipp = "Gold Forever bricht deine teuerste Auktion dieses Items ab; die Ware kommt per Post zurück." },
          hinweis = "Deine Auktion für " .. GF.geld(x.preis) .. " ist unterboten – günstigstes Angebot " .. GF.geld(i.p) .. ". Auch zum Tageshoch lag der Preis nicht so hoch (höchstens ~" .. GF.geld(math.floor(grenze)) .. "). In TSM „Meine Auktionen“ abbrechen und für " .. GF.geld(neu) .. " neu einstellen (Einstellgebühr ist dann weg)." }
        d.ahL[#d.ahL + 1] = e
      end
    end
  end
  -- Eigene Ware: jetzt einstellen (grün) oder warten (blaue Kacheln)
  for _, v in ipairs(GF.verkaufListe()) do
    local n = v.n - (posN[v.id] or 0)
    if n > 0 and not GF.raid(v.id) then
      local preis, dauer = GF.einstellen(v.i)
      do
        local erloes = math.floor(v.w * n)
        local orte = GF.lagerorte(v.id)
        local grund = kurzGrund(v.e)
        if nurBank(orte) then grund = mit(grund, grau("erst aus der Bank holen")) end
        local e = { id = v.id, n = n, betrag = H.hell .. betrag(erloes) .. ENDE, wert = erloes, weg = true, orte = orte,
          ton = v.e.reset and F.orange or nil, bank = nurBank(orte),
          aktion = preis and { art = "post", id = v.id, preis = preis, n = n, dauer = dauer, text = "Einstellen", tipp = "Gold Forever stellt diese Ware jetzt selbst für " .. GF.geld(preis) .. " je Stück ein (" .. (dauer or "24 Std.") .. "). TSM wird nicht gebraucht. Ein Klick = eine Auktion." } or nil,
          zeile2 = mit(verb("gruen", "Einstellen für " .. (preis and GF.geld(preis) or "")), grund) }
        if not v.i.ahGeprueft and not v.e.reset then e.scan = true; d.scan[#d.scan + 1] = v.id end
        d.jetzt[#d.jetzt + 1] = e
      end
    end
  end
  for _, v in ipairs(GF.warteListe()) do
    local n = v.n - (posN[v.id] or 0)
    if n > 0 and not GF.raid(v.id) then
      -- Kachel-Text (2.52, Wunsch Alex: „tief“/„ab 9“ war unverständlich): „Preis tief“ = gerade unter üblich, warten;
      -- „ab 9 Uhr“ = dann ist meist Tageshoch, dann einstellen; „steigt“/„fällt“ = aktueller Trend
      local wk = wannKurz(v.e)
      local erkl = (wk == "Preis tief" and "Warten: Der Preis liegt gerade unter üblich – Gold Forever meldet sich, wenn er zurück ist.")
        or (wk:find("Uhr") and ("Warten bis " .. wk:gsub("mrg", "morgen") .. ": dann ist meist Tageshoch – erst dann einstellen."))
        or (wk == "steigt" and "Warten: Der Preis steigt gerade.") or ""
      d.warte[#d.warte + 1] = { id = v.id, n = n, wert = math.floor(v.w * n), x = wk, weg = true, hinweis = erkl .. (erkl ~= "" and "\n" or "") .. (v.e.grund or ""), prognose = GF.prognose(v.id) }
      d.haltWert = d.haltWert + math.floor(v.w * n)
    end
  end
  -- Dringendes (orange) oben, Ware nur in der Bank unten, sonst nach Wert
  table.sort(d.jetzt, function(a, c)
    if (a.ton ~= nil) ~= (c.ton ~= nil) then return a.ton ~= nil end
    if (a.bank and true or false) ~= (c.bank and true or false) then return not a.bank end
    return (a.wert or 0) > (c.wert or 0)
  end)
  -- Halten sortieren (2.52): Gewinn absteigend (Standard), Gewinn aufsteigend oder A–Z
  local hs = GoldForeverDB.haltSort or "ab"
  local function nm(e) return itemName(e.id) or "" end
  local function sortier(a, c)
    if hs == "az" then return nm(a) < nm(c) end
    if hs == "auf" then return (a.wert or 0) < (c.wert or 0) end
    return (a.wert or 0) > (c.wert or 0)
  end
  table.sort(d.warte, sortier)
  table.sort(d.spaeter, sortier)
  table.sort(d.ahL, function(a, c)
    if (a.ton ~= nil) ~= (c.ton ~= nil) then return a.ton ~= nil end
    return (a.wert or 0) > (c.wert or 0)
  end)

  -- Einkaufen: Budget-Plan (Raid-Vorrat steht im Reiter „Raid & Events")
  local P = (GF.ah and GF.ah.plan) or GF.budgetPlan()
  d.budget = P.budget
  -- zu teuer = die geplante Menge gibt es im AH nicht mehr bis zum Höchstpreis (nicht nur das billigste Einzelstück)
  -- immer true/false (nil/false gemischt machte table.sort ungültig -> Standard-Ansicht leer, 2.51)
  local function zuTeuer(x) local l = GF.kaufPreis(x.id, math.max(1, x.menge - GF.gekauft(x.id))); return (l and l > x.maxKauf) and true or false end
  local deals = {}
  -- ausgeblendete Items sofort raus (am AH ist der Plan beim Öffnen festgehalten)
  for _, x in ipairs(P.deals) do if not GF.ausgeblendet(x.id) then deals[#deals + 1] = x end end
  table.sort(deals, function(x, y) if zuTeuer(x) ~= zuTeuer(y) then return not zuTeuer(x) end; return false end)
  d.kaufListe = {}
  -- 2.52: Unterbieter-Schnäppchen ganz oben (1–3 Stück weit unter üblich, Rest des Marktes normal)
  for _, u in ipairs(GF.unterbieterListe()) do
    d.kauf[#d.kauf + 1] = { id = u.id, n = u.n, betrag = plusMinus(u.gewinn), weg = true,
      hinweis = "Unterbieter: jemand bietet " .. u.n .. " Stück für bis " .. GF.geld(u.max) .. " an, üblich ist " .. GF.geld(u.R) .. ".\nAufkaufen und für " .. GF.geld(u.neu) .. " neu einstellen (nach Gebühr ca. +" .. GF.geld(u.gewinn) .. ").",
      zeile2 = mit(verb("lila", "Aufkaufen"), grau("Unterbieter · neu für " .. GF.geld(u.neu))),
      aktion = GF.istRohstoff(u.id) and { art = "buy", id = u.id, n = u.n, max = u.max, text = "Kaufen " .. u.n .. "×",
        tipp = "Klick 1: Preis anfragen, Klick 2 („OK …“): kaufen. Danach unter Verkaufen für " .. GF.geld(u.neu) .. " einstellen." } or nil }
  end
  for _, x in ipairs(deals) do
    local g2 = GF.gekauft(x.id)
    local live = GF.kaufPreis(x.id, math.max(1, x.menge - g2))
    local e0 = GF.empfehlung(x.id, x.i, true)
    local erq = GF.erholung(x.id, x.i)
    local hinweis = "Warum: " .. ((e0 and e0.grund) or "unter üblich") .. (erq and (", erholt sich in " .. math.floor(erq * 100 + 0.5) .. " % der Fälle") or "")
      .. ".\nPlan: " .. x.menge .. "× bis " .. GF.geld(x.maxKauf) .. " kaufen, später um " .. GF.geld(x.ziel) .. " verkaufen."
    if zuTeuer(x) and GF.frisch(x.id) then
      -- 2.53 (Befund 34): frisch geprüft und zu teuer -> nicht mehr zeigen
      d.kaufWeg = (d.kaufWeg or 0) + 1
    elseif zuTeuer(x) then
      d.kauf[#d.kauf + 1] = { id = x.id, n = x.menge, grau = true, betrag = H.grau .. "—" .. ENDE, zeile2 = grau("zu teuer – überspringen"),
        hinweis = hinweis .. "\nDas Tief ist vorbei: im AH gerade " .. GF.geld(live) .. "." }
    else
      -- Menge passt sich an: schon gekauft wird abgezogen (Karte zeigt den Rest)
      local rest = x.menge - g2
      if rest <= 0 then
        d.kauf[#d.kauf + 1] = { id = x.id, n = x.menge, gekauft = true, betrag = H.lila .. "gekauft" .. ENDE, hinweis = hinweis,
          zeile2 = mit(verb("lila", "Fertig"), grau("liegt im Briefkasten bzw. in der Tasche")) }
      else
        local stueckGewinn = x.menge > 0 and x.gewinn / x.menge or 0
        local schon = g2 + (x.schon or 0)
        local lv = GF.live[x.id]
        local nurVoll = lv and lv.voll
        d.kauf[#d.kauf + 1] = { id = x.id, n = rest, betrag = plusMinus(math.floor(stueckGewinn * rest)), weg = true, gekauft = schon > 0, scan = nurVoll,
          aktion = GF.istRohstoff(x.id) and { art = "buy", id = x.id, n = rest, max = x.maxKauf, text = "Kaufen " .. rest .. "×",
            tipp = "Klick 1: Gold Forever fragt den echten Preis für " .. rest .. " Stück an. Klick 2 („OK …“): kaufen. Liegt der Preis über " .. GF.geld(x.maxKauf) .. " je Stück, bricht Gold Forever selbst ab." } or nil,
          hinweis = hinweis .. (nurVoll and "\nPreis nur aus dem Vollscan – billige Angebote sind oft schnell weg. Vor dem Kauf suchen (Klick auf die Karte)." or ""),
          zeile2 = mit(verb("lila", "Kaufen bis " .. GF.geld(x.maxKauf)), mit(schon > 0 and grau(schon .. " schon gekauft") or "",
            nurVoll and verb("orange", "aus Vollscan – vor dem Kauf suchen") or grau(live and ("im AH gerade " .. GF.geld(live)) or "jetzt, solange so günstig"))) }
        d.kaufListe[#d.kaufListe + 1] = x
      end
    end
  end

  -- Aufkäufer
  for id, z in pairs((GoldForeverData and GoldForeverData.zeit) or {}) do
    if z.rs then
      local i = GF.info(id)
      if i and (i.u or 0) >= 20 then
        local x = GF.aufkaeufer(id, i)
        if x then d.aufk[#d.aufk + 1] = { id = tonumber(id), x = GF.faktor(x), f = x, haken = GF.anzahl(id) > 0,
          hinweis = "Preissprung: Jemand hat das günstige Angebot leergekauft – Preis " .. GF.faktor(x) .. " gegenüber vorher " .. GF.geld(z.rs.v) .. ". Eigene Ware jetzt verkaufen, nicht kaufen – der Preis fällt meist bald zurück." } end
      end
    end
  end
  table.sort(d.aufk, function(a, c) return a.f > c.f end)
  -- Herstellen (2.53): eigene Rohstoffe -> Rezept bringt mehr; Zutaten kaufen -> herstellen -> verkaufen
  d.herst, d.herstIds = {}, {}
  local okH, eigen, kaufH = pcall(GF.herstellenListe)
  if okH then
    for _, x in ipairs(eigen) do
      local b = x.b
      d.herst[#d.herst + 1] = { id = x.id, n = x.n, betrag = plusMinus(x.mehr), wert = x.mehr, weg = true, orte = GF.lagerorte(x.id),
        zeile2 = mit(verb("gelb", "Herstellen: " .. (b.name or "?")), grau("+" .. GF.geld(math.floor(b.pro - x.w)) .. " je Stück mehr als Verkaufen")),
        hinweis = "Verarbeiten bringt je Stück ca. " .. GF.geld(math.floor(b.pro)) .. " statt " .. GF.geld(x.w) .. " beim Verkaufen" .. (b.beruf and b.beruf ~= "" and (" (" .. b.beruf .. ")") or "") .. "." }
      d.herstIds[#d.herstIds + 1] = x.id
    end
    for _, k in ipairs(kaufH) do
      local zut = {}
      for _, z in ipairs(k.r[5]) do zut[#zut + 1] = z[2] .. "× " .. itemName(z[1]); d.herstIds[#d.herstIds + 1] = z[1] end
      d.herst[#d.herst + 1] = { id = k.id, n = k.menge > 1 and math.floor(k.menge + 0.5) or nil, betrag = plusMinus(k.gewinn), wert = k.gewinn, weg = true, scan = not k.frisch,
        zeile2 = mit(verb("gelb", "Zutaten kaufen & herstellen"), grau("Kosten " .. GF.geld(math.floor(k.kosten)) .. " · Erlös " .. GF.geld(math.floor(k.erl)))),
        hinweis = "Zutaten: " .. table.concat(zut, ", ") .. ".\nKosten ca. " .. GF.geld(math.floor(k.kosten)) .. ", Verkauf nach Gebühr ca. " .. GF.geld(math.floor(k.erl)) ..
          (k.frisch and "" or "\nZutaten-Preise nicht frisch – erst im AH prüfen.") }
    end
  end
  local nRez = 0; for _ in pairs((GoldForeverDB.rezepte or {})[GF.charKey()] or {}) do nRez = nRez + 1 end
  d.herstInfo = nRez > 0 and (H.grau .. nRez .. " eigene Rezepte" .. ENDE) or (H.orange .. "Berufsfenster einmal öffnen – dann kennt GF deine Rezepte" .. ENDE)
  if nRez == 0 then d.herstLeer = "Noch keine eigenen Rezepte bekannt. Öffne einmal jedes Berufsfenster (z. B. Alchemie), dann rechnet Gold Forever mit deinen Rezepten." end
  return d
end

-- ---------------------------------------------------------------- Daten: Reiter „Raid & Events"
local function eventsSortiert()
  local out = {}
  for _, e in ipairs((GoldForeverData and GoldForeverData.events) or {}) do
    local bis = GF.tageBis(e[3] or e[2])
    if e[4] ~= "raid" and bis and bis >= 0 then
      out[#out + 1] = { titel = e[1], vonDatum = e[2], bisDatum = e[3] or e[2], von = GF.tageBis(e[2]), bis = bis, items = e[5] or {} }
    end
  end
  table.sort(out, function(a, b) return a.von < b.von end)
  return out
end
local function tage(von, bis)
  local r = GF.resetTag()
  return GF.WT[(r + von) % 7 + 1] .. "–" .. GF.WT[(r + bis) % 7 + 1]
end
local function raidDaten()
  local D = GoldForeverData or {}
  local d = { kauf = {}, ware = {}, event = {}, jetzt = 0, kaufListe = {} }
  d.start = datum(D.raidstart)
  d.laeuft = GF.raidLaeuft()
  d.verkTage, d.kaufTage = tage(-1, 1), tage(2, 4)
  -- 1. Kaufen
  local okR, RP = pcall(GF.raidPlan)
  for _, k in ipairs((okR and RP and RP.plan) or {}) do
    if not GF.ausgeblendet(k.id) then
    d.kauf[#d.kauf + 1] = { id = k.id, n = k.menge, betrag = plusMinus(k.gewinn), weg = true,
      zeile2 = mit(verb("lila", "Kaufen bis " .. GF.geld(k.maxKauf)), grau(zeitKurz(k.id, "kauf"))),
      hinweis = "Raid-Vorrat: " .. k.menge .. "× bis " .. GF.geld(k.maxKauf) .. " kaufen, ab Raidstart (" .. d.start .. ") um " .. GF.geld(k.ziel) .. " verkaufen." }
    d.kaufListe[#d.kaufListe + 1] = k
    end
  end
  -- 2. Deine Raid-Ware: Taschen, Bank und nach Vorschlag gekaufte Raid-Ware (auch im AH / in der Post)
  local gesehen, summe = {}, 0
  local function dazu(id, rk, p)
    if gesehen[id] then return end
    local i = GF.info(id); local e = i and GF.empfehlung(id, i)
    local n = p and p.n or GF.anzahl(id)
    if not e or n <= 0 then return end
    gesehen[id] = true
    local w = (GF.verkaufswert(i) or 0) * n
    summe = summe + w
    local orte = GF.lagerorte(id, p and { post = p.post or 0, ah = p.imAH or 0 } or nil)
    local wer = (rk[3] and rk[3] ~= "") and rk[3] or (rk[2] or "")
    local zeile, ton
    if e.position and e.plan then
      local pl = e.plan
      if pl.art == "verk" then
        zeile = verb(pl.stop and "orange" or "gruen", (pl.abbrechen and "Abbrechen, neu für " or "Einstellen für ") .. GF.geld(pl.preis))
        ton = pl.stop and F.orange or nil
        d.jetzt = d.jetzt + 1
      elseif pl.verkauft then
        -- wie bei Standard: erst 1 Std. nach dem Verkauf als „Briefkasten leeren“ zeigen
        GoldForeverDB.verkauftSeit = GoldForeverDB.verkauftSeit or {}
        local key = GF.charKey() .. ":" .. id
        local seit = GoldForeverDB.verkauftSeit[key] or time()
        GoldForeverDB.verkauftSeit[key] = seit
        if time() - seit < 3600 then gesehen[id] = true; summe = summe - w; return end
        zeile = verb("gruen", "Briefkasten leeren"); d.jetzt = d.jetzt + 1
      else zeile = verb("blau", "Halten " .. ohneFarbe(pl.kurz):gsub("^halten ", "")) end
    elseif e.art == "verk" then
      zeile = verb("gruen", "Einstellen für " .. GF.geld(GF.einstellen(i))); d.jetzt = d.jetzt + 1
    else
      zeile = verb("blau", d.laeuft and "Behalten" or ("Behalten bis " .. d.start))
    end
    local akt
    if e.position and e.plan and e.plan.art == "verk" then
      akt = e.plan.abbrechen and { art = "cancel", id = id, text = "Abbrechen", tipp = e.plan.lang or "" }
        or { art = "post", id = id, preis = e.plan.preis, n = p and p.da or n, dauer = select(2, GF.einstellen(i)), text = "Einstellen", tipp = "Gold Forever stellt diese Ware jetzt selbst für " .. GF.geld(e.plan.preis) .. " je Stück ein (" .. (select(2, GF.einstellen(i)) or "24 Std.") .. "). TSM wird nicht gebraucht. Ein Klick = eine Auktion." }
    elseif not e.position and e.art == "verk" then
      local pr, du = GF.einstellen(i)
      if pr then akt = { art = "post", id = id, preis = pr, n = n, dauer = du, text = "Einstellen", tipp = "Gold Forever stellt diese Ware jetzt selbst für " .. GF.geld(pr) .. " je Stück ein (" .. (du or "24 Std.") .. "). TSM wird nicht gebraucht. Ein Klick = eine Auktion." } end
    end
    d.ware[#d.ware + 1] = { id = id, n = n, gekauft = p and true or false, betrag = H.hell .. betrag(w) .. ENDE, wert = w, orte = orte, ton = ton, aktion = akt,
      zeile2 = mit(zeile, grau(wer)), weg = not p, prognose = (zeile:find("Halten") or zeile:find("Behalten")) and GF.prognose(id, p) or nil }
  end
  for _, p in ipairs(GF.positionen()) do local rk = GF.raid(p.id); if rk then dazu(p.id, rk, p) end end
  for id, rk in pairs(D.raid or {}) do id = tonumber(id); if GF.anzahl(id) > 0 then dazu(id, rk) end end
  table.sort(d.ware, function(a, b) if (a.ton ~= nil) ~= (b.ton ~= nil) then return a.ton ~= nil end; return a.wert > b.wert end)
  d.summe = summe
  -- 3. Event
  local ev = eventsSortiert()
  d.e1 = ev[1]
  if d.e1 then
    local aktiv = d.e1.von <= 0
    local liste = {}
    for _, sid in ipairs(d.e1.items) do
      local id = tonumber(sid); local i = id and GF.info(id)
      if i then liste[#liste + 1] = { id = id, i = i, n = GF.anzahl(id) } end
    end
    table.sort(liste, function(a, b)
      if (a.n > 0) ~= (b.n > 0) then return a.n > 0 end
      local qa = (a.i.p and a.i.r and a.i.r > 0) and a.i.p / a.i.r or 9
      local qb = (b.i.p and b.i.r and b.i.r > 0) and b.i.p / b.i.r or 9
      return qa < qb
    end)
    for _, v in ipairs(liste) do
      local w = GF.verkaufswert(v.i) or 0
      local e = { id = v.id, n = v.n > 0 and v.n or nil, orte = v.n > 0 and GF.lagerorte(v.id) or nil }
      if aktiv and v.n > 0 then e.betrag = H.hell .. betrag(w * v.n) .. ENDE; e.zeile2 = verb("gruen", "Jetzt verkaufen"); d.jetzt = d.jetzt + 1
      elseif v.n > 0 then e.betrag = H.hell .. betrag(w * v.n) .. ENDE; e.zeile2 = verb("blau", "Behalten bis " .. datum(d.e1.vonDatum))
      elseif not aktiv and v.i.p and v.i.r and v.i.p < v.i.r then e.betrag = H.hell .. betrag(v.i.p) .. ENDE; e.zeile2 = verb("lila", "Jetzt kaufen")
      else e.betrag = H.grau .. betrag(v.i.p or v.i.r) .. ENDE; e.zeile2 = grau(aktiv and "wird gerade gesucht" or "zu teuer, abwarten") end
      d.event[#d.event + 1] = e
    end
    d.eAktiv = aktiv
  end
  d.danach = {}
  for k = 2, math.min(#ev, 3) do d.danach[#d.danach + 1] = ev[k].titel .. " ab " .. datum(ev[k].vonDatum) end
  return d
end

-- Zahlen für Reiter und Minimap-Tooltip (zuletzt berechnet)
local zahlen = { standard = 0, qualitaet = 0, raid = 0, risiko = 0 }
function GF.reiterZahlen()
  if not zahlen.zeit then
    local ok1, s = pcall(standardDaten); local ok2, r = pcall(raidDaten)
    zahlen.standard = ok1 and #s.jetzt or 0; zahlen.raid = ok2 and r.jetzt or 0; zahlen.zeit = time()
  end
  return zahlen
end

-- ---------------------------------------------------------------- Ansichten
local ANSICHTEN = {}
local REITER = { { "standard", "Standard" }, { "qualitaet", "Qualität" }, { "raid", "Raid & Events" }, { "risiko", "Risiko" } }

-- Standard
function ANSICHTEN.standard(v, s, r)
  local d = s
  -- Herstellen (2.53)
  d.herst = d.herst or {}
  local zahl = { verk = #d.jetzt, herst = #d.herst, halt = #d.spaeter + #d.warte, ah = #d.ahL, kauf = #(d.kauf or {}) }
  -- Badge orange, wenn im AH etwas zu tun ist (unterboten / abbrechen)
  local ahTun = 0; for _, e in ipairs(d.ahL) do if e.ton then ahTun = ahTun + 1 end end
  local wahl = GoldForeverDB.unter
  if not zahl[wahl or ""] then wahl = "verk" end
  v.unter.wahl = wahl
  for _, b in ipairs(v.unter.b) do
    local an, n = b.key == wahl, zahl[b.key] or 0
    local c = an and F.hell or F.grau
    b.t:SetTextColor(c[1], c[2], c[3]); b.strich:SetShown(an)
    b.bg:SetColorTexture(b.farbe[1], b.farbe[2], b.farbe[3], an and 0.10 or 0.03)
    b.badge:SetShown(n > 0); b.halo:SetShown(n > 0)
    if b.key == "ah" then
      local c2 = ahTun > 0 and F.orange or b.farbe
      b.badge:SetColorTexture(c2[1], c2[2], c2[3], 1); b.halo:SetColorTexture(c2[1], c2[2], c2[3], 0.35)
    end
    b.badge:SetWidth(n >= 100 and 26 or n >= 10 and 20 or 14); b.halo:SetWidth(b.badge:GetWidth() + 6)
    b.zahl:SetText(n > 0 and tostring(n) or "")
  end
  -- Bank-Leiste (2.53): nur an der offenen Bank
  v.bank:SetShown(GF.bankOffen and true or false)
  -- Verkaufen
  kopfSetzen(v.jetzt, "Verkaufen", #d.jetzt)
  local ns = #d.scan
  zeile2(v.jetzt, idsVon(d.jetzt), (GF.ah and ns > 0) and (H.orange .. ns .. " Preis" .. (ns == 1 and "" or "e") .. " nicht frisch" .. ENDE) or nil)
  fuelle(v.jetzt, d.jetzt, { leer = "Gerade nichts zu verkaufen – alles liegt gut.", scan = (not GF.ah) and d.scan or nil,
    scanText = ns .. " von " .. #d.jetzt .. (ns == 1 and " Preis" or " Preisen") .. " noch nicht im AH geprüft  ·" })
  -- Herstellen
  kopfSetzen(v.herst, "Herstellen", #d.herst)
  zeile2(v.herst, GF.ah and d.herstIds or nil, d.herstInfo)
  fuelle(v.herst, d.herst, { leer = d.herstLeer or "Gerade lohnt kein Rezept mehr als Verkaufen." })
  -- Halten
  local na = GF.anzahlAusgeblendet()
  kopfSetzen(v.spaeter, "Halten", #d.spaeter + #d.warte)
  v.spaeter.rechts:SetText("")
  local ids = idsVon(d.spaeter); for _, e in ipairs(d.warte) do if e.id then ids[#ids + 1] = e.id end end
  zeile2(v.spaeter, ids, H.grau .. "Wert jetzt " .. ENDE .. H.hell .. betrag(d.haltWert) .. ENDE, true)
  local SORT = { ab = "Gewinn hoch", auf = "Gewinn tief", az = "A–Z" }
  v.haltSort:Text(SORT[GoldForeverDB.haltSort or "ab"] or "Gewinn hoch")
  v.einblenden:SetShown(na > 0); v.einblenden:Text(na .. " ausgeblendet")
  v.haltSort:ClearAllPoints()
  if na > 0 then v.haltSort:SetPoint("RIGHT", v.einblenden, "LEFT", -12, 0) else v.haltSort:SetPoint("RIGHT", v.spaeter.z2, "RIGHT", 0, 0) end
  v.tsmHalten:Hide()
  fuelle(v.spaeter, d.spaeter, { leer = (#d.warte == 0) and "Nichts zu halten." or nil })
  fuelleKacheln(v.spaeter, d.warte)
  -- Auktionshaus
  kopfSetzen(v.ah, "Auktionshaus", #d.ahL, #d.ahL > 0 and (H.grau .. "Erlös " .. ENDE .. H.hell .. betrag(d.ahWert) .. ENDE .. H.grau .. "  ·  Gewinn " .. ENDE .. plusMinus(d.ahGewinn)) or nil)
  zeile2(v.ah, idsVon(d.ahL), nil)
  fuelle(v.ah, d.ahL, { leer = "Nichts im Auktionshaus. („Meine Auktionen“ wird beim Öffnen des AH geladen.)" })
  -- Kaufen
  kopfSetzen(v.kauf, "Kaufen", #d.kauf)
  v.tsm:Hide()
  v.voll:SetShown(GF.ah ~= nil); v.voll:ClearAllPoints(); v.voll:SetPoint("TOPRIGHT", 0, -2)
  local ab = GF.vollscanBereitAb and GF.vollscanBereitAb()
  v.voll:Text(ab and ("Vollscan ab " .. date("%H:%M", ab)) or "Vollscan")
  zeile2(v.kauf, idsVon(d.kauf), (d.kaufWeg or 0) > 0 and grau(d.kaufWeg .. " nach Prüfung zu teuer – ausgeblendet") or nil)
  fuelle(v.kauf, d.kauf, { leer = keinKaufText() })
  v.aufk:Hide()
  -- nur der gewählte Abschnitt ist sichtbar
  v.jetzt:SetShown(wahl == "verk"); v.herst:SetShown(wahl == "herst"); v.spaeter:SetShown(wahl == "halt"); v.kauf:SetShown(wahl == "kauf"); v.ah:SetShown(wahl == "ah")
  GF.angezeigteKaeufe = d.kaufListe
  return stapeln(v, { v.bank, v.unter, v.jetzt, v.herst, v.spaeter, v.ah, v.kauf })
end

-- Qualität / Risiko: Platzhalter, bis der Regel-Chat die Einteilung festlegt (claude/reiter-kategorien.md)
local BEISPIEL = {
  qualitaet = { info = "Regeln für „Qualität“ folgen (teurere Items, größere Marge). Bis dahin Platzhalter – alle Items stehen unter „Standard“.",
    ids = { 13463, 13464, 8836 } },
  risiko = { info = "Regeln für „Risiko“ folgen (hoher Gewinn, Verlust möglich). Bis dahin Platzhalter – alle Items stehen unter „Standard“.",
    ids = { 8838, 3358, 13465 } },
}
local function platzhalter(art, v)
  local b = BEISPIEL[art]
  v.info.t:SetText(b.info)
  local function bsp(id, farbe, s) return { { id = id, platzhalter = true, grau = true, betrag = H.grau .. "—" .. ENDE,
    zeile2 = mit(verb(farbe, s), grau("Beispiel")), hinweis = "Platzhalter – die Regeln für diesen Reiter werden noch festgelegt." } } end
  kopfSetzen(v.jetzt, "Verkaufen"); fuelle(v.jetzt, bsp(b.ids[1], "gruen", "Einstellen für …"))
  kopfSetzen(v.spaeter, "Halten"); fuelle(v.spaeter, bsp(b.ids[2], "blau", "Halten bis …"))
  kopfSetzen(v.kauf, "Kaufen", nil, art == "risiko" and "max. —g im Risiko" or nil); fuelle(v.kauf, bsp(b.ids[3], "lila", "Kaufen bis …"))
  GF.angezeigteKaeufe = {}
  return stapeln(v, { v.info, v.jetzt, v.spaeter, v.kauf })
end
function ANSICHTEN.qualitaet(v) return platzhalter("qualitaet", v) end
function ANSICHTEN.risiko(v) return platzhalter("risiko", v) end

-- Raid & Events
function ANSICHTEN.raid(v, s, d)
  -- Plan als drei Schritte; der Schritt von heute hat einen Rahmen in seiner Farbe
  local aktiv = 1
  if d.laeuft then
    local a = GF.PLAN.dauer[GF.wochenOff() + 1]
    aktiv = (a == "verk" and 3) or (a == "kauf" and 1) or 2
  end
  local texte = d.laeuft and { d.kaufTage, "bis zum Reset", d.verkTage } or { "bis " .. d.start, "bis Raidstart", "ab " .. d.start .. ", " .. d.verkTage }
  local farben = { F.lila, F.blau, F.gruen }
  for k, kt in ipairs(v.schritte) do
    kt.wert:SetText(texte[k])
    kt.r:farbe(farben[k], 1); kt.r:zeigen(k == aktiv)
  end
  local t = GF.tageBis(GoldForeverData and GoldForeverData.raidstart)
  v.zeile:SetText(d.laeuft and ("Raid-Woche  ·  heute " .. GF.WT[tonumber(date("%w")) + 1]) or ("Raidstart " .. d.start .. "  ·  in " .. (t or "?") .. " Tagen"))
  kopfSetzen(v.kauf, d.laeuft and "Kaufen – günstig nachkaufen" or "Kaufen – Vorrat bis zum Raid", #d.kauf)
  v.tsm:SetShown(#d.kaufListe > 0)
  fuelle(v.kauf, d.kauf, { leer = d.laeuft and ("Heute kein Einkaufstag – günstig wird es wieder " .. d.kaufTage .. ".") or "Gerade nichts günstig genug." })
  kopfSetzen(v.ware, "Deine Raid-Ware", #d.ware, (#d.ware > 0) and ("Wert " .. betrag(d.summe)) or nil)
  fuelle(v.ware, d.ware, { leer = "Noch keine Raid-Ware in Taschen oder Bank." })
  if d.e1 then
    kopfSetzen(v.event, "Event – " .. d.e1.titel, nil, d.eAktiv and ("läuft bis " .. datum(d.e1.bisDatum)) or ("ab " .. datum(d.e1.vonDatum) .. " (in " .. d.e1.von .. " Tagen)"))
    fuelle(v.event, d.event, { leer = "Keine Preise zu den Event-Items." })
  else
    kopfSetzen(v.event, "Events"); fuelle(v.event, {}, { leer = "Kein Event in Sicht." })
  end
  v.danach:SetText(#d.danach > 0 and ("Danach:  " .. table.concat(d.danach, "  ·  ")) or ""); v.danach.hoehe = #d.danach > 0 and 16 or 0
  v.danach:SetShown(#d.danach > 0)
  GF.angezeigteKaeufe = d.kaufListe
  -- Schritte (44) + 8 + Zeile (16) + 20, danach die Abschnitte
  local y = 44 + 8 + 16 + ABSTAND
  local h = stapeln(v.unten, { v.kauf, v.ware, v.event })
  if v.danach:IsShown() then v.danach:ClearAllPoints(); v.danach:SetPoint("TOPLEFT", v.unten, "TOPLEFT", 0, -(h + 8)); h = h + 8 + 16 end
  v.unten:SetHeight(math.max(1, h))
  return y + h
end

-- Bilanz
local ZEITRAUM = { { "heute", "Heute" }, { "7", "7 Tage" }, { "30", "30 Tage" }, { "alle", "Gesamt" } }
local function sekundenFuer(z)
  if z == "heute" then local t = date("*t"); return t.hour * 3600 + t.min * 60 + t.sec end
  if z == "7" then return 7 * 86400 end
  if z == "30" then return 30 * 86400 end
  return nil
end
local function zeitpunkt(t) return GF.WT[tonumber(date("%w", t)) + 1] .. " " .. date("%d.%m. %H:%M", t) end
-- Verlauf: Einnahmen − Ausgaben je Stunde (Heute) bzw. je Tag (höchstens 30 Balken)
local VERLAUF_B, VERLAUF_H = 404, 36
local function verlaufDaten(wahl, liste, start)
  local jetzt = time()
  local t0 = date("*t", jetzt)
  local mitternacht = jetzt - (t0.hour * 3600 + t0.min * 60 + t0.sec)
  local d = { wert = {}, ein = {}, aus = {}, label = {} }
  local idx
  if wahl == "heute" then
    d.von, d.bis = {}, {}
    for h = 0, 23 do d.wert[h + 1], d.ein[h + 1], d.aus[h + 1] = 0, 0, 0; d.label[h + 1] = h .. "–" .. (h + 1) .. " Uhr"; d.von[h + 1], d.bis[h + 1] = mitternacht + h * 3600, mitternacht + (h + 1) * 3600 end
    idx = function(t) if t >= mitternacht then return math.min(24, math.floor((t - mitternacht) / 3600) + 1) end end
  else
    local tage = (wahl == "7" and 7) or (wahl == "30" and 30) or math.max(1, math.ceil((mitternacht + 86400 - (start or jetzt)) / 86400))
    local pro = math.max(1, math.ceil(tage / 30))
    local n = math.ceil(tage / pro)
    local anfang = mitternacht + 86400 - n * pro * 86400
    for k = 1, n do
      local a = anfang + (k - 1) * pro * 86400
      d.wert[k], d.ein[k], d.aus[k] = 0, 0, 0
      d.von = d.von or {}; d.bis = d.bis or {}; d.von[k], d.bis[k] = a, a + pro * 86400
      d.label[k] = (pro == 1) and (GF.WT[tonumber(date("%w", a)) + 1] .. " " .. date("%d.%m.", a)) or (date("%d.%m.", a) .. "–" .. date("%d.%m.", a + pro * 86400 - 1))
    end
    idx = function(t) if t >= anfang then return math.min(n, math.floor((t - anfang) / (pro * 86400)) + 1) end end
  end
  for _, e in ipairs(liste or {}) do
    local i = idx(e.x.t)
    if i and d.wert[i] then
      local w = e.wert or 0
      d.wert[i] = d.wert[i] + w
      if w >= 0 then d.ein[i] = d.ein[i] + w else d.aus[i] = d.aus[i] + w end
    end
  end
  return d
end
local function verlaufZeichnen(c, d)
  local n = #d.wert
  local luecke = n > 14 and 2 or 4
  local bw = math.max(2, math.floor((VERLAUF_B - (n - 1) * luecke) / n))
  local x0 = math.floor((VERLAUF_B - (n * bw + (n - 1) * luecke)) / 2) -- mittig, links und rechts gleich viel Rand
  local groesst, minus = 1, false
  for _, w in ipairs(d.wert) do groesst = math.max(groesst, math.abs(w)); if w < 0 then minus = true end end
  local mitte = minus and VERLAUF_H / 2 or VERLAUF_H -- Nulllinie: Mitte, oder unten, wenn nichts negativ ist
  local platz = mitte - 1
  c.linie:ClearAllPoints(); c.linie:SetPoint("TOPLEFT", 0, -mitte); c.linie:SetPoint("TOPRIGHT", 0, -mitte)
  for k, bk in ipairs(c.balken) do
    local w = d.wert[k]
    if w then
      local h = (w == 0) and 1 or math.max(2, math.floor(math.abs(w) / groesst * platz + 0.5))
      local x = x0 + (k - 1) * (bw + luecke)
      bk:ClearAllPoints(); bk:SetSize(bw, h)
      if w >= 0 then bk:SetPoint("BOTTOMLEFT", c, "TOPLEFT", x, -mitte) else bk:SetPoint("TOPLEFT", c, "TOPLEFT", x, -mitte - 1) end
      local farbe = (w > 0 and F.gruen) or (w < 0 and F.rot) or F.grau
      bk.t:SetColorTexture(farbe[1], farbe[2], farbe[3], 1); bk.t:SetAlpha(w == 0 and 0.3 or 0.7)
      bk.wert, bk.ein, bk.aus, bk.label, bk.von, bk.bis = w, d.ein[k], d.aus[k], d.label[k], d.von and d.von[k], d.bis and d.bis[k]
      bk:Show()
    else bk:Hide() end
  end
end

function ANSICHTEN.bilanz(v)
  local wahl = GoldForeverDB.bilanzZeit or "7"
  for _, b in ipairs(v.zeit) do
    local an = b.wert == wahl
    local c = an and F.gold or F.grau
    b.t:SetTextColor(c[1], c[2], c[3]); b.strich:SetShown(an)
  end
  local r = GF.bilanz(sekundenFuer(wahl))
  -- 2.53 (Wunsch Alex): Bilanz wie TSM – alle Käufe und Verkäufe, dazu „davon durch Gold Forever“
  local A = GF.handelZeitraum(sekundenFuer(wahl))
  v.ergebnis.wert:SetText(plusMinus(A.profit))
  local werte = {
    { "Verkauft (" .. A.nV .. ")", H.gruen .. "+" .. betrag(A.ein) .. ENDE },
    { "Gekauft (" .. A.nK .. ")", H.rot .. "-" .. betrag(A.aus) .. ENDE },
    { "davon durch Gold Forever", plusMinus(r.ergebnis) },
    { "Gekaufte Ware noch da", H.hell .. betrag(r.bestand) .. ENDE },
  }
  local filter = GF.bilanzFilter
  for k, kz in ipairs(v.vier) do
    kz.oben:SetText(werte[k][1]); kz.wert:SetText(werte[k][2])
    kz.r:farbe(F.gold, 0.8); kz.r:zeigen(filter and filter.art == kz.art or false)
  end
  -- Anteil-Leisten: Länge im Verhältnis zum größten der vier Werte
  local roh = { { A.ein, F.gruen }, { A.aus, F.rot }, { r.ergebnis, (r.ergebnis or 0) >= 0 and F.gruen or F.rot }, { r.bestand, F.hell } }
  local groesst = 1; for _, w in ipairs(roh) do groesst = math.max(groesst, math.abs(w[1] or 0)) end
  for k, kz in ipairs(v.vier) do
    local w = math.abs(roh[k][1] or 0)
    local laenge = math.floor(198 * w / groesst + 0.5)
    kz.fuell:SetShown(laenge > 0); kz.fuell:SetWidth(math.max(1, laenge))
    kz.fuell:SetColorTexture(roh[k][2][1], roh[k][2][2], roh[k][2][3], 0.7)
  end
  verlaufZeichnen(v.verlauf, verlaufDaten(wahl, A.liste, GF.bilanzDaten().start))
  -- Top-Verkauf / Top-Einkauf (wie TSM)
  v.jeReiter:SetText(H.grau .. "Top-Verkauf: " .. ENDE .. (A.topV and (H.hell .. itemName(A.topV.id) .. ENDE .. " " .. H.gruen .. "+" .. betrag(A.topV.w) .. ENDE) or "—") ..
    H.grau .. "   ·   Top-Einkauf: " .. ENDE .. (A.topK and (H.hell .. itemName(A.topK.id) .. ENDE .. " " .. H.rot .. "-" .. betrag(A.topK.w) .. ENDE) or "—"))
  -- Gold nach Herkunft (2.53)
  local hk = GF.geldHerkunft(sekundenFuer(wahl))
  local HK = { { "loot", "Loot" }, { "quest", "Quests" }, { "haendler", "Händler" }, { "ah", "AH" }, { "ahkauf", "AH-Käufe" }, { "haendlerkauf", "Händler-Kauf" }, { "sonst", "Sonstiges" } }
  local teile = {}
  for _, z in ipairs(HK) do local w = hk[z[1]] or 0; if w ~= 0 then teile[#teile + 1] = H.grau .. z[2] .. " " .. ENDE .. plusMinus(w) end end
  v.herkunft:SetText(H.gold .. "Gold nach Herkunft:  " .. ENDE .. (#teile > 0 and table.concat(teile, H.grau .. "  ·  " .. ENDE) or (H.grau .. "wird ab 2.53 mitgeschrieben" .. ENDE)))
  -- Geschäfte: alle, oder gefiltert nach Kachel (Art) bzw. Balken (Zeitraum)
  local zeilen = {}
  local WAS = { flip = { "gruen", "verkauft" }, farm = { "gruen", "Mehrerlös" }, kauf = { "lila", "gekauft" } }
  local function wannText(t) return GF.WT[tonumber(date("%w", t)) + 1] .. " " .. date("%d.%m. %H:%M", t) end
  if filter and filter.art == "bestand" then
    -- Ware noch da: gekaufte Ware, die noch nicht verkauft ist – mit Ort
    for _, p in ipairs(GF.positionen()) do
      local i = GF.info(p.id); local w = (GF.verkaufswert(i) or 0) * p.n
      local o = GF.lagerorte(p.id, { post = p.post or 0, ah = p.imAH or 0 })
      local orte = {}
      for _, ort in ipairs(ORTE) do if (o[ort.k] or 0) > 0 then orte[#orte + 1] = o[ort.k] .. " " .. ort.titel end end
      local kurz = (o.tasche or 0) > 0 and "Tasche" or ((o.bank or 0) + (o.kriegsmeute or 0)) > 0 and "Bank" or (o.ah or 0) > 0 and "im AH" or (o.post or 0) > 0 and "Post" or "?"
      zeilen[#zeilen + 1] = { id = p.id, n = p.n, mitte = H.grau .. kurz .. ENDE, betrag = H.hell .. betrag(w) .. ENDE, details = {
        { "Wo", table.concat(orte, ", ") ~= "" and table.concat(orte, ", ") or "unbekannt" },
        { "Gekauft", wannText(p.seit) },
        { "Einkauf je Stück", GF.geld(p.ek) },
        { "Ziel je Stück", GF.geld(p.ziel) },
        { "Wert heute", GF.geld(w) },
        { "Plan", ohneFarbe((GF.verkaufsPlan(p) or {}).kurz or "") },
      } }
    end
  else
    -- ohne Filter: Tagesbuch (wie TSM Activity Log); „Verkauft“/„Gekauft“: alle Geschäfte; „durch GF“: nur GF-Geschäfte
    if not filter then
      local tage = {}
      for tag, T in pairs(A.tage) do tage[#tage + 1] = { tag = tag, T = T } end
      table.sort(tage, function(a, c) return a.tag > c.tag end)
      for _, e in ipairs(tage) do
        local T = e.T
        local hkT = (GoldForeverDB.geld and GoldForeverDB.geld[GF.charKey()] or {})[e.tag] or {}
        zeilen[#zeilen + 1] = { tag = true, name = GF.WT[tonumber(date("%w", T.t)) + 1] .. " " .. date("%d.%m.", T.t), betrag = plusMinus(T.ein - T.aus),
          mitte = H.gruen .. "+" .. betragKurz(T.ein) .. ENDE .. H.grau .. " / " .. ENDE .. H.rot .. "-" .. betragKurz(T.aus) .. ENDE,
          details = { { "Verkauft", GF.geld(T.ein) .. " (" .. T.nV .. ")" }, { "Gekauft", GF.geld(T.aus) .. " (" .. T.nK .. ")" }, { "Saldo", GF.geld(T.ein - T.aus) },
            { "Gold aus Loot", GF.geld(hkT.loot or 0) }, { "Gold aus Quests", GF.geld(hkT.quest or 0) }, { "Händler", GF.geld((hkT.haendler or 0) + (hkT.haendlerkauf or 0)) } } }
      end
    end
    local quelle = (filter and (filter.art == "alleVerk" or filter.art == "alleKauf" or filter.von)) and A.liste or (filter and r.liste or {})
    for _, e in ipairs(quelle) do
      local x = e.x
      if not e.typ then e.typ = (x.art == "verk") and "flip" or "kauf"; e.n = x.n end
      local passt = (filter and filter.art == "gf") or (filter and filter.art == "alleVerk" and x.art == "verk") or (filter and filter.art == "alleKauf" and x.art == "kauf")
        or (filter and filter.von and x.t >= filter.von and x.t < filter.bis)
      if passt then
        local n = e.n or x.n
        local w = WAS[e.typ] or WAS.kauf
        local det = {
          { "Was", w[2] .. ((e.typ == "flip") and " (Flip)" or (e.typ == "farm") and " (eigene Ware)" or " (nach Vorschlag)") },
          { "Wann", wannText(x.t) },
          { "Wer", x.char or "?" },
          { "Menge", n .. " Stück" },
          { "Je Stück", GF.geld(math.abs(x.betrag or 0) / math.max(1, x.n)) },
          { e.typ == "farm" and "Gesamt (Erlös)" or "Gesamt", GF.geld(math.abs(e.typ == "farm" and math.floor((x.betrag or 0) * n / math.max(1, x.n)) or e.wert or 0)) },
        }
        if e.typ == "farm" and x.basis then det[#det + 1] = { "Vergleichspreis", GF.geld(x.basis) .. " je Stück" }; det[#det + 1] = { "Mehrerlös", GF.geld(e.wert) } end
        if e.typ ~= "kauf" then det[#det + 1] = { "Wo", "Auktionshaus, dann Briefkasten" } end
        zeilen[#zeilen + 1] = { id = x.id, n = n, betrag = plusMinus(e.wert), details = det,
          mitte = verb(w[1], w[2]) .. H.grau .. " " .. GF.WT[tonumber(date("%w", x.t)) + 1] .. " " .. date("%H:%M", x.t) .. ENDE }
      end
    end
  end
  local n = 0
  for k, z in ipairs(v.zeilen) do
    local e = zeilen[k]
    if e then
      n = k
      z.itemId, z.details = e.id, e.details
      if e.tag then
        z.icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01"); z.name:SetText(H.hell .. e.name .. ENDE)
      else
        z.icon:SetTexture(itemIcon(e.id))
        z.name:SetText(H.grau .. e.n .. "× " .. ENDE .. H.hell .. itemName(e.id) .. ENDE)
      end
      z.mitte:SetText(e.mitte); z.betrag:SetText(e.betrag)
      z:Show()
    else z:Hide() end
  end
  local titel = filter and ("Details: " .. (filter.titel or "")) or "Tagesbuch"
  kopfSetzen(v.liste, titel, #zeilen)
  v.alle:SetShown(filter ~= nil)
  v.liste.leer:SetShown(n == 0)
  v.liste.leer.t:SetText(filter and "Hier gibt es in diesem Zeitraum nichts." or "Noch keine Käufe oder Verkäufe in diesem Zeitraum.")
  v.liste.mehr:SetText("")
  local lh = 28 + (n > 0 and n * LISTE_H or KARTE_H)
  if #zeilen > n then
    v.liste.mehr:ClearAllPoints(); v.liste.mehr:SetPoint("TOPLEFT", 0, -(lh + 4)); v.liste.mehr:SetText("+ " .. (#zeilen - n) .. " weitere")
    lh = lh + 20
  end
  v.liste.hoehe = lh; v.liste:SetHeight(lh)
  local b = GF.bilanzDaten()
  local inserate = 0; for _, x in pairs(b.inserat) do inserate = inserate + (x.v or 0) end
  v.fuss:SetText(H.grau .. "Mitgeschrieben seit " .. zeitpunkt(b.start) .. (inserate > 0 and ("  ·  noch im AH nach Vorschlag: " .. inserate .. " Stück") or "") ..
    (r.ohne > 0 and ("\n" .. r.ohne .. (r.ohne == 1 and " Geschäft" or " Geschäfte") .. " ohne Vorschlag – nicht mitgezählt") or "") .. ENDE)
  -- Zeitraum 20, +8, Ergebnis 96, +8, 2 × 44 (+8), +8, Je Reiter 16, +20, Liste, +8, Fuß 32
  local y = 20 + 8 + 96 + 8 + 44 + 8 + 44 + 8 + 16 + 8 + 28 + ABSTAND
  v.liste:ClearAllPoints(); v.liste:SetPoint("TOPLEFT", 0, -y)
  y = y + lh + 8
  v.fuss:ClearAllPoints(); v.fuss:SetPoint("TOPLEFT", 0, -y)
  return y + 32
end

-- Test (nur Testphase)
local TESTPLAN = {
  { k = "einstellen", text = "10–13 Uhr: grüne Items einstellen", tipp = "Grün markierte Items aus Bank und Tasche über TSM einstellen. Preis: „Einstellen“ aus dem Gold-Forever-Tooltip." },
  { k = "kaufen", text = "Abends/nachts: Einkaufsplan kaufen", tipp = "Ins TSM-Suchfeld klicken, dann „In TSM suchen“ (Reiter Standard). Nur kaufen, was angezeigt wird. Keine Bauchkäufe." },
  { k = "post", text = "Briefkasten leeren", tipp = "Erst beim Öffnen des Briefkastens zählt die Bilanz deine Verkäufe." },
  { k = "positionen", text = "Gekaufte Ware nach Plan behandeln", tipp = "„Verkaufen“ abarbeiten, „Halten“ liegen lassen." },
  { k = "bank", text = "Blaue Items in die Bank", tipp = "Blau = behalten. Nicht verkaufen, bis sie grün werden." },
  { k = "reload", text = "Vor dem Ausloggen /reload", tipp = "WoW speichert Addon-Daten nur bei /reload oder Ausloggen. Danach kann Claude sie auswerten." },
}
local function testDB()
  GoldForeverDB.test = GoldForeverDB.test or {}
  local T = GoldForeverDB.test
  T.tage = T.tage or {}; T.notizen = T.notizen or {}
  local heute = date("%Y-%m-%d")
  T.tage[heute] = T.tage[heute] or { h = {} }
  return T, T.tage[heute]
end
function ANSICHTEN.test(v)
  local T, tag = testDB()
  local s = GF.testHeute()
  local auto = {
    einstellen = { s.einV > 0, s.einV .. " nach Vorschlag" .. (s.einO > 0 and (", " .. s.einO .. " ohne") or "") },
    kaufen = { s.kaufV > 0, s.kaufV .. " Käufe nach Vorschlag" .. (s.kaufO > 0 and (", " .. s.kaufO .. " ohne") or "") },
    post = { s.post, s.post and "heute geleert" or "noch nicht" },
    positionen = { false, s.pos .. " gekauft" .. (s.posVerk > 0 and (", " .. s.posVerk .. " jetzt verkaufen") or "") },
    bank = { false, "" }, reload = { false, "" },
  }
  local fertig = 0
  for n, p in ipairs(TESTPLAN) do
    local z = v.plan[n]
    local a = auto[p.k] or { false, "" }
    if a[1] and not tag.h[p.k] then tag.h[p.k] = "auto" end
    local an = tag.h[p.k] and true or false
    if an then fertig = fertig + 1 end
    z.an = an; z.k = p.k; z.tipp = p.tipp
    z.box.haken:SetShown(an)
    z.text:SetText((an and H.grau or H.hell) .. p.text .. ENDE)
    z.status:SetText(a[2] ~= "" and ((a[1] and H.gruen or H.grau) .. a[2] .. ENDE) or "")
  end
  tag.fertig = fertig
  v.kopf.titel:SetText("Testplan · " .. GF.WT[tonumber(date("%w")) + 1] .. " " .. date("%d.%m."))
  v.kopf.rechts:SetText(fertig .. "/" .. #TESTPLAN .. " erledigt" .. (s.datenAlter and ("  ·  Daten vor " .. s.datenAlter .. " Std.") or ""))
  local an, ag = GF.auftragStand()
  local vs = GoldForeverDB.vollscan and GoldForeverDB.vollscan[#GoldForeverDB.vollscan]
  v.scan.rechts:SetText("heute " .. an .. "/" .. ag .. " gescannt  ·  Vollscan " .. (vs and date("%d.%m. %H:%M", vs.t) or "noch keiner"))
  v.melden.rechts:SetText(#T.notizen .. " gesamt")
  local zeilen = {}
  for k = #T.notizen, math.max(1, #T.notizen - 2), -1 do
    local m = T.notizen[k]
    zeilen[#zeilen + 1] = H.grau .. date("%d.%m. %H:%M", m.t) .. "  " .. ENDE .. H.gold .. m.kat .. ":" .. ENDE .. " " .. H.hell .. m.text .. ENDE
  end
  v.meldungen:SetText(#zeilen > 0 and table.concat(zeilen, "\n") or (H.grau .. "Noch keine Meldungen." .. ENDE))
  return v.hoehe
end
local function testMelden(kat)
  local box = fenster.ansichten.test.box
  local txt = (box:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if txt == "" then box:SetFocus(); return end
  local T = testDB()
  local meta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
  T.notizen[#T.notizen + 1] = { t = time(), kat = kat, text = txt, version = meta and meta("GoldForever", "Version"), reiter = fenster.ansicht }
  box:SetText(""); box:ClearFocus()
  print(H.gold .. "Gold Forever:" .. ENDE .. " Meldung gespeichert (" .. kat .. "). Wird nach /reload oder Ausloggen für Claude übertragen.")
  GF.aktualisieren()
end

-- ---------------------------------------------------------------- Ansicht wechseln
local function testmodus() return GoldForeverDB.testmodus ~= false end
local function zeigeAnsicht(name)
  if not fenster then return end
  if name == "handel" or not fenster.ansichten[name] then name = "standard" end
  if name == "test" and not testmodus() then name = "standard" end
  fenster.ansicht = name
  for k, v in pairs(fenster.ansichten) do v:SetShown(k == name) end
  for k, r in pairs(fenster.reiter) do
    local an = k == name
    local c = an and F.gold or F.grau
    r.t:SetTextColor(c[1], c[2], c[3]); r.strich:SetShown(an)
  end
  for k, b in pairs(fenster.symbole) do b:Aktiv(k == name) end
  fenster.scroll:SetVerticalScroll(0)
  if not GF.ah and fenster.reiter[name] then GoldForeverDB.reiter = name end
  GF.aktualisieren()
end
GF.zeigeAnsicht = zeigeAnsicht

function GF.aktualisieren()
  if not fenster or not fenster:IsShown() then return end
  local okS, s = pcall(standardDaten); if not okS then s = { jetzt = {}, spaeter = {}, warte = {}, kauf = {}, aufk = {}, scan = {}, kaufListe = {} } end
  local okR, r = pcall(raidDaten); if not okR then r = { kauf = {}, ware = {}, event = {}, jetzt = 0, kaufListe = {}, danach = {}, start = "?", verkTage = "", kaufTage = "" } end
  zahlen.standard, zahlen.raid, zahlen.zeit = #s.jetzt, r.jetzt, time()
  -- Kopf
  local ein, aus, prof = GF.handelHeute()
  fenster.k.gold.wert:SetText(H.hell .. betragKurz(GetMoney()) .. ENDE)
  fenster.k.budget.wert:SetText(H.lila .. betragKurz(s.budget or GF.budgetPlan().budget) .. ENDE)
  fenster.k.ein.wert:SetText(ein > 0 and (H.gruen .. betragKurz(ein) .. ENDE) or (H.grau .. "—" .. ENDE))
  fenster.k.profit.wert:SetText((ein > 0 or aus > 0) and plusMinusKurz(prof) or (H.grau .. "—" .. ENDE))
  fenster.k.profit.tipp = "Einnahmen " .. GF.geld(ein) .. " minus Einkäufe " .. GF.geld(aus) .. " (heute). Gold seit Tagesbeginn: " .. GF.geld(GF.tagesbilanz() or 0) .. ". Klick: Bilanz."
  fenster.wer:SetText(H.grau .. "·  " .. ENDE .. H.hell .. GF.charKey() .. ENDE .. (GF.ah and (H.grau .. "  ·  Einkaufsliste" .. ENDE) or ""))
  for _, rr in ipairs(REITER) do
    local b = fenster.reiter[rr[1]]
    local n = zahlen[rr[1]] or 0
    b.t:SetText(rr[2] .. (n > 0 and ("  " .. H.grau .. n .. ENDE) or ""))
  end
  -- Inhalt
  local v = fenster.ansichten[fenster.ansicht]
  local ok, h = pcall(ANSICHTEN[fenster.ansicht], v, s, r)
  if not ok then print(H.gold .. "Gold Forever:" .. ENDE .. " Fehler im Fenster – " .. tostring(h)); h = 100 end
  h = math.max(4, math.floor(h + 0.5))
  v:SetHeight(h); fenster.inhalt:SetHeight(h)
  local maxH = math.min(MAX_H, math.floor((UIParent:GetHeight() or 900) * 0.85 / (fenster:GetScale() or 1)))
  fenster:SetHeight(math.max(MIN_H, math.min(KOPF + h + FUSS, maxH)))
  fenster.scroll:Zeige()
  -- Fuß
  local d = GoldForeverData
  local alter = d and d.stand and math.floor((time() - d.stand) / 3600)
  local meta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
  local version = meta and meta("GoldForever", "Version")
  local ra = GF.realmAlter and GF.realmAlter()
  local raText = ra and ("  ·  Realm vor " .. math.floor(ra / 3600) .. " Std.") or "  ·  " .. H.orange .. "Realm-Daten fehlen" .. ENDE
  fenster.fussL:SetText((version and ("v" .. version .. "  ·  ") or "") .. (TSM_API and "TSM live" or "GF-Daten") .. (alter and ("  ·  TSM vor " .. alter .. " Std.") or "") .. raText)
end

-- ---------------------------------------------------------------- Bauen
local function baueAnsichten(kind)
  local A = {}
  -- Standard
  local v = CreateFrame("Frame", nil, kind); v:SetWidth(INNEN); v:SetPoint("TOPLEFT")
  -- Unter-Reiter mit leuchtender Zahl (2.50, Befund 4)
  v.unter = CreateFrame("Frame", nil, v); v.unter:SetSize(INNEN, 28); v.unter.hoehe = 28
  v.unter.b = {}
  -- 2.53: fünf Unter-Reiter (82 breit), Zahl-Badge oben rechts in der Ecke
  local UNTER = { { "verk", "Verkaufen", F.gruen }, { "herst", "Herstellen", F.gelb }, { "halt", "Halten", F.blau }, { "ah", "Auktionshaus", F.gold }, { "kauf", "Kaufen", F.lila } }
  for k, u in ipairs(UNTER) do
    local b = CreateFrame("Button", nil, v.unter); b:SetSize(82, 28); b:SetPoint("TOPLEFT", (k - 1) * 88.5, 0)
    b.key, b.farbe = u[1], u[3]
    b.bg = b:CreateTexture(nil, "BACKGROUND"); b.bg:SetAllPoints(); b.bg:SetColorTexture(1, 1, 1, 0.03)
    b.t = text(b, 11, F.grau); b.t:SetPoint("BOTTOM", 0, 5); b.t:SetText(u[2])
    b.badge = b:CreateTexture(nil, "ARTWORK", nil, 2); b.badge:SetSize(14, 11); b.badge:SetPoint("TOPRIGHT", -2, -2)
    b.badge:SetColorTexture(u[3][1], u[3][2], u[3][3], 1)
    b.halo = b:CreateTexture(nil, "ARTWORK", nil, 1); b.halo:SetSize(24, 20); b.halo:SetPoint("CENTER", b.badge, "CENTER")
    b.halo:SetColorTexture(u[3][1], u[3][2], u[3][3], 0.35)
    b.zahl = text(b, 10, { 0.06, 0.07, 0.09 }); b.zahl:SetShadowOffset(0, 0); b.zahl:SetPoint("CENTER", b.badge, "CENTER", 0, 0); b.zahl:SetJustifyH("CENTER")
    b.strich = b:CreateTexture(nil, "OVERLAY"); b.strich:SetHeight(2); b.strich:SetPoint("BOTTOMLEFT"); b.strich:SetPoint("BOTTOMRIGHT")
    b.strich:SetColorTexture(u[3][1], u[3][2], u[3][3], 1); b.strich:Hide()
    b:SetScript("OnClick", function(self)
      GoldForeverDB.unter = self.key
      if fenster and fenster.scroll then fenster.scroll:SetVerticalScroll(0) end
      GF.aktualisieren()
    end)
    b:SetScript("OnEnter", function(self) self.t:SetTextColor(F.hell[1], F.hell[2], F.hell[3]) end)
    b:SetScript("OnLeave", function(self) local c = (self.key == v.unter.wahl) and F.hell or F.grau; self.t:SetTextColor(c[1], c[2], c[3]) end)
    v.unter.b[k] = b
  end
  v.jetzt = abschnitt(v, F.gruen, 20)
  v.herst = abschnitt(v, F.gelb, 15)
  -- Bank-Leiste (2.53): an der offenen Bank drei Knöpfe
  v.bank = CreateFrame("Frame", nil, v); v.bank:SetSize(INNEN, 24); v.bank.hoehe = 24; flaeche(v.bank, 0.04); v.bank:Hide()
  v.bank.t = text(v.bank, 10, F.grau); v.bank.t:SetPoint("LEFT", 8, 0); v.bank.t:SetText("Bank:")
  -- 2.53.2 (Befund 35): Symbole statt „→“ (Zeichen fehlt in der Schrift) – gleiche Icons wie die Lagerorte der Karten
  local TA, BA, PF = "|TInterface\\Icons\\INV_Misc_Bag_08:14:14:0:0:64:64:5:59:5:59|t", "|TInterface\\Icons\\INV_Box_01:14:14:0:0:64:64:5:59:5:59|t",
    "|TInterface\\ChatFrame\\ChatFrameExpandArrow:12:12|t"
  local BK = { { "haltRein", "Halten " .. TA .. PF .. BA, F.blau, "Halten in die Bank" }, { "haltRaus", "Halten " .. BA .. PF .. TA, F.blau, "Halten in die Tasche" },
    { "verkRaus", "Verkaufen " .. BA .. PF .. TA, F.gruen, "Verkaufen in die Tasche" } }
  local vorher
  for k, x in ipairs(BK) do
    local l = link(v.bank, 10, function() GF.bankVerschieben(x[1]) end,
      { x[4], k == 1 and "Alle blauen Halten-Items aus der Tasche in die Bank." or k == 2 and "Alle blauen Halten-Items aus der Bank in die Tasche." or "Alle grünen Verkaufen-Items aus der Bank in die Tasche – bereit zum Einstellen." })
    l:Text(x[2]); l.t:SetTextColor(x[3][1], x[3][2], x[3][3])
    if vorher then l:SetPoint("LEFT", vorher, "RIGHT", 14, 0) else l:SetPoint("LEFT", v.bank.t, "RIGHT", 10, 0) end
    vorher = l
  end
  v.spaeter = abschnitt(v, F.blau, 5, F.blau, 22)
  v.einblenden = link(v.spaeter.z2, 10, function() GF.alleEinblenden() end)
  v.einblenden:SetPoint("RIGHT", 0, 0)
  v.einblenden:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM"); GameTooltip:AddLine("Ausgeblendete Items")
    for id in pairs(GoldForeverDB.ignor or {}) do GameTooltip:AddLine(itemName(id), F.grau[1], F.grau[2], F.grau[3]) end
    GameTooltip:AddLine("Klick: alle wieder einblenden und neu prüfen", F.gold[1], F.gold[2], F.gold[3])
    GameTooltip:Show()
  end)
  v.tsmHalten = link(v.spaeter, 10, function() if v.haltenIds and #v.haltenIds > 0 then sucheText((namenListe(v.haltenIds))) end end,
    { "Halten-Ware in TSM suchen", "Zuerst ins TSM-Suchfeld klicken, dann hier. So siehst du, ob deine Ware unterboten ist." })
  v.tsmHalten:SetPoint("TOPRIGHT", 0, -2); v.tsmHalten:Text("In TSM suchen")
  -- Halten: Gesamtwert + Sortierung (2.52)
  v.haltSort = link(v.spaeter.z2, 10, function()
    local nx = { ab = "auf", auf = "az", az = "ab" }
    GoldForeverDB.haltSort = nx[GoldForeverDB.haltSort or "ab"]; GF.aktualisieren()
  end, { "Sortierung wechseln", "Gewinn hoch, Gewinn tief, A–Z" })
  v.haltSort:SetPoint("RIGHT", 0, 0)
  v.ah = abschnitt(v, F.gold, 20)
  v.kauf = abschnitt(v, F.lila, 10)
  v.tsm = link(v.kauf, 10, function() pcall(inTsmSuchen) end, { "Ganzen Einkaufsplan in TSM suchen", "Zuerst ins TSM-Suchfeld klicken, dann hier." })
  v.tsm:SetPoint("TOPRIGHT", 0, -2); v.tsm:Text("In TSM suchen")
  -- 2.52: Vollscan direkt unter Kaufen (am AH), mit Abklingzeit
  v.voll = link(v.kauf, 10, function() GF.vollscanStarten(); C_Timer.After(1, function() GF.aktualisieren() end) end,
    { "Vollscan", "Ganzes Auktionshaus einlesen (Blizzard erlaubt das alle 15 Min.). Die Kauf-Vorschläge rechnen sich danach neu. AH offen lassen, bis „gespeichert“ im Chat steht." })
  v.aufk = abschnitt(v, F.orange, 0, F.orange, 11)
  A.standard = v
  -- Qualität, Risiko (Platzhalter)
  for _, art in ipairs({ "qualitaet", "risiko" }) do
    local p = CreateFrame("Frame", nil, kind); p:SetWidth(INNEN); p:SetPoint("TOPLEFT")
    p.info = CreateFrame("Frame", nil, p); p.info:SetSize(INNEN, KARTE_H); flaeche(p.info, 0.02); p.info.hoehe = KARTE_H
    p.info.t = text(p.info, 10, F.grau); p.info.t:SetPoint("CENTER"); p.info.t:SetWidth(INNEN - 16); p.info.t:SetJustifyH("CENTER"); p.info.t:SetWordWrap(true)
    p.jetzt = abschnitt(p, F.gruen, 1); p.spaeter = abschnitt(p, F.blau, 1); p.kauf = abschnitt(p, F.lila, 1)
    A[art] = p
  end
  -- Raid & Events
  local r = CreateFrame("Frame", nil, kind); r:SetWidth(INNEN); r:SetPoint("TOPLEFT")
  r.schritte = {}
  local namen = { "1  Kaufen", "2  Behalten", "3  Verkaufen" }
  for k = 1, 3 do
    local kt = kennzahl(r, 140, 44); kt:SetPoint("TOPLEFT", (k - 1) * 148, 0)
    kt.oben:SetFontObject(SCHRIFT[12]); kt.oben:SetText(namen[k]); kt.oben:SetTextColor(F.hell[1], F.hell[2], F.hell[3])
    kt.wert:SetFontObject(SCHRIFT[10]); kt.wert:ClearAllPoints(); kt.wert:SetPoint("TOP", 0, -24); kt.wert:SetTextColor(F.grau[1], F.grau[2], F.grau[3])
    kt:EnableMouse(false)
    r.schritte[k] = kt
  end
  r.zeile = text(r, 10, F.grau); r.zeile:SetPoint("TOPLEFT", 0, -52)
  r.unten = CreateFrame("Frame", nil, r); r.unten:SetWidth(INNEN); r.unten:SetPoint("TOPLEFT", 0, -(44 + 8 + 16 + ABSTAND))
  r.kauf = abschnitt(r.unten, F.lila, 5)
  r.tsm = link(r.kauf, 10, function() pcall(inTsmSuchen) end, { "Raid-Vorrat in TSM suchen", "Zuerst ins TSM-Suchfeld klicken, dann hier." })
  r.tsm:SetPoint("TOPRIGHT", 0, -2); r.tsm:Text("In TSM suchen")
  r.ware = abschnitt(r.unten, F.blau, 10)
  r.event = abschnitt(r.unten, F.grau, 6)
  r.danach = text(r.unten, 10, F.grau); r.danach:SetWidth(INNEN)
  A.raid = r
  -- Bilanz
  local b = CreateFrame("Frame", nil, kind); b:SetWidth(INNEN); b:SetPoint("TOPLEFT")
  b.zeit = {}
  for k, z in ipairs(ZEITRAUM) do
    local zb = CreateFrame("Button", nil, b); zb:SetSize(103, 20); zb:SetPoint("TOPLEFT", (k - 1) * 111, 0)
    zb.wert = z[1]
    zb.t = text(zb, 12, F.grau); zb.t:SetPoint("CENTER", 0, 1); zb.t:SetText(z[2])
    zb.strich = zb:CreateTexture(nil, "ARTWORK"); zb.strich:SetHeight(2); zb.strich:SetPoint("BOTTOMLEFT"); zb.strich:SetPoint("BOTTOMRIGHT")
    zb.strich:SetColorTexture(F.gold[1], F.gold[2], F.gold[3], 1)
    zb:SetScript("OnClick", function(self) GoldForeverDB.bilanzZeit = self.wert; GF.bilanzFilter = nil; GF.aktualisieren() end)
    b.zeit[k] = zb
  end
  b.ergebnis = kennzahl(b, INNEN, 96); b.ergebnis:SetPoint("TOPLEFT", 0, -28); b.ergebnis:EnableMouse(false)
  b.ergebnis.oben:SetText("Profit – alle Käufe und Verkäufe"); b.ergebnis.oben:SetPoint("TOP", 0, -8); b.ergebnis.wert:SetPoint("TOP", 0, -26)
  b.ergebnis:SetScript("OnEnter", nil)
  -- Verlauf: kleine Balken je Stunde/Tag (Einnahmen − Ausgaben), Nulllinie grau
  local c = CreateFrame("Frame", nil, b.ergebnis); c:SetSize(VERLAUF_B, VERLAUF_H); c:SetPoint("TOPLEFT", 16, -52)
  c.linie = c:CreateTexture(nil, "BORDER"); c.linie:SetHeight(1); c.linie:SetColorTexture(1, 1, 1, 0.12)
  c.balken = {}
  for k = 1, 31 do
    local bk = CreateFrame("Frame", nil, c); bk:EnableMouse(true)
    bk.t = bk:CreateTexture(nil, "ARTWORK"); bk.t:SetAllPoints()
    bk:SetScript("OnEnter", function(self)
      self.t:SetAlpha(1)
      GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:AddLine(self.label or "")
      GameTooltip:AddDoubleLine("Ergebnis", plusMinus(self.wert or 0), F.grau[1], F.grau[2], F.grau[3])
      if (self.ein or 0) > 0 then GameTooltip:AddDoubleLine("Verkäufe", H.gruen .. "+" .. betrag(self.ein) .. ENDE, F.grau[1], F.grau[2], F.grau[3]) end
      if (self.aus or 0) < 0 then GameTooltip:AddDoubleLine("Einkäufe", H.rot .. "-" .. betrag(self.aus) .. ENDE, F.grau[1], F.grau[2], F.grau[3]) end
      GameTooltip:AddLine("Alle Käufe und Verkäufe im AH (wie TSM).", F.grau[1], F.grau[2], F.grau[3], true)
      GameTooltip:AddLine("Klick: Geschäfte in diesem Zeitraum zeigen", F.gold[1], F.gold[2], F.gold[3])
      GameTooltip:Show()
    end)
    bk:SetScript("OnLeave", function(self) self.t:SetAlpha(0.7); GameTooltip:Hide() end)
    bk:SetScript("OnMouseUp", function(self)
      if not self.von then return end
      local f = GF.bilanzFilter
      if f and f.von == self.von then GF.bilanzFilter = nil else GF.bilanzFilter = { von = self.von, bis = self.bis, titel = self.label } end
      GF.aktualisieren()
    end)
    bk:Hide(); c.balken[k] = bk
  end
  b.verlauf = c
  b.vier = {}
  for k = 1, 4 do
    local kz = kennzahl(b, 214, 44)
    kz.art = ({ "alleVerk", "alleKauf", "gf", "bestand" })[k]
    kz:SetScript("OnClick", function(self)
      local f = GF.bilanzFilter
      if f and f.art == self.art then GF.bilanzFilter = nil else GF.bilanzFilter = { art = self.art, titel = self.oben:GetText() } end
      GF.aktualisieren()
    end)
    kz:SetScript("OnEnter", function(self)
      self.bg:SetColorTexture(1, 1, 1, 0.06)
      GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:AddLine("Klick: Details zeigen"); GameTooltip:Show()
    end)
    kz:SetScript("OnLeave", function(self) self.bg:SetColorTexture(1, 1, 1, 0.03); GameTooltip:Hide() end)
    kz:SetPoint("TOPLEFT", ((k - 1) % 2) * 222, -(132 + math.floor((k - 1) / 2) * 52))
    -- Anteil-Leiste unten in der Kachel (2 hoch, 8 Rand)
    kz.spur = kz:CreateTexture(nil, "BORDER"); kz.spur:SetHeight(2); kz.spur:SetPoint("BOTTOMLEFT", 8, 6); kz.spur:SetPoint("BOTTOMRIGHT", -8, 6)
    kz.spur:SetColorTexture(1, 1, 1, 0.06)
    kz.fuell = kz:CreateTexture(nil, "ARTWORK"); kz.fuell:SetHeight(2); kz.fuell:SetPoint("BOTTOMLEFT", 8, 6)
    b.vier[k] = kz
  end
  b.jeReiter = text(b, 10); b.jeReiter:SetPoint("TOPLEFT", 0, -236); b.jeReiter:SetWidth(INNEN); b.jeReiter:SetWordWrap(false)
  b.herkunft = text(b, 10); b.herkunft:SetPoint("TOPLEFT", 0, -258); b.herkunft:SetWidth(INNEN); b.herkunft:SetWordWrap(true); b.herkunft:SetSpacing(3)
  b.liste = abschnitt(b, F.gold, 0)
  b.zeilen = {}
  b.alle = link(b.liste, 10, function() GF.bilanzFilter = nil; GF.aktualisieren() end)
  b.alle:SetPoint("TOPRIGHT", 0, -2); b.alle:Text("alle zeigen"); b.alle:Hide()
  for k = 1, 12 do
    local z = CreateFrame("Button", nil, b.liste); z:SetSize(INNEN, LISTE_H); z:SetPoint("TOPLEFT", 0, -(28 + (k - 1) * LISTE_H))
    z.hl = flaeche(z, 0.06); z.hl:Hide()
    z.icon = z:CreateTexture(nil, "ARTWORK"); z.icon:SetSize(16, 16); z.icon:SetPoint("LEFT", 0, 0); z.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    z.name = text(z, 12); z.name:SetPoint("LEFT", 24, 0); z.name:SetWidth(196)
    z.mitte = text(z, 10); z.mitte:SetPoint("LEFT", 228, 0); z.mitte:SetWidth(104)
    z.betrag = text(z, 12); z.betrag:SetPoint("RIGHT", -8, 0); z.betrag:SetJustifyH("RIGHT"); z.betrag:SetWidth(BETRAG_B)
    z:SetScript("OnEnter", function(self)
      self.hl:Show()
      if not self.itemId then
        if not self.details then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:AddLine(H.gold .. "Tagesbuch" .. ENDE)
        for _, d in ipairs(self.details) do GameTooltip:AddDoubleLine(d[1], d[2], F.grau[1], F.grau[2], F.grau[3], F.hell[1], F.hell[2], F.hell[3]) end
        GameTooltip:Show(); return
      end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetItemByID(self.itemId)
      if self.details then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(H.gold .. "Gold Forever – Details" .. ENDE)
        for _, d in ipairs(self.details) do GameTooltip:AddDoubleLine(d[1], d[2], F.grau[1], F.grau[2], F.grau[3], F.hell[1], F.hell[2], F.hell[3]) end
      end
      GameTooltip:Show()
    end)
    z:SetScript("OnLeave", function(self) self.hl:Hide(); GameTooltip:Hide() end)
    z:RegisterForClicks("LeftButtonUp"); z:SetScript("OnClick", karteKlick)
    z:Hide(); b.zeilen[k] = z
  end
  b.liste.leer:ClearAllPoints(); b.liste.leer:SetPoint("TOPLEFT", 0, -28)
  b.fuss = text(b, 10, F.grau); b.fuss:SetWidth(INNEN); b.fuss:SetWordWrap(true); b.fuss:SetSpacing(4)
  A.bilanz = b
  -- Test
  local t = CreateFrame("Frame", nil, kind); t:SetWidth(INNEN); t:SetPoint("TOPLEFT")
  t.kopf = abschnitt(t, F.gold, 0); t.kopf:SetPoint("TOPLEFT"); t.kopf.titel:SetText("Testplan"); t.kopf:SetHeight(20)
  t.plan = {}
  for n = 1, #TESTPLAN do
    local z = CreateFrame("Button", nil, t); z:SetSize(INNEN, LISTE_H); z:SetPoint("TOPLEFT", 0, -(28 + (n - 1) * LISTE_H))
    z.hl = flaeche(z, 0.06); z.hl:Hide()
    z.box = CreateFrame("Frame", nil, z); z.box:SetSize(16, 16); z.box:SetPoint("LEFT", 0, 0); flaeche(z.box, 0.06); rahmen(z.box):farbe({ 1, 1, 1 }, 0.2)
    z.box.haken = z.box:CreateTexture(nil, "OVERLAY"); z.box.haken:SetSize(14, 14); z.box.haken:SetPoint("CENTER")
    z.box.haken:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready"); z.box.haken:SetDesaturated(true); z.box.haken:SetVertexColor(F.gruen[1], F.gruen[2], F.gruen[3])
    z.text = text(z, 12); z.text:SetPoint("LEFT", 24, 0); z.text:SetWidth(232)
    z.status = text(z, 10, F.grau); z.status:SetPoint("RIGHT", -8, 0); z.status:SetJustifyH("RIGHT"); z.status:SetWidth(164)
    z:SetScript("OnClick", function(self) local _, tag = testDB(); tag.h[self.k] = (not self.an) and "hand" or nil; GF.aktualisieren() end)
    z:SetScript("OnEnter", function(self) self.hl:Show(); GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:AddLine(self.tipp or "", 1, 1, 1, true); GameTooltip:Show() end)
    z:SetScript("OnLeave", function(self) self.hl:Hide(); GameTooltip:Hide() end)
    t.plan[n] = z
  end
  local y = 28 + #TESTPLAN * LISTE_H + ABSTAND
  t.scan = abschnitt(t, F.gold, 0); t.scan:SetPoint("TOPLEFT", 0, -y); t.scan.titel:SetText("Scan-Auftrag für Claude"); t.scan:SetHeight(20)
  local ab = knopf(t, 214, "1. Auftrag in TSM suchen", function() sucheText((GF.auftragSuche())) end,
    { "Scan-Auftrag: " .. GF.AUFTRAG.titel, "Am AH zuerst ins TSM-Suchfeld klicken, dann hier. Gold Forever schreibt Mengen, Preisstufen und Verkäufer mit. Danach /reload." })
  ab:SetPoint("TOPLEFT", 0, -(y + 28))
  local vb = knopf(t, 214, "2. Vollscan (1× am Tag)", function() GF.vollscanStarten() end,
    { "Vollscan des ganzen Auktionshauses", "Offizieller Ein-Klick-Scan von Blizzard (alle 15 Min. möglich). Nur am offenen AH. Danach /reload." })
  vb:SetPoint("TOPLEFT", 222, -(y + 28))
  y = y + 28 + 24 + ABSTAND
  t.melden = abschnitt(t, F.gold, 0); t.melden:SetPoint("TOPLEFT", 0, -y); t.melden.titel:SetText("Auffälligkeit melden"); t.melden:SetHeight(20)
  local hint = text(t, 10, F.grau); hint:SetPoint("TOPLEFT", 0, -(y + 28)); hint:SetText("Was wirkt falsch oder fehlt? Kurz eintippen, dann Art wählen.")
  t.box = CreateFrame("EditBox", nil, t); t.box:SetSize(INNEN, 24); t.box:SetPoint("TOPLEFT", 0, -(y + 48))
  eigeneFelder[t.box] = true
  t.box:SetFontObject(SCHRIFT[12]); t.box:SetTextInsets(8, 8, 0, 0); t.box:SetAutoFocus(false); t.box:SetMaxLetters(250)
  flaeche(t.box, 0.06); local br = rahmen(t.box); br:farbe({ 1, 1, 1 }, 0.12)
  t.box:SetScript("OnEditFocusGained", function() br:farbe(F.gold, 0.8) end)
  t.box:SetScript("OnEditFocusLost", function() br:farbe({ 1, 1, 1 }, 0.12) end)
  t.box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  for k, kat in ipairs({ "Vorschlag falsch", "Fehler", "Idee/Design" }) do
    local kb = knopf(t, 140, kat, function() testMelden(kat) end); kb:SetPoint("TOPLEFT", (k - 1) * 148, -(y + 80))
  end
  t.meldungen = text(t, 10); t.meldungen:SetPoint("TOPLEFT", 0, -(y + 116)); t.meldungen:SetWidth(INNEN); t.meldungen:SetWordWrap(true); t.meldungen:SetSpacing(4)
  t.hoehe = y + 116 + 48
  A.test = t
  return A
end

local function symbolKnopf(parent, textur, tipp, onClick)
  local b = CreateFrame("Button", nil, parent); b:SetSize(20, 20)
  b.i = b:CreateTexture(nil, "ARTWORK"); b.i:SetSize(16, 16); b.i:SetPoint("CENTER"); b.i:SetTexture(textur)
  b.i:SetTexCoord(0.08, 0.92, 0.08, 0.92); b.i:SetDesaturated(true)
  local function farbe(self) local c = self.aktiv and F.gold or (self:IsMouseOver() and F.hell or F.grau); self.i:SetVertexColor(c[1], c[2], c[3]) end
  function b:Aktiv(an) self.aktiv = an; farbe(self) end
  b:SetScript("OnClick", onClick)
  b:SetScript("OnEnter", function(self) farbe(self); if tipp then GameTooltip:SetOwner(self, "ANCHOR_BOTTOM"); GameTooltip:AddLine(tipp); GameTooltip:Show() end end)
  b:SetScript("OnLeave", function(self) self.aktiv = self.aktiv; self.i:SetVertexColor((self.aktiv and F.gold or F.grau)[1], (self.aktiv and F.gold or F.grau)[2], (self.aktiv and F.gold or F.grau)[3]); GameTooltip:Hide() end)
  b:Aktiv(false)
  return b
end

local function symbolePlatzieren()
  local x = -RAND - 20 - 8
  fenster.symbole.test:SetShown(testmodus())
  if testmodus() then fenster.symbole.test:ClearAllPoints(); fenster.symbole.test:SetPoint("TOPRIGHT", x, -24); x = x - 24 end
  fenster.symbole.bilanz:ClearAllPoints(); fenster.symbole.bilanz:SetPoint("TOPRIGHT", x, -24)
end

-- Fenster an der Ecke oben links festmachen (statt CENTER).
-- So wächst es beim Größer-Ziehen und bei mehr Inhalt nur nach rechts und unten.
local function obenLinksVerankern(merken)
  if not fenster then return end
  local l, o = fenster:GetLeft(), fenster:GetTop()
  if not (l and o) then return end
  local s = fenster:GetScale()
  local x, y = l, o - UIParent:GetHeight() / s
  fenster:ClearAllPoints(); fenster:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, y)
  if merken == false then return end
  if GF.ah then GoldForeverDB.posAH = { "TOPLEFT", x, y } else GoldForeverDB.pos = { "TOPLEFT", x, y } end
end

function GF.logoSetzen()
  if not (fenster and fenster.logo and fenster.titel) then return end
  local an = GoldForeverDB.logo == true
  if an then fenster.logo:SetTexture("Interface\\AddOns\\GoldForever\\Media\\Logo") end
  fenster.logo:SetShown(an); fenster.titel:SetShown(not an)
end

local function baue()
  schriftenBauen()
  fenster = CreateFrame("Frame", "GoldForeverFenster", UIParent, "BackdropTemplate")
  fenster:SetSize(BREITE, MIN_H)
  local p = GoldForeverDB.pos
  fenster:SetPoint(p and p[1] or "CENTER", UIParent, p and p[1] or "CENTER", p and p[2] or 0, p and p[3] or 0)
  fenster:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
  fenster:SetBackdropColor(0.055, 0.063, 0.082, 0.96)
  fenster:SetBackdropBorderColor(F.gold[1], F.gold[2], F.gold[3], 0.35)
  fenster:SetFrameStrata("HIGH"); fenster:SetToplevel(true)
  fenster:SetMovable(true); fenster:EnableMouse(true); fenster:RegisterForDrag("LeftButton")
  fenster:SetScript("OnDragStart", fenster.StartMoving)
  fenster:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); obenLinksVerankern() end)
  tinsert(UISpecialFrames, "GoldForeverFenster")

  -- Logo-Zeile (y 8–56, 48 hoch): Bilddatei 128 × 64 (Media\Logo.tga, 512 × 256 Pixel), sichtbar ca. 124 × 45
  fenster.logo = fenster:CreateTexture(nil, "ARTWORK"); fenster.logo:SetSize(128, 64); fenster.logo:SetPoint("TOPLEFT", RAND - 2, -2)
  -- Logo (2.50, Befund 10): WoW meldet eine fehlende Bilddatei nicht zuverlässig (SetTexture liefert trotzdem true).
  -- Darum Standard = Schriftzug „Gold Forever“; das Logo erst nach /gf logo (wenn Logo.tga in GoldForever\Media liegt).
  fenster.titel = text(fenster, 16, F.gold); fenster.titel:SetPoint("TOPLEFT", RAND, -26); fenster.titel:SetText("Gold Forever")
  GF.logoSetzen()
  fenster.wer = text(fenster, 12); fenster.wer:SetPoint("LEFT", fenster, "TOPLEFT", RAND + 132, -34)
  local zu = symbolKnopf(fenster, "Interface\\Buttons\\UI-StopButton", "Schließen", function() fenster:Hide() end)
  zu.i:SetTexCoord(0, 1, 0, 1); zu:SetPoint("TOPRIGHT", -RAND, -24)
  fenster.symbole = {
    bilanz = symbolKnopf(fenster, "Interface\\Icons\\INV_Scroll_03", "Bilanz", function() zeigeAnsicht(fenster.ansicht == "bilanz" and (GoldForeverDB.reiter or "standard") or "bilanz") end),
    test = symbolKnopf(fenster, "Interface\\Icons\\Trade_Alchemy", "Test (nur Testphase)", function() zeigeAnsicht(fenster.ansicht == "test" and (GoldForeverDB.reiter or "standard") or "test") end),
  }
  symbolePlatzieren()

  -- Kennzahlen (y 64, 4 × 103): Gold · Budget · Einnahmen · Profit (2.52, Wunsch Alex)
  fenster.k = {}
  local KZ = {
    { "gold", "Gold", "Gold auf diesem Charakter." },
    { "budget", "Kaufbudget", "So viel darf Gold Forever für Einkäufe einplanen (Anteil deines Golds)." },
    { "ein", "Einnahmen heute", "Erlöse aus AH-Verkäufen heute (aus der Post, nach Gebühr)." },
    { "profit", "Profit heute", "Einnahmen minus Einkäufe heute. Klick: Bilanz." },
  }
  for k, n in ipairs(KZ) do
    local kz = kennzahl(fenster, 103, 44); kz:SetPoint("TOPLEFT", RAND + (k - 1) * 111, -64); kz.oben:SetText(n[2])
    kz.tipp = n[3]
    kz:SetScript("OnEnter", function(self) self.bg:SetColorTexture(1, 1, 1, 0.06); GameTooltip:SetOwner(self, "ANCHOR_BOTTOM"); GameTooltip:AddLine(n[2]); GameTooltip:AddLine(self.tipp, F.grau[1], F.grau[2], F.grau[3], true); GameTooltip:Show() end)
    kz:SetScript("OnLeave", function(self) self.bg:SetColorTexture(self.farbe and self.farbe[1] or 1, self.farbe and self.farbe[2] or 1, self.farbe and self.farbe[3] or 1, self.farbe and 0.12 or 0.03); GameTooltip:Hide() end)
    fenster.k[n[1]] = kz
  end
  -- Budget farbig hinterlegt (lila = Kaufen)
  fenster.k.budget.farbe = F.lila; fenster.k.budget.bg:SetColorTexture(F.lila[1], F.lila[2], F.lila[3], 0.12)
  fenster.k.profit:SetScript("OnClick", function() zeigeAnsicht("bilanz") end)
  -- Gold nach Herkunft (2.53): Tooltip auf der Gold-Kachel, Klick = Bilanz
  fenster.k.gold:SetScript("OnClick", function() zeigeAnsicht("bilanz") end)
  fenster.k.gold:SetScript("OnEnter", function(self)
    self.bg:SetColorTexture(1, 1, 1, 0.06)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM"); GameTooltip:AddLine("Gold heute – woher?")
    local t = date("*t"); local h = GF.geldHerkunft(t.hour * 3600 + t.min * 60 + t.sec)
    local ZEILEN = { { "loot", "Loot" }, { "quest", "Quests" }, { "haendler", "Händler-Verkauf" }, { "ah", "AH-Verkäufe (Post)" },
      { "ahkauf", "AH-Käufe" }, { "haendlerkauf", "Händler-Kauf / Reparatur" }, { "sonst", "Sonstiges" } }
    local summe = 0
    for _, z in ipairs(ZEILEN) do
      local w = h[z[1]] or 0; summe = summe + w
      if w ~= 0 then GameTooltip:AddDoubleLine(z[2], plusMinus(w), F.grau[1], F.grau[2], F.grau[3]) end
    end
    local gfH = select(3, GF.handelHeute()) or 0
    GameTooltip:AddDoubleLine("davon durch GF (Handel)", plusMinus(gfH), F.grau[1], F.grau[2], F.grau[3])
    if summe == 0 then GameTooltip:AddLine("Noch nichts mitgeschrieben – zählt ab 2.53 jede Goldänderung.", F.grau[1], F.grau[2], F.grau[3], true) end
    GameTooltip:AddLine("Klick: Bilanz", F.gold[1], F.gold[2], F.gold[3]); GameTooltip:Show()
  end)
  fenster.k.heute = fenster.k.profit -- alter Name (Bilanz-Code)

  -- Reiter (y 120, 4 × 103) und Linie (y 144)
  local linie = fenster:CreateTexture(nil, "ARTWORK"); linie:SetColorTexture(1, 1, 1, 0.08); linie:SetHeight(1)
  linie:SetPoint("TOPLEFT", RAND, -144); linie:SetPoint("TOPRIGHT", -RAND, -144)
  fenster.reiter = {}
  for k, rr in ipairs(REITER) do
    local b = CreateFrame("Button", nil, fenster); b:SetSize(103, 24); b:SetPoint("TOPLEFT", RAND + (k - 1) * 111, -120)
    b.t = text(b, 12, F.grau); b.t:SetPoint("CENTER", 0, 1); b.t:SetText(rr[2])
    b.strich = b:CreateTexture(nil, "OVERLAY"); b.strich:SetHeight(2); b.strich:SetPoint("BOTTOMLEFT", 0, -1); b.strich:SetPoint("BOTTOMRIGHT", 0, -1)
    b.strich:SetColorTexture(F.gold[1], F.gold[2], F.gold[3], 1); b.strich:Hide()
    b:SetScript("OnClick", function() zeigeAnsicht(rr[1]) end)
    b:SetScript("OnEnter", function(self) if fenster.ansicht ~= rr[1] then self.t:SetTextColor(F.hell[1], F.hell[2], F.hell[3]) end end)
    b:SetScript("OnLeave", function(self) if fenster.ansicht ~= rr[1] then self.t:SetTextColor(F.grau[1], F.grau[2], F.grau[3]) end end)
    fenster.reiter[rr[1]] = b
  end

  -- Inhalt (y 136 bis Fuß), scrollt per Mausrad, wenn das Fenster seine Höchsthöhe erreicht
  local bereich = CreateFrame("Frame", nil, fenster)
  bereich:SetPoint("TOPLEFT", RAND, -KOPF); bereich:SetPoint("BOTTOMRIGHT", -RAND, FUSS)
  local sf = CreateFrame("ScrollFrame", nil, bereich); sf:SetAllPoints(); sf:EnableMouseWheel(true)
  local kind = CreateFrame("Frame", nil, sf); kind:SetSize(INNEN, 10); sf:SetScrollChild(kind)
  sf.balken = fenster:CreateTexture(nil, "OVERLAY"); sf.balken:SetColorTexture(F.gold[1], F.gold[2], F.gold[3], 0.45); sf.balken:SetWidth(2); sf.balken:Hide()
  sf.mehr = fenster:CreateTexture(nil, "OVERLAY"); sf.mehr:SetSize(12, 12); sf.mehr:SetPoint("BOTTOMRIGHT", bereich, "BOTTOMRIGHT", 14, 0)
  sf.mehr:SetTexture("Interface\\Buttons\\Arrow-Down-Up"); sf.mehr:SetVertexColor(F.gold[1], F.gold[2], F.gold[3]); sf.mehr:Hide()
  function sf:Bereich() return math.max(0, (kind:GetHeight() or 0) - (self:GetHeight() or 0)) end
  function sf:Zeige()
    local weit, sicht = self:Bereich(), self:GetHeight() or 0
    local pos = self:GetVerticalScroll() or 0
    if pos > weit then pos = weit; self:SetVerticalScroll(pos) end
    -- Rechts im Fuß: Pfeil + „mehr – Mausrad“ in Gold, solange unten noch Inhalt liegt; sonst der Bedienhinweis
    local function fussHinweis(mehr)
      if not fenster.fussR then return end
      if mehr then fenster.fussR:SetText("|TInterface\\Buttons\\Arrow-Down-Up:12:12:0:0:32:32:0:32:0:32:245:196:82|t" .. H.gold .. " mehr – Mausrad" .. ENDE) else fenster.fussR:SetText("Klick = im AH suchen") end
    end
    if weit <= 1 or sicht <= 0 then self.balken:Hide(); self.mehr:Hide(); fussHinweis(false); return end
    local lang = math.max(20, sicht * sicht / (sicht + weit))
    local y = (sicht - lang) * pos / weit
    self.balken:ClearAllPoints(); self.balken:SetPoint("TOPRIGHT", bereich, "TOPRIGHT", 8, -y); self.balken:SetHeight(lang); self.balken:Show()
    self.mehr:SetShown(weit - pos > 4)
    fussHinweis(weit - pos > 4)
  end
  sf:SetScript("OnMouseWheel", function(self, delta)
    self:SetVerticalScroll(math.max(0, math.min(self:Bereich(), (self:GetVerticalScroll() or 0) - delta * 2 * KARTE_TAKT)))
    self:Zeige()
  end)
  sf:SetScript("OnSizeChanged", function(self) self:Zeige() end)
  fenster.scroll, fenster.inhalt = sf, kind
  fenster.ansichten = baueAnsichten(kind)

  -- Fuß (unten 12, 16 hoch)
  fenster.fussL = text(fenster, 10, F.grau); fenster.fussL:SetPoint("BOTTOMLEFT", RAND, 14)
  fenster.fussR = text(fenster, 10, F.grau); fenster.fussR:SetPoint("BOTTOMRIGHT", -RAND - 16, 14); fenster.fussR:SetJustifyH("RIGHT")
  fenster.fussR:SetText("Klick = im AH suchen")

  -- Größe: Ecke unten rechts ziehen (skaliert das ganze Fenster, 70–140 %)
  fenster:SetScale(GoldForeverDB.groesse or 1)
  local griff = CreateFrame("Button", nil, fenster); griff:SetSize(14, 14); griff:SetPoint("BOTTOMRIGHT", -2, 2)
  griff:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  griff:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
  griff:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
  -- Die Ecke oben links bleibt stehen, die Ecke unten rechts folgt der Maus.
  griff:SetScript("OnMouseDown", function(self)
    obenLinksVerankern()
    local s = fenster:GetScale()
    self.links, self.oben = fenster:GetLeft() * s, fenster:GetTop() * s -- in UIParent-Einheiten
    self:SetScript("OnUpdate", function()
      local mx = GetCursorPosition() / UIParent:GetEffectiveScale()
      local neu = math.max(0.7, math.min(1.4, (mx - self.links) / BREITE))
      fenster:SetScale(neu); GoldForeverDB.groesse = neu
      fenster:ClearAllPoints()
      fenster:SetPoint("TOPLEFT", UIParent, "TOPLEFT", self.links / neu, (self.oben - UIParent:GetHeight()) / neu)
    end)
  end)
  griff:SetScript("OnMouseUp", function(self) self:SetScript("OnUpdate", nil); obenLinksVerankern() end)

  -- Vorne/hinten wie ein normales Fenster
  local function nachVorne() fenster:SetFrameStrata("HIGH"); fenster:Raise() end
  local function nachHinten() if fenster:IsShown() then fenster:SetFrameStrata("MEDIUM"); fenster:Lower() end end
  GF.fensterNachHinten = nachHinten
  fenster:SetScript("OnShow", function() nachVorne(); obenLinksVerankern(false); GF.aktualisieren() end)
  fenster:SetScript("OnMouseDown", nachVorne)
  local maus = CreateFrame("Frame", nil, fenster)
  maus:RegisterEvent("GLOBAL_MOUSE_DOWN")
  maus:SetScript("OnEvent", function()
    if not fenster:IsShown() then return end
    if fenster:IsMouseOver() then nachVorne() else nachHinten() end
  end)
  for _, f in ipairs({ "OpenAllBags", "ToggleAllBags", "ToggleBackpack", "OpenBackpack" }) do
    if _G[f] then hooksecurefunc(f, function() pcall(nachHinten) end) end
  end
  if EUI_Bags and EUI_Bags.HookScript then EUI_Bags:HookScript("OnShow", function() pcall(nachHinten) end) end
  local ev = CreateFrame("Frame", nil, fenster)
  ev:RegisterEvent("BAG_UPDATE_DELAYED"); ev:RegisterEvent("PLAYER_MONEY")
  ev:SetScript("OnEvent", function() if fenster:IsShown() then GF.aktualisieren() end end)
  fenster:Hide()
  zeigeAnsicht(GoldForeverDB.reiter or "standard")
end

-- Am Auktionshaus automatisch daneben öffnen (immer Standard · Kaufen), beim Schließen wieder weg
-- 2.51.1: nicht mehr auf „Raid & Events“ springen, nur weil dort mehr Einkäufe stehen (Wunsch Alex 17.11.)
local vomAH = false
local function ahReiter() return "standard" end
function GoldForever_AH(auf)
  if not fenster then baue() end
  if auf then
    local ar = ahReiter(); if ar == "standard" then GoldForeverDB.unter = "kauf" end
    if fenster:IsShown() then zeigeAnsicht(ar); return end
    fenster:ClearAllPoints()
    local pa = GoldForeverDB.posAH
    local ah = AuctionHouseFrame or AuctionFrame
    if pa then fenster:SetPoint(pa[1], UIParent, pa[1], pa[2], pa[3])
    elseif ah and ah:IsShown() then fenster:SetPoint("TOPLEFT", ah, "TOPRIGHT", 8, 0)
    else fenster:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -330, -220) end
    vomAH = true; fenster.ansicht = ar; fenster:Show(); zeigeAnsicht(fenster.ansicht)
  elseif vomAH then
    vomAH = false; fenster:Hide(); fenster:ClearAllPoints()
    local p = GoldForeverDB.pos
    fenster:SetPoint(p and p[1] or "CENTER", UIParent, p and p[1] or "CENTER", p and p[2] or 0, p and p[3] or 0)
    zeigeAnsicht(GoldForeverDB.reiter or "standard")
  else
    GF.aktualisieren()
  end
end

function GoldForever_Toggle()
  if not fenster then baue() end
  if fenster:IsShown() then fenster:Hide() else fenster:Show() end
end

-- ---------------------------------------------------------------- Einstellungen (vom Minimap-Knopf)
function GF.fensterZuruecksetzen()
  GoldForeverDB.pos, GoldForeverDB.posAH = nil, nil
  if fenster then fenster:ClearAllPoints(); fenster:SetPoint("CENTER", UIParent, "CENTER", 0, 0) end
  print(H.gold .. "Gold Forever:" .. ENDE .. " Fenster-Position zurückgesetzt.")
end
function GF.groesseZuruecksetzen()
  GoldForeverDB.groesse = 1
  if fenster then fenster:SetScale(1); GF.aktualisieren() end
  print(H.gold .. "Gold Forever:" .. ENDE .. " Fenster-Größe zurückgesetzt.")
end
function GF.testmodusUmschalten()
  GoldForeverDB.testmodus = not testmodus()
  if fenster then
    symbolePlatzieren()
    if fenster.ansicht == "test" and not testmodus() then zeigeAnsicht("standard") end
  end
  print(H.gold .. "Gold Forever:" .. ENDE .. " Testmodus " .. (testmodus() and "an" or "aus") .. ".")
end

-- ---------------------------------------------------------------- Minimap-Knopf
-- Linksklick: Fenster auf/zu · Rechtsklick: Einstellungen · Ziehen: am Minimap-Rand verschieben
-- Ist LibDBIcon geladen (von einem anderen Addon), meldet sich Gold Forever dort an – dann erfassen
-- Knopf-Sammler den Knopf. Sonst eigener runder Knopf.
local ICON = "Interface\\Icons\\INV_Ingot_03" -- Goldbarren
local function knopfDB()
  GoldForeverDB.knopf = GoldForeverDB.knopf or { minimapPos = 200, hide = false }
  return GoldForeverDB.knopf
end
local function knopfTooltip(tt)
  tt:AddLine(H.gold .. "Gold Forever" .. ENDE)
  local tb = GF.tagesbilanz and GF.tagesbilanz()
  if tb then tt:AddDoubleLine("Heute", plusMinus(tb), F.grau[1], F.grau[2], F.grau[3]) end
  local z = GF.reiterZahlen()
  tt:AddDoubleLine("Verkaufen", "Standard " .. (z.standard or 0) .. "  ·  Raid " .. (z.raid or 0), F.grau[1], F.grau[2], F.grau[3], F.hell[1], F.hell[2], F.hell[3])
  local d = GoldForeverData
  local alter = d and d.stand and math.floor((time() - d.stand) / 3600)
  if alter then tt:AddLine("Daten vor " .. alter .. " Std.", F.grau[1], F.grau[2], F.grau[3]) end
  tt:AddLine("Linksklick: öffnen  ·  Rechtsklick: Einstellungen", F.grau[1], F.grau[2], F.grau[3])
end
local knopfEigen, ldbIcon
local function knopfZeigen(an)
  knopfDB().hide = not an
  if ldbIcon then if an then ldbIcon:Show("GoldForever") else ldbIcon:Hide("GoldForever") end
  elseif knopfEigen then knopfEigen:SetShown(an) end
end
local function menue(owner)
  if MenuUtil and MenuUtil.CreateContextMenu then
    MenuUtil.CreateContextMenu(owner, function(_, root)
      root:CreateTitle("Gold Forever")
      root:CreateButton("Fenster öffnen / schließen", function() GoldForever_Toggle() end)
      root:CreateButton("Fenster-Position zurücksetzen", function() GF.fensterZuruecksetzen() end)
      root:CreateButton("Fenster-Größe zurücksetzen", function() GF.groesseZuruecksetzen() end)
      root:CreateCheckbox("Testmodus (Test-Knopf im Fenster)", function() return testmodus() end, function() GF.testmodusUmschalten() end)
      root:CreateButton("Minimap-Knopf ausblenden", function()
        knopfZeigen(false); print(H.gold .. "Gold Forever:" .. ENDE .. " Minimap-Knopf ausgeblendet – wieder einblenden mit /gf knopf")
      end)
      root:CreateDivider()
      root:CreateTitle("Weitere Einstellungen folgen")
    end)
  else
    print(H.gold .. "Gold Forever:" .. ENDE .. " Einstellungen: /gf knopf · /gf test · /gf position · /gf groesse")
  end
end
local function klick(self, taste)
  if taste == "RightButton" then menue(self) else GoldForever_Toggle() end
end
local function eigenerKnopf()
  if not Minimap then return end
  local b = CreateFrame("Button", "GoldForeverMinimapKnopf", Minimap)
  b:SetSize(31, 31); b:SetFrameStrata("MEDIUM"); b:SetFrameLevel(8)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp"); b:RegisterForDrag("LeftButton")
  b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  local bg = b:CreateTexture(nil, "BACKGROUND"); bg:SetSize(20, 20); bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background"); bg:SetPoint("TOPLEFT", 7, -5)
  local ic = b:CreateTexture(nil, "ARTWORK"); ic:SetSize(17, 17); ic:SetTexture(ICON); ic:SetPoint("TOPLEFT", 7, -6); ic:SetTexCoord(0.05, 0.95, 0.05, 0.95)
  local rd = b:CreateTexture(nil, "OVERLAY"); rd:SetSize(53, 53); rd:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder"); rd:SetPoint("TOPLEFT")
  local function setzen()
    local w = math.rad(knopfDB().minimapPos or 200)
    local x, y = math.cos(w), math.sin(w)
    local r = (Minimap:GetWidth() or 140) / 2 + 5
    local form = GetMinimapShape and GetMinimapShape() or "ROUND"
    if form == "SQUARE" then local m = math.max(math.abs(x), math.abs(y)); if m > 0 then x, y = x / m, y / m end end
    b:ClearAllPoints(); b:SetPoint("CENTER", Minimap, "CENTER", x * r, y * r)
  end
  b:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local px, py = GetCursorPosition()
      local s = Minimap:GetEffectiveScale()
      local winkel = math.deg(math.atan2(py / s - my, px / s - mx))
      knopfDB().minimapPos = winkel % 360
      setzen()
    end)
  end)
  b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  b:SetScript("OnClick", klick)
  b:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_LEFT"); knopfTooltip(GameTooltip); GameTooltip:Show() end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  setzen()
  b:SetShown(not knopfDB().hide)
  knopfEigen = b
end
local function knopfStart()
  local ldb = LibStub and LibStub("LibDataBroker-1.1", true)
  local icon = LibStub and LibStub("LibDBIcon-1.0", true)
  if ldb and icon then
    local obj = ldb:NewDataObject("GoldForever", { type = "launcher", text = "Gold Forever", icon = ICON,
      OnClick = klick, OnTooltipShow = knopfTooltip })
    local ok = pcall(icon.Register, icon, "GoldForever", obj, knopfDB())
    if ok then ldbIcon = icon; return end
  end
  eigenerKnopf()
end
local start = CreateFrame("Frame")
start:RegisterEvent("PLAYER_LOGIN")
start:SetScript("OnEvent", function() pcall(knopfStart) end)

-- /gf knopf · /gf test · /gf position · /gf groesse (alles andere wie bisher in Core.lua)
local altSlash = SlashCmdList.GOLDFOREVER
SlashCmdList.GOLDFOREVER = function(arg)
  local a = string.lower(arg or "")
  if a == "logo" then
    GoldForeverDB.logo = not (GoldForeverDB.logo == true); GF.logoSetzen()
    print(H.gold .. "Gold Forever:" .. ENDE .. (GoldForeverDB.logo and " Logo an (braucht Media\\Logo.tga, sonst bleibt der Kopf leer – dann /gf logo erneut)." or " Logo aus, Schriftzug „Gold Forever“."))
    return
  end
  if a == "knopf" then knopfZeigen(knopfDB().hide); print(H.gold .. "Gold Forever:" .. ENDE .. " Minimap-Knopf " .. (knopfDB().hide and "aus" or "an") .. ".") ; return end
  if a == "test" then GF.testmodusUmschalten(); return end
  if a == "position" then GF.fensterZuruecksetzen(); return end
  if a == "groesse" or a == "größe" then GF.groesseZuruecksetzen(); return end
  if altSlash then altSlash(arg) end
end
