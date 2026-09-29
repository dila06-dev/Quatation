@{
    # =========================================================================
    # Portable Projektpfade
    # =========================================================================
    Paths = @{
        RuntimeRoot          = 'runtime'
        IncomingDirectory    = 'runtime\incoming'
        ArchiveDirectory     = 'runtime\archive'
        LogPath              = 'runtime\logs\workist_if_import.log'
        RequestDumpDirectory = 'runtime\request-dumps'
    }

    # =========================================================================
    # IBM-i Add-API
    # =========================================================================
    Api = @{
        BaseUrl = 'http://localhost:8085/api/ibmi/s105dd7a'
        AddUrl  = ''

        HeaderTable   = 'TVPFTEST.IFGK'
        PositionTable = 'TVPFTEST.IFGP'

        # true  = API validiert/simuliert, kein INSERT
        # false = echter INSERT
        TestMode = $true

        TimeoutSeconds = 90

        BearerTokenFile = 'runtime\secure\api-token.sec'
        PromptForBearerToken = $false

        # Sicherheitsgurt:
        # false = ausschließlich TVPFTEST.IFGK / TVPFTEST.IFGP
        # true  = TVPF.IFGK / TVPF.IFGP grundsätzlich zulässig.
        # Erst nach fachlicher/technischer Freigabe aktivieren.
        AllowProductionTables = $false
    }

    # =========================================================================
    # IFGK / IFGP
    # =========================================================================
    Interface = @{
        # ZWINGEND setzen:
        # IF-Firmen-Nr. aus der Trend-Interface-Konfiguration / USIF.
        # Kombination IFGKIFFI + IFGKIFNR muss eindeutig sein.
        InterfaceCompany = '01'

        # quote_unique_id wird direkt als IFGKIFNR / IFGPIFNR verwendet.
        CustomerNumberMinimumLength = 6

        # Dokumentierte/fachliche Defaults
        CaptureUser      = 'DILA'
        Company          = '01'
        ContractType     = '150'
        Responsible      = 'TIK'
        Plant            = '001'
        Department       = 'VK'
        OutputType       = 'D'
        CurrencyCode     = 'EUR'

        ShippingAddressNumber = ''
        ShippingCondition     = '220'
        DeliveryCondition     = '060'
        PaymentCondition      = '012'
        PackagingCondition    = ''
        CustomerOrderGroup    = ''
        ProjectNumber         = ''
        PriceList             = ''
        LeadTime              = 0
        TimeBasis             = ''
        LanguageCode          = 'D'
        FollowUpDate          = 0
        PrintConditions       = 'J'

        # IFGP
        IdentifierAccess = '0'
        QuantityUnit     = ''
        PriceType        = 'AKD'
        PriceDimension   = '1'

        HeaderFreeText   = ''
        PositionFreeText = ''

        # ---------------------------------------------------------------------
        # Preis-Sicherheitslogik
        #
        # Die Projektdokumentation beschreibt in IFGP nur EINEN Einzelpreis
        # IFGPPREI. Sie definiert nicht, wie gross/net/discount aus Workist
        # abzubilden sind.
        #
        # Standard: keine stillschweigende Informationsvernichtung.
        # ---------------------------------------------------------------------
        Pricing = @{
            PreferredPrice = 'Net'
            AllowDifferentGrossAndNet = $false
            AllowNonZeroDiscount = $false
        }

        # ---------------------------------------------------------------------
        # Physische Datei-Auditfelder aus SYSCOLUMNS
        #
        # IFGKJNAM/JDAT/JZEI/USER/PROG/BIBL und IFGP...
        # sind in der Programmdokumentation NICHT als fachliche IF-Eingabefelder
        # beschrieben. Deshalb standardmäßig deaktiviert.
        #
        # Wenn später bestätigt, kann hier APICAL/DILA aktiviert werden.
        # ---------------------------------------------------------------------
        PhysicalAuditFields = @{
            Enabled = $false
            Lock    = ''
            JobName = 'APICAL'
            User    = 'DILA'
            Program = 'APICAL'
            Library = ''
        }

        # ---------------------------------------------------------------------
        # Kontrollierte Erweiterung
        #
        # Nur tatsächlich in IFGK/IFGP vorhandene Feldnamen sind zulässig.
        # Bereits im Kernmapping belegte Felder dürfen NICHT überschrieben
        # werden.
        # ---------------------------------------------------------------------
        AdditionalHeaderFields = @{}
        AdditionalPositionFields = @{}
    }

    # =========================================================================
    # Optionale ODBC-Duplikat- und Nachkontrolle
    #
    # Empfohlen für späteren Scheduler-Betrieb.
    # Mit Mode='None' funktionieren INSERTs über die API, aber eine saubere
    # Vor-/Nachkontrolle über IFGKIFFI+IFGKIFNR ist nicht möglich.
    # =========================================================================
    Verification = @{
        Mode = 'None'

        # Beispiel:
        # ConnectionString = 'DSN=MEINE_IBM_I_DSN'
        ConnectionString = 'DSN=SET_ME'
        Username = ''
        PasswordFile = 'runtime\secure\odbc-password.sec'
    }

    # =========================================================================
    # Optionaler SFTP-Eingang
    # =========================================================================
    Sftp = @{
        Enabled = $false
        Host = ''
        Port = 22
        User = ''
        PasswordFile = 'runtime\secure\sftp-password.sec'
        PrivateKeyPath = ''
        RemoteDirectory = '/'
        FileMask = '*.csv'
        WinScpNetDllPath = 'C:\Program Files (x86)\WinSCP\WinSCPnet.dll'
        SessionLogPath = 'runtime\logs\winscp-session.log'
        SshHostKeyFingerprint = ''
        AllowInsecureHostKey = $false

        # Nur nach vollständig persistiertem Import.
        DeleteRemoteAfterSuccessfulImport = $true
    }

    # =========================================================================
    # Trend-Übernahme IFGK/IFGP -> AGKO/AGPO
    #
    # GNIFGK/GNIFGP bzw. Batchprogramme sind dokumentiert, aber deren
    # technische Aufrufparameter wurden nicht geliefert. Deshalb NICHT
    # automatisch aufrufen und nichts erfinden.
    # =========================================================================
    TrendTransfer = @{
        Enabled = $false
    }
}
