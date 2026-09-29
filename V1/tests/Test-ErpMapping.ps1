#requires -Version 5.1
# Offline-Verhaltenstest: keine API, kein SFTP, keine IBM-i-Schreibzugriffe.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$module = Import-Module (Join-Path $root 'modules/QuoteImport.Common.psm1') -Force -PassThru
$mapping = Import-PowerShellDataFile (Join-Path $root 'config/QuoteImport.mapping.psd1')
& $module {
    param($m, $reference)
    function Assert($Condition, $Message) { if (-not $Condition) { throw $Message } }
    $runtime = @{Date='20260916';Time='090658'}
    $raw = [pscustomobject]@{quote_unique_id='63a6c633';quote_number='WVO-122533';quantity='3,00';gross_unit_price='203,01'}
    $row = @(ConvertTo-CanonicalQuoteRows @($raw) $m.Input.Columns)[0]
    foreach ($rule in @($m.Erp.AGKO)+@($m.Erp.AGPO)) {
        if ($rule.Source -like 'Csv.*') {
            $column = $rule.Source.Substring(4)
            $row.$column = Resolve-ErpValue $rule @{Csv=$row;Runtime=$runtime}
        }
    }
    Test-QuoteGroup @($row) '63a6c633'
    $h = New-ErpPayloadData $m.Erp.AGKO @{Csv=$row;Runtime=$runtime;Number=@{Year=2026;Number=103018};Customer=@{}} ''
    $d = New-ErpPayloadData $m.Erp.AGPO @{Csv=$row;Runtime=$runtime;Header=$h;Position=@{Number=10};Article=@{}} ''
    Assert ($h.Count -eq 44 -and $d.Count -eq 104) 'Feldanzahl falsch'
    Assert ($h.GKKDNR -ceq '001330' -and $h.GKAGNR -ceq '103018') 'Fuehrende Nullen/Nummernformat'
    Assert ($h.GKGBDA -eq 20260925 -and $h.GKJDAT -is [int]) 'Datumsfallback/JSON-Typ'
    Assert ($d.GPWAWT -eq 609.03 -and $d.GPNESU -eq 609.03) 'Dezimalkomma/Berechnung'
    Assert ($d.GPTBZ1 -ceq '' -and $d.GPKOW1 -eq 0) 'Leertext/Nullvorbelegung'
    $rule = @{Field='TEST';Source='Csv.x';Type='Decimal';Default=7}
    Assert ((Resolve-ErpValue $rule @{Csv=@{x=0}}) -eq 0) 'Numerische Null wurde ueberschrieben'
    Assert ((Resolve-ErpValue $rule @{Csv=@{x='  '}}) -eq 7) 'Leerwert nicht vorbelegt'
    $failed=$false
    try { Resolve-ErpValue $rule @{Csv=@{x='defekt'}} } catch { $failed=$true }
    Assert $failed 'Ungueltiger vorhandener Wert muss Fehler ausloesen'
    $row.net_unit_price='100'; $d=New-ErpPayloadData $m.Erp.AGPO @{Csv=$row;Header=$h;Position=@{Number=10};Article=@{}} ''
    Assert ($d.GPNESU -eq 300) 'Expliziter Nettopreis hat keinen Vorrang'
    $idRule = $m.Erp.AGKO | Where-Object Field -eq GKFREX
    $failed=$false
    try { Resolve-ErpValue $idRule @{Csv=@{}} } catch { $failed=$true }
    Assert $failed 'Fehlende externe ID muss abbrechen'
    Assert ($h.GKJZEI -is [int] -and $h.GKJZEI -eq 90658) 'Kopf-Uhrzeit muss numerisch sein'
    Assert ($d.GPJZEI -is [int] -and $d.GPJDAT -is [int]) 'Positions-Zeitstempel numerisch'
    Assert ($h.GKLOCK -ceq '' -and $h.GKLFTG -eq 0) 'Neue Kopf-Defaults'
    Assert ($d.GPLOCK -ceq '' -and $d.GPUFK1 -eq 0) 'Neue Positions-Defaults'
    # Serialisierung ebenfalls pruefen: kein String bei numerischen SQL-Feldern.
    $json = $h | ConvertTo-Json -Compress
    Assert ($json -match '"GKJZEI":90658' -and $json -match '"GKJDAT":20260916') 'JSON-Zeitstempel falsch typisiert'
    $timeRule = $m.Erp.AGKO | Where-Object Field -eq GKJZEI
    Assert ((Resolve-ErpValue $timeRule @{Runtime=@{Time='000000'}}) -eq 0) 'Mitternacht falsch'
    $failed=$false
    try { Resolve-ErpValue $timeRule @{Runtime=@{Time='240000'}} } catch { $failed=$true }
    Assert $failed 'Ungueltige HHmmss-Zeit muss scheitern'
    $qtyRule = $m.Erp.AGPO | Where-Object Field -eq GPMENG
    Assert ((Resolve-ErpValue $qtyRule @{Csv=@{quantity='999999999.99'}}) -eq [decimal]'999999999.99') 'Maximalmenge falsch'
    # Nur SQL-Typgrenze pruefen; fachlich positive Menge wird separat validiert.
    Assert ((Resolve-ErpValue $qtyRule @{Csv=@{quantity='-999999999.99'}}) -eq [decimal]'-999999999.99') 'Negative SQL-Grenze falsch'
    foreach ($bad in @('1000000000.00','-1000000000.00','1.001')) {
        $failed=$false
        try { Resolve-ErpValue $qtyRule @{Csv=@{quantity=$bad}} } catch { $failed=$true }
        Assert $failed "Mengen-Grenzpruefung fehlt: $bad"
    }
    $customerRule = $m.Erp.AGKO | Where-Object Field -eq GKKDNR
    Assert ((Resolve-ErpValue $customerRule @{Csv=@{customer_number='1234567890'}}) -ceq '1234567890') '10-stelliger Kunde muss passen'
    $failed=$false
    try { Resolve-ErpValue $customerRule @{Csv=@{customer_number='12345678901'}} } catch { $failed=$true }
    Assert $failed '11-stelliger Kunde muss scheitern'
    # Vollstaendige Feldabdeckung gegen separaten DDL-Auszug.
    foreach ($table in @('AGKO','AGPO')) {
        $ddl = Get-Content -LiteralPath (Join-Path $reference ($table + '.schema.sql')) -Raw
        $expected = @([regex]::Matches($ddl, '(?m)^\s+(G[KP][A-Z0-9]+)\s+(CHAR|NUMERIC)') | ForEach-Object { $_.Groups[1].Value })
        $actual = @($m.Erp[$table] | ForEach-Object { $_.Field })
        Assert (@(Compare-Object $expected $actual).Count -eq 0) "DDL-Abdeckung $table falsch"
    }
    Write-Host 'OK: ERP-Mapping, Fallbacks, JSON-Typen und Berechnungen.' -ForegroundColor Green
} $mapping (Join-Path $root 'reference')
