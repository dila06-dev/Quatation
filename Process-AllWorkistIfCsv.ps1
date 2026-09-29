#requires -Version 5.1
[CmdletBinding()]
param(
    [string] $ConfigPath = '',
    [switch] $Execute,
    [switch] $SkipSftp,
    [switch] $PromptForBearerToken
)

$scriptDirectory = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($scriptDirectory) -and
    -not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
    $scriptDirectory = Split-Path $PSCommandPath -Parent
}
if ([string]::IsNullOrWhiteSpace($scriptDirectory)) {
    $scriptDirectory = (Get-Location).Path
}
if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
    $ConfigPath = Join-Path $scriptDirectory 'WorkistIF.config.psd1'
}

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $scriptDirectory 'WorkistIF.Common.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $scriptDirectory 'WorkistIF.Sftp.psm1') -Force -DisableNameChecking

if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
    throw "Konfiguration nicht gefunden: $ConfigPath"
}

$config = Import-PowerShellDataFile -LiteralPath $ConfigPath

$paths = $config.Paths
$api = $config.Api
$interface = $config.Interface
$verification = $config.Verification
$sftp = $config.Sftp

$incoming = Resolve-ProjectPath $scriptDirectory ([string]$paths.IncomingDirectory)
$archive = Resolve-ProjectPath $scriptDirectory ([string]$paths.ArchiveDirectory)
$logPath = Resolve-ProjectPath $scriptDirectory ([string]$paths.LogPath)
$dumps = Resolve-ProjectPath $scriptDirectory ([string]$paths.RequestDumpDirectory)

Ensure-Directory $incoming
Ensure-Directory $archive
Ensure-Directory $dumps
Initialize-IfLog $logPath

$promptFromConfig = [bool](Get-ConfigValue $api 'PromptForBearerToken' $false)
if ($PromptForBearerToken -or $promptFromConfig) {
    $api['BearerToken'] = Read-ApiBearerToken 'API Bearer Token eingeben'
    Write-IfLog 'Bearer-Token wurde interaktiv für diesen Lauf übernommen.' INFO $logPath
}

$dryRun = -not $Execute

Write-IfLog "Gesamtprozess startet. Execute=$([bool]$Execute), DryRun=$dryRun, SkipSftp=$([bool]$SkipSftp)" INFO $logPath

if ($Execute) {
    Test-ExecuteSafety -ApiConfig $api -LogPath $logPath
}

# Relative SFTP-Pfade in absolute Projektpfade umwandeln.
foreach ($key in @('PasswordFile','PrivateKeyPath','SessionLogPath','WinScpNetDllPath')) {
    if ($sftp.ContainsKey($key) -and -not [string]::IsNullOrWhiteSpace([string]$sftp[$key])) {
        if ($key -ne 'WinScpNetDllPath' -or -not [System.IO.Path]::IsPathRooted([string]$sftp[$key])) {
            $sftp[$key] = Resolve-ProjectPath $scriptDirectory ([string]$sftp[$key])
        }
    }
}

$downloadManifest = @()
if (-not $SkipSftp -and [bool]$sftp.Enabled) {
    try {
        $downloadManifest = @(
            Receive-WorkistCsvFromSftp `
                -SftpConfig $sftp `
                -LocalDirectory $incoming `
                -LogPath $logPath
        )
    }
    catch {
        Write-IfLog "SFTP-Download fehlgeschlagen: $($_.Exception.Message)" ERROR $logPath
        exit 2
    }
}
elseif (-not $SkipSftp) {
    Write-IfLog 'SFTP ist deaktiviert. Es werden lokale CSV-Dateien verarbeitet.' INFO $logPath
}

$remoteByLocal = @{}
foreach ($item in $downloadManifest) {
    $remoteByLocal[[string]$item.LocalPath] = [string]$item.RemotePath
}

$files = @(
    Get-ChildItem -LiteralPath $incoming -Filter '*.csv' -File |
    Sort-Object Name
)

if ($files.Count -eq 0) {
    Write-IfLog 'Keine CSV-Dateien gefunden.' INFO $logPath
    exit 0
}

$okFiles = 0
$failedFiles = 0

foreach ($file in $files) {
    Write-IfLog ('=' * 100) INFO $logPath
    Write-IfLog "Datei startet: $($file.FullName)" INFO $logPath

    try {
        $summary = Send-IfQuoteCsv `
            -CsvPath $file.FullName `
            -ApiConfig $api `
            -InterfaceConfig $interface `
            -VerificationConfig $verification `
            -ProjectRoot $scriptDirectory `
            -LogPath $logPath `
            -RequestDumpDirectory $dumps `
            -DryRun:$dryRun

        if ($summary.Failed -gt 0) {
            throw "Mindestens eine IF-Gruppe ist fehlgeschlagen: $($summary.Failed)"
        }

        if (-not $summary.CanArchive) {
            if ($dryRun) {
                Write-IfLog "DRY-RUN erfolgreich. Datei bleibt im Incoming: $($file.Name)" INFO $logPath
            }
            else {
                Write-IfLog "Datei wurde nicht archiviert, weil kein vollständig persistierter Echtlauf bestätigt ist. Simulation=$($summary.Simulated)." WARN $logPath
            }

            $okFiles++
            continue
        }

        $localKey = [string]$file.FullName
        if ($remoteByLocal.ContainsKey($localKey) -and
            [bool]$sftp.DeleteRemoteAfterSuccessfulImport) {

            try {
                Remove-WorkistSftpFiles `
                    -SftpConfig $sftp `
                    -RemotePaths @($remoteByLocal[$localKey]) `
                    -LogPath $logPath
            }
            catch {
                Write-IfLog "IF-Import erfolgreich, Remote-Löschung aber fehlgeschlagen: $($_.Exception.Message)" WARN $logPath
            }
        }

        $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        $archiveName = '{0}_{1}{2}' -f $file.BaseName,$stamp,$file.Extension
        $archivePath = Join-Path $archive $archiveName
        Move-Item -LiteralPath $file.FullName -Destination $archivePath -Force

        Write-IfLog "Datei archiviert: $archivePath" INFO $logPath
        $okFiles++
    }
    catch {
        $failedFiles++
        Write-IfLog "Datei fehlgeschlagen und bleibt im Incoming: $($file.FullName). Ursache: $($_.Exception.Message)" ERROR $logPath
    }
}

Write-IfLog "Gesamtprozess beendet. Erfolgreiche Dateien=$okFiles, Fehlerhafte Dateien=$failedFiles" INFO $logPath

if ($failedFiles -gt 0) {
    exit 1
}

exit 0
