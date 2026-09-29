#requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('Api','Odbc','Sftp')]
    [string] $Type = 'Api'
)

$root = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($root)) { $root = (Get-Location).Path }

$path = switch ($Type) {
    'Api'  { Join-Path $root 'runtime\secure\api-token.sec' }
    'Odbc' { Join-Path $root 'runtime\secure\odbc-password.sec' }
    'Sftp' { Join-Path $root 'runtime\secure\sftp-password.sec' }
}

$dir = Split-Path $path -Parent
if (-not (Test-Path $dir)) {
    New-Item $dir -ItemType Directory -Force | Out-Null
}

$secure = Read-Host "$Type Secret eingeben" -AsSecureString
$encrypted = ConvertFrom-SecureString -SecureString $secure
$utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($path,$encrypted,$utf8WithoutBom)

Write-Host "Secret-Datei erstellt: $path"
Write-Host 'Wichtig: DPAPI ist an denselben Windows-Benutzer und Rechner gebunden.'
