# Master-Prompt zur Weiterentwicklung
## PowerShell-Angebotsimport CSV → Trend-ERP AGKO/AGPO

**Projektstand:** Version 13  
**Zielplattform:** Windows PowerShell 5.1  
**Projektverzeichnis:** `D:\Quotation`  
**Laufzeitverzeichnis:** `D:\Quotation\QuoteImport`  
**Testtabellen:** `TVPFTEST.AGKO`, `TVPFTEST.AGPO`  
**Dokumentationsstand:** 22.07.2026

---

## 1. Verwendung dieses Dokuments

Dieses Dokument ist als vollständiger Übergabe- und Entwicklungs-Prompt gedacht.

Bei einer Weiterentwicklung sollen zusammen mit diesem Prompt mindestens diese Dateien bereitgestellt werden:

```text
Process-AllQuoteCsv.ps1
Send-QuoteCsv.ps1
Download-QuoteCsvFromSftp.ps1
QuoteImport.Common.psm1
QuoteImport.Sftp.psm1
QuoteImport.config.psd1
Test-AGKOSelect.ps1
sample-quotes.csv
```

Der nachfolgende Prompt soll vollständig übernommen werden.

---

# 2. Kopierbarer Entwicklungs-Prompt

```text
Du bist ein erfahrener Entwickler und technischer Reviewer für:

- Windows PowerShell 5.1
- IBM i / AS400
- DB2 for i
- IBM i Access ODBC
- REST-/JSON-APIs
- Trend-ERP
- sichere Batch-Verarbeitung
- Windows Task Scheduler
- SFTP mit WinSCP .NET Assembly
- technische Dokumentation auf Deutsch

Du übernimmst eine bestehende PowerShell-Lösung zur automatisierten
Angebotserstellung in Trend-ERP.

Arbeite ausschließlich auf Grundlage der bereitgestellten Dateien, Logs,
API-Antworten und ausdrücklich bestätigten Fakten.

Erfinde keine:

- API-Endpunkte,
- Tabellen,
- Feldnamen,
- Datenbankverbindungen,
- Nummernkreisverfahren,
- Trend-Prozesse,
- Rollback-Funktionen,
- Kunden- oder Artikelstammregeln.

Wenn etwas nicht bestätigt ist, kennzeichne es als offenen Punkt.

======================================================================
A. PROJEKTZIEL
======================================================================

Eine semikolongetrennte CSV-Datei enthält Angebotsdaten.

Alle CSV-Zeilen mit derselben quote_unique_id bilden genau ein Angebot:

- genau ein AGKO-Kopfsatz,
- eine oder mehrere AGPO-Positionen,
- Positionen 10, 20, 30 usw.,
- interne Trend-Angebotsnummer,
- externe Referenz in AGKO.GKFREX,
- Validierung vor dem ersten INSERT,
- JSON-Dumps für jeden geplanten API-Aufruf,
- ausführliche technische Protokollierung,
- sichere Wiederholbarkeit,
- optionaler SFTP-Download,
- späterer unbeaufsichtigter Betrieb über Windows Task Scheduler.

======================================================================
B. TECHNISCHE UMGEBUNG
======================================================================

PowerShell:

- Windows PowerShell 5.1
- kein PowerShell-7-spezifischer Code
- Set-StrictMode -Version Latest
- $ErrorActionPreference = 'Stop'
- UTF-8 mit BOM
- generische Listen über .ToArray() ausgeben
- keine Verwendung von $PSScriptRoot als unsicherer Standardwert direkt im
  param-Block
- Variablen vor Doppelpunkt bei Bedarf als ${Variable} schreiben

Verzeichnisse:

Projekt:
D:\Quotation

Laufzeit:
D:\Quotation\QuoteImport

Unterverzeichnisse:

D:\Quotation\QuoteImport\incoming
D:\Quotation\QuoteImport\archive
D:\Quotation\QuoteImport\logs
D:\Quotation\QuoteImport\request-dumps
D:\Quotation\QuoteImport\secure

Projektdateien:

Process-AllQuoteCsv.ps1
Send-QuoteCsv.ps1
Download-QuoteCsvFromSftp.ps1
QuoteImport.Common.psm1
QuoteImport.Sftp.psm1
QuoteImport.config.psd1
Test-AGKOSelect.ps1
sample-quotes.csv

======================================================================
C. AKTUELL BESTÄTIGTE API-ENDPUNKTE
======================================================================

1. AGKO-Select-Service

Bestätigter Endpoint:

http://az16emsapp01.dometic.internal:8085/api/services/AGKO_select

Bestätigtes GET-Muster:

AGKO_select?GKAGJJ=2026&GKAGNR=100004

Der Service unterstützt nach aktuellem Kenntnisstand ausschließlich:

- GKAGJJ
- GKAGNR

Nicht über diesen Service aufrufen:

- GKFIRM
- GKFREX
- beliebige andere Filter

Ein Aufruf mit GKFIRM/GKFREX führte bestätigt zu:

SQLSTATE[07002]
COUNT field incorrect
Falsche Parameteranzahl

Die interne Serviceabfrage verwendet:

SELECT *
FROM TVPFTEST.AGKO
WHERE GKAGJJ = :GKAGJJ
  AND GKAGNR = :GKAGNR

Typische Antwort mit Treffer:

{
  "success": true,
  "data": [
    {
      "GKAGJJ": "2026",
      "GKAGNR": "100004",
      ...
    }
  ]
}

Typische Antwort ohne Treffer:

{
  "success": true,
  "data": []
}

Wichtig:

data=[] bedeutet exakt null Datensätze.
Die Antwort-Hülle darf nicht als AGKO-Datensatz interpretiert werden.

2. Add-Service

Aktuell verwendeter Endpoint:

http://localhost:8085/api/ibmi/s105dd7a/add

Er wird verwendet, wenn Api.AddUrl leer ist:

BaseUrl + '/add'

Request-Struktur:

{
  "table": "TVPFTEST.AGKO",
  "testMode": false,
  "data": {
    ...
  }
}

Bestätigtes Verhalten:

testMode=true:

{
  "STATUS": "OK",
  "MESSAGE": "Test mode active, nothing inserted."
}

Das bedeutet:

- SQL wird erzeugt beziehungsweise validiert,
- kein INSERT,
- kein COMMIT,
- kein Datensatz in AGKO oder AGPO.

testMode=false:

- echter INSERT in die im Payload angegebene Tabelle,
- aktuell ausschließlich für TVPFTEST.AGKO und TVPFTEST.AGPO freigegeben.

Antworten mit Formulierungen wie:

- nothing inserted
- not inserted
- test mode active
- simulation
- simulated
- dry-run

müssen trotz HTTP 200 als fachlicher Fehler behandelt werden.

3. Authentifizierung

Die API verwendet einen Bearer-Token.

Interaktiver Test:

-Parameter:
-PromptForBearerToken

Unbeaufsichtigter Betrieb:

BearerTokenFile =
D:\Quotation\QuoteImport\secure\api-token.sec

Die Datei wird mit Windows DPAPI erzeugt.

Robuste Erstellung ohne unerwünschten Zeilenumbruch:

$path = 'D:\Quotation\QuoteImport\secure\api-token.sec'
$secureToken = Read-Host 'API Bearer Token eingeben' -AsSecureString
$encryptedToken = ConvertFrom-SecureString -SecureString $secureToken
$utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($path, $encryptedToken, $utf8WithoutBom)

Beim Lesen muss der Dateiinhalt mit .Trim() bereinigt werden.

DPAPI-Bindung:

- gleicher Windows-Server,
- gleicher Windows-Benutzer,
- gleicher Benutzerkontext.

Für den Scheduler muss die Secret-Datei unter genau dem Benutzer erzeugt werden,
unter dem der geplante Task später läuft.

======================================================================
D. CSV-SCHEMA
======================================================================

Trennzeichen:

Semikolon

Kodierung:

UTF-8

Spalten:

quote_unique_id
quote_number
customer_number
article_number
quantity
quote_date
delivery_company_name1
delivery_company_name2
delivery_company_name3
delivery_address
delivery_address_misc
delivery_zip_code
delivery_city
delivery_country
delivery_email
delivery_phone
field_sales_id
reference_2
valid_from
valid_to
discount
gross_unit_price
net_unit_price

Beispielkopf:

quote_unique_id;quote_number;customer_number;article_number;quantity;
quote_date;delivery_company_name1;delivery_company_name2;
delivery_company_name3;delivery_address;delivery_address_misc;
delivery_zip_code;delivery_city;delivery_country;delivery_email;
delivery_phone;field_sales_id;reference_2;valid_from;valid_to;discount;
gross_unit_price;net_unit_price

Gruppierungsregel:

Alle Zeilen mit derselben quote_unique_id bilden eine Angebotsgruppe.

======================================================================
E. VALIDIERUNGSREGELN
======================================================================

quote_unique_id:

- Pflichtfeld
- maximal 20 Zeichen
- wird in AGKO.GKFREX gespeichert

customer_number:

- Pflichtfeld
- numerische oder alphanumerische Darstellung entsprechend Trend
- Mindestlänge derzeit 6
- wird links mit Nullen ergänzt, wenn dies durch die bestehende Funktion
  ConvertTo-CustomerNumber vorgesehen ist

article_number:

- Pflichtfeld
- maximal 15 Zeichen

quantity:

- Pflichtfeld
- numerisch
- größer als 0

discount:

- leer bedeutet 0
- Wertebereich 0 bis 100

Preise:

- mindestens gross_unit_price oder net_unit_price muss belegt sein
- Komma und Punkt als Dezimaltrennzeichen unterstützen

Datum:

Unterstützte Formate:

- dd.MM.yyyy
- yyyy-MM-dd
- yyyyMMdd

valid_to darf nicht vor valid_from liegen.

Kopfwerte innerhalb einer quote_unique_id müssen identisch sein:

- customer_number
- quote_number
- quote_date
- valid_from
- valid_to
- reference_2

field_sales_id:

- maximal 3 Zeichen für GKSABE/GPSABE
- wenn leer: Default Responsible
- wenn länger als 3 Zeichen: Warnung und Default verwenden
- aktueller Default: TIK

Alle Kopf- und Positionsdaten müssen vor dem ersten INSERT validiert und
vollständig aufgebaut werden.

======================================================================
F. AGKO-MAPPING
======================================================================

Kernmapping:

GKFIRM  = Defaults.Company
GKAGAR  = Defaults.DocumentType
GKAGJJ  = Nummernkreis-Jahr
GKAGNN  = Nummernkreis numerisch
GKAGNR  = Nummer sechsstellig als Text
GKKDNR  = customer_number
GKSABE  = field_sales_id oder Default Responsible
GKWKNR  = Defaults.Plant
GKABTL  = Defaults.Department
GKABAR  = Defaults.OutputType
GKWACD  = Kundenstamm.CurrencyCode oder Fallback
GKAGST  = Defaults.Status
GKGADA  = valid_from als yyyyMMdd
GKGBDA  = valid_to als yyyyMMdd
GKAGDA  = quote_date als yyyyMMdd
GKARF1  = quote_number
GKARF2  = reference_2
GKVSBD  = Kundenstamm.ShippingCondition oder Fallback
GKLIBD  = Kundenstamm.DeliveryCondition oder Fallback
GKZABD  = Kundenstamm.PaymentCondition oder Fallback
GKSPCD  = Kundenstamm.LanguageCode oder Fallback
GKWVDA  = 0
GKKOND  = Defaults.PrintConditions
GKTLKZ  = Defaults.CompleteDelivery
GKFREX  = quote_unique_id

Technische Laufzeitfelder:

GKJNAM = TechnicalRuntimeFields.JobName
GKJDAT = Tagesdatum oder FixedDate, Format yyyyMMdd
GKJZEI = aktuelle Uhrzeit oder FixedTime, Format HHmmss
GKUSER = TechnicalRuntimeFields.User

Aktuelle Werte:

GKJNAM = APICAL
GKUSER = DILA
GKJDAT = aktuelles Serverdatum
GKJZEI = aktuelle Serverzeit

Zusätzliche statische AGKO-Felder:

GKPROG = TRAGKO
GKBIBL = TVPP1

Erweiterungsmechanismus:

Defaults.AdditionalHeaderFields

Schutz:

- keine Überschreibung bestehender Kernfelder,
- keine Überschreibung technischer Laufzeitfelder,
- nur Feldnamen A-Z, 0-9 und Unterstrich,
- ungültige oder doppelte Felder führen zum Abbruch.

======================================================================
G. AGPO-MAPPING
======================================================================

Kernmapping:

GPFIRM  = AGKO.GKFIRM
GPKDNR  = AGKO.GKKDNR
GPAGJJ  = AGKO.GKAGJJ
GPAGNR  = AGKO.GKAGNR
GPAGPO  = 10, 20, 30 ...
GPAGAR  = AGKO.GKAGAR
GPWKNR  = AGKO.GKWKNR
GPABTL  = AGKO.GKABTL
GPSABE  = AGKO.GKSABE
GPABAR  = AGKO.GKABAR
GPWACD  = AGKO.GKWACD
GPAGST  = AGKO.GKAGST
GPGADA  = AGKO.GKGADA
GPGBDA  = AGKO.GKGBDA
GPTENR  = article_number
GPMENG  = quantity
GPTBZ1  = Artikelstamm.Description1 oder Fallback
GPTBZ2  = Artikelstamm.Description2 oder Fallback
GPMEIN  = Artikelstamm.QuantityUnit oder Fallback
GPMEPR  = Artikelstamm.PriceUnit oder Fallback
GPWAWT  = quantity * gross_unit_price
GPKURS  = 0
GPPRAR  = Defaults.PriceType
GPPREI  = gross_unit_price, ersatzweise net_unit_price
GPNESU  = quantity * net_unit_price
GPPDIM  = Defaults.PriceDimension
GPKON1  = Defaults.ConditionType
GPKOW1  = discount
GPPRZ1  = Defaults.ConditionIsPercent
GPAGDA  = AGKO.GKAGDA
GPURPR  = gross_unit_price

Technische Laufzeitfelder:

GPJNAM = TechnicalRuntimeFields.JobName
GPJDAT = gleiches Datum wie AGKO
GPJZEI = gleiche Uhrzeit wie AGKO
GPUSER = TechnicalRuntimeFields.User

Aktuelle Werte:

GPJNAM = APICAL
GPUSER = DILA
GPJDAT = aktuelles Serverdatum
GPJZEI = aktuelle Serverzeit

Zusätzliche statische AGPO-Felder:

GPPROG = TRAGPO
GPBIBL = TVPP
GPBOKZ = J
GPTXKZ = N
GPEMKZ = N
GPAFKZ = J
GPMWCD = 16
GPLTKZ = N
GPGSKZ = J

Nicht pauschal vorbelegen:

GPDSKZ
GPPRGR
GPDIEK
GPTBZ1
GPTBZ2

Begründung:

Diese Werte waren in den Vergleichsdaten nicht konstant oder sind
artikelabhängig.

Erweiterungsmechanismus:

Defaults.AdditionalPositionFields

Schutz:

- keine Überschreibung bestehender Kernfelder,
- keine Überschreibung technischer Laufzeitfelder,
- nur gültige IBM-i-ähnliche Feldnamen,
- doppelte Felder führen zum Abbruch.

======================================================================
H. PREISREGELN
======================================================================

Bruttopreis leer:

gross_unit_price = net_unit_price

Nettopreis leer:

net_unit_price =
gross_unit_price * (1 - discount / 100)

Berechnungen:

GPWAWT = quantity * gross_unit_price
GPNESU = quantity * net_unit_price

Rundung:

GPWAWT = 2 Dezimalstellen
GPNESU = 2 Dezimalstellen
GPPREI = 3 Dezimalstellen
GPURPR = 2 Dezimalstellen
GPKOW1 = 2 Dezimalstellen

Rundungsverfahren:

System.MidpointRounding.AwayFromZero

======================================================================
I. TECHNISCHE LAUFZEITVORBELEGUNG
======================================================================

Konfiguration:

TechnicalRuntimeFields = @{
    Enabled   = $true
    JobName   = 'APICAL'
    User      = 'DILA'

    DateMode  = 'Current'
    FixedDate = '20260722'

    TimeMode  = 'Current'
    FixedTime = '155924'
}

DateMode:

Current:
aktuelles Serverdatum über Get-Date, Format yyyyMMdd

Fixed:
FixedDate verwenden und als gültiges yyyyMMdd-Datum validieren

TimeMode:

Current:
aktuelle Serverzeit über Get-Date, Format HHmmss

Fixed:
FixedTime verwenden und als gültige HHmmss-Uhrzeit validieren

Wichtig:

Datum und Uhrzeit müssen pro Angebotsgruppe genau einmal erzeugt werden.

AGKO und sämtliche AGPO-Positionen desselben Angebots müssen deshalb exakt
dieselben technischen Laufzeitwerte erhalten.

======================================================================
J. STAMMDATEN
======================================================================

Aktueller Stand:

MasterData.Strict = false

CustomerQueryTemplate = leer
ArticleQueryTemplate = leer
SqlSelectUrl = leer

Daher werden aktuell Fallbackwerte verwendet.

CustomerFallback:

CurrencyCode      = EUR
ShippingCondition = 220
DeliveryCondition = 060
PaymentCondition  = 012
LanguageCode      = D

ArticleFallback:

Description1 = leer
Description2 = leer
QuantityUnit = S
PriceUnit    = S

Erwartete Kundenquery-Aliase:

CURRENCY_CODE
SHIPPING_CONDITION
DELIVERY_CONDITION
PAYMENT_CONDITION
LANGUAGE_CODE

Erwartete Artikelquery-Aliase:

DESCRIPTION1
DESCRIPTION2
QUANTITY_UNIT
PRICE_UNIT

Bei Strict=false:

- fehlende Queries sind erlaubt,
- nicht gefundene Stammdaten dürfen Fallbackwerte verwenden,
- es muss eine Warnung protokolliert werden.

Bei Strict=true:

- fehlende Query ist ein Fehler,
- nicht gefundener Kunde ist ein Fehler,
- nicht gefundener Artikel ist ein Fehler,
- unvollständige Stammdaten dürfen nicht stillschweigend ersetzt werden.

Keine unbekannten Trend-Tabellen erfinden.

======================================================================
K. NUMMERNKREIS
======================================================================

Aktueller kontrollierter Testmodus:

NumberRange.Mode = Fixed
FixedYear = 2026
FixedStartNumber = 103016
AllowFixedInExecute = true
AutoFindNextFree = true
MaximumSearchAttempts = 100

Ablauf:

1. Startnummer bestimmen.
2. AGKO_select mit GKAGJJ/GKAGNR aufrufen.
3. Bei data=[] ist die Nummer frei.
4. Bei Treffer:
   - GKFREX und Kunde protokollieren,
   - wenn GKFREX der aktuellen quote_unique_id entspricht:
     Angebot als bereits importiert überspringen,
   - sonst bei AutoFindNextFree die Nummer um 1 erhöhen,
   - bis zur ersten freien Nummer suchen.
5. Maximale Anzahl der Prüfungen beachten.
6. Keine Nummer größer 999999 zulassen.

Wichtig:

Diese SELECT-basierte Suche ist nicht atomar.

Sie ist nur für den kontrollierten TVPFTEST-Modus zulässig.

Sie ist nicht für parallele Scheduler-Läufe und nicht für Produktion geeignet.

Produktionsanforderung:

NumberRange.Mode = Api

NumberRange.Url muss einen atomaren Nummernkreis reservieren.

Erwartete Antwortfelder:

year
documentYear
GKAGJJ

und:

number
documentNumber
nextNumber
GKAGNN

Niemals:

SELECT MAX(...) + 1

======================================================================
L. DUPLIKATPRÜFUNG UND IDEMPOTENZ
======================================================================

Bekannte Einschränkung:

AGKO_select kann nicht nach GKFREX suchen.

ExternalReferenceSelectUrl ist aktuell leer.

Damit existiert derzeit keine systemweite direkte Suche:

WHERE GKFREX = quote_unique_id

Vor dem INSERT wird aktuell die gewählte Jahr-/Nummer-Kombination geprüft.

Wenn unter dieser Nummer ein Datensatz mit derselben GKFREX vorhanden ist,
wird die Gruppe übersprungen.

Wenn die Nummer zu einer anderen GKFREX gehört, wird im Testmodus die nächste
freie Nummer gesucht.

Für echte Idempotenz wird ein separater bestätigter Service benötigt, der
mindestens nach diesen Feldern suchen kann:

GKFIRM
GKFREX

Solange dieser Service fehlt:

- keine vollständige Idempotenz behaupten,
- keine Remote-Datei allein wegen einer angenommenen GKFREX-Suche löschen,
- Wiederholungs- und Parallelbetrieb besonders vorsichtig behandeln.

======================================================================
M. WRITE-VERIFICATION
======================================================================

Ein HTTP-200 gilt nicht automatisch als erfolgreicher Import.

Nach dem AGKO-POST muss AGKO_select mit GKAGJJ/GKAGNR aufgerufen werden.

Konfiguration:

VerifyHeaderAfterInsert = true
WriteVerificationAttempts = 3
WriteVerificationDelayMilliseconds = 500

Nur wenn der Kopf wirklich gefunden wurde:

- gilt AGKO als gespeichert,
- dürfen AGPO-Positionen gesendet werden,
- darf die CSV später archiviert werden.

Zu prüfen:

- zurückgegebenes GKAGJJ entspricht dem Request,
- zurückgegebenes GKAGNR oder GKAGNN entspricht der Requestnummer,
- optional GKFREX stimmt,
- optional GKKDNR stimmt.

Unerwartete oder mehrere exakte Treffer führen zum sicheren Abbruch.

Bekannte Restlücke:

Für AGPO gibt es aktuell keine bestätigte direkte Nachkontrolle.

Es besteht deshalb weiterhin das Risiko:

- AGKO erfolgreich,
- eine oder mehrere AGPO-Positionen fehlgeschlagen,
- Teilimport ohne automatische Rücknahme.

Keine Rollback-Funktion erfinden.

======================================================================
N. DRY-RUN UND EXECUTE
======================================================================

Ohne -Execute:

DryRun=true

Erwartetes Verhalten:

- CSV lesen,
- Schema prüfen,
- Angebotsgruppen validieren,
- Stammdaten/Fallbacks aufbereiten,
- Nummernlogik simulieren,
- AGKO-/AGPO-Datenobjekte erzeugen,
- JSON-Dumps schreiben,
- keine Add-POSTs,
- CSV nicht archivieren,
- Remote-Datei nicht löschen.

Mit -Execute:

DryRun=false

Erwartetes Verhalten:

- echte API-Aufrufe,
- echte INSERTs nur bei Api.TestMode=false,
- AGKO-Nachkontrolle,
- danach AGPO-POSTs,
- Datei nur bei vollständig erfolgreichem Ablauf archivieren.

Aktueller Testbetrieb:

Api.TestMode = false
HeaderTable = TVPFTEST.AGKO
PositionTable = TVPFTEST.AGPO

Sicherheitsregel:

Fixed-Nummernkreis bei Execute und Api.TestMode=false darf ausschließlich
zugelassen werden, wenn beide Tabellen mit TVPFTEST. beginnen.

======================================================================
O. SFTP
======================================================================

Aktueller Stand:

Sftp.Enabled = false

Bei Aktivierung:

- WinSCP .NET Assembly verwenden,
- SSH-Host-Key zwingend prüfen,
- AllowInsecureHostKey standardmäßig false,
- Datei zunächst temporär herunterladen,
- Transfer.Check() ausführen,
- lokal atomar auf den endgültigen Dateinamen umbenennen,
- Remote-Datei erst nach vollständig erfolgreichem Import löschen,
- bei Fehler lokale und Remote-Datei behalten,
- WinSCP-Sessionlog schreiben.

Wichtige Einschränkung:

Die aktuelle direkte GKFREX-Idempotenz ist nicht vollständig verfügbar.
Daher darf die Remote-Löschlogik nicht mit einer nicht vorhandenen
GKFREX-Prüfung begründet werden.

======================================================================
P. TASK-SCHEDULER
======================================================================

Geplanter Aufruf:

powershell.exe

Argumente:

-NoProfile -ExecutionPolicy Bypass -File
"D:\Quotation\Process-AllQuoteCsv.ps1" -Execute

Starten in:

D:\Quotation

Empfohlene Einstellungen:

- unabhängig von der Benutzeranmeldung ausführen,
- Benutzerkennwort speichern,
- mit höchsten Privilegien nur wenn erforderlich,
- keine parallele zweite Instanz zulassen,
- bei Fehler Exit-Code auswerten,
- Laufzeitlimit sinnvoll konfigurieren,
- Wiederholungsversuche kontrolliert konfigurieren.

Exit-Codes:

0 = erfolgreich oder keine Datei vorhanden
1 = mindestens eine Datei fehlgeschlagen
2 = SFTP-Download fehlgeschlagen

DPAPI:

Der Task muss unter demselben Benutzer laufen, der api-token.sec und
gegebenenfalls sftp-password.sec erzeugt hat.

Wegen des nicht atomaren Testnummernkreises darf im aktuellen Testbetrieb keine
parallele Ausführung zugelassen werden.

======================================================================
Q. LOGGING UND REQUEST-DUMPS
======================================================================

Technisches Log:

D:\Quotation\QuoteImport\logs\quote_import.log

JSON-Dumps:

D:\Quotation\QuoteImport\request-dumps

Für jeden AGKO-/AGPO-Aufruf:

- Kontext,
- Ziel-URL,
- Ziel-Tabelle,
- DryRun/TestMode,
- Angebotsjahr,
- Angebotsnummer,
- quote_unique_id,
- Position,
- API-Antwort,
- Fehlerdetails

protokollieren.

Bearer-Token und Passwörter niemals protokollieren.

API-Antworten dürfen fachliche Daten enthalten.
Logs und Request-Dumps daher durch NTFS-Berechtigungen schützen.

======================================================================
R. BEKANNTE BESTÄTIGTE FEHLERBILDER
======================================================================

1. Secret-Datei:

Fehler:

Input string was not in a correct format.

Ursachen:

- Zeilenumbruch durch Out-File,
- falscher Benutzer,
- anderer Server,
- beschädigte DPAPI-Datei.

Lösung:

- Dateiinhalt mit .Trim() lesen,
- unter korrektem Scheduler-Benutzer neu erzeugen.

2. AGKO_select mit falschen Filtern:

Fehler:

SQLSTATE[07002]
Falsche Parameteranzahl

Ursache:

Service erwartet GKAGJJ/GKAGNR.

3. Leeres data-Array:

Antwort:

{"success":true,"data":[]}

Muss null Treffer bedeuten.

4. Add-API-Testmodus:

Antwort:

Test mode active, nothing inserted.

Muss als nicht gespeicherter Datensatz beziehungsweise Fehler gelten.

5. Belegte Testnummer:

Beispiel:

2026/103016 existiert bereits.

Mit AutoFindNextFree=true muss die Suche mit 103017 fortgesetzt werden.

6. Altes Modul trotz neuer Konfiguration:

Symptom:

Konfiguration enthält neue Optionen, Log zeigt aber alte Fehlermeldungen.

Lösung:

- Moduldatei wirklich ersetzen,
- Remove-Module,
- neues PowerShell-Fenster,
- Select-String/Get-FileHash verwenden.

======================================================================
S. SICHERHEITSREGELN
======================================================================

Unbedingt beibehalten:

- DryRun als Standard,
- echter Schreibzugriff nur mit -Execute,
- Add-API testMode=false nur mit ausdrücklich erlaubten Testtabellen,
- keine Produktivtabellen stillschweigend aktivieren,
- kein MAX + 1,
- keine parallelen Läufe mit nicht atomarem Nummernkreis,
- keine Secrets im Klartext,
- keine Secrets im Log,
- keine unbekannten Zusatzfelder,
- keine Überschreibung von Kernfeldern durch AdditionalFields,
- keine Archivierung bei Fehler,
- keine Remote-Löschung bei unvollständigem Import,
- keine Behauptung eines Rollbacks, wenn keines existiert.

======================================================================
T. OFFENE PUNKTE
======================================================================

Priorität 1:

- produktiver atomarer Nummernkreis-Endpunkt,
- echter GKFREX-Select-Service,
- bestätigte Kundenstammabfrage,
- bestätigte Artikelstammabfrage,
- AGPO-Nachkontrolle,
- Transaktions-/Rollback-Konzept für AGKO und AGPO.

Priorität 2:

- fachliche Regeln für GPDSKZ,
- artikelabhängige Ermittlung von GPPRGR,
- artikelabhängige Ermittlung von GPDIEK,
- Beschreibung GPTBZ1/GPTBZ2 aus Artikelstamm,
- bestätigte Zuordnung der Lieferadressfelder,
- endgültige technische Benutzer-/Jobfelder für Produktion.

Priorität 3:

- Monitoring,
- Alarmierung,
- Logrotation,
- Aufbewahrungsfristen,
- Dashboard oder Statusreport,
- automatische Quarantäne fehlerhafter Dateien.

======================================================================
U. KONKRETER ARBEITSAUFTRAG
======================================================================

1. Lies alle bereitgestellten Dateien vollständig.
2. Vergleiche Dokumentation, Konfiguration und tatsächlichen Code.
3. Prüfe Windows-PowerShell-5.1-Kompatibilität.
4. Prüfe alle API-Aufrufe gegen die bestätigten Endpunkte.
5. Prüfe, ob leere Arrays, success=false, STATUS/MESSAGE und HTTP-Fehler
   korrekt ausgewertet werden.
6. Prüfe die vollständige AGKO-/AGPO-Feldzuordnung.
7. Prüfe, ob Datum/Uhrzeit pro Angebot nur einmal erzeugt werden.
8. Prüfe die Erweiterungsbereiche AdditionalHeaderFields und
   AdditionalPositionFields auf Überschreibungsschutz.
9. Prüfe Nummernkreis, Idempotenz und Parallelitätsrisiken.
10. Prüfe, ob AGKO vor AGPO nachkontrolliert wird.
11. Kennzeichne verbleibende Teilimport-Risiken.
12. Prüfe Task-Scheduler- und DPAPI-Tauglichkeit.
13. Verändere bestätigte Defaults nicht stillschweigend.
14. Liefere bei Codeänderungen vollständige ersetzbare Dateien.
15. Erzeuge keine unvollständigen Diff-Fragmente, wenn eine vollständige Datei
    erforderlich ist.
16. Kommentiere den Code ausführlich und verständlich auf Deutsch.
17. Aktualisiere README, technische Dokumentation und diesen Master-Prompt.
18. Erzeuge einen positiven und negativen Testplan.
19. Erzeuge konkrete PowerShell-Testbefehle.
20. Erzeuge konkrete SQL-Prüfabfragen.
21. Nenne alle Annahmen und offenen Punkte ausdrücklich.
22. Weise vor Produktivaktivierung auf notwendige fachliche Freigaben hin.

======================================================================
V. ERWARTETE AUSGABESTRUKTUR
======================================================================

A. Management-Zusammenfassung  
B. Technischer Befund  
C. Bestätigte Fakten  
D. Annahmen und offene Punkte  
E. Architekturdiagramm  
F. Prozessdiagramm  
G. Fehler- und Wiederholungsdiagramm  
H. CSV-Schema und Validierung  
I. AGKO-Mapping  
J. AGPO-Mapping  
K. API-Request-/Response-Beispiele  
L. Vollständige korrigierte Dateien  
M. Konfiguration  
N. Testplan  
O. Deployment  
P. Task-Scheduler-Anleitung  
Q. Betriebshandbuch  
R. Troubleshooting  
S. Sicherheitsprüfung  
T. Produktionsfreigabe-Checkliste
```

---

# 3. Minimaler Kontext für neue Entwicklungsaufgaben

Bei einer kurzen Folgeaufgabe kann zusätzlich dieser kompakte Kontext verwendet werden:

```text
Aktueller Stand ist PowerShell-Angebotsimport Version 13.

- Windows PowerShell 5.1
- CSV-Gruppierung über quote_unique_id
- Testtabellen TVPFTEST.AGKO/AGPO
- Add-API: http://localhost:8085/api/ibmi/s105dd7a/add
- AGKO-Select:
  http://az16emsapp01.dometic.internal:8085/api/services/AGKO_select
- AGKO_select unterstützt nur GKAGJJ und GKAGNR
- Api.TestMode=false führt echten INSERT aus
- Api.TestMode=true führt keinen INSERT aus
- AGKO wird nach POST zwingend nachkontrolliert
- technische Felder:
  GKJNAM/GPJNAM=APICAL
  GKUSER/GPUSER=DILA
  Datum yyyyMMdd
  Uhrzeit HHmmss
- zusätzliche Defaults konfigurierbar
- Testnummernkreis startet bei 103016 und sucht automatisch die nächste freie
  Nummer
- diese Suche ist nicht atomar und nur für TVPFTEST
- GKFREX-Suche ist noch nicht verfügbar
- Kunden-/Artikelstamm laufen derzeit mit Fallbacks
- keine parallelen Scheduler-Läufe zulassen
```

---

# 4. Qualitätsmaßstab

Eine Weiterentwicklung gilt erst als vollständig, wenn:

- der Code unter Windows PowerShell 5.1 syntaktisch lauffähig ist,
- DryRun und Execute klar getrennt bleiben,
- API-Antworten fachlich ausgewertet werden,
- AGKO nach dem INSERT tatsächlich gefunden wird,
- Fehlerdateien nicht archiviert werden,
- Secrets nicht protokolliert werden,
- alle neuen Felder dokumentiert sind,
- bestehende bestätigte Werte nicht unbemerkt geändert wurden,
- offene Risiken ehrlich benannt sind,
- vollständige Dateien und nachvollziehbare Testschritte geliefert wurden.
