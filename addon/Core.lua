-- Gold Forever: Kern (Preise, Empfehlungen, Tooltip, Loot-Hinweise)
-- Preise kommen live aus TSM (falls installiert), sonst aus der Gold-Forever-Datendatei.

local ADDON = ...
GoldForever = GoldForever or {}
local GF = GoldForever
GoldForeverDB = GoldForeverDB or {}

local GOLD = "|cfff5c451"
local GRUEN = "|cff4ade80"
local BLAU = "|cff38bdf8"
local GRAU = "|cff8b93a5"
local WEISS = "|cffe7e9ee"
local ENDE = "|r"
GF.farbe = { gold = GOLD, gruen = GRUEN, blau = BLAU, grau = GRAU, weiss = WEISS }

local function D() return GoldForeverData or {} end

-- ---------------------------------------------------------------- Hilfen
-- Geldbetrag mit Muenz-Icons (Gold/Silber/Kupfer), z. B. 1[G] 52[S] 43[K]
local MUENZE = {
  g = "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t",
  s = "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t",
  c = "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t",
}
function GF.geld(c)
  if not c then return "—" end
  c = math.floor(c + 0.5)
  local minus = c < 0 and "-" or ""
  c = math.abs(c)
  local g, s, k = math.floor(c / 10000), math.floor(c / 100) % 100, c % 100
  local t = {}
  if g > 0 then t[#t + 1] = g .. MUENZE.g end
  if s > 0 then t[#t + 1] = s .. MUENZE.s end
  if k > 0 or #t == 0 then t[#t + 1] = k .. MUENZE.c end
  return minus .. table.concat(t, " ")
end

local function tag(datum) -- "2026-12-09" -> Zeitstempel (Mitternacht lokal)
  local y, m, d = string.match(datum or "", "(%d+)-(%d+)-(%d+)")
  if not y then return nil end
  return time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 0 })
end
function GF.tageBis(datum)
  local t = tag(datum); if not t then return nil end
  return math.ceil((t - time()) / 86400)
end

local WT = { "So", "Mo", "Di", "Mi", "Do", "Fr", "Sa" }
GF.WT = WT

-- ---------------------------------------------------------------- Preise
local function tsm(quelle, id)
  if not (TSM_API and TSM_API.GetCustomPriceValue) then return nil end
  local ok, v = pcall(TSM_API.GetCustomPriceValue, quelle, "i:" .. id)
  if ok and type(v) == "number" and v > 0 then return v end
  return nil
end

-- Live-Preise aus Auktionshaus-Suchen (Blizzard-AH oder TSM, beide nutzen dieselbe Suche)
GF.live = {} -- [id] = {p = guenstigster Stueckpreis, n = Anzahl Angebote, t = Zeit}
-- Live-Preis aus der letzten AH-Suche: 10 Min. gilt er als "frisch" (AH live),
-- fuer Entscheidungen zaehlt er bis zu 2 Std. vor den TSM-Daten (sonst springt z. B. eine
-- Position nach der Suche zwischen "halten" und "jetzt einstellen" hin und her).
local LIVE_FRISCH, LIVE_MERKEN = 600, 7200
function GF.livePreis(id, frisch)
  local l = GF.live[tonumber(id)]
  if l and l.p and time() - l.t < (frisch and LIVE_FRISCH or LIVE_MERKEN) then return l.p, l end
  return nil
end
-- Letzte AH-Suche fand nur eigene Auktionen (kein fremdes Angebot): eigener Preis ist kein Marktpreis
function GF.liveNurEigene(id)
  local l = GF.live[tonumber(id)]
  return (l and not l.p and l.eigen and time() - l.t < LIVE_MERKEN) and true or false
end

-- Preis, zu dem man die gewuenschte Menge wirklich bekommt (Stueckpreis des letzten noetigen Angebots).
-- Ein paar billige Einzelstuecke ganz oben zaehlen so nicht als "guenstig" (Elementarerde 15.11.).
-- nil = keine AH-Suche in den letzten 2 Std.
-- Wie viele Stueck gibt es laut letzter Suche/Vollscan bis zu diesem Stueckpreis? nil = keine Live-Daten
function GF.mengeBis(id, maxPreis)
  local p, l = GF.livePreis(id)
  if not p then return nil end
  if not (l and l.st and #l.st > 0) then return p <= maxPreis and 999999 or 0 end
  local n = 0
  for _, x in ipairs(l.st) do
    if x.p <= maxPreis then n = n + (x.q or 1) else return n end
  end
  return #l.st >= 30 and 999999 or n -- alle gemerkten Stufen guenstig genug: Menge offen
end

function GF.kaufPreis(id, menge)
  local p, l = GF.livePreis(id)
  if not p then return nil end
  if not (l and l.st and #l.st > 0) then return p end
  local summe = 0
  for _, x in ipairs(l.st) do
    summe = summe + (x.q or 1)
    if summe >= (menge or 1) then return x.p end
  end
  return l.st[#l.st].p -- nicht genug im Angebot: teuerste gesehene Stufe
end

-- Liefert {n, p, r, mw, u, a, s, g, live}
function GF.info(id)
  id = tonumber(id); if not id then return nil end
  local it = (D().items or {})[id]
  local p = GF.livePreis(id) or tsm("DBRecent", id) or tsm("DBMinBuyout", id)
  local r = tsm("DBRegionSaleAvg", id) or tsm("DBRegionMarketAvg", id)
  local mw = tsm("DBMarket", id)
  -- Kaufpreis beim Haendler: TSM merkt ihn sich beim Haendlerbesuch, Gold Forever ebenfalls (GoldForeverDB.haendler)
  local vb = tsm("VendorBuy", id) or (GoldForeverDB.haendler and GoldForeverDB.haendler[id])
  local name, _, q, _, _, _, _, _, _, _, vk, kl = (C_Item and C_Item.GetItemInfo or GetItemInfo)(id)
  local sr = tsm("DBRegionSaleRate*1000", id)
  -- 2.56 (Befund 49): Items, die nur in den Realm-Daten (GitHub) stehen, kennt GF jetzt auch
  local rl = not it and GF.realm(id)
  if not it and not p and not r and not (vk and vk > 0) and not vb and not rl then return nil end
  if not it and not name and C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
  local nurRealm = (not it) and rl and true or nil
  it = it or {}
  local u = it[5]
  if not u and nurRealm and rl.vt then u = rl.vt end
  if not u then local spd = tsm("DBRegionSoldPerDay*1000", id); u = spd and spd / 1000 or nil end
  return {
    n = it[1] or name or (nurRealm and ("Item " .. id)) or nil, p = p or it[2] or (nurRealm and rl.m0) or nil, r = r or it[3], mw = mw or it[4], u = u, a = it[6], s = it[7], g = it[8],
    q = q, vk = (vk and vk > 0) and vk or nil, vb = vb, live = p ~= nil, ahLive = GF.livePreis(id, true) ~= nil, ahGeprueft = GF.livePreis(id) ~= nil or GF.liveNurEigene(id),
    kl = kl, sr = sr and sr / 1000 or nil, id = id, nurRealm = nurRealm,
    opMin = tsm("AuctioningOpMin", id), -- Mindestpreis deiner TSM-Einstell-Operation (darunter ueberspringt TSM)
  }
end

-- Ueblicher Preis ("Referenz") fuer alle Kauf- und Verkaufsregeln:
--   Realm: Median des guenstigsten Angebots der letzten 7 Tage (ab 6 stuendlichen Messungen, aus der Datendatei)
--   sonst: min(Regions-Verkaufsschnitt, Marktwert)
-- Grund: auf dem eigenen Realm liegen viele Items dauerhaft unter dem Regions-Ø (z. B. Donnernder Gluecksbringer
-- Region 32s 95c, Realm 25s) – gegen den Regions-Ø waeren sie scheinbar immer "guenstig".
-- Realm-Daten direkt aus GitHub (2.52): GoldForeverRealm.i[id] = {m, n, m0, tr3, fall, vt, vp, st}
-- m = Median der Tagesmediane (bis 7 Tage, alle Auktionen des Realms), m0 = letzte 24 Std.
-- Auswertung Woche 1: gegen diesen Wert lagen Verlust-Kaeufe im Median bei 100 %, Gewinn-Kaeufe bei 78 %.
function GF.realm(id)
  local R = GoldForeverRealm
  local r = R and R.i and R.i[tonumber(id)]
  if not r then return nil end
  return { m = (r[1] or 0) > 0 and r[1] or nil, n = r[2] or 0, m0 = (r[3] or 0) > 0 and r[3] or nil, tr3 = r[4] or 0,
    fall = r[5] or 0, vt = (r[6] or 0) > 0 and r[6] or nil, vp = (r[7] or 0) > 0 and r[7] or nil, st = r[8] or 0 }
end
function GF.realmAlter() local R = GoldForeverRealm; return R and R.t and (time() - R.t) or nil end
-- 2.56 (Befund 49): alle Items, die GF fuer Kaufen/Pruefen betrachtet = Datendatei + Realm-Items mit
-- >= 20 Verkaeufen/Tag und >= 3 Tagen Daten (vorher nur die ~790 Items der TSM-Liste, ~950 Handelswaren fehlten).
-- mitLive = true: Realm-Items nur, wenn es einen aktuellen AH-Preis gibt (Vollscan/Suche) – spart Rechenzeit.
local idsCache = {}
function GF.alleIds(mitLive)
  local R = GoldForeverRealm
  local key = (R and R.t or 0) .. ":" .. tostring(D().stand)
  if idsCache.key ~= key then
    local ids = {}
    for id in pairs(D().items or {}) do ids[tonumber(id) or id] = "datei" end
    if R and R.i then
      for id, r in pairs(R.i) do
        if not ids[id] and (r[6] or 0) >= 20 and (r[2] or 0) >= 3 and (r[1] or 0) > 0 then ids[id] = "realm" end
      end
    end
    idsCache = { key = key, ids = ids }
  end
  if not mitLive then return idsCache.ids end
  local out = {}
  for id, w in pairs(idsCache.ids) do if w == "datei" or GF.livePreis(id) then out[id] = w end end
  return out
end

function GF.referenz(id, i)
  i = i or GF.info(id); if not i then return nil end
  local z = (D().zeit or {})[tonumber(id)]
  local rl = GF.realm(id)
  if rl and rl.m and rl.n >= 3 then return rl.m, "realm", z end
  if z and z.m and (z.n or 0) >= 6 then return z.m, "realm", z end
  if i.r and i.r > 0 then return math.min(i.r, (i.mw and i.mw > 0) and i.mw or i.r), "region", z end
  return nil, nil, z
end

-- Tagesrhythmus (aus der Datendatei, ueber alle Items): wann ist es meist am teuersten / billigsten?
-- Liefert {vVon, vBis, kVon, kBis, spanne (% Unterschied), jetztVerk, jetztKauf} oder nil (zu wenig Daten / kein Effekt)
local tfCache = { t = 0 }
function GF.tagesfenster()
  if tfCache.wert ~= nil and time() - tfCache.t < 300 then return tfCache.wert or nil end
  local T = D().tag or {}
  local we = ({ Sa = true, So = true })[GF.WT[tonumber(date("%w")) + 1]]
  local prof = T[we and "we" or "wt"]
  -- eigenes Wochenend-/Werktagsprofil erst, wenn es genug Stunden mit >= 2 Tagen hat
  local gut = 0; for _, v in pairs(prof or {}) do if (v.n or 0) >= 2 then gut = gut + 1 end end
  if gut < 16 then prof = T.alle end
  local stunden = 0; for _ in pairs(prof or {}) do stunden = stunden + 1 end
  local wert = false
  if prof and stunden >= 16 then
    local function p(h) local v = prof[h % 24] or prof[tostring(h % 24)]; return v and v.p end
    local bestV, bestK, vH, kH
    for h = 0, 23 do -- 3-Stunden-Fenster
      local a, b, c2 = p(h), p(h + 1), p(h + 2)
      if a and b and c2 then
        local s = (a + b + c2) / 3
        if not bestV or s > bestV then bestV, vH = s, h end
        if not bestK or s < bestK then bestK, kH = s, h end
      end
    end
    if bestV and bestK and bestV - bestK >= 2 then
      -- in Minuten rechnen: das Fenster gilt schon 60 Min. vorher (eine Auktion laeuft ohnehin 12+ Std.
      -- und steht dann zum Tageshoch im AH) bis zum Ende der 3 Stunden
      local jetzt = tonumber(date("%H")) * 60 + tonumber(date("%M"))
      local function drin(von) local d = (jetzt - von * 60) % 1440; return d < 180 or d >= 1440 - 60 end
      local function bis(von) return ((von * 60 - jetzt) % 1440) / 60 end
      wert = { vVon = vH, vBis = (vH + 3) % 24, kVon = kH, kBis = (kH + 3) % 24, spanne = math.floor(bestV - bestK + 0.5),
        jetztVerk = drin(vH), jetztKauf = drin(kH), bisVerk = bis(vH) }
    end
  end
  tfCache.wert, tfCache.t = wert, time()
  return wert or nil
end

-- Erholt sich ein Item nach einem Preistief wieder? (aus dem Verlauf: Tief <= 85 % des Medians,
-- erholt = innerhalb 12 Std. wieder >= 95 %). Eigene Quote ab 2 Tiefs, sonst Quote der Warengruppe.
-- Befund 14.11.: Massenware 95 %, Beruf 83 %, Markt 78 %, Forever-Neu 75 %, Qualitaetsware 55 %.
function GF.erholung(id, i)
  local z = (D().zeit or {})[tonumber(id)]
  if z and (z.dip or 0) >= 2 then return z.erh / z.dip, "item" end
  local g = i and i.g
  local G = g and (D().gruppen or {})[g]
  if G and G.q then return G.q, "gruppe" end
  return nil
end

-- Laeuft fuer das Item gerade ein Event, das bald endet? Dann bricht die Nachfrage weg.
local eventIndex
function GF.eventEndetBald(id)
  if not eventIndex then
    eventIndex = {}
    for _, e in ipairs(D().events or {}) do
      for _, sid in ipairs(e[5] or {}) do
        local n = tonumber(sid); if n then eventIndex[n] = eventIndex[n] or {}; table.insert(eventIndex[n], e) end
      end
    end
  end
  for _, e in ipairs(eventIndex[tonumber(id)] or {}) do
    local von, bis = GF.tageBis(e[2]), GF.tageBis(e[3] or e[2])
    if von and bis and von <= 0 and bis >= 0 and bis <= 3 then return e[1], bis end
  end
  return nil
end

-- Aufkaeufer (Reset): Datendatei markiert Items, deren Preis sprunghaft >= 2x stieg, waehrend die Angebote
-- fast verschwanden. Aktiv, solange der Preis noch >= 1,4x vorher liegt. Liefert Faktor, Vorher-Preis.
local PFEIL = "|TInterface\\Buttons\\Arrow-Up-Up:13:13:0:-2:32:32:0:32:0:32:251:146:60|t"
GF.PFEIL = PFEIL
function GF.aufkaeufer(id, i)
  local z = (D().zeit or {})[tonumber(id)]
  if not (z and z.rs and z.rs.v and z.rs.v > 0) then return nil end
  i = i or GF.info(id)
  local p = i and i.p; if not p then return nil end
  local x = p / z.rs.v
  if x < 1.4 then return nil end
  return x, z.rs.v
end
function GF.faktor(x) return (string.format("×%.1f", x):gsub("%.", ",")) end

-- Faellt der Preis seit Tagen? (rollende 24-Std.-Fenster aus den GitHub-Kennzahlen, Tagesrhythmus zaehlt nicht)
-- Liefert einen kurzen Text oder nil. 2.51: sperrt Kaeufe, bricht unterbotene Ware frueher ab, Verlustbremse.
function GF.faelltTage(id)
  local rl = GF.realm(id)
  if rl and rl.n >= 3 then
    if rl.fall >= 2 then return "seit " .. rl.fall .. " Tagen" end
    if rl.tr3 <= -10 then return rl.tr3 .. " % in 3 Tagen" end
    return nil
  end
  local z = (D().zeit or {})[tonumber(id)]
  if not z then return nil end
  if (z.rfall or 0) >= 2 then return "seit " .. z.rfall .. " Tagen" end
  if z.rtr3 and z.rtr3 <= -10 then return z.rtr3 .. " % in 3 Tagen" end
  return nil
end

-- ---------------------------------------------------------------- Lernsystem (2.54, Wunsch Alex 20.11.)
-- Aus dem Bilanz-Buch: jedes nach Vorschlag gekaufte/hergestellte Los wird mit den spaeteren Verkaeufen
-- (zuerst gekauft = zuerst verkauft) abgeglichen. Je Item und je Warengruppe: Anzahl Geschaefte, Treffer
-- (mit Gewinn), Ø Rendite, Ø Haltedauer, Gewinn, Verluste in Folge.
--   bewaehrt  = >= 2 Geschaefte, >= 70 % mit Gewinn, Ø Rendite > +5 %  -> Kaufgrenze 88 % statt 85 %, mehr Menge, oben im Plan
--   vorsicht  = >= 2 Geschaefte und < 40 % Treffer, oder die letzten 2 mit Verlust -> Kaufgrenze 75 %
local lernCache = { n = -1 }
function GF.lernen()
  local buch = (GoldForeverDB.bilanz and GoldForeverDB.bilanz.buch) or {}
  if lernCache.n == #buch and lernCache.item then return lernCache end
  local lose, item, gruppe = {}, {}, {}
  local function dazu(tab, key, r, std, g)
    local x = tab[key] or { n = 0, plus = 0, rend = 0, std = 0, gewinn = 0, folge = 0 }
    x.n = x.n + 1
    if g > 0 then x.plus = x.plus + 1; x.folge = 0 else x.folge = x.folge + 1 end
    x.rend = x.rend + r; x.std = x.std + std; x.gewinn = x.gewinn + g
    tab[key] = x
  end
  for _, x in ipairs(buch) do
    if (x.art == "kauf" or x.art == "herg") and x.v and (x.n or 0) > 0 then
      local q = lose[x.id] or {}; q[#q + 1] = { n = x.n, preis = -(x.betrag or 0) / x.n, t = x.t, verk = 0, vn = 0 }; lose[x.id] = q
    elseif x.art == "verk" and (x.n or 0) > 0 and lose[x.id] and #lose[x.id] > 0 then
      local q, rest, proStk = lose[x.id], x.n, (x.betrag or 0) / x.n
      while rest > 0 and #q > 0 do
        local l = q[1]
        local m = math.min(rest, l.n)
        l.verk = l.verk + proStk * m; l.vn = l.vn + m; l.n = l.n - m; rest = rest - m
        if l.n <= 0 then
          local schnitt = l.verk / l.vn
          local r = l.preis > 0 and (schnitt / l.preis - 1) or 0
          local g = math.floor((schnitt - l.preis) * l.vn)
          local std = (x.t - l.t) / 3600
          dazu(item, x.id, r, std, g)
          local it = (D().items or {})[x.id]
          if it and it[8] then dazu(gruppe, it[8], r, std, g) end
          table.remove(q, 1)
        end
      end
    end
  end
  for _, tab in ipairs({ item, gruppe }) do
    for _, x in pairs(tab) do
      x.quote = x.plus / x.n; x.avg = x.rend / x.n; x.avgStd = x.std / x.n
      x.bewaehrt = x.n >= 2 and x.quote >= 0.7 and x.avg > 0.05
      x.vorsicht = (x.n >= 2 and x.quote < 0.4) or x.folge >= 2
    end
  end
  lernCache = { n = #buch, item = item, gruppe = gruppe }
  return lernCache
end
function GF.erfahrung(id) local L = GF.lernen(); return L.item[tonumber(id)] end
-- Trefferquote fuer die Sortierung des Einkaufsplans: eigenes Item (>= 2), sonst Warengruppe (>= 5), sonst Erholungsquote
function GF.trefferQuote(id, i)
  local L = GF.lernen()
  local e = L.item[tonumber(id)]
  if e and e.n >= 2 then return e.quote, "item" end
  local g = i and i.g and L.gruppe[i.g]
  if g and g.n >= 5 then return g.quote, "gruppe" end
  return GF.erholung(id, i) or 0.75, "erholung"
end
function GF.erfahrungText(e)
  if not e then return nil end
  local p = math.floor(e.avg * 100 + 0.5)
  return e.n .. "× gehandelt, " .. e.plus .. "× mit Gewinn · Ø " .. (p >= 0 and "+" or "") .. p .. " % · Ø " .. math.floor(e.avgStd + 0.5) .. " Std."
end

-- Genug Handel fuer Kauf-Empfehlungen? (sonst bleibt man auf der Ware sitzen)
function GF.handelbar(i)
  -- 2.56: Realm-Items ohne Item-Infos (noch nicht geladen) nicht kaufen – Klasse unbekannt
  if i.nurRealm and not i.kl then return false, "Item-Infos laden noch" end
  if i.nurRealm and i.q and i.q >= 3 then return false, "Qualitätsware schwankt zu stark" end
  if (i.u or 0) < 20 then return false, "zu wenig Umsatz (" .. math.floor((i.u or 0) + 0.5) .. "/Tag)" end
  if i.sr and i.sr < 0.2 then return false, "verkauft sich selten" end
  if i.kl == 9 then return false, "Rezepte schwanken zu stark" end
  if i.kl == 2 or i.kl == 4 then return false, "Ausrüstung schwankt zu stark" end
  return true
end

-- realistischer Verkaufswert nach 5 % Gebuehr
function GF.wert(i)
  if not i then return nil end
  local m
  -- 2.55 (Befund 43): mit Realm-Daten zaehlt der Realm – der Regions-Ø liegt auf Forever oft weit darunter
  -- (Flitzdistel: Realm 9s 59c, Region 4s 10c -> Wert war 3s 89c). Live-Preis darunter gewinnt (man muss unterbieten).
  local R, quelle = nil, nil
  if i.id and GF.referenz then R, quelle = GF.referenz(i.id, i) end
  if quelle == "realm" and R and R > 0 then
    m = R
    if i.p and i.p > 0 and i.p < m then m = i.p end
  else
    for _, v in ipairs({ i.p, i.mw, i.r }) do if v and v > 0 and (not m or v < m) then m = v end end
  end
  if m and i.vb then m = math.min(m, i.vb - 1) end -- teurer als beim Haendler kauft niemand
  return m and math.floor(m * 0.95) or nil
end

function GF.tempo(i)
  if not i or not i.u or i.u <= 0 then return nil end
  local lv = (i.u >= 200 and 1) or (i.u >= 50 and 2) or 3
  if (i.a or 0) / i.u > 2 and lv < 3 then lv = lv + 1 end
  return ({ "meist in wenigen Stunden", "meist innerhalb eines Tages", "oft 1–2 Tage" })[lv]
end

function GF.einstellen(i)
  if not i or not i.p then return nil end
  local R = i.id and GF.referenz(i.id, i) or i.r
  local boden = R and math.floor(R * 0.9) or 0
  local preis = math.max(i.p - 1, boden)
  -- Ausreisser: wenn das guenstigste Angebot weit ueber dem ueblichen Preis liegt, nahe daran einstellen
  local anker = R or 0
  -- Ausreisser abfangen – ausser bei Aufkaeufer-Preis: dann knapp unter ihm einstellen
  if anker > 0 and i.p > anker * 2 and not (i.id and GF.aufkaeufer(i.id, i)) then preis = math.floor(anker * 1.2) end
  if i.vb then preis = math.min(preis, i.vb - 1) end
  -- 2.52 (Befund 26): Forever hat die Classic-Laufzeiten 2 / 8 / 24 Std. (Stufe 1/2/3). Standard 24 Std.,
  -- nur sehr schnell verkaufte Ware 8 Std. (Gebuehr kleiner). 2 Std. nie.
  local rl = i.id and GF.realm(i.id)
  local proTag = math.max(i.u or 0, rl and rl.vt or 0)
  local dauer = "24 Std." -- 2.53.2: immer 24 Std. (8-Std.-Regel griff wegen zu hoher Verkaufsschaetzung viel zu oft)
  return preis, dauer
end

-- Kann TSM das Item zu diesem Preis einstellen? TSM-Auctioning stellt nur ein, wenn das Item in einer
-- TSM-Gruppe mit Einstell-Operation ist (sonst "Operation: -") und der Preis nicht unter deren Mindestpreis liegt.
-- Liefert nil (TSM kann) oder einen kurzen Grund; Ausweg ist der Knopf "WoW UI" in TSM.
function GF.tsmSperre(i, preis)
  if not (TSM_API and i) then return nil end
  if not i.opMin then return "keine TSM-Regel" end
  if preis and preis < i.opMin then return "unter TSM-Min " .. GF.geld(i.opMin) end
  return nil
end

-- ---------------------------------------------------------------- Raid & Rhythmus
function GF.raid(id) return (D().raid or {})[tonumber(id)] end
function GF.raidLaeuft() local t = GF.tageBis(D().raidstart); return t ~= nil and t <= 0 end
function GF.resetTag() return (GoldForeverDB.reset or D().reset or 3) end
function GF.wochenOff()
  local heute = tonumber(date("%w")) -- 0 = Sonntag
  return (heute - GF.resetTag() + 7) % 7
end
local PLAN = {
  dauer = { "verk", "verk", "kauf", "kauf", "kauf", "halt", "verk" },
  boss = { "verk", "verk", "kauf", "kauf", "kauf", "halt", "verk" },
  mat = { "verk", "halt", "kauf", "kauf", "kauf", "halt", "verk" },
  neu = { "halt", "halt", "kauf", "kauf", "halt", "halt", "halt" },
}
GF.PLAN = PLAN
local TYP = { dauer = "Raid-Dauerrenner", boss = "Boss-Trank", mat = "Raid-Mat", neu = "Neu in Forever" }
GF.TYP = TYP

-- ---------------------------------------------------------------- Empfehlung
-- Ergebnis: {text, farbe, art = "verk"|"kauf"|"halt"}
-- Feste Kategorien mit festen Farben:
--   haendler = grau, verk = gruen (Auktionshaus), halt = blau (behalten), kauf = lila, herstellen = gelb
local KAT = {
  haendler = { titel = "Händler", farbe = "|cff9ca3af", rgb = { 0.5, 0.52, 0.56 } },
  verk = { titel = "AH verkaufen", farbe = GRUEN, rgb = { 0.13, 0.95, 0.38 } },
  halt = { titel = "Behalten", farbe = "|cff60a5fa", rgb = { 0.25, 0.6, 1 } },
  kauf = { titel = "Kaufen", farbe = "|cffc084fc", rgb = { 0.75, 0.52, 0.99 } },
  herstellen = { titel = "Verarbeiten", farbe = "|cfffacc15", rgb = { 1, 0.82, 0.05 } },
}
-- kleines farbiges Quadrat mit dunklem Rand, gleiche Farbe wie die Taschen-Marke
function GF.katIcon(art, groesse)
  local k = KAT[art]; if not k then return "" end
  local s = groesse or 11
  local r, g, b = math.floor(k.rgb[1] * 255), math.floor(k.rgb[2] * 255), math.floor(k.rgb[3] * 255)
  return "|TInterface\\Buttons\\WHITE8X8:" .. s .. ":" .. s .. ":0:0:8:8:0:8:0:8:" .. r .. ":" .. g .. ":" .. b .. "|t"
end
GF.KAT = KAT
local function E(art, grund) local k = KAT[art]; return { art = art, titel = k.titel, grund = grund, farbe = k.farbe, text = k.titel .. " · " .. grund } end

local function basisEmpfehlung(id, i, eigen)
  local hat = eigen or GF.anzahl(id) > 0
  local ah = GF.wert(i)
  if i.vk and (i.q == 0 or not ah or i.vk >= ah * 0.8) then return E("haendler", "zahlt " .. GF.geld(i.vk)) end
  -- Haendlerware: im AH nur unter dem Haendler-Kaufpreis verkaeuflich, also kein Extra-Gewinn
  -- Haendlerware (beim Haendler unbegrenzt zu haben): nie vorschlagen – weder kaufen noch verkaufen (Wunsch Alex 15.11.)
  if i.vb or GF.HAENDLERWARE[tonumber(id)] then
    local e = E("halt", "Händlerware" .. (i.vb and (", kostet beim Händler " .. GF.geld(i.vb)) or " – gibt es beim Händler")); e.still = true; return e
  end
  -- Aufkaeufer-Preis: eigene Ware jetzt verkaufen (faellt meist bald), sonst auf keinen Fall kaufen
  local ax, av = GF.aufkaeufer(id, i)
  if ax then
    local e
    if hat then e = E("verk", "Preissprung " .. GF.faktor(ax) .. " – jetzt verkaufen")
    else e = E("halt", "Preissprung " .. GF.faktor(ax) .. " – nicht kaufen") end
    e.reset, e.faktor, e.vorher = true, ax, av
    return e
  end
  local rk = GF.raid(id)
  local R, quelle, z = GF.referenz(id, i)
  local q = (i.p and R and R > 0) and (i.p / R) or nil
  -- Raid-Vorrat nur, wenn das Item gehandelt wird und der Preis nicht gerade faellt
  -- Gegenprobe mit dem TSM-Marktwert: liegt der Preis darueber, ist er nicht wirklich guenstig
  -- Gegenprobe (Backtest 15.11.: Treffer 77 % -> 87 %): guenstig nur, wenn der Preis auch
  -- unter 95 % des TSM-Marktwerts UND nicht ueber dem Regions-Verkaufsschnitt liegt
  -- 2.55 (Befund 42): mit Realm-Daten keine Gegenprobe gegen den Regions-Ø mehr (auf Forever liegen viele Items
  -- dauerhaft darueber -> konnten nie Kauf werden). TSM-Marktwert ist realm-bezogen und bleibt.
  local function ueberMarktwert()
    if not i.p then return false end
    if i.mw and i.mw > 0 and i.p > i.mw * 0.95 then return true end
    if quelle ~= "realm" and i.r and i.r > 0 and i.p > i.r then return true end
    return false
  end
  local function gegenText() return "laut TSM nicht günstig (Marktwert " .. GF.geld(i.mw) .. (quelle ~= "realm" and (", Region " .. GF.geld(i.r)) or "") .. ")" end
  local function raidKauf(grund)
    if ueberMarktwert() then return E("halt", "Raid-Ware, aber " .. gegenText()) end
    local ok, warum = GF.handelbar(i)
    if not ok then local e = E("halt", "Raid-Ware, aber " .. warum); e.still = true; return e end
    if z and ((z.t or 0) <= -10 or (z.tl or 0) <= -10) then return E("halt", "Raid-Ware, Preis fällt noch – abwarten") end
    local ftr = GF.faelltTage(id)
    if ftr then return E("halt", "Raid-Ware, Preis fällt " .. ftr .. " – abwarten") end
    return E("kauf", grund)
  end
  if rk then
    local typ = rk[1]
    if not GF.raidLaeuft() then
      if typ == "neu" then
        if q and q <= 0.9 then return raidKauf("neu in Forever, günstig – kleine Menge testen") end
        return E("halt", "neu in Forever, Bedarf noch offen")
      end
      if q and q <= 1 then return raidKauf("vor Raidstart günstig auf Vorrat") end
      local y, m, d = string.match(D().raidstart or "", "(%d+)-(%d+)-(%d+)")
      return E("halt", "bis Raidstart" .. (d and (" " .. tonumber(d) .. "." .. tonumber(m) .. ".") or ""))
    end
    local a = PLAN[typ][GF.wochenOff() + 1]
    if a == "verk" and q and q >= 1 then return E("verk", "heute Raid-Nachfrage") end
    if a == "kauf" then
      if q and q <= 1 then return raidKauf("Preistief nach dem Reset") end
      return E("halt", "Preistief nach dem Reset – nicht verkaufen")
    end
    return E("halt", "bis zum Tag vor dem Reset")
  end
  if not q or (i.u or 0) < 50 then
    -- Wenig Umsatz: nur verkaufen, wenn der Preis gerade ueber dem ueblichen liegt; nie zum Kauf raten
    local proTag = math.max(1, math.floor((i.u or 0) + 0.5))
    if ah and (i.u or 0) > 0 and q and q >= 1.1 then
      local e = E("verk", "über üblich, verkauft sich aber langsam (ca. " .. proTag .. "/Tag)"); e.langsam = true; return e
    end
    local e = E("halt", (i.u or 0) > 0 and ("wenig Handel (ca. " .. proTag .. "/Tag), Preis nicht besonders") or "kaum Handel im Auktionshaus")
    e.still = true; return e
  end
  local abw = math.floor((q - 1) * 100 + 0.5)
  local wo = "üblich" -- 2.52 (Befund 25): immer „üblich“; Quelle (Realm/Region) steht im Tooltip
  -- Eigene Ware in einem Markt, der seit Tagen faellt: Warten kostet nur – jetzt verkaufen
  if z and z.tl and z.tl <= -10 and abw < 25 and hat then
    return E("verk", "Markt fällt seit Tagen (" .. z.tl .. " %) – lieber jetzt verkaufen")
  end
  local kaufGrenze = (quelle == "realm") and -15 or -25 -- ohne eigenen Verlauf strenger
  -- 2.54 Lernsystem: bewaehrte Items etwas frueher kaufen, Verlierer erst deutlich tiefer
  local erf = GF.erfahrung(id)
  -- 2.56: neue Items nur aus den Realm-Daten (ohne Datendatei/Erfahrung) vorsichtiger: erst ab 20 % unter üblich
  if i.nurRealm and not erf then kaufGrenze = math.min(kaufGrenze, -20) end
  if erf and erf.bewaehrt then kaufGrenze = kaufGrenze + 3 elseif erf and erf.vorsicht then kaufGrenze = kaufGrenze - 10 end
  if abw <= kaufGrenze then
    -- Kaufen nur, wenn: genug Handel, guenstiger Preis bestaetigt (2 Messungen in Folge oder live im AH),
    -- und der Preis nicht gerade noch stark faellt
    local ok, warum = GF.handelbar(i)
    if not ok then local e = E("halt", (-abw) .. " % unter " .. wo .. ", aber " .. warum); e.still = true; return e end
    if ueberMarktwert() then return E("halt", (-abw) .. " % unter " .. wo .. ", aber " .. gegenText()) end
    -- Markt wird geflutet (Angebot ploetzlich >= 3x so gross): neues Preisniveau statt Preistief (Backtest: 40 % statt 73 %)
    if z and z.am and z.am > 0 and i.a and i.a >= 20 and i.a >= 3 * z.am then
      return E("halt", (-abw) .. " % unter " .. wo .. ", aber Angebot plötzlich " .. math.floor(i.a / z.am + 0.5) .. "× so groß – Markt wird geflutet")
    end
    -- Live-Preis bestaetigt nur den Preis, nicht dass der Fall vorbei ist
    -- gleiche Schwelle wie die Anzeige "fällt noch" (-10 %), plus laengerer Trend (Tag gegen Vortag)
    -- Backtest 15.11.: "noch nicht bestaetigt" und "faellt noch (6 Std.)" senkten die Trefferquote – entfernt.
    if z and z.tl and z.tl <= -10 then return E("halt", (-abw) .. " % unter " .. wo .. ", Markt fällt seit Tagen (" .. z.tl .. " %) – abwarten") end
    -- Preissturz (z. B. neues Item, Blauer Machtkristall 15.11.: 14s 71c -> 3s 93c in 15 Std.): der Median hinkt
    -- hinterher, das "Tief" ist keins. Nur bei starkem Fall (>= 25 % in ~6 Std.), leichtes Fallen bleibt erlaubt.
    if z and (z.t or 0) <= -25 then return E("halt", (-abw) .. " % unter " .. wo .. ", aber Preis stürzt gerade (" .. z.t .. " %) – abwarten") end
    -- Langsamer Fall ueber Tage (2.51): kein echtes Tief, sondern neues Preisniveau
    local ft = GF.faelltTage(id)
    if ft then return E("halt", (-abw) .. " % unter " .. wo .. ", aber Preis fällt " .. ft .. " – abwarten") end
    -- Nur kaufen, was sich nach Preistiefs auch wieder erholt
    local erq = GF.erholung(id, i)
    if erq and erq < 0.7 then return E("halt", (-abw) .. " % unter " .. wo .. ", erholt sich aber selten (" .. math.floor(erq * 100 + 0.5) .. " %)") end
    -- Kein Kauf kurz vor Event-Ende (z. B. Dunkelmond-Abgaben)
    local ev, bis = GF.eventEndetBald(id)
    if ev then return E("halt", (-abw) .. " % unter " .. wo .. ", aber " .. ev .. " endet in " .. bis .. " Tagen – Nachfrage fällt") end
    local ek = E("kauf", (-abw) .. " % unter " .. wo .. ((erf and erf.bewaehrt) and " · bewährt" or ""))
    ek.bewaehrt = erf and erf.bewaehrt
    return ek
  end
  if abw >= 25 and (i.a or 3) >= 3 then
    return E("verk", abw .. " % über " .. wo .. ((i.p > R * 2) and " (teures Einzelangebot)" or ""))
  end
  -- Eigene Ware (z. B. gefarmt) zum normalen Preis: Halten bringt nichts – verkaufen, aber zur richtigen Uhrzeit.
  -- Raet das Addon zum Warten, merkt es sich den Preis von jetzt: Grundlage fuer den Mehrerloes in der Bilanz.
  local function warten(e)
    GoldForeverDB.warte = GoldForeverDB.warte or {}
    local w = GoldForeverDB.warte[id]
    if (not w or time() - w.t > 36 * 3600) and i.p then GoldForeverDB.warte[id] = { t = time(), p = i.p } end
    e.spaeter = true
    return e
  end
  if hat then
    if q < 0.95 then return warten(E("halt", "gerade unter " .. wo .. " – halten, bis der Preis zurück ist")) end
    if z and z.tl and z.tl <= -10 then return E("verk", "normaler Preis, Markt fällt seit Tagen – jetzt verkaufen") end
    if z and (z.t or 0) >= 10 then return warten(E("halt", "normaler Preis, steigt gerade – noch halten")) end
    local tf = GF.tagesfenster()
    -- Warten nur, wenn das Tageshoch bald kommt; ist es noch > 10 Std. weg, lohnen ein paar Prozent das Halten nicht
    if tf and not tf.jetztVerk and (tf.bisVerk or 0) <= 10 then
      return warten(E("halt", "normaler Preis – am besten " .. tf.vVon .. "–" .. tf.vBis .. " Uhr einstellen (ca. +" .. tf.spanne .. " %)"))
    end
    if tf and not tf.jetztVerk then return E("verk", "normaler Preis – Tageshoch erst morgen, lieber jetzt einstellen") end
    return E("verk", tf and "normaler Preis, jetzt ist Tageshoch" or "normaler Preis – Halten bringt nichts")
  end
  return E("halt", "Preis normal, kein Extra-Gewinn")
end

-- ---------------------------------------------------------------- Rezepte / Material-Check
local nutzIndex
-- 2.53 (Wunsch Alex): eigene, gelernte Rezepte (GoldForeverDB.rezepte[char][rezeptID] = {produkt, menge, beruf, 0, {{id, n}...}, name})
-- Sind fuer diesen Charakter Rezepte bekannt, zaehlen NUR diese (was er wirklich herstellen kann), sonst die Liste der Datendatei.
function GF.eigeneRezepte()
  local r = GoldForeverDB.rezepte and GoldForeverDB.rezepte[GF.charKey and GF.charKey() or ""]
  if not r then return nil end
  local liste = {}
  for _, x in pairs(r) do liste[#liste + 1] = x end
  return #liste > 0 and liste or nil
end
local function rezeptListe() return GF.eigeneRezepte() or D().rez or {} end
function GF.rezepteNeu() nutzIndex = nil end
local function index()
  if nutzIndex then return nutzIndex end
  nutzIndex = {}
  for _, r in ipairs(rezeptListe()) do
    for _, z in ipairs(r[5] or {}) do
      local t = nutzIndex[z[1]] or {}; t[#t + 1] = r; nutzIndex[z[1]] = t
    end
  end
  return nutzIndex
end

-- Bester Einsatz eines Materials: {name, proStueck, beruf}
function GF.besteNutzung(id)
  id = tonumber(id)
  local best
  for _, r in ipairs(index()[id] or {}) do
    local prod = GF.info(r[1]); local erl = GF.wert(prod)
    if erl then
      local andere, n, ok = 0, 1, true
      for _, z in ipairs(r[5]) do
        if z[1] == id then n = z[2] else
          local zi = GF.info(z[1]); if zi and zi.p then andere = andere + zi.p * z[2] else ok = false end
        end
      end
      if ok then
        local pro = (erl * (r[2] > 0 and r[2] or 1) - andere) / n
        if not best or pro > best.pro then best = { name = prod.n or ((C_Item and C_Item.GetItemInfo or GetItemInfo)(r[1])) or ("Item " .. r[1]), pro = pro, beruf = r[3], skill = r[4], id = r[1], r = r } end
      end
    end
  end
  return best
end

-- Realistischer Verkaufserloes pro Stueck (Wert oder Einstellpreis nach Gebuehr, das Hoehere)
function GF.verkaufswert(i)
  local w = GF.wert(i); if not w then return nil end
  local pr = GF.einstellen(i); if pr then w = math.max(w, math.floor(pr * 0.95)) end
  return w
end

-- Lohnt Verarbeiten deutlich mehr (> 10 %) als Verkaufen? -> beste Nutzung, Verkaufswert
-- 2.55 (Befund 44): wie der Reiter Herstellen erst ab 5s Mehrerloes fuer die eigene Menge – sonst "klein" (Tooltip grau)
function GF.verarbeitenLohnt(id, i)
  local b, w = GF.besteNutzung(id), GF.verkaufswert(i)
  if b and w and b.pro > w * 1.1 then
    local n = math.max(1, GF.anzahl(id))
    if (b.pro - w) * n < 500 then return nil, w, b, (b.pro - w) * n end
    return b, w
  end
  return nil, w
end

-- Empfehlung: Basisregel; Raid-, Haendler- und Haendlerware-Regeln haben Vorrang,
-- sonst gewinnt "Verarbeiten" (gelb), wenn es deutlich mehr bringt als Verkaufen.
-- Gleiche Entscheidung fuer Tooltip, Taschen-Marken und Fenster.
function GF.empfehlung(id, i, ohnePosition, eigen)
  i = i or GF.info(id); if not i then return nil end
  -- Selbst nach Vorschlag gekauft und noch nicht verkauft: dann zaehlt der Verkaufsplan
  if not ohnePosition and GF.position then
    local p = GF.position(id)
    local pl = p and GF.verkaufsPlan(p)
    if pl then
      local n = E(pl.art, (p.hergestellt and "hergestellt · " or "dein Einkauf · ") .. pl.kurz)
      if pl.stop then n.farbe = "|cfffb923c"; n.titel = "Verkaufen"; n.text = n.titel .. " · " .. n.grund end
      n.position = p; n.plan = pl; return n
    end
  end
  local e = basisEmpfehlung(id, i, eigen)
  if not e or e.art == "haendler" or e.still or GF.raid(id) then return e end
  local b, w = GF.verarbeitenLohnt(id, i)
  if b then
    local n = E("herstellen", "bringt mehr als Verkaufen")
    n.nutzung = b; return n
  end
  return e
end

-- Herstellen: Materialkosten, Erloes, Gewinn
function GF.herstellung(id)
  id = tonumber(id)
  for _, r in ipairs(rezeptListe()) do
    if r[1] == id then
      local k, ok = 0, true
      for _, z in ipairs(r[5]) do local zi = GF.info(z[1]); if zi and zi.p then k = k + zi.p * z[2] else ok = false end end
      local erl = GF.wert(GF.info(id))
      if ok and erl then return { kosten = k / (r[2] > 0 and r[2] or 1), erloes = erl, beruf = r[3], skill = r[4] } end
    end
  end
  return nil
end

-- ---------------------------------------------------------------- Bestand & Budget
-- Bestand in Taschen + Bank, OHNE angelegte Ausruestung (GetItemCount zaehlt Angelegtes mit)
function GF.anzahl(id)
  local f = (C_Item and C_Item.GetItemCount) or GetItemCount
  local ok, n = pcall(f, id, true)
  n = (ok and n) or 0
  if n > 0 and GetInventoryItemID then
    for slot = 1, 19 do
      local ok2, sid = pcall(GetInventoryItemID, "player", slot)
      if ok2 and sid == tonumber(id) then n = n - 1 end
    end
  end
  return math.max(0, n)
end

-- Ausgeblendete Items (selbst genutzt, z. B. Elixiere): kein Verkaufsvorschlag, keine Taschenmarke
-- Bekannte Haendlerware, auch ohne Haendlerbesuch (Preis unbekannt -> nur nicht vorschlagen)
GF.HAENDLERWARE = { [6530] = true } -- Nachtkriecher
function GF.ausgeblendet(id) return GoldForeverDB.ignor and GoldForeverDB.ignor[tonumber(id)] and true or false end
function GF.ausblenden(id)
  GoldForeverDB.ignor = GoldForeverDB.ignor or {}; GoldForeverDB.ignor[tonumber(id)] = true
  local name = ((C_Item and C_Item.GetItemInfo or GetItemInfo)(id)) or ("Item " .. id)
  -- 2.53.3 (Befund 37): 20 Sek. lang „Rückgängig“ im Fenster
  GF.rueckgaengig = { id = tonumber(id), t = time(), name = name }
  print(GOLD .. "Gold Forever:" .. ENDE .. " " .. name .. " ausgeblendet – im Fenster „Rückgängig“ oder über „ausgeblendet“ einzeln wieder einblenden.")
  if C_Timer then C_Timer.After(21, function() if GF.aktualisieren then pcall(GF.aktualisieren) end end) end
  if GF.punkteAktualisieren then pcall(GF.punkteAktualisieren) end
  if GF.aktualisieren then pcall(GF.aktualisieren) end
end
function GF.einblenden(id)
  if GoldForeverDB.ignor then GoldForeverDB.ignor[tonumber(id)] = nil end
  if GF.rueckgaengig and GF.rueckgaengig.id == tonumber(id) then GF.rueckgaengig = nil end
  if GF.punkteAktualisieren then pcall(GF.punkteAktualisieren) end
  if GF.aktualisieren then pcall(GF.aktualisieren) end
end
function GF.anzahlAusgeblendet() local n = 0; for _ in pairs(GoldForeverDB.ignor or {}) do n = n + 1 end; return n end
function GF.alleEinblenden()
  local n = GF.anzahlAusgeblendet(); GoldForeverDB.ignor = {}
  print(GOLD .. "Gold Forever:" .. ENDE .. " " .. n .. " Items wieder eingeblendet und neu geprüft.")
  if GF.punkteAktualisieren then pcall(GF.punkteAktualisieren) end
  if GF.aktualisieren then pcall(GF.aktualisieren) end
end

-- Alle Items, die der Charakter besitzt: Taschen (immer) + Bank (gemerkt beim letzten Bankbesuch)
-- + bekannte Markt-Items mit Bestand. So zeigt das Fenster dieselben Items wie die Taschenmarken.
local BANK_TASCHEN = { -1, -3, 6, 7, 8, 9, 10, 11, 12 }
function GF.bankMerken()
  if not (C_Container and C_Container.GetContainerNumSlots) then return end
  local ids = {}
  for _, b in ipairs(BANK_TASCHEN) do
    local ok, n = pcall(C_Container.GetContainerNumSlots, b)
    for s = 1, (ok and n or 0) do
      local ok2, info = pcall(C_Container.GetContainerItemInfo, b, s)
      if ok2 and info and info.itemID then ids[info.itemID] = true end
    end
  end
  GoldForeverDB.bankIds = GoldForeverDB.bankIds or {}
  GoldForeverDB.bankIds[GF.charKey()] = ids
end
function GF.eigeneIds()
  local ids = {}
  if C_Container and C_Container.GetContainerNumSlots then
    for b = 0, 5 do
      local ok, n = pcall(C_Container.GetContainerNumSlots, b)
      for s = 1, (ok and n or 0) do
        local ok2, info = pcall(C_Container.GetContainerItemInfo, b, s)
        if ok2 and info and info.itemID and not info.isBound then ids[info.itemID] = true end
      end
    end
  end
  for id in pairs(((GoldForeverDB.bankIds or {})[GF.charKey()]) or {}) do ids[id] = true end
  for id in pairs(D().items or {}) do if not ids[id] and GF.anzahl(id) > 0 then ids[id] = true end end
  return ids
end

function GF.verkaufListe()
  local out = {}
  for id in pairs(GF.eigeneIds()) do
    local n = GF.anzahl(id)
    if n > 0 then
      local i = GF.info(id); local e = not GF.ausgeblendet(id) and GF.empfehlung(id, i); local w = GF.wert(i)
      if e and e.art == "verk" and not e.langsam and w then local pr = GF.einstellen(i); if pr then w = math.floor(pr * 0.95) end; out[#out + 1] = { id = id, n = n, i = i, w = w, ges = w * n, e = e } end
    end
  end
  table.sort(out, function(a, b) return a.ges > b.ges end)
  return out
end
-- Eigene Ware, bei der Gold Forever zum Warten raet (Tageshoch, steigt, gerade unter ueblich)
function GF.warteListe()
  local out = {}
  for id in pairs(GF.eigeneIds()) do
    local n = GF.anzahl(id)
    if n > 0 then
      local i = GF.info(id); local e = not GF.ausgeblendet(id) and GF.empfehlung(id, i)
      -- auch eigene Ware, die gerade deutlich unter ueblich liegt (Kauf-Zweig) – sonst verschwindet sie aus dem Fenster
      if e and not e.position and (e.art == "kauf" or (e.art == "halt" and (e.spaeter or not e.still))) then
        local pr = GF.einstellen(i); local w = pr and math.floor(pr * 0.95) or GF.wert(i) or 0
        out[#out + 1] = { id = id, n = n, i = i, w = w, ges = w * n, e = e }
      end
    end
  end
  table.sort(out, function(a, b) return a.ges > b.ges end)
  return out
end

function GF.budgetPlan()
  local gold = GetMoney and GetMoney() or 0
  local budget = math.floor(gold * (D().budget or 0.7))
  local kand, grund = {}, {}
  for id in pairs(GF.alleIds(true)) do
    local i = GF.info(id)
    local e = i and i.p and i.p > 0 and GF.empfehlung(id, i, true)
    local R = e and e.art == "kauf" and not GF.raid(id) and not GF.ausgeblendet(id) and GF.referenz(id, i)
    -- 2.53 (Befund 34): Preis nur aus dem Vollscan und knapp an der Grenze -> erst nach Pruefung im AH vorschlagen
    local lvv = R and GF.live[tonumber(id)]
    if lvv and lvv.voll and i.p > R * 0.80 then grund[id] = "aus dem Vollscan knapp an der Grenze – wird im AH geprüft"; R = nil end
    if R then
      -- Ziel vorsichtig: ueblicher Preis, hoechstens TSM-Marktwert
      local ziel = (i.mw and i.mw > 0) and math.min(R, i.mw) or R
      local netto = math.floor(ziel * 0.95)
      local stueck = netto - i.p
      if stueck >= math.max(1, i.p * 0.1) then
        -- schon gekaufte (offene) Menge abziehen: von 10 vorgeschlagenen 3 gekauft -> noch 7
        local pos = GF.position(id)
        -- 2.52: Absatz = kleinerer Wert aus Region (TSM) und Realm-Verkaeufen (GitHub), 5 % davon
        local rl = GF.realm(id)
        local absatz = (rl and rl.vt) and math.min(i.u or rl.vt, rl.vt) or (i.u or 0)
        local erfM = GF.erfahrung(id)
        local markt = math.max(1, math.floor(absatz * ((erfM and erfM.bewaehrt) and 0.075 or 0.05))) - (pos and pos.n or 0)
        local maxKauf = math.floor(netto / 1.1)
        -- 2.51: nur so viel planen, wie es laut Suche/Vollscan bis zum Hoechstpreis gibt (vorher nur 5 Stueck geprueft)
        local verfuegbar = GF.mengeBis(id, maxKauf)
        if verfuegbar == 0 then grund[id] = "im AH gerade nichts bis " .. GF.geld(maxKauf)
        elseif markt < 1 then grund[id] = "schon genug gekauft (Grenze 5 % der Tagesverkäufe)"
        else
          if verfuegbar then markt = math.min(markt, verfuegbar) end
          kand[#kand + 1] = { id = id, i = i, ziel = ziel, stueck = stueck, markt = markt, maxKauf = maxKauf, schon = pos and pos.n or 0 }
        end
      else grund[id] = "Gewinn je Stück zu klein (" .. GF.geld(math.max(0, stueck)) .. ")" end
    end
  end
  -- Erwarteter Gewinn = moeglicher Gewinn x Erholungsquote (zuverlaessige Items zuerst)
  -- 2.54: erwarteter Gewinn x gelernte Trefferquote (eigenes Item, sonst Warengruppe, sonst Erholung)
  local function wert(k) return k.stueck * math.min(k.markt, math.floor(budget * 0.3 / k.i.p) - (k.schon or 0)) * (GF.trefferQuote(k.id, k.i)) end
  table.sort(kand, function(a, b) return wert(a) > wert(b) end)
  local rest, deals = budget, {}
  for _, k in ipairs(kand) do
    local menge = math.min(k.markt, math.floor(budget * 0.3 / k.i.p) - (k.schon or 0), math.floor(rest / k.i.p))
    -- Mindestgewinn 5s je Vorschlag: Kleinkram (ein paar Silber) lohnt den Aufwand nicht
    if menge < 1 then grund[k.id] = "Kaufbudget reicht nicht"
    elseif menge * k.stueck < 500 then grund[k.id] = "lohnt nicht: Gewinn " .. GF.geld(menge * k.stueck) .. " < 5s bei deinem Budget"
    elseif #deals >= 5 or rest < 100 then grund[k.id] = "Plan ist voll – andere Käufe bringen mehr"
    else
      k.menge = menge; k.gewinn = menge * k.stueck; deals[#deals + 1] = k
      rest = rest - menge * k.i.p
    end
  end
  return { gold = gold, budget = budget, deals = deals, grund = grund }
end

-- 2.55 (Befund 42): "Warum nicht gekauft?" – alle Items mindestens 10 % unter üblich, die nicht im Plan stehen,
-- mit Grund und Gruppe. Gruppen-Zaehlung wird gespeichert (GoldForeverDB.kaufDiag) fuer die Auswertung.
local DIAG = {
  { "nicht günstig", "TSM-Gegenprobe" }, { "erholt sich", "erholt sich selten" }, { "geflutet", "Markt geflutet" },
  { "stürzt", "Preis stürzt" }, { "fällt", "Preis fällt" }, { "wenig Handel", "wenig Handel" }, { "kaum Handel", "wenig Handel" },
  { "Gewinn je Stück", "Gewinn je Stück zu klein" }, { "lohnt nicht", "unter 5s Gewinn" }, { "Budget", "Budget" },
  { "Vollscan", "erst AH-Prüfung" }, { "nichts bis", "im AH nichts so billig" }, { "genug gekauft", "schon genug gekauft" },
  { "Plan ist voll", "Plan voll (max. 5)" }, { "Händler", "Händlerware" }, { "endet in", "Event endet" }, { "Raid", "Raid-Ware" },
  { "Preissprung", "Preissprung" }, { "nicht handelbar", "nicht handelbar" },
}
function GF.kaufDiagnose()
  local P = (GF.ah and GF.ah.plan) or GF.budgetPlan()
  local imPlan = {}; for _, d in ipairs(P.deals or {}) do imPlan[d.id] = true end
  local liste, kat = {}, {}
  for id in pairs(GF.alleIds(true)) do
    local i = not imPlan[id] and not GF.ausgeblendet(id) and GF.info(id)
    local R = i and i.p and i.p > 0 and GF.referenz(id, i)
    if R and i.p <= R * 0.9 then
      local grund = P.grund and P.grund[id]
      if not grund then
        local e = GF.empfehlung(id, i, true)
        grund = e and e.art ~= "kauf" and e.grund or nil
        if not grund and e and e.art == "kauf" then grund = "unter üblich, aber nicht im Plan" end
      end
      grund = grund or "unbekannt"
      local abw = math.floor((1 - i.p / R) * 100 + 0.5)
      local g
      for _, x in ipairs(DIAG) do if grund:find(x[1], 1, true) then g = x[2]; break end end
      g = g or (abw < 15 and "noch nicht tief genug" or "sonstiges")
      kat[g] = (kat[g] or 0) + 1
      liste[#liste + 1] = { id = id, n = i.n or ("Item " .. id), abw = abw, grund = grund, gruppe = g }
    end
  end
  table.sort(liste, function(a, b) return a.abw > b.abw end)
  local gr = {}; for g, n in pairs(kat) do gr[#gr + 1] = { g = g, n = n } end
  table.sort(gr, function(a, b) return a.n > b.n end)
  GoldForeverDB.kaufDiag = { t = time(), n = #liste, kat = kat, deals = #(P.deals or {}),
    top = (function() local t = {}; for k = 1, math.min(15, #liste) do local x = liste[k]; t[k] = { x.id, x.abw, x.grund } end; return t end)() }
  return liste, gr, #(P.deals or {})
end
function GF.kaufDiagnoseChat()
  local liste, gr, nd = GF.kaufDiagnose()
  print(GOLD .. "Gold Forever:" .. ENDE .. " Warum nicht gekauft? " .. #liste .. " Items mind. 10 % unter üblich, " .. nd .. " im Plan.")
  local teile = {}; for k = 1, math.min(6, #gr) do teile[#teile + 1] = gr[k].g .. " " .. gr[k].n end
  if #teile > 0 then print(GRAU .. "  " .. table.concat(teile, "  ·  ") .. ENDE) end
  for k = 1, math.min(10, #liste) do local x = liste[k]; print(GRAU .. "  -" .. x.abw .. " % " .. ENDE .. x.n .. GRAU .. ": " .. x.grund .. ENDE) end
end

function GF.naechstesEvent()
  local best
  for _, e in ipairs(D().events or {}) do
    local bis = GF.tageBis(e[3] or e[2])
    if bis and bis >= 0 then
      local von = GF.tageBis(e[2])
      if not best or von < best.von then best = { titel = e[1], von = von, bis = bis, art = e[4], items = e[5] } end
    end
  end
  return best
end

-- ---------------------------------------------------------------- Zeitfenster aus dem Preisverlauf
-- Datendatei liefert pro Item zeit = {t = Trend % (letzte ~6 Std.), ph = "hoch"|"tief"|"normal",
--   h = Std. in dieser Phase, d = typische Dauer solcher Phasen (Std., erst mit genug Verlauf),
--   bv = beste Stunde zum Verkaufen, bk = beste Stunde zum Kaufen (erst ab ~4 Tagen Verlauf)}
local ORANGE = "|cfffb923c"
function GF.zeit(id) return (D().zeit or {})[tonumber(id)] end
local function uhr(h) return h and (h .. " Uhr") or nil end
function GF.zeitText(id, art)
  local z = GF.zeit(id); if not z then return nil end
  local t, teile = z.t or 0, {}
  if art == "verk" then
    if z.ph == "hoch" and z.d and z.h then
      local rest = math.floor(z.d - z.h + 0.5)
      teile[#teile + 1] = rest >= 1 and (WEISS .. "noch ca. " .. rest .. " Std. hoch" .. ENDE) or (ORANGE .. "Hoch endet bald – jetzt" .. ENDE)
    elseif t <= -10 then teile[#teile + 1] = ORANGE .. "Preis fällt – heute verkaufen" .. ENDE
    elseif t >= 10 then teile[#teile + 1] = WEISS .. "Preis steigt noch" .. ENDE
    elseif z.ph == "hoch" and (z.h or 0) >= 1 then teile[#teile + 1] = WEISS .. "seit " .. z.h .. " Std. hoch" .. ENDE end
    if z.bv then teile[#teile + 1] = GRAU .. "beste Zeit ~" .. uhr(z.bv) .. ENDE
    else local tf = GF.tagesfenster(); if tf then teile[#teile + 1] = GRAU .. "Tageshoch meist " .. tf.vVon .. "–" .. tf.vBis .. " Uhr" .. ENDE end end
  else
    if z.ph == "tief" and z.d and z.h then
      local rest = math.floor(z.d - z.h + 0.5)
      teile[#teile + 1] = rest >= 1 and (WEISS .. "noch ca. " .. rest .. " Std. günstig" .. ENDE) or (ORANGE .. "Tief endet bald – jetzt" .. ENDE)
    elseif t >= 10 then teile[#teile + 1] = ORANGE .. "Preis steigt – bald kaufen" .. ENDE
    elseif t <= -10 then teile[#teile + 1] = WEISS .. "Preis fällt noch" .. ENDE
    elseif z.ph == "tief" and (z.h or 0) >= 1 then teile[#teile + 1] = WEISS .. "seit " .. z.h .. " Std. günstig" .. ENDE end
    if z.bk then teile[#teile + 1] = GRAU .. "beste Zeit ~" .. uhr(z.bk) .. ENDE
    else local tf = GF.tagesfenster(); if tf and not tf.jetztKauf then teile[#teile + 1] = GRAU .. "günstiger meist " .. tf.kVon .. "–" .. tf.kBis .. " Uhr" .. ENDE end end
  end
  if #teile == 0 then return nil end
  return table.concat(teile, GRAU .. "  ·  " .. ENDE)
end

-- ---------------------------------------------------------------- Raid-Einkaufsplan
-- Raid-Items, die gerade unter Ø liegen: Menge nach Budget-Anteil und Markttiefe,
-- erwarteter Gewinn bis zum Raid = (Ø × 0,95 − Preis) × Menge.
function GF.raidPlan()
  local gold = GetMoney and GetMoney() or 0
  local budget = math.floor(gold * (D().budget or 0.7) * 0.5)
  local kand, grund = {}, {}
  for id, rk in pairs(D().raid or {}) do
    id = tonumber(id)
    local i = not GF.ausgeblendet(id) and GF.info(id); local e = i and GF.empfehlung(id, i, true)
    local R = e and e.art == "kauf" and i.p and GF.referenz(id, i)
    if R and i.p < R then
      local netto = math.floor(R * 0.95)
      local stueck = netto - i.p
      if stueck >= math.max(1, i.p * 0.1) then
        local markt = math.max(1, math.floor((i.u or 0) * 0.05))
        if rk[1] == "neu" then markt = math.min(markt, 3) end
        kand[#kand + 1] = { id = id, i = i, rk = rk, ziel = R, stueck = stueck, markt = markt, maxKauf = math.floor(netto / 1.1) }
      else grund[id] = "Gewinn je Stück zu klein (" .. GF.geld(math.max(0, stueck)) .. ")" end
    elseif R then grund[id] = "Preis nicht unter üblich (" .. GF.geld(R) .. ")"
    end
  end
  local function wert(k) return k.stueck * math.min(k.markt, math.floor(budget * 0.3 / k.i.p)) end
  table.sort(kand, function(a, b) return wert(a) > wert(b) end)
  local rest, plan = budget, {}
  for _, k in ipairs(kand) do
    local menge = math.min(k.markt, math.floor(budget * 0.3 / k.i.p), math.floor(rest / k.i.p))
    if #plan >= 5 then grund[k.id] = "Raid-Vorrat ist voll – andere Käufe bringen mehr"
    elseif menge < 1 then grund[k.id] = "Raid-Budget reicht nicht"
    else
      k.menge = menge; k.gewinn = menge * k.stueck; plan[#plan + 1] = k
      rest = rest - menge * k.i.p
    end
  end
  return { budget = budget, plan = plan, grund = grund }
end

-- ---------------------------------------------------------------- Eine Entscheidung fuer Tooltip, Loot-Hinweis, Taschen und Fenster (2.50)
-- "Kaufen" gilt nur, wenn das Item auch im Einkaufsplan (bzw. Raid-Vorrat) steht – sonst "Behalten" mit Grund.
local planCache, raidCache = { t = 0 }, { t = 0 }
function GF.planNeu() planCache.p = nil; raidCache.p = nil end
function GF.planFuer()
  if GF.ah and GF.ah.plan then return GF.ah.plan end
  if not planCache.p or time() - planCache.t > 20 then planCache.p = GF.budgetPlan(); planCache.t = time() end
  return planCache.p
end
local function raidPlanFuer()
  if not raidCache.p or time() - raidCache.t > 20 then local ok, rp = pcall(GF.raidPlan); raidCache.p = ok and rp or { plan = {} }; raidCache.t = time() end
  return raidCache.p
end
-- nil + Deal, wenn im Plan; sonst der Grund, warum nicht
function GF.kaufStatus(id)
  id = tonumber(id)
  if GF.ausgeblendet(id) then return "ausgeblendet" end
  if GF.raid(id) then
    local rp = raidPlanFuer()
    for _, k in ipairs(rp.plan or {}) do if k.id == id then return nil, k end end
    return (rp.grund and rp.grund[id]) or "nicht im Raid-Vorrat"
  end
  local P = GF.planFuer()
  for _, d in ipairs(P.deals or {}) do if d.id == id then return nil, d end end
  return (P.grund and P.grund[id]) or "nicht im Einkaufsplan"
end
function GF.entscheidung(id, i, eigen)
  i = i or GF.info(id); if not i then return nil end
  local e = GF.empfehlung(id, i, nil, eigen)
  if e and e.art == "kauf" and not e.position then
    local grund, deal = GF.kaufStatus(id)
    if grund then
      local n = E("halt", e.grund .. ", aber " .. grund)
      n.keinKauf, n.kaufGrund = grund, e.grund
      return n
    end
    e.deal = deal
  end
  return e
end
-- Wert pro Stueck, wie Tooltip und Loot-Hinweis ihn zeigen
function GF.stueckWert(e, i)
  if not (e and i) then return nil end
  if e.art == "haendler" then return i.vk end
  if e.art == "herstellen" and e.nutzung then return math.floor(e.nutzung.pro) end
  if e.art == "verk" then local pr = GF.einstellen(i); if pr then return math.floor(pr * 0.95) end end
  return GF.wert(i)
end

-- Erwarteter Gewinn einer Position (2.50, Befund 20): realistischer Verkaufspreis statt des eigenen Angebotspreises.
-- Liegt der eigene Preis (oder das Ziel) ueber min(ueblich, TSM-Marktwert), zaehlt dieser Wert; der eigene Preis ist nur der Bestfall.
function GF.realPreis(p, pl)
  if p.verkauftPreis then return p.verkauftPreis end -- schon verkauft: echter Preis (Befund 28)
  if pl and pl.preis then return pl.preis end
  local basis = p.ahPreis or p.ziel
  if not basis then return nil end
  local i = p.i or GF.info(p.id)
  local R = i and GF.referenz(p.id, i)
  local cap = R
  if i and i.mw and i.mw > 0 then cap = cap and math.min(cap, i.mw) or i.mw end
  if cap and basis > cap then return math.max(cap, 1), basis end
  return basis
end
function GF.erwartGewinn(p, pl)
  local real, best = GF.realPreis(p, pl)
  if not real then return 0 end
  local g = math.floor((real * 0.95 - p.ek) * p.n)
  return g, best and math.floor((best * 0.95 - p.ek) * p.n) or nil
end

-- ---------------------------------------------------------------- Tooltip
local GELB = "|cfffacc15"
local HAKEN = "|TInterface\\RaidFrame\\ReadyCheck-Ready:12:12|t"
GF.HAKEN = HAKEN
-- duenne Trennlinie (Textur, weil WoW-Fonts keine Linienzeichen haben)
local TRENNER = "|TInterface\\Buttons\\WHITE8X8:1:210:0:0:8:8:0:8:0:8:120:110:60|t"
-- Berufe: Name (wie in der Datendatei) -> Icon
local I = "Interface\\Icons\\"
local BERUF_ICON = {
  ["Alchimie"] = I .. "Trade_Alchemy", ["Schmiedekunst"] = I .. "Trade_BlackSmithing", ["Verzauberkunst"] = I .. "Trade_Engraving", ["Ingenieurskunst"] = I .. "Trade_Engineering",
  ["Lederverarbeitung"] = I .. "INV_Misc_ArmorKit_17", ["Schneiderei"] = I .. "Trade_Tailoring", ["Bergbau"] = I .. "Trade_Mining", ["Kochkunst"] = I .. "INV_Misc_Food_15",
  ["Erste Hilfe"] = I .. "Spell_Holy_SealOfSacrifice", ["Gifte"] = I .. "Trade_BrewPoison",
  alchemy = I .. "Trade_Alchemy", blacksmithing = I .. "Trade_BlackSmithing", enchanting = I .. "Trade_Engraving", engineering = I .. "Trade_Engineering", leatherworking = I .. "INV_Misc_ArmorKit_17",
  tailoring = I .. "Trade_Tailoring", mining = I .. "Trade_Mining", cooking = I .. "INV_Misc_Food_15", firstaid = I .. "Spell_Holy_SealOfSacrifice",
}
local function berufIcon(beruf)
  return "|T" .. (BERUF_ICON[beruf or ""] or 134400) .. ":14:14:0:0:64:64:5:59:5:59|t"
end
-- eigener Skill im Beruf (nil, wenn nicht gelernt oder nicht abfragbar)
local function eigenerSkill(beruf)
  if not (GetProfessions and GetProfessionInfo and beruf) then return nil end
  local ok, a, b, c, d, e2, f2 = pcall(GetProfessions)
  if not ok then return nil end
  for _, idx in ipairs({ a, b, c, d, e2, f2 }) do
    local ok2, name, _, rank = pcall(GetProfessionInfo, idx)
    if ok2 and name == beruf then return rank end
  end
  return nil
end
-- rechte Spalte: "Alchimie 55" grau, rot wenn eigener Skill zu niedrig/nicht gelernt
local function berufRechts(beruf, skill)
  if not beruf or beruf == "" then return "" end
  local txt = beruf .. ((skill and skill > 0) and (" " .. skill) or "")
  local eigen = eigenerSkill(beruf)
  if eigen == nil then return GRAU .. txt .. ENDE end
  if skill and eigen < skill then return "|cfff87171" .. txt .. " (du " .. eigen .. ")" .. ENDE end
  return GRAU .. txt .. ENDE
end
-- Tooltip, immer gleich aufgebaut:
--   Gold Forever                     (TSM live)
--   Preis 8s 98c · Ø 6s 71c          239/Tag
--   AH verkaufen · 34 % über Ø       8× = 1g 2s     <- Farbe der Kategorie
--   Einstellen 8s 97c · 12 Std. · geht schnell     <- grau, nur beim Verkaufen
--   Herstellen · ...                               <- gelb, nur wenn es sich lohnt
local function tooltipZeilen(tt, id)
  if GoldForeverDB.tooltip == false then return end
  if GF.ausgeblendet(id) then
    tt:AddLine(" "); tt:AddLine(GOLD .. "Gold Forever" .. ENDE .. GRAU .. "  ·  ausgeblendet (nutzt du selbst)" .. ENDE); return
  end
  local i = GF.info(id); if not i then return end
  local e = GF.entscheidung(id, i)
  local n = GF.anzahl(id)
  -- Kompakt: hoechstens 3 Zeilen, lange Texte umbrechen statt den Tooltip breit zu ziehen
  tt:AddLine(" ")
  local R, quelle = GF.referenz(id, i)
  local kopf = GOLD .. "Gold Forever" .. ENDE
  if i.p or i.r then
    kopf = kopf .. GRAU .. "   " .. ENDE .. WEISS .. GF.geld(i.p) .. ENDE .. GRAU .. (quelle == "realm" and "  ·  üblich " or "  ·  üblich (Region) ") .. ENDE .. WEISS .. GF.geld(R or i.r) .. ENDE
  end
  tt:AddDoubleLine(kopf, (i.ahLive and (GRUEN .. "AH live" .. ENDE) or "") .. (i.u and (GRAU .. (i.ahLive and " · " or "") .. math.floor(i.u + 0.5) .. "/Tag" .. ENDE) or ""))
  -- 2.54 Lernsystem: eigene Erfahrung mit diesem Item
  local erf = GF.erfahrung(id)
  if erf then
    local farbe = erf.bewaehrt and GRUEN or (erf.vorsicht and "|cfffb923c" or GRAU)
    tt:AddLine(farbe .. (erf.bewaehrt and "Bewährt: " or (erf.vorsicht and "Vorsicht: " or "Erfahrung: ")) .. GF.erfahrungText(erf) .. ENDE)
  end
  if not e then return end
  if e.position then
    local p, pl = e.position, e.plan
    local gewinn, best = GF.erwartGewinn(p, pl)
    tt:AddDoubleLine(GF.katIcon(e.art) .. " " .. e.farbe .. HAKEN .. ((e.position and e.position.hergestellt) and " Hergestellt: " or " Dein Einkauf: ") .. pl.kurz .. ENDE,
      (gewinn >= 0 and GRUEN .. "+" or "|cfff87171-") .. GF.geld(math.abs(gewinn)) .. ENDE)
    local info = p.n .. "× gekauft je " .. GF.geld(p.ek) .. (p.post > 0 and (" · " .. p.post .. " in der Post") or "")
      .. ((best and best ~= gewinn) and (" · Bestfall " .. (best >= 0 and "+" or "-") .. GF.geld(math.abs(best))) or "")
    tt:AddLine(GRAU .. info .. ENDE)
    if pl.lang and not pl.lang:find("^halten, bis") and not pl.imAH then tt:AddLine(e.farbe .. pl.lang .. ENDE, 1, 1, 1, true) end
  else
    local wert = GF.stueckWert(e, i)
    if e.reset then
      tt:AddDoubleLine(PFEIL .. " " .. ORANGE .. "Preissprung  " .. GF.faktor(e.faktor) .. ENDE .. GRAU .. "   vorher " .. ENDE .. WEISS .. GF.geld(e.vorher) .. ENDE,
        (n > 0 and wert) and (GRUEN .. "deine " .. n .. ": " .. GF.geld(wert * n) .. ENDE) or "")
      tt:AddLine((n > 0 and (GRUEN .. "Jetzt verkaufen – fällt meist bald zurück") or (GRAU .. "Nicht kaufen")) .. ENDE)
      return
    end
    tt:AddDoubleLine(GF.katIcon(e.art) .. " " .. e.farbe .. e.titel .. "  ·  " .. e.grund .. ENDE,
      (n > 0 and wert) and (e.farbe .. "deine " .. n .. ": " .. GF.geld(wert * n) .. ENDE) or "")
    local teile = {}
    if e.deal then teile[#teile + 1] = KAT.kauf.farbe .. "Plan: " .. e.deal.menge .. "× bis " .. GF.geld(e.deal.maxKauf) .. ENDE end
    if e.art == "verk" and n > 0 then
      local preis, dauer = GF.einstellen(i)
      if preis then teile[#teile + 1] = "Einstellen " .. GF.geld(preis) .. " · " .. dauer end
    end
    if e.art == "verk" or e.art == "kauf" then
      local zt = GF.zeitText(id, e.art); if zt then teile[#teile + 1] = zt end
    end
    if #teile > 0 then tt:AddLine(GRAU .. table.concat(teile, "  ·  ") .. ENDE, 1, 1, 1, true) end
  end
  local rk = GF.raid(id)
  if rk and rk[4] and rk[4] ~= "" then tt:AddLine((e and e.farbe or GRAU) .. TYP[rk[1]] .. "  ·  " .. rk[4] .. ENDE) end
  -- Berufe-Block (gelb), abgesetzt durch Trennlinie + Berufs-Icon
  local b, w, bk, plusK = GF.verarbeitenLohnt(id, i)
  local h = GF.herstellung(id)
  if b or bk or h then
    tt:AddLine(TRENNER)
    if b then
      tt:AddDoubleLine(berufIcon(b.beruf) .. " " .. GELB .. "Verarbeiten  ·  zu " .. b.name .. ENDE, berufRechts(b.beruf, b.skill))
      tt:AddLine(GELB .. "      " .. GF.geld(b.pro) .. " statt " .. GF.geld(w) .. " pro Stück" .. ENDE .. GRAU .. "  (+" .. GF.geld(b.pro - w) .. ")" .. ENDE)
    elseif bk then
      tt:AddDoubleLine(berufIcon(bk.beruf) .. " " .. GRAU .. "Verarbeiten zu " .. bk.name .. " lohnt kaum (+" .. GF.geld(plusK) .. ")" .. ENDE, berufRechts(bk.beruf, bk.skill))
    end
    if h then
      local g = h.erloes - h.kosten
      if g > 0 then
        tt:AddDoubleLine(berufIcon(h.beruf) .. " " .. GELB .. "Herstellen  ·  Gewinn +" .. GF.geld(g) .. " pro Stück" .. ENDE, berufRechts(h.beruf, h.skill))
        tt:AddLine(GRAU .. "      Zutaten " .. GF.geld(h.kosten) .. "  ·  Verkauf " .. GF.geld(h.erloes) .. ENDE)
      else
        tt:AddDoubleLine(berufIcon(h.beruf) .. " " .. GRAU .. "Selbst herstellen lohnt nicht" .. ENDE, GRAU .. "Zutaten " .. GF.geld(h.kosten) .. ENDE)
      end
    end
  end
end


local function hookTooltips()
  if TooltipDataProcessor and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt, data)
      if tt ~= GameTooltip and tt ~= ItemRefTooltip then return end
      local id = data and data.id
      if not id and tt.GetItem then local _, link = tt:GetItem(); id = link and tonumber(string.match(link, "item:(%d+)")) end
      if id then pcall(tooltipZeilen, tt, id) end
    end)
  else
    GameTooltip:HookScript("OnTooltipSetItem", function(tt)
      local _, link = tt:GetItem(); local id = link and tonumber(string.match(link, "item:(%d+)"))
      if id then pcall(tooltipZeilen, tt, id) end
    end)
  end
end

-- ---------------------------------------------------------------- Loot-Hinweise im Chat
local zuletzt = {}
local function lootHinweis(msg, guid)
  if GoldForeverDB.loot == false then return end
  if guid and UnitGUID and guid ~= UnitGUID("player") then return end
  local link = string.match(msg or "", "(|c.-|Hitem:.-|h.-|h|r)") or string.match(msg or "", "(|Hitem:.-|h.-|h)")
  local id = link and tonumber(string.match(link, "item:(%d+)")); if not id then return end
  if zuletzt[id] and time() - zuletzt[id] < 600 then return end
  local i = GF.info(id); if not i then return end
  -- gleiche Entscheidung und gleicher Wert wie Tooltip und Fenster (2.50: GF.entscheidung, Ware zaehlt als eigene)
  local e = GF.entscheidung(id, i, true); if not e then return end
  local w = GF.stueckWert(e, i); local rk = GF.raid(id)
  if not rk and (not w or w < 100) then return end
  zuletzt[id] = time()
  print(GOLD .. "Gold Forever:" .. ENDE .. " " .. link .. " " .. GRAU .. "ca. " .. ENDE .. GF.geld(w) .. GRAU .. " pro Stück  ·  " .. ENDE ..
    GF.katIcon(e.art) .. " " .. e.farbe .. e.text .. ENDE)
end

-- ---------------------------------------------------------------- Tagesbilanz
local function charKey() return (UnitName and UnitName("player")) or "?" end
GF.charKey = charKey
-- Eigene Auktionen je Charakter (Twinks haben eigene Auktionen)
function GF.ahDaten()
  GoldForeverDB.imAHc = GoldForeverDB.imAHc or {}
  local k = charKey()
  if not GoldForeverDB.imAHc[k] then GoldForeverDB.imAHc[k] = { t = 0, items = {} } end
  return GoldForeverDB.imAHc[k]
end
local function tagPruefen()
  GoldForeverDB.tag = GoldForeverDB.tag or {}
  local heute = date("%Y-%m-%d"); local t = GoldForeverDB.tag[charKey()]
  if not t or t.d ~= heute then GoldForeverDB.tag[charKey()] = { d = heute, start = GetMoney() } end
end
-- Einnahmen/Ausgaben/Profit aus dem Bilanz-Buch (2.52, Kopf des Fensters): heute bzw. seit Sekunden
function GF.handelHeute(seit)
  local t = date("*t")
  local ab = seit and (time() - seit) or (time() - (t.hour * 3600 + t.min * 60 + t.sec))
  local ein, aus, ich = 0, 0, charKey()
  for _, x in ipairs((GoldForeverDB.bilanz and GoldForeverDB.bilanz.buch) or {}) do
    if x.t >= ab and (x.char == nil or x.char == ich) then
      if x.art == "verk" then ein = ein + (x.betrag or 0) elseif x.art == "kauf" then aus = aus - (x.betrag or 0) end
    end
  end
  return ein, aus, ein - aus
end
-- Alle Käufe/Verkäufe (wie TSM) in einem Zeitraum (2.53): {ein, aus, profit, liste = {{x, wert}}, topV, topK, tage}
function GF.handelZeitraum(sekunden)
  local ab = sekunden and (time() - sekunden) or 0
  local ich = charKey()
  local r = { ein = 0, aus = 0, liste = {}, tage = {}, nV = 0, nK = 0 }
  local proItemV, proItemK = {}, {}
  for _, x in ipairs((GoldForeverDB.bilanz and GoldForeverDB.bilanz.buch) or {}) do
    if x.t >= ab and (x.char == nil or x.char == ich) and (x.art == "verk" or x.art == "kauf") then
      local w = x.betrag or 0
      r.liste[#r.liste + 1] = { x = x, wert = w }
      local tag = date("%Y-%m-%d", x.t)
      local T = r.tage[tag] or { ein = 0, aus = 0, nV = 0, nK = 0, t = x.t }; r.tage[tag] = T
      if x.art == "verk" then
        r.ein = r.ein + w; r.nV = r.nV + 1; T.ein = T.ein + w; T.nV = T.nV + 1
        proItemV[x.id] = (proItemV[x.id] or 0) + w
      else
        r.aus = r.aus - w; r.nK = r.nK + 1; T.aus = T.aus - w; T.nK = T.nK + 1
        proItemK[x.id] = (proItemK[x.id] or 0) - w
      end
    end
  end
  r.profit = r.ein - r.aus
  for id, w in pairs(proItemV) do if not r.topV or w > r.topV.w then r.topV = { id = id, w = w } end end
  for id, w in pairs(proItemK) do if not r.topK or w > r.topK.w then r.topK = { id = id, w = w } end end
  return r
end
-- 2.55 (Befund 46): Top-Verkaeufe & Verluste je Item im Zeitraum. Einkaufspreis = Ø aller eigenen Kaeufe
-- (auch aelter als der Zeitraum, sonst fehlt er), Herstellen zaehlt wie Kauf. Ohne Kauf = eigene Ware (Gewinn = Erloes).
function GF.topFlops(sekunden)
  local ab = sekunden and (time() - sekunden) or 0
  local ich = charKey()
  local it = {}
  for _, x in ipairs((GoldForeverDB.bilanz and GoldForeverDB.bilanz.buch) or {}) do
    if (x.char == nil or x.char == ich) and (x.n or 0) > 0 and x.id then
      local e = it[x.id] or { id = x.id, kN = 0, kG = 0, vN = 0, vG = 0, gf = false }
      if x.art == "kauf" or x.art == "herg" then
        e.kN = e.kN + x.n; e.kG = e.kG - (x.betrag or 0); e.kT = e.kT or x.t
        if x.t >= ab then e.kNz = (e.kNz or 0) + x.n end
      elseif x.art == "verk" and x.t >= ab then
        e.vN = e.vN + x.n; e.vG = e.vG + (x.betrag or 0); e.vT = x.t
      end
      if x.v then e.gf = true end
      it[x.id] = e
    end
  end
  local liste = {}
  for id, e in pairs(it) do
    if e.vN > 0 then
      if e.kN > 0 then
        e.ek = e.kG / e.kN
        e.kosten = math.floor(e.ek * e.vN)
        e.profit = e.vG - e.kosten
        e.pct = e.kosten > 0 and (e.profit / e.kosten) or nil
      else
        e.eigen = true; e.profit = e.vG
      end
      local erf = GF.erfahrung and GF.erfahrung(id)
      e.std = erf and erf.avgStd or ((e.kT and e.vT and e.vT > e.kT) and (e.vT - e.kT) / 3600 or nil)
      liste[#liste + 1] = e
    end
  end
  table.sort(liste, function(a, b) return a.profit > b.profit end)
  return liste
end
function GF.tagesbilanz()
  local t = GoldForeverDB.tag and GoldForeverDB.tag[charKey()]
  if not t then return nil end
  return GetMoney() - t.start
end

-- ---------------------------------------------------------------- Farbmarken in den Taschen (EllesmereUI-Bags)
-- Gruen = im AH verkaufen, Blau = Raid-Ware behalten, Gelb = verarbeiten lohnt. Sonst keine Marke.
-- Gut sichtbar auch auf hellen Icons: farbiger Rahmen ums ganze Feld + Ecke oben rechts mit dunklem Rand.
local WEISS8 = "Interface\\Buttons\\WHITE8X8"
-- Marke = genau die Empfehlung aus dem Tooltip (gleiche Funktion, gleiche Farbe).
-- Keine Marke, wenn es nichts zu entscheiden gibt: gebundene Items, Haendlerware,
-- kaum gehandelte Items, "verkauft sich langsam".
-- Rahmen nur bei Handlungs-Farben (verkaufen, verarbeiten), sonst nur die Ecke.
local function punktFuer(id, gebunden)
  if GF.ausgeblendet(id) then return nil end
  local i = GF.info(id); if not i then return nil end
  local e = GF.entscheidung(id, i); if not e then return nil end
  if gebunden and not (e.art == "haendler" and i.q == 0) then return nil end
  if e.still or e.langsam then return nil end
  if e.reset and e.art == "verk" then return { 0.98, 0.57, 0.24 }, true end
  return KAT[e.art].rgb, (e.art == "verk" or e.art == "herstellen")
end
local function tex(btn, sub)
  local t = btn:CreateTexture(nil, "OVERLAY", nil, sub); t:SetTexture(WEISS8); return t
end
local function markeBauen(btn)
  local m = {}
  local s = math.max(10, math.floor((btn:GetWidth() or 36) * 0.32 + 0.5))
  -- Rahmen: dunkle Linie innen, farbige Linie aussen (2 px)
  m.rahmen, m.rahmenTeile, m.ecke = {}, {}, {}
  for _, seite in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
    local schatten, farbe = tex(btn, 5), tex(btn, 6)
    schatten:SetVertexColor(0, 0, 0, 0.8)
    if seite == "TOP" or seite == "BOTTOM" then
      local y = seite == "TOP" and 1 or -1
      farbe:SetPoint(seite .. "LEFT", 0, 0); farbe:SetPoint(seite .. "RIGHT", 0, 0); farbe:SetHeight(2)
      schatten:SetPoint(seite .. "LEFT", 2, -2 * y); schatten:SetPoint(seite .. "RIGHT", -2, -2 * y); schatten:SetHeight(1)
    else
      local x = seite == "LEFT" and 1 or -1
      farbe:SetPoint("TOP" .. seite, 0, 0); farbe:SetPoint("BOTTOM" .. seite, 0, 0); farbe:SetWidth(2)
      schatten:SetPoint("TOP" .. seite, 2 * x, -2); schatten:SetPoint("BOTTOM" .. seite, 2 * x, 2); schatten:SetWidth(1)
    end
    m.rahmen[#m.rahmen + 1] = farbe; m.rahmenTeile[#m.rahmenTeile + 1] = farbe; m.rahmenTeile[#m.rahmenTeile + 1] = schatten
  end
  -- Ecke oben rechts: schwarzer Rand, farbige Flaeche, heller Glanz oben
  m.rand = tex(btn, 6); m.rand:SetVertexColor(0, 0, 0, 1); m.rand:SetSize(s + 2, s + 2); m.rand:SetPoint("TOPRIGHT", 0, 0)
  m.punkt = tex(btn, 7); m.punkt:SetSize(s, s); m.punkt:SetPoint("CENTER", m.rand, "CENTER", 0, 0)
  m.glanz = tex(btn, 7); m.glanz:SetVertexColor(1, 1, 1, 0.35); m.glanz:SetSize(s, math.floor(s / 3)); m.glanz:SetPoint("TOP", m.punkt, "TOP", 0, 0)
  m.ecke = { m.rand, m.punkt, m.glanz }
  btn.gfMarke = m
  return m
end
local function punktSetzen(btn)
  if not btn or not btn.GetID then return end
  local bag = btn.GetBagID and btn:GetBagID() or (btn:GetParent() and btn:GetParent():GetID())
  local slot = btn:GetID()
  local info = bag and slot and C_Container and C_Container.GetContainerItemInfo(bag, slot)
  local farbe, rahmen
  if GoldForeverDB.punkte ~= false and info and info.itemID then farbe, rahmen = punktFuer(info.itemID, info.isBound) end
  if btn.gfPunkt then btn.gfPunkt:Hide() end -- alter 7-px-Punkt aus v1.1
  if farbe then
    local m = btn.gfMarke or markeBauen(btn)
    m.punkt:SetVertexColor(farbe[1], farbe[2], farbe[3], 1)
    for _, r in ipairs(m.rahmen) do r:SetVertexColor(farbe[1], farbe[2], farbe[3], 0.9) end
    for _, t in ipairs(m.ecke) do t:Show() end
    for _, t in ipairs(m.rahmenTeile) do if rahmen then t:Show() else t:Hide() end end
  elseif btn.gfMarke then
    for _, t in ipairs(btn.gfMarke.ecke) do t:Hide() end
    for _, t in ipairs(btn.gfMarke.rahmenTeile) do t:Hide() end
  end
end
local function alleKnoepfe(frame, tiefe)
  if not frame or tiefe > 7 then return end
  for _, c in ipairs({ frame:GetChildren() }) do
    if c.GetObjectType and (c:GetObjectType() == "ItemButton" or c.GetBagID) and c:IsShown() then pcall(punktSetzen, c) end
    alleKnoepfe(c, tiefe + 1)
  end
end
-- Bank-Fenster finden (EllesmereUI benennt sie EUI_...Bank...; Blizzard-Bank als Rueckfall), einmalig beim ersten Bankbesuch
local bankFenster
local function bankFensterSuchen()
  if bankFenster and bankFenster.eui then return bankFenster end
  bankFenster = {}
  for name, f in pairs(_G) do
    local n = type(name) == "string" and string.lower(name)
    if n and type(f) == "table" and (string.match(n, "^eui") or string.find(n, "ellesmere")) and string.find(n, "bank")
      and f.IsVisible and f.GetChildren then
      bankFenster[#bankFenster + 1] = f; bankFenster.eui = true
    end
  end
  if BankFrame then bankFenster[#bankFenster + 1] = BankFrame end
  -- Aktualisierungs-Funktionen der Bankfenster mitnutzen (nur einmal je Fenster)
  for _, f in ipairs(bankFenster) do
    if not f.gfGehakt then f.gfGehakt = true
    for _, m in ipairs({ "RefreshInventory", "RefreshBank", "Refresh", "Update" }) do
      if type(f[m]) == "function" then pcall(hooksecurefunc, f, m, function() pcall(GF.punkteAktualisieren) end) end
    end
    end
  end
  return bankFenster
end
GF.bankOffen = false
function GF.punkteAktualisieren()
  if EUI_Bags and EUI_Bags.IsVisible and EUI_Bags:IsVisible() then alleKnoepfe(EUI_Bags, 0) end
  if EUI_BagsReagent and EUI_BagsReagent.IsVisible and EUI_BagsReagent:IsVisible() then alleKnoepfe(EUI_BagsReagent, 0) end
  if GF.bankOffen then
    for _, f in ipairs(bankFensterSuchen()) do
      if f:IsVisible() and f ~= EUI_Bags and f ~= EUI_BagsReagent then alleKnoepfe(f, 0) end
    end
  end
end
local function taschenHaken()
  if EUI_Bags and EUI_Bags.RefreshInventory and not GF.taschenGehakt then
    hooksecurefunc(EUI_Bags, "RefreshInventory", function() pcall(GF.punkteAktualisieren) end)
    if EUI_BagsReagent and EUI_BagsReagent.RefreshInventory then hooksecurefunc(EUI_BagsReagent, "RefreshInventory", function() pcall(GF.punkteAktualisieren) end) end
    GF.taschenGehakt = true
  end
end

-- ---------------------------------------------------------------- Auktionshaus: Einkaufsliste
GF.ah = nil -- {plan, start = {id = Anzahl beim Oeffnen}}
local function ahAuf()
  local plan = GF.budgetPlan(); local start = {}
  for _, d in ipairs(plan.deals) do start[d.id] = GF.anzahl(d.id) end
  GF.ah = { plan = plan, start = start, t0 = time() }
  if GoldForever_AH then GoldForever_AH(true) end
end
local function ahZu()
  GF.ah = nil; GF.kaufLauf = nil
  if GoldForever_AH then GoldForever_AH(false) end
end
-- Seit dem Oeffnen des AH gekauft: aus den gebuchten Kaeufen (Commodities landen im Briefkasten,
-- nicht in der Tasche), mindestens aber der Zuwachs in Taschen/Bank
function GF.gekauft(id)
  if not GF.ah then return 0 end
  id = tonumber(id)
  local n = 0
  local ich = UnitName and UnitName("player") or "?"
  for _, x in ipairs(((GoldForeverDB.bilanz or {}).buch) or {}) do
    if x.art == "kauf" and x.id == id and x.t >= (GF.ah.t0 or 0) and (x.char == nil or x.char == ich) then n = n + (x.n or 0) end
  end
  local tasche = GF.ah.start[id] and math.max(0, GF.anzahl(id) - GF.ah.start[id]) or 0
  return math.max(n, tasche)
end

-- ---------------------------------------------------------------- Bilanz: Geschaefte mitschreiben
-- GoldForeverDB.bilanz = {
--   buch    = { {t, art = "kauf"|"verk", id, n, betrag (Kupfer, + Einnahme / - Ausgabe), v = nach Vorschlag?, hd = Haendlerwert} },
--   inserat = { [Name] = {id, v = Stueck nach Vorschlag, o = Stueck ohne} },
--   post    = { [Schluessel] = Zeit }   -- schon gezaehlte Verkaufs-Mails
--   start   = Zeitpunkt, ab dem mitgeschrieben wird }
local function B()
  GoldForeverDB.bilanz = GoldForeverDB.bilanz or {}
  local b = GoldForeverDB.bilanz
  b.buch = b.buch or {}; b.inserat = b.inserat or {}; b.post = b.post or {}; b.start = b.start or time()
  return b
end
GF.bilanzDaten = B

local function buchen(art, id, n, betrag, v, ziel, basis)
  local i = GF.info(id)
  local hd = (i and i.vk or 0) * n
  table.insert(B().buch, { t = time(), art = art, id = id, n = n, betrag = betrag, v = v and true or false, hd = hd, ziel = ziel, basis = basis, char = charKey() })
  if GF.aktualisieren then pcall(GF.aktualisieren) end
end

-- War ein Kauf von Gold Forever vorgeschlagen? (Budget-Plan, Raid-Plan oder Empfehlung "Kaufen")
-- Liefert: vorgeschlagen?, Zielpreis pro Stueck (zu dem spaeter verkauft werden soll)
local function zielPreis(i) return i and i.id and GF.referenz(i.id, i) or nil end
local function kaufVorschlag(id)
  local um = GF.unterbieterMerk and GF.unterbieterMerk[id]
  if um and time() - um.t < 900 then return true, um.neu end
  if GF.ah and GF.ah.plan then for _, d in ipairs(GF.ah.plan.deals) do if d.id == id then return true, d.ziel end end end
  local ok, rp = pcall(GF.raidPlan)
  if ok and rp then for _, k in ipairs(rp.plan) do if k.id == id then return true, k.ziel end end end
  local i = GF.info(id); local e = GF.empfehlung(id, i, true)
  return e ~= nil and e.art == "kauf", zielPreis(i)
end

-- Kaeufe: Commodities (Kraeuter, Erze, Traenke ...) und Einzel-Auktionen
local offen -- {id, n, geld}
local function kaufAbschliessen()
  if not offen then return end
  local k = offen; offen = nil
  local ausgabe = k.geld - GetMoney()
  if ausgabe > 0 then local v, ziel = kaufVorschlag(k.id); buchen("kauf", k.id, k.n, -ausgabe, v, ziel) end
end
local function kaufHaken()
  if not C_AuctionHouse or GF.kaufGehakt then return end
  GF.kaufGehakt = true
  if C_AuctionHouse.ConfirmCommoditiesPurchase then
    hooksecurefunc(C_AuctionHouse, "ConfirmCommoditiesPurchase", function(itemID, menge)
      offen = { id = itemID, n = menge or 1, geld = GetMoney() }
    end)
  end
  if C_AuctionHouse.PlaceBid then
    hooksecurefunc(C_AuctionHouse, "PlaceBid", function(auctionID)
      local ok, info = pcall(C_AuctionHouse.GetAuctionInfoByID, auctionID)
      local id = ok and info and info.itemKey and info.itemKey.itemID
      if id then offen = { id = id, n = (info.quantity or 1), geld = GetMoney() } end
    end)
  end
  -- Einstellen: merken, ob das Item gerade zum Verkaufen vorgeschlagen war
  local function eingestellt(itemLoc, menge, preis)
    local ok, id = pcall(C_Item.GetItemID, itemLoc); if not ok or not id then return end
    local e = GF.empfehlung(id)
    local name = (C_Item.GetItemInfo and C_Item.GetItemInfo(id)) or (GF.info(id) or {}).n
    if not name then return end
    local r = B().inserat[name] or { id = id, v = 0, o = 0 }
    if e and e.art == "verk" then r.v = r.v + (menge or 1) else r.o = r.o + (menge or 1) end
    r.id = id; B().inserat[name] = r
    -- Vergleichspreis fuer eigene Ware: Preis, als Gold Forever zum Warten geraten hat (max. 36 Std. alt),
    -- sonst der uebliche Preis. Bilanz zaehlt bei eigener Ware nur den Mehrerloes darueber.
    if e and e.art == "verk" then
      local w = GoldForeverDB.warte and GoldForeverDB.warte[id]
      if w and time() - w.t <= 36 * 3600 then r.basis = w.p else r.basis = GF.referenz(id) end
      if GoldForeverDB.warte then GoldForeverDB.warte[id] = nil end
    end
    local log = B().einstellLog or {}; B().einstellLog = log
    log[#log + 1] = { t = time(), id = id, n = menge or 1, v = (e and e.art == "verk") and true or false, char = charKey() }
    -- Preis-Protokoll: Vorschlag von Gold Forever vs. tatsaechlich eingestellter Preis (TSM), Verkauf kommt per Post dazu
    pcall(GF.preisLogNeu, id, name, menge or 1, preis, e)
    while #log > 500 do table.remove(log, 1) end
    B().eingestellt = (B().eingestellt or 0) + ((e and e.art == "verk") and 1 or 0)
  end
  if C_AuctionHouse.PostCommodity then
    hooksecurefunc(C_AuctionHouse, "PostCommodity", function(loc, _, menge, preis)
      pcall(eingestellt, loc, menge, preis)
      pcall(function()
        local id = C_Item.GetItemID(loc); if not id then return end
        local AH = GF.ahDaten()
        local x = AH.items[id] or { n = 0 }
        x.n = x.n + (menge or 1); if preis and (not x.preis or preis < x.preis) then x.preis = preis end
        AH.items[id] = x
      end)
    end)
  end
  if C_AuctionHouse.PostItem then
    hooksecurefunc(C_AuctionHouse, "PostItem", function(loc, _, menge, gebot, sofort)
      pcall(eingestellt, loc, menge, sofort or gebot)
      pcall(function()
        local id = C_Item.GetItemID(loc); if not id then return end
        local AH = GF.ahDaten()
        local x = AH.items[id] or { n = 0 }
        local preis = sofort or gebot
        x.n = x.n + (menge or 1); if preis and (not x.preis or preis < x.preis) then x.preis = preis end
        AH.items[id] = x
      end)
    end)
  end
end

-- Verkaeufe: Rechnungen der AH-Post ("Auktion erfolgreich") auswerten, jede Mail nur einmal
local function idZuName(name)
  local r = B().inserat[name]; if r and r.id then return r.id end
  local _, link = (C_Item and C_Item.GetItemInfo or GetItemInfo)(name)
  local id = link and tonumber(string.match(link, "item:(%d+)")); if id then return id end
  for iid, it in pairs(D().items or {}) do if it[1] == name then return iid end end
  return nil
end
-- ---------------------------------------------------------------- Preis-Protokoll
-- GoldForeverDB.preisLog = Liste (max. 1500), je Einstellen ein Eintrag:
--   t = Zeit, id, name, n = Stueck, char, preis = eingestellt (Stueckpreis), vor = Vorschlag Gold Forever,
--   live = AH-Live-Preis (falls < 2 Std.), markt = Datenpreis, opMin = TSM-Mindestpreis, art = Empfehlung (verk/halt/kauf)
--   Verkauf (aus der AH-Post): vk = Zeit erster Verkauf, vn = verkaufte Stueck, erl = Erloes brutto
-- Auswertung spaeter (Claude/Web-App): Abweichung preis/vor, Verkaufsdauer vk - t, Verkaufsquote.
function GF.preisLogNeu(id, name, menge, preis, e)
  local log = GoldForeverDB.preisLog or {}; GoldForeverDB.preisLog = log
  local i = GF.info(id) or {}
  local vor = i.p and GF.einstellen(i) or nil
  local gv = GF.vorschlagPreis and GF.vorschlagPreis[tonumber(id)]
  if gv and time() - gv.t < 30 then vor = gv.p end -- von Gold Forever selbst eingestellt (2.51)
  log[#log + 1] = { t = time(), id = id, name = name, n = menge, char = charKey(), preis = preis, vor = vor,
    live = GF.livePreis(id), markt = i.p, opMin = i.opMin, art = e and e.art or nil }
  while #log > 1500 do table.remove(log, 1) end
end
-- Verkauf aus der Post dem aeltesten offenen Eintrag gleichen Namens zuordnen (gleicher Charakter)
local function preisLogVerkauf(name, menge, erloes, wann)
  local ich = charKey()
  for _, x in ipairs(GoldForeverDB.preisLog or {}) do
    if x.name == name and (x.char == nil or x.char == ich) and (x.vn or 0) < (x.n or 1) and x.t <= wann + 60 then
      x.vk = x.vk or wann; x.vn = (x.vn or 0) + menge; x.erl = (x.erl or 0) + (erloes or 0)
      return
    end
  end
end

local function postLesen()
  if not GetInboxNumItems or not GetInboxInvoiceInfo then return end
  local b = B()
  GoldForeverDB.test = GoldForeverDB.test or {}
  GoldForeverDB.test.post = date("%Y-%m-%d")
  for k = 1, GetInboxNumItems() do
    local ok, typ, name, _, gebot, _, _, gebuehr, _, _, _, menge = pcall(GetInboxInvoiceInfo, k)
    if ok and typ == "seller" and name and gebot then
      local _, _, absender, betreff, geld, _, tage = GetInboxHeaderInfo(k)
      -- Ankunftszeit der Mail (AH-Post bleibt 30 Tage) als stabiler Schluessel
      local ankunft = tage and math.floor((time() - (30 - tage) * 86400) / 1800) or 0
      local key = name .. "|" .. gebot .. "|" .. (menge or 1) .. "|" .. ankunft
      if not b.post[key] then
        b.post[key] = time()
        pcall(preisLogVerkauf, name, menge or 1, gebot, tage and math.floor(time() - (30 - tage) * 86400) or time())
        local n = menge or 1
        local id = idZuName(name)
        local r = b.inserat[name]
        local v = false
        if r and (r.v or 0) > 0 then v = true; r.v = math.max(0, r.v - n)
        elseif r then r.o = math.max(0, (r.o or 0) - n) end
        if id then buchen("verk", id, n, gebot - (gebuehr or 0), v, nil, v and r and r.basis or nil) end
      end
    end
  end
  -- alte Mail-Schluessel aufraeumen
  for key, t in pairs(b.post) do if time() - t > 40 * 86400 then b.post[key] = nil end end
  -- 2.52 (Befund 29): Waren in der Post zaehlen. Gekaufte Ware, die weder in Tasche/Bank, im AH noch in der Post ist,
  -- wurde verarbeitet/verbraucht (z. B. Roher Weisenfisch gekocht) – die Position wird dann geschlossen.
  if GetInboxItem then
    local items = {}
    for k = 1, GetInboxNumItems() do
      for a = 1, (ATTACHMENTS_MAX_RECEIVE or 16) do
        local ok, _, iid, _, anz = pcall(GetInboxItem, k, a)
        if ok and iid then items[iid] = (items[iid] or 0) + (anz or 1) end
      end
    end
    GoldForeverDB.postWare = GoldForeverDB.postWare or {}
    GoldForeverDB.postWare[charKey()] = { t = time(), items = items }
  end
end

-- Offene Positionen: nach Vorschlag gekauft, noch nicht verkauft
-- {id, n (offen), da (in Taschen/Bank), post (noch in der Post), ek (Einkauf pro Stueck), ziel (Ziel pro Stueck), seit}
local posCache = { t = 0, n = -1 }
function GF.positionen()
  local b = B()
  if posCache.liste and posCache.t == time() and posCache.n == #b.buch and posCache.buch == b.buch then return posCache.liste end
  local ich = charKey()
  -- Alte Eintraege ohne Charakter: dem Charakter zuordnen, der die Ware hat (Taschen/Bank oder AH)
  for _, x in ipairs(b.buch) do
    if not x.char and x.art == "kauf" and x.v and (GF.anzahl(x.id) > 0 or (GF.ahDaten().items[x.id])) then x.char = ich end
  end
  local pos, liste, fremd = {}, {}, {}
  for _, x in ipairs(b.buch) do
    local key = (x.char or "?") .. ":" .. x.id
    local p = pos[key]
    if (x.art == "kauf" or x.art == "herg") and x.v then
      p = p or { id = x.id, char = x.char or "?", n = 0, kosten = 0, zielSumme = 0, zielN = 0, seit = x.t }
      if x.art == "herg" then p.hergestellt = true end
      p.n = p.n + x.n; p.kosten = p.kosten - x.betrag
      if x.ziel then p.zielSumme = p.zielSumme + x.ziel * x.n; p.zielN = p.zielN + x.n end
      pos[key] = p
    elseif x.art == "verk" and not p then
      -- Verkauf ohne Charakter-Treffer: auf eine offene Position dieses Items buchen
      for k2, p2 in pairs(pos) do if p2.id == x.id and p2.n > 0 then p = p2; break end end
    end
    if x.art == "verk" and p then
      local weg = math.min(p.n, x.n)
      if p.n > 0 then p.kosten = p.kosten * (p.n - weg) / p.n end
      p.n = p.n - weg
    end
  end
  for _, p in pairs(pos) do
    local id = p.id
    if p.n > 0 and p.char ~= ich then
      p.ek = math.floor(p.kosten / p.n); p.i = GF.info(id); fremd[#fremd + 1] = p
    elseif p.n > 0 then
      local i = GF.info(id)
      p.ek = math.floor(p.kosten / p.n)
      p.ziel = (p.zielN > 0) and math.floor(p.zielSumme / p.zielN) or zielPreis(i) or p.ek
      -- Ziel mitziehen, wenn der uebliche Preis seit dem Kauf gefallen ist (sonst wartet man auf einen Preis,
      -- den es nicht mehr gibt); nie ueber das urspruengliche Ziel anheben
      local jetztZiel = zielPreis(i)
      if jetztZiel and jetztZiel < p.ziel then p.zielAlt = p.ziel; p.ziel = jetztZiel end
      -- Ziel nie unter "Einkauf + Gebuehr + 5 %", sonst waere es ein Verlustgeschaeft
      p.ziel = math.max(p.ziel, math.ceil(p.ek * 1.05 / 0.95))
      p.da = math.min(p.n, GF.anzahl(id))
      local ahN, ahPreis = GF.imAH(id)
      p.imAH = math.min(p.n - p.da, ahN); p.ahPreis = ahPreis
      p.post = math.max(0, p.n - p.da - p.imAH)
      -- Post gesehen (nach dem Kauf): was dort nicht liegt und nicht verkauft ist, ist verarbeitet/verbraucht
      local pw = GoldForeverDB.postWare and GoldForeverDB.postWare[ich]
      if p.post > 0 and pw and pw.t > p.seit then
        local vkN = (GF.ahDaten().verkauft or {})[id] or 0
        local weg = p.post - math.min(p.post, (pw.items[id] or 0) + vkN)
        if weg > 0 then
          p.kosten = p.kosten * (p.n - weg) / p.n
          p.n = p.n - weg; p.post = p.post - weg; p.weg = weg
        end
      end
      -- schon verkauft (Gold wartet im Briefkasten)?
      local vk = (GF.ahDaten().verkauft or {})[id] or 0
      p.verkauftPost = math.min(p.post, vk)
      if p.n <= 0 then p.aus = true end
      p.verkauftPreis = p.verkauftPost > 0 and ((GF.ahDaten().vpreis or {})[id]) or nil
      p.i = i
      if not p.aus then liste[#liste + 1] = p end
    end
  end
  table.sort(liste, function(a, c) return a.seit > c.seit end)
  posCache.liste, posCache.t, posCache.n, posCache.buch = liste, time(), #b.buch, b.buch
  GF.fremdePos = fremd
  return liste
end
function GF.position(id)
  for _, p in ipairs(GF.positionen()) do if p.id == tonumber(id) then return p end end
  return nil
end

-- Verkaufsplan fuer eine Position: {art = "verk"|"halt", kurz, lang, preis}
-- Messreihe fuer gekaufte Ware: Marktpreis hoechstens einmal pro 50 Min. merken (fuer die Verlustbremse)
function GF.posMessung(id, markt)
  if not markt then return end
  GoldForeverDB.posVerlauf = GoldForeverDB.posVerlauf or {}
  local v = GoldForeverDB.posVerlauf[id] or {}
  local letzte = v[#v]
  if not letzte or time() - letzte.t >= 3000 or (letzte.p ~= markt and time() - letzte.t >= 600) then
    v[#v + 1] = { t = time(), p = markt }
    while #v > 72 do table.remove(v, 1) end
  end
  GoldForeverDB.posVerlauf[id] = v
end
-- Abwaertstrend ueber Tage (2.55.1, Befund 48): nicht mehr "3 Messungen hintereinander gefallen" – das war
-- oft nur das normale Abendtief. Jetzt: gleiche Uhrzeit an Vortagen vergleichen (Messung vor 20–28 Std. und
-- vor 44–52 Std.), oder Fall ueber Tage aus den Realm-Daten, oder Trend der Datendatei <= -10 %.
local function messungVor(v, vonStd, bisStd)
  local jetzt = time()
  for k = #v, 1, -1 do
    local a = (jetzt - v[k].t) / 3600
    if a >= vonStd and a <= bisStd then return v[k].p end
  end
end
local function faellt(id)
  local v = (GoldForeverDB.posVerlauf or {})[id] or {}
  local jetzt = v[#v] and v[#v].p
  local gestern, vorgestern = messungVor(v, 20, 28), messungVor(v, 44, 52)
  if jetzt and gestern then
    if vorgestern and jetzt < gestern * 0.95 and gestern < vorgestern then return true end
    if not vorgestern and jetzt < gestern * 0.92 then return true end
  end
  if GF.faelltTage(id) then return true end
  local z = GF.zeit and GF.zeit(id)
  return z ~= nil and (z.t or 0) <= -10
end

-- Verlustbremse fuer nach Vorschlag gekaufte Ware (Regeln siehe addon-stand.md):
--   Schonfrist 24 Std. (bewaehrt 36 Std.) nach dem Kauf, ausser Absturz >= 50 % (seit 2.55.1)
--   a) Erloes jetzt >= 15 % unter Einkauf UND Preis faellt weiter
--   b) Erloes jetzt >= 25 % unter Einkauf (Raid-Ware vor Raidstart: >= 40 %)
--   c) der uebliche Preis (Ziel aus Ø/Marktwert) liegt inzwischen selbst unter dem Einkauf
--      UND Erloes jetzt unter Einkauf -> Ziel nicht mehr erreichbar
-- 2.55.1 (Befund 48, Wunsch Alex): Halten mindestens 24 Std. (bewaehrte Items 36 Std.), Tagesrhythmus beachten:
-- ausserhalb des Tageshochs (Profil Werktag/Wochenende aus den Daten, sonst 11–18 Uhr) keine Verkaufswarnung,
-- sondern "halten, neu pruefen im Tageshoch". Chat-Warnung erst, wenn der Verlust im Tageshoch 90 Min. bestehen bleibt.
-- Ausnahme: Absturz >= 50 %, von einer frueheren Messung bestaetigt.
function GF.imTageshoch()
  local tf = GF.tagesfenster and GF.tagesfenster()
  if tf then return tf.jetztVerk, tf.vVon, tf.bisVerk end
  local h = tonumber(date("%H"))
  return h >= 11 and h < 18, 11, ((11 - h) % 24)
end
local function bremseMerken(id, an)
  GoldForeverDB.bremseSeit = GoldForeverDB.bremseSeit or {}
  if not an then GoldForeverDB.bremseSeit[id] = nil; return nil end
  GoldForeverDB.bremseSeit[id] = GoldForeverDB.bremseSeit[id] or time()
  return GoldForeverDB.bremseSeit[id]
end
local function verlustBremse(p, i, markt, istRaid)
  if not markt then return nil end
  local erloes = markt * 0.95
  local verlust = 1 - erloes / p.ek -- Anteil unter Einkauf
  local alter = time() - p.seit
  local pz = math.floor(verlust * 100 + 0.5)
  local grund
  if istRaid then
    if verlust >= 0.40 then grund = "Raid-Ware " .. pz .. " % unter Einkauf" end
  else
    -- Einzelner Tiefpreis reicht nicht: ab 40 % sofort, sonst muss eine fruehere Messung (>= 45 Min. alt,
    -- letzte 6 Std.) den Verlust schon gezeigt haben (>= 20 %) – schuetzt vor einem einzelnen Billigangebot
    local function bestaetigt()
      for _, m in ipairs((GoldForeverDB.posVerlauf or {})[p.id] or {}) do
        local a = time() - m.t
        if a >= 2700 and a <= 6 * 3600 and 1 - m.p * 0.95 / p.ek >= 0.20 then return true end
      end
      return false
    end
    local erf = GF.erfahrung and GF.erfahrung(p.id)
    local frist = (erf and erf.bewaehrt) and 36 * 3600 or 24 * 3600
    local absturz = verlust >= 0.50 and bestaetigt()
    if alter < frist and not absturz then bremseMerken(p.id, false); return nil end
    if absturz or verlust >= 0.40 or (verlust >= 0.25 and bestaetigt()) then grund = pz .. " % unter Einkauf"
    elseif verlust >= 0.15 and faellt(p.id) then grund = pz .. " % unter Einkauf und fällt seit Tagen"
    -- 2.52 (Auswertung Woche 1): Verlierer lagen fast alle in Maerkten, die ueber Tage fielen, und wurden zu lange gehalten
    elseif verlust >= 0.05 and GF.faelltTage(p.id) then grund = pz .. " % unter Einkauf, Markt fällt " .. GF.faelltTage(p.id)
    elseif verlust > 0 then
      local zp = GF.referenz(p.id, i)
      if zp and zp * 0.95 < p.ek then grund = "üblicher Preis ist gefallen, Ziel nicht mehr erreichbar" end
    end
  end
  if not grund then bremseMerken(p.id, false); return nil end
  local minus = math.floor((p.ek - erloes) * p.n)
  -- 2.55 (Befund 41): Kleinstverlust (< 2s gesamt, unter 25 %) nicht mit Gebuehr realisieren – lieber halten
  if not istRaid and verlust < 0.25 and minus < 200 then bremseMerken(p.id, false); return nil end
  -- 2.55.1: Tagesrhythmus – ausserhalb des Tageshochs halten (ausser Absturz >= 50 % / Raid-Ware)
  if not istRaid and verlust < 0.50 then
    local hoch, von, inStd = GF.imTageshoch()
    if not hoch then
      bremseMerken(p.id, false)
      local wann = inStd and inStd < 1 and "gleich" or ("ab ca. " .. von .. " Uhr")
      return { art = "halt", kurz = "Tagestief – halten", tief = true,
        lang = grund .. " – aber gerade kein Tageshoch: halten, neu prüfen " .. wann }
    end
  end
  local seit = bremseMerken(p.id, true)
  return { art = "verk", stop = true, kurz = "Verlust begrenzen", preis = markt, seit = seit,
    lang = grund .. " – lieber jetzt für " .. GF.geld(markt) .. " verkaufen (ca. -" .. GF.geld(minus) .. ")" }
end

function GF.verkaufsPlan(p)
  local i = GF.info(p.id); if not i then return nil end -- immer frisch (Live-Preis)
  -- Nichts mehr in Taschen/Bank und nichts im AH: verkauft (Gold im Briefkasten) oder Ware liegt in der Post
  if (p.da or 0) == 0 and (p.imAH or 0) == 0 then
    if (p.verkauftPost or 0) > 0 then
      return { art = "halt", imAH = true, verkauft = true, kurz = "verkauft", lang = "Verkauft – Briefkasten leeren, dann zählt es in der Bilanz" }
    end
    return { art = "halt", imAH = true, post = true, kurz = "im Briefkasten", lang = "Liegt im Briefkasten – abholen, danach plant Gold Forever den Verkauf" }
  end
  -- Schon alles im AH eingestellt: warten; nur melden, wenn jemand deutlich billiger anbietet
  if (p.imAH or 0) > 0 and (p.da or 0) == 0 then
    -- Kein fremdes Angebot im AH (letzte Suche fand nur die eigene Auktion): eigener Preis gegen ueblich/Marktwert
    if p.ahPreis and GF.liveNurEigene(p.id) then
      local R = GF.referenz(p.id, i)
      local cap = R and ((i.mw and i.mw > 0) and math.min(R, i.mw) or R)
      if cap and p.ahPreis > cap * 1.3 and (cap - 1) * 0.95 > p.ek then
        local neu = cap - 1
        return { art = "verk", abbrechen = true, kurz = "abbrechen, neu einstellen", preis = neu,
          lang = "Dein Preis " .. GF.geld(p.ahPreis) .. " ist das einzige Angebot, liegt aber weit über üblich (" .. GF.geld(cap) .. ") – verkauft so kaum. Auktion abbrechen (die Einstellgebühr ist dann weg) und für " .. GF.geld(neu) .. " neu einstellen" }
      end
    end
    -- Unterboten und der Markt faellt seit Tagen (nicht nur Tagesrhythmus): Warten bis zum Ablauf kostet -> jetzt neu einstellen
    local ft = GF.faelltTage(p.id)
    if ft and p.ahPreis and i.ahGeprueft and i.p and i.p < p.ahPreis * 0.97 then
      local neu = i.p - 1
      local minus = neu * 0.95 < p.ek
      return { art = "verk", abbrechen = true, stop = minus or nil, kurz = "abbrechen, neu einstellen", preis = neu,
        lang = "Unterboten (" .. GF.geld(i.p) .. ") und der Preis fällt " .. ft .. " – Warten bis zum Ablauf kostet. Auktion abbrechen und für " .. GF.geld(neu) .. " neu einstellen" .. (minus and " (mit Verlust, aber er wird nicht größer)" or "") }
    end
    -- nur mit Live-Preis aus einer AH-Suche beurteilen (sonst sind die Daten zu alt)
    -- Weit ueber dem Markt (z. B. nach einer Preisspitze eingestellt): abbrechen und neu einstellen,
    -- sofern der neue Preis noch Gewinn bringt – Warten auf den Ablauf lohnt dann nicht
    if p.ahPreis and i.ahGeprueft and i.p and i.p * 1.3 < p.ahPreis and (i.p - 1) * 0.95 > p.ek then
      local neu = i.p - 1
      return { art = "verk", abbrechen = true, kurz = "abbrechen, neu einstellen", preis = neu,
        lang = "Dein Preis " .. GF.geld(p.ahPreis) .. " liegt weit über dem Markt (" .. GF.geld(i.p) .. ") – verkauft so nicht. Auktion abbrechen (die Einstellgebühr ist dann weg) und für " .. GF.geld(neu) .. " neu einstellen" }
    end
    if p.ahPreis and i.ahLive and i.p and i.p < p.ahPreis * 0.97 then
      return { art = "halt", kurz = "im AH, unterboten", lang = "Im AH für " .. GF.geld(p.ahPreis) .. ", aber jemand bietet " .. GF.geld(i.p) .. " – erst neu einstellen, wenn die Auktion abläuft" }
    end
    local fuer = p.ahPreis and (" für je " .. GF.geld(p.ahPreis)) or ""
    return { art = "halt", kurz = "im AH" .. (p.ahPreis and (" für " .. GF.geld(p.ahPreis)) or ""), imAH = true, lang = p.imAH .. " Stück im AH" .. fuer .. " – warten, bis verkauft (danach Briefkasten leeren)" }
  end
  -- Entscheidend ist der Preis, zu dem man jetzt wirklich vorn im AH steht (guenstigstes Angebot - 1c),
  -- nicht der Mindestpreis aus GF.einstellen – sonst liegt die Ware zu teuer herum.
  local markt = i.p and (i.p - 1)
  if markt and i.vb then markt = math.min(markt, i.vb - 1) end
  local rk = GF.raid(p.id)
  if rk and not GF.raidLaeuft() then
    local stop = verlustBremse(p, i, markt, true); if stop then return stop end
    local y, m, d = string.match(D().raidstart or "", "(%d+)-(%d+)-(%d+)")
    local dat = d and (tonumber(d) .. "." .. tonumber(m) .. ".") or "Raidstart"
    return { art = "halt", kurz = "halten bis " .. dat, lang = "Raid-Ware: halten, ab " .. dat .. " verkaufen" }
  end
  -- 2.53.3 (Befund 38): Hergestelltes direkt verkaufen, sobald der Erloes ueber dem Wert der Zutaten liegt
  if p.hergestellt and markt and markt * 0.95 >= p.ek then
    return { art = "verk", kurz = "jetzt einstellen", preis = markt, lang = "Hergestellt nach Vorschlag – jetzt für " .. GF.geld(markt) .. " einstellen (Zutaten-Wert " .. GF.geld(p.ek) .. ")" }
  end
  if markt and markt >= p.ziel then
    -- Preisspitze: guenstiges Angebot wurde leergekauft, Markt liegt weit ueber ueblich.
    -- Trotzdem jetzt einstellen (kostet nur die Gebuehr), aber mit Rueckfallplan.
    local R = GF.referenz(p.id, i)
    if R and markt > R * 2.5 then
      return { art = "verk", kurz = "jetzt einstellen", preis = markt, spitze = true,
        lang = "Preisspitze (Markt leergekauft) – jetzt für " .. GF.geld(markt) .. " einstellen. Nicht verkauft nach 24 Std.? Dann für ca. " .. GF.geld(math.floor(R * 1.5)) .. " neu einstellen" }
    end
    return { art = "verk", kurz = "jetzt einstellen", lang = "Ziel erreicht – jetzt für " .. GF.geld(markt) .. " einstellen", preis = markt }
  end
  if markt and markt * 0.95 >= p.ek * 1.3 then
    return { art = "verk", kurz = "jetzt einstellen", lang = "Ziel noch nicht ganz, aber +30 % Gewinn möglich – für " .. GF.geld(markt) .. " einstellen", preis = markt }
  end
  local stop = verlustBremse(p, i, markt, false); if stop then return stop end
  local tage = math.floor((time() - p.seit) / 86400)
  if tage >= 7 and markt and markt * 0.95 > p.ek then
    return { art = "verk", kurz = "jetzt einstellen", lang = "seit " .. tage .. " Tagen unter Ziel – für " .. GF.geld(markt) .. " mit kleinem Gewinn einstellen", preis = markt }
  end
  local zt = GF.zeitText(p.id, "verk")
  local jetztTxt = (i.ahLive and markt) and ("Im AH gerade " .. GF.geld(markt + 1) .. " – zu wenig. ") or ""
  return { art = "halt", kurz = "halten · Ziel " .. GF.geld(p.ziel),
    lang = jetztTxt .. "halten, bis der Preis " .. GF.geld(p.ziel) .. " erreicht – Gold Forever meldet sich dann" }
end

-- Testplan: was ist heute automatisch erkennbar erledigt?
function GF.testHeute()
  local b = B(); local heute = date("%Y-%m-%d")
  local mitternacht = time() - (tonumber(date("%H")) * 3600 + tonumber(date("%M")) * 60 + tonumber(date("%S")))
  local r = { einV = 0, einO = 0, kaufV = 0, kaufO = 0, verkV = 0, post = (GoldForeverDB.test or {}).post == heute }
  for _, x in ipairs(b.einstellLog or {}) do if x.t >= mitternacht then if x.v then r.einV = r.einV + 1 else r.einO = r.einO + 1 end end end
  for _, x in ipairs(b.buch) do
    if x.t >= mitternacht then
      if x.art == "kauf" then if x.v then r.kaufV = r.kaufV + 1 else r.kaufO = r.kaufO + 1 end
      elseif x.v then r.verkV = r.verkV + 1 end
    end
  end
  local pos = GF.positionen(); r.pos = #pos; r.posVerk = 0
  for _, p in ipairs(pos) do local pl = GF.verkaufsPlan(p); if pl and pl.art == "verk" then r.posVerk = r.posVerk + 1 end end
  local d = D(); r.datenAlter = d.stand and math.floor((time() - d.stand) / 3600) or nil
  return r
end

-- Auswertung fuer einen Zeitraum (Sekunden zurueck, nil = alles)
function GF.bilanz(sekunden)
  -- Zwei Arten von Geschaeften nach Vorschlag:
  --   Flip: nach Vorschlag gekauft und wieder verkauft -> voller Erloes minus Einkauf zaehlt.
  --   Eigene Ware (gefarmt/vorhanden) nach Vorschlag verkauft -> nur der MEHRERLOES zaehlt:
  --     (Erloes pro Stueck - Vergleichspreis x 0,95) x Menge. Vergleichspreis = Preis beim Rat zu warten,
  --     sonst ueblicher Preis. Normale Farm-Verkaeufe ohne Vorteil zaehlen damit nicht als Erfolg.
  -- Geschaefte ohne Vorschlag zaehlen gar nicht.
  local b = B(); local ab = sekunden and (time() - sekunden) or 0
  local r = { ein = 0, aus = 0, nVerk = 0, nKauf = 0, mehr = 0, nFarm = 0, ohne = 0, bestand = 0, liste = {} }
  local pos, netto = {}, {}
  for _, x in ipairs(b.buch) do -- chronologisch, damit Flips richtig zugeordnet werden
    local drin = x.t >= ab
    if x.v and (x.art == "kauf" or x.art == "herg") then
      pos[x.id] = (pos[x.id] or 0) + x.n
      if drin then
        r.aus = r.aus - x.betrag; r.nKauf = r.nKauf + 1
        netto[x.id] = (netto[x.id] or 0) + x.n
        r.liste[#r.liste + 1] = { x = x, typ = "kauf", wert = x.betrag }
      end
    elseif x.v and x.art == "verk" then
      local flipN = math.min(x.n, pos[x.id] or 0); local farmN = x.n - flipN
      pos[x.id] = (pos[x.id] or 0) - flipN
      local proStk = x.betrag / x.n
      if drin then
        if flipN > 0 then
          r.ein = r.ein + proStk * flipN; r.nVerk = r.nVerk + 1
          netto[x.id] = (netto[x.id] or 0) - flipN
          r.liste[#r.liste + 1] = { x = x, typ = "flip", n = flipN, wert = math.floor(proStk * flipN) }
        end
        if farmN > 0 then
          local mehr = x.basis and math.floor((proStk - x.basis * 0.95) * farmN) or 0
          r.mehr = r.mehr + mehr; r.nFarm = r.nFarm + 1
          r.liste[#r.liste + 1] = { x = x, typ = "farm", n = farmN, wert = mehr }
        end
      end
    elseif drin then
      r.ohne = r.ohne + 1
    end
  end
  -- Gekaufte Ware, die noch da ist, zum heutigen Verkaufswert
  for id, n in pairs(netto) do
    if n > 0 then
      local da = math.min(n, GF.anzahl(id)); local w = GF.verkaufswert(GF.info(id)) or 0
      r.bestand = r.bestand + da * w
    end
  end
  r.ein = math.floor(r.ein)
  r.ergebnis = r.ein - r.aus + r.bestand + r.mehr
  table.sort(r.liste, function(a, c) return a.x.t > c.x.t end)
  return r
end

-- ---------------------------------------------------------------- Eigene Auktionen im AH
-- GoldForeverDB.imAH = {t = Zeit, items = {[itemID] = {n = Stueck, preis = guenstigster eigener Stueckpreis}}}
local function eigeneAuktionen()
  if not (C_AuctionHouse and C_AuctionHouse.GetNumOwnedAuctions and C_AuctionHouse.GetOwnedAuctionInfo) then return end
  local items, verkauft, vpreis = {}, {}, {}
  GF.ahAuktionen = {}
  for k = 1, C_AuctionHouse.GetNumOwnedAuctions() do
    local a = C_AuctionHouse.GetOwnedAuctionInfo(k)
    -- status 0 = laeuft, 1 = verkauft (wartet auf Post)
    if a and a.itemKey and a.itemKey.itemID and (a.status or 0) == 1 then
      local id = a.itemKey.itemID
      verkauft[id] = (verkauft[id] or 0) + (a.quantity or 1)
      -- 2.52 (Befund 28): Verkaufspreis merken, damit der Gewinn mit dem echten Erloes rechnet, nicht mit dem Ziel
      if a.buyoutAmount and a.buyoutAmount > 0 then
        vpreis[id] = vpreis[id] or {}; local v = vpreis[id]; v.n = (v.n or 0) + (a.quantity or 1); v.summe = (v.summe or 0) + a.buyoutAmount * (a.quantity or 1)
      end
    end
    if a and a.itemKey and a.itemKey.itemID and (a.status or 0) == 0 then
      local id = a.itemKey.itemID
      local x = items[id] or { n = 0 }
      x.n = x.n + (a.quantity or 1)
      local p = a.buyoutAmount
      if p and (not x.preis or p < x.preis) then x.preis = p end
      items[id] = x
      if a.auctionID then
        local l = GF.ahAuktionen[id] or {}; l[#l + 1] = { id = a.auctionID, p = p, n = a.quantity or 1 }; GF.ahAuktionen[id] = l
      end
    end
  end
  GoldForeverDB.imAHc = GoldForeverDB.imAHc or {}
  local vp = {}
  for id, v in pairs(vpreis) do vp[id] = math.floor(v.summe / v.n) end
  GoldForeverDB.imAHc[charKey()] = { t = time(), items = items, verkauft = verkauft, vpreis = vp }
  if GF.aktualisieren then pcall(GF.aktualisieren) end
end
function GF.imAH(id)
  id = tonumber(id)
  local a = GF.ahDaten()
  local x = a and a.items and a.items[id]
  if x then return x.n or 0, x.preis end
  -- Rueckfall: eingestellt laut Protokoll (letzte 48 Std.), seit der letzten Liste "Meine Auktionen"
  local seit = math.max(time() - 48 * 3600, (a and a.t) or 0)
  local n = 0
  for _, l in ipairs(B().einstellLog or {}) do if l.id == id and l.t > seit and (l.char == nil or l.char == charKey()) then n = n + (l.n or 1) end end
  return n, nil
end

-- ---------------------------------------------------------------- Selbst einstellen / abbrechen (2.51, Befund 22)
-- Ein Klick im Fenster = eine Auktion (Blizzard verlangt einen Klick je Auktion). TSM wird zum Verkaufen nicht gebraucht.
GF.vorschlagPreis = {} -- [id] = {p, t}: Preis, mit dem Gold Forever gerade selbst eingestellt hat
GF.ahAuktionen = {}    -- [id] = { {id = Auktions-ID, p, n} } aus „Meine Auktionen“
local DAUER = { ["2 Std."] = 1, ["8 Std."] = 2, ["24 Std."] = 3 }
local function taschenPlatz(id)
  if not (C_Container and C_Container.GetContainerNumSlots) then return nil end
  for b = 0, 5 do
    local ok, n = pcall(C_Container.GetContainerNumSlots, b)
    for s = 1, (ok and n or 0) do
      local ok2, info = pcall(C_Container.GetContainerItemInfo, b, s)
      if ok2 and info and info.itemID == id and not info.isBound and not info.isLocked then return b, s, info end
    end
  end
  return nil
end
function GF.inTasche(id) return taschenPlatz(tonumber(id)) ~= nil end
function GF.einstellenJetzt(id, preis, menge, dauerText)
  id = tonumber(id)
  if not (GF.ah and C_AuctionHouse and ItemLocation) then return false, "das Auktionshaus ist nicht offen" end
  local b, s, info = taschenPlatz(id)
  if not b then return false, "nicht in der Tasche – erst aus Bank oder Post holen" end
  preis = math.max(1, math.floor(preis or 0))
  local loc = ItemLocation:CreateFromBagAndSlot(b, s)
  local dauer = DAUER[dauerText or ""] or 3
  local status = C_AuctionHouse.GetItemCommodityStatus and C_AuctionHouse.GetItemCommodityStatus(loc)
  local rohstoff = Enum and Enum.ItemCommodityStatus and status == Enum.ItemCommodityStatus.Commodity
  GF.vorschlagPreis[id] = { p = preis, t = time() }
  local n
  local ok, err = pcall(function()
    if rohstoff then
      local max = (C_AuctionHouse.GetAvailablePostCount and C_AuctionHouse.GetAvailablePostCount(loc)) or info.stackCount or 1
      n = math.max(1, math.min(menge or max, max))
      local frage = C_AuctionHouse.PostCommodity(loc, dauer, n, preis)
      if frage and C_AuctionHouse.ConfirmPostCommodity then C_AuctionHouse.ConfirmPostCommodity(loc, dauer, n, preis) end
    else
      n = 1 -- Einzel-Items (Ausruestung) je Klick ein Stueck
      local frage = C_AuctionHouse.PostItem(loc, dauer, n, nil, preis)
      if frage and C_AuctionHouse.ConfirmPostItem then C_AuctionHouse.ConfirmPostItem(loc, dauer, n, nil, preis) end
    end
  end)
  return ok, err, n
end
-- bricht die teuerste eigene Auktion dieses Items ab (die Ware kommt per Post zurueck)
function GF.abbrechenJetzt(id)
  id = tonumber(id)
  local l = GF.ahAuktionen[id]
  if not (GF.ah and C_AuctionHouse and C_AuctionHouse.CancelAuction) then return false, "das Auktionshaus ist nicht offen" end
  if not (l and #l > 0) then
    if C_AuctionHouse.QueryOwnedAuctions then pcall(C_AuctionHouse.QueryOwnedAuctions, {}) end
    return false, "„Meine Auktionen“ wird geladen – gleich noch einmal klicken"
  end
  table.sort(l, function(a, b) return (a.p or 0) > (b.p or 0) end)
  local a = l[1]
  if C_AuctionHouse.CanCancelAuction and not C_AuctionHouse.CanCancelAuction(a.id) then return false, "diese Auktion kann nicht abgebrochen werden" end
  local ok, err = pcall(C_AuctionHouse.CancelAuction, a.id)
  if ok then table.remove(l, 1) end
  return ok, err, a
end

-- ---------------------------------------------------------------- Selbst kaufen (2.52)
-- Rohstoffe (Commodities): Klick 1 fragt bei Blizzard den echten Gesamtpreis an (StartCommoditiesPurchase),
-- Klick 2 bestaetigt – nur wenn der Stueckpreis nicht ueber dem Hoechstpreis aus dem Plan liegt.
-- Einzel-Items brauchen eine Suche mit Auktions-ID: dafuer bleibt „Suchen“.
GF.kaufLauf = nil -- {id, n, max, t, unit, total}
function GF.kaufStarten(id, menge, maxPreis)
  id = tonumber(id)
  if not (GF.ah and C_AuctionHouse and C_AuctionHouse.StartCommoditiesPurchase) then return false, "das Auktionshaus ist nicht offen" end
  local i = GF.info(id)
  menge = math.max(1, math.floor(menge or 1))
  local kosten = (GF.kaufPreis(id, menge) or maxPreis or 0) * menge
  if GetMoney and kosten > GetMoney() then return false, "nicht genug Gold" end
  GF.kaufLauf = { id = id, n = menge, max = maxPreis, t = time() }
  local ok, err = pcall(C_AuctionHouse.StartCommoditiesPurchase, id, menge)
  if not ok then GF.kaufLauf = nil; return false, err end
  return true
end
function GF.kaufPreisDa(unit, total)
  local k = GF.kaufLauf; if not k then return end
  k.unit, k.total = unit, total
  if k.max and unit and unit > k.max then
    pcall(C_AuctionHouse.CancelCommoditiesPurchase)
    GF.kaufLauf = nil
    print(GOLD .. "Gold Forever:" .. ENDE .. " Kauf abgebrochen – im AH kostet es jetzt " .. GF.geld(unit) .. " je Stück, Höchstpreis " .. GF.geld(k.max) .. ". Das Tief ist vorbei.")
  end
  if GF.aktualisieren then pcall(GF.aktualisieren) end
end
function GF.kaufBestaetigen()
  local k = GF.kaufLauf
  if not (k and k.unit) then return false, "Preis noch nicht da – gleich noch einmal klicken" end
  if time() - k.t > 50 then GF.kaufLauf = nil; return false, "Angebot abgelaufen – noch einmal „Kaufen“ klicken" end
  local ok, err = pcall(C_AuctionHouse.ConfirmCommoditiesPurchase, k.id, k.n)
  GF.kaufLauf = nil
  return ok, err, k
end
-- Unterbieter-Schnaeppchen (2.52, Wunsch Alex): Bietet jemand nur 1–3 Stueck deutlich (>= 25 %) unter ueblich an
-- und liegt der Rest des Marktes wieder normal, lohnt es, diese Stuecke selbst zu kaufen und zum normalen Preis
-- neu einzustellen. Nur mit frischer AH-Suche (10 Min.), nur gehandelte Items, nie Haendlerware.
function GF.unterbieter(id)
  id = tonumber(id)
  local l = GF.live[id]
  if not (l and l.st and #l.st >= 2 and not l.voll and time() - l.t < 600) then return nil end
  local i = GF.info(id); if not i or i.vb or GF.HAENDLERWARE[id] then return nil end
  if (i.u or 0) < 20 then return nil end
  local R = GF.referenz(id, i); if not R then return nil end
  local n, kosten, maxP, naechster = 0, 0, 0, nil
  for _, x in ipairs(l.st) do
    if x.p <= R * 0.75 then n = n + (x.q or 1); kosten = kosten + x.p * (x.q or 1); maxP = math.max(maxP, x.p)
    else naechster = x.p; break end
  end
  if n < 1 or n > 3 or not naechster or naechster < R * 0.9 then return nil end
  local neu = math.min(naechster - 1, R)
  local gewinn = math.floor(neu * 0.95 * n - kosten)
  if gewinn < 200 then return nil end -- unter 2s lohnt der Aufwand nicht
  GF.unterbieterMerk = GF.unterbieterMerk or {}
  GF.unterbieterMerk[id] = { neu = neu, t = time() }
  return { id = id, n = n, max = maxP, kosten = kosten, neu = neu, gewinn = gewinn, R = R }
end
function GF.unterbieterListe()
  local out = {}
  for id in pairs(GF.live) do
    local u = GF.unterbieter(id)
    if u and not GF.ausgeblendet(id) then out[#out + 1] = u end
  end
  table.sort(out, function(a, b) return a.gewinn > b.gewinn end)
  return out
end

function GF.istRohstoff(id)
  local l = GF.live[tonumber(id)]
  if l and l.rohstoff then return true end -- aus einer Rohstoff-Suche
  local _, _, _, _, _, _, _, stapel = (C_Item and C_Item.GetItemInfo or GetItemInfo)(id)
  return (stapel or 1) > 1
end

-- ---------------------------------------------------------------- Rezepte merken (2.53)
-- Beim Oeffnen eines Berufsfensters: gelernte Rezepte mit Zutaten und Ergebnis speichern (je Charakter).
local rezeptTimer
local function rezepteLesen()
  local mein = (GoldForeverDB.rezepte and GoldForeverDB.rezepte[charKey()]) or {}
  local neu = 0
  if C_TradeSkillUI and C_TradeSkillUI.GetAllRecipeIDs and C_TradeSkillUI.GetRecipeSchematic then
    local beruf
    local okb, bi = pcall(C_TradeSkillUI.GetBaseProfessionInfo); if okb and bi then beruf = bi.professionName end
    for _, rid in ipairs(C_TradeSkillUI.GetAllRecipeIDs() or {}) do
      local ok, info = pcall(C_TradeSkillUI.GetRecipeInfo, rid)
      if ok and info and info.learned then
        local ok2, sc = pcall(C_TradeSkillUI.GetRecipeSchematic, rid, false)
        if ok2 and sc and sc.outputItemID then
          local z = {}
          for _, slot in ipairs(sc.reagentSlotSchematics or {}) do
            local basis = slot.reagentType == nil or slot.reagentType == 1 or (Enum and Enum.CraftingReagentType and slot.reagentType == Enum.CraftingReagentType.Basic)
            local r = slot.reagents and slot.reagents[1]
            if basis and r and r.itemID and slot.required ~= false then z[#z + 1] = { r.itemID, slot.quantityRequired or 1 } end
          end
          if #z > 0 then
            if not mein[rid] then neu = neu + 1 end
            mein[rid] = { sc.outputItemID, ((sc.quantityMin or 1) + (sc.quantityMax or sc.quantityMin or 1)) / 2, beruf or "", 0, z, name = info.name }
          end
        end
      end
    end
  elseif GetNumTradeSkills and GetTradeSkillInfo then
    -- Rueckfall: alte Berufs-API (Classic)
    local beruf = GetTradeSkillLine and GetTradeSkillLine() or ""
    for k = 1, GetNumTradeSkills() do
      local name, typ = GetTradeSkillInfo(k)
      if name and typ ~= "header" then
        local link = GetTradeSkillItemLink and GetTradeSkillItemLink(k)
        local pid = link and tonumber(string.match(link, "item:(%d+)"))
        if pid then
          local z = {}
          for r = 1, (GetTradeSkillNumReagents and GetTradeSkillNumReagents(k) or 0) do
            local _, _, anz = GetTradeSkillReagentInfo(k, r)
            local rl = GetTradeSkillReagentItemLink and GetTradeSkillReagentItemLink(k, r)
            local rid = rl and tonumber(string.match(rl, "item:(%d+)"))
            if rid then z[#z + 1] = { rid, anz or 1 } end
          end
          local mn, mx = 1, 1
          if GetTradeSkillNumMade then mn, mx = GetTradeSkillNumMade(k) end
          local key = "c" .. pid
          if #z > 0 then
            if not mein[key] then neu = neu + 1 end
            mein[key] = { pid, ((mn or 1) + (mx or mn or 1)) / 2, beruf, 0, z, name = name }
          end
        end
      end
    end
  end
  GoldForeverDB.rezepte = GoldForeverDB.rezepte or {}
  GoldForeverDB.rezepte[charKey()] = mein
  nutzIndex = nil
  if neu > 0 then
    local n = 0; for _ in pairs(mein) do n = n + 1 end
    print(GOLD .. "Gold Forever:" .. ENDE .. " " .. neu .. " Rezepte neu gemerkt (" .. n .. " insgesamt) – „Herstellen“ rechnet jetzt mit deinen Rezepten.")
    if GF.aktualisieren then pcall(GF.aktualisieren) end
  end
end
function GF.rezepteLesenSpaeter()
  if not C_Timer then return pcall(rezepteLesen) end
  if rezeptTimer then rezeptTimer:Cancel() end
  rezeptTimer = C_Timer.NewTimer(1.5, function() rezeptTimer = nil; pcall(rezepteLesen) end)
end

-- Herstellen-Vorschlaege (2.53):
--  a) eigene Rohstoffe, bei denen ein eigenes Rezept deutlich mehr bringt als Verkaufen (Empfehlung „herstellen“)
--  b) Zutaten kaufen -> herstellen -> verkaufen: Gewinn >= 5s und >= 10 % der Kosten, Ergebnis verkauft sich (>= 20/Tag)
function GF.herstellenListe()
  -- 2.53.4 (Befund 40): eine Rechnung je Rezept und Zutat – vorhandene Menge zaehlt mit dem entgangenen
  -- Verkaufswert, fehlende Menge mit dem Haendlerpreis (Haendlerware) bzw. dem AH-Kaufpreis nach Menge.
  -- Rueckgabe: eigen (leer, alte Form), kauf = Liste {id, r, menge (Herstellungen), kosten, erl, gewinn, fehlt, eigen, frisch}
  local liste = {}
  for _, r in ipairs(GF.eigeneRezepte() or {}) do
    local pid = r[1]
    local pi = GF.info(pid)
    local erl1 = pi and GF.wert(pi)
    local rl = GF.realm(pid)
    local absatz = math.max(pi and pi.u or 0, rl and rl.vt or 0)
    if erl1 and erl1 > 0 and absatz >= 20 and not GF.ausgeblendet(pid) then
      local aus = (r[2] and r[2] > 0) and r[2] or 1
      -- Wie oft herstellen? Nach der eigenen Hauptzutat (am meisten Herstellungen), hoechstens 5 % des Tagesabsatzes
      local maxAbsatz = math.max(1, math.floor(absatz * 0.05 / aus))
      local nachEigen = 0
      for _, z in ipairs(r[5]) do
        local zi = GF.info(z[1])
        if not (zi and zi.vb) and not GF.HAENDLERWARE[z[1]] then
          nachEigen = math.max(nachEigen, math.floor(GF.anzahl(z[1]) / z[2]))
        end
      end
      local menge = math.max(1, math.min(maxAbsatz, nachEigen > 0 and nachEigen or 1))
      local kosten, ok, frisch, fehlt, eigen = 0, true, true, {}, false
      for _, z in ipairs(r[5]) do
        local zid, bedarf = z[1], z[2] * menge
        local zi = GF.info(zid)
        local hat = math.min(bedarf, GF.anzahl(zid))
        local rest = bedarf - hat
        if hat > 0 then
          eigen = true
          local w = (zi and (GF.verkaufswert(zi) or zi.p)) or (zi and zi.vb) or 0
          kosten = kosten + w * hat
        end
        if rest > 0 then
          local haendler = (zi and zi.vb) or nil
          if haendler or GF.HAENDLERWARE[zid] then
            if not haendler then ok = false; break end
            kosten = kosten + haendler * rest
            fehlt[#fehlt + 1] = { id = zid, n = rest, quelle = "haendler", preis = haendler }
          else
            local preis = GF.kaufPreis(zid, rest) or (zi and zi.p)
            if not preis then ok = false; break end
            if not GF.frisch(zid) then frisch = false end
            kosten = kosten + preis * rest
            fehlt[#fehlt + 1] = { id = zid, n = rest, quelle = "ah", preis = preis }
          end
        end
      end
      if ok then
        local erl = erl1 * aus * menge
        local gewinn = math.floor(erl - kosten)
        if gewinn >= 500 and gewinn >= kosten * 0.1 then
          liste[#liste + 1] = { id = pid, r = r, menge = menge, aus = aus, kosten = kosten, erl = erl, gewinn = gewinn, fehlt = fehlt, eigen = eigen, frisch = frisch }
          GF.herstellMerken(pid, r, math.floor(erl1 / 0.95))
        end
      end
    end
  end
  -- eigene Zutaten zuerst (lohnt am meisten, weil schon da), dann nach Gewinn
  table.sort(liste, function(a, b) if a.eigen ~= b.eigen then return a.eigen end; return a.gewinn > b.gewinn end)
  return {}, liste
end

-- Herstellen nach Vorschlag erkennen (2.53.3, Befund 38): Vorgeschlagene Produkte merken; steigt beim offenen
-- Berufsfenster ihre Anzahl in den Taschen, wird das wie ein Kauf gebucht (art "herg", Kosten = Wert der Zutaten,
-- Ziel = erwarteter Erloes). Dann erscheint das Produkt unter Verkaufen/Auktionshaus und zaehlt in der Bilanz.
GF.herstellMerk = GF.herstellMerk or {}
function GF.rezeptKosten(r)
  local k = 0
  for _, z in ipairs(r[5] or {}) do
    local zi = GF.info(z[1])
    local preis = (zi and zi.vb) or (zi and (GF.verkaufswert(zi) or zi.p)) or 0
    k = k + preis * z[2]
  end
  local menge = (r[2] and r[2] > 0) and r[2] or 1
  return math.floor(k / menge)
end
local function herstellMerken(pid, r, ziel)
  GF.herstellMerk[pid] = { t = time(), r = r, ziel = ziel }
end
GF.herstellMerken = herstellMerken
local berufStand = {}
function GF.berufAuf()
  GF.berufOffen = true
  berufStand = {}
  for pid in pairs(GF.herstellMerk) do berufStand[pid] = GF.anzahl(pid) end
end
function GF.berufZu() GF.berufOffen = false end
function GF.herstellenPruefen()
  if not GF.berufOffen then return end
  for pid, m in pairs(GF.herstellMerk) do
    if time() - m.t <= 6 * 3600 then
      local jetzt = GF.anzahl(pid)
      local vorher = berufStand[pid]
      if vorher == nil then berufStand[pid] = jetzt
      elseif jetzt > vorher then
        local n = jetzt - vorher
        local kosten = GF.rezeptKosten(m.r)
        buchen("herg", pid, n, -kosten * n, true, m.ziel)
        berufStand[pid] = jetzt
        local name = ((C_Item and C_Item.GetItemInfo or GetItemInfo)(pid)) or ("Item " .. pid)
        print(GOLD .. "Gold Forever:" .. ENDE .. " " .. n .. "× " .. name .. " nach Vorschlag hergestellt – steht jetzt unter „Verkaufen“ (Ziel " .. GF.geld(m.ziel or 0) .. ").")
      else berufStand[pid] = jetzt end
    end
  end
end

-- ---------------------------------------------------------------- Gold nach Herkunft (2.53, Wunsch Alex)
-- Jede Goldaenderung wird nach dem Zusammenhang eingeordnet: Loot, Quest, Haendler (Verkauf/Kauf/Reparatur),
-- AH (Verkaufserloes aus der Post / Kaeufe), Sonstiges (Post von Spielern, Flugmeister, Gebuehren …).
-- GoldForeverDB.geld[char][JJJJ-MM-TT] = {loot, quest, haendler, haendlerkauf, ah, ahkauf, sonst}
local geldVorher, geldZeit = nil, {}
GF.offen = {}
local function geldMerken(art) geldZeit[art] = time() end
function GF.geldKontext(ev)
  if ev == "LOOT_OPENED" or ev == "LOOT_READY" then GF.offen.loot = true; geldMerken("loot")
  elseif ev == "LOOT_CLOSED" then GF.offen.loot = false; geldMerken("loot")
  elseif ev == "CHAT_MSG_MONEY" then geldMerken("loot")
  elseif ev == "QUEST_COMPLETE" then GF.offen.quest = true; geldMerken("quest")
  elseif ev == "QUEST_FINISHED" then GF.offen.quest = false; geldMerken("quest")
  elseif ev == "QUEST_TURNED_IN" then geldMerken("quest")
  elseif ev == "MERCHANT_SHOW" then GF.offen.haendler = true
  elseif ev == "MERCHANT_CLOSED" then GF.offen.haendler = false; geldMerken("haendler")
  elseif ev == "MAIL_SHOW" then GF.offen.post = true
  elseif ev == "MAIL_CLOSED" then GF.offen.post = false end
end
local function geldArt(diff)
  local jetzt = time()
  local function kurz(a, s) return geldZeit[a] and jetzt - geldZeit[a] <= (s or 3) end
  if kurz("ahpost", 5) and diff > 0 then return "ah" end
  if GF.ah and diff < 0 then return "ahkauf" end
  if GF.offen.quest or kurz("quest") then return "quest" end
  if GF.offen.loot or kurz("loot") then return diff > 0 and "loot" or "sonst" end
  if GF.offen.haendler or kurz("haendler", 1) then return diff > 0 and "haendler" or "haendlerkauf" end
  return "sonst"
end
function GF.geldBuchen()
  local jetzt = GetMoney and GetMoney() or 0
  if geldVorher == nil then geldVorher = jetzt; return end
  local diff = jetzt - geldVorher; geldVorher = jetzt
  if diff == 0 then return end
  local art = geldArt(diff)
  GoldForeverDB.geld = GoldForeverDB.geld or {}
  local c = GoldForeverDB.geld[charKey()] or {}; GoldForeverDB.geld[charKey()] = c
  local tag = date("%Y-%m-%d")
  local t = c[tag] or {}; c[tag] = t
  t[art] = (t[art] or 0) + diff
  -- nur 60 Tage aufbewahren
  local grenze = date("%Y-%m-%d", time() - 60 * 86400)
  for d in pairs(c) do if d < grenze then c[d] = nil end end
end
-- Summen fuer einen Zeitraum (Sekunden zurueck, nil = alles; "heute" = seit Mitternacht)
function GF.geldHerkunft(sekunden)
  local c = (GoldForeverDB.geld or {})[charKey()] or {}
  local ab = sekunden and date("%Y-%m-%d", time() - sekunden) or "0000"
  local s = { loot = 0, quest = 0, haendler = 0, haendlerkauf = 0, ah = 0, ahkauf = 0, sonst = 0 }
  for d, t in pairs(c) do if d >= ab then for k, v in pairs(t) do s[k] = (s[k] or 0) + v end end end
  return s
end
-- AH-Erloes beim Geld-Nehmen aus der Post erkennen
local function postGeldHaken()
  if GF.postGehakt or not TakeInboxMoney then return end
  GF.postGehakt = true
  hooksecurefunc("TakeInboxMoney", function(k)
    local ok, typ = pcall(GetInboxInvoiceInfo, k)
    if ok and typ == "seller" then geldMerken("ahpost") end
  end)
  if AutoLootMailItem then hooksecurefunc("AutoLootMailItem", function(k)
    local ok, typ = pcall(GetInboxInvoiceInfo, k)
    if ok and typ == "seller" then geldMerken("ahpost") end
  end) end
end

-- ---------------------------------------------------------------- Bank-Knoepfe (2.53, Wunsch Alex)
-- An der offenen Bank: Halten-Ware (blau) in die Bank / wieder heraus, Verkaufen-Ware (gruen) aus der Bank in die Tasche.
local TASCHEN = { 0, 1, 2, 3, 4, 5 }
local BANKFAECHER = { -1, -3, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17 }
-- Welche Art hat ein Item fuer die Bank-Knoepfe? "verk" (gruen), "halt" (blau) oder nil (nicht anfassen)
function GF.bankArt(id)
  if GF.ausgeblendet(id) then return nil end
  local i = GF.info(id); if not i then return nil end
  local e = GF.empfehlung(id, i, nil, true)
  if not e then return nil end
  if e.art == "verk" and not e.langsam then return "verk" end
  if GF.raid(id) and e.art ~= "verk" then return "halt" end
  if (e.art == "halt" and not e.still) or e.art == "kauf" or e.art == "herstellen" then return "halt" end
  return nil
end
local function slotsVon(faecher)
  local out = {}
  for _, b in ipairs(faecher) do
    local ok, n = pcall(C_Container.GetContainerNumSlots, b)
    for sl = 1, (ok and n or 0) do
      local ok2, info = pcall(C_Container.GetContainerItemInfo, b, sl)
      if ok2 and info and info.itemID and not info.isLocked then out[#out + 1] = { b = b, s = sl, id = info.itemID, gebunden = info.isBound } end
    end
  end
  return out
end
-- modus: "haltRein" (Tasche -> Bank), "haltRaus" (Bank -> Tasche), "verkRaus" (Bank -> Tasche)
function GF.bankVerschieben(modus)
  if not (GF.bankOffen and C_Container and C_Container.UseContainerItem) then
    print(GOLD .. "Gold Forever:" .. ENDE .. " Das geht nur an der offenen Bank."); return
  end
  local quelle = (modus == "haltRein") and TASCHEN or BANKFAECHER
  local will = (modus == "verkRaus") and "verk" or "halt"
  local art, n = {}, 0
  for _, x in ipairs(slotsVon(quelle)) do
    if art[x.id] == nil then art[x.id] = GF.bankArt(x.id) or false end
    if art[x.id] == will and not (modus == "haltRein" and x.gebunden and not GF.raid(x.id)) then
      local ok = pcall(C_Container.UseContainerItem, x.b, x.s)
      if ok then n = n + 1 end
    end
  end
  local was = ({ haltRein = "Halten-Ware in die Bank", haltRaus = "Halten-Ware in die Tasche", verkRaus = "Verkaufen-Ware in die Tasche" })[modus]
  print(GOLD .. "Gold Forever:" .. ENDE .. " " .. n .. (n == 1 and " Stapel " or " Stapel ") .. was .. "." .. (n == 0 and " (Nichts zu verschieben.)" or " Fehlt etwas: Tasche/Bank voll? Dann noch einmal klicken."))
  if C_Timer and GF.aktualisieren then C_Timer.After(1, function() pcall(GF.aktualisieren) end) end
  return n
end

-- ---------------------------------------------------------------- Im AH pruefen (2.53, Befund 32/33/34)
-- GF sucht Items selbst nacheinander im AH (eigene Suche, kein TSM-Suchfeld). Ergebnis landet ueber die
-- normalen Such-Ereignisse in GF.live (frisch 10 Min.). Je Item hoechstens 2,5 Sek., dann das naechste.
GF.pruef = { liste = {}, k = 0, n = 0 }
local function pruefNaechstes()
  local P = GF.pruef
  if not GF.ah then P.liste = {}; P.aktiv = false; return end
  P.k = P.k + 1
  local id = P.liste[P.k]
  if not id then
    P.liste = {}; P.aktiv = false; P.aktuell = nil
    if P.fertig then local f = P.fertig; P.fertig = nil; pcall(f) end
    GF.planNeu()
    if GF.aktualisieren then pcall(GF.aktualisieren) end
    return
  end
  P.aktiv, P.aktuell = true, id
  local ok = pcall(function()
    local key = C_AuctionHouse.MakeItemKey(id)
    local sortierung = { { sortOrder = (Enum and Enum.AuctionHouseSortOrder and Enum.AuctionHouseSortOrder.Price) or 0, reverseSort = false } }
    C_AuctionHouse.SendSearchQuery(key, sortierung, true)
  end)
  local meinK = P.k
  if C_Timer then C_Timer.After(ok and 2.5 or 0.1, function() if GF.pruef.k == meinK and GF.pruef.aktiv then pruefNaechstes() end end) end
  if GF.aktualisieren then pcall(GF.aktualisieren) end
end
function GF.pruefen(ids, fertig)
  if not (GF.ah and C_AuctionHouse and C_AuctionHouse.SendSearchQuery and C_AuctionHouse.MakeItemKey) then
    print(GOLD .. "Gold Forever:" .. ENDE .. " Im AH prüfen geht nur am offenen Auktionshaus."); return
  end
  local P, schon = GF.pruef, {}
  P.liste, P.k, P.fertig = {}, 0, fertig
  for _, id in ipairs(ids or {}) do
    id = tonumber(id)
    if id and not schon[id] then schon[id] = true; P.liste[#P.liste + 1] = id end
  end
  P.n = #P.liste
  if P.n == 0 then return end
  pruefNaechstes()
end
function GF.pruefStand() local P = GF.pruef; if P.aktiv then return math.min(P.k, P.n), P.n end end
local function pruefErgebnis(id)
  local P = GF.pruef
  if not (P.aktiv and P.aktuell == tonumber(id)) then return end
  local meinK = P.k
  if C_Timer then C_Timer.After(0.4, function() if GF.pruef.k == meinK and GF.pruef.aktiv then pruefNaechstes() end end) end
end
-- Frisch = AH-Suche in den letzten 10 Min. (auch wenn nur die eigene Auktion gefunden wurde)
function GF.frisch(id)
  local l = GF.live[tonumber(id)]
  return (l and not l.voll and time() - l.t < 600) and true or false
end

-- ---------------------------------------------------------------- Live-Preise aus AH-Suchen
local function liveCommodity(itemID)
  if not (C_AuctionHouse and C_AuctionHouse.GetCommoditySearchResultInfo) then return end
  local r = C_AuctionHouse.GetCommoditySearchResultInfo(itemID, 1)
  if r and r.unitPrice then
    local n = C_AuctionHouse.GetNumCommoditySearchResults and C_AuctionHouse.GetNumCommoditySearchResults(itemID) or nil
    -- Preisstufen merken (bis 30): wie viel Stueck gibt es zu welchem Preis? Fuer den Kaufpreis einer Menge.
    -- Eigene Angebote zaehlen nicht (2.50): sonst gilt der eigene Preis als Marktpreis (Hirschfrikadelle 17.11.)
    local st, p, eigen = {}, nil, nil
    for k = 1, math.min(n or 1, 40) do
      local x = C_AuctionHouse.GetCommoditySearchResultInfo(itemID, k)
      if x and x.unitPrice then
        local q = x.quantity or 1
        local own = math.min(q, x.numOwnerItems or (x.containsOwnerItem and q or 0))
        if own > 0 and not eigen then eigen = x.unitPrice end
        if q - own > 0 then p = p or x.unitPrice; if #st < 30 then st[#st + 1] = { p = x.unitPrice, q = q - own } end end
      end
    end
    GF.live[itemID] = { p = p, n = n, t = time(), st = st, eigen = eigen, rohstoff = true }
    GF.planNeu()
    if GF.aktualisieren then pcall(GF.aktualisieren) end
  end
end
-- ---------------------------------------------------------------- Scans mitschreiben (fuer die Auswertung)
-- GoldForeverDB.scans = { {t, id, p (guenstigster Stueckpreis), q (Stueck gesamt), s (Preisstufen),
--   q5 (Stueck bis +5 % ueber guenstigstem), o (Verkaeufer, nur Einzel-Items)} } – je Item hoechstens alle 10 Min.
local function scanMerken(id, p, q, s, q5, o)
  if not (id and p) then return end
  GoldForeverDB.scans = GoldForeverDB.scans or {}
  local L = GoldForeverDB.scans
  for k = #L, math.max(1, #L - 200), -1 do
    if L[k].id == id and time() - L[k].t < 600 then return end
  end
  L[#L + 1] = { t = time(), id = id, p = p, q = q, s = s, q5 = q5, o = o }
  while #L > 4000 do table.remove(L, 1) end
end
local function scanCommodity(itemID)
  local n = C_AuctionHouse.GetNumCommoditySearchResults and C_AuctionHouse.GetNumCommoditySearchResults(itemID) or 0
  local q, q5, p = 0, 0, nil
  for k = 1, n do
    local r = C_AuctionHouse.GetCommoditySearchResultInfo(itemID, k)
    if r and r.unitPrice then
      p = p or r.unitPrice; q = q + (r.quantity or 0)
      if r.unitPrice <= p * 1.05 then q5 = q5 + (r.quantity or 0) end
    end
  end
  scanMerken(itemID, p, q, n, q5, nil)
end
local function scanItem(itemKey)
  local n = C_AuctionHouse.GetNumItemSearchResults and C_AuctionHouse.GetNumItemSearchResults(itemKey) or 0
  local q, q5, p, owner = 0, 0, nil, {}
  for k = 1, n do
    local r = C_AuctionHouse.GetItemSearchResultInfo(itemKey, k)
    local b = r and r.buyoutAmount
    if b then
      local stk = math.max(1, r.quantity or 1)
      local unit = b
      p = p or unit; q = q + stk
      if unit <= p * 1.05 then q5 = q5 + stk end
      for _, o in ipairs(r.owners or {}) do owner[o] = true end
    end
  end
  local no = 0; for _ in pairs(owner) do no = no + 1 end
  scanMerken(itemKey.itemID, p, q, n, q5, no > 0 and no or nil)
end

-- Vollscan (offizieller Ein-Klick-Scan des Auktionshauses, alle 15 Min. moeglich)
-- GoldForeverDB.vollscan = { {t, n (Auktionen), items = {[id] = {q, a, m (guenstigster Stueckpreis), o (Verkaeufer)}}} } – die letzten 5
local vollOffen = false
local vollWache = nil
-- 2.52 (Befund 27): Blizzard erlaubt den Vollscan nur alle 15 Min. (fuer alle Addons zusammen, auch TSM/Auctionator)
-- und macht in der Abklingzeit still nichts. Darum: Abklingzeit selbst merken und nach 90 Sek. ohne Ergebnis melden.
function GF.vollscanBereitAb()
  local t = GoldForeverDB.vollscanZeit
  if t and time() - t < 900 then return t + 900 end
  return nil
end
function GF.vollscanStarten()
  if not (C_AuctionHouse and C_AuctionHouse.ReplicateItems) then print(GOLD .. "Gold Forever:" .. ENDE .. " Vollscan geht nur am offenen Auktionshaus."); return end
  local ab = GF.vollscanBereitAb()
  if ab then
    print(GOLD .. "Gold Forever:" .. ENDE .. " Vollscan erst wieder ab " .. date("%H:%M", ab) .. " möglich (Blizzard erlaubt ihn nur alle 15 Min.).")
    return
  end
  vollOffen = true
  local ok = pcall(C_AuctionHouse.ReplicateItems)
  if not ok then print(GOLD .. "Gold Forever:" .. ENDE .. " Vollscan nicht möglich – Auktionshaus offen?"); return end
  print(GOLD .. "Gold Forever:" .. ENDE .. " Vollscan läuft – Auktionshaus offen lassen, bis „gespeichert“ kommt (meist 10–60 Sek.).")
  if C_Timer then
    if vollWache then vollWache:Cancel() end
    local start = time()
    vollWache = C_Timer.NewTimer(90, function()
      vollWache = nil
      if not GoldForeverDB.vollscanZeit or GoldForeverDB.vollscanZeit < start then
        GoldForeverDB.vollscanZeit = start -- Abklingzeit laeuft vermutlich trotzdem
        print(GOLD .. "Gold Forever:" .. ENDE .. " Vollscan ohne Ergebnis. Meist läuft noch die Abklingzeit (15 Min., auch durch TSM/Auctionator) oder das Auktionshaus wurde geschlossen. Nächster Versuch ab " .. date("%H:%M", start + 900) .. ".")
      end
    end)
  end
end
-- Lesen in Portionen (sonst friert das Spiel bei zehntausenden Auktionen ein) und nur einmal je Scan:
-- REPLICATE_ITEM_LIST_UPDATE kommt mehrfach – erst 3 Sek. nach dem letzten Ereignis starten.
local vollLauf, vollTimer = nil, nil
local function vollscanAuswerten()
  if vollLauf then return end
  if not (C_AuctionHouse.GetNumReplicateItems and C_AuctionHouse.GetReplicateItemInfo) then return end
  local n = C_AuctionHouse.GetNumReplicateItems() or 0
  if n == 0 then return end
  -- denselben Scan nicht doppelt speichern (das Ereignis kommt manchmal nach dem Auswerten noch einmal)
  local letzte = (GoldForeverDB.vollscan or {})[#(GoldForeverDB.vollscan or {})]
  if letzte and letzte.n == n and time() - letzte.t < 300 then return end
  GoldForeverDB.vollscanZeit = time()
  local scan = { t = time(), n = n, items = {} }
  local owners = {}
  -- fuer Kauf-Vorschlaege: Preisstufen der Items aus der Datendatei, Raid-Liste und eigenen Positionen
  local rel, stufen = {}, {}
  for id in pairs(GF.alleIds()) do rel[tonumber(id) or id] = true end
  for id in pairs(D().raid or {}) do rel[tonumber(id) or id] = true end
  vollLauf = { k = 0 }
  local function portion()
    local bis = math.min(n - 1, vollLauf.k + 1500)
    for k = vollLauf.k, bis do
      -- Rueckgabe: name, texture, count, qualityID, usable, level, levelType, minBid, minIncrement,
      --           buyoutPrice, bidAmount, highBidder, bidderFullName, owner, ownerFullName, saleStatus, itemID, hasAllInfo
      local ok, _, _, count, _, _, _, _, _, _, buyout, _, _, _, owner, _, _, itemID, alles = pcall(C_AuctionHouse.GetReplicateItemInfo, k)
      if ok and (not itemID or alles == false) then vollLauf.unvoll = (vollLauf.unvoll or 0) + 1 end
      if ok and itemID then
        local x = scan.items[itemID] or { q = 0, a = 0 }
        local c = math.max(1, count or 1)
        x.q = x.q + c; x.a = x.a + 1
        if buyout and buyout > 0 then
          local u = math.floor(buyout / c); if not x.m or u < x.m then x.m = u end
          if rel[itemID] then local l = stufen[itemID] or {}; l[#l + 1] = { p = u, q = c }; stufen[itemID] = l end
        end
        if owner then owners[itemID] = owners[itemID] or {}; owners[itemID][owner] = true end
        scan.items[itemID] = x
      end
    end
    vollLauf.k = bis + 1
    if vollLauf.k < n then C_Timer.After(0.05, portion); return end
    -- 2.53 (Befund 34): Daten noch unvollstaendig (WoW laedt nach) -> nicht speichern, kurz warten, neu lesen
    if (vollLauf.unvoll or 0) > n * 0.02 and (GF.vollVersuche or 0) < 4 then
      GF.vollVersuche = (GF.vollVersuche or 0) + 1
      vollLauf = nil
      print(GOLD .. "Gold Forever:" .. ENDE .. " Vollscan lädt noch nach – kurz warten …")
      C_Timer.After(4, function() pcall(vollscanAuswerten) end)
      return
    end
    GF.vollVersuche = 0
    for id, os in pairs(owners) do local c = 0; for _ in pairs(os) do c = c + 1 end; if scan.items[id] then scan.items[id].o = c end end
    -- nur die letzten 2 Vollscans behalten (300.000 Auktionen = sonst sehr grosse SavedVariables);
    -- fehlerhafte Scans aus 2.28 (nur 1 Item) werfen
    local alt = GoldForeverDB.vollscan or {}
    local neu = {}
    for _, v in ipairs(alt) do local c = 0; for _ in pairs(v.items or {}) do c = c + 1; if c > 1 then break end end; if c > 1 then neu[#neu + 1] = v end end
    neu[#neu + 1] = scan
    while #neu > 2 do table.remove(neu, 1) end
    GoldForeverDB.vollscan = neu
    local m = 0; for _ in pairs(scan.items) do m = m + 1 end
    vollLauf = nil
    -- Live-Preise setzen (ausser frische eigene Suche < 10 Min.), dann Einkaufsplan neu rechnen
    local gesetzt, neuRealm = 0, 0
    for id, l in pairs(stufen) do
      if not GF.livePreis(id, true) then
        table.sort(l, function(a, b) return a.p < b.p end)
        local st = {}
        for _, x in ipairs(l) do
          local letzte = st[#st]
          if letzte and letzte.p == x.p then letzte.q = letzte.q + x.q elseif #st < 30 then st[#st + 1] = { p = x.p, q = x.q } else break end
        end
        GF.live[id] = { p = l[1].p, n = #l, t = time(), st = st, voll = true }
        gesetzt = gesetzt + 1
        if GF.alleIds()[id] == "realm" then neuRealm = neuRealm + 1 end
      end
    end
    GF.planNeu()
    local vorschlaege = 0
    if GF.ah then
      GF.ah.plan = GF.budgetPlan()
      for _, d in ipairs(GF.ah.plan.deals) do GF.ah.start[d.id] = GF.ah.start[d.id] or GF.anzahl(d.id) end
      vorschlaege = #GF.ah.plan.deals
    else vorschlaege = #GF.budgetPlan().deals end
    print(GOLD .. "Gold Forever:" .. ENDE .. " Vollscan gespeichert: " .. n .. " Auktionen, " .. m .. " verschiedene Items. " ..
      gesetzt .. " Preise übernommen" .. (neuRealm > 0 and (" (davon " .. neuRealm .. " neu aus den Realm-Daten)") or "") .. " – " .. vorschlaege .. " Kauf-Vorschläge. Kandidaten werden jetzt im AH geprüft …")
    -- 2.55 (Befund 42): Gruende festhalten und kurz nennen
    do
      local ok, liste, gr = pcall(GF.kaufDiagnose)
      if ok and liste and #liste > 0 then
        local teile = {}; for k = 1, math.min(3, #gr) do teile[#teile + 1] = gr[k].g .. " " .. gr[k].n end
        print(GRAU .. "  Nicht gekauft (" .. #liste .. " unter üblich): " .. table.concat(teile, " · ") .. " – Details: „Warum nicht?“ unter Kaufen" .. ENDE)
      end
    end
    -- 2.53 (Befund 34): Kauf-Kandidaten aus dem Vollscan sofort gezielt im AH pruefen
    if GF.ah and GF.pruefen then
      local ids = {}
      for id, l in pairs(GF.live) do
        if l.voll then
          local i = GF.info(id); local R = i and GF.referenz(id, i)
          if R and i.p and i.p <= R * 0.9 and not GF.ausgeblendet(id) then ids[#ids + 1] = id end
        end
      end
      table.sort(ids, function(a, b) return a < b end)
      while #ids > 25 do table.remove(ids) end
      if #ids > 0 then pcall(GF.pruefen, ids) end
    end
    if GF.aktualisieren then pcall(GF.aktualisieren) end
  end
  portion()
end
local function vollscanLesen()
  if not C_Timer then return end
  if vollTimer then vollTimer:Cancel() end
  vollTimer = C_Timer.NewTimer(3, function() vollTimer = nil; pcall(vollscanAuswerten) end)
end

-- Scan-Auftrag (Testphase): Items, deren Mengen/Verkaeufer Claude gezielt sehen will
GF.AUFTRAG = {
  titel = "Kräuter, Erze, Stoffe",
  ids = { 2453, 3355, 3356, 2452, 3821, 765, 2447, 2449, 2450, 13464, 8836, 3358, 13463, 8838,
    2772, 2770, 11370, 3858, 10620, 2589, 2592, 4306, 4338, 249399 },
}
function GF.auftragStand()
  local heute = time() - (tonumber(date("%H")) * 3600 + tonumber(date("%M")) * 60)
  local da = {}
  for _, x in ipairs(GoldForeverDB.scans or {}) do if x.t >= heute then da[x.id] = true end end
  local n = 0; for _, id in ipairs(GF.AUFTRAG.ids) do if da[id] then n = n + 1 end end
  return n, #GF.AUFTRAG.ids
end
function GF.auftragSuche()
  local t = {}
  for _, id in ipairs(GF.AUFTRAG.ids) do
    local name = ((C_Item and C_Item.GetItemInfo or GetItemInfo)(id)) or ((D().items or {})[id] or {})[1]
    if name then t[#t + 1] = name end
  end
  return table.concat(t, ";"), #t
end

local function liveItem(itemKey)
  if not (itemKey and C_AuctionHouse and C_AuctionHouse.GetItemSearchResultInfo) then return end
  local r = C_AuctionHouse.GetItemSearchResultInfo(itemKey, 1)
  local preis = r and (r.buyoutAmount or r.bidAmount)
  if preis and itemKey.itemID then
    -- eigene Auktionen nicht als Marktpreis zaehlen (2.50)
    local st, p, eigen = {}, nil, nil
    local n = C_AuctionHouse.GetNumItemSearchResults and C_AuctionHouse.GetNumItemSearchResults(itemKey) or 1
    for k = 1, math.min(n, 40) do
      local x = C_AuctionHouse.GetItemSearchResultInfo(itemKey, k)
      local b = x and (x.buyoutAmount or x.bidAmount)
      if b then
        if x.containsOwnerItem then eigen = eigen or b
        else p = p or b; if x.buyoutAmount and #st < 30 then st[#st + 1] = { p = x.buyoutAmount, q = x.quantity or 1 } end end
      end
    end
    GF.live[itemKey.itemID] = { p = p, t = time(), st = st, eigen = eigen }
    GF.planNeu()
    if GF.aktualisieren then pcall(GF.aktualisieren) end
  end
end

-- ---------------------------------------------------------------- Ziel-Meldung fuer gekaufte Ware
-- Sobald eine Position von "halten" auf "jetzt einstellen" springt: einmal im Chat + Bildschirm + Ton.
-- Geprueft beim Einloggen/Reload, alle 5 Minuten und nach jeder AH-Suche (Live-Preis).
function GF.zieleCheck()
  GoldForeverDB.zielGemeldet = GoldForeverDB.zielGemeldet or {}
  local gem = GoldForeverDB.zielGemeldet
  local offen = {}
  for _, p in ipairs(GF.positionen()) do
    offen[p.id] = true
    local i = GF.info(p.id)
    if i and i.p then GF.posMessung(p.id, i.p - 1) end
    local pl = GF.verkaufsPlan(p)
    -- 2.55.1: Verlust-Warnung im Chat erst, wenn sie im Tageshoch 90 Min. bestehen bleibt (Raid-Ware/Absturz sofort)
    if pl and pl.stop and pl.seit and time() - pl.seit < 5400 and (1 - (pl.preis or 0) * 0.95 / math.max(1, p.ek)) < 0.5 and not p.raid then pl = nil end
    if pl and pl.art == "verk" then
      local art = pl.stop and "stop" or "ziel"
      if gem[p.id] ~= art and not (type(gem[p.id]) == "number" and art == "ziel") then
        gem[p.id] = art
        local _, link = (C_Item and C_Item.GetItemInfo or GetItemInfo)(p.id)
        local name = (link or (p.i and p.i.n) or "Item")
        if pl.stop then
          print(GOLD .. "Gold Forever:" .. ENDE .. " |cfffb923cAchtung|r " .. name .. " |cfffb923c" .. pl.lang .. ENDE .. GRAU .. "  ·  " .. p.n .. " Stück" .. ENDE)
          if RaidNotice_AddMessage and RaidWarningFrame then
            pcall(RaidNotice_AddMessage, RaidWarningFrame, "Gold Forever: " .. ((p.i and p.i.n) or "Item") .. " fällt – lieber jetzt verkaufen", { r = 0.98, g = 0.57, b = 0.24 })
          end
          if PlaySound then pcall(PlaySound, 8959) end
        else
          local gewinn = math.floor(((pl.preis or p.ziel) * 0.95 - p.ek) * p.n)
          print(GOLD .. "Gold Forever:" .. ENDE .. " " .. HAKEN .. " " .. name .. " " ..
            GRUEN .. pl.lang .. ENDE .. GRAU .. "  ·  " .. p.n .. " Stück, Gewinn ca. " .. ENDE .. GRUEN .. "+" .. GF.geld(gewinn) .. ENDE)
          if RaidNotice_AddMessage and RaidWarningFrame then
            pcall(RaidNotice_AddMessage, RaidWarningFrame, "Gold Forever: " .. ((p.i and p.i.n) or "Item") .. " – Ziel erreicht, jetzt verkaufen", { r = 0.29, g = 0.87, b = 0.5 })
          end
          if PlaySound then pcall(PlaySound, 8960) end
        end
      end
    elseif gem[p.id] then
      gem[p.id] = nil -- Preis wieder unter Ziel: beim naechsten Erreichen erneut melden
    end
  end
  for id in pairs(gem) do if not offen[id] then gem[id] = nil end end
end

-- ---------------------------------------------------------------- Haendlerware merken
-- Beim Haendlerbesuch alle Waren mit unbegrenztem Vorrat speichern: {[itemID] = Stueckpreis}.
-- Solche Items schlaegt Gold Forever nie zum Verkaufen vor (teurer als beim Haendler kauft niemand).
-- Waren mit begrenztem Vorrat (seltene Rezepte o. ae.) bleiben handelbar.
local function haendlerMerken()
  if not (GetMerchantNumItems and GetMerchantItemInfo and GetMerchantItemID) then return end
  GoldForeverDB.haendler = GoldForeverDB.haendler or {}
  local neu = 0
  for k = 1, GetMerchantNumItems() do
    local _, _, preis, menge, vorrat, _, _, extra = GetMerchantItemInfo(k)
    local id = GetMerchantItemID(k)
    if id and preis and preis > 0 and (vorrat == nil or vorrat < 0) and not extra then
      local stk = math.floor(preis / math.max(1, menge or 1))
      if GoldForeverDB.haendler[id] ~= stk then neu = neu + 1 end
      GoldForeverDB.haendler[id] = stk
    end
  end
  if neu > 0 then
    if GF.punkteAktualisieren then pcall(GF.punkteAktualisieren) end
    if GF.aktualisieren then pcall(GF.aktualisieren) end
  end
end

-- ---------------------------------------------------------------- Start
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("CHAT_MSG_LOOT")
f:RegisterEvent("PLAYER_MONEY")
f:RegisterEvent("AUCTION_HOUSE_SHOW")
f:RegisterEvent("AUCTION_HOUSE_CLOSED")
f:RegisterEvent("BAG_UPDATE_DELAYED")
f:RegisterEvent("BANKFRAME_OPENED")
f:RegisterEvent("BANKFRAME_CLOSED")
f:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
pcall(f.RegisterEvent, f, "PLAYERREAGENTBANKSLOTS_CHANGED")
f:RegisterEvent("COMMODITY_PURCHASE_SUCCEEDED")
f:RegisterEvent("COMMODITY_PURCHASE_FAILED")
f:RegisterEvent("AUCTION_HOUSE_PURCHASE_COMPLETED")
f:RegisterEvent("MAIL_INBOX_UPDATE")
pcall(f.RegisterEvent, f, "COMMODITY_PRICE_UPDATED")
pcall(f.RegisterEvent, f, "OWNED_AUCTIONS_UPDATED")
f:RegisterEvent("COMMODITY_SEARCH_RESULTS_UPDATED")
f:RegisterEvent("ITEM_SEARCH_RESULTS_UPDATED")
pcall(f.RegisterEvent, f, "REPLICATE_ITEM_LIST_UPDATE")
f:RegisterEvent("MERCHANT_SHOW")
pcall(f.RegisterEvent, f, "MERCHANT_UPDATE")
for _, e in ipairs({ "TRADE_SKILL_SHOW", "TRADE_SKILL_CLOSE", "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_DATA_SOURCE_CHANGED", "LOOT_OPENED", "LOOT_READY", "LOOT_CLOSED",
  "CHAT_MSG_MONEY", "QUEST_COMPLETE", "QUEST_TURNED_IN", "QUEST_FINISHED", "MERCHANT_CLOSED", "MAIL_SHOW", "MAIL_CLOSED" }) do pcall(f.RegisterEvent, f, e) end
f:SetScript("OnEvent", function(_, ev, ...)
  if ev == "TRADE_SKILL_SHOW" then pcall(GF.herstellenListe); pcall(GF.berufAuf) end
  if ev == "TRADE_SKILL_CLOSE" then pcall(GF.herstellenPruefen); pcall(GF.berufZu); return end
  if ev == "TRADE_SKILL_SHOW" or ev == "TRADE_SKILL_LIST_UPDATE" or ev == "TRADE_SKILL_DATA_SOURCE_CHANGED" then pcall(GF.rezepteLesenSpaeter); return end
  if ev == "LOOT_OPENED" or ev == "LOOT_READY" or ev == "LOOT_CLOSED" or ev == "CHAT_MSG_MONEY" or ev == "QUEST_COMPLETE" or ev == "QUEST_TURNED_IN"
    or ev == "QUEST_FINISHED" or ev == "MERCHANT_SHOW" or ev == "MERCHANT_CLOSED" or ev == "MAIL_SHOW" or ev == "MAIL_CLOSED" then
    pcall(GF.geldKontext, ev)
    if ev == "MAIL_SHOW" then pcall(postGeldHaken) end
    if ev ~= "MERCHANT_SHOW" then return end
  end
  if ev == "MERCHANT_SHOW" or ev == "MERCHANT_UPDATE" then
    if C_Timer then C_Timer.After(0.5, function() pcall(haendlerMerken) end) else pcall(haendlerMerken) end
    return
  end
  if ev == "PLAYER_MONEY" then tagPruefen(); pcall(GF.geldBuchen); return end
  if ev == "AUCTION_HOUSE_SHOW" then
    pcall(kaufHaken); pcall(ahAuf)
    if C_Timer and C_AuctionHouse and C_AuctionHouse.QueryOwnedAuctions then C_Timer.After(1, function() pcall(C_AuctionHouse.QueryOwnedAuctions, {}) end) end
    return
  end
  if ev == "COMMODITY_PURCHASE_SUCCEEDED" or ev == "AUCTION_HOUSE_PURCHASE_COMPLETED" then
    if C_Timer then C_Timer.After(0.5, function() pcall(kaufAbschliessen) end) else pcall(kaufAbschliessen) end
    return
  end
  if ev == "COMMODITY_PURCHASE_FAILED" then offen = nil; return end
  if ev == "MAIL_INBOX_UPDATE" then pcall(postLesen); return end
  if ev == "COMMODITY_PRICE_UPDATED" then pcall(GF.kaufPreisDa, ...); return end
  if ev == "OWNED_AUCTIONS_UPDATED" then pcall(eigeneAuktionen); return end
  if ev == "COMMODITY_SEARCH_RESULTS_UPDATED" then pcall(liveCommodity, ...); pcall(scanCommodity, ...); pcall(GF.zieleCheck); pcall(pruefErgebnis, ...); return end
  if ev == "ITEM_SEARCH_RESULTS_UPDATED" then
    pcall(liveItem, ...); pcall(scanItem, ...); pcall(GF.zieleCheck)
    local key = ...; pcall(pruefErgebnis, type(key) == "table" and key.itemID or key); return
  end
  if ev == "REPLICATE_ITEM_LIST_UPDATE" then pcall(vollscanLesen); return end
  if ev == "AUCTION_HOUSE_CLOSED" then pcall(ahZu); return end
  if ev == "BAG_UPDATE_DELAYED" then taschenHaken(); if GF.bankOffen then pcall(GF.punkteAktualisieren) end; if GF.berufOffen then pcall(GF.herstellenPruefen) end; return end
  if ev == "BANKFRAME_OPENED" then
    if C_Timer then C_Timer.After(1, function() pcall(GF.bankMerken) end) else pcall(GF.bankMerken) end
    GF.bankOffen = true
    if GF.aktualisieren then pcall(GF.aktualisieren) end
    -- kurz warten, bis das Bankfenster seine Knoepfe gebaut hat
    if C_Timer then C_Timer.After(0.3, function() pcall(GF.punkteAktualisieren) end); C_Timer.After(1, function() pcall(GF.punkteAktualisieren) end)
    else pcall(GF.punkteAktualisieren) end
    return
  end
  if ev == "BANKFRAME_CLOSED" then GF.bankOffen = false; if GF.aktualisieren then pcall(GF.aktualisieren) end; return end
  if ev == "PLAYERBANKSLOTS_CHANGED" or ev == "PLAYERREAGENTBANKSLOTS_CHANGED" then pcall(GF.bankMerken); pcall(GF.punkteAktualisieren); return end
  if ev == "PLAYER_LOGIN" then
    hookTooltips(); tagPruefen(); pcall(taschenHaken); pcall(kaufHaken); B(); pcall(GF.geldBuchen)
    if C_Timer then
      C_Timer.After(8, function() pcall(GF.zieleCheck) end)
      if C_Timer.NewTicker then C_Timer.NewTicker(300, function() pcall(GF.zieleCheck) end) end
    end
    local d = D()
    local alter = d.stand and math.floor((time() - d.stand) / 3600) or nil
    print(GOLD .. "Gold Forever" .. ENDE .. " geladen – " .. GRAU .. "/gf öffnet das Fenster" .. ENDE ..
      (alter and (GRAU .. " · Daten von vor " .. alter .. " Std." .. ENDE) or (GRAU .. " · noch keine Datendatei" .. ENDE)) ..
      ((TSM_API and (GRAU .. " · TSM-Preise live" .. ENDE)) or ""))
  elseif ev == "CHAT_MSG_LOOT" then
    local msg = ...
    local guid = select(12, ...)
    -- kurz warten, bis die Beute in der Tasche ist (Tooltip zaehlt sie dann auch)
    if C_Timer then C_Timer.After(1, function() pcall(lootHinweis, msg, guid) end) else pcall(lootHinweis, msg, guid) end
  end
end)

SLASH_GOLDFOREVER1 = "/gf"
SLASH_GOLDFOREVER2 = "/goldforever"
SlashCmdList.GOLDFOREVER = function(arg)
  arg = string.lower(arg or "")
  if arg == "einblenden" then GF.alleEinblenden(); return end
  if arg == "warum" then GF.kaufDiagnoseChat(); return end
  if arg == "loot" then
    GoldForeverDB.loot = GoldForeverDB.loot == false
    print(GOLD .. "Gold Forever:" .. ENDE .. " Loot-Hinweise " .. (GoldForeverDB.loot == false and "aus" or "an"))
  elseif arg == "punkte" then
    GoldForeverDB.punkte = GoldForeverDB.punkte == false
    print(GOLD .. "Gold Forever:" .. ENDE .. " Farbmarken in den Taschen " .. (GoldForeverDB.punkte == false and "aus" or "an"))
    pcall(GF.punkteAktualisieren)
  elseif arg == "tooltip" then
    GoldForeverDB.tooltip = GoldForeverDB.tooltip == false
    print(GOLD .. "Gold Forever:" .. ENDE .. " Tooltip-Zeilen " .. (GoldForeverDB.tooltip == false and "aus" or "an"))
  elseif string.match(arg, "^reset") then
    local t = { di = 2, mi = 3, ["do"] = 4 }
    local v = t[string.sub(arg, 7, 8)]
    if v then GoldForeverDB.reset = v; print(GOLD .. "Gold Forever:" .. ENDE .. " Raid-Reset = " .. WT[v + 1]) else print("Beispiel: /gf reset mi") end
  else
    if GoldForever_Toggle then GoldForever_Toggle() end
  end
end
