#requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $CsvPath,

    [string] $ConfigPath = '',

    # Ohne -Execute werden nur Validierung und JSON-Dumps durchgeführt.
    [switch] $Execute,

    # Fragt den API Bearer Token verdeckt für diesen Lauf ab.
    [switch] $PromptForBearerToken
)

# Windows PowerShell 5.1 kann $PSScriptRoot während der Auswertung
# eines Standardwerts im param-Block noch leer bereitstellen.
# Daher wird das Skriptverzeichnis erst nach dem param-Block bestimmt.
$scriptDirectory = $PSScriptRoot

if ([string]::IsNullOrWhiteSpace($scriptDirectory) -and
    -not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
    $scriptDirectory = Split-Path -Path $PSCommandPath -Parent
}

if ([string]::IsNullOrWhiteSpace($scriptDirectory)) {
    $scriptDirectory = (Get-Location).Path
}

if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
    $ConfigPath = Join-Path -Path $scriptDirectory -ChildPath 'QuoteImport.config.psd1'
}

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $scriptDirectory 'QuoteImport.Common.psm1') `
    -Force `
    -DisableNameChecking

if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
    throw "Konfigurationsdatei nicht gefunden: $ConfigPath"
}

$config = Import-PowerShellDataFile -LiteralPath $ConfigPath
$logPath = [string]$config.Paths.LogPath
$requestDumpDirectory = [string]$config.Paths.RequestDumpDirectory
$dryRun = -not $Execute

$promptFromConfig = [bool](Get-ConfigValue `
    -Object $config.Api `
    -Name 'PromptForBearerToken' `
    -Default $false)

if ($PromptForBearerToken -or $promptFromConfig) {
    $config.Api['BearerToken'] = Read-ApiBearerToken `
        -Prompt 'API Bearer Token eingeben'
}

Initialize-QuoteImportLog -LogPath $logPath

if ($PromptForBearerToken -or $promptFromConfig) {
    Write-QuoteLog `
        -Message 'API Bearer Token wurde interaktiv für diesen Lauf übernommen.' `
        -Level INFO `
        -LogPath $logPath
}

$summary = Send-QuoteCsv `
    -CsvPath $CsvPath `
    -ApiConfig $config.Api `
    -Defaults $config.Defaults `
    -NumberRangeConfig $config.NumberRange `
    -MasterDataConfig $config.MasterData `
    -LogPath $logPath `
    -RequestDumpDirectory $requestDumpDirectory `
    -DryRun:$dryRun

$summary | Format-List
$summary.Details | Format-Table -AutoSize

if ($summary.Failed -gt 0) {
    exit 1
}

exit 0
