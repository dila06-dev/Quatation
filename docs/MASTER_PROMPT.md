# Master-Prompt – Workist → Trend IFGK / IFGP

## Projektstand

Dies ist ein vollständig neues Projekt. Der alte direkte AGKO/AGPO-Import ist
nicht mehr die Zielarchitektur.

## Unverrückbare Regeln

1. Workist befüllt ausschließlich IFGK und IFGP.
2. Keine direkten INSERTs nach AGKO/AGPO.
3. IFGK-Schlüssel:
   - IFGKTSTP eindeutig
   - IFGKIFFI + IFGKIFNR eindeutig
4. IFGP-Schlüssel:
   - IFGPIFGK + IFGPIFGP eindeutig
   - IFGPTSTP eindeutig
   - IFGPIFFI + IFGPIFNR + IFGPIFGP eindeutig
5. quote_unique_id wird als IFGKIFNR / IFGPIFNR verwendet.
6. IFGPIFGK muss exakt dem IFGKTSTP des Kopfes entsprechen.
7. IFGPIFGP zählt 1,2,3,...
8. IFGK-Neustatus ist 00/00/00.
9. IFGP-Neustatus ist 10/10.
10. AGJJ/AGNR/AGPO sind bei IF-Neuanlage Ergebnisfelder und werden nicht durch
    einen eigenen Angebotsnummernkreis vorbelegt.
11. IFGKKDNR ist Pflicht.
12. IFGKGBDA ist Pflicht und darf nicht kleiner als IFGKGADA sein.
13. IFGPTENR und IFGPMENG sind Pflicht.
14. IFGPMEIN darf im Payload leer bleiben, damit Trend laut Dokumentation
    TEIL.TEMEVK bzw. TEIL.TEMEIN vorbelegen kann.
15. Keine nicht dokumentierten Preis-/Rabattfelder erfinden.
16. Freie Lieferadresse nicht ungeprüft in IFGKFREI schreiben.
17. Produktivtabellen bleiben bis zur ausdrücklichen Freigabe blockiert.
18. Trend-Übernahmeprogramme nicht automatisch aufrufen, solange deren
    technische Parameter nicht bestätigt sind.

## Tabellenstruktur

IFGK besitzt 50 Felder; IFGP 41 Felder.
Die Datentypen und Längen sind in docs/FIELD_MAPPING.md berücksichtigt.

Wesentliche Felder:

IFGK:
- IFGKTSTP TIMESTAMP
- IFGKIFFI CHAR(5)
- IFGKIFNR CHAR(32)
- IFGKERUS CHAR(10)
- IFGKERDA NUMERIC(8,0)
- IFGKEZEI NUMERIC(6,0)
- IFGKFIRM CHAR(2)
- IFGKAGJJ NUMERIC(4,0)
- IFGKAGNR CHAR(6)
- IFGKAGAR CHAR(3)
- IFGKIFST/IFKO/IFPO CHAR(2)
- IFGKKDNR CHAR(10)
- IFGKGBDA NUMERIC(8,0)
- IFGKFREI CHAR(512)

IFGP:
- IFGPIFGK TIMESTAMP
- IFGPIFGP NUMERIC(4,0)
- IFGPTSTP TIMESTAMP
- IFGPIFFI CHAR(5)
- IFGPIFNR CHAR(32)
- IFGPERUS CHAR(10)
- IFGPERDA NUMERIC(8,0)
- IFGPEZEI NUMERIC(6,0)
- IFGPIFST/IFPO CHAR(2)
- IFGPTENR CHAR(15)
- IFGPMENG NUMERIC(11,2)
- IFGPMEIN CHAR(1)
- IFGPPRAR CHAR(3)
- IFGPPREI NUMERIC(11,3)
- IFGPPDIM CHAR(1)
- IFGPFREI CHAR(512)

## Technischer Stack

- Windows PowerShell 5.1
- REST/JSON Add-API
- DPAPI-Secrets
- optional IBM i Access ODBC
- optional WinSCP .NET SFTP
- Semikolon-CSV

## Sicherheitsmodell

DryRun ist Standard.

Echter Schreibzugriff erfordert:
- -Execute
- Api.TestMode=false

Solange Api.AllowProductionTables=false:
- nur TVPFTEST.IFGK
- nur TVPFTEST.IFGP

ODBC-Verifikation ist für Scheduler-Betrieb empfohlen.

## Bekannte offene Punkte

- IF-Firmen-Nr.
- Preisregel bei Rabatt
- freie Lieferadresse / IFGKVSNR
- finaler automatischer Aufruf der Trend-Übernahme
- Produktivfreigabe
