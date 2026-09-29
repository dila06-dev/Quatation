# Workist → Trend IFGK / IFGP

Komplett neues PowerShell-5.1-Projekt für den Trend-IF-Briefkasten.


## 0.1 PowerShell-5.1-Korrektur in Version 1.1

Version 1.1 korrigiert Parserstellen, die unter Windows PowerShell 5.1 strenger
behandelt werden:

- Variablen unmittelbar vor `:` werden als `${Variable}` geschrieben.
- Funktionsaufrufe innerhalb von `.Insert(...)` werden zunächst in Variablen
  ausgewertet und danach an die Methode übergeben.
- `Test-Configuration.ps1` arbeitet mit `Set-StrictMode` und
  `$ErrorActionPreference = 'Stop'`, damit ein fehlerhafter Modulimport nicht
  mehr mit einer irreführenden Erfolgsmeldung weiterläuft.

## 1. Wichtigste Änderung

Dieses Projekt schreibt **nicht direkt nach AGKO/AGPO**.

Zieltabellen:

```text
TVPFTEST.IFGK
TVPFTEST.IFGP
```

Später, nach Freigabe:

```text
TVPF.IFGK
TVPF.IFGP
```

Die anschließende Erzeugung von AGKO/AGPO erfolgt durch Trend.

## 2. Projektstruktur

```text
Workist_IFGK_IFGP_v1
├── Process-AllWorkistIfCsv.ps1
├── Send-WorkistIfCsv.ps1
├── WorkistIF.Common.psm1
├── WorkistIF.Sftp.psm1
├── WorkistIF.config.psd1
├── New-ProtectedSecret.ps1
├── Test-Configuration.ps1
├── sample-workist.csv
├── docs\
├── sql\
└── runtime\
    ├── incoming\
    ├── archive\
    ├── logs\
    ├── request-dumps\
    └── secure\
```

Alle Laufzeitpfade sind relativ zum Projektordner. Der Ordner kann daher z. B.
nach `D:\Workist_IF` kopiert werden, ohne jeden Pfad im Skript ändern zu müssen.

## 3. Vor dem ersten Lauf

### 3.1 IF-Firmen-Nr. setzen

In `WorkistIF.config.psd1`:

```powershell
InterfaceCompany = 'SETME'
```

durch die echte IF-Firmen-Nr. ersetzen.

Ohne diese Einstellung ist kein Import möglich.

### 3.2 API-Secret erstellen

```powershell
.\New-ProtectedSecret.ps1 -Type Api
```

DPAPI bindet die Datei an denselben Windows-Benutzer und Rechner.

### 3.3 Konfiguration prüfen

```powershell
.\Test-Configuration.ps1
```

## 4. Dry-Run

CSV nach:

```text
runtime\incoming
```

kopieren und:

```powershell
.\Process-AllWorkistIfCsv.ps1
```

Der Dry-Run:
- liest und validiert die CSV,
- baut IFGK/IFGP vollständig,
- erzeugt JSON-Dumps,
- ruft keine INSERT-API auf,
- archiviert nichts.

## 5. API-Simulation

Die Konfiguration startet absichtlich mit:

```powershell
Api.TestMode = $true
```

Mit:

```powershell
.\Process-AllWorkistIfCsv.ps1 -Execute
```

kann die Add-API im Testmodus angesprochen werden. Eine Antwort wie
`Test mode active, nothing inserted.` wird als Simulation behandelt.
Die Datei wird **nicht** archiviert.

## 6. Echte Testtabellen-INSERTs

Erst nach Kontrolle der Dumps:

```powershell
Api.TestMode = $false
```

Dann:

```powershell
.\Process-AllWorkistIfCsv.ps1 -Execute
```

Solange:

```powershell
AllowProductionTables = $false
```

sind nur diese Ziele erlaubt:

```text
TVPFTEST.IFGK
TVPFTEST.IFGP
```

## 7. ODBC-Nachkontrolle

Für Scheduler-Betrieb empfohlen:

```powershell
Verification = @{
    Mode = 'Odbc'
    ConnectionString = 'DSN=MEINE_DSN'
    Username = '...'
    PasswordFile = 'runtime\secure\odbc-password.sec'
}
```

Passwort:

```powershell
.\New-ProtectedSecret.ps1 -Type Odbc
```

ODBC ermöglicht:
- Suche über IF-Firma + IF-Nr.,
- Erkennung bereits vorhandener Interface-Sätze,
- Vergleich der Positionsanzahl,
- Nachkontrolle nach INSERT.

Ohne ODBC können DB-Unique-Keys weiterhin Duplikate verhindern, aber das Projekt
kann bestehende Teilimporte nicht zuverlässig vorab analysieren.

## 8. Statuslogik

IFGK-Neuanlage:

```text
IFGKIFST = 00
IFGKIFKO = 00
IFGKIFPO = 00
```

IFGP-Neuanlage:

```text
IFGPIFST = 10
IFGPIFPO = 10
```

## 9. Nummernkreis

Das Projekt besitzt **keinen AGKO-/AGPO-Nummernkreis mehr**.

Bei Neuanlage:

```text
IFGKAGJJ = 0
IFGKAGNR = ''
IFGPAGJJ = 0
IFGPAGNR = ''
IFGPAGPO = 0
```

Diese Werte sind Ergebnis der späteren Trend-Verarbeitung.

## 10. Preisregel

IFGP besitzt dokumentiert nur:

```text
IFGPPRAR
IFGPPREI
IFGPPDIM
```

Workist enthält dagegen Brutto, Netto und Rabatt.

Daher standardmäßig:
- Rabatt != 0 → Fehler
- Brutto != Netto → Fehler
- bei gleichen Werten wird `PreferredPrice` verwendet

Erst nach fachlicher Bestätigung dürfen die Sicherheitsoptionen gelockert werden.

## 11. Lieferadresse

Die Workist-CSV enthält freie Anschriftfelder.
IFGK dokumentiert dafür nur:

```text
IFGKVSNR
```

Deshalb werden freie Adressdaten nicht automatisch in Freifelder gepackt.
Optional kann die CSV die zusätzliche Spalte `shipping_address_number`
enthalten.

## 12. Optionale CSV-Spalten

Zusätzlich unterstützt:

```text
shipping_address_number
quantity_unit
price_type
price_dimension
identifier_access
article_description1
article_description2
```

## 13. SQL-Kontrolle

Siehe:

```text
sql\01_verify_interface_records.sql
sql\02_status_and_errors.sql
```

## 14. Noch offen

- echte IF-Firmen-Nr.
- fachliche Preisregel bei Rabatt bzw. unterschiedlichen Brutto-/Nettopreisen
- Zuordnung freier Lieferadresse zu einer Trend-Versandadressnummer
- ggf. Artikel-/Kundenstammanreicherung
- technische Parameter für automatischen Aufruf von GNIFGK/GNIFGP bzw. Batchlauf
- finaler Statusablauf nach Trend-Übernahme
- Produktionsfreigabe für TVPF.IFGK / TVPF.IFGP

## 15. Scheduler

Später:

```text
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\...\Process-AllWorkistIfCsv.ps1" -Execute
```

Keine parallele zweite Instanz zulassen.
Secrets müssen unter demselben Scheduler-Benutzer erzeugt worden sein.
