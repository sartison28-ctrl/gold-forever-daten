# gold-forever-daten

Stündliche Auktionshaus-Daten für **WoW: Forever (EU)**. Sie werden über die Blizzard Game Data API abgerufen, von GitHub Actions (`.github/workflows/ah.yml`, jede Stunde um Minute 37 UTC, als Reserve zusätzlich um Minute 7; Blizzard aktualisiert die Daten etwa zu Minute 19) gesammelt und hier gespeichert. Gold Forever (Pipeline + Web-App) liest sie von hier.

## Einrichtung
- Repo-Secrets: `BLIZZARD_CLIENT_ID`, `BLIZZARD_CLIENT_SECRET` (develop.battle.net).
- `konfig.json`: Region, Namespace (`dynamic-forever-eu`), Ruleset (`auto` = PvP) und Häuser. Eingestellt ist **Haus 113** (Horde). Am 15.11.2026 per Abgleich mit TSM bestimmt: Auktionszahl API/TSM 1,01, Preisabweichung im Median 2 %; die Horde-Häuser 114, 120 und 124 passen nicht.
- Manuell starten: Actions → „Auktionshaus sammeln“ → *Run workflow*.

## API (inoffiziell, Stand Nov. 2026)
- Forever hat keine Realms, sondern **Rulesets**: `/data/wow/ruleset/index`.
- Häuser: `/data/wow/ruleset/{id}/auctions/` (den **Schrägstrich am Ende** braucht es). Davon gibt es 15, jeweils 5 für Allianz, Horde und Blackwater.
- Auktionen: `/data/wow/ruleset/{id}/auctions/{haus}`, Rohstoffe unter `…/{haus}/commodities`.

## Dateien
| Datei | Inhalt |
|---|---|
| `daten/haeuser.json` | Rulesets, alle Häuser und das gewählte Haus mit Auktionszahl. Hinweis: Laut Blizzard-Forum liefert jedes Ruleset dieselben Häuser, das Ruleset filtert also nicht. |
| `daten/status.json` | letzter Lauf je Haus (Zeit, Auktionen, Stück, geschätzte Verkäufe der Stunde) |
| `daten/<haus>/aktuell.csv` | neueste Stunde |
| `daten/<haus>/<JJJJ-MM-TT>.csv` | alle Stunden eines Tages (UTC), angehängt |

Die Rohdaten (kompakte Auktionsliste je Stunde) liegen nicht im Git. Sie werden 2 Tage lang als Actions-Artefakt aufbewahrt, die jeweils letzte Liste zusätzlich im Actions-Cache.

### Spalten (Preise in Kupfer, 1g = 10000)
| Spalte | Bedeutung |
|---|---|
| `zeit_utc` | Zeitpunkt des Abrufs |
| `item_id` | Item |
| `stueck`, `auktionen` | Stück gesamt / Anzahl Auktionen im AH |
| `stueck_ohne_sofortkauf` | Stück nur mit Gebot (gehen nicht in die Preise ein) |
| `min`, `p10`, `p25`, `median` | Stückpreis: günstigster Preis und nach Stückzahl gewichtete Perzentile |
| `stueck_bis_5pct` | Stück bis höchstens 5 % über dem günstigsten Preis („Wand“) |
| `weg_lang` | seit der Vorstunde verschwunden, Restzeit war LONG/VERY_LONG → meist verkauft (zurückgezogene Auktionen, die neu eingestellt wurden, sind schon abgezogen) |
| `weg_mittel` | verschwunden, Restzeit war MEDIUM (verkauft oder abgelaufen) |
| `weg_kurz` | verschwunden, Restzeit war SHORT → meist abgelaufen |
| `teilverkauf` | Rohstoffe: Menge einer weiterhin vorhandenen Auktion gesunken |
| `verkauf_schaetzung` | `weg_lang + teilverkauf` (vorsichtig: `weg_mittel` enthält auch abgelaufene 2-Std-Auktionen; zurückgezogene Auktionen ohne Neueinstellung gleicher Stückzahl sind weiter enthalten) |
| `verkauf_preis_median` / `verkauf_preis_min` / `verkauf_umsatz` | Stückpreis (mengengewichteter Median / Minimum) und Umsatz der geschätzten Verkäufe dieser Stunde (Preis aus der Vorstunde; ab 17.11.2026) |
| `zurueckgezogen` | Rohstoffe: verschwundene LONG-Auktionen, die teurer waren als ein Angebot, das stehen blieb → zurückgezogen, nicht verkauft (Käufer bekommen immer zuerst die billigsten Stücke). Zählt nicht mehr in `weg_lang`/`verkauf_schaetzung` (ab 17.11.2026) |
| `neu_stueck` | seit der Vorstunde neu eingestellte Stück (einschließlich umgestellter) |
| `umgestellt` | Stück, die zurückgezogen und neu eingestellt wurden: Eine verschwundene Auktion wird einer neuen Auktion desselben Items mit gleicher Stückzahl zugeordnet. Diese Stück zählen nicht als Verkauf |

Die Spalten `weg_*`, `teilverkauf`, `verkauf_schaetzung`, `neu_stueck` und `umgestellt` sind leer, wenn es keine passende Vorstunde gibt (erster Lauf oder mehr als 75 Minuten zwischen den Blizzard-Datenständen laut `Last-Modified`). Hat sich der Datenstand laut `Last-Modified` seit dem letzten Lauf nicht geändert, wird keine Zeile geschrieben.

## Test
`python test/test_sammeln.py` (offline, mit simulierter API).

## Kennzahlen (`daten/<haus>/kennzahlen.json`, stündlich nach dem Sammeln)
`kennzahlen.py` fasst die letzten 14 Tage je Item zusammen, in rollenden 24-Std.-Fenstern (Tagesrhythmus gleicht sich aus):
`m` Median des günstigsten Angebots je Fenster (neueste zuerst), `st` Stück im AH, `vt`/`vt1` Verkäufe pro Tag (Ø 7 Tage / letzte 24 Std.),
`vp`/`vpn` Median-Verkaufspreis 7 Tage und Stückzahl dahinter, `vh` Verkäufe je Stunde (UTC), `tr1`/`tr3` Trend in % gegen 1 bzw. 3 Tage vorher,
`fall` Anzahl Tage in Folge mit fallendem Median. Für Gold Forever (Datendatei) gedacht.
