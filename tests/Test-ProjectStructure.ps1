#requires -Version 5.1
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$required=@(
 'config\QuoteImport.settings.psd1','config\QuoteImport.mapping.psd1',
 'modules\QuoteImport.Common.psm1','modules\QuoteImport.Sftp.psm1',
 'scripts\Start-QuoteImport.ps1','scripts\Receive-QuoteFiles.ps1','scripts\Send-OneQuoteFile.ps1'
)
foreach($relative in $required){
 if(-not(Test-Path -LiteralPath (Join-Path $root $relative) -PathType Leaf)){throw "Projektdatei fehlt: $relative"}
}
Import-Module (Join-Path $root 'modules\QuoteImport.Common.psm1') -Force
$settings=Import-QuoteImportDataFile (Join-Path $root 'config\QuoteImport.settings.psd1') 'Parameterdatei'
$mapping=Import-QuoteImportDataFile (Join-Path $root 'config\QuoteImport.mapping.psd1') 'Mappingdatei'
# SFTP-Abhängigkeit wird in diesem Strukturtest bewusst nicht benötigt.
$settings.Sftp.Enabled=$false
Test-QuoteImportConfiguration $settings $mapping $root
$name=Resolve-QuoteFileName $mapping.Output.ArchiveFileName @{BaseName='quotes';Timestamp='20260915_140000';Extension='.csv'}
if($name -ne 'quotes_20260915_140000.csv'){throw "Archivvorlage fehlerhaft: $name"}
Write-Host 'OK: Projektstruktur, Konfiguration und Dateinamensvorlagen sind konsistent.' -ForegroundColor Green
