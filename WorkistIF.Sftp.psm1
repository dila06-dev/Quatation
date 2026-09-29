#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-SftpConfigValue {
    param(
        [Parameter(Mandatory)] $Object,
        [Parameter(Mandatory)] [string] $Name,
        $Default = $null
    )

    if ($Object -is [System.Collections.IDictionary]) {
        foreach ($key in $Object.Keys) {
            if ([string]$key -ieq $Name) { return $Object[$key] }
        }
    }
    return $Default
}

function Import-WinScpAssembly {
    param([Parameter(Mandatory)] [string] $WinScpNetDllPath)

    if (-not (Test-Path -LiteralPath $WinScpNetDllPath -PathType Leaf)) {
        throw "WinSCP .NET Assembly nicht gefunden: $WinScpNetDllPath"
    }

    if (-not ('WinSCP.Session' -as [type])) {
        Add-Type -Path $WinScpNetDllPath
    }
}

function New-WorkistSftpSession {
    param(
        [Parameter(Mandatory)] [hashtable] $SftpConfig,
        [Parameter(Mandatory)] [string] $LogPath
    )

    $dll = [string](Get-SftpConfigValue $SftpConfig 'WinScpNetDllPath' 'C:\Program Files (x86)\WinSCP\WinSCPnet.dll')
    Import-WinScpAssembly $dll

    $hostName = [string](Get-SftpConfigValue $SftpConfig 'Host' '')
    $userName = [string](Get-SftpConfigValue $SftpConfig 'User' '')
    $port = [int](Get-SftpConfigValue $SftpConfig 'Port' 22)
    $passwordFile = [string](Get-SftpConfigValue $SftpConfig 'PasswordFile' '')
    $privateKey = [string](Get-SftpConfigValue $SftpConfig 'PrivateKeyPath' '')
    $fingerprint = [string](Get-SftpConfigValue $SftpConfig 'SshHostKeyFingerprint' '')
    $allowInsecure = [bool](Get-SftpConfigValue $SftpConfig 'AllowInsecureHostKey' $false)

    if ([string]::IsNullOrWhiteSpace($hostName)) { throw 'Sftp.Host ist leer.' }
    if ([string]::IsNullOrWhiteSpace($userName)) { throw 'Sftp.User ist leer.' }

    $options = New-Object WinSCP.SessionOptions
    $options.Protocol = [WinSCP.Protocol]::Sftp
    $options.HostName = $hostName
    $options.PortNumber = $port
    $options.UserName = $userName

    if (-not [string]::IsNullOrWhiteSpace($passwordFile)) {
        $options.Password = Get-ProtectedSecret $passwordFile
    }

    if (-not [string]::IsNullOrWhiteSpace($privateKey)) {
        if (-not (Test-Path -LiteralPath $privateKey -PathType Leaf)) {
            throw "SFTP Private Key nicht gefunden: $privateKey"
        }
        $options.SshPrivateKeyPath = $privateKey
    }

    if (-not [string]::IsNullOrWhiteSpace($fingerprint)) {
        $options.SshHostKeyFingerprint = $fingerprint
    }
    elseif ($allowInsecure) {
        Write-IfLog 'WARNUNG: SFTP Host-Key-Prüfung ist deaktiviert.' WARN $LogPath
        $options.GiveUpSecurityAndAcceptAnySshHostKey = $true
    }
    else {
        throw 'Sftp.SshHostKeyFingerprint fehlt.'
    }

    $session = New-Object WinSCP.Session
    $session.SessionLogPath = [string](Get-SftpConfigValue $SftpConfig 'SessionLogPath' '')
    $session.Open($options)
    return $session
}

function Join-SftpPath {
    param(
        [Parameter(Mandatory)] [string] $Directory,
        [Parameter(Mandatory)] [string] $Name
    )

    $dir = if ([string]::IsNullOrWhiteSpace($Directory)) { '/' } else { $Directory.TrimEnd('/') }
    if ($dir -eq '') { $dir = '/' }
    if ($dir -eq '/') { return "/$Name" }
    return "$dir/$Name"
}

function Receive-WorkistCsvFromSftp {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [hashtable] $SftpConfig,
        [Parameter(Mandatory)] [string] $LocalDirectory,
        [Parameter(Mandatory)] [string] $LogPath
    )

    Ensure-Directory $LocalDirectory
    $remoteDir = [string](Get-SftpConfigValue $SftpConfig 'RemoteDirectory' '/')
    $mask = [string](Get-SftpConfigValue $SftpConfig 'FileMask' '*.csv')
    $results = New-Object System.Collections.Generic.List[object]
    $session = $null

    try {
        $session = New-WorkistSftpSession $SftpConfig $LogPath
        $files = @(
            $session.ListDirectory($remoteDir).Files |
            Where-Object { -not $_.IsDirectory -and $_.Name -like $mask } |
            Sort-Object Name
        )

        $options = New-Object WinSCP.TransferOptions
        $options.TransferMode = [WinSCP.TransferMode]::Binary

        foreach ($remoteFile in $files) {
            $remotePath = Join-SftpPath $remoteDir $remoteFile.Name
            $localPath = Join-Path $LocalDirectory $remoteFile.Name

            if (Test-Path -LiteralPath $localPath -PathType Leaf) {
                Write-IfLog "Lokale Datei existiert bereits: $localPath" WARN $LogPath
                $results.Add([pscustomobject]@{
                    RemotePath = $remotePath
                    LocalPath = $localPath
                    FileName = $remoteFile.Name
                    Downloaded = $false
                })
                continue
            }

            $temp = "$localPath.download-$([guid]::NewGuid().ToString('N'))"
            $transfer = $session.GetFiles($remotePath,$temp,$false,$options)
            $transfer.Check()
            Move-Item -LiteralPath $temp -Destination $localPath -Force

            $results.Add([pscustomobject]@{
                RemotePath = $remotePath
                LocalPath = $localPath
                FileName = $remoteFile.Name
                Downloaded = $true
            })
        }

        return $results.ToArray()
    }
    finally {
        if ($null -ne $session) { $session.Dispose() }
    }
}

function Remove-WorkistSftpFiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [hashtable] $SftpConfig,
        [Parameter(Mandatory)] [string[]] $RemotePaths,
        [Parameter(Mandatory)] [string] $LogPath
    )

    $session = $null
    try {
        $session = New-WorkistSftpSession $SftpConfig $LogPath

        foreach ($remotePath in $RemotePaths) {
            if ([string]::IsNullOrWhiteSpace($remotePath)) { continue }

            Write-IfLog "Lösche Remote-Datei nach erfolgreichem IF-Import: $remotePath" INFO $LogPath
            $removal = $session.RemoveFiles($remotePath)
            $removal.Check()
        }
    }
    finally {
        if ($null -ne $session) { $session.Dispose() }
    }
}

Export-ModuleMember -Function @(
    'Receive-WorkistCsvFromSftp',
    'Remove-WorkistSftpFiles'
)
