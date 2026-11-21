dofile("/home/claude/test/t20.lua")
local GF = GoldForever
local S = GF.sniper
GT = 1000; GetTime = function() return GT end
local B = GoldForeverSniperKnopf
local function klick(down) B._scripts.OnClick(B, "LeftButton", down) end
KAEUFE = {}
C_AuctionHouse.StartCommoditiesPurchase = function(id, n) KAEUFE[#KAEUFE + 1] = "start" .. n end
C_AuctionHouse.ConfirmCommoditiesPurchase = function(id, n) KAEUFE[#KAEUFE + 1] = "ok" .. n end
local function treffer(rk) GF.kaufLauf = nil; S.sperreBis = nil
  S.treffer = { id = 5631, n = 5, max = 40, neu = 69, gewinn = 100, kosten = 200, R = 60, Rv = 60, abw = 30, t = time(), risiko = rk, zeigGT = GT } end
-- 1) gruen: druecken -> Preis kommt -> loslassen = gekauft (1 Druck)
treffer("sicher"); KAEUFE = {}
GT = GT + 0.2; klick(true); zeige("zu früh (0,2 s nach Anzeige): " .. #KAEUFE)
GT = GT + 0.3; klick(true); GF.kaufPreisDa(40, 200); GT = GT + 0.15; klick(false)
zeige("Grün halten: " .. table.concat(KAEUFE, ",") .. " rz " .. tostring(S.ausstehend and S.ausstehend.t.rz))
-- 2) loslassen bevor der Preis da ist -> nichts, 2. Druck bestaetigt
treffer("ok"); KAEUFE = {}
GT = GT + 1; klick(true); klick(false); GF.kaufPreisDa(40, 200)
zeige("Blau zu kurz: " .. table.concat(KAEUFE, ","))
klick(true); zeige("Blau 2. Druck: " .. table.concat(KAEUFE, ","))
-- 3) orange: loslassen bestaetigt nie
treffer("risiko"); KAEUFE = {}
GT = GT + 1; klick(true); GF.kaufPreisDa(40, 200); GT = GT + 0.2; klick(false)
zeige("Orange halten: " .. table.concat(KAEUFE, ","))
GT = GT + 1.2; klick(true); zeige("Orange 2. Druck: " .. table.concat(KAEUFE, ","))
-- 4) Sperre nach Kauf: Mausrad dreht weiter, neuer Treffer
treffer("sicher"); S.sperreBis = GT + 0.6; KAEUFE = {}
klick(true); zeige("Sperre nach Kauf: " .. #KAEUFE)
-- 5) teurer -> Rest-Suche
treffer("sicher"); KAEUFE = {}; S.an = true; S.queue = {}
GT = GT + 1; klick(true); GF.kaufPreisDa(55, 275)
local lg = GoldForeverDB.sniper.log[#GoldForeverDB.sniper.log]
zeige("teurer: aus " .. lg.aus .. " zs " .. tostring(lg.zs) .. " zp " .. tostring(lg.zp) .. " Queue[1] " .. tostring(S.queue[1]) .. " rest " .. tostring(S.rest and S.rest[5631] ~= nil))
GF.live[5631] = { t = JETZT, p = 30, st = { { p = 30, q = 30 }, { p = 60, q = 50 } } }
GoldForeverDB.einzelItem[5631] = nil; S.hits = { [5631] = { time(), time(), time() } }
S.suche = 5631; S.treffer = nil; GF.sniperErgebnis(5631)
zeige("Rest-Treffer: " .. tostring(S.treffer and S.treffer.n) .. " rest " .. tostring(S.treffer and S.treffer.rest) .. " grund " .. tostring(S.letzterGrund))
zeige("Ende 2.66 ok")
