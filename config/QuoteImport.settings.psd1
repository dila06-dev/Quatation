@{
    SchemaVersion = '1.0'

    Dependencies = @{
        MinimumPowerShellVersion = '5.1'
        WinScpNetDllPath = 'C:\Program Files (x86)\WinSCP\WinSCPnet.dll'
        RequiredModules = @('QuoteImport.Common.psm1', 'QuoteImport.Sftp.psm1')
    }

    Paths = @{
        IncomingDirectory = 'D:\Quotation\QuoteImport\incoming'
        ArchiveDirectory = 'D:\Quotation\QuoteImport\archive'
        ResultDirectory = 'D:\Quotation\QuoteImport\results'
        LogPath = 'D:\Quotation\QuoteImport\logs\quote_import.log'
        RequestDumpDirectory = 'D:\Quotation\QuoteImport\request-dumps'
    }

    Api = @{
        BaseUrl = 'http://localhost:8085/api/ibmi/s105dd7a'
        HeaderSelectUrl = 'http://az16emsapp01.dometic.internal:8085/api/services/AGKO_select'
        ExternalReferenceSelectUrl = ''
        SqlSelectUrl = ''
        AddUrl = ''
        TestMode = $false
        TimeoutSeconds = 90
        VerifyHeaderAfterInsert = $true
        WriteVerificationAttempts = 3
        WriteVerificationDelayMilliseconds = 500
        BearerTokenFile = 'D:\Quotation\QuoteImport\secure\api-token.sec'
        PromptForBearerToken = $false
    }

    # Fachliche Vorbelegungen stehen jetzt ausschliesslich in mapping.psd1 / Erp.
    Defaults = @{
        CustomerNumberMinimumLength = 6
        TechnicalRuntimeFields = @{
            Enabled = $true
            DateMode = 'Current'; FixedDate = '20260916'
            TimeMode = 'Current'; FixedTime = '090658'
        }
    }

    NumberRange = @{
        Mode = 'Fixed'; FixedYear = 2026; FixedStartNumber = 103016
        AllowFixedInExecute = $true; AutoFindNextFree = $true
        MaximumSearchAttempts = 100; Url = ''; Method = 'POST'
    }

    MasterData = @{
        Strict = $false; CustomerQueryTemplate = ''; ArticleQueryTemplate = ''
        CustomerFallback = @{} # ERP-Fallbacks stehen im Mapping.
        ArticleFallback = @{}
    }

    Sftp = @{
        Enabled = $false; Host = 'az16sftp01.blob.core.windows.net'; Port = 22
        User = 'SET_ME'; PasswordFile = 'D:\Quotation\QuoteImport\secure\sftp-password.sec'
        PrivateKeyPath = ''; RemoteDirectory = '/'
        SessionLogPath = 'D:\Quotation\QuoteImport\logs\winscp-session.log'
        SshHostKeyFingerprint = ''; AllowInsecureHostKey = $false
        DeleteRemoteAfterSuccessfulImport = $true
    }
}
