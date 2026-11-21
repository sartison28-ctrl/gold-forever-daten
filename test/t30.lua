dofile("/home/claude/test/t29.lua")
local GF = GoldForever
local ID = 8170
NAMEN[ID] = "Unverwüstliches Leder"
local ich = GF.charKey()
GoldForeverDB.bilanz.buch[#GoldForeverDB.bilanz.buch + 1] = { t = time() - 3000, art = "kauf", id = ID, n = 30, betrag = -39600, v = true, char = ich, sn = true }
ANZAHL[ID] = 4
GoldForeverDB.imAHc[ich] = { t = time() - 60, items = {}, verkauft = { [ID] = 26 }, vpreis = { [ID] = 1898 } }
local u, je = GF.goldUnterwegs()
zeige("unterwegs: " .. u .. " je " .. tostring(je[ID]))
local p = GF.position(ID)
zeige("Position n " .. p.n .. " da " .. p.da .. " verkauftPost " .. tostring(p.verkauftPost))
GF.ah = nil
local d = GF.standardDaten()
for nm2, l in pairs(d) do if type(l) == "table" then for _, e in ipairs(l) do if type(e) == "table" and e.id == ID then zeige("Liste " .. nm2 .. ": " .. tostring(e.n) .. "× wert " .. tostring(e.wert)) end end end end
for _, e in ipairs(d.ahL) do if e.id == ID then zeige("AH-Zeile: " .. e.n .. "× wert " .. tostring(e.wert) .. " " .. tostring(e.zeile2):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end end
local h = GF.wareIchTeile()
zeige("Ware halten " .. h)
-- abgeholt: Verkauf gebucht nach dem Stand der AH-Liste
GoldForeverDB.bilanz.buch[#GoldForeverDB.bilanz.buch + 1] = { t = time(), art = "verk", id = ID, n = 26, betrag = 46882, char = ich }
local u2 = GF.goldUnterwegs()
zeige("nach Abholen unterwegs " .. u2)
zeige("Ende 2.72 ok")
