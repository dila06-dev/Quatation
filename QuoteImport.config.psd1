@{
    # -------------------------------------------------------------------------
    # Lokale Verzeichnisse
    # -------------------------------------------------------------------------
    Paths = @{
        IncomingDirectory     = 'D:\Quotation\QuoteImport\incoming'
        ArchiveDirectory      = 'D:\Quotation\QuoteImport\archive'
        LogPath               = 'D:\Quotation\QuoteImport\logs\quote_import.log'
        RequestDumpDirectory  = 'D:\Quotation\QuoteImport\request-dumps'
    }

    # -------------------------------------------------------------------------
    # IBM-i-API
    # -------------------------------------------------------------------------
    Api = @{
        # Rückwärtskompatibler Basis-Endpunkt. Solange AddUrl leer bleibt,
        # wird für INSERT weiterhin BaseUrl + '/add' verwendet.
        BaseUrl          = 'http://localhost:8085/api/ibmi/s105dd7a'

        # Bestätigter AGKO-GET-Service mit Query-Parametern.
        # Beispiel:
        # AGKO_select?GKAGJJ=2026&GKAGNR=100004
        HeaderSelectUrl  = 'http://az16emsapp01.dometic.internal:8085/api/services/AGKO_select'

        # Der bekannte AGKO_select-Service unterstützt ausschließlich:
        # GKAGJJ und GKAGNR.
        #
        # Für eine echte GKFREX-/quote_unique_id-Prüfung wäre ein separater
        # bestätigter GET-Service erforderlich. Leer bedeutet: keine externe
        # ID-Prüfung; stattdessen wird die reservierte Jahr-/Nummer-Kombination
        # vor dem INSERT auf Kollision geprüft.
        ExternalReferenceSelectUrl = ''

        # Optionaler SQL-POST-Endpunkt nur für spätere Kunden-/Artikelqueries.
        # Leer lassen, solange CustomerQueryTemplate und ArticleQueryTemplate
        # ebenfalls leer sind.
        SqlSelectUrl     = ''

        # Optionaler vollständiger INSERT-Endpunkt.
        # Leer bedeutet: BaseUrl + '/add'.
        # Nicht ohne bestätigte Add-URL auf einen anderen Service umstellen.
        AddUrl           = ''

        HeaderTable      = 'TVPFTEST.AGKO'
        PositionTable    = 'TVPFTEST.AGPO'

        # Dieser Wert wird als "testMode" an die Add-API gesendet.
        #
        # Bestätigtes API-Verhalten:
        # $true  = "Test mode active, nothing inserted."
        # $false = echter INSERT in die im Payload angegebene Tabelle.
        #
        # Die Zieltabellen bleiben ausdrücklich TVPFTEST.AGKO/TVPFTEST.AGPO.
        TestMode         = $false

        TimeoutSeconds   = 90

        # Nach jedem erfolgreichen AGKO-POST wird über AGKO_select geprüft,
        # ob der Kopf tatsächlich gespeichert und sichtbar ist.
        VerifyHeaderAfterInsert               = $true
        WriteVerificationAttempts             = 3
        WriteVerificationDelayMilliseconds    = 500

        # Kein Token im Klartext im Skript speichern.
        # Datei erzeugen:
        # Read-Host 'API Bearer Token' -AsSecureString |
        #   ConvertFrom-SecureString |
        #   Set-Content 'D:\Quotation\QuoteImport\secure\api-token.sec'
        BearerTokenFile  = 'D:\Quotation\QuoteImport\secure\api-token.sec'

        # $false:
        # Token-Datei verwenden, sofern vorhanden. Keine interaktive Abfrage.
        #
        # $true:
        # Bei jedem manuellen Skriptstart wird der Bearer-Token verdeckt
        # abgefragt. Nicht für unbeaufsichtigte Task-Scheduler-Läufe verwenden.
        PromptForBearerToken = $false
    }

    # -------------------------------------------------------------------------
    # Feste fachliche Werte
    # -------------------------------------------------------------------------
    Defaults = @{
        Company                      = '01'
        DocumentType                 = '150'
        Responsible                  = 'TIK'
        Plant                        = '001'
        Department                   = 'VK'
        OutputType                   = 'D'
        Status                       = '00'
        PrintConditions              = 'J'
        CompleteDelivery             = 'N'
        CustomerNumberMinimumLength  = 6

        PriceType                    = 'AKD'
        PriceDimension               = '1'
        ConditionType                = 'RA5'
        ConditionIsPercent           = 'J'

        # =================================================================
        # 1. TECHNISCHE LAUFZEITVORBELEGUNG
        # =================================================================
        # Diese Werte werden bei jedem Angebot automatisch sowohl in AGKO
        # als auch in allen AGPO-Positionen gesetzt.
        #
        # DateMode / TimeMode:
        #   Current = aktuelles Serverdatum / aktuelle Serverzeit
        #   Fixed   = FixedDate / FixedTime verwenden
        #
        # Beispiel bei Current:
        #   GKJDAT / GPJDAT = 20260722
        #   GKJZEI / GPJZEI = 155924
        TechnicalRuntimeFields = @{
            Enabled   = $true
            JobName   = 'APICAL'
            User      = 'DILA'

            DateMode  = 'Current'
            FixedDate = '20260722'

            TimeMode  = 'Current'
            FixedTime = '155924'
        }

        # =================================================================
        # 2. ERWEITERTE STATISCHE AGKO-VORBELEGUNG
        # =================================================================
        # Hier können weitere bestätigte AGKO-Felder ergänzt werden.
        # Bereits im Kernmapping oder in TechnicalRuntimeFields enthaltene
        # Felder dürfen nicht noch einmal eingetragen werden.
        # -----------------------------------------------------------------
        # Diese Werte waren in den vorhandenen, über Trend angelegten
        # Vergleichsangeboten stabil belegt.
        AdditionalHeaderFields = @{
            GKPROG = 'TRAGKO'
            GKBIBL = 'TVPP1'
        }

        # =================================================================
        # 3. ERWEITERTE STATISCHE AGPO-VORBELEGUNG
        # =================================================================
        # Hier können weitere bestätigte AGPO-Felder ergänzt werden.
        # Bereits im Kernmapping oder in TechnicalRuntimeFields enthaltene
        # Felder dürfen nicht noch einmal eingetragen werden.
        # Diese Werte waren in allen auswertbaren Vergleichszeilen gleich.
        AdditionalPositionFields = @{
            GPPROG = 'TRAGPO'
            GPBIBL = 'TVPP'
            GPBOKZ = 'J'
            GPTXKZ = 'N'
            GPEMKZ = 'N'
            GPAFKZ = 'J'
            GPMWCD = '16'
            GPLTKZ = 'N'
            GPGSKZ = 'J'

            # Nicht automatisch gesetzt:
            # GPDSKZ variiert in den Vergleichsdaten zwischen N und J.
            # GPPRGR und GPDIEK sind artikelabhängig.
            # GPTBZ1/GPTBZ2 müssen aus dem Artikelstamm kommen.
        }
    }

    # -------------------------------------------------------------------------
    # Nummernkreis
    # -------------------------------------------------------------------------
    NumberRange = @{
        # KONTROLLIERTER TESTTABELLEN-SCHREIBTEST:
        # Die feste Nummer ist bei Execute=True nur erlaubt, weil
        # AllowFixedInExecute ausdrücklich aktiviert ist und beide Zieltabellen
        # mit TVPFTEST. beginnen. Vor Produktivbetrieb zwingend deaktivieren.
        Mode                  = 'Fixed'
        FixedYear             = 2026

        # Startpunkt der Suche. Die Nummer darf bereits belegt sein.
        FixedStartNumber      = 103016

        # Nur für den kontrollierten TVPFTEST-Schreibmodus.
        AllowFixedInExecute   = $true

        # Prüft ab FixedStartNumber fortlaufend über AGKO_select und verwendet
        # die erste freie Nummer, z. B. 103016 -> 103017 -> 103018.
        AutoFindNextFree      = $true
        MaximumSearchAttempts = 100

        # WICHTIG:
        # Diese SELECT-basierte Suche ist nicht atomar. Bei parallelen Läufen
        # können zwei Prozesse dieselbe freie Nummer erkennen. Für Produktion
        # ist zwingend Mode='Api' mit einem atomaren Nummernkreis erforderlich.

        # PRODUKTION:
        # Mode = 'Api'
        # Url muss einen atomaren Nummernkreis reservieren.
        # KEIN SELECT MAX(...) + 1 verwenden.
        Url               = ''
        Method            = 'POST'
    }

    # -------------------------------------------------------------------------
    # Kunden- und Artikelstamm
    # -------------------------------------------------------------------------
    MasterData = @{
        # Für den ersten DryRun false. Vor Produktion auf true setzen und die
        # beiden SQL-Templates mit den echten Trend-Tabellen ergänzen.
        Strict = $false

        # Erwartete Aliasnamen:
        # CURRENCY_CODE, SHIPPING_CONDITION, DELIVERY_CONDITION,
        # PAYMENT_CONDITION, LANGUAGE_CODE
        # Beispielsyntax steht in README.md. Leer bedeutet: Fallback verwenden.
        CustomerQueryTemplate = ''

        # Erwartete Aliasnamen:
        # DESCRIPTION1, DESCRIPTION2, QUANTITY_UNIT, PRICE_UNIT
        # Beispielsyntax steht in README.md. Leer bedeutet: Fallback verwenden.
        ArticleQueryTemplate = ''

        CustomerFallback = @{
            CurrencyCode       = 'EUR'
            ShippingCondition  = '220'
            DeliveryCondition  = '060'
            PaymentCondition   = '012'
            LanguageCode       = 'D'
        }

        ArticleFallback = @{
            Description1 = ''
            Description2 = ''
            QuantityUnit = 'S'
            PriceUnit    = 'S'
        }
    }

    # -------------------------------------------------------------------------
    # SFTP
    # -------------------------------------------------------------------------
    Sftp = @{
        Enabled                         = $false
        Host                            = 'az16sftp01.blob.core.windows.net'
        Port                            = 22
        User                            = 'SET_ME'
        PasswordFile                    = 'D:\Quotation\QuoteImport\secure\sftp-password.sec'
        PrivateKeyPath                  = ''
        RemoteDirectory                 = '/'
        FileMask                        = '*.csv'
        WinScpNetDllPath                = 'C:\Program Files (x86)\WinSCP\WinSCPnet.dll'
        SessionLogPath                  = 'D:\Quotation\QuoteImport\logs\winscp-session.log'

        # Unbedingt den echten Fingerprint eintragen.
        SshHostKeyFingerprint           = ''
        AllowInsecureHostKey             = $false

        # Remote-Datei nur nach vollständig erfolgreichem Import löschen.
        DeleteRemoteAfterSuccessfulImport = $true
    }
}
