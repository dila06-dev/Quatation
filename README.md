# Angebotimport V14 – mappinggesteuertes PowerShell-Projekt

## Ergebnis

V14 trennt konsequent zwischen Programmlogik, Laufzeitparametern und fachlichem Mapping. Eingabedatei, CSV-Spalten, API-Zieltabellen und erzeugte Ausgabedateien werden nicht mehr in den Skripten fest verdrahtet.

## Projektstruktur

```text
QuoteImport-V14/
├── config/
│   ├── QuoteImport.settings.psd1   # alle Parameter und Abhängigkeiten
│   └── QuoteImport.mapping.psd1    # Ein-/Ausgabe- und Spaltenmapping
├── docs/
│   └── BETRIEBSDOKUMENTATION.md
├── modules/
│   ├── QuoteImport.Common.psm1     # Validierung, Transformation, API
│   └── QuoteImport.Sftp.psm1       # SFTP über WinSCP
├── samples/sample-quotes.csv
├── scripts/
│   ├── Start-QuoteImport.ps1       # Hauptprozess
│   ├── Receive-QuoteFiles.ps1      # nur SFTP-Download
│   └── Send-OneQuoteFile.ps1       # eine lokale Datei testen/importieren
└── tests/Test-ProjectStructure.ps1
```

## Schnellstart

1. `config/QuoteImport.settings.psd1` an die Umgebung anpassen.
2. In `config/QuoteImport.mapping.psd1` Quellspalten und Dateinamen prüfen.
3. Zuerst Strukturtest und Dry-Run starten.

```powershell
.\tests\Test-ProjectStructure.ps1
.\scripts\Start-QuoteImport.ps1 -SkipSftp
```

Erst nach erfolgreicher Prüfung echt schreiben:

```powershell
.\scripts\Start-QuoteImport.ps1 -SkipSftp -Execute
```

Eine einzelne Datei:

```powershell
.\scripts\Send-OneQuoteFile.ps1 -InputPath 'D:\Quotation\QuoteImport\incoming\quotes.csv'
.\scripts\Send-OneQuoteFile.ps1 -InputPath 'D:\Quotation\QuoteImport\incoming\quotes.csv' -Execute
```

Ohne `-Execute` ist der Lauf ein Dry-Run. Die feste Testnummer ist nicht parallelitätssicher; Produktion benötigt `NumberRange.Mode='Api'` mit atomarer Reservierung.
