#requires -Version 5.1
[CmdletBinding()]
param([string] $ConfigPath = '')

$root = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($root)) { $root = (Get-Location).Path }
if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
    $ConfigPath = Join-Path $root 'WorkistIF.config.psd1'
}

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $root 'WorkistIF.Common.psm1') -Force -DisableNameChecking

$config = Import-PowerShellDataFile -LiteralPath $ConfigPath

Write-Host '--- Kernkonfiguration ---'
Write-Host "HeaderTable:       $($config.Api.HeaderTable)"
Write-Host "PositionTable:     $($config.Api.PositionTable)"
Write-Host "Api.TestMode:      $($config.Api.TestMode)"
Write-Host "IF Firmen-Nr.:     $($config.Interface.InterfaceCompany)"
Write-Host "Firma:             $($config.Interface.Company)"
Write-Host "Vertragsart:       $($config.Interface.ContractType)"
Write-Host "Erfassungs-User:   $($config.Interface.CaptureUser)"
Write-Host "Verification.Mode: $($config.Verification.Mode)"

if ([string]::IsNullOrWhiteSpace([string]$config.Interface.InterfaceCompany) -or
    [string]$config.Interface.InterfaceCompany -eq 'SETME') {
    Write-Warning 'Interface.InterfaceCompany ist noch nicht gesetzt.'
}

Write-Host ''
Write-Host 'Konfiguration wurde geladen.'
