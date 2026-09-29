#requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $CsvPath,
    [string] $ConfigPath = '',
    [switch] $Execute,
    [switch] $PromptForBearerToken
)

$root = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($root)) { $root = (Get-Location).Path }
if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
    $ConfigPath = Join-Path $root 'WorkistIF.config.psd1'
}

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $root 'WorkistIF.Common.psm1') -Force -DisableNameChecking

$config = Import-PowerShellDataFile -LiteralPath $ConfigPath

$logPath = Resolve-ProjectPath $root ([string]$config.Paths.LogPath)
$dumps = Resolve-ProjectPath $root ([string]$config.Paths.RequestDumpDirectory)

Ensure-Directory (Split-Path $logPath -Parent)
Ensure-Directory $dumps
Initialize-IfLog $logPath

if ($PromptForBearerToken -or [bool](Get-ConfigValue $config.Api 'PromptForBearerToken' $false)) {
    $config.Api['BearerToken'] = Read-ApiBearerToken 'API Bearer Token eingeben'
}

if ($Execute) {
    Test-ExecuteSafety -ApiConfig $config.Api -LogPath $logPath
}

$summary = Send-IfQuoteCsv `
    -CsvPath $CsvPath `
    -ApiConfig $config.Api `
    -InterfaceConfig $config.Interface `
    -VerificationConfig $config.Verification `
    -ProjectRoot $root `
    -LogPath $logPath `
    -RequestDumpDirectory $dumps `
    -DryRun:(-not $Execute)

$summary | Format-List
if ($summary.Failed -gt 0) { exit 1 }
exit 0
