#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Cursor für feste Testnummern; wird pro PowerShell-Prozess einmal initialisiert.
$script:FixedNumberCursor = $null

<#
.SYNOPSIS
    Gemeinsames Modul für den Import von Angebotsdaten aus CSV nach AGKO/AGPO.

.DESCRIPTION
    Dieses Modul enthält:
      - einheitliches Logging,
      - Secret-/Konfigurations-Hilfsfunktionen,
      - robuste Datums- und Zahlenkonvertierung,
      - HTTP-Aufrufe zur IBM-i-API,
      - Kunden- und Artikelstamm-Lookups,
      - sichere Nummernkreis-Anforderung,
      - CSV-Validierung,
      - Mapping und Import nach AGKO (Kopf) und AGPO (Positionen).

    Wichtige Sicherheitsentscheidung:
    Die Angebotsnummer wird NICHT über MAX(GKAGNN) + 1 ermittelt. Dieses Verfahren
    wäre bei parallelen Importen nicht transaktionssicher und könnte doppelte
    Schlüssel erzeugen. Im Produktivbetrieb muss deshalb ein atomarer
    Nummernkreis-Endpunkt verwendet werden.
#>

function Get-ConfigValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Object,
        [Parameter(Mandatory)] [string] $Name,
        $Default = $null
    )

    if ($null -eq $Object) {
        return $Default
    }

    if ($Object -is [System.Collections.IDictionary]) {
        foreach ($key in $Object.Keys) {
            if ([string]$key -ieq $Name) {
                return $Object[$key]
            }
        }
        return $Default
    }

    $property = $Object.PSObject.Properties |
        Where-Object { $_.Name -ieq $Name } |
        Select-Object -First 1

    if ($null -eq $property) {
        return $Default
    }

    return $property.Value
}

function Ensure-Directory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw 'Ein leerer Verzeichnispfad wurde übergeben.'
    }

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        New-Item -Path $Path -ItemType Directory -Force | Out-Null
    }
}

function Initialize-QuoteImportLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $LogPath
    )

    $directory = Split-Path -Path $LogPath -Parent
    if (-not [string]::IsNullOrWhiteSpace($directory)) {
        Ensure-Directory -Path $directory
    }

    $separator = '=' * 100
    @(
        $separator
        "RUN START: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        $separator
    ) | Out-File -LiteralPath $LogPath -Encoding utf8 -Append
}

function Write-QuoteLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Message,
        [ValidateSet('DEBUG', 'INFO', 'WARN', 'ERROR')]
        [string] $Level = 'INFO',
        [Parameter(Mandatory)] [string] $LogPath
    )

    $line = '[{0}] [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message

    switch ($Level) {
        'ERROR' { Write-Host $line -ForegroundColor Red }
        'WARN'  { Write-Host $line -ForegroundColor Yellow }
        'DEBUG' { Write-Host $line -ForegroundColor DarkGray }
        default { Write-Host $line }
    }

    try {
        $directory = Split-Path -Path $LogPath -Parent
        if (-not [string]::IsNullOrWhiteSpace($directory)) {
            Ensure-Directory -Path $directory
        }
        Add-Content -LiteralPath $LogPath -Value $line -Encoding utf8
    }
    catch {
        Write-Warning "Logdatei konnte nicht geschrieben werden: $LogPath. Ursache: $($_.Exception.Message)"
    }
}


function Read-ApiBearerToken {
    <#
    .SYNOPSIS
        Fragt einen Bearer-Token verdeckt über die Konsole ab.

    .DESCRIPTION
        Die Eingabe erfolgt mit Read-Host -AsSecureString. Der Token wird nicht
        angezeigt und nicht protokolliert. Für den HTTP-Authorization-Header muss
        er innerhalb des aktuellen PowerShell-Prozesses kurzzeitig als Klartext
        bereitgestellt werden. Er wird nicht in eine Datei geschrieben.

        Diese Funktion eignet sich für interaktive Tests und manuelle Läufe.
        Ein unbeaufsichtigter Task Scheduler darf nicht auf eine Eingabe warten;
        dort sollte weiterhin BearerTokenFile verwendet werden.
    #>
    [CmdletBinding()]
    param(
        [string] $Prompt = 'API Bearer Token'
    )

    $secureToken = Read-Host -Prompt $Prompt -AsSecureString

    if ($null -eq $secureToken -or $secureToken.Length -eq 0) {
        throw 'Es wurde kein API Bearer Token eingegeben.'
    }

    $bstr = [IntPtr]::Zero

    try {
        $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)
        $plainToken = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)

        if ([string]::IsNullOrWhiteSpace($plainToken)) {
            throw 'Der eingegebene API Bearer Token ist leer.'
        }

        return $plainToken
    }
    finally {
        if ($bstr -ne [IntPtr]::Zero) {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
        }

        $secureToken = $null
    }
}

function Get-ProtectedSecret {
    <#
    .SYNOPSIS
        Liest einen per ConvertFrom-SecureString geschützten Wert.

    .NOTES
        Ohne expliziten Schlüssel ist die Datei an Windows-Benutzer und Rechner
        gebunden. Der geplante Task muss daher unter demselben Benutzer laufen,
        unter dem die Secret-Datei erzeugt wurde.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Secret-Datei nicht gefunden: $Path"
    }

    try {
        # Out-File und Set-Content können am Dateiende einen Zeilenumbruch
        # hinterlassen. ConvertTo-SecureString erwartet ausschließlich die
        # verschlüsselte Zeichenfolge, daher wird der Inhalt bereinigt.
        $encryptedValue = (
            Get-Content `
                -LiteralPath $Path `
                -Raw `
                -ErrorAction Stop
        ).Trim()

        if ([string]::IsNullOrWhiteSpace($encryptedValue)) {
            throw 'Die Secret-Datei ist leer.'
        }

        $secureString = ConvertTo-SecureString `
            -String $encryptedValue `
            -ErrorAction Stop

        $credential = New-Object System.Management.Automation.PSCredential(
            'secret',
            $secureString
        )

        $plainValue = $credential.GetNetworkCredential().Password

        if ([string]::IsNullOrWhiteSpace($plainValue)) {
            throw 'Die Secret-Datei enthält keinen verwendbaren Wert.'
        }

        return $plainValue
    }
    catch {
        throw "Secret-Datei konnte nicht entschlüsselt werden: $Path. Ursache: $($_.Exception.Message)"
    }
}

function ConvertTo-LimitedText {
    [CmdletBinding()]
    param(
        [AllowNull()] [object] $Value,
        [Parameter(Mandatory)] [int] $MaxLength,
        [switch] $FailWhenTooLong,
        [string] $FieldName = 'Textfeld'
    )

    $text = if ($null -eq $Value) { '' } else { ([string]$Value).Trim() }

    if ($text.Length -le $MaxLength) {
        return $text
    }

    if ($FailWhenTooLong) {
        throw "$FieldName ist länger als $MaxLength Zeichen: '$text'"
    }

    return $text.Substring(0, $MaxLength)
}

function ConvertTo-TrendDate {
    <#
    .SYNOPSIS
        Konvertiert unterstützte Datumswerte nach yyyyMMdd als Int32.

    .DESCRIPTION
        Unterstützte Eingabeformate:
          - dd.MM.yyyy
          - yyyy-MM-dd
          - yyyyMMdd
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Value,
        [Parameter(Mandatory)] [string] $FieldName
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        throw "Pflichtfeld '$FieldName' enthält kein Datum."
    }

    $formats = @('dd.MM.yyyy', 'yyyy-MM-dd', 'yyyyMMdd')
    $parsed = [datetime]::MinValue
    $culture = [System.Globalization.CultureInfo]::InvariantCulture
    $styles = [System.Globalization.DateTimeStyles]::None

    foreach ($format in $formats) {
        if ([datetime]::TryParseExact($Value.Trim(), $format, $culture, $styles, [ref]$parsed)) {
            return [int]$parsed.ToString('yyyyMMdd')
        }
    }

    throw "Ungültiges Datum in '$FieldName': '$Value'. Erwartet wird dd.MM.yyyy, yyyy-MM-dd oder yyyyMMdd."
}

function ConvertTo-DecimalValue {
    <#
    .SYNOPSIS
        Liest Dezimalwerte sowohl mit Punkt als auch mit Komma.
    #>
    [CmdletBinding()]
    param(
        [AllowNull()] [object] $Value,
        [Parameter(Mandatory)] [string] $FieldName,
        [switch] $AllowEmpty,
        [decimal] $DefaultValue = 0
    )

    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) {
        if ($AllowEmpty) {
            return $DefaultValue
        }
        throw "Pflichtfeld '$FieldName' ist leer."
    }

    $text = ([string]$Value).Trim()
    $numberStyles = [System.Globalization.NumberStyles]::Number
    $result = [decimal]0

    $cultures = @(
        [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Globalization.CultureInfo]::GetCultureInfo('de-DE')
    )

    foreach ($culture in $cultures) {
        if ([decimal]::TryParse($text, $numberStyles, $culture, [ref]$result)) {
            return $result
        }
    }

    throw "Ungültiger Dezimalwert in '$FieldName': '$text'."
}

function ConvertTo-CustomerNumber {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Value,
        [int] $MinimumLength = 6
    )

    $customer = $Value.Trim()
    if ([string]::IsNullOrWhiteSpace($customer)) {
        throw 'customer_number ist leer.'
    }

    if ($customer.Length -gt 10) {
        throw "customer_number '$customer' überschreitet die Feldlänge von GKKDNR/GPKDNR (10 Zeichen)."
    }

    if ($customer -match '^\d+$' -and $customer.Length -lt $MinimumLength) {
        $customer = $customer.PadLeft($MinimumLength, '0')
    }

    return $customer
}

function ConvertTo-SqlLiteral {
    [CmdletBinding()]
    param([AllowNull()] [object] $Value)

    if ($null -eq $Value) {
        return ''
    }

    return ([string]$Value).Replace("'", "''")
}

function Test-QualifiedTableName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $TableName
    )

    if ($TableName -notmatch '^[A-Za-z0-9_#$@]+\.[A-Za-z0-9_#$@]+$') {
        throw "Ungültiger Tabellenname '$TableName'. Erwartet wird SCHEMA.TABELLE."
    }
}

function Get-ObjectPropertyValue {
    [CmdletBinding()]
    param(
        [AllowNull()] $Object,
        [Parameter(Mandatory)] [string[]] $Names,
        $Default = $null
    )

    if ($null -eq $Object) {
        return $Default
    }

    foreach ($name in $Names) {
        if ($Object -is [System.Collections.IDictionary]) {
            foreach ($key in $Object.Keys) {
                if ([string]$key -ieq $name) {
                    return $Object[$key]
                }
            }
        }
        else {
            $property = $Object.PSObject.Properties |
                Where-Object { $_.Name -ieq $name } |
                Select-Object -First 1

            if ($null -ne $property) {
                return $property.Value
            }
        }
    }

    return $Default
}

function Get-ApiRows {
    <#
    .SYNOPSIS
        Extrahiert echte Datensätze aus einer API-Antwort.

    .DESCRIPTION
        Unterscheidet ausdrücklich zwischen:

        - Envelope-Feld fehlt
        - Envelope-Feld ist vorhanden und NULL
        - Envelope-Feld ist vorhanden und enthält ein leeres Array
        - Envelope-Feld enthält einen oder mehrere Datensätze

        Diese Unterscheidung ist unter Windows PowerShell 5.1 wichtig:
        Ein Vergleich wie "$null -ne @()" liefert keinen einzelnen Boolean-Wert.
        Dadurch wurde bisher bei {"success":true,"data":[]} fälschlich die
        komplette Antwort-Hülle als ein Datensatz zurückgegeben.
    #>
    [CmdletBinding()]
    param(
        [AllowNull()] $Response
    )

    if ($null -eq $Response) {
        return @()
    }

    if ($Response -is [System.Array]) {
        return @($Response)
    }

    foreach ($propertyName in @('data', 'rows', 'results', 'items')) {
        $propertyFound = $false
        $value = $null

        if ($Response -is [System.Collections.IDictionary]) {
            foreach ($key in $Response.Keys) {
                if ([string]$key -ieq $propertyName) {
                    $propertyFound = $true
                    $value = $Response[$key]
                    break
                }
            }
        }
        else {
            $property = $Response.PSObject.Properties |
                Where-Object { $_.Name -ieq $propertyName } |
                Select-Object -First 1

            if ($null -ne $property) {
                $propertyFound = $true
                $value = $property.Value
            }
        }

        if (-not $propertyFound) {
            continue
        }

        # Das Envelope-Feld existiert ausdrücklich, enthält aber keine Daten.
        if ($null -eq $value) {
            return @()
        }

        if ($value -is [System.Array]) {
            if ($value.Count -eq 0) {
                return @()
            }

            return @($value)
        }

        # Ein einzelnes Objekt im data-Feld wird als genau eine Zeile behandelt.
        return @($value)
    }

    # Nur Antworten ohne bekannte Envelope-Felder werden als direkter
    # Datensatz beziehungsweise direktes Datensatz-Array behandelt.
    return @($Response)
}

function Invoke-QuoteApi {
    <#
    .SYNOPSIS
        Zentraler JSON-API-Wrapper.

    .DESCRIPTION
        Ein HTTP-Aufruf gilt als erfolgreich, wenn Invoke-RestMethod keine Exception
        wirft. Auch eine leere 204-Antwort wird daher korrekt als Erfolg behandelt.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Url,
        [ValidateSet('GET', 'POST', 'PUT', 'PATCH', 'DELETE')]
        [string] $Method = 'POST',
        [AllowNull()] $Body,
        [hashtable] $Headers = @{},
        [Parameter(Mandatory)] [string] $LogPath,
        [string] $Context = '',
        [string] $RequestDumpDirectory = '',
        [string] $DumpFileName = '',
        [int] $TimeoutSeconds = 90,
        [switch] $DryRun
    )

    $json = $null
    if ($null -ne $Body) {
        if ($Body -is [string]) {
            $json = $Body
        }
        else {
            $json = $Body | ConvertTo-Json -Depth 20
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($RequestDumpDirectory) -and
        -not [string]::IsNullOrWhiteSpace($DumpFileName) -and
        $null -ne $json) {

        Ensure-Directory -Path $RequestDumpDirectory
        $safeName = $DumpFileName -replace '[^A-Za-z0-9_.-]', '_'
        $dumpPath = Join-Path $RequestDumpDirectory $safeName
        $json | Out-File -LiteralPath $dumpPath -Encoding utf8 -Force
        Write-QuoteLog -Message "JSON-Dump: $dumpPath" -Level DEBUG -LogPath $LogPath
    }

    Write-QuoteLog -Message "API $Method $Url | $Context | DryRun=$([bool]$DryRun)" -Level DEBUG -LogPath $LogPath

    if ($DryRun) {
        return [pscustomobject]@{
            Success  = $true
            Response = $null
            DryRun   = $true
            Error    = $null
        }
    }

    try {
        $invokeParameters = @{
            Uri         = $Url
            Method      = $Method
            Headers     = $Headers
            ErrorAction = 'Stop'
            TimeoutSec  = $TimeoutSeconds
        }

        if ($null -ne $json) {
            $invokeParameters['Body'] = $json
            $invokeParameters['ContentType'] = 'application/json; charset=utf-8'
        }

        $response = Invoke-RestMethod @invokeParameters

        # Die HTTP-Schicht kann 200 liefern, obwohl die Anwendung selbst
        # success=false meldet. Deshalb wird die JSON-Antwort zusätzlich
        # fachlich bewertet und für die Analyse protokolliert.
        $responseJson = ''

        if ($null -eq $response) {
            $responseJson = '<leere Antwort oder HTTP 204>'
        }
        else {
            try {
                $responseJson = $response |
                    ConvertTo-Json -Depth 20 -Compress
            }
            catch {
                $responseJson = [string]$response
            }
        }

        Write-QuoteLog `
            -Message "API-Antwort bei '$Context': $responseJson" `
            -Level DEBUG `
            -LogPath $LogPath

        if (-not (Test-ApiResponseSuccess -Response $response)) {
            $applicationMessage = [string](Get-ObjectPropertyValue `
                -Object $response `
                -Names @('message', 'MESSAGE', 'error', 'details') `
                -Default 'Die API meldet success=false.')

            Write-QuoteLog `
                -Message "API-Anwendungsfehler bei '$Context': $applicationMessage" `
                -Level ERROR `
                -LogPath $LogPath

            return [pscustomobject]@{
                Success  = $false
                Response = $response
                DryRun   = $false
                Error    = $applicationMessage
            }
        }

        # Einige Add-Endpunkte melden HTTP 200 und STATUS=OK, obwohl wegen
        # aktivem API-Testmodus bewusst kein INSERT erfolgt ist.
        $responseMessage = (
            [string](Get-ObjectPropertyValue `
                -Object $response `
                -Names @('message', 'MESSAGE') `
                -Default '')
        ).Trim()

        if ($Method -ieq 'POST' -and
            $responseMessage -match '(?i)(nothing\s+inserted|not\s+inserted|test\s+mode\s+active|simulation|simulated|dry[\s-]*run)') {
            $simulationError = "Die API hat keinen Datensatz gespeichert: $responseMessage"

            Write-QuoteLog `
                -Message "API-Anwendungsfehler bei '$Context': $simulationError" `
                -Level ERROR `
                -LogPath $LogPath

            return [pscustomobject]@{
                Success  = $false
                Response = $response
                DryRun   = $false
                Error    = $simulationError
            }
        }

        return [pscustomobject]@{
            Success  = $true
            Response = $response
            DryRun   = $false
            Error    = $null
        }
    }
    catch {
        $message = $_.Exception.Message

        try {
            if ($null -ne $_.Exception.Response) {
                $stream = $_.Exception.Response.GetResponseStream()
                if ($null -ne $stream) {
                    $reader = New-Object System.IO.StreamReader($stream)
                    $responseText = $reader.ReadToEnd()
                    if (-not [string]::IsNullOrWhiteSpace($responseText)) {
                        $message = "$message | API-Antwort: $responseText"
                    }
                }
            }
        }
        catch {
            # Das Lesen des Fehlerbodys ist nur eine Zusatzinformation.
        }

        Write-QuoteLog -Message "API-Fehler bei '$Context': $message" -Level ERROR -LogPath $LogPath

        return [pscustomobject]@{
            Success  = $false
            Response = $null
            DryRun   = $false
            Error    = $message
        }
    }
}

function New-ApiHeaders {
    [CmdletBinding()]
    param(
        [AllowEmptyString()] [string] $BearerToken
    )

    $headers = @{
        Accept = 'application/json'
    }

    if (-not [string]::IsNullOrWhiteSpace($BearerToken)) {
        $headers['Authorization'] = "Bearer $BearerToken"
    }

    return $headers
}


function New-UrlWithQueryParameters {
    <#
    .SYNOPSIS
        Erstellt eine GET-URL mit URL-codierten Filterparametern.

    .EXAMPLE
        AGKO_select?GKAGJJ=2026&GKAGNR=100004
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $BaseUrl,
        [Parameter(Mandatory)] [System.Collections.IDictionary] $Parameters
    )

    if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
        throw 'Für den GET-Select wurde keine URL übergeben.'
    }

    $pairs = New-Object System.Collections.Generic.List[string]

    foreach ($key in @($Parameters.Keys | Sort-Object)) {
        $value = $Parameters[$key]

        if ($null -eq $value -or [string]::IsNullOrWhiteSpace([string]$value)) {
            continue
        }

        $encodedKey = [System.Uri]::EscapeDataString([string]$key)
        $encodedValue = [System.Uri]::EscapeDataString([string]$value)
        $pairs.Add("$encodedKey=$encodedValue")
    }

    if ($pairs.Count -eq 0) {
        return $BaseUrl
    }

    $separator = if ($BaseUrl.Contains('?')) { '&' } else { '?' }
    return "$BaseUrl$separator$($pairs.ToArray() -join '&')"
}

function Test-ApiResponseSuccess {
    [CmdletBinding()]
    param(
        [AllowNull()] $Response
    )

    if ($null -eq $Response) {
        return $true
    }

    $value = Get-ObjectPropertyValue `
        -Object $Response `
        -Names @('success') `
        -Default $null

    if ($null -eq $value) {
        return $true
    }

    if ($value -is [bool]) {
        return [bool]$value
    }

    return (([string]$value).Trim() -notmatch '^(false|0|no)$')
}

function Invoke-FilteredSelect {
    <#
    .SYNOPSIS
        Ruft einen IBM-i-Service per HTTP GET und Feldfiltern auf.

    .DESCRIPTION
        Der Endpunkt erwartet keine SQL-Anweisung. Die Filter werden als
        Query-Parameter übertragen. Die Antwort darf das Format
        {"success":true,"data":[...]} besitzen.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $SelectUrl,
        [Parameter(Mandatory)] [System.Collections.IDictionary] $Filters,
        [Parameter(Mandatory)] [hashtable] $Headers,
        [Parameter(Mandatory)] [string] $LogPath,
        [string] $Context = 'GET SELECT',
        [int] $TimeoutSeconds = 90,
        [switch] $DryRun
    )

    $requestUrl = New-UrlWithQueryParameters `
        -BaseUrl $SelectUrl `
        -Parameters $Filters

    if ($DryRun) {
        Write-QuoteLog `
            -Message "DRY-RUN: GET wird nicht ausgeführt: $requestUrl" `
            -Level DEBUG `
            -LogPath $LogPath

        return @()
    }

    $apiResult = Invoke-QuoteApi `
        -Url $requestUrl `
        -Method GET `
        -Body $null `
        -Headers $Headers `
        -LogPath $LogPath `
        -Context $Context `
        -TimeoutSeconds $TimeoutSeconds

    if (-not $apiResult.Success) {
        throw "GET-SELECT fehlgeschlagen: $($apiResult.Error)"
    }

    if (-not (Test-ApiResponseSuccess -Response $apiResult.Response)) {
        $message = Get-ObjectPropertyValue `
            -Object $apiResult.Response `
            -Names @('message', 'error') `
            -Default 'Der Service meldet success=false.'

        throw "GET-SELECT wurde vom Service abgelehnt: $message"
    }

    $rows = @(Get-ApiRows -Response $apiResult.Response)

    Write-QuoteLog `
        -Message "GET-SELECT '$Context': echte Datensätze in data[] = $($rows.Count)" `
        -Level DEBUG `
        -LogPath $LogPath

    return $rows
}

function Invoke-SelectQuery {
    <#
    .SYNOPSIS
        Optionaler SQL-POST für spätere Stammdatenabfragen.

    .NOTES
        Diese Funktion wird NICHT für AGKO_select verwendet. AGKO_select ist
        ein GET-Service und wird über Invoke-FilteredSelect angesprochen.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Query,
        [AllowEmptyString()] [string] $SqlSelectUrl,
        [Parameter(Mandatory)] [hashtable] $Headers,
        [Parameter(Mandatory)] [string] $LogPath,
        [string] $Context = 'SQL SELECT',
        [int] $TimeoutSeconds = 90,
        [switch] $DryRun
    )

    if ([string]::IsNullOrWhiteSpace($SqlSelectUrl)) {
        throw 'Ein SQL-Query ist konfiguriert, aber Api.SqlSelectUrl ist leer.'
    }

    if ($DryRun) {
        Write-QuoteLog `
            -Message "DRY-RUN: SQL-POST wird nicht ausgeführt: $Query" `
            -Level DEBUG `
            -LogPath $LogPath

        return @()
    }

    $result = Invoke-QuoteApi `
        -Url $SqlSelectUrl `
        -Method POST `
        -Body @{ query = $Query } `
        -Headers $Headers `
        -LogPath $LogPath `
        -Context $Context `
        -TimeoutSeconds $TimeoutSeconds

    if (-not $result.Success) {
        throw "SQL-SELECT fehlgeschlagen: $($result.Error)"
    }

    return @(Get-ApiRows -Response $result.Response)
}

function Get-CustomerMasterData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $CustomerNumber,
        [Parameter(Mandatory)] [hashtable] $MasterDataConfig,
        [AllowEmptyString()] [string] $SqlSelectUrl,
        [Parameter(Mandatory)] [hashtable] $Headers,
        [Parameter(Mandatory)] [string] $LogPath,
        [int] $TimeoutSeconds = 90,
        [switch] $DryRun
    )

    $strict = [bool](Get-ConfigValue -Object $MasterDataConfig -Name 'Strict' -Default $false)
    $template = [string](Get-ConfigValue -Object $MasterDataConfig -Name 'CustomerQueryTemplate' -Default '')

    $fallback = Get-ConfigValue -Object $MasterDataConfig -Name 'CustomerFallback' -Default @{}
    $result = [ordered]@{
        CurrencyCode       = [string](Get-ConfigValue -Object $fallback -Name 'CurrencyCode' -Default 'EUR')
        ShippingCondition  = [string](Get-ConfigValue -Object $fallback -Name 'ShippingCondition' -Default '')
        DeliveryCondition  = [string](Get-ConfigValue -Object $fallback -Name 'DeliveryCondition' -Default '')
        PaymentCondition   = [string](Get-ConfigValue -Object $fallback -Name 'PaymentCondition' -Default '')
        LanguageCode       = [string](Get-ConfigValue -Object $fallback -Name 'LanguageCode' -Default 'D')
        Source             = 'Fallback'
    }

    if ([string]::IsNullOrWhiteSpace($template)) {
        if ($strict) {
            throw 'MasterData.Strict=true, aber CustomerQueryTemplate ist nicht konfiguriert.'
        }

        Write-QuoteLog -Message "Kein Kundenstamm-Query konfiguriert. Fallbackwerte werden für Kunde $CustomerNumber verwendet." -Level WARN -LogPath $LogPath
        return [pscustomobject]$result
    }

    $query = $template.Replace('{{CUSTOMER_NUMBER}}', (ConvertTo-SqlLiteral $CustomerNumber))
    $rows = @(Invoke-SelectQuery -Query $query -SqlSelectUrl $SqlSelectUrl -Headers $Headers -LogPath $LogPath -Context "Kundenstamm $CustomerNumber" -TimeoutSeconds $TimeoutSeconds -DryRun:$DryRun)

    if ($rows.Count -eq 0) {
        if ($strict -and -not $DryRun) {
            throw "Kunde $CustomerNumber wurde über CustomerQueryTemplate nicht gefunden."
        }

        Write-QuoteLog -Message "Kunde $CustomerNumber nicht gefunden. Fallbackwerte werden verwendet." -Level WARN -LogPath $LogPath
        return [pscustomobject]$result
    }

    $row = $rows[0]
    $result.CurrencyCode      = [string](Get-ObjectPropertyValue -Object $row -Names @('CURRENCY_CODE', 'GKWACD') -Default $result.CurrencyCode)
    $result.ShippingCondition = [string](Get-ObjectPropertyValue -Object $row -Names @('SHIPPING_CONDITION', 'GKVSBD') -Default $result.ShippingCondition)
    $result.DeliveryCondition = [string](Get-ObjectPropertyValue -Object $row -Names @('DELIVERY_CONDITION', 'GKLIBD') -Default $result.DeliveryCondition)
    $result.PaymentCondition  = [string](Get-ObjectPropertyValue -Object $row -Names @('PAYMENT_CONDITION', 'GKZABD') -Default $result.PaymentCondition)
    $result.LanguageCode      = [string](Get-ObjectPropertyValue -Object $row -Names @('LANGUAGE_CODE', 'GKSPCD') -Default $result.LanguageCode)
    $result.Source            = 'CustomerMaster'

    return [pscustomobject]$result
}

function Get-ArticleMasterData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $ArticleNumber,
        [Parameter(Mandatory)] [hashtable] $MasterDataConfig,
        [AllowEmptyString()] [string] $SqlSelectUrl,
        [Parameter(Mandatory)] [hashtable] $Headers,
        [Parameter(Mandatory)] [string] $LogPath,
        [int] $TimeoutSeconds = 90,
        [switch] $DryRun
    )

    $strict = [bool](Get-ConfigValue -Object $MasterDataConfig -Name 'Strict' -Default $false)
    $template = [string](Get-ConfigValue -Object $MasterDataConfig -Name 'ArticleQueryTemplate' -Default '')

    $fallback = Get-ConfigValue -Object $MasterDataConfig -Name 'ArticleFallback' -Default @{}
    $result = [ordered]@{
        Description1 = [string](Get-ConfigValue -Object $fallback -Name 'Description1' -Default '')
        Description2 = [string](Get-ConfigValue -Object $fallback -Name 'Description2' -Default '')
        QuantityUnit = [string](Get-ConfigValue -Object $fallback -Name 'QuantityUnit' -Default 'S')
        PriceUnit    = [string](Get-ConfigValue -Object $fallback -Name 'PriceUnit' -Default 'S')
        Source       = 'Fallback'
    }

    if ([string]::IsNullOrWhiteSpace($template)) {
        if ($strict) {
            throw 'MasterData.Strict=true, aber ArticleQueryTemplate ist nicht konfiguriert.'
        }

        Write-QuoteLog -Message "Kein Artikelstamm-Query konfiguriert. Fallbackwerte werden für Artikel $ArticleNumber verwendet." -Level WARN -LogPath $LogPath
        return [pscustomobject]$result
    }

    $query = $template.Replace('{{ARTICLE_NUMBER}}', (ConvertTo-SqlLiteral $ArticleNumber))
    $rows = @(Invoke-SelectQuery -Query $query -SqlSelectUrl $SqlSelectUrl -Headers $Headers -LogPath $LogPath -Context "Artikelstamm $ArticleNumber" -TimeoutSeconds $TimeoutSeconds -DryRun:$DryRun)

    if ($rows.Count -eq 0) {
        if ($strict -and -not $DryRun) {
            throw "Artikel $ArticleNumber wurde über ArticleQueryTemplate nicht gefunden."
        }

        Write-QuoteLog -Message "Artikel $ArticleNumber nicht gefunden. Fallbackwerte werden verwendet." -Level WARN -LogPath $LogPath
        return [pscustomobject]$result
    }

    $row = $rows[0]
    $result.Description1 = [string](Get-ObjectPropertyValue -Object $row -Names @('DESCRIPTION1', 'GPTBZ1') -Default $result.Description1)
    $result.Description2 = [string](Get-ObjectPropertyValue -Object $row -Names @('DESCRIPTION2', 'GPTBZ2') -Default $result.Description2)
    $result.QuantityUnit = [string](Get-ObjectPropertyValue -Object $row -Names @('QUANTITY_UNIT', 'GPMEIN') -Default $result.QuantityUnit)
    $result.PriceUnit    = [string](Get-ObjectPropertyValue -Object $row -Names @('PRICE_UNIT', 'GPMEPR') -Default $result.PriceUnit)
    $result.Source       = 'ArticleMaster'

    return [pscustomobject]$result
}

function Get-NextQuoteNumber {
    <#
    .SYNOPSIS
        Reserviert eine eindeutige Angebotsnummer.

    .DESCRIPTION
        Mode=Api:
          Ruft einen atomaren Nummernkreis-Endpunkt auf. Erwartete Antwortfelder:
          year/documentYear/GKAGJJ und number/documentNumber/nextNumber/GKAGNN.
          Die Felder dürfen direkt oder unter "data" stehen.

        Mode=Fixed:
          Ausgehend von FixedStartNumber wird pro Angebotsgruppe hochgezählt.
          Mit AutoFindNextFree=true kann im kontrollierten TVPFTEST-Modus über
          AGKO_select die nächste freie Nummer gesucht werden.

          Diese Variante ist NICHT atomar und NICHT produktionssicher.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [hashtable] $NumberRangeConfig,
        [Parameter(Mandatory)] [string] $Company,
        [Parameter(Mandatory)] [string] $DocumentType,
        [Parameter(Mandatory)] [string] $ExternalReference,
        [Parameter(Mandatory)] [hashtable] $Headers,
        [Parameter(Mandatory)] [string] $LogPath,
        [int] $TimeoutSeconds = 90,
        [switch] $TestMode,
        [switch] $DryRun
    )

    $mode = [string](Get-ConfigValue -Object $NumberRangeConfig -Name 'Mode' -Default 'Api')

    if ($mode -ieq 'Fixed') {
        $allowFixedInExecute = [bool](Get-ConfigValue `
            -Object $NumberRangeConfig `
            -Name 'AllowFixedInExecute' `
            -Default $false)

        if (-not $TestMode -and -not $DryRun -and -not $allowFixedInExecute) {
            throw 'NumberRange.Mode=Fixed ist außerhalb von TestMode/DryRun nur mit NumberRange.AllowFixedInExecute=$true zulässig.'
        }

        if (-not $TestMode -and -not $DryRun -and $allowFixedInExecute) {
            Write-QuoteLog `
                -Message 'SICHERHEITSHINWEIS: Fester Nummernkreis wird bei Execute=True und Api.TestMode=False verwendet. Dies ist ausschließlich für einen kontrollierten Testtabellen-Import zulässig.' `
                -Level WARN `
                -LogPath $LogPath
        }

        $fixedYear = [int](Get-ConfigValue -Object $NumberRangeConfig -Name 'FixedYear' -Default (Get-Date).Year)
        $fixedStart = [int](Get-ConfigValue -Object $NumberRangeConfig -Name 'FixedStartNumber' -Default 1)

        if ($null -eq $script:FixedNumberCursor) {
            $script:FixedNumberCursor = $fixedStart
        }
        else {
            $script:FixedNumberCursor++
        }

        if ($script:FixedNumberCursor -gt 999999) {
            throw 'Die sechsstellige Angebotsnummer überschreitet 999999.'
        }

        return [pscustomobject]@{
            Year   = $fixedYear
            Number = $script:FixedNumberCursor
            Source = 'FixedTestNumber'
        }
    }

    if ($mode -ine 'Api') {
        throw "Unbekannter NumberRange.Mode '$mode'. Zulässig sind Api und Fixed."
    }

    $url = [string](Get-ConfigValue -Object $NumberRangeConfig -Name 'Url' -Default '')
    if ([string]::IsNullOrWhiteSpace($url)) {
        throw 'NumberRange.Mode=Api, aber NumberRange.Url ist leer. Ein atomarer Nummernkreis-Endpunkt ist erforderlich.'
    }

    $method = [string](Get-ConfigValue -Object $NumberRangeConfig -Name 'Method' -Default 'POST')
    $requestedYear = (Get-Date).Year

    $body = [ordered]@{
        company           = $Company
        documentType      = $DocumentType
        year              = $requestedYear
        externalReference = $ExternalReference
        testMode          = [bool]$TestMode
    }

    $apiResult = Invoke-QuoteApi `
        -Url $url `
        -Method $method `
        -Body $body `
        -Headers $Headers `
        -LogPath $LogPath `
        -Context "Nummernkreis für $ExternalReference" `
        -TimeoutSeconds $TimeoutSeconds `
        -DryRun:$DryRun

    if (-not $apiResult.Success) {
        throw "Nummernkreis konnte nicht reserviert werden: $($apiResult.Error)"
    }

    if ($DryRun) {
        throw 'DryRun mit NumberRange.Mode=Api liefert keine echte Nummer. Für reine JSON-Tests NumberRange.Mode=Fixed verwenden.'
    }

    $response = $apiResult.Response
    $data = Get-ObjectPropertyValue -Object $response -Names @('data') -Default $response

    $numberValue = Get-ObjectPropertyValue -Object $data -Names @('number', 'documentNumber', 'nextNumber', 'GKAGNN')
    $yearValue = Get-ObjectPropertyValue -Object $data -Names @('year', 'documentYear', 'GKAGJJ') -Default $requestedYear

    if ($null -eq $numberValue) {
        throw 'Nummernkreis-Antwort enthält kein Feld number/documentNumber/nextNumber/GKAGNN.'
    }

    $number = [int]$numberValue
    $year = [int]$yearValue

    if ($number -lt 1 -or $number -gt 999999) {
        throw "Ungültige Angebotsnummer aus Nummernkreis: $number."
    }

    return [pscustomobject]@{
        Year   = $year
        Number = $number
        Source = 'ApiNumberRange'
    }
}

function Test-QuoteCsvSchema {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object[]] $Rows
    )

    $requiredColumns = @(
        'quote_unique_id',
        'quote_number',
        'customer_number',
        'article_number',
        'quantity',
        'quote_date',
        'delivery_company_name1',
        'delivery_company_name2',
        'delivery_company_name3',
        'delivery_address',
        'delivery_address_misc',
        'delivery_zip_code',
        'delivery_city',
        'delivery_country',
        'delivery_email',
        'delivery_phone',
        'field_sales_id',
        'reference_2',
        'valid_from',
        'valid_to',
        'discount',
        'gross_unit_price',
        'net_unit_price'
    )

    if ($Rows.Count -eq 0) {
        throw 'Die CSV-Datei enthält keine Datenzeilen.'
    }

    $actualColumns = @($Rows[0].PSObject.Properties.Name)
    $missing = @($requiredColumns | Where-Object { $_ -notin $actualColumns })

    if ($missing.Count -gt 0) {
        throw "CSV-Spalten fehlen: $($missing -join ', ')"
    }
}

function Test-QuoteGroup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object[]] $Rows,
        [Parameter(Mandatory)] [string] $ExternalId
    )

    if ([string]::IsNullOrWhiteSpace($ExternalId)) {
        throw 'quote_unique_id ist leer.'
    }

    [void](ConvertTo-LimitedText -Value $ExternalId -MaxLength 20 -FailWhenTooLong -FieldName 'quote_unique_id')

    $first = $Rows[0]
    $headerFields = @('customer_number', 'quote_number', 'quote_date', 'valid_from', 'valid_to', 'reference_2')

    foreach ($field in $headerFields) {
        $expected = [string](Get-ObjectPropertyValue -Object $first -Names @($field) -Default '')
        foreach ($row in $Rows) {
            $current = [string](Get-ObjectPropertyValue -Object $row -Names @($field) -Default '')
            if ($current -ne $expected) {
                throw "quote_unique_id '$ExternalId' enthält unterschiedliche Kopfwerte im Feld '$field'."
            }
        }
    }

    $quoteDate = ConvertTo-TrendDate -Value ([string]$first.quote_date) -FieldName 'quote_date'
    $validFrom = ConvertTo-TrendDate -Value ([string]$first.valid_from) -FieldName 'valid_from'
    $validTo = ConvertTo-TrendDate -Value ([string]$first.valid_to) -FieldName 'valid_to'

    if ($validTo -lt $validFrom) {
        throw "valid_to liegt vor valid_from für quote_unique_id '$ExternalId'."
    }

    foreach ($row in $Rows) {
        $article = ([string]$row.article_number).Trim()
        if ([string]::IsNullOrWhiteSpace($article)) {
            throw "article_number ist leer für quote_unique_id '$ExternalId'."
        }
        if ($article.Length -gt 15) {
            throw "article_number '$article' überschreitet 15 Zeichen."
        }

        $quantity = ConvertTo-DecimalValue -Value $row.quantity -FieldName 'quantity'
        if ($quantity -le 0) {
            throw "quantity muss größer als 0 sein. Artikel: $article"
        }

        $discount = ConvertTo-DecimalValue -Value $row.discount -FieldName 'discount' -AllowEmpty -DefaultValue 0
        if ($discount -lt 0 -or $discount -gt 100) {
            throw "discount muss zwischen 0 und 100 liegen. Artikel: $article"
        }

        $grossEmpty = [string]::IsNullOrWhiteSpace([string]$row.gross_unit_price)
        $netEmpty = [string]::IsNullOrWhiteSpace([string]$row.net_unit_price)
        if ($grossEmpty -and $netEmpty) {
            throw "Für Artikel '$article' fehlt gross_unit_price und net_unit_price."
        }
    }
}

function Get-ResponsibleCode {
    [CmdletBinding()]
    param(
        [AllowNull()] [object] $CsvValue,
        [Parameter(Mandatory)] [string] $DefaultValue,
        [Parameter(Mandatory)] [string] $LogPath
    )

    $value = if ($null -eq $CsvValue) { '' } else { ([string]$CsvValue).Trim() }

    if ([string]::IsNullOrWhiteSpace($value)) {
        return $DefaultValue
    }

    if ($value.Length -gt 3) {
        Write-QuoteLog -Message "field_sales_id '$value' passt nicht in das dreistellige Feld GKSABE/GPSABE. Default '$DefaultValue' wird verwendet." -Level WARN -LogPath $LogPath
        return $DefaultValue
    }

    return $value
}

function Get-ExistingQuoteByNumber {
    <#
    .SYNOPSIS
        Sucht einen AGKO-Datensatz über Angebotsjahr und Angebotsnummer.

    .DESCRIPTION
        Der bestätigte AGKO_select-Endpunkt unterstützt ausschließlich das
        Filtermuster:

        AGKO_select?GKAGJJ=2026&GKAGNR=100004

        Deshalb darf dieser Endpunkt nicht mit GKFREX, GKFIRM oder anderen
        Filterfeldern aufgerufen werden.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [int] $QuoteYear,
        [Parameter(Mandatory)] [int] $QuoteNumber,
        [Parameter(Mandatory)] [string] $HeaderSelectUrl,
        [Parameter(Mandatory)] [hashtable] $Headers,
        [Parameter(Mandatory)] [string] $LogPath,
        [int] $TimeoutSeconds = 90,
        [switch] $DryRun
    )

    $formattedNumber = '{0:D6}' -f $QuoteNumber

    $rows = @(
        Invoke-FilteredSelect `
            -SelectUrl $HeaderSelectUrl `
            -Filters @{
                GKAGJJ = $QuoteYear
                GKAGNR = $formattedNumber
            } `
            -Headers $Headers `
            -LogPath $LogPath `
            -Context "AGKO-Nummernprüfung $QuoteYear/$formattedNumber" `
            -TimeoutSeconds $TimeoutSeconds `
            -DryRun:$DryRun
    )

    if ($rows.Count -eq 0) {
        Write-QuoteLog `
            -Message "AGKO-Nummernprüfung: $QuoteYear/$formattedNumber ist nicht vorhanden." `
            -Level DEBUG `
            -LogPath $LogPath

        return $null
    }

    $matchingRows = New-Object System.Collections.Generic.List[object]
    $unexpectedRows = New-Object System.Collections.Generic.List[string]

    foreach ($row in $rows) {
        $returnedYear = (
            [string](Get-ObjectPropertyValue `
                -Object $row `
                -Names @('GKAGJJ') `
                -Default '')
        ).Trim()

        $returnedNumber = (
            [string](Get-ObjectPropertyValue `
                -Object $row `
                -Names @('GKAGNR', 'GKAGNN') `
                -Default '')
        ).Trim()

        if ($returnedYear -eq [string]$QuoteYear -and
            $returnedNumber -eq $formattedNumber) {
            $matchingRows.Add($row)
        }
        else {
            $unexpectedRows.Add(
                "GKAGJJ='$returnedYear', GKAGNR/GKAGNN='$returnedNumber'"
            )
        }
    }

    if ($unexpectedRows.Count -gt 0) {
        throw "AGKO_select lieferte für den Request $QuoteYear/$formattedNumber unerwartete Datensätze: $($unexpectedRows.ToArray() -join '; '). Die Antwort wird aus Sicherheitsgründen nicht als gültige Kollisionsprüfung akzeptiert."
    }

    if ($matchingRows.Count -eq 0) {
        # Dieser Fall sollte nach obiger Prüfung nur bei einer strukturell
        # unerwarteten Antwort auftreten.
        throw "AGKO_select lieferte Daten, aber keinen exakt passenden Datensatz für $QuoteYear/$formattedNumber."
    }

    if ($matchingRows.Count -gt 1) {
        throw "AGKO_select lieferte für $QuoteYear/$formattedNumber mehrere exakt passende Datensätze: $($matchingRows.Count). Die Schlüsselkonsistenz muss geprüft werden."
    }

    $matchedRow = $matchingRows[0]

    $existingCustomer = [string](Get-ObjectPropertyValue `
        -Object $matchedRow `
        -Names @('GKKDNR') `
        -Default '')

    Write-QuoteLog `
        -Message "AGKO-Nummernprüfung: $QuoteYear/$formattedNumber existiert bereits. Kunde='$existingCustomer'." `
        -Level WARN `
        -LogPath $LogPath

    return $matchedRow
}

function Test-ExternalReferenceAlreadyImported {
    <#
    .SYNOPSIS
        Optionale externe-ID-Prüfung über einen separaten, bestätigten Service.

    .DESCRIPTION
        Der bekannte AGKO_select-Endpunkt unterstützt GKFREX nicht. Deshalb
        wird eine GKFREX-Prüfung nur ausgeführt, wenn in der Konfiguration ein
        eigener ExternalReferenceSelectUrl angegeben wurde.

        Erwartetes GET-Muster:
        <ExternalReferenceSelectUrl>?GKFIRM=01&GKFREX=<quote_unique_id>
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $ExternalId,
        [Parameter(Mandatory)] [string] $Company,
        [AllowEmptyString()] [string] $ExternalReferenceSelectUrl,
        [Parameter(Mandatory)] [hashtable] $Headers,
        [Parameter(Mandatory)] [string] $LogPath,
        [int] $TimeoutSeconds = 90,
        [switch] $DryRun
    )

    if ([string]::IsNullOrWhiteSpace($ExternalReferenceSelectUrl)) {
        Write-QuoteLog `
            -Message "Keine externe-ID-Prüfung für GKFREX ausgeführt: Api.ExternalReferenceSelectUrl ist nicht konfiguriert. AGKO_select unterstützt nur GKAGJJ/GKAGNR." `
            -Level WARN `
            -LogPath $LogPath

        return $false
    }

    $rows = @(
        Invoke-FilteredSelect `
            -SelectUrl $ExternalReferenceSelectUrl `
            -Filters @{
                GKFIRM = $Company
                GKFREX = $ExternalId
            } `
            -Headers $Headers `
            -LogPath $LogPath `
            -Context "Externe-ID-Prüfung $ExternalId" `
            -TimeoutSeconds $TimeoutSeconds `
            -DryRun:$DryRun
    )

    return ($rows.Count -gt 0)
}


function Confirm-QuoteHeaderInserted {
    <#
    .SYNOPSIS
        Verifiziert nach dem POST, dass der AGKO-Datensatz wirklich existiert.

    .DESCRIPTION
        Ein HTTP-200 oder success=true beweist nicht zwingend, dass die API
        tatsächlich committed hat. Deshalb wird AGKO_select wiederholt mit dem
        bestätigten Schlüssel GKAGJJ/GKAGNR aufgerufen.

        Nur ein exakt passender Datensatz gilt als erfolgreiche Speicherung.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [int] $QuoteYear,
        [Parameter(Mandatory)] [int] $QuoteNumber,
        [Parameter(Mandatory)] [string] $ExpectedExternalId,
        [Parameter(Mandatory)] [string] $ExpectedCustomerNumber,
        [Parameter(Mandatory)] [string] $HeaderSelectUrl,
        [Parameter(Mandatory)] [hashtable] $Headers,
        [Parameter(Mandatory)] [string] $LogPath,
        [int] $TimeoutSeconds = 90,
        [int] $Attempts = 3,
        [int] $DelayMilliseconds = 500
    )

    if ($Attempts -lt 1) {
        $Attempts = 1
    }

    if ($DelayMilliseconds -lt 0) {
        $DelayMilliseconds = 0
    }

    $formattedNumber = '{0:D6}' -f $QuoteNumber

    for ($attempt = 1; $attempt -le $Attempts; $attempt++) {
        $existingQuote = Get-ExistingQuoteByNumber `
            -QuoteYear $QuoteYear `
            -QuoteNumber $QuoteNumber `
            -HeaderSelectUrl $HeaderSelectUrl `
            -Headers $Headers `
            -LogPath $LogPath `
            -TimeoutSeconds $TimeoutSeconds

        if ($null -ne $existingQuote) {
            $actualExternalId = (
                [string](Get-ObjectPropertyValue `
                    -Object $existingQuote `
                    -Names @('GKFREX') `
                    -Default '')
            ).Trim()

            $actualCustomer = (
                [string](Get-ObjectPropertyValue `
                    -Object $existingQuote `
                    -Names @('GKKDNR') `
                    -Default '')
            ).Trim()

            if (-not [string]::IsNullOrWhiteSpace($ExpectedExternalId) -and
                -not [string]::IsNullOrWhiteSpace($actualExternalId) -and
                $actualExternalId -ne $ExpectedExternalId) {
                throw "AGKO-Nachkontrolle fand $QuoteYear/$formattedNumber, aber GKFREX='$actualExternalId' statt '$ExpectedExternalId'."
            }

            if (-not [string]::IsNullOrWhiteSpace($ExpectedCustomerNumber) -and
                -not [string]::IsNullOrWhiteSpace($actualCustomer) -and
                $actualCustomer -ne $ExpectedCustomerNumber) {
                throw "AGKO-Nachkontrolle fand $QuoteYear/$formattedNumber, aber GKKDNR='$actualCustomer' statt '$ExpectedCustomerNumber'."
            }

            Write-QuoteLog `
                -Message "AGKO-Nachkontrolle erfolgreich: $QuoteYear/$formattedNumber ist in der Tabelle vorhanden. Versuch=$attempt/$Attempts." `
                -Level INFO `
                -LogPath $LogPath

            return $existingQuote
        }

        if ($attempt -lt $Attempts -and $DelayMilliseconds -gt 0) {
            Write-QuoteLog `
                -Message "AGKO-Nachkontrolle: $QuoteYear/$formattedNumber noch nicht sichtbar. Neuer Versuch $($attempt + 1)/$Attempts." `
                -Level DEBUG `
                -LogPath $LogPath

            Start-Sleep -Milliseconds $DelayMilliseconds
        }
    }

    throw "AGKO-POST wurde von der API ohne HTTP-Fehler beantwortet, aber $QuoteYear/$formattedNumber ist nach $Attempts Nachkontrollversuch(en) nicht in AGKO vorhanden. Mögliche Ursachen: Api.TestMode=True simuliert nur, AddUrl zeigt auf ein anderes System, die API hat nicht committed oder die Antwort meldet nur Validierungserfolg."
}



function New-TechnicalRuntimeDefaults {
    <#
    .SYNOPSIS
        Erzeugt die technischen Laufzeitvorbelegungen für AGKO und AGPO.

    .DESCRIPTION
        Die Werte werden pro Angebot genau einmal ermittelt. Dadurch erhalten
        Angebotskopf und alle Positionen identische Werte für Datum und Uhrzeit.

        Unterstützte Modi:
        - Current: aktuelles Serverdatum beziehungsweise aktuelle Serverzeit
        - Fixed:   fest in der Konfiguration hinterlegter Wert

        Resultierende Felder:
        - GKJNAM / GPJNAM
        - GKJDAT / GPJDAT
        - GKJZEI / GPJZEI
        - GKUSER / GPUSER
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable] $Defaults,

        [Parameter(Mandatory)]
        [string] $LogPath
    )

    $runtimeConfig = Get-ConfigValue `
        -Object $Defaults `
        -Name 'TechnicalRuntimeFields' `
        -Default @{}

    if (-not ($runtimeConfig -is [System.Collections.IDictionary])) {
        throw 'Defaults.TechnicalRuntimeFields muss als Hashtable konfiguriert werden.'
    }

    $enabled = [bool](Get-ConfigValue `
        -Object $runtimeConfig `
        -Name 'Enabled' `
        -Default $true)

    if (-not $enabled) {
        Write-QuoteLog `
            -Message 'Technische Laufzeitvorbelegung ist deaktiviert.' `
            -Level WARN `
            -LogPath $LogPath

        return [pscustomobject]@{
            Enabled = $false
            JobName = ''
            Date     = ''
            Time     = ''
            User     = ''
        }
    }

    $jobName = ConvertTo-LimitedText `
        -Value (Get-ConfigValue $runtimeConfig 'JobName' 'APICAL') `
        -MaxLength 10 `
        -FailWhenTooLong `
        -FieldName 'TechnicalRuntimeFields.JobName'

    $user = ConvertTo-LimitedText `
        -Value (Get-ConfigValue $runtimeConfig 'User' 'DILA') `
        -MaxLength 10 `
        -FailWhenTooLong `
        -FieldName 'TechnicalRuntimeFields.User'

    $dateMode = (
        [string](Get-ConfigValue $runtimeConfig 'DateMode' 'Current')
    ).Trim()

    $timeMode = (
        [string](Get-ConfigValue $runtimeConfig 'TimeMode' 'Current')
    ).Trim()

    $now = Get-Date

    switch -Regex ($dateMode) {
        '^(?i)current$' {
            $technicalDate = $now.ToString('yyyyMMdd')
            break
        }

        '^(?i)fixed$' {
            $technicalDate = (
                [string](Get-ConfigValue $runtimeConfig 'FixedDate' '')
            ).Trim()

            if ($technicalDate -notmatch '^\d{8}$') {
                throw "TechnicalRuntimeFields.FixedDate muss im Format yyyyMMdd angegeben werden. Aktueller Wert: '$technicalDate'."
            }

            try {
                [void][datetime]::ParseExact(
                    $technicalDate,
                    'yyyyMMdd',
                    [System.Globalization.CultureInfo]::InvariantCulture
                )
            }
            catch {
                throw "TechnicalRuntimeFields.FixedDate ist kein gültiges Datum: '$technicalDate'."
            }

            break
        }

        default {
            throw "TechnicalRuntimeFields.DateMode muss 'Current' oder 'Fixed' sein. Aktueller Wert: '$dateMode'."
        }
    }

    switch -Regex ($timeMode) {
        '^(?i)current$' {
            $technicalTime = $now.ToString('HHmmss')
            break
        }

        '^(?i)fixed$' {
            $technicalTime = (
                [string](Get-ConfigValue $runtimeConfig 'FixedTime' '')
            ).Trim()

            if ($technicalTime -notmatch '^\d{6}$') {
                throw "TechnicalRuntimeFields.FixedTime muss im Format HHmmss angegeben werden. Aktueller Wert: '$technicalTime'."
            }

            try {
                [void][datetime]::ParseExact(
                    $technicalTime,
                    'HHmmss',
                    [System.Globalization.CultureInfo]::InvariantCulture
                )
            }
            catch {
                throw "TechnicalRuntimeFields.FixedTime ist keine gültige Uhrzeit: '$technicalTime'."
            }

            break
        }

        default {
            throw "TechnicalRuntimeFields.TimeMode muss 'Current' oder 'Fixed' sein. Aktueller Wert: '$timeMode'."
        }
    }

    Write-QuoteLog `
        -Message "Technische Laufzeitvorbelegung: JobName='$jobName', Date='$technicalDate', Time='$technicalTime', User='$user', DateMode='$dateMode', TimeMode='$timeMode'." `
        -Level DEBUG `
        -LogPath $LogPath

    return [pscustomobject]@{
        Enabled = $true
        JobName = $jobName
        Date     = $technicalDate
        Time     = $technicalTime
        User     = $user
    }
}

function Add-TechnicalRuntimeFields {
    <#
    .SYNOPSIS
        Fügt die technischen Laufzeitfelder einem AGKO-/AGPO-Objekt hinzu.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Collections.Specialized.OrderedDictionary] $Data,

        [Parameter(Mandatory)]
        $RuntimeValues,

        [Parameter(Mandatory)]
        [ValidateSet('Header', 'Position')]
        [string] $Target,

        [Parameter(Mandatory)]
        [string] $LogPath
    )

    if (-not [bool]$RuntimeValues.Enabled) {
        return
    }

    if ($Target -eq 'Header') {
        $fieldValues = [ordered]@{
            GKJNAM = $RuntimeValues.JobName
            GKJDAT = $RuntimeValues.Date
            GKJZEI = $RuntimeValues.Time
            GKUSER = $RuntimeValues.User
        }

        $context = 'AGKO-Laufzeitvorbelegung'
    }
    else {
        $fieldValues = [ordered]@{
            GPJNAM = $RuntimeValues.JobName
            GPJDAT = $RuntimeValues.Date
            GPJZEI = $RuntimeValues.Time
            GPUSER = $RuntimeValues.User
        }

        $context = 'AGPO-Laufzeitvorbelegung'
    }

    foreach ($fieldName in $fieldValues.Keys) {
        if ($Data.Contains($fieldName)) {
            throw "$context würde das bereits vorhandene Feld $fieldName überschreiben."
        }

        [void]$Data.Add($fieldName, $fieldValues[$fieldName])

        Write-QuoteLog `
            -Message "$context ergänzt: $fieldName='$($fieldValues[$fieldName])'" `
            -Level DEBUG `
            -LogPath $LogPath
    }
}

function Add-ConfiguredDatabaseFields {
    <#
    .SYNOPSIS
        Ergänzt ein AGKO-/AGPO-Datenobjekt um konfigurierte Zusatzfelder.

    .DESCRIPTION
        Die Kernfelder werden weiterhin durch das fachliche Mapping erzeugt.
        Zusatzfelder dienen ausschließlich für technisch/fachlich bestätigte
        Vorbelegungen.

        Schutzmechanismen:
        - nur IBM-i-ähnliche Feldnamen A-Z/0-9/_,
        - vorhandene Kernfelder dürfen nicht überschrieben werden,
        - NULL-Werte werden als leere Zeichenfolge übertragen,
        - jedes ergänzte Feld wird im DEBUG-Log genannt.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Collections.Specialized.OrderedDictionary] $Data,

        [AllowNull()]
        $AdditionalFields,

        [Parameter(Mandatory)]
        [string] $Context,

        [Parameter(Mandatory)]
        [string] $LogPath
    )

    if ($null -eq $AdditionalFields) {
        return
    }

    if (-not ($AdditionalFields -is [System.Collections.IDictionary])) {
        throw "$Context muss als Hashtable/Dictionary konfiguriert werden."
    }

    foreach ($rawFieldName in @($AdditionalFields.Keys | Sort-Object)) {
        $fieldName = ([string]$rawFieldName).Trim().ToUpperInvariant()

        if ($fieldName -notmatch '^[A-Z][A-Z0-9_]{0,29}$') {
            throw "Ungültiger Datenbankfeldname in ${Context}: '$rawFieldName'."
        }

        if ($Data.Contains($fieldName)) {
            throw "Zusatzfeld $fieldName in $Context würde ein bereits gemapptes Kernfeld überschreiben. Das ist nicht zulässig."
        }

        $value = $AdditionalFields[$rawFieldName]

        if ($null -eq $value) {
            $value = ''
        }

        [void]$Data.Add($fieldName, $value)

        Write-QuoteLog `
            -Message "$Context ergänzt: $fieldName='$value'" `
            -Level DEBUG `
            -LogPath $LogPath
    }
}

function New-QuoteHeaderData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $FirstRow,
        [Parameter(Mandatory)] $NumberRange,
        [Parameter(Mandatory)] $CustomerMaster,
        [Parameter(Mandatory)] [hashtable] $Defaults,
        [Parameter(Mandatory)] $TechnicalRuntimeValues,
        [Parameter(Mandatory)] [string] $ExternalId,
        [Parameter(Mandatory)] [string] $LogPath
    )

    $company = [string](Get-ConfigValue -Object $Defaults -Name 'Company' -Default '01')
    $documentType = [string](Get-ConfigValue -Object $Defaults -Name 'DocumentType' -Default '150')
    $customerLength = [int](Get-ConfigValue -Object $Defaults -Name 'CustomerNumberMinimumLength' -Default 6)
    $customerNumber = ConvertTo-CustomerNumber -Value ([string]$FirstRow.customer_number) -MinimumLength $customerLength
    $defaultResponsible = [string](Get-ConfigValue -Object $Defaults -Name 'Responsible' -Default 'TIK')
    $responsible = Get-ResponsibleCode -CsvValue $FirstRow.field_sales_id -DefaultValue $defaultResponsible -LogPath $LogPath

    $numberText = ([int]$NumberRange.Number).ToString('000000')

    $data = [ordered]@{
        GKFIRM = ConvertTo-LimitedText -Value $company -MaxLength 2 -FailWhenTooLong -FieldName 'GKFIRM'
        GKAGAR = ConvertTo-LimitedText -Value $documentType -MaxLength 3 -FailWhenTooLong -FieldName 'GKAGAR'
        GKAGJJ = [int]$NumberRange.Year
        GKAGNN = [int]$NumberRange.Number
        GKAGNR = $numberText
        GKKDNR = $customerNumber
        GKSABE = $responsible
        GKWKNR = ConvertTo-LimitedText -Value (Get-ConfigValue $Defaults 'Plant' '001') -MaxLength 3 -FailWhenTooLong -FieldName 'GKWKNR'
        GKABTL = ConvertTo-LimitedText -Value (Get-ConfigValue $Defaults 'Department' 'VK') -MaxLength 3 -FailWhenTooLong -FieldName 'GKABTL'
        GKABAR = ConvertTo-LimitedText -Value (Get-ConfigValue $Defaults 'OutputType' 'D') -MaxLength 1 -FailWhenTooLong -FieldName 'GKABAR'
        GKWACD = ConvertTo-LimitedText -Value $CustomerMaster.CurrencyCode -MaxLength 3 -FailWhenTooLong -FieldName 'GKWACD'
        GKAGST = ConvertTo-LimitedText -Value (Get-ConfigValue $Defaults 'Status' '00') -MaxLength 2 -FailWhenTooLong -FieldName 'GKAGST'
        GKGADA = ConvertTo-TrendDate -Value ([string]$FirstRow.valid_from) -FieldName 'valid_from'
        GKGBDA = ConvertTo-TrendDate -Value ([string]$FirstRow.valid_to) -FieldName 'valid_to'
        GKAGDA = ConvertTo-TrendDate -Value ([string]$FirstRow.quote_date) -FieldName 'quote_date'
        GKARF1 = ConvertTo-LimitedText -Value $FirstRow.quote_number -MaxLength 30
        GKARF2 = ConvertTo-LimitedText -Value $FirstRow.reference_2 -MaxLength 30
        GKVSBD = ConvertTo-LimitedText -Value $CustomerMaster.ShippingCondition -MaxLength 3
        GKLIBD = ConvertTo-LimitedText -Value $CustomerMaster.DeliveryCondition -MaxLength 3
        GKZABD = ConvertTo-LimitedText -Value $CustomerMaster.PaymentCondition -MaxLength 3
        GKSPCD = ConvertTo-LimitedText -Value $CustomerMaster.LanguageCode -MaxLength 1
        GKWVDA = 0
        GKKOND = ConvertTo-LimitedText -Value (Get-ConfigValue $Defaults 'PrintConditions' 'J') -MaxLength 1 -FailWhenTooLong -FieldName 'GKKOND'
        GKTLKZ = ConvertTo-LimitedText -Value (Get-ConfigValue $Defaults 'CompleteDelivery' 'N') -MaxLength 1 -FailWhenTooLong -FieldName 'GKTLKZ'
        GKFREX = ConvertTo-LimitedText -Value $ExternalId -MaxLength 20 -FailWhenTooLong -FieldName 'GKFREX/quote_unique_id'
    }

    # -----------------------------------------------------------------
    # Technische Laufzeitfelder
    # -----------------------------------------------------------------
    Add-TechnicalRuntimeFields `
        -Data $data `
        -RuntimeValues $TechnicalRuntimeValues `
        -Target Header `
        -LogPath $LogPath

    # -----------------------------------------------------------------
    # Frei erweiterbare statische Zusatzfelder
    # -----------------------------------------------------------------
    $additionalHeaderFields = Get-ConfigValue `
        -Object $Defaults `
        -Name 'AdditionalHeaderFields' `
        -Default @{}

    Add-ConfiguredDatabaseFields `
        -Data $data `
        -AdditionalFields $additionalHeaderFields `
        -Context 'AGKO-Zusatzvorbelegung' `
        -LogPath $LogPath

    return $data
}

function New-QuotePositionData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Row,
        [Parameter(Mandatory)] [int] $PositionNumber,
        [Parameter(Mandatory)] $HeaderData,
        [Parameter(Mandatory)] $ArticleMaster,
        [Parameter(Mandatory)] [hashtable] $Defaults,
        [Parameter(Mandatory)] $TechnicalRuntimeValues,
        [Parameter(Mandatory)] [string] $LogPath
    )

    $quantity = ConvertTo-DecimalValue -Value $Row.quantity -FieldName 'quantity'
    $discount = ConvertTo-DecimalValue -Value $Row.discount -FieldName 'discount' -AllowEmpty -DefaultValue 0

    $grossEmpty = [string]::IsNullOrWhiteSpace([string]$Row.gross_unit_price)
    $netEmpty = [string]::IsNullOrWhiteSpace([string]$Row.net_unit_price)

    if ($grossEmpty) {
        $grossUnitPrice = ConvertTo-DecimalValue -Value $Row.net_unit_price -FieldName 'net_unit_price'
    }
    else {
        $grossUnitPrice = ConvertTo-DecimalValue -Value $Row.gross_unit_price -FieldName 'gross_unit_price'
    }

    if ($netEmpty) {
        $netUnitPrice = $grossUnitPrice * (1 - ($discount / 100))
    }
    else {
        $netUnitPrice = ConvertTo-DecimalValue -Value $Row.net_unit_price -FieldName 'net_unit_price'
    }

    $goodsValue = [math]::Round(($quantity * $grossUnitPrice), 2, [System.MidpointRounding]::AwayFromZero)
    $netTotal = [math]::Round(($quantity * $netUnitPrice), 2, [System.MidpointRounding]::AwayFromZero)

    $data = [ordered]@{
        GPFIRM = $HeaderData.GKFIRM
        GPKDNR = $HeaderData.GKKDNR
        GPAGJJ = $HeaderData.GKAGJJ
        GPAGNR = $HeaderData.GKAGNR
        GPAGPO = $PositionNumber
        GPAGAR = $HeaderData.GKAGAR
        GPWKNR = $HeaderData.GKWKNR
        GPABTL = $HeaderData.GKABTL
        GPSABE = $HeaderData.GKSABE
        GPABAR = $HeaderData.GKABAR
        GPWACD = $HeaderData.GKWACD
        GPAGST = $HeaderData.GKAGST
        GPGADA = $HeaderData.GKGADA
        GPGBDA = $HeaderData.GKGBDA
        GPTENR = ConvertTo-LimitedText -Value $Row.article_number -MaxLength 15 -FailWhenTooLong -FieldName 'GPTENR/article_number'
        GPMENG = [decimal]$quantity
        GPTBZ1 = ConvertTo-LimitedText -Value $ArticleMaster.Description1 -MaxLength 30
        GPTBZ2 = ConvertTo-LimitedText -Value $ArticleMaster.Description2 -MaxLength 30
        GPMEIN = ConvertTo-LimitedText -Value $ArticleMaster.QuantityUnit -MaxLength 1 -FailWhenTooLong -FieldName 'GPMEIN'
        GPMEPR = ConvertTo-LimitedText -Value $ArticleMaster.PriceUnit -MaxLength 1 -FailWhenTooLong -FieldName 'GPMEPR'
        GPWAWT = [decimal]$goodsValue
        GPKURS = [decimal]0
        GPPRAR = ConvertTo-LimitedText -Value (Get-ConfigValue $Defaults 'PriceType' 'AKD') -MaxLength 3 -FailWhenTooLong -FieldName 'GPPRAR'
        GPPREI = [math]::Round([decimal]$grossUnitPrice, 3, [System.MidpointRounding]::AwayFromZero)
        GPNESU = [decimal]$netTotal
        GPPDIM = ConvertTo-LimitedText -Value (Get-ConfigValue $Defaults 'PriceDimension' '1') -MaxLength 1 -FailWhenTooLong -FieldName 'GPPDIM'
        GPKON1 = ConvertTo-LimitedText -Value (Get-ConfigValue $Defaults 'ConditionType' 'RA5') -MaxLength 3 -FailWhenTooLong -FieldName 'GPKON1'
        GPKOW1 = [math]::Round([decimal]$discount, 2, [System.MidpointRounding]::AwayFromZero)
        GPPRZ1 = ConvertTo-LimitedText -Value (Get-ConfigValue $Defaults 'ConditionIsPercent' 'J') -MaxLength 1 -FailWhenTooLong -FieldName 'GPPRZ1'
        GPAGDA = $HeaderData.GKAGDA
        GPURPR = [math]::Round([decimal]$grossUnitPrice, 2, [System.MidpointRounding]::AwayFromZero)
    }

    # -----------------------------------------------------------------
    # Technische Laufzeitfelder
    # -----------------------------------------------------------------
    Add-TechnicalRuntimeFields `
        -Data $data `
        -RuntimeValues $TechnicalRuntimeValues `
        -Target Position `
        -LogPath $LogPath

    # -----------------------------------------------------------------
    # Frei erweiterbare statische Zusatzfelder
    # -----------------------------------------------------------------
    $additionalPositionFields = Get-ConfigValue `
        -Object $Defaults `
        -Name 'AdditionalPositionFields' `
        -Default @{}

    Add-ConfiguredDatabaseFields `
        -Data $data `
        -AdditionalFields $additionalPositionFields `
        -Context "AGPO-Zusatzvorbelegung Position $PositionNumber" `
        -LogPath $LogPath

    return $data
}

function Send-QuoteCsv {
    <#
    .SYNOPSIS
        Importiert eine CSV-Datei nach AGKO/AGPO.

    .OUTPUTS
        PSCustomObject mit Erfolgs-, Skip- und Fehlerzähler sowie Detailstatus.

    .NOTES
        Die API-Aufrufe für Kopf und Positionen sind getrennte Requests. Falls die
        API keine serverseitige Transaktion oder Rollback-Funktion bereitstellt,
        kann bei einem Positionsfehler ein unvollständiger Angebotskopf verbleiben.
        Das Skript kennzeichnet diesen Zustand im Log und archiviert die CSV nicht.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $CsvPath,
        [Parameter(Mandatory)] [hashtable] $ApiConfig,
        [Parameter(Mandatory)] [hashtable] $Defaults,
        [Parameter(Mandatory)] [hashtable] $NumberRangeConfig,
        [Parameter(Mandatory)] [hashtable] $MasterDataConfig,
        [Parameter(Mandatory)] [string] $LogPath,
        [Parameter(Mandatory)] [string] $RequestDumpDirectory,
        [switch] $DryRun
    )

    if (-not (Test-Path -LiteralPath $CsvPath -PathType Leaf)) {
        throw "CSV-Datei nicht gefunden: $CsvPath"
    }

    # AGKO_select ist ein GET-Service mit Feldfiltern.
    # SqlSelectUrl ist davon getrennt und nur für optionale SQL-Stammdatenqueries.
    $baseUrl = ([string](Get-ConfigValue $ApiConfig 'BaseUrl' '')).TrimEnd('/')
    $headerSelectUrl = ([string](Get-ConfigValue $ApiConfig 'HeaderSelectUrl' '')).Trim()
    $externalReferenceSelectUrl = ([string](Get-ConfigValue $ApiConfig 'ExternalReferenceSelectUrl' '')).Trim()
    $sqlSelectUrl = ([string](Get-ConfigValue $ApiConfig 'SqlSelectUrl' '')).Trim()
    $addUrl = ([string](Get-ConfigValue $ApiConfig 'AddUrl' '')).Trim()

    # Rückwärtskompatibilität zur vorherigen Konfiguration.
    if ([string]::IsNullOrWhiteSpace($headerSelectUrl)) {
        $headerSelectUrl = ([string](Get-ConfigValue $ApiConfig 'SelectUrl' '')).Trim()
    }

    if ([string]::IsNullOrWhiteSpace($headerSelectUrl)) {
        throw 'Api.HeaderSelectUrl ist nicht konfiguriert.'
    }

    if ([string]::IsNullOrWhiteSpace($addUrl)) {
        if ([string]::IsNullOrWhiteSpace($baseUrl)) {
            throw 'Api.AddUrl und Api.BaseUrl sind nicht konfiguriert.'
        }

        $addUrl = "$baseUrl/add"
    }

    $headerTable = [string](Get-ConfigValue $ApiConfig 'HeaderTable' 'TVPFTEST.AGKO')
    $positionTable = [string](Get-ConfigValue $ApiConfig 'PositionTable' 'TVPFTEST.AGPO')
    Test-QualifiedTableName -TableName $headerTable
    Test-QualifiedTableName -TableName $positionTable

    $testMode = [bool](Get-ConfigValue $ApiConfig 'TestMode' $true)
    $timeoutSeconds = [int](Get-ConfigValue $ApiConfig 'TimeoutSeconds' 90)
    $verifyHeaderAfterInsert = [bool](Get-ConfigValue `
        -Object $ApiConfig `
        -Name 'VerifyHeaderAfterInsert' `
        -Default $true)

    $writeVerificationAttempts = [int](Get-ConfigValue `
        -Object $ApiConfig `
        -Name 'WriteVerificationAttempts' `
        -Default 3)

    $writeVerificationDelayMilliseconds = [int](Get-ConfigValue `
        -Object $ApiConfig `
        -Name 'WriteVerificationDelayMilliseconds' `
        -Default 500)

    $numberRangeMode = [string](Get-ConfigValue `
        -Object $NumberRangeConfig `
        -Name 'Mode' `
        -Default 'Api')

    $allowFixedInExecute = [bool](Get-ConfigValue `
        -Object $NumberRangeConfig `
        -Name 'AllowFixedInExecute' `
        -Default $false)

    if (-not $DryRun -and
        -not $testMode -and
        $numberRangeMode -ieq 'Fixed' -and
        $allowFixedInExecute) {

        if ($headerTable -notmatch '(?i)^TVPFTEST\.' -or
            $positionTable -notmatch '(?i)^TVPFTEST\.') {
            throw "Unsichere Konfiguration: Api.TestMode=False und fester Nummernkreis dürfen mit AllowFixedInExecute nur für TVPFTEST-Tabellen verwendet werden. Header='$headerTable', Position='$positionTable'."
        }

        Write-QuoteLog `
            -Message "KONTROLLIERTER TESTTABELLEN-SCHREIBMODUS: API testMode=false, Zieltabellen $headerTable und $positionTable, fester Nummernkreis ausdrücklich freigegeben." `
            -Level WARN `
            -LogPath $LogPath
    }

    $bearerToken = [string](Get-ConfigValue $ApiConfig 'BearerToken' '')

    if ([string]::IsNullOrWhiteSpace($bearerToken)) {
        $tokenFile = [string](Get-ConfigValue $ApiConfig 'BearerTokenFile' '')
        if (-not [string]::IsNullOrWhiteSpace($tokenFile) -and (Test-Path -LiteralPath $tokenFile -PathType Leaf)) {
            $bearerToken = Get-ProtectedSecret -Path $tokenFile
        }
    }

    $headers = New-ApiHeaders -BearerToken $bearerToken

    Ensure-Directory -Path $RequestDumpDirectory

    Write-QuoteLog `
        -Message "API-Endpunkte: HeaderSelectUrl=$headerSelectUrl | ExternalReferenceSelectUrl=$externalReferenceSelectUrl | SqlSelectUrl=$sqlSelectUrl | AddUrl=$addUrl" `
        -Level DEBUG `
        -LogPath $LogPath

    Write-QuoteLog -Message "CSV-Import startet: $CsvPath | Header=$headerTable | Position=$positionTable | TestMode=$testMode | DryRun=$([bool]$DryRun) | VerifyHeaderAfterInsert=$verifyHeaderAfterInsert" -Level INFO -LogPath $LogPath

    if (-not $DryRun -and $testMode) {
        Write-QuoteLog `
            -Message 'ACHTUNG: Execute=True und Api.TestMode=True. Die bekannte Add-API antwortet in diesem Modus mit "Test mode active, nothing inserted." Es wird deshalb kein echter INSERT erwartet.' `
            -Level WARN `
            -LogPath $LogPath
    }
    elseif (-not $DryRun -and -not $testMode) {
        Write-QuoteLog `
            -Message 'ECHTER API-SCHREIBMODUS: Der Request enthält "testMode":false. Die im Payload genannten Tabellen werden tatsächlich beschrieben, sofern die API den INSERT akzeptiert.' `
            -Level WARN `
            -LogPath $LogPath
    }

    $rows = @(Import-Csv -LiteralPath $CsvPath -Delimiter ';' -Encoding UTF8)
    Test-QuoteCsvSchema -Rows $rows

    $groups = @($rows | Group-Object -Property quote_unique_id)
    $details = New-Object System.Collections.Generic.List[object]
    $successCount = 0
    $skippedCount = 0
    $failedCount = 0

    foreach ($group in $groups) {
        $externalId = ([string]$group.Name).Trim()
        $groupRows = @($group.Group)
        $quoteNumberForLog = [string]$groupRows[0].quote_number

        Write-QuoteLog -Message "Verarbeite quote_unique_id=$externalId, quote_number=$quoteNumberForLog, Positionen=$($groupRows.Count)" -Level INFO -LogPath $LogPath

        try {
            Test-QuoteGroup -Rows $groupRows -ExternalId $externalId

            $company = [string](Get-ConfigValue $Defaults 'Company' '01')
            $documentType = [string](Get-ConfigValue $Defaults 'DocumentType' '150')

            # Der bestätigte AGKO_select-Endpunkt kann nicht nach GKFREX suchen.
            # Eine externe-ID-Prüfung ist deshalb nur möglich, wenn ein separater
            # ExternalReferenceSelectUrl konfiguriert wurde.
            $alreadyImportedByExternalId = Test-ExternalReferenceAlreadyImported `
                -ExternalId $externalId `
                -Company $company `
                -ExternalReferenceSelectUrl $externalReferenceSelectUrl `
                -Headers $headers `
                -LogPath $LogPath `
                -TimeoutSeconds $timeoutSeconds `
                -DryRun:$DryRun

            if ($alreadyImportedByExternalId) {
                Write-QuoteLog `
                    -Message "Angebot $externalId wurde über den separaten GKFREX-Lookup bereits gefunden und wird übersprungen." `
                    -Level WARN `
                    -LogPath $LogPath

                $skippedCount++
                $details.Add([pscustomobject]@{
                    ExternalId     = $externalId
                    QuoteNumber    = $quoteNumberForLog
                    Status         = 'SkippedAlreadyImportedByExternalId'
                    TrendYear      = $null
                    TrendNumber    = $null
                    PositionCount  = $groupRows.Count
                    Error          = $null
                })
                continue
            }

            # Alle Kopf- und Positionsdaten werden vor dem ersten INSERT validiert.
            # Dadurch werden vermeidbare Teilimporte reduziert.
            $firstRow = $groupRows[0]
            $customerNumber = ConvertTo-CustomerNumber `
                -Value ([string]$firstRow.customer_number) `
                -MinimumLength ([int](Get-ConfigValue $Defaults 'CustomerNumberMinimumLength' 6))

            $customerMaster = Get-CustomerMasterData `
                -CustomerNumber $customerNumber `
                -MasterDataConfig $MasterDataConfig `
                -SqlSelectUrl $sqlSelectUrl `
                -Headers $headers `
                -LogPath $LogPath `
                -TimeoutSeconds $timeoutSeconds `
                -DryRun:$DryRun

            $articleMasterByNumber = @{}
            foreach ($row in $groupRows) {
                $articleNumber = ([string]$row.article_number).Trim()
                if (-not $articleMasterByNumber.ContainsKey($articleNumber)) {
                    $articleMasterByNumber[$articleNumber] = Get-ArticleMasterData `
                        -ArticleNumber $articleNumber `
                        -MasterDataConfig $MasterDataConfig `
                        -SqlSelectUrl $sqlSelectUrl `
                        -Headers $headers `
                        -LogPath $LogPath `
                        -TimeoutSeconds $timeoutSeconds `
                        -DryRun:$DryRun
                }
            }

            $numberRange = Get-NextQuoteNumber `
                -NumberRangeConfig $NumberRangeConfig `
                -Company $company `
                -DocumentType $documentType `
                -ExternalReference $externalId `
                -Headers $headers `
                -LogPath $LogPath `
                -TimeoutSeconds $timeoutSeconds `
                -TestMode:$testMode `
                -DryRun:$DryRun

            # -----------------------------------------------------------------
            # Nummernkollision / nächste freie Testnummer
            # -----------------------------------------------------------------
            # Der bestätigte AGKO_select-Service unterstützt ausschließlich
            # GKAGJJ und GKAGNR.
            #
            # Im kontrollierten TVPFTEST-Modus kann ab FixedStartNumber
            # automatisch die nächste freie Nummer gesucht werden. Dies ist
            # bewusst KEIN produktionssicherer, atomarer Nummernkreis.
            $autoFindNextFree = [bool](Get-ConfigValue `
                -Object $NumberRangeConfig `
                -Name 'AutoFindNextFree' `
                -Default $false)

            $maximumSearchAttempts = [int](Get-ConfigValue `
                -Object $NumberRangeConfig `
                -Name 'MaximumSearchAttempts' `
                -Default 100)

            if ($maximumSearchAttempts -lt 1) {
                throw 'NumberRange.MaximumSearchAttempts muss mindestens 1 sein.'
            }

            $numberSearchAttempt = 0
            $skipCurrentGroup = $false

            while ($true) {
                $numberSearchAttempt++

                $existingQuote = Get-ExistingQuoteByNumber `
                    -QuoteYear ([int]$numberRange.Year) `
                    -QuoteNumber ([int]$numberRange.Number) `
                    -HeaderSelectUrl $headerSelectUrl `
                    -Headers $headers `
                    -LogPath $LogPath `
                    -TimeoutSeconds $timeoutSeconds `
                    -DryRun:$DryRun

                if ($null -eq $existingQuote) {
                    if ($numberSearchAttempt -gt 1) {
                        Write-QuoteLog `
                            -Message "Nächste freie Test-Angebotsnummer gefunden: $($numberRange.Year)/$('{0:D6}' -f ([int]$numberRange.Number)). Prüfversuche=$numberSearchAttempt." `
                            -Level INFO `
                            -LogPath $LogPath
                    }

                    break
                }

                $formattedNumber = '{0:D6}' -f ([int]$numberRange.Number)
                $existingExternalId = (
                    [string](Get-ObjectPropertyValue `
                        -Object $existingQuote `
                        -Names @('GKFREX') `
                        -Default '')
                ).Trim()

                $existingCustomer = (
                    [string](Get-ObjectPropertyValue `
                        -Object $existingQuote `
                        -Names @('GKKDNR') `
                        -Default '')
                ).Trim()

                if (-not [string]::IsNullOrWhiteSpace($existingExternalId) -and
                    $existingExternalId -eq $externalId) {
                    Write-QuoteLog `
                        -Message "Angebot $externalId ist bereits als $($numberRange.Year)/$formattedNumber vorhanden und wird übersprungen." `
                        -Level WARN `
                        -LogPath $LogPath

                    $skippedCount++
                    $details.Add([pscustomobject]@{
                        ExternalId     = $externalId
                        QuoteNumber    = $quoteNumberForLog
                        Status         = 'SkippedAlreadyImportedByNumber'
                        TrendYear      = $numberRange.Year
                        TrendNumber    = $numberRange.Number
                        PositionCount  = $groupRows.Count
                        Error          = $null
                    })

                    $skipCurrentGroup = $true
                    break
                }

                $isFixedTestNumber = (
                    [string]$numberRange.Source
                ) -match '^FixedTestNumber'

                if (-not $autoFindNextFree -or -not $isFixedTestNumber) {
                    throw "Angebotsnummer $($numberRange.Year)/$formattedNumber existiert bereits in AGKO. Vorhandene GKFREX='$existingExternalId', Kunde='$existingCustomer'. Die Nummer darf nicht erneut verwendet werden."
                }

                if ($numberSearchAttempt -ge $maximumSearchAttempts) {
                    throw "Ab $($numberRange.Year)/$formattedNumber konnte innerhalb von $maximumSearchAttempts Prüfversuchen keine freie Test-Angebotsnummer gefunden werden."
                }

                $nextNumber = ([int]$numberRange.Number) + 1

                if ($nextNumber -gt 999999) {
                    throw 'Die sechsstellige Angebotsnummer überschreitet 999999.'
                }

                Write-QuoteLog `
                    -Message "Test-Angebotsnummer $($numberRange.Year)/$formattedNumber ist belegt durch GKFREX='$existingExternalId', Kunde='$existingCustomer'. Suche wird mit $($numberRange.Year)/$('{0:D6}' -f $nextNumber) fortgesetzt." `
                    -Level WARN `
                    -LogPath $LogPath

                $numberRange = [pscustomobject]@{
                    Year   = [int]$numberRange.Year
                    Number = $nextNumber
                    Source = 'FixedTestNumberAutoNextFree'
                }

                # Cursor angleichen, damit eine weitere Angebotsgruppe in
                # derselben CSV nicht erneut bei einer bereits geprüften Nummer
                # beginnt.
                $script:FixedNumberCursor = $nextNumber
            }

            if ($skipCurrentGroup) {
                continue
            }

            # Datum und Uhrzeit werden genau einmal pro Angebot erzeugt.
            # Dadurch besitzen Kopf und alle Positionen identische technische
            # Protokollwerte.
            $technicalRuntimeValues = New-TechnicalRuntimeDefaults `
                -Defaults $Defaults `
                -LogPath $LogPath

            $headerData = New-QuoteHeaderData `
                -FirstRow $firstRow `
                -NumberRange $numberRange `
                -CustomerMaster $customerMaster `
                -Defaults $Defaults `
                -TechnicalRuntimeValues $technicalRuntimeValues `
                -ExternalId $externalId `
                -LogPath $LogPath

            $positions = New-Object System.Collections.Generic.List[object]
            $positionNumber = 10
            foreach ($row in $groupRows) {
                $articleNumber = ([string]$row.article_number).Trim()
                $positionData = New-QuotePositionData `
                    -Row $row `
                    -PositionNumber $positionNumber `
                    -HeaderData $headerData `
                    -ArticleMaster $articleMasterByNumber[$articleNumber] `
                    -Defaults $Defaults `
                    -TechnicalRuntimeValues $technicalRuntimeValues `
                    -LogPath $LogPath

                $positions.Add($positionData)
                $positionNumber += 10
            }

            $trendId = '{0}/{1}' -f $headerData.GKAGJJ, $headerData.GKAGNR
            $safeExternalId = $externalId -replace '[^A-Za-z0-9_.-]', '_'

            $headerBody = [ordered]@{
                table    = $headerTable
                testMode = $testMode
                data     = $headerData
            }

            $headerResult = Invoke-QuoteApi `
                -Url $addUrl `
                -Method POST `
                -Body $headerBody `
                -Headers $headers `
                -LogPath $LogPath `
                -Context "AGKO $trendId / $externalId" `
                -RequestDumpDirectory $RequestDumpDirectory `
                -DumpFileName "AGKO_${safeExternalId}_${trendId}.json" `
                -TimeoutSeconds $timeoutSeconds `
                -DryRun:$DryRun

            if (-not $headerResult.Success) {
                throw "AGKO-Insert fehlgeschlagen: $($headerResult.Error)"
            }

            if (-not $DryRun -and $verifyHeaderAfterInsert) {
                [void](Confirm-QuoteHeaderInserted `
                    -QuoteYear ([int]$headerData.GKAGJJ) `
                    -QuoteNumber ([int]$headerData.GKAGNN) `
                    -ExpectedExternalId $externalId `
                    -ExpectedCustomerNumber ([string]$headerData.GKKDNR) `
                    -HeaderSelectUrl $headerSelectUrl `
                    -Headers $headers `
                    -LogPath $LogPath `
                    -TimeoutSeconds $timeoutSeconds `
                    -Attempts $writeVerificationAttempts `
                    -DelayMilliseconds $writeVerificationDelayMilliseconds)
            }

            $insertedPositions = 0
            foreach ($positionData in $positions) {
                $positionBody = [ordered]@{
                    table    = $positionTable
                    testMode = $testMode
                    data     = $positionData
                }

                $positionResult = Invoke-QuoteApi `
                    -Url $addUrl `
                    -Method POST `
                    -Body $positionBody `
                    -Headers $headers `
                    -LogPath $LogPath `
                    -Context "AGPO $trendId Pos=$($positionData.GPAGPO) / $externalId" `
                    -RequestDumpDirectory $RequestDumpDirectory `
                    -DumpFileName "AGPO_${safeExternalId}_${trendId}_$($positionData.GPAGPO).json" `
                    -TimeoutSeconds $timeoutSeconds `
                    -DryRun:$DryRun

                if (-not $positionResult.Success) {
                    throw "AGPO-Insert bei Position $($positionData.GPAGPO) fehlgeschlagen. AGKO und $insertedPositions Position(en) könnten bereits geschrieben sein. Ursache: $($positionResult.Error)"
                }

                $insertedPositions++
            }

            Write-QuoteLog -Message "Angebot erfolgreich verarbeitet: $externalId -> $trendId, Positionen=$insertedPositions" -Level INFO -LogPath $LogPath
            $successCount++

            $details.Add([pscustomobject]@{
                ExternalId     = $externalId
                QuoteNumber    = $quoteNumberForLog
                Status         = if ($DryRun) { 'DryRunSuccess' } else { 'Imported' }
                TrendYear      = $headerData.GKAGJJ
                TrendNumber    = $headerData.GKAGNR
                PositionCount  = $insertedPositions
                Error          = $null
            })
        }
        catch {
            $failedCount++
            $errorMessage = $_.Exception.Message
            Write-QuoteLog -Message "Fehler bei quote_unique_id=${externalId}: $errorMessage" -Level ERROR -LogPath $LogPath

            $details.Add([pscustomobject]@{
                ExternalId     = $externalId
                QuoteNumber    = $quoteNumberForLog
                Status         = 'Failed'
                TrendYear      = $null
                TrendNumber    = $null
                PositionCount  = $groupRows.Count
                Error          = $errorMessage
            })
        }
    }

    $summary = [pscustomobject]@{
        CsvPath       = $CsvPath
        QuoteGroups   = $groups.Count
        Successful    = $successCount
        Skipped       = $skippedCount
        Failed        = $failedCount
        DryRun        = [bool]$DryRun
        TestMode      = $testMode
        Details       = $details.ToArray()
    }

    Write-QuoteLog -Message "CSV-Abschluss: Gruppen=$($summary.QuoteGroups), Erfolgreich=$successCount, Übersprungen=$skippedCount, Fehler=$failedCount" -Level INFO -LogPath $LogPath
    return $summary
}

Export-ModuleMember -Function @(
    'Ensure-Directory',
    'Initialize-QuoteImportLog',
    'Write-QuoteLog',
    'Read-ApiBearerToken',
    'Get-ProtectedSecret',
    'Get-ConfigValue',
    'Send-QuoteCsv'
)
