#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    SFTP-Funktionen für den Angebotsimport.

.DESCRIPTION
    Dateien werden zunächst nur heruntergeladen. Die Remote-Datei wird bewusst
    NICHT direkt nach dem Download gelöscht. Process-AllCsv.ps1 löscht sie erst,
    nachdem AGKO und alle AGPO-Positionen erfolgreich verarbeitet wurden.
#>

function Get-SftpConfigValue {
    param(
        [Parameter(Mandatory)] $Object,
        [Parameter(Mandatory)] [string] $Name,
        $Default = $null
    )

    if ($Object -is [System.Collections.IDictionary]) {
        foreach ($key in $Object.Keys) {
            if ([string]$key -ieq $Name) {
                return $Object[$key]
            }
        }
    }

    return $Default
}

function Import-WinScpAssembly {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $WinScpNetDllPath
    )

    if (-not (Test-Path -LiteralPath $WinScpNetDllPath -PathType Leaf)) {
        throw "WinSCP .NET Assembly nicht gefunden: $WinScpNetDllPath"
    }

    if (-not ('WinSCP.Session' -as [type])) {
        Add-Type -Path $WinScpNetDllPath
    }
}

function New-QuoteSftpSession {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [hashtable] $SftpConfig,
        [Parameter(Mandatory)] [string] $LogPath
    )

    $dllPath = [string](Get-SftpConfigValue $SftpConfig 'WinScpNetDllPath' 'C:\Program Files (x86)\WinSCP\WinSCPnet.dll')
    Import-WinScpAssembly -WinScpNetDllPath $dllPath

    $hostName = [string](Get-SftpConfigValue $SftpConfig 'Host' '')
    $port = [int](Get-SftpConfigValue $SftpConfig 'Port' 22)
    $userName = [string](Get-SftpConfigValue $SftpConfig 'User' '')
    $passwordFile = [string](Get-SftpConfigValue $SftpConfig 'PasswordFile' '')
    $privateKeyPath = [string](Get-SftpConfigValue $SftpConfig 'PrivateKeyPath' '')
    $hostKeyFingerprint = [string](Get-SftpConfigValue $SftpConfig 'SshHostKeyFingerprint' '')
    $allowInsecure = [bool](Get-SftpConfigValue $SftpConfig 'AllowInsecureHostKey' $false)

    if ([string]::IsNullOrWhiteSpace($hostName)) {
        throw 'Sftp.Host ist nicht konfiguriert.'
    }
    if ([string]::IsNullOrWhiteSpace($userName)) {
        throw 'Sftp.User ist nicht konfiguriert.'
    }

    $sessionOptions = New-Object WinSCP.SessionOptions
    $sessionOptions.Protocol = [WinSCP.Protocol]::Sftp
    $sessionOptions.HostName = $hostName
    $sessionOptions.PortNumber = $port
    $sessionOptions.UserName = $userName

    if (-not [string]::IsNullOrWhiteSpace($privateKeyPath)) {
        if (-not (Test-Path -LiteralPath $privateKeyPath -PathType Leaf)) {
            throw "SFTP Private Key nicht gefunden: $privateKeyPath"
        }
        $sessionOptions.SshPrivateKeyPath = $privateKeyPath
    }

    if (-not [string]::IsNullOrWhiteSpace($passwordFile)) {
        $sessionOptions.Password = Get-ProtectedSecret -Path $passwordFile
    }

    if (-not [string]::IsNullOrWhiteSpace($hostKeyFingerprint)) {
        $sessionOptions.SshHostKeyFingerprint = $hostKeyFingerprint
    }
    elseif ($allowInsecure) {
        Write-QuoteLog -Message 'WARNUNG: SFTP-Host-Key wird nicht geprüft. Nur vorübergehend für Tests verwenden.' -Level WARN -LogPath $LogPath
        $sessionOptions.GiveUpSecurityAndAcceptAnySshHostKey = $true
    }
    else {
        throw 'Sftp.SshHostKeyFingerprint fehlt. Unsichere Host-Key-Akzeptanz ist deaktiviert.'
    }

    $session = New-Object WinSCP.Session
    $session.SessionLogPath = [string](Get-SftpConfigValue $SftpConfig 'SessionLogPath' '')
    $session.Open($sessionOptions)
    return $session
}

function Join-SftpPath {
    param(
        [Parameter(Mandatory)] [string] $Directory,
        [Parameter(Mandatory)] [string] $Name
    )

    $cleanDirectory = if ([string]::IsNullOrWhiteSpace($Directory)) { '/' } else { $Directory.TrimEnd('/') }
    if ($cleanDirectory -eq '') {
        $cleanDirectory = '/'
    }

    if ($cleanDirectory -eq '/') {
        return "/$Name"
    }

    return "$cleanDirectory/$Name"
}

function Receive-QuoteCsvFromSftp {
    <#
    .OUTPUTS
        Objekte mit RemotePath, LocalPath, FileName und Downloaded.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [hashtable] $SftpConfig,
        [Parameter(Mandatory)] [string] $LocalDirectory,
        [Parameter(Mandatory)] [string] $LogPath
    )

    Ensure-Directory -Path $LocalDirectory

    $remoteDirectory = [string](Get-SftpConfigValue $SftpConfig 'RemoteDirectory' '/')
    $fileMask = [string](Get-SftpConfigValue $SftpConfig 'FileMask' '*.csv')
    $session = $null
    $results = New-Object System.Collections.Generic.List[object]

    try {
        Write-QuoteLog -Message "Öffne SFTP-Verbindung für Download aus $remoteDirectory." -Level INFO -LogPath $LogPath
        $session = New-QuoteSftpSession -SftpConfig $SftpConfig -LogPath $LogPath

        $directory = $session.ListDirectory($remoteDirectory)
        $remoteFiles = @(
            $directory.Files |
            Where-Object { -not $_.IsDirectory -and $_.Name -like $fileMask } |
            Sort-Object -Property Name
        )

        if ($remoteFiles.Count -eq 0) {
            Write-QuoteLog -Message "Keine SFTP-Dateien passend zu '$fileMask' gefunden." -Level INFO -LogPath $LogPath
            return @()
        }

        $transferOptions = New-Object WinSCP.TransferOptions
        $transferOptions.TransferMode = [WinSCP.TransferMode]::Binary

        foreach ($remoteFile in $remoteFiles) {
            $remotePath = Join-SftpPath -Directory $remoteDirectory -Name $remoteFile.Name
            $localPath = Join-Path $LocalDirectory $remoteFile.Name

            if (Test-Path -LiteralPath $localPath -PathType Leaf) {
                Write-QuoteLog -Message "Lokale Datei existiert bereits und wird nicht überschrieben: $localPath" -Level WARN -LogPath $LogPath
                $results.Add([pscustomobject]@{
                    RemotePath = $remotePath
                    LocalPath  = $localPath
                    FileName   = $remoteFile.Name
                    Downloaded = $false
                })
                continue
            }

            $temporaryPath = "$localPath.download-$([guid]::NewGuid().ToString('N'))"
            Write-QuoteLog -Message "Lade $remotePath nach $localPath." -Level INFO -LogPath $LogPath

            $transfer = $session.GetFiles($remotePath, $temporaryPath, $false, $transferOptions)
            $transfer.Check()

            Move-Item -LiteralPath $temporaryPath -Destination $localPath -Force

            $results.Add([pscustomobject]@{
                RemotePath = $remotePath
                LocalPath  = $localPath
                FileName   = $remoteFile.Name
                Downloaded = $true
            })
        }

        return $results.ToArray()
    }
    finally {
        if ($null -ne $session) {
            $session.Dispose()
        }
    }
}

function Remove-QuoteSftpFiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [hashtable] $SftpConfig,
        [Parameter(Mandatory)] [string[]] $RemotePaths,
        [Parameter(Mandatory)] [string] $LogPath
    )

    if ($RemotePaths.Count -eq 0) {
        return
    }

    $session = $null
    try {
        $session = New-QuoteSftpSession -SftpConfig $SftpConfig -LogPath $LogPath

        foreach ($remotePath in $RemotePaths) {
            if ([string]::IsNullOrWhiteSpace($remotePath)) {
                continue
            }

            Write-QuoteLog -Message "Lösche nach erfolgreichem Import die SFTP-Datei: $remotePath" -Level INFO -LogPath $LogPath
            $removal = $session.RemoveFiles($remotePath)
            $removal.Check()
        }
    }
    finally {
        if ($null -ne $session) {
            $session.Dispose()
        }
    }
}

Export-ModuleMember -Function @(
    'Receive-QuoteCsvFromSftp',
    'Remove-QuoteSftpFiles'
)
