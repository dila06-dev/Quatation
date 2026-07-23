# Analyse der erweiterten Vorbelegung

## Ausgangspunkt

Die letzte Zeile der Excel-Auswertung entspricht dem über die API erzeugten
Angebot `2026/103015`.

Der Datensatz wurde erfolgreich in `TVPFTEST.AGKO` und `TVPFTEST.AGPO`
geschrieben. Im Vergleich zu den 16 vorhandenen Trend-Angeboten waren einige
Felder jedoch noch nicht fachlich oder technisch vorbelegt.

## Automatisch ergänzte stabile Werte

### AGKO

| Feld | Neuer Default | Vergleich |
|---|---:|---|
| `GKPROG` | `TRAGKO` | in allen 16 vorhandenen AGKO-Zeilen |
| `GKBIBL` | `TVPP1` | 15 von 16 Zeilen; eine ältere Zeile `TVPP` |

### AGPO

| Feld | Neuer Default | Vergleich |
|---|---:|---|
| `GPPROG` | `TRAGPO` | alle vorhandenen, nicht leeren Werte |
| `GPBIBL` | `TVPP` | alle vorhandenen, nicht leeren Werte |
| `GPBOKZ` | `J` | 16 von 16 |
| `GPTXKZ` | `N` | 16 von 16 |
| `GPEMKZ` | `N` | 16 von 16 |
| `GPAFKZ` | `J` | 16 von 16 |
| `GPMWCD` | `16` | 16 von 16 |
| `GPLTKZ` | `N` | 16 von 16 |
| `GPGSKZ` | `J` | 16 von 16 |

## Bewusst nicht pauschal vorbelegt

### Artikelstammdaten

Diese Felder unterscheiden sich je Artikel und müssen später über einen
Artikelstamm-Service oder ein bestätigtes SQL-Query ermittelt werden:

- `GPTBZ1`
- `GPTBZ2`
- `GPPRGR`
- `GPDIEK`

Die Excel-Daten zeigen beispielsweise unterschiedliche Werte für `GPPRGR`
und `GPDIEK` je Artikel. Ein fester Default wäre fachlich falsch.

### Variables Kennzeichen

`GPDSKZ` ist in den Vergleichsdaten nicht konstant:

- zwölf Zeilen: `N`
- vier Zeilen: `J`

Das Feld wird daher nicht automatisch gesetzt, bis seine fachliche Regel
bekannt ist.

### Technische Protokollfelder

Folgende Felder sind benutzer-, Job- oder Laufzeitabhängig und werden nicht
blind mit einem historischen Wert vorbelegt:

- `GKLOCK`, `GKJNAM`, `GKJDAT`, `GKJZEI`, `GKUSER`
- `GPLOCK`, `GPJNAM`, `GPJDAT`, `GPJZEI`, `GPUSER`

Eine spätere Erweiterung kann dafür einen bestätigten technischen Benutzer,
Jobnamen sowie aktuelles Datum und aktuelle Uhrzeit verwenden.

## Konfigurationsprinzip

Die Zusatzwerte stehen in `QuoteImport.config.psd1`:

```powershell
AdditionalHeaderFields = @{
    GKPROG = 'TRAGKO'
    GKBIBL = 'TVPP1'
}

AdditionalPositionFields = @{
    GPPROG = 'TRAGPO'
    GPBIBL = 'TVPP'
    GPBOKZ = 'J'
    GPTXKZ = 'N'
    GPEMKZ = 'N'
    GPAFKZ = 'J'
    GPMWCD = '16'
    GPLTKZ = 'N'
    GPGSKZ = 'J'
}
```

Die Werte können später erweitert werden, ohne die Kernfunktion
`New-QuoteHeaderData` oder `New-QuotePositionData` erneut umzubauen.

Das Modul verhindert, dass Zusatzfelder bereits vorhandene Kernfelder
überschreiben.

## Technische Laufzeitfelder ab Version 12

Folgende Felder werden nun pro Angebot automatisch vorbelegt:

| AGKO | AGPO | Quelle |
|---|---|---|
| `GKJNAM` | `GPJNAM` | `TechnicalRuntimeFields.JobName`, Standard `APICAL` |
| `GKJDAT` | `GPJDAT` | Tagesdatum `yyyyMMdd`, zum Beispiel `20260722` |
| `GKJZEI` | `GPJZEI` | Uhrzeit `HHmmss`, zum Beispiel `155924` |
| `GKUSER` | `GPUSER` | `TechnicalRuntimeFields.User`, Standard `DILA` |

Datum und Uhrzeit werden nur einmal pro Angebotsgruppe erzeugt. Dadurch stimmen
AGKO und sämtliche AGPO-Positionen exakt überein.

Über `DateMode` und `TimeMode` kann zwischen aktuellen und festen Werten
umgeschaltet werden.
