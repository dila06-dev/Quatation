#requires -Version 5.1
[CmdletBinding()]
param(
    [string] $ConfigPath = ''
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

Import-Module (Join-Path $scriptDirectory 'QuoteImport.Common.psm1') -Force
Import-Module (Join-Path $scriptDirectory 'QuoteImport.Sftp.psm1') -Force

if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
    throw "Konfigurationsdatei nicht gefunden: $ConfigPath"
}

$config = Import-PowerShellDataFile -LiteralPath $ConfigPath
$logPath = [string]$config.Paths.LogPath
$incomingDirectory = [string]$config.Paths.IncomingDirectory

Initialize-QuoteImportLog -LogPath $logPath

if (-not [bool]$config.Sftp.Enabled) {
    throw 'Sftp.Enabled ist false. Der Download von Angebots-CSV-Dateien wurde nicht ausgeführt.'
}

$manifest = @(
    Receive-QuoteCsvFromSftp `
        -SftpConfig $config.Sftp `
        -LocalDirectory $incomingDirectory `
        -LogPath $logPath
)

$manifest | Format-Table -AutoSize

Write-QuoteLog `
    -Message 'Download der Angebots-CSV-Dateien beendet. Die Dateien auf dem SFTP werden erst nach erfolgreicher Erstellung von AGKO und AGPO durch Process-AllQuoteCsv.ps1 gelöscht.' `
    -Level INFO `
    -LogPath $logPath
