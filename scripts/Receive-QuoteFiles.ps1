#requires -Version 5.1
[CmdletBinding()]
param([string]$SettingsPath='', [string]$MappingPath='')
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($SettingsPath)){$SettingsPath=Join-Path $root 'config\QuoteImport.settings.psd1'}
if ([string]::IsNullOrWhiteSpace($MappingPath)){$MappingPath=Join-Path $root 'config\QuoteImport.mapping.psd1'}
Import-Module (Join-Path $root 'modules\QuoteImport.Common.psm1') -Force
Import-Module (Join-Path $root 'modules\QuoteImport.Sftp.psm1') -Force
$settings=Import-QuoteImportDataFile $SettingsPath 'Parameterdatei'
$mapping=Import-QuoteImportDataFile $MappingPath 'Mappingdatei'
Test-QuoteImportConfiguration $settings $mapping $root
Initialize-QuoteImportLog $settings.Paths.LogPath
Receive-QuoteCsvFromSftp -SftpConfig $settings.Sftp -LocalDirectory $settings.Paths.IncomingDirectory -FileMask $mapping.Input.FileMask -LogPath $settings.Paths.LogPath
