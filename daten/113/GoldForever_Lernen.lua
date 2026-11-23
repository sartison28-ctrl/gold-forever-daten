-- Gold Forever Lern-Datei (Wochenanalyse, Claude) – stand = Zeitpunkt der Analyse (UTC). Nicht von Hand bearbeiten.
-- kaufH/verkH = billigstes/teuerstes 4-Std.-Fenster je Item (GitHub-Stundendaten 15.–23.11., p10 je Stunde relativ zum Tagesmedian, Ortszeit).
-- Quelle: claude/wochenanalyse-2026-11-23.md + Investment Alex 23.11. (Instabiler Ausloeser). Gilt bis zur naechsten Analyse (Mo 30.11.).
GoldForeverLernen = {stand = "2026-11-23T18:50Z", t = 1795459800, standText = "Mo 23.11.",
regel = {
  kauf = { minPreis = 100, minStueck = 25, minProzent = 15, minGewinn = 10000, maxStueck = 250, maxBewaehrt = 400, trend = -15 },
  trend = { m0 = 120, tr3 = 10 }, -- 2.80: Trend-Item automatisch (24 Std. >= 120 % vom 7-Tage-Median und 3-Tage-Trend >= +10 %)
  sniper = { margeFels = 10, felsSpanne = 110, felsUmsatz = 5000, spanneFisch = 125 },
},
-- s = bewaehrt | vorsicht (aus allen Geschaeften der Woche)
item = {
  [8170] = { s = "bewaehrt", g = "Leder" },        -- Unverwuestliches Leder +30g 13s, 230/230 Treffer
  [4338] = { s = "bewaehrt", g = "Stoffe" },       -- Magiestoff +4g 76s, 31/31
  [4304] = { s = "bewaehrt", g = "Leder" },        -- Dickes Leder +4g 29s, 35/35, Aufwaertstrend
  [7067] = { s = "bewaehrt", g = "Woche" },        -- Elementarerde +2g 82s, Di -> Sa
  [264085] = { s = "bewaehrt", g = "Verfügungen" }, -- Handwerksverfuegung: Instabiler Ausloeser 50s -> 82-84s
  [8167] = { s = "vorsicht" },   -- Schildkroetenschuppe (Absturz, 0/3)
  [277501] = { s = "vorsicht" }, -- Schriftrolle der Durchdringung: Grosser Frost (-65 %)
  [279982] = { s = "vorsicht" },
  [4480] = { s = "vorsicht" },
  [250069] = { s = "vorsicht" },
  [18255] = { s = "vorsicht" },  -- Runn-Tum-Knolle
  [248688] = { s = "vorsicht" }, -- Abgefangene Kiste: Textilien des Gesellen
  [13889] = { s = "vorsicht" },  -- Roher Weissschuppenlachs
  [249274] = { s = "vorsicht" }, -- Wuergerebe (faellt die ganze Woche)
  [6358] = { s = "vorsicht" },   -- Oeliges Schwarzmaul (faellt)
  [14047] = { s = "vorsicht" },  -- Runenstoff (faellt)
},
plan = {
  stand = "Analyse Mo 23.11.", kaufH = { 19, 1 }, verkH = { 10, 14 },
  items = {
    { id = 7067, g = "Woche", kauf = "Di Mi", verk = "Sa So", kp = 88, vp = 112, max = 400, kaufH = { 18, 22 }, verkH = { 23, 3 } },
    { id = 2592, g = "Woche", kauf = "Di Mi Do", verk = "Fr", kp = 85, vp = 110, max = 250, kaufH = { 23, 3 }, verkH = { 13, 17 } },
    { id = 2319, g = "Woche", trend = "steigt", kauf = "Di Mi", verk = "Fr", kp = 85, vp = 110, max = 250, kaufH = { 23, 3 }, verkH = { 12, 16 } },
    { id = 8839, g = "Woche", trend = "steigt", kauf = "Di Mi", verk = "Sa So", kp = 90, vp = 110, max = 150, kaufH = { 21, 1 }, verkH = { 14, 18 } },
    { id = 13465, g = "Woche", kauf = "Fr", verk = "Di", kp = 90, vp = 112, max = 150, kaufH = { 14, 18 }, verkH = { 0, 4 } },
    { id = 13463, g = "Woche", kauf = "Fr", verk = "Di", kp = 90, vp = 110, max = 150, kaufH = { 6, 10 }, verkH = { 22, 2 } },
    { id = 264085, g = "Verfügungen", kauf = "immer", verk = "immer", kp = 65, vp = 95, max = 20 },
  },
},
}
