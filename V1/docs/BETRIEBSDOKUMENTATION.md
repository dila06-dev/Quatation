# Betrieb V16

Start, Projektstruktur und Prüfstatus: [README](../README.md).
Feldkonfiguration, Vorbelegungen, Datentypen, Preise und Migration: [ERP_MAPPING.md](ERP_MAPPING.md).

`Start-QuoteImport.ps1` verarbeitet die zur Mapping-Dateimaske passenden Dateien im konfigurierten Eingangsverzeichnis. SFTP ist standardmäßig deaktiviert; mit `-SkipSftp` wird lokal gearbeitet. Für SFTP sind WinSCP-DLL, Hostschlüssel und die vorhandene kontogebundene Geheimnisverwaltung erforderlich.

Log, JSON-Dumps, Ergebnisdateien und Archiv befinden sich in den konfigurierten Verzeichnissen. Die Namensvorlagen stehen unter `Mapping.Output`. Keine Zugangsdaten in die Mappingdatei schreiben.

Ohne `-Execute` werden API-Aufrufe simuliert. Ein Dry-Run ist keine Bestätigung einer freien Angebotsnummer oder eines erfolgten Imports. Mit `-Execute` und `Api.TestMode=false` werden tatsächlich Datensätze geschrieben.

Fehlt ein Stammdaten-Query, gelten die ERP-Vorbelegungen. Fehlende externe-ID-Prüfung wird weiterhin protokolliert. Für parallele produktive Verarbeitung ist ein atomarer Nummernkreis erforderlich; der feste Testnummernkreis genügt dafür nicht.
