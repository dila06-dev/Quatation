#requires -Version 5.1
[CmdletBinding()]
param(
    [string] $ConfigPath = '',

    # Ohne -Execute läuft der komplette Prozess als DryRun:
    # CSV lesen, validieren und JSON-Dumps erzeugen, aber keine Schreib-Requests.
    [switch] $Execute,

    # Überspringt den SFTP-Download und verarbeitet nur lokale CSV-Dateien.
    [switch] $SkipSftp,

    # Fragt den API Bearer Token verdeckt für diesen Lauf ab.
    # Der Token wird nur im Speicher gehalten und nicht protokolliert.
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

$commonModule = Join-Path $scriptDirectory 'QuoteImport.Common.psm1'
$sftpModule = Join-Path $scriptDirectory 'QuoteImport.Sftp.psm1'

Import-Module $commonModule -Force -DisableNameChecking
Import-Module $sftpModule -Force -DisableNameChecking

if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
    throw "Konfigurationsdatei nicht gefunden: $ConfigPath"
}

$config = Import-PowerShellDataFile -LiteralPath $ConfigPath
$paths = $config.Paths
$api = $config.Api
$defaults = $config.Defaults
$numberRange = $config.NumberRange
$masterData = $config.MasterData
$sftp = $config.Sftp

# Der Bearer-Token kann für einen manuellen Lauf sicher abgefragt werden.
# Die Eingabe erfolgt nur einmal, auch wenn mehrere CSV-Dateien verarbeitet werden.
$promptFromConfig = [bool](Get-ConfigValue `
    -Object $api `
    -Name 'PromptForBearerToken' `
    -Default $false)

if ($PromptForBearerToken -or $promptFromConfig) {
    $api['BearerToken'] = Read-ApiBearerToken `
        -Prompt 'API Bearer Token eingeben'

    Write-QuoteLog `
        -Message 'API Bearer Token wurde interaktiv für diesen Lauf übernommen.' `
        -Level INFO `
        -LogPath ([string]$paths.LogPath)
}

$incomingDirectory = [string]$paths.IncomingDirectory
$archiveDirectory = [string]$paths.ArchiveDirectory
$logPath = [string]$paths.LogPath
$requestDumpDirectory = [string]$paths.RequestDumpDirectory
$dryRun = -not $Execute

Ensure-Directory -Path $incomingDirectory
Ensure-Directory -Path $archiveDirectory
Ensure-Directory -Path $requestDumpDirectory
Initialize-QuoteImportLog -LogPath $logPath

Write-QuoteLog -Message "Gesamtprozess startet. Execute=$([bool]$Execute), DryRun=$dryRun, SkipSftp=$([bool]$SkipSftp), PromptForBearerToken=$([bool]($PromptForBearerToken -or $promptFromConfig))" -Level INFO -LogPath $logPath

# Manifest ordnet einer lokalen Datei den ursprünglichen Remote-Pfad zu.
$downloadManifest = @()
if (-not $SkipSftp -and [bool]$sftp.Enabled) {
    try {
        $downloadManifest = @(
            Receive-QuoteCsvFromSftp `
                -SftpConfig $sftp `
                -LocalDirectory $incomingDirectory `
                -LogPath $logPath
        )
    }
    catch {
        Write-QuoteLog -Message "SFTP-Download fehlgeschlagen: $($_.Exception.Message)" -Level ERROR -LogPath $logPath
        exit 2
    }
}
elseif (-not $SkipSftp) {
    Write-QuoteLog -Message 'SFTP ist in der Konfiguration deaktiviert. Es werden nur lokale Dateien verarbeitet.' -Level INFO -LogPath $logPath
}

$remotePathByLocalPath = @{}
foreach ($manifestItem in $downloadManifest) {
    $remotePathByLocalPath[[string]$manifestItem.LocalPath] = [string]$manifestItem.RemotePath
}

$csvFiles = @(
    Get-ChildItem -LiteralPath $incomingDirectory -Filter '*.csv' -File |
    Sort-Object -Property Name
)

if ($csvFiles.Count -eq 0) {
    Write-QuoteLog -Message 'Keine CSV-Dateien zur Verarbeitung gefunden.' -Level INFO -LogPath $logPath
    exit 0
}

$totalSuccessfulFiles = 0
$totalFailedFiles = 0

foreach ($csvFile in $csvFiles) {
    Write-QuoteLog -Message ('-' * 100) -Level INFO -LogPath $logPath
    Write-QuoteLog -Message "Datei startet: $($csvFile.FullName)" -Level INFO -LogPath $logPath

    try {
        $summary = Send-QuoteCsv `
            -CsvPath $csvFile.FullName `
            -ApiConfig $api `
            -Defaults $defaults `
            -NumberRangeConfig $numberRange `
            -MasterDataConfig $masterData `
            -LogPath $logPath `
            -RequestDumpDirectory $requestDumpDirectory `
            -DryRun:$dryRun

        if ($summary.Failed -gt 0) {
            throw "Mindestens eine Angebotsgruppe ist fehlgeschlagen: $($summary.Failed)"
        }

        if ($dryRun) {
            Write-QuoteLog -Message "DRY-RUN erfolgreich. Datei bleibt im Eingangsverzeichnis: $($csvFile.Name)" -Level INFO -LogPath $logPath
            $totalSuccessfulFiles++
            continue
        }

        # Erst nach einem vollständigen Import darf die Remote-Datei gelöscht werden.
        $localKey = [string]$csvFile.FullName
        if ($remotePathByLocalPath.ContainsKey($localKey) -and
            [bool]$sftp.DeleteRemoteAfterSuccessfulImport) {

            try {
                Remove-QuoteSftpFiles `
                    -SftpConfig $sftp `
                    -RemotePaths @($remotePathByLocalPath[$localKey]) `
                    -LogPath $logPath
            }
            catch {
                # Der Datenimport war bereits erfolgreich. Deshalb wird die lokale
                # Datei trotzdem archiviert. Die Duplikatprüfung über GKFREX schützt
                # bei erneutem Download vor einem zweiten Import.
                Write-QuoteLog -Message "Import erfolgreich, aber Remote-Löschung fehlgeschlagen: $($_.Exception.Message)" -Level WARN -LogPath $logPath
            }
        }

        $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        $archiveName = '{0}_{1}{2}' -f $csvFile.BaseName, $timestamp, $csvFile.Extension
        $archivePath = Join-Path $archiveDirectory $archiveName
        Move-Item -LiteralPath $csvFile.FullName -Destination $archivePath -Force

        Write-QuoteLog -Message "Datei erfolgreich archiviert: $archivePath" -Level INFO -LogPath $logPath
        $totalSuccessfulFiles++
    }
    catch {
        $totalFailedFiles++
        Write-QuoteLog -Message "Datei fehlgeschlagen und bleibt für Analyse/Wiederholung liegen: $($csvFile.FullName). Ursache: $($_.Exception.Message)" -Level ERROR -LogPath $logPath
    }
}

Write-QuoteLog -Message "Gesamtprozess beendet. Erfolgreiche Dateien=$totalSuccessfulFiles, Fehlerhafte Dateien=$totalFailedFiles" -Level INFO -LogPath $logPath

if ($totalFailedFiles -gt 0) {
    exit 1
}

exit 0
