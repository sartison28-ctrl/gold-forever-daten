-- Gold Forever Lern-Datei (Wochenanalyse, Claude) – stand = Zeitpunkt der Analyse (UTC). Nicht von Hand bearbeiten.
-- Quelle: claude/wochenanalyse-2026-11-23.md + Investment Alex 23.11. (Instabiler Ausloeser). Gilt bis zur naechsten Analyse (Mo 30.11.).
GoldForeverLernen = {stand = "2026-11-23T18:45Z", t = 1795459500, standText = "Mo 23.11.",
regel = {
  kauf = { minPreis = 100, minStueck = 25, minProzent = 15, minGewinn = 10000, maxStueck = 250, maxBewaehrt = 400, trend = -15 },
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
    { id = 7067, g = "Woche", kauf = "Di Mi", verk = "Sa So", kp = 88, vp = 112, max = 400 },
    { id = 2592, g = "Woche", kauf = "Di Mi Do", verk = "Fr", kp = 85, vp = 110, max = 250 },
    { id = 2319, g = "Woche", kauf = "Di Mi", verk = "Fr", kp = 85, vp = 110, max = 250 },
    { id = 8839, g = "Woche", kauf = "Di Mi", verk = "Sa So", kp = 90, vp = 110, max = 150 },
    { id = 13465, g = "Woche", kauf = "Fr", verk = "Di", kp = 90, vp = 112, max = 150 },
    { id = 13463, g = "Woche", kauf = "Fr", verk = "Di", kp = 90, vp = 110, max = 150 },
    { id = 264085, g = "Verfügungen", kauf = "immer", verk = "immer", kp = 65, vp = 95, max = 20 },
  },
},
}
