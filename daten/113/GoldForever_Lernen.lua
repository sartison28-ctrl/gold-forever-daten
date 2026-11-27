-- Gold Forever Lern-Datei (Wochenanalyse, Claude) – stand = Zeitpunkt der Analyse (UTC). Nicht von Hand bearbeiten.
-- kaufH/verkH = billigstes/teuerstes 4-Std.-Fenster je Item (GitHub-Stundendaten 15.–23.11., p10 je Stunde relativ zum Tagesmedian, Ortszeit).
-- Quelle: claude/wochenanalyse-2026-11-23.md + Investment Alex 23.11. (Instabiler Ausloeser). Gilt bis zur naechsten Analyse (Mo 30.11.).
GoldForeverLernen = {stand = "2026-11-23T18:50Z", t = 1795459800, standText = "Mo 23.11.",
waechter = { t = 1795794731, text = "27.11. 16:52" },
regel = {
  -- 2.81 (Backtest 27.11.): Rabatt-Staffel, Preissturz bei liquiden Items = Kaufchance (Wochenanalyse stellt nach)
  kauf = { minPreis = 100, minStueck = 25, minProzent = 15, minGewinn = 10000, maxStueck = 250, maxBewaehrt = 400, trend = -15,
    grenze = 15, tief = 30, tiefUmsatz = 50, sturz = 25, sturzUmsatz = 200, mengeMax = 2, minUmsatz = 20, wenigUmsatz = 50, wenigRabatt = 25 },
  invest = { basis = 1, trendAnteil = 25, trendKp = 95 },
  verkauf = { ladenStd = 12, ladenEinst = 3, frist = 24, verlustMax = 10 }, -- 2.84: Ladenhueter-Regel (Analyse Verkaufen 27.11., OK Alex) -- 2.81: Grenzen vom aktuellen Niveau, kleiner Einstieg bei Trend
  trend = { m0 = 120, tr3 = 10 }, -- 2.80: Trend-Item automatisch (24 Std. >= 120 % vom 7-Tage-Median und 3-Tage-Trend >= +10 %)
  sniper = { margeFels = 10, felsSpanne = 110, felsUmsatz = 5000, spanneFisch = 125 },
},
-- 2.81: Bericht (Waechter/Analyse) – Addon zeigt ihn einmal im Chat, /gf bericht zeigt alles
bericht = { t = 1795794731, von = "Wächter", text = "Fr 27.11.",
  gut = "6g 18s Gewinn in 24 Std. (Skorpidschuppe +3g 87s, Eberlunge +2g 45s)",
  schlecht = "Elixier der Weisen -1g 91s (Preis eingebrochen) · Bleichhauer-Ziel 5s 13c zu hoch",
  tun = "Bleichhauer für 3s 99c und Schrapnellbombe für 80s 29c einstellen · Magiestoff, Fleisch, Item 277499 am Ziel verkaufen",
  item = {
    [274976] = "Ziel zu hoch – verkaufen für 3s 99c (Gewinn ca. 58s für 74 Stk.)",
    [264088] = "Ladenhüter seit 66 Std. – für 80s 29c einstellen (gekauft 60s 90c)",
    [4245] = "Ladenhüter seit 14 Std. – für 20s 64c einstellen (gekauft 21s, kleiner Verlust)",
    [4338] = "am Ziel – verkaufen ab 3s 99c (steht zu 4s 8c)",
    [277499] = "am Ziel – verkaufen ab 6s 83c (gekauft 4s 45c)",
    [249695] = "am Ziel – verkaufen ab 13s 98c (gekauft 10s 78c)",
    [13447] = "Vorsicht: Preis eingebrochen (39s 90c) – nicht nachkaufen",
    [8392] = "Preis fällt (52s 30c, Trend -30 %) – kein Nachkauf",
  },
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
  [1015] = { s = "vorsicht", g = "Wächter 27.11.: geflutet (2,2x üblich), Preis fällt" }, -- Magere Wolfflanke
  [5631] = { s = "vorsicht", g = "Wächter 27.11.: 2 Verluste in Folge" }, -- Wuttrank
  [13447] = { s = "vorsicht", g = "Wächter 27.11.: Einbruch (79 % vom 7-Tage-Median, Trend -21 %)" }, -- Elixier der Weisen
  [13930] = { s = "vorsicht", g = "Wächter 27.11.: geflutet (2,1x üblich), Preis fällt" }, -- Rotkiemenfilet
  [213546] = { s = "vorsicht", g = "Wächter 27.11.: geflutet (2,2x üblich), Preis fällt" }, -- Schriftrolle: SCHUBIDU
  [248686] = { s = "vorsicht", g = "Wächter 27.11.: 2 Verluste in Folge" }, -- Abgefangene Kiste: Kräuter des Gesellen
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
