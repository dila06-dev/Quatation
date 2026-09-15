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

    Defaults = @{
        Company = '01'; DocumentType = '150'; Responsible = 'TIK'
        Plant = '001'; Department = 'VK'; OutputType = 'D'; Status = '00'
        PrintConditions = 'J'; CompleteDelivery = 'N'
        CustomerNumberMinimumLength = 6
        PriceType = 'AKD'; PriceDimension = '1'
        ConditionType = 'RA5'; ConditionIsPercent = 'J'
        TechnicalRuntimeFields = @{
            Enabled = $true; JobName = 'APICAL'; User = 'DILA'
            DateMode = 'Current'; FixedDate = '20260722'
            TimeMode = 'Current'; FixedTime = '155924'
        }
        AdditionalHeaderFields = @{ GKPROG = 'TRAGKO'; GKBIBL = 'TVPP1' }
        AdditionalPositionFields = @{
            GPPROG = 'TRAGPO'; GPBIBL = 'TVPP'; GPBOKZ = 'J'; GPTXKZ = 'N'
            GPEMKZ = 'N'; GPAFKZ = 'J'; GPMWCD = '16'; GPLTKZ = 'N'; GPGSKZ = 'J'
        }
    }

    NumberRange = @{
        Mode = 'Fixed'; FixedYear = 2026; FixedStartNumber = 103016
        AllowFixedInExecute = $true; AutoFindNextFree = $true
        MaximumSearchAttempts = 100; Url = ''; Method = 'POST'
    }

    MasterData = @{
        Strict = $false; CustomerQueryTemplate = ''; ArticleQueryTemplate = ''
        CustomerFallback = @{
            CurrencyCode = 'EUR'; ShippingCondition = '220'; DeliveryCondition = '060'
            PaymentCondition = '012'; LanguageCode = 'D'
        }
        ArticleFallback = @{
            Description1 = ''; Description2 = ''; QuantityUnit = 'S'; PriceUnit = 'S'
        }
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
