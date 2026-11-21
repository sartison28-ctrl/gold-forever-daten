dofile("/home/claude/test/t13.lua")
local GF = GoldForever
-- Position Dolche: 66 Makelloses Leder (6000) aus t5 vorhanden? eigene neue: 9100 Golderz
table.insert(GoldForeverDB.bilanz.buch, { t = JETZT - 3600, art = "kauf", id = 9100, n = 26, betrag = -26 * 809, v = true, ziel = 999, char = "Dolche" })
SlashCmdList.GOLDFOREVER("bank Ser Swarley")
zeige("Bank: " .. tostring(GoldForeverDB.bankChar))
-- Post: 26 Golderz an Ser Swarley
table.insert(GoldForeverDB.bilanz.buch, { t = JETZT, art = "umzug", id = 9100, n = 20, betrag = 0, von = "Dolche", an = "Ser Swarley", char = "Dolche" })
local gesehen = {}
-- Positionen inkl. fremder Charaktere: GF.positionen liefert nur eigene; Swarley-Sicht simulieren
UnitName = function() return "Ser Swarley" end
JETZT = JETZT + 1
ANZAHL[9100] = 20
for _, p in ipairs(GF.positionen()) do if p.id == 9100 then zeige("Swarley-Position: " .. p.n .. " ek " .. p.ek .. " ziel " .. p.ziel .. " char " .. p.char) ; gesehen.s = p end end
UnitName = function() return "Dolche" end
JETZT = JETZT + 1
ANZAHL[9100] = 6
for _, p in ipairs(GF.positionen()) do if p.id == 9100 then zeige("Dolche-Position: " .. p.n .. " ek " .. p.ek); gesehen.d = p end end
assert(gesehen.s and gesehen.s.n == 20 and gesehen.s.ek == 809)
assert(gesehen.d and gesehen.d.n == 6)
zeige("Ende 2.59 ok")
