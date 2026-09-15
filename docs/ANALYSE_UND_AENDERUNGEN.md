# Analyse der gelieferten Version und Änderungen in V14

## Ausgangslage

Das gelieferte Paket bestand aus drei Einstiegsskripten, zwei Modulen, einer großen kombinierten Konfigurationsdatei sowie Dokumentation und Beispieldaten. Ein RPG-Quellprogramm war nicht enthalten; die Analyse bezieht sich daher auf den tatsächlich gelieferten PowerShell-basierten Angebotimport für IBM i.

## Wesentliche Befunde

1. Die lokale Dateisuche verwendete fest `*.csv`, unabhängig von der SFTP-Konfiguration.
2. Trennzeichen `;`, Kodierung `UTF8` und alle CSV-Spaltennamen waren im Common-Modul fest programmiert.
3. Die Ausgabenamen für Archivdateien und AGKO-/AGPO-Dumps wurden in der Programmlogik zusammengesetzt.
4. API-Zieltabellen lagen in derselben technischen Konfiguration wie Zugang, Pfade und Defaults.
5. Es gab keine maschinenlesbare zentrale Liste der Software- und Modulabhängigkeiten.
6. Eine Änderung des Lieferantenlayouts erforderte Codeänderungen im größten Modul.
7. Der Batchlauf erzeugte keine eigenständige Ergebnisdatei je Eingabedatei.

## Umgesetzte Architektur

- `QuoteImport.settings.psd1` ist die einzige Quelle für Laufzeitparameter und Abhängigkeiten.
- `QuoteImport.mapping.psd1` ist die einzige Quelle für Ein-/Ausgabeformat und Dateinamen.
- Externe Zeilen werden direkt nach `Import-Csv` in das kanonische interne Schema transformiert.
- SFTP- und lokale Dateiauswahl verwenden dieselbe gemappte Maske.
- Archiv-, Ergebnis- und Dumpnamen werden über geprüfte Vorlagen erzeugt.
- Zieltabellen werden aus dem Mapping gelesen und als `LIBRARY.TABLE` validiert.
- Der Start validiert Abschnitte, Pflichtwerte, Module, PowerShell-Version und – bei aktiviertem SFTP – die WinSCP-DLL.

## Bewusst beibehaltene fachliche Logik

- AGKO wird vor AGPO geschrieben.
- Nach erfolgreichem AGKO-Schreiben kann eine Leseprüfung erfolgen.
- Die Eingabe bleibt bei einem Fehler für Analyse und Wiederholung liegen.
- Ohne `-Execute` gilt Dry-Run.
- Die vorhandenen Feldlängen-, Datums-, Mengen-, Preis- und Duplikatprüfungen bleiben erhalten.

## Offene produktive Entscheidungen

- Die korrekten Produktivtabellen müssen fachlich bestätigt werden.
- Die SQL-Templates für Kunden- und Artikelstamm sind noch leer und verwenden Fallbacks.
- Der produktive Nummernkreis benötigt eine atomare API; die feste Suchnummer ist nur für kontrollierte Tests geeignet.
- Der echte SFTP-Benutzer und SSH-Host-Key-Fingerprint müssen gesetzt werden.
- Für eine echte Transaktionssicherheit muss die Serverseite AGKO und AGPO gemeinsam committen oder rollbacken können.

## Qualitätsprüfung

Im bereitgestellten Laufzeitcontainer war kein PowerShell-Interpreter vorhanden. Deshalb wurden statische Struktur-, Referenz-, Klammer- und Hardcoding-Prüfungen durchgeführt und `tests/Test-ProjectStructure.ps1` für die verbindliche Prüfung unter Windows PowerShell 5.1 beigelegt. Vor dem ersten API-Lauf muss dieser Test auf dem Zielserver erfolgreich sein.
