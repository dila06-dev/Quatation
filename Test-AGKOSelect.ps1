#requires -Version 5.1
[CmdletBinding()]
param(
    [int] $Year = 2026,
    [string] $QuoteNumber = '100004',
    [string] $ConfigPath = '',

    # Fragt den Bearer-Token verdeckt ab und hat Vorrang vor der Token-Datei.
    [switch] $PromptForBearerToken
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDirectory = $PSScriptRoot

if ([string]::IsNullOrWhiteSpace($scriptDirectory) -and
    -not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
    $scriptDirectory = Split-Path -Path $PSCommandPath -Parent
}

if ([string]::IsNullOrWhiteSpace($scriptDirectory)) {
    $scriptDirectory = (Get-Location).Path
}

if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
    $ConfigPath = Join-Path $scriptDirectory 'QuoteImport.config.psd1'
}

Import-Module (Join-Path $scriptDirectory 'QuoteImport.Common.psm1') `
    -Force `
    -DisableNameChecking

$config = Import-PowerShellDataFile -LiteralPath $ConfigPath
$baseUrl = [string]$config.Api.HeaderSelectUrl

if ([string]::IsNullOrWhiteSpace($baseUrl)) {
    throw 'Api.HeaderSelectUrl ist leer.'
}

$headers = @{
    Accept = 'application/json'
}

$promptFromConfig = [bool](Get-ConfigValue `
    -Object $config.Api `
    -Name 'PromptForBearerToken' `
    -Default $false)

$token = ''

if ($PromptForBearerToken -or $promptFromConfig) {
    $token = Read-ApiBearerToken `
        -Prompt 'API Bearer Token eingeben'
}
else {
    $tokenFile = [string](Get-ConfigValue `
        -Object $config.Api `
        -Name 'BearerTokenFile' `
        -Default '')

    if (-not [string]::IsNullOrWhiteSpace($tokenFile) -and
        (Test-Path -LiteralPath $tokenFile -PathType Leaf)) {
        $token = Get-ProtectedSecret -Path $tokenFile
    }
}

if (-not [string]::IsNullOrWhiteSpace($token)) {
    $headers.Authorization = "Bearer $token"
}

$requestUrl =
    $baseUrl +
    '?GKAGJJ=' + [System.Uri]::EscapeDataString([string]$Year) +
    '&GKAGNR=' + [System.Uri]::EscapeDataString($QuoteNumber)

Write-Host "GET $requestUrl"

$response = Invoke-RestMethod `
    -Uri $requestUrl `
    -Method GET `
    -Headers $headers `
    -TimeoutSec ([int]$config.Api.TimeoutSeconds) `
    -ErrorAction Stop

$response | ConvertTo-Json -Depth 20
