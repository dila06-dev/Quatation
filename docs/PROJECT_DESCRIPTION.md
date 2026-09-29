# Projektbeschreibung – Workist → Trend IFGK / IFGP

## Ziel

Die bisherige direkte Befüllung von `AGKO` und `AGPO` wird vollständig ersetzt.

Neue Zielarchitektur:

```text
Workist CSV
   |
   v
PowerShell-Projekt
   |
   +--> IFGK  (Interface-Kopf)
   |
   +--> IFGP  (Interface-Positionen)
            |
            v
Trend-Übernahmeprogramme
GNIFGK / GNIFGP bzw. dokumentierte Batchübernahme
            |
            v
AGKO / AGPO
```

## Warum die Architektur geändert wird

Trend stellt für KD-Angebote/Rahmenverträge einen eigenen IF-Briefkasten bereit.
Die Schnittstelle soll deshalb die IF-Dateien befüllen und die fachliche
Erzeugung der Angebotsdateien Trend überlassen.

## Schlüssel

### IFGK

Primär:
- `IFGKTSTP` eindeutig

Alternativ:
- `IFGKIFFI + IFGKIFNR` eindeutig

Im Projekt:
- `IFGKIFFI` = konfigurierte IF-Firmen-Nr.
- `IFGKIFNR` = `quote_unique_id`

Damit ist die Workist-ID direkt als externer Interface-Schlüssel nutzbar.

### IFGP

Primär:
- `IFGPIFGK + IFGPIFGP`

Zusätzlich:
- `IFGPTSTP` eindeutig

Alternativ:
- `IFGPIFFI + IFGPIFNR + IFGPIFGP`

Im Projekt:
- `IFGPIFGK` = exakt `IFGKTSTP`
- `IFGPIFGP` = 1,2,3,...
- `IFGPIFFI` = Kopf-IF-Firma
- `IFGPIFNR` = Kopf-IF-Nr.

## Initialstatus

IFGK:
- IFGKIFST = 00
- IFGKIFKO = 00
- IFGKIFPO = 00

IFGP:
- IFGPIFST = 10
- IFGPIFPO = 10

## Ergebnisfelder

`IFGKAGJJ`, `IFGKAGNR`, `IFGPAGJJ`, `IFGPAGNR`, `IFGPAGPO` werden bei der
Neuanlage auf 0/leer gesetzt. Das Projekt vergibt keine AGKO-/AGPO-Nummern mehr.

## Erfassung

Kopf und Positionen erhalten pro Angebotsgruppe dasselbe:
- Erfassungsdatum
- Erfassungszeit
- Erfassungsuser

Die eigentlichen Timestamp-Schlüssel werden separat eindeutig erzeugt.

## Sicherheit

- DryRun ist Standard.
- Produktivtabellen TVPF.* sind standardmäßig blockiert.
- `-Execute` plus `Api.TestMode=false` ist für echte INSERTs nötig.
- Die IF-Firmen-Nr. muss explizit gesetzt werden.
- Bei unklarer Preisabbildung wird abgebrochen.
- Freie Lieferadresse wird nicht erfunden/gemappt.
- Trend-Übernahmeprogramme werden noch nicht automatisch gestartet, weil deren
  technische Aufrufparameter nicht Bestandteil der gelieferten Dokumentation sind.
