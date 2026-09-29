#requires -Version 5.1
[CmdletBinding()]
param(
    [string] $SettingsPath = '',
    [string] $MappingPath = '',
    [switch] $Execute,
    [switch] $SkipSftp,
    [switch] $PromptForBearerToken
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($SettingsPath)) { $SettingsPath = Join-Path $projectRoot 'config\QuoteImport.settings.psd1' }
if ([string]::IsNullOrWhiteSpace($MappingPath)) { $MappingPath = Join-Path $projectRoot 'config\QuoteImport.mapping.psd1' }

Import-Module (Join-Path $projectRoot 'modules\QuoteImport.Common.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $projectRoot 'modules\QuoteImport.Sftp.psm1') -Force -DisableNameChecking

$settings = Import-QuoteImportDataFile -Path $SettingsPath -Description 'Parameterdatei'
$mapping = Import-QuoteImportDataFile -Path $MappingPath -Description 'Mappingdatei'
Test-QuoteImportConfiguration -Settings $settings -Mapping $mapping -ProjectRoot $projectRoot

$paths = $settings.Paths
$api = $settings.Api
$sftp = $settings.Sftp
$logPath = [string]$paths.LogPath
$dryRun = -not $Execute
foreach ($directory in @($paths.IncomingDirectory, $paths.ArchiveDirectory, $paths.ResultDirectory, $paths.RequestDumpDirectory)) {
    Ensure-Directory -Path ([string]$directory)
}
Initialize-QuoteImportLog -LogPath $logPath

$promptConfigured = [bool](Get-ConfigValue $api 'PromptForBearerToken' $false)
if ($PromptForBearerToken -or $promptConfigured) {
    $api['BearerToken'] = Read-ApiBearerToken -Prompt 'API Bearer Token eingeben'
}

Write-QuoteLog -Message "Start. Execute=$([bool]$Execute); SkipSftp=$([bool]$SkipSftp); Mapping=$MappingPath" -Level INFO -LogPath $logPath
$downloadManifest = @()
if (-not $SkipSftp -and [bool]$sftp.Enabled) {
    $downloadManifest = @(Receive-QuoteCsvFromSftp -SftpConfig $sftp -LocalDirectory ([string]$paths.IncomingDirectory) -FileMask ([string]$mapping.Input.FileMask) -LogPath $logPath)
}

$remoteByLocal = @{}
foreach ($item in $downloadManifest) { $remoteByLocal[[string]$item.LocalPath] = [string]$item.RemotePath }
$inputFiles = @(Get-ChildItem -LiteralPath ([string]$paths.IncomingDirectory) -Filter ([string]$mapping.Input.FileMask) -File | Sort-Object Name)
if ($inputFiles.Count -eq 0) {
    Write-QuoteLog -Message "Keine Eingabedatei passend zu '$($mapping.Input.FileMask)' gefunden." -Level INFO -LogPath $logPath
    exit 0
}

$failedFiles = 0
foreach ($inputFile in $inputFiles) {
    try {
        $summary = Send-QuoteCsv -CsvPath $inputFile.FullName -ApiConfig $api -Defaults $settings.Defaults -NumberRangeConfig $settings.NumberRange -MasterDataConfig $settings.MasterData -MappingConfig $mapping -LogPath $logPath -RequestDumpDirectory ([string]$paths.RequestDumpDirectory) -DryRun:$dryRun
        $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        $tokens = @{ BaseName=$inputFile.BaseName; Extension=$inputFile.Extension; Timestamp=$timestamp }
        $resultName = Resolve-QuoteFileName -Template ([string]$mapping.Output.ResultFileName) -Tokens $tokens
        $resultPath = Join-Path -Path ([string]$paths.ResultDirectory) -ChildPath $resultName
        $summary.Details | Export-Csv -LiteralPath $resultPath -Delimiter ';' -Encoding UTF8 -NoTypeInformation
        if ($summary.Failed -gt 0) { throw "$($summary.Failed) Angebotsgruppe(n) fehlgeschlagen." }
        if ($dryRun) { continue }

        if ($remoteByLocal.ContainsKey($inputFile.FullName) -and [bool]$sftp.DeleteRemoteAfterSuccessfulImport) {
            Remove-QuoteSftpFiles -SftpConfig $sftp -RemotePaths @($remoteByLocal[$inputFile.FullName]) -LogPath $logPath
        }
        $archiveName = Resolve-QuoteFileName -Template ([string]$mapping.Output.ArchiveFileName) -Tokens $tokens
        Move-Item -LiteralPath $inputFile.FullName -Destination (Join-Path ([string]$paths.ArchiveDirectory) $archiveName) -Force
    }
    catch {
        $failedFiles++
        Write-QuoteLog -Message "Datei '$($inputFile.FullName)' fehlgeschlagen: $($_.Exception.Message)" -Level ERROR -LogPath $logPath
    }
}
if ($failedFiles -gt 0) { exit 1 }
exit 0
