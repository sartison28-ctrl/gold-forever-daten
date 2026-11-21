dofile("/home/claude/test/t23.lua")
local GF = GoldForever
local S = GF.sniper
GF.kaufLauf = nil; S.sperreBis = nil
S.treffer = { id = 5631, n = 5, max = 40, neu = 69, gewinn = 100, kosten = 200, R = 60, t = time(), risiko = "ok", zeigGT = 0 }
GoldForeverSniperKnopf._scripts.OnClick(GoldForeverSniperKnopf, "RightButton", false)
zeige("Rechtsklick: Treffer weg " .. tostring(S.treffer == nil) .. " log " .. GoldForeverDB.sniper.log[#GoldForeverDB.sniper.log].aus)
zeige("Ende 2.66.2 ok")
