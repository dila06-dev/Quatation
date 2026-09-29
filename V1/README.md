# QuoteImport V16.1 – ERP-Trend als Grundlage des Feldmappings

Das vollständige Projekt enthält die vorhandenen API-/SFTP-Abläufe sowie einen neuen, kommentierten ERP-Mappingprozessor. Alle 44 AGKO- und 104 AGPO-Felder aus den gelieferten ERP-DDLs stehen in `config/QuoteImport.mapping.psd1` unter `Erp.AGKO` und `Erp.AGPO`.

- `config/QuoteImport.mapping.psd1`: CSV-Aliasse, Ein-/Ausgabedateien, Zieltabellen und sämtliche fachlichen Feldvorbelegungen.
- `config/QuoteImport.settings.psd1`: Verzeichnisse, API, SFTP, Abhängigkeiten, Nummernkreis und technische Datum-/Uhrzeitsteuerung.
- `modules/QuoteImport.Common.psm1`: kommentierte Auflösung, Konvertierung, Validierung und Import.
- `docs/FELDVERZEICHNIS.md`: vollständiger DDL-Abgleich für 148 Felder.
- `reference/`: Schema-Auszüge zur Dokumentation, nicht zur automatischen Ausführung.
- `docs/ERP_MAPPING.md`: Regeln, Beispiele, Migration und Einschränkungen.
- `tests/Test-ErpMapping.ps1`: Offline-Verhaltenstests ohne API-Zugriff.

## Start unter Windows PowerShell 5.1 oder neuer

```powershell
.\tests\Test-ProjectStructure.ps1
.\tests\Test-ErpMapping.ps1
.\scripts\Start-QuoteImport.ps1 -SkipSftp
```

Der letzte Aufruf erzeugt im Dry-Run JSON-Dumps. Ohne `-Execute` werden keine API-Schreibzugriffe ausgeführt. Auch Existenzprüfungen werden im bisherigen Dry-Run nicht tatsächlich ausgeführt; ein solcher Lauf bestätigt keine freie Angebotsnummer.

Vor dem Echtlauf insbesondere Kunde `001330`, Artikel `9600000038`, Menge `3`, Preis `203.01`, Referenz `reference_2` und die Bedingungen fachlich prüfen: Diese Vorbelegungen stammen aus dem gelieferten Beispiel und gelten bei fehlendem CSV-Wert. Zieltabellen sind `TVPFTEST.AGKO` und `TVPFTEST.AGPO`; `testMode=false` bleibt erhalten.

```powershell
.\scripts\Start-QuoteImport.ps1 -SkipSftp -Execute
```

## Prüfstand dieser Lieferung

Feldabdeckung und Struktur wurden statisch geprüft; das ZIP wurde auf Integrität geprüft. In der Erstellungsumgebung steht kein PowerShell-Interpreter zur Verfügung. Die PowerShell-Tests liegen bei, wurden hier aber nicht ausgeführt. Es fand kein Zugriff auf die interne API oder IBM i statt.

## Korrektur V16.1

Der unter Windows PowerShell 5.1 nicht verfügbare Aufruf `[decimal]::Abs()` wurde durch `[math]::Abs()` ersetzt. Der übergebene Wert bleibt Decimal. Der Offline-Test prüft zusätzlich die negative NUMERIC-Grenze und einen negativen Überlauf.

Für ein bestehendes V16-Projekt nur `modules/QuoteImport.Common.psm1` und `tests/Test-ErpMapping.ps1` ersetzen; lokale Konfigurationsanpassungen beibehalten. Danach beide Tests erneut starten. Diese Korrektur wurde statisch geprüft; eine PowerShell-Ausführung ist in der Erstellungsumgebung weiterhin nicht möglich.
