# Änderungen V15 → V16

Die ERP-DDLs ersetzen die Beispielpayloads als Grundlage für Datentypen und Grenzen. Die fachlichen Mappingentscheidungen aus V15 bleiben erhalten.

| Bereich | V15 | V16 |
|---|---|---|
| AGKO | 31 Felder aus Beispiel | Alle 44 DDL-Felder |
| AGPO | 44 Felder aus Beispiel | Alle 104 DDL-Felder aus Anhang |
| Technisches Datum/Uhrzeit | JSON-String | JSON-Zahl gemäß NUMERIC |
| Textgrenzen | Nur teilweise geprüft | MaxLength für jedes CHAR-Feld |
| Numerische Grenzen | Keine vollständige DDL-Prüfung | Precision/Scale für jedes NUMERIC-Feld |
| Zusatzfelder | Nicht vollständig enthalten | Expliziter Leerstring bzw. 0 gemäß DDL |
| Schema-Dokumentation | Beispielbasiert | SQL-Auszüge, JSON-Schemaübersicht, vollständiges Feldverzeichnis |

`GKJDAT/GPJDAT` sind NUMERIC(8,0), `GKJZEI/GPJZEI` NUMERIC(6,0). Zum Beispiel wird 09:06:58 als Zahl `90658` übertragen. Uhrzeitprüfung verwendet intern sechs Stellen und lehnt 24:00:00 ab; Mitternacht wird als 0 übertragen.

`GKKDNR/GPKDNR` sind CHAR(10). Die bisherige Mindestauffüllung auf sechs Zeichen bleibt fachliche Importkonfiguration, nicht eine aus CHAR(10) abgeleitete Pflicht, jede Kundennummer auf zehn Zeichen aufzufüllen.

Neu hinzugefügte Datumszahlen ohne fachliche Zuordnung bleiben numerische 0 gemäß DDL. Für fachlich verwendete Datumsfelder gilt weiterhin die kalenderbezogene Prüfung des Mappings. `NOT NULL` bedeutet nicht automatisch, dass Leerstring/0 fachlich unzulässig ist. Umgekehrt beweist ein gültiger DB-Default keine fachliche Eignung für Trend.

`DbDefault` dokumentiert die Datenbankvorgabe. `Default` steuert die Importvorbelegung. Beispiel: GKFREX hat DB-Default Leerstring, bleibt im Import aber Pflicht, damit die externe Angebots-ID nicht verloren geht.

CCSID 1141 für AGKO bzw. 273 für AGPO wird als Metadatum mitgeführt. Das Modul prüft Zeichenlängen, jedoch nicht die Darstellbarkeit jedes Unicode-Zeichens in diesen CCSIDs. Die Zeichenkonvertierung bleibt Aufgabe der API/DB-Verbindung.

Die SQL-Auszüge unter `reference` sind Dokumentation. Der Import führt weder CREATE TABLE noch GRANT-Anweisungen aus. Die Importziele bleiben TVPFTEST.AGKO und TVPFTEST.AGPO. Die tatsächliche Gleichheit dieser Testtabellen mit der gelieferten TVPF-DDL wurde mangels Systemzugriff nicht geprüft.

Die Offline-Tests decken Feldabdeckung, JSON-Zahlentypen, Datums-/Uhrzeitwerte, Textlängen, numerischen Überlauf und überzählige Nachkommastellen ab. In dieser Laufzeit fehlt PowerShell; die Tests sind bereitgestellt, aber hier nicht ausgeführt.
