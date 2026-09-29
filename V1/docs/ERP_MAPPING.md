# ERP-Feldmapping V16

## Grundprinzip

Jedes Ausgabefeld wird explizit anhand seines ERP-Namens definiert. Die JSON-Payload besteht weiterhin aus `table`, `testMode` und `data`. PSD1 wird verwendet, weil diese Datenform Kommentare unterstützt; die erzeugten API-Requests bleiben normales JSON ohne Kommentare.

```powershell
# Fehlende Spalte, null, Leerstring oder nur Leerzeichen -> TST.
@{ Field = 'GKSABE'; Source = 'Csv.field_sales_id'; Type = 'String'; Default = 'TST'; MaxLength = 3 }
# Immer feste Vorbelegung:
@{ Field = 'GKBIBL'; Source = ''; Type = 'String'; Default = 'TVPP1' }
# Führende Nullen erhalten:
@{ Field = 'GKKDNR'; Source = 'Csv.customer_number'; Type = 'String'; Default = '001330'; Pad = 6 }
# Dynamischer Wert statt wiederverwendeter Beispielnummer:
@{ Field = 'GKAGNR'; Source = 'Number.Number'; Type = 'String'; Pad = 6 }
```

Die Einträge stehen in Arrays: `Field` ist der ERP-Feldname, `Source` beschreibt seine Herkunft. Feldnamen werden nicht mehr im Payload-Builder festgelegt. Neue ERP-Felder können als weitere Regeln ergänzt werden. Werden Felder entfernt, fehlen sie auch im JSON; Schlüssel- und Berechnungsfelder dürfen daher nicht entfernt werden.

## Reihenfolge der Wertauflösung

1. Den konfigurierten Quellwert lesen.
2. Nur bei fehlendem Wert, null oder Leertext `FallbackSource` bzw. `Default` anwenden.
3. In den angegebenen Datentyp umwandeln; Textlängen prüfen.
4. Bei ungültigem vorhandenem Wert abbrechen. `0` ist vorhanden und wird nicht ersetzt.
5. Positionsbeträge aus bereits gemappter Menge, Preis und Rabatt berechnen.

Ohne Quellwert und ohne Vorbelegung ist ein Feld Pflicht. `GKFREX` bleibt Pflicht, weil eine statische externe ID mehrere Angebote fälschlich als dasselbe Angebot identifizieren würde.

`Default=''` ist eine gültige explizite Vorbelegung, beispielsweise für `GPTBZ1`. Eine zu lange Sachbearbeiterkennung wird jetzt abgewiesen: `TEST` ist länger als drei Zeichen. Die Beispiel-CSV verwendet deshalb `TST`.

## Quellen

| Präfix | Bedeutung |
|---|---|
| `Csv` | Interner CSV-Alias aus `Input.Columns` |
| `Customer` | Tatsächlich gelesene Kundenstammdaten, sonst leer |
| `Article` | Tatsächlich gelesene Artikelstammdaten, sonst leer |
| `Header` | Bereits fertig gemapptes AGKO-Feld für AGPO |
| `Number` | Reserviertes bzw. konfiguriertes Angebotsjahr und Angebotsnummer |
| `Position` | Positionsnummer 10, 20, 30 … |
| `Runtime` | Technisches Datum/Uhrzeit des Angebots |
| `Calc` | Benannte Betragsberechnung |

`Source=''` mit `Default` erzeugt einen konstanten Wert. Für eine neue CSV-Quelle zuerst einen Alias in `Input.Columns` ergänzen, zum Beispiel `currency='waehrung'`, und dann `Source='Csv.currency'` verwenden. Fehlende Quellspalten sind erlaubt; die dazugehörige ERP-Regel entscheidet über Vorbelegung oder Fehler. Die bestehenden internen Aliasse bleiben aus Kompatibilitätsgründen erhalten.

## Datum, Nummern und Typen

`GKAGJJ`, `GKAGNN` und `GKAGNR` kommen aus dem Nummernkreis. Die konkrete Beispielnummer 103018 wird nicht als globale Vorbelegung verwendet. Der mitgelieferte Nummernkreis entspricht weiterhin V14: Startnummer 103016, Jahr 2026. Für das Referenzbeispiel im Offline-Test wird 103018 eingesetzt.

Fehlendes Angebotsdatum und Gültigkeitsbeginn werden mit dem aktuellen Serverdatum vorbelegt. Fehlendes Gültigkeitsende ist Laufdatum plus neun Tage, passend zum Abstand im Referenzbeispiel. `AddDays` ist konfigurierbar. Ein vorhandener Gültigkeitsbeginn verändert diesen Fallback nicht automatisch; ungültige Datumsintervalle werden abgewiesen. Technische Zeitstempel entstehen einmal je Angebot. Technisches FixedDate/FixedTime beeinflusst nicht den aktuellen Datumsvorschlag für fehlende CSV-Datumsfelder.

`String` erhält führende Nullen. `Int`, `Decimal` und `Date` werden als JSON-Zahlen ausgegeben; `Date` hat das Format yyyyMMdd. Technische `GKJDAT/GPJDAT` werden als JSON-Zahlen (Datum yyyyMMdd), `GKJZEI/GPJZEI` als JSON-Zahlen (Uhrzeit HHmmss) ausgegeben. 09:06:58 wird daher numerisch `90658`; die Uhrzeitprüfung ergänzt intern führende Nullen. Dezimalzahlen dürfen Punkt oder Komma als Dezimaltrennzeichen haben, aber keine Tausendertrennzeichen. Ungültige Eingaben werden nicht stillschweigend korrigiert.

## Preise

- `GPPREI`: CSV-Bruttopreis, sonst 203.01 gemäß Beispiel.
- `GPKOW1`: CSV-Rabatt, sonst 0.
- `GPWAWT`: Menge × Bruttopreis, kaufmännisch auf zwei Nachkommastellen gerundet.
- `GPNESU`: Menge × expliziter CSV-Nettopreis; fehlt dieser, Menge × Bruttopreis × (1 − Rabatt/100).
- `GPURPR`: Bruttopreis auf zwei Nachkommastellen gerundet.

Die Berechnungen sind aus dem bisherigen Import übernommen und keine neue Bestätigung der fachlichen Trend-Semantik. Beispielsweise ergeben 3 × 203.01 die gelieferten 609.03. Bei abweichender Bedeutung eines Trend-Felds muss die Berechnungsregel fachlich angepasst werden. Fehlender Bruttopreis verwendet jetzt seine explizite Mappingvorbelegung; ein vorhandener Nettopreis ersetzt diesen nicht automatisch.

## Grenzen der Referenzpayloads

Alle Felder aus den beiden gelieferten DDLs sind abgedeckt. Textlängen und numerische Precision/Scale werden anhand dieser DDL geprüft; es wird nichts still abgeschnitten oder auf eine kleinere Skala gerundet. Zusätzliche fachliche Trend-Regeln und die tatsächliche Struktur von TVPFTEST müssen separat geprüft werden. Die CSV-Lieferadressfelder sind weiterhin einlesbar, werden aber nicht übertragen: Die gelieferten Zielpayloads enthalten keine entsprechenden ERP-Zielfelder.

Kopfwerte innerhalb einer externen Angebots-ID müssen übereinstimmen. Kopf und alle Positionen werden vor dem ersten POST erzeugt und validiert. Die API-Aufrufe sind weiterhin keine gemeinsame Transaktion: Ein späterer API-Fehler kann einen Teilimport hinterlassen. Vor erneutem Echtlauf den vorhandenen Kopf und die Positionen prüfen.

## Migration

1. V16 separat entpacken; bisheriges Paket aufbewahren.
2. Lokale Pfade, API-/SFTP-Konfiguration und Nummernkreis in die neue settings-Datei übertragen.
3. Bisherige fachliche Anpassungen nach `Erp.AGKO/AGPO` übertragen. Die alte settings-Datei nicht komplett über die neue kopieren.
4. `AdditionalHeaderFields`, `AdditionalPositionFields`, fachliche `Defaults` sowie Stammdaten-Fallbackwerte werden durch die expliziten ERP-Regeln ersetzt. Leere MasterData-Fallbackabschnitte bleiben nur zur Kompatibilität im Paket.
5. Offline-Tests ausführen, dann Dry-Run. JSON-Dumps fachlich mit den gewünschten Werten vergleichen.
6. Erst nach Prüfung mit `-Execute` in die konfigurierten Testtabellen schreiben.

Es wird keine API/SFTP-Verbindung für die beiliegenden Tests benötigt. Ein erfolgreicher Offline-Test bestätigt Mappingverhalten, nicht die fachliche Akzeptanz durch Trend.

## DDL-Abgleich V16

Das [vollständige Feldverzeichnis](FELDVERZEICHNIS.md) dokumentiert 44 AGKO- und 104 AGPO-Felder einschließlich ERP-Beschreibung, SQL-Typ, CCSID, Datenbankdefault und Mappingquelle. Die [Änderungsbeschreibung](ANALYSE_UND_AENDERUNGEN.md) erklärt die Unterschiede zu V15.

Jede Feldregel enthält jetzt `SqlType`, `Nullable`, `DbDefault` sowie entweder `MaxLength/Ccsid` oder `Precision/Scale`. Diese Metadaten sind Bestandteil der transparenten Mappingdatei. Der Konfigurationstest prüft Typkonsistenz; der Resolver prüft die konkreten Werte auch bei berechneten Beträgen.

Zusätzliche Nachkommastellen werden abgewiesen. Nachkommastellen mit ausschließlich Nullen ändern den Zahlenwert nicht und bleiben zulässig. Die ausdrücklich definierte kaufmännische Betragsberechnung bleibt erhalten.

Die beiliegenden SQL-Auszüge dienen nur dem Abgleich. Für den Import muss der API-Service die vollständigen Feldlisten akzeptieren; das muss im Testsystem geprüft werden. Testtabellen werden nicht automatisch erzeugt oder verändert.
