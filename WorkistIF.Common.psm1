#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ============================================================================
# Workist -> Trend IFGK / IFGP
# Gemeinsames Modul
#
# WICHTIG:
# Dieses Projekt schreibt NICHT direkt nach AGKO/AGPO.
# Primärziel sind ausschließlich die Trend-Interface-Dateien IFGK und IFGP.
# ============================================================================

$script:LastGeneratedTimestamp = [datetime]::MinValue

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

function Resolve-ProjectPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $ProjectRoot,
        [AllowEmptyString()] [string] $Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return ''
    }

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }

    return [System.IO.Path]::GetFullPath((Join-Path $ProjectRoot $Path))
}

function Ensure-Directory {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [string] $Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw 'Ein leerer Verzeichnispfad wurde übergeben.'
    }

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        New-Item -Path $Path -ItemType Directory -Force | Out-Null
    }
}

function Initialize-IfLog {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [string] $LogPath)

    $dir = Split-Path $LogPath -Parent
    if (-not [string]::IsNullOrWhiteSpace($dir)) {
        Ensure-Directory $dir
    }

    @(
        ('=' * 100)
        "RUN START: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        ('=' * 100)
    ) | Out-File -LiteralPath $LogPath -Encoding utf8 -Append
}

function Write-IfLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Message,
        [ValidateSet('DEBUG','INFO','WARN','ERROR')]
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
        $dir = Split-Path $LogPath -Parent
        if (-not [string]::IsNullOrWhiteSpace($dir)) {
            Ensure-Directory $dir
        }
        Add-Content -LiteralPath $LogPath -Value $line -Encoding utf8
    }
    catch {
        Write-Warning "Logdatei konnte nicht geschrieben werden: $LogPath. $($_.Exception.Message)"
    }
}

function Read-ApiBearerToken {
    [CmdletBinding()]
    param([string] $Prompt = 'API Bearer Token')

    $secure = Read-Host -Prompt $Prompt -AsSecureString
    if ($null -eq $secure -or $secure.Length -eq 0) {
        throw 'Es wurde kein Bearer-Token eingegeben.'
    }

    $bstr = [IntPtr]::Zero
    try {
        $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
        $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
        if ([string]::IsNullOrWhiteSpace($plain)) {
            throw 'Der Bearer-Token ist leer.'
        }
        return $plain
    }
    finally {
        if ($bstr -ne [IntPtr]::Zero) {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
        }
        $secure = $null
    }
}

function Get-ProtectedSecret {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [string] $Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Secret-Datei nicht gefunden: $Path"
    }

    try {
        $encrypted = (Get-Content -LiteralPath $Path -Raw -ErrorAction Stop).Trim()
        if ([string]::IsNullOrWhiteSpace($encrypted)) {
            throw 'Secret-Datei ist leer.'
        }

        $secure = ConvertTo-SecureString -String $encrypted -ErrorAction Stop
        $cred = New-Object System.Management.Automation.PSCredential('secret',$secure)
        $plain = $cred.GetNetworkCredential().Password

        if ([string]::IsNullOrWhiteSpace($plain)) {
            throw 'Secret-Datei enthält keinen verwendbaren Wert.'
        }

        return $plain
    }
    catch {
        throw "Secret-Datei konnte nicht entschlüsselt werden: $Path. Ursache: $($_.Exception.Message)"
    }
}

function ConvertTo-LimitedText {
    [CmdletBinding()]
    param(
        [AllowNull()] $Value,
        [Parameter(Mandatory)] [int] $MaxLength,
        [string] $FieldName = 'Textfeld',
        [switch] $FailWhenTooLong
    )

    $text = if ($null -eq $Value) { '' } else { ([string]$Value).Trim() }

    if ($text.Length -le $MaxLength) {
        return $text
    }

    if ($FailWhenTooLong) {
        throw "$FieldName überschreitet die maximale Länge $MaxLength: '$text'"
    }

    return $text.Substring(0,$MaxLength)
}

function ConvertTo-IfDate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Value,
        [Parameter(Mandatory)] [string] $FieldName
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        throw "Pflichtdatum '$FieldName' ist leer."
    }

    $formats = @('dd.MM.yyyy','yyyy-MM-dd','yyyyMMdd')
    $parsed = [datetime]::MinValue
    $culture = [System.Globalization.CultureInfo]::InvariantCulture
    $styles = [System.Globalization.DateTimeStyles]::None

    foreach ($format in $formats) {
        if ([datetime]::TryParseExact($Value.Trim(),$format,$culture,$styles,[ref]$parsed)) {
            return [int]$parsed.ToString('yyyyMMdd')
        }
    }

    throw "Ungültiges Datum in '$FieldName': '$Value'. Zulässig: dd.MM.yyyy, yyyy-MM-dd, yyyyMMdd."
}

function ConvertTo-DecimalValue {
    [CmdletBinding()]
    param(
        [AllowNull()] $Value,
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
    $styles = [System.Globalization.NumberStyles]::Number
    $result = [decimal]0

    foreach ($culture in @(
        [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Globalization.CultureInfo]::GetCultureInfo('de-DE')
    )) {
        if ([decimal]::TryParse($text,$styles,$culture,[ref]$result)) {
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
        throw "customer_number '$customer' überschreitet IFGKKDNR CHAR(10)."
    }

    if ($customer -match '^\d+$' -and $customer.Length -lt $MinimumLength) {
        $customer = $customer.PadLeft($MinimumLength,'0')
    }

    return $customer
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

    if ($Object -is [System.Collections.IDictionary]) {
        foreach ($name in $Names) {
            foreach ($key in $Object.Keys) {
                if ([string]$key -ieq $name) {
                    return $Object[$key]
                }
            }
        }
        return $Default
    }

    foreach ($name in $Names) {
        $property = $Object.PSObject.Properties |
            Where-Object { $_.Name -ieq $name } |
            Select-Object -First 1

        if ($null -ne $property) {
            return $property.Value
        }
    }

    return $Default
}

function Test-ApiResponseSuccess {
    [CmdletBinding()]
    param([AllowNull()] $Response)

    if ($null -eq $Response) {
        return $true
    }

    $success = Get-ObjectPropertyValue $Response @('success') $null
    if ($null -ne $success) {
        if ($success -is [bool]) {
            return [bool]$success
        }
        if (([string]$success).Trim() -match '^(?i:false|0|no)$') {
            return $false
        }
    }

    $status = [string](Get-ObjectPropertyValue $Response @('STATUS','status') '')
    if (-not [string]::IsNullOrWhiteSpace($status) -and
        $status.Trim() -match '^(?i:error|failed|fail|nok)$') {
        return $false
    }

    return $true
}

function New-ApiHeaders {
    [CmdletBinding()]
    param([AllowEmptyString()] [string] $BearerToken)

    $headers = @{ Accept = 'application/json' }

    if (-not [string]::IsNullOrWhiteSpace($BearerToken)) {
        $headers['Authorization'] = "Bearer $BearerToken"
    }

    return $headers
}

function Invoke-IfApi {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Url,
        [ValidateSet('GET','POST')] [string] $Method,
        [AllowNull()] $Body,
        [Parameter(Mandatory)] [hashtable] $Headers,
        [Parameter(Mandatory)] [string] $LogPath,
        [string] $Context = '',
        [string] $RequestDumpDirectory = '',
        [string] $DumpFileName = '',
        [int] $TimeoutSeconds = 90,
        [switch] $DryRun,
        [switch] $AllowSimulation
    )

    $json = $null
    if ($null -ne $Body) {
        $json = if ($Body -is [string]) {
            $Body
        }
        else {
            $Body | ConvertTo-Json -Depth 20
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($RequestDumpDirectory) -and
        -not [string]::IsNullOrWhiteSpace($DumpFileName) -and
        $null -ne $json) {

        Ensure-Directory $RequestDumpDirectory
        $safe = $DumpFileName -replace '[^A-Za-z0-9_.-]','_'
        $dumpPath = Join-Path $RequestDumpDirectory $safe
        $json | Out-File -LiteralPath $dumpPath -Encoding utf8 -Force
        Write-IfLog "JSON-Dump: $dumpPath" DEBUG $LogPath
    }

    Write-IfLog "API $Method $Url | $Context | DryRun=$([bool]$DryRun)" DEBUG $LogPath

    if ($DryRun) {
        return [pscustomobject]@{
            Success = $true
            Simulated = $true
            DryRun = $true
            Response = $null
            Error = $null
        }
    }

    try {
        $invoke = @{
            Uri = $Url
            Method = $Method
            Headers = $Headers
            ErrorAction = 'Stop'
            TimeoutSec = $TimeoutSeconds
        }

        if ($null -ne $json) {
            $invoke['Body'] = $json
            $invoke['ContentType'] = 'application/json; charset=utf-8'
        }

        $response = Invoke-RestMethod @invoke

        $responseJson = if ($null -eq $response) {
            '<leere Antwort oder HTTP 204>'
        }
        else {
            try { $response | ConvertTo-Json -Depth 20 -Compress }
            catch { [string]$response }
        }

        Write-IfLog "API-Antwort bei '$Context': $responseJson" DEBUG $LogPath

        if (-not (Test-ApiResponseSuccess $response)) {
            $msg = [string](Get-ObjectPropertyValue $response @('message','MESSAGE','error','details') 'API meldet Fehler.')
            return [pscustomobject]@{
                Success = $false
                Simulated = $false
                DryRun = $false
                Response = $response
                Error = $msg
            }
        }

        $message = ([string](Get-ObjectPropertyValue $response @('message','MESSAGE') '')).Trim()
        $simulated = $false

        if ($Method -eq 'POST' -and
            $message -match '(?i)(nothing\s+inserted|not\s+inserted|test\s+mode\s+active|simulation|simulated|dry[\s-]*run)') {

            $simulated = $true

            if (-not $AllowSimulation) {
                return [pscustomobject]@{
                    Success = $false
                    Simulated = $true
                    DryRun = $false
                    Response = $response
                    Error = "API hat keinen Datensatz gespeichert: $message"
                }
            }
        }

        return [pscustomobject]@{
            Success = $true
            Simulated = $simulated
            DryRun = $false
            Response = $response
            Error = $null
        }
    }
    catch {
        $message = $_.Exception.Message

        try {
            if ($null -ne $_.Exception.Response) {
                $stream = $_.Exception.Response.GetResponseStream()
                if ($null -ne $stream) {
                    $reader = New-Object System.IO.StreamReader($stream)
                    $body = $reader.ReadToEnd()
                    if (-not [string]::IsNullOrWhiteSpace($body)) {
                        $message = "$message | API-Antwort: $body"
                    }
                }
            }
        }
        catch {}

        Write-IfLog "API-Fehler bei '$Context': $message" ERROR $LogPath

        return [pscustomobject]@{
            Success = $false
            Simulated = $false
            DryRun = $false
            Response = $null
            Error = $message
        }
    }
}

function New-UniqueDb2Timestamp {
    [CmdletBinding()]
    param()

    $candidate = Get-Date

    # IBM-i-TIMESTAMP wird hier mit 6 Nachkommastellen ausgegeben.
    # Wenn zwei Werte im selben Mikrosekundenfenster entstehen, wird der
    # nächste Wert künstlich um mindestens eine Mikrosekunde erhöht.
    if ($script:LastGeneratedTimestamp -ne [datetime]::MinValue -and
        $candidate -le $script:LastGeneratedTimestamp) {
        $candidate = $script:LastGeneratedTimestamp.AddTicks(10)
    }
    elseif ($script:LastGeneratedTimestamp -ne [datetime]::MinValue -and
            ($candidate - $script:LastGeneratedTimestamp).Ticks -lt 10) {
        $candidate = $script:LastGeneratedTimestamp.AddTicks(10)
    }

    $script:LastGeneratedTimestamp = $candidate

    return $candidate.ToString(
        'yyyy-MM-dd-HH.mm.ss.ffffff',
        [System.Globalization.CultureInfo]::InvariantCulture
    )
}

function New-InterfaceRuntimeValues {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [hashtable] $InterfaceConfig
    )

    $now = Get-Date
    $captureUser = ConvertTo-LimitedText `
        -Value (Get-ConfigValue $InterfaceConfig 'CaptureUser' 'DILA') `
        -MaxLength 10 `
        -FieldName 'Interface.CaptureUser' `
        -FailWhenTooLong

    return [pscustomobject]@{
        CaptureUser = $captureUser
        Date = [int]$now.ToString('yyyyMMdd')
        Time = [int]$now.ToString('HHmmss')
    }
}

function Get-ResponsibleCode {
    [CmdletBinding()]
    param(
        [AllowEmptyString()] [string] $CsvValue,
        [Parameter(Mandatory)] [string] $DefaultValue,
        [Parameter(Mandatory)] [string] $LogPath
    )

    $value = $CsvValue.Trim()
    if ([string]::IsNullOrWhiteSpace($value)) {
        return $DefaultValue
    }

    if ($value.Length -gt 3) {
        Write-IfLog "field_sales_id '$value' passt nicht in IFGKSABE CHAR(3). Default '$DefaultValue' wird verwendet." WARN $LogPath
        return $DefaultValue
    }

    return $value
}

function Get-OptionalCsvValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Row,
        [Parameter(Mandatory)] [string] $Name,
        [AllowEmptyString()] [string] $Default = ''
    )

    $property = $Row.PSObject.Properties |
        Where-Object { $_.Name -ieq $Name } |
        Select-Object -First 1

    if ($null -eq $property -or $null -eq $property.Value) {
        return $Default
    }

    return ([string]$property.Value).Trim()
}

function Test-IfCsvSchema {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object[]] $Rows,
        [Parameter(Mandatory)] [string] $CsvPath
    )

    if ($Rows.Count -eq 0) {
        throw "CSV-Datei enthält keine Datenzeilen: $CsvPath"
    }

    $required = @(
        'quote_unique_id',
        'quote_number',
        'customer_number',
        'article_number',
        'quantity',
        'quote_date',
        'field_sales_id',
        'reference_2',
        'valid_from',
        'valid_to',
        'discount',
        'gross_unit_price',
        'net_unit_price'
    )

    $available = @($Rows[0].PSObject.Properties.Name)
    foreach ($name in $required) {
        if ($available -notcontains $name) {
            throw "CSV-Pflichtspalte fehlt: $name"
        }
    }
}

function Test-IfGroup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object[]] $Rows,
        [Parameter(Mandatory)] [hashtable] $InterfaceConfig
    )

    $first = $Rows[0]

    $externalId = ([string]$first.quote_unique_id).Trim()
    if ([string]::IsNullOrWhiteSpace($externalId)) {
        throw 'quote_unique_id ist leer.'
    }
    if ($externalId.Length -gt 32) {
        throw "quote_unique_id '$externalId' überschreitet IFGKIFNR CHAR(32)."
    }

    foreach ($field in @('customer_number','quote_number','quote_date','valid_from','valid_to','reference_2')) {
        $expected = [string](Get-ObjectPropertyValue $first @($field) '')
        foreach ($row in $Rows) {
            $actual = [string](Get-ObjectPropertyValue $row @($field) '')
            if ($actual.Trim() -ne $expected.Trim()) {
                throw "Kopfwert '$field' ist innerhalb quote_unique_id=$externalId nicht einheitlich."
            }
        }
    }

    $validFrom = ConvertTo-IfDate ([string]$first.valid_from) 'valid_from'
    $validTo = ConvertTo-IfDate ([string]$first.valid_to) 'valid_to'
    if ($validTo -lt $validFrom) {
        throw "valid_to ($validTo) darf nicht kleiner als valid_from ($validFrom) sein."
    }

    $position = 0
    foreach ($row in $Rows) {
        $position++

        $article = ([string]$row.article_number).Trim()
        if ([string]::IsNullOrWhiteSpace($article)) {
            throw "article_number ist in Position $position leer."
        }
        if ($article.Length -gt 15) {
            throw "article_number '$article' überschreitet IFGPTENR CHAR(15)."
        }

        $quantity = ConvertTo-DecimalValue $row.quantity "quantity Position $position"
        if ($quantity -le 0) {
            throw "quantity muss > 0 sein. Position $position."
        }
        if ([math]::Abs($quantity) -gt [decimal]999999999.99) {
            throw "quantity überschreitet IFGPMENG NUMERIC(11,2). Position $position."
        }

        [void](Get-IfSinglePrice -Row $row -PricingConfig (Get-ConfigValue $InterfaceConfig 'Pricing' @{}) -PositionNumber $position)
    }
}

function Get-IfSinglePrice {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Row,
        [Parameter(Mandatory)] $PricingConfig,
        [Parameter(Mandatory)] [int] $PositionNumber
    )

    $grossText = [string](Get-ObjectPropertyValue $Row @('gross_unit_price') '')
    $netText = [string](Get-ObjectPropertyValue $Row @('net_unit_price') '')
    $discountText = [string](Get-ObjectPropertyValue $Row @('discount') '')

    $gross = ConvertTo-DecimalValue $grossText "gross_unit_price Position $PositionNumber" -AllowEmpty -DefaultValue ([decimal]-1)
    $net = ConvertTo-DecimalValue $netText "net_unit_price Position $PositionNumber" -AllowEmpty -DefaultValue ([decimal]-1)
    $discount = ConvertTo-DecimalValue $discountText "discount Position $PositionNumber" -AllowEmpty -DefaultValue 0

    if ($gross -lt 0 -and $net -lt 0) {
        throw "Position $PositionNumber: mindestens gross_unit_price oder net_unit_price muss gefüllt sein."
    }

    if ($discount -lt 0 -or $discount -gt 100) {
        throw "Position $PositionNumber: discount muss zwischen 0 und 100 liegen."
    }

    $allowDifferent = [bool](Get-ConfigValue $PricingConfig 'AllowDifferentGrossAndNet' $false)
    $allowDiscount = [bool](Get-ConfigValue $PricingConfig 'AllowNonZeroDiscount' $false)
    $preferred = ([string](Get-ConfigValue $PricingConfig 'PreferredPrice' 'Net')).Trim()

    if ($discount -ne 0 -and -not $allowDiscount) {
        throw "Position $PositionNumber: discount=$discount kann nicht verlustfrei in die dokumentierten IFGP-Felder gemappt werden. Pricing.AllowNonZeroDiscount ist false."
    }

    if ($gross -ge 0 -and $net -ge 0 -and $gross -ne $net -and -not $allowDifferent) {
        throw "Position $PositionNumber: gross_unit_price=$gross und net_unit_price=$net unterscheiden sich. IFGP besitzt nur IFGPPREI. Pricing.AllowDifferentGrossAndNet ist false."
    }

    $price = $null

    if ($preferred -ieq 'Gross') {
        if ($gross -ge 0) { $price = $gross } else { $price = $net }
    }
    elseif ($preferred -ieq 'Net') {
        if ($net -ge 0) { $price = $net } else { $price = $gross }
    }
    else {
        throw "Pricing.PreferredPrice muss 'Gross' oder 'Net' sein."
    }

    if ($price -lt 0 -or $price -gt [decimal]99999999.999) {
        throw "Position $PositionNumber: Einzelpreis überschreitet IFGPPREI NUMERIC(11,3)."
    }

    return [math]::Round([decimal]$price,3,[System.MidpointRounding]::AwayFromZero)
}

function Add-AdditionalFields {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [System.Collections.Specialized.OrderedDictionary] $Data,
        [AllowNull()] $AdditionalFields,
        [Parameter(Mandatory)] [string[]] $AllowedFieldNames,
        [Parameter(Mandatory)] [string] $Context
    )

    if ($null -eq $AdditionalFields) {
        return
    }

    if (-not ($AdditionalFields -is [System.Collections.IDictionary])) {
        throw "$Context muss als Hashtable konfiguriert werden."
    }

    foreach ($key in $AdditionalFields.Keys) {
        $field = ([string]$key).Trim().ToUpperInvariant()

        if ($AllowedFieldNames -notcontains $field) {
            throw "$Context enthält unbekanntes oder nicht freigegebenes IF-Feld '$field'."
        }

        if ($Data.Contains($field)) {
            throw "$Context würde das bereits gemappte Feld $field überschreiben."
        }

        $value = $AdditionalFields[$key]
        if ($null -eq $value) { $value = '' }
        [void]$Data.Add($field,$value)
    }
}

function New-IfHeaderData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $FirstRow,
        [Parameter(Mandatory)] [hashtable] $InterfaceConfig,
        [Parameter(Mandatory)] $RuntimeValues,
        [Parameter(Mandatory)] [string] $HeaderTimestamp,
        [Parameter(Mandatory)] [string] $LogPath
    )

    $interfaceCompany = ConvertTo-LimitedText `
        (Get-ConfigValue $InterfaceConfig 'InterfaceCompany' '') 5 'Interface.InterfaceCompany' -FailWhenTooLong

    if ([string]::IsNullOrWhiteSpace($interfaceCompany) -or $interfaceCompany -eq 'SETME') {
        throw 'Interface.InterfaceCompany muss mit der echten IF-Firmen-Nr. aus Trend konfiguriert werden.'
    }

    $externalId = ConvertTo-LimitedText $FirstRow.quote_unique_id 32 'IFGKIFNR/quote_unique_id' -FailWhenTooLong
    $customer = ConvertTo-CustomerNumber `
        -Value ([string]$FirstRow.customer_number) `
        -MinimumLength ([int](Get-ConfigValue $InterfaceConfig 'CustomerNumberMinimumLength' 6))

    $responsible = Get-ResponsibleCode `
        -CsvValue ([string]$FirstRow.field_sales_id) `
        -DefaultValue ([string](Get-ConfigValue $InterfaceConfig 'Responsible' 'TIK')) `
        -LogPath $LogPath

    $validFrom = ConvertTo-IfDate ([string]$FirstRow.valid_from) 'valid_from'
    $validTo = ConvertTo-IfDate ([string]$FirstRow.valid_to) 'valid_to'
    $quoteDate = ConvertTo-IfDate ([string]$FirstRow.quote_date) 'quote_date'

    $shippingAddressNumber = Get-OptionalCsvValue $FirstRow 'shipping_address_number' `
        ([string](Get-ConfigValue $InterfaceConfig 'ShippingAddressNumber' ''))

    $data = [ordered]@{
        # ---------------------------------------------------------------------
        # Primär-/Alternativschlüssel der IF-Schnittstelle
        # ---------------------------------------------------------------------
        IFGKTSTP = $HeaderTimestamp
        IFGKIFFI = $interfaceCompany
        IFGKIFNR = $externalId

        # ---------------------------------------------------------------------
        # Erfassung
        # ---------------------------------------------------------------------
        IFGKERUS = $RuntimeValues.CaptureUser
        IFGKERDA = $RuntimeValues.Date
        IFGKEZEI = $RuntimeValues.Time

        # ---------------------------------------------------------------------
        # Trend-Zielzuordnung / spätere Ergebnisfelder
        # AGJJ/AGNR werden bei der IF-Neuanlage NICHT vorweggenommen.
        # ---------------------------------------------------------------------
        IFGKFIRM = ConvertTo-LimitedText (Get-ConfigValue $InterfaceConfig 'Company' '01') 2 'IFGKFIRM' -FailWhenTooLong
        IFGKAGJJ = 0
        IFGKAGNR = ''
        IFGKAGAR = ConvertTo-LimitedText (Get-ConfigValue $InterfaceConfig 'ContractType' '150') 3 'IFGKAGAR' -FailWhenTooLong

        # ---------------------------------------------------------------------
        # Fehler-/Übernahmeinformationen: Initialzustand
        # ---------------------------------------------------------------------
        IFGKFENR = ''
        IFGKFFLD = ''
        IFGKUEDA = 0
        IFGKUEUZ = 0

        # ---------------------------------------------------------------------
        # Laut Trend-Dokumentation bei Neuanlage zwingend 00
        # ---------------------------------------------------------------------
        IFGKIFST = '00'
        IFGKIFKO = '00'
        IFGKIFPO = '00'
        IFGKFR01 = ''

        # ---------------------------------------------------------------------
        # Fachliche Angebotskopfdaten
        # ---------------------------------------------------------------------
        IFGKKDNR = $customer
        IFGKVSNR = ConvertTo-LimitedText $shippingAddressNumber 3 'IFGKVSNR' -FailWhenTooLong
        IFGKSABE = ConvertTo-LimitedText $responsible 3 'IFGKSABE' -FailWhenTooLong
        IFGKWKNR = ConvertTo-LimitedText (Get-ConfigValue $InterfaceConfig 'Plant' '001') 3 'IFGKWKNR' -FailWhenTooLong
        IFGKABTL = ConvertTo-LimitedText (Get-ConfigValue $InterfaceConfig 'Department' 'VK') 3 'IFGKABTL' -FailWhenTooLong
        IFGKABAR = ConvertTo-LimitedText (Get-ConfigValue $InterfaceConfig 'OutputType' 'D') 1 'IFGKABAR' -FailWhenTooLong
        IFGKWACD = ConvertTo-LimitedText (Get-ConfigValue $InterfaceConfig 'CurrencyCode' 'EUR') 3 'IFGKWACD' -FailWhenTooLong
        IFGKGADA = $validFrom
        IFGKGBDA = $validTo
        IFGKAGDA = $quoteDate
        IFGKARF1 = ConvertTo-LimitedText $FirstRow.quote_number 30 'IFGKARF1/quote_number' -FailWhenTooLong
        IFGKARF2 = ConvertTo-LimitedText $FirstRow.reference_2 30 'IFGKARF2/reference_2' -FailWhenTooLong
        IFGKVSBD = ConvertTo-LimitedText (Get-ConfigValue $InterfaceConfig 'ShippingCondition' '220') 3 'IFGKVSBD' -FailWhenTooLong
        IFGKLIBD = ConvertTo-LimitedText (Get-ConfigValue $InterfaceConfig 'DeliveryCondition' '060') 3 'IFGKLIBD' -FailWhenTooLong
        IFGKZABD = ConvertTo-LimitedText (Get-ConfigValue $InterfaceConfig 'PaymentCondition' '012') 3 'IFGKZABD' -FailWhenTooLong
        IFGKVPEI = ConvertTo-LimitedText (Get-ConfigValue $InterfaceConfig 'PackagingCondition' '') 3 'IFGKVPEI' -FailWhenTooLong
        IFGKAAGR = ConvertTo-LimitedText (Get-ConfigValue $InterfaceConfig 'CustomerOrderGroup' '') 3 'IFGKAAGR' -FailWhenTooLong
        IFGKPJNR = ConvertTo-LimitedText (Get-ConfigValue $InterfaceConfig 'ProjectNumber' '') 10 'IFGKPJNR' -FailWhenTooLong
        IFGKPSLI = ConvertTo-LimitedText (Get-ConfigValue $InterfaceConfig 'PriceList' '') 2 'IFGKPSLI' -FailWhenTooLong
        IFGKLFTG = [int](Get-ConfigValue $InterfaceConfig 'LeadTime' 0)
        IFGKLVZA = ConvertTo-LimitedText (Get-ConfigValue $InterfaceConfig 'TimeBasis' '') 1 'IFGKLVZA' -FailWhenTooLong
        IFGKSPCD = ConvertTo-LimitedText (Get-ConfigValue $InterfaceConfig 'LanguageCode' 'D') 1 'IFGKSPCD' -FailWhenTooLong
        IFGKWVDA = [int](Get-ConfigValue $InterfaceConfig 'FollowUpDate' 0)
        IFGKKOND = ConvertTo-LimitedText (Get-ConfigValue $InterfaceConfig 'PrintConditions' 'J') 1 'IFGKKOND' -FailWhenTooLong
        IFGKFREI = ConvertTo-LimitedText (Get-ConfigValue $InterfaceConfig 'HeaderFreeText' '') 512 'IFGKFREI' -FailWhenTooLong
    }

    # Die physischen Änderungs-/Jobfelder stehen in der SQL-Struktur, sind aber
    # in der Projektbeschreibung nicht als fachliche IF-Eingabefelder beschrieben.
    # Sie werden deshalb nur bei expliziter Freigabe gesetzt.
    $physical = Get-ConfigValue $InterfaceConfig 'PhysicalAuditFields' @{}
    if ([bool](Get-ConfigValue $physical 'Enabled' $false)) {
        $data.Insert(0,'IFGKLOCK',ConvertTo-LimitedText (Get-ConfigValue $physical 'Lock' '') 1 'IFGKLOCK' -FailWhenTooLong)
        $data.Insert(1,'IFGKJNAM',ConvertTo-LimitedText (Get-ConfigValue $physical 'JobName' 'APICAL') 10 'IFGKJNAM' -FailWhenTooLong)
        $data.Insert(2,'IFGKJDAT',$RuntimeValues.Date)
        $data.Insert(3,'IFGKJZEI',$RuntimeValues.Time)
        $data.Insert(4,'IFGKUSER',ConvertTo-LimitedText (Get-ConfigValue $physical 'User' $RuntimeValues.CaptureUser) 10 'IFGKUSER' -FailWhenTooLong)
        $data.Insert(5,'IFGKPROG',ConvertTo-LimitedText (Get-ConfigValue $physical 'Program' 'APICAL') 10 'IFGKPROG' -FailWhenTooLong)
        $data.Insert(6,'IFGKBIBL',ConvertTo-LimitedText (Get-ConfigValue $physical 'Library' '') 10 'IFGKBIBL' -FailWhenTooLong)
    }

    $allHeaderFields = @(
        'IFGKLOCK','IFGKJNAM','IFGKJDAT','IFGKJZEI','IFGKUSER','IFGKPROG','IFGKBIBL',
        'IFGKTSTP','IFGKIFFI','IFGKIFNR','IFGKERUS','IFGKERDA','IFGKEZEI','IFGKFIRM',
        'IFGKAGJJ','IFGKAGNR','IFGKAGAR','IFGKFENR','IFGKFFLD','IFGKUEDA','IFGKUEUZ',
        'IFGKIFST','IFGKIFKO','IFGKIFPO','IFGKFR01','IFGKKDNR','IFGKVSNR','IFGKSABE',
        'IFGKWKNR','IFGKABTL','IFGKABAR','IFGKWACD','IFGKGADA','IFGKGBDA','IFGKAGDA',
        'IFGKARF1','IFGKARF2','IFGKVSBD','IFGKLIBD','IFGKZABD','IFGKVPEI','IFGKAAGR',
        'IFGKPJNR','IFGKPSLI','IFGKLFTG','IFGKLVZA','IFGKSPCD','IFGKWVDA','IFGKKOND','IFGKFREI'
    )

    Add-AdditionalFields `
        -Data $data `
        -AdditionalFields (Get-ConfigValue $InterfaceConfig 'AdditionalHeaderFields' @{}) `
        -AllowedFieldNames $allHeaderFields `
        -Context 'Interface.AdditionalHeaderFields'

    return $data
}

function New-IfPositionData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Row,
        [Parameter(Mandatory)] [hashtable] $InterfaceConfig,
        [Parameter(Mandatory)] $RuntimeValues,
        [Parameter(Mandatory)] [string] $HeaderTimestamp,
        [Parameter(Mandatory)] [int] $InterfacePosition,
        [Parameter(Mandatory)] [string] $LogPath
    )

    if ($InterfacePosition -lt 1 -or $InterfacePosition -gt 9999) {
        throw "IFGPIFGP muss zwischen 1 und 9999 liegen. Wert: $InterfacePosition."
    }

    $pricing = Get-ConfigValue $InterfaceConfig 'Pricing' @{}
    $price = Get-IfSinglePrice $Row $pricing $InterfacePosition
    $quantity = ConvertTo-DecimalValue $Row.quantity "quantity Position $InterfacePosition"
    $quantity = [math]::Round($quantity,2,[System.MidpointRounding]::AwayFromZero)

    $interfaceCompany = ConvertTo-LimitedText (Get-ConfigValue $InterfaceConfig 'InterfaceCompany' '') 5 'IFGPIFFI' -FailWhenTooLong
    $externalId = ConvertTo-LimitedText $Row.quote_unique_id 32 'IFGPIFNR' -FailWhenTooLong

    $quantityUnit = Get-OptionalCsvValue $Row 'quantity_unit' `
        ([string](Get-ConfigValue $InterfaceConfig 'QuantityUnit' ''))

    $priceType = Get-OptionalCsvValue $Row 'price_type' `
        ([string](Get-ConfigValue $InterfaceConfig 'PriceType' 'AKD'))

    $priceDimension = Get-OptionalCsvValue $Row 'price_dimension' `
        ([string](Get-ConfigValue $InterfaceConfig 'PriceDimension' '1'))

    $identifierAccess = Get-OptionalCsvValue $Row 'identifier_access' `
        ([string](Get-ConfigValue $InterfaceConfig 'IdentifierAccess' '0'))

    $description1 = Get-OptionalCsvValue $Row 'article_description1' ''
    $description2 = Get-OptionalCsvValue $Row 'article_description2' ''

    $data = [ordered]@{
        # Verknüpfung zum IFGK-Kopf und eindeutige IF-Position
        IFGPIFGK = $HeaderTimestamp
        IFGPIFGP = $InterfacePosition
        IFGPTSTP = New-UniqueDb2Timestamp

        # Alternativer Zugriffsschlüssel
        IFGPIFFI = $interfaceCompany
        IFGPIFNR = $externalId

        # Erfassung
        IFGPERUS = $RuntimeValues.CaptureUser
        IFGPERDA = $RuntimeValues.Date
        IFGPEZEI = $RuntimeValues.Time

        # Firma / spätere Ergebnisfelder
        IFGPFIRM = ConvertTo-LimitedText (Get-ConfigValue $InterfaceConfig 'Company' '01') 2 'IFGPFIRM' -FailWhenTooLong
        IFGPAGJJ = 0
        IFGPAGNR = ''
        IFGPAGPO = 0

        # Fehler-/Übernahmeinformationen
        IFGPFENR = ''
        IFGPFFLD = ''
        IFGPPA03 = ''
        IFGPPA04 = ''
        IFGPPA05 = ''
        IFGPPA06 = ''
        IFGPPA07 = ''
        IFGPUEDA = 0
        IFGPUEUZ = 0

        # Laut Trend-Dokumentation bei Neuanlage zwingend 10
        IFGPIFST = '10'
        IFGPIFPO = '10'
        IFGPFR01 = ''

        # Fachliche Position
        IFGPTENR = ConvertTo-LimitedText $Row.article_number 15 'IFGPTENR/article_number' -FailWhenTooLong
        IFGPTEKZ = ConvertTo-LimitedText $identifierAccess 1 'IFGPTEKZ' -FailWhenTooLong
        IFGPTBZ1 = ConvertTo-LimitedText $description1 30 'IFGPTBZ1' -FailWhenTooLong
        IFGPTBZ2 = ConvertTo-LimitedText $description2 30 'IFGPTBZ2' -FailWhenTooLong
        IFGPMENG = $quantity

        # Laut Projektdokumentation wird eine leere Mengeneinheit bei der
        # Übernahme aus TEIL.TEMEVK, ersatzweise TEIL.TEMEIN, vorbelegt.
        IFGPMEIN = ConvertTo-LimitedText $quantityUnit 1 'IFGPMEIN' -FailWhenTooLong

        IFGPPRAR = ConvertTo-LimitedText $priceType 3 'IFGPPRAR' -FailWhenTooLong
        IFGPPREI = $price
        IFGPPDIM = ConvertTo-LimitedText $priceDimension 1 'IFGPPDIM' -FailWhenTooLong
        IFGPFREI = ConvertTo-LimitedText (Get-ConfigValue $InterfaceConfig 'PositionFreeText' '') 512 'IFGPFREI' -FailWhenTooLong
    }

    $physical = Get-ConfigValue $InterfaceConfig 'PhysicalAuditFields' @{}
    if ([bool](Get-ConfigValue $physical 'Enabled' $false)) {
        $data.Insert(0,'IFGPLOCK',ConvertTo-LimitedText (Get-ConfigValue $physical 'Lock' '') 1 'IFGPLOCK' -FailWhenTooLong)
        $data.Insert(1,'IFGPJNAM',ConvertTo-LimitedText (Get-ConfigValue $physical 'JobName' 'APICAL') 10 'IFGPJNAM' -FailWhenTooLong)
        $data.Insert(2,'IFGPJDAT',$RuntimeValues.Date)
        $data.Insert(3,'IFGPJZEI',$RuntimeValues.Time)
        $data.Insert(4,'IFGPUSER',ConvertTo-LimitedText (Get-ConfigValue $physical 'User' $RuntimeValues.CaptureUser) 10 'IFGPUSER' -FailWhenTooLong)
        $data.Insert(5,'IFGPPROG',ConvertTo-LimitedText (Get-ConfigValue $physical 'Program' 'APICAL') 10 'IFGPPROG' -FailWhenTooLong)
        $data.Insert(6,'IFGPBIBL',ConvertTo-LimitedText (Get-ConfigValue $physical 'Library' '') 10 'IFGPBIBL' -FailWhenTooLong)
    }

    $allPositionFields = @(
        'IFGPLOCK','IFGPJNAM','IFGPJDAT','IFGPJZEI','IFGPUSER','IFGPPROG','IFGPBIBL',
        'IFGPIFGK','IFGPIFGP','IFGPTSTP','IFGPIFFI','IFGPIFNR','IFGPERUS','IFGPERDA',
        'IFGPEZEI','IFGPFIRM','IFGPAGJJ','IFGPAGNR','IFGPAGPO','IFGPFENR','IFGPFFLD',
        'IFGPPA03','IFGPPA04','IFGPPA05','IFGPPA06','IFGPPA07','IFGPUEDA','IFGPUEUZ',
        'IFGPIFST','IFGPIFPO','IFGPFR01','IFGPTENR','IFGPTEKZ','IFGPTBZ1','IFGPTBZ2',
        'IFGPMENG','IFGPMEIN','IFGPPRAR','IFGPPREI','IFGPPDIM','IFGPFREI'
    )

    Add-AdditionalFields `
        -Data $data `
        -AdditionalFields (Get-ConfigValue $InterfaceConfig 'AdditionalPositionFields' @{}) `
        -AllowedFieldNames $allPositionFields `
        -Context 'Interface.AdditionalPositionFields'

    return $data
}

function Test-QualifiedTableName {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [string] $TableName)

    if ($TableName -notmatch '^[A-Za-z0-9_#$@]+\.[A-Za-z0-9_#$@]+$') {
        throw "Ungültiger Tabellenname '$TableName'. Erwartet SCHEMA.TABELLE."
    }
}

function Test-ExecuteSafety {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [hashtable] $ApiConfig,
        [Parameter(Mandatory)] [string] $LogPath
    )

    $headerTable = [string](Get-ConfigValue $ApiConfig 'HeaderTable' '')
    $positionTable = [string](Get-ConfigValue $ApiConfig 'PositionTable' '')

    Test-QualifiedTableName $headerTable
    Test-QualifiedTableName $positionTable

    $allowProduction = [bool](Get-ConfigValue $ApiConfig 'AllowProductionTables' $false)

    if (-not $allowProduction) {
        if ($headerTable -notmatch '^(?i)TVPFTEST\.IFGK$' -or
            $positionTable -notmatch '^(?i)TVPFTEST\.IFGP$') {
            throw "Sicherheitsabbruch: Solange Api.AllowProductionTables=false ist, sind ausschließlich TVPFTEST.IFGK und TVPFTEST.IFGP erlaubt."
        }
    }

    Write-IfLog "Schreibziel: Header=$headerTable, Position=$positionTable, AllowProductionTables=$allowProduction" WARN $LogPath
}

function Get-AddUrl {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [hashtable] $ApiConfig)

    $add = ([string](Get-ConfigValue $ApiConfig 'AddUrl' '')).Trim()
    if (-not [string]::IsNullOrWhiteSpace($add)) {
        return $add
    }

    $base = ([string](Get-ConfigValue $ApiConfig 'BaseUrl' '')).TrimEnd('/')
    if ([string]::IsNullOrWhiteSpace($base)) {
        throw 'Api.AddUrl und Api.BaseUrl sind leer.'
    }

    return "$base/add"
}

function New-OdbcConnection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [hashtable] $VerificationConfig,
        [Parameter(Mandatory)] [string] $ProjectRoot
    )

    $connectionString = ([string](Get-ConfigValue $VerificationConfig 'ConnectionString' '')).Trim()
    if ([string]::IsNullOrWhiteSpace($connectionString) -or $connectionString -match 'SET_ME') {
        throw 'Verification.ConnectionString ist für ODBC nicht konfiguriert.'
    }

    $username = ([string](Get-ConfigValue $VerificationConfig 'Username' '')).Trim()
    $passwordFile = Resolve-ProjectPath $ProjectRoot ([string](Get-ConfigValue $VerificationConfig 'PasswordFile' ''))

    if (-not [string]::IsNullOrWhiteSpace($username)) {
        $connectionString += ";UID=$username"
    }

    if (-not [string]::IsNullOrWhiteSpace($passwordFile)) {
        $password = Get-ProtectedSecret $passwordFile
        $connectionString += ";PWD=$password"
    }

    $connection = New-Object System.Data.Odbc.OdbcConnection -ArgumentList $connectionString
    $connection.Open()
    return $connection
}

function Invoke-OdbcRows {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [hashtable] $VerificationConfig,
        [Parameter(Mandatory)] [string] $ProjectRoot,
        [Parameter(Mandatory)] [string] $Sql,
        [Parameter(Mandatory)] [object[]] $Parameters
    )

    $connection = $null
    try {
        $connection = New-OdbcConnection $VerificationConfig $ProjectRoot
        $command = $connection.CreateCommand()
        $command.CommandText = $Sql

        foreach ($value in $Parameters) {
            $parameter = $command.CreateParameter()
            $parameter.Value = $value
            [void]$command.Parameters.Add($parameter)
        }

        $adapter = New-Object System.Data.Odbc.OdbcDataAdapter -ArgumentList $command
        $table = New-Object System.Data.DataTable
        [void]$adapter.Fill($table)

        $rows = New-Object System.Collections.Generic.List[object]
        foreach ($dataRow in $table.Rows) {
            $obj = [ordered]@{}
            foreach ($column in $table.Columns) {
                $obj[[string]$column.ColumnName] = $dataRow[$column]
            }
            $rows.Add([pscustomobject]$obj)
        }

        return $rows.ToArray()
    }
    finally {
        if ($null -ne $connection) {
            $connection.Dispose()
        }
    }
}

function Get-ExistingIfHeader {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [hashtable] $VerificationConfig,
        [Parameter(Mandatory)] [string] $ProjectRoot,
        [Parameter(Mandatory)] [string] $HeaderTable,
        [Parameter(Mandatory)] [string] $InterfaceCompany,
        [Parameter(Mandatory)] [string] $InterfaceNumber
    )

    Test-QualifiedTableName $HeaderTable

    $sql = @"
SELECT
    IFGKTSTP,
    IFGKIFFI,
    IFGKIFNR,
    IFGKIFST,
    IFGKIFKO,
    IFGKIFPO,
    IFGKFENR,
    IFGKFFLD,
    IFGKAGJJ,
    IFGKAGNR,
    IFGKUEDA,
    IFGKUEUZ
FROM $HeaderTable
WHERE IFGKIFFI = ?
  AND IFGKIFNR = ?
FETCH FIRST 2 ROWS ONLY
"@

    return @(
        Invoke-OdbcRows `
            -VerificationConfig $VerificationConfig `
            -ProjectRoot $ProjectRoot `
            -Sql $sql `
            -Parameters @($InterfaceCompany,$InterfaceNumber)
    )
}

function Get-ExistingIfPositions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [hashtable] $VerificationConfig,
        [Parameter(Mandatory)] [string] $ProjectRoot,
        [Parameter(Mandatory)] [string] $PositionTable,
        [Parameter(Mandatory)] [string] $InterfaceCompany,
        [Parameter(Mandatory)] [string] $InterfaceNumber
    )

    Test-QualifiedTableName $PositionTable

    $sql = @"
SELECT
    IFGPIFGK,
    IFGPIFGP,
    IFGPTSTP,
    IFGPIFFI,
    IFGPIFNR,
    IFGPIFST,
    IFGPIFPO,
    IFGPFENR,
    IFGPFFLD,
    IFGPTENR,
    IFGPMENG,
    IFGPPREI,
    IFGPAGJJ,
    IFGPAGNR,
    IFGPAGPO
FROM $PositionTable
WHERE IFGPIFFI = ?
  AND IFGPIFNR = ?
ORDER BY IFGPIFGP
"@

    return @(
        Invoke-OdbcRows `
            -VerificationConfig $VerificationConfig `
            -ProjectRoot $ProjectRoot `
            -Sql $sql `
            -Parameters @($InterfaceCompany,$InterfaceNumber)
    )
}

function Test-OdbcVerificationEnabled {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [hashtable] $VerificationConfig)

    return (([string](Get-ConfigValue $VerificationConfig 'Mode' 'None')).Trim() -ieq 'Odbc')
}

function Send-IfQuoteCsv {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $CsvPath,
        [Parameter(Mandatory)] [hashtable] $ApiConfig,
        [Parameter(Mandatory)] [hashtable] $InterfaceConfig,
        [Parameter(Mandatory)] [hashtable] $VerificationConfig,
        [Parameter(Mandatory)] [string] $ProjectRoot,
        [Parameter(Mandatory)] [string] $LogPath,
        [Parameter(Mandatory)] [string] $RequestDumpDirectory,
        [switch] $DryRun
    )

    if (-not (Test-Path -LiteralPath $CsvPath -PathType Leaf)) {
        throw "CSV-Datei nicht gefunden: $CsvPath"
    }

    $rows = @(
        Import-Csv -LiteralPath $CsvPath -Delimiter ';' -Encoding UTF8
    )

    Test-IfCsvSchema $rows $CsvPath

    $headerTable = [string](Get-ConfigValue $ApiConfig 'HeaderTable' 'TVPFTEST.IFGK')
    $positionTable = [string](Get-ConfigValue $ApiConfig 'PositionTable' 'TVPFTEST.IFGP')
    $timeout = [int](Get-ConfigValue $ApiConfig 'TimeoutSeconds' 90)
    $testMode = [bool](Get-ConfigValue $ApiConfig 'TestMode' $true)
    $addUrl = Get-AddUrl $ApiConfig

    $bearer = [string](Get-ConfigValue $ApiConfig 'BearerToken' '')
    if ([string]::IsNullOrWhiteSpace($bearer)) {
        $tokenFile = Resolve-ProjectPath $ProjectRoot ([string](Get-ConfigValue $ApiConfig 'BearerTokenFile' ''))
        if (-not [string]::IsNullOrWhiteSpace($tokenFile) -and
            (Test-Path -LiteralPath $tokenFile -PathType Leaf)) {
            $bearer = Get-ProtectedSecret $tokenFile
        }
    }

    $headers = New-ApiHeaders $bearer
    $groups = @($rows | Group-Object -Property quote_unique_id)

    $successful = 0
    $skipped = 0
    $failed = 0
    $simulated = 0
    $details = New-Object System.Collections.Generic.List[object]

    Write-IfLog "IF-CSV-Import startet: $CsvPath | Header=$headerTable | Position=$positionTable | Api.TestMode=$testMode | DryRun=$([bool]$DryRun)" INFO $LogPath

    $verificationEnabled = Test-OdbcVerificationEnabled $VerificationConfig

    if (-not $DryRun -and -not $verificationEnabled) {
        Write-IfLog 'ODBC-Verifikation ist deaktiviert. Duplikat- und Nachkontrolle erfolgt nur über DB-Schlüssel/API-Fehler. Für Scheduler-Betrieb wird Verification.Mode=Odbc empfohlen.' WARN $LogPath
    }

    foreach ($group in $groups) {
        $groupRows = @($group.Group)
        $externalId = ([string]$group.Name).Trim()

        try {
            Write-IfLog ('-' * 90) INFO $LogPath
            Write-IfLog "Verarbeite quote_unique_id=$externalId, Positionen=$($groupRows.Count)" INFO $LogPath

            Test-IfGroup $groupRows $InterfaceConfig

            $first = $groupRows[0]
            $runtime = New-InterfaceRuntimeValues $InterfaceConfig
            $headerTimestamp = New-UniqueDb2Timestamp

            $headerData = New-IfHeaderData `
                -FirstRow $first `
                -InterfaceConfig $InterfaceConfig `
                -RuntimeValues $runtime `
                -HeaderTimestamp $headerTimestamp `
                -LogPath $LogPath

            $positionDataList = New-Object System.Collections.Generic.List[object]
            $positionNumber = 0

            foreach ($row in $groupRows) {
                $positionNumber++
                $positionData = New-IfPositionData `
                    -Row $row `
                    -InterfaceConfig $InterfaceConfig `
                    -RuntimeValues $runtime `
                    -HeaderTimestamp $headerTimestamp `
                    -InterfacePosition $positionNumber `
                    -LogPath $LogPath

                $positionDataList.Add($positionData)
            }

            # Vollständige Payloads müssen VOR dem ersten INSERT erzeugt sein.
            $headerBody = [ordered]@{
                table = $headerTable
                testMode = $testMode
                data = $headerData
            }

            $safeId = $externalId -replace '[^A-Za-z0-9_.-]','_'

            # Request-Dumps werden IMMER erzeugt, aber an dieser Stelle wird
            # ausdrücklich noch kein API-Aufruf ausgeführt.
            Ensure-Directory $RequestDumpDirectory
            $headerDumpPath = Join-Path $RequestDumpDirectory "IFGK_${safeId}.json"
            $headerBody | ConvertTo-Json -Depth 20 | Out-File -LiteralPath $headerDumpPath -Encoding utf8 -Force
            Write-IfLog "JSON-Dump: $headerDumpPath" DEBUG $LogPath

            for ($i = 0; $i -lt $positionDataList.Count; $i++) {
                $pos = $i + 1
                $positionBody = [ordered]@{
                    table = $positionTable
                    testMode = $testMode
                    data = $positionDataList[$i]
                }

                $positionDumpPath = Join-Path $RequestDumpDirectory ("IFGP_{0}_{1:D4}.json" -f $safeId,$pos)
                $positionBody | ConvertTo-Json -Depth 20 | Out-File -LiteralPath $positionDumpPath -Encoding utf8 -Force
                Write-IfLog "JSON-Dump: $positionDumpPath" DEBUG $LogPath
            }

            if ($DryRun) {
                $successful++
                $details.Add([pscustomobject]@{
                    ExternalId = $externalId
                    Status = 'DryRun'
                    HeaderTimestamp = $headerTimestamp
                    Positions = $positionDataList.Count
                    Error = $null
                })
                continue
            }

            $interfaceCompany = [string]$headerData.IFGKIFFI

            if ($verificationEnabled) {
                $existingHeader = @(
                    Get-ExistingIfHeader `
                        -VerificationConfig $VerificationConfig `
                        -ProjectRoot $ProjectRoot `
                        -HeaderTable $headerTable `
                        -InterfaceCompany $interfaceCompany `
                        -InterfaceNumber $externalId
                )

                if ($existingHeader.Count -gt 1) {
                    throw "Mehr als ein IFGK-Satz für IF-Firma=$interfaceCompany, IF-Nr=$externalId gefunden."
                }

                if ($existingHeader.Count -eq 1) {
                    $existingPositions = @(
                        Get-ExistingIfPositions `
                            -VerificationConfig $VerificationConfig `
                            -ProjectRoot $ProjectRoot `
                            -PositionTable $positionTable `
                            -InterfaceCompany $interfaceCompany `
                            -InterfaceNumber $externalId
                    )

                    if ($existingPositions.Count -eq $positionDataList.Count) {
                        Write-IfLog "IF-Satz ist bereits vollständig vorhanden: IFGK=1, IFGP=$($existingPositions.Count). Gruppe wird übersprungen." WARN $LogPath
                        $skipped++
                        $details.Add([pscustomobject]@{
                            ExternalId = $externalId
                            Status = 'AlreadyExists'
                            HeaderTimestamp = [string]$existingHeader[0].IFGKTSTP
                            Positions = $existingPositions.Count
                            Error = $null
                        })
                        continue
                    }

                    throw "IFGK existiert bereits, aber IFGP-Anzahl stimmt nicht. DB=$($existingPositions.Count), CSV=$($positionDataList.Count). Manueller Review erforderlich."
                }
            }

            # Erst jetzt echte INSERT-Aufrufe.
            $headerResult = Invoke-IfApi `
                -Url $addUrl `
                -Method POST `
                -Body $headerBody `
                -Headers $headers `
                -LogPath $LogPath `
                -Context "IFGK INSERT $externalId" `
                -TimeoutSeconds $timeout `
                -AllowSimulation:$testMode

            if (-not $headerResult.Success) {
                throw "IFGK-Insert fehlgeschlagen: $($headerResult.Error)"
            }

            if ($headerResult.Simulated) {
                Write-IfLog "IFGK wurde von der API nur simuliert. Api.TestMode=True." WARN $LogPath
            }

            $allPositionsSimulated = $true

            for ($i = 0; $i -lt $positionDataList.Count; $i++) {
                $pos = $i + 1
                $positionBody = [ordered]@{
                    table = $positionTable
                    testMode = $testMode
                    data = $positionDataList[$i]
                }

                $positionResult = Invoke-IfApi `
                    -Url $addUrl `
                    -Method POST `
                    -Body $positionBody `
                    -Headers $headers `
                    -LogPath $LogPath `
                    -Context "IFGP INSERT $externalId Pos=$pos" `
                    -TimeoutSeconds $timeout `
                    -AllowSimulation:$testMode

                if (-not $positionResult.Success) {
                    throw "IFGP-Insert Position $pos fehlgeschlagen: $($positionResult.Error)"
                }

                if (-not $positionResult.Simulated) {
                    $allPositionsSimulated = $false
                }
            }

            if ($testMode -or $headerResult.Simulated -or $allPositionsSimulated) {
                $simulated++
                $details.Add([pscustomobject]@{
                    ExternalId = $externalId
                    Status = 'ApiSimulation'
                    HeaderTimestamp = $headerTimestamp
                    Positions = $positionDataList.Count
                    Error = $null
                })
                Write-IfLog "API-Testmodus: $externalId wurde nicht als persistierter Import gewertet." WARN $LogPath
                continue
            }

            if ($verificationEnabled) {
                $verifyHeader = @(
                    Get-ExistingIfHeader `
                        -VerificationConfig $VerificationConfig `
                        -ProjectRoot $ProjectRoot `
                        -HeaderTable $headerTable `
                        -InterfaceCompany $interfaceCompany `
                        -InterfaceNumber $externalId
                )

                $verifyPositions = @(
                    Get-ExistingIfPositions `
                        -VerificationConfig $VerificationConfig `
                        -ProjectRoot $ProjectRoot `
                        -PositionTable $positionTable `
                        -InterfaceCompany $interfaceCompany `
                        -InterfaceNumber $externalId
                )

                if ($verifyHeader.Count -ne 1) {
                    throw "Nachkontrolle IFGK fehlgeschlagen. Erwartet=1, Gefunden=$($verifyHeader.Count)."
                }

                if ($verifyPositions.Count -ne $positionDataList.Count) {
                    throw "Nachkontrolle IFGP fehlgeschlagen. Erwartet=$($positionDataList.Count), Gefunden=$($verifyPositions.Count)."
                }

                Write-IfLog "ODBC-Nachkontrolle erfolgreich: IFGK=1, IFGP=$($verifyPositions.Count)." INFO $LogPath
            }

            $successful++
            $details.Add([pscustomobject]@{
                ExternalId = $externalId
                Status = 'Inserted'
                HeaderTimestamp = $headerTimestamp
                Positions = $positionDataList.Count
                Error = $null
            })

            Write-IfLog "IF-Briefkasten erfolgreich befüllt: IF-Nr=$externalId, Positionen=$($positionDataList.Count)." INFO $LogPath
        }
        catch {
            $failed++
            $details.Add([pscustomobject]@{
                ExternalId = $externalId
                Status = 'Failed'
                HeaderTimestamp = $null
                Positions = $groupRows.Count
                Error = $_.Exception.Message
            })
            Write-IfLog "Fehler bei quote_unique_id=$externalId: $($_.Exception.Message)" ERROR $LogPath
        }
    }

    $canArchive = (-not $DryRun -and -not $testMode -and $failed -eq 0 -and $simulated -eq 0)

    Write-IfLog "CSV-Abschluss: Gruppen=$($groups.Count), Erfolgreich=$successful, Übersprungen=$skipped, Simulation=$simulated, Fehler=$failed, CanArchive=$canArchive" INFO $LogPath

    return [pscustomobject]@{
        Groups = $groups.Count
        Successful = $successful
        Skipped = $skipped
        Simulated = $simulated
        Failed = $failed
        CanArchive = $canArchive
        Details = $details.ToArray()
    }
}

Export-ModuleMember -Function @(
    'Get-ConfigValue',
    'Resolve-ProjectPath',
    'Ensure-Directory',
    'Initialize-IfLog',
    'Write-IfLog',
    'Read-ApiBearerToken',
    'Get-ProtectedSecret',
    'Test-ExecuteSafety',
    'Send-IfQuoteCsv',
    'Get-ExistingIfHeader',
    'Get-ExistingIfPositions'
)
