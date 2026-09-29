#requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$InputPath,
    [string]$SettingsPath='', [string]$MappingPath='', [switch]$Execute
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($SettingsPath)){$SettingsPath=Join-Path $root 'config\QuoteImport.settings.psd1'}
if ([string]::IsNullOrWhiteSpace($MappingPath)){$MappingPath=Join-Path $root 'config\QuoteImport.mapping.psd1'}
Import-Module (Join-Path $root 'modules\QuoteImport.Common.psm1') -Force
$settings=Import-QuoteImportDataFile $SettingsPath 'Parameterdatei'
$mapping=Import-QuoteImportDataFile $MappingPath 'Mappingdatei'
Test-QuoteImportConfiguration $settings $mapping $root
Initialize-QuoteImportLog $settings.Paths.LogPath
Send-QuoteCsv -CsvPath $InputPath -ApiConfig $settings.Api -Defaults $settings.Defaults -NumberRangeConfig $settings.NumberRange -MasterDataConfig $settings.MasterData -MappingConfig $mapping -LogPath $settings.Paths.LogPath -RequestDumpDirectory $settings.Paths.RequestDumpDirectory -DryRun:(-not $Execute)
