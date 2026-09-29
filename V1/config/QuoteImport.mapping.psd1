@{
    SchemaVersion = '3.0'

    # Externes CSV-Layout. Nur hier werden Lieferantenspalten den stabilen
    # internen Feldnamen zugeordnet. Die Programmlogik verwendet ausschließlich
    # die Namen auf der linken Seite.
    Input = @{
        FileMask = '*.csv'
        Delimiter = ';'
        Encoding = 'UTF8'
        Columns = @{
            quote_unique_id       = 'quote_unique_id'
            quote_number          = 'quote_number'
            customer_number       = 'customer_number'
            article_number        = 'article_number'
            quantity              = 'quantity'
            quote_date            = 'quote_date'
            delivery_company_name1 = 'delivery_company_name1'
            delivery_company_name2 = 'delivery_company_name2'
            delivery_company_name3 = 'delivery_company_name3'
            delivery_address      = 'delivery_address'
            delivery_address_misc = 'delivery_address_misc'
            delivery_zip_code     = 'delivery_zip_code'
            delivery_city         = 'delivery_city'
            delivery_country      = 'delivery_country'
            delivery_email        = 'delivery_email'
            delivery_phone        = 'delivery_phone'
            field_sales_id        = 'field_sales_id'
            reference_2           = 'reference_2'
            valid_from            = 'valid_from'
            valid_to              = 'valid_to'
            discount              = 'discount'
            gross_unit_price      = 'gross_unit_price'
            net_unit_price        = 'net_unit_price'
        }
    }

    # Physische und fachliche Ausgaben. Platzhalter stehen in geschweiften
    # Klammern und werden durch das Skript ersetzt.
    Output = @{
        HeaderTable = 'TVPFTEST.AGKO'
        PositionTable = 'TVPFTEST.AGPO'
        ArchiveFileName = '{BaseName}_{Timestamp}{Extension}'
        ResultFileName = '{BaseName}_{Timestamp}_result.csv'
        HeaderDumpFileName = 'AGKO_{ExternalId}_{TrendYear}_{TrendNumber}.json'
        PositionDumpFileName = 'AGPO_{ExternalId}_{TrendYear}_{TrendNumber}_{Position}.json'
    }

    # ERP-Zielfelder sind die fuehrende Mappingstruktur.
    # Source: Csv/Customer/Article/Header/Number/Position/Runtime/Calc + Eigenschaft.
    # Fehlend/null/Leertext => Default bzw. FallbackSource. 0 bleibt erhalten.
    # Ohne Quelle und mit Default: immer konstante Vorbelegung.
    # Ohne Default: Pflichtwert. Ungueltige vorhandene Werte sind Fehler.
    # Reihenfolge entspricht ERP-DDL; Calc-Felder werden im zweiten Durchlauf aufgeloest.
    Erp = @{
        AGKO = @(
            # Satz-Sperre | CHAR(1) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GKLOCK'; Source = ''; Type = 'String'; Default = ''; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 1; Ccsid = 1141 }
            # Ltz.Änd.Job-Na | CHAR(10) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GKJNAM'; Source = ''; Type = 'String'; Default = 'APICAL'; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 10; Ccsid = 1141 }
            # Ltz.Änd.JobDat | NUMERIC(8,0) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GKJDAT'; Source = 'Runtime.Date'; Type = 'Date'; SqlType = 'NUMERIC'; Nullable = $false; DbDefault = 0; Precision = 8; Scale = 0 }
            # Ltz.Änd.Job-Zt | NUMERIC(6,0) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GKJZEI'; Source = 'Runtime.Time'; Type = 'Time'; SqlType = 'NUMERIC'; Nullable = $false; DbDefault = 0; Precision = 6; Scale = 0 }
            # Ltz.Änd.User | CHAR(10) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GKUSER'; Source = ''; Type = 'String'; Default = 'DILA'; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 10; Ccsid = 1141 }
            # Ltz.Änd.Prog | CHAR(10) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GKPROG'; Source = ''; Type = 'String'; Default = 'TRAGKO'; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 10; Ccsid = 1141 }
            # Ltz.Änd.Bibl | CHAR(10) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GKBIBL'; Source = ''; Type = 'String'; Default = 'TVPP1'; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 10; Ccsid = 1141 }
            # Firmen-Nr | CHAR(2) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GKFIRM'; Source = ''; Type = 'String'; Default = '01'; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 2; Ccsid = 1141 }
            # Vertrags-Art | CHAR(3) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GKAGAR'; Source = ''; Type = 'String'; Default = '150'; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 3; Ccsid = 1141 }
            # Vertrag-Jahr | NUMERIC(4,0) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GKAGJJ'; Source = 'Number.Year'; Type = 'Int'; SqlType = 'NUMERIC'; Nullable = $false; DbDefault = 0; Precision = 4; Scale = 0 }
            # Vertrags-Nr | NUMERIC(6,0) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GKAGNN'; Source = 'Number.Number'; Type = 'Int'; SqlType = 'NUMERIC'; Nullable = $false; DbDefault = 0; Precision = 6; Scale = 0 }
            # Vertrags-Nr | CHAR(6) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GKAGNR'; Source = 'Number.Number'; Type = 'String'; Pad = 6; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 6; Ccsid = 1141 }
            # Kunden-Nr | CHAR(10) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GKKDNR'; Source = 'Csv.customer_number'; Type = 'String'; Default = '001330'; Pad = 6; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 10; Ccsid = 1141 }
            # Sachbearbeiter | CHAR(3) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GKSABE'; Source = 'Csv.field_sales_id'; Type = 'String'; Default = 'TST'; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 3; Ccsid = 1141 }
            # Werks-Nr | CHAR(3) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GKWKNR'; Source = ''; Type = 'String'; Default = '001'; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 3; Ccsid = 1141 }
            # Abteilung | CHAR(3) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GKABTL'; Source = ''; Type = 'String'; Default = 'VK'; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 3; Ccsid = 1141 }
            # Ausgabe-Art | CHAR(1) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GKABAR'; Source = ''; Type = 'String'; Default = 'D'; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 1; Ccsid = 1141 }
            # Währungs-Code | CHAR(3) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GKWACD'; Source = 'Customer.CurrencyCode'; Type = 'String'; Default = 'EUR'; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 3; Ccsid = 1141 }
            # Status | CHAR(2) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GKAGST'; Source = ''; Type = 'String'; Default = '00'; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 2; Ccsid = 1141 }
            # Gültig-ab | NUMERIC(8,0) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GKGADA'; Source = 'Csv.valid_from'; Type = 'Date'; FallbackSource = 'Runtime.Date'; AddDays = 0; SqlType = 'NUMERIC'; Nullable = $false; DbDefault = 0; Precision = 8; Scale = 0 }
            # Gültig-bis | NUMERIC(8,0) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GKGBDA'; Source = 'Csv.valid_to'; Type = 'Date'; FallbackSource = 'Runtime.Date'; AddDays = 9; SqlType = 'NUMERIC'; Nullable = $false; DbDefault = 0; Precision = 8; Scale = 0 }
            # Vertrags-Datum | NUMERIC(8,0) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GKAGDA'; Source = 'Csv.quote_date'; Type = 'Date'; FallbackSource = 'Runtime.Date'; AddDays = 0; SqlType = 'NUMERIC'; Nullable = $false; DbDefault = 0; Precision = 8; Scale = 0 }
            # Referenz-1 | CHAR(30) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GKARF1'; Source = 'Csv.quote_number'; Type = 'String'; Default = ''; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 30; Ccsid = 1141 }
            # Referenz-2 | CHAR(30) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GKARF2'; Source = 'Csv.reference_2'; Type = 'String'; Default = 'reference_2'; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 30; Ccsid = 1141 }
            # Versand-Bed | CHAR(3) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GKVSBD'; Source = 'Customer.ShippingCondition'; Type = 'String'; Default = '220'; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 3; Ccsid = 1141 }
            # Liefer-Bed | CHAR(3) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GKLIBD'; Source = 'Customer.DeliveryCondition'; Type = 'String'; Default = '060'; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 3; Ccsid = 1141 }
            # Zahlungs-Bed | CHAR(3) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GKZABD'; Source = 'Customer.PaymentCondition'; Type = 'String'; Default = '012'; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 3; Ccsid = 1141 }
            # Verp-Bedingung | CHAR(3) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GKVPEI'; Source = ''; Type = 'String'; Default = ''; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 3; Ccsid = 1141 }
            # KD-Af-Art-Grp | CHAR(3) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GKAAGR'; Source = ''; Type = 'String'; Default = ''; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 3; Ccsid = 1141 }
            # Projekt-Nr | CHAR(10) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GKPJNR'; Source = ''; Type = 'String'; Default = ''; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 10; Ccsid = 1141 }
            # Preis-Liste | CHAR(2) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GKPSLI'; Source = ''; Type = 'String'; Default = ''; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 2; Ccsid = 1141 }
            # Vorlauf-Zeit | NUMERIC(3,0) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GKLFTG'; Source = ''; Type = 'Int'; Default = 0; SqlType = 'NUMERIC'; Nullable = $false; DbDefault = 0; Precision = 3; Scale = 0 }
            # Zeit-Basis | CHAR(1) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GKLVZA'; Source = ''; Type = 'String'; Default = ''; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 1; Ccsid = 1141 }
            # Sprach-Code | CHAR(1) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GKSPCD'; Source = 'Customer.LanguageCode'; Type = 'String'; Default = 'D'; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 1; Ccsid = 1141 }
            # Wiedervorlage | NUMERIC(8,0) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GKWVDA'; Source = ''; Type = 'Int'; Default = 0; SqlType = 'NUMERIC'; Nullable = $false; DbDefault = 0; Precision = 8; Scale = 0 }
            # Kond.drucken | CHAR(1) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GKKOND'; Source = ''; Type = 'String'; Default = 'J'; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 1; Ccsid = 1141 }
            # Vertreter-Nr | CHAR(10) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GKVTN1'; Source = ''; Type = 'String'; Default = ''; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 10; Ccsid = 1141 }
            # Vertreter-Nr | CHAR(10) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GKVTN2'; Source = ''; Type = 'String'; Default = ''; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 10; Ccsid = 1141 }
            # Vertreter-Nr | CHAR(10) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GKVTN3'; Source = ''; Type = 'String'; Default = ''; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 10; Ccsid = 1141 }
            # Lotus-Notes | CHAR(1) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GKLNKZ'; Source = ''; Type = 'String'; Default = ''; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 1; Ccsid = 1141 }
            # Lief.Komplett | CHAR(1) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GKTLKZ'; Source = ''; Type = 'String'; Default = 'N'; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 1; Ccsid = 1141 }
            # Versand-Adr-Nr | CHAR(3) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GKVSNR'; Source = ''; Type = 'String'; Default = ''; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 3; Ccsid = 1141 }
            # Freifeld-int | CHAR(15) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GKFRIN'; Source = ''; Type = 'String'; Default = ''; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 15; Ccsid = 1141 }
            # Freifeld-ext | CHAR(20) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GKFREX'; Source = 'Csv.quote_unique_id'; Type = 'String'; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 20; Ccsid = 1141 }
        )
        AGPO = @(
            # Satz-Sperre | CHAR(1) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GPLOCK'; Source = ''; Type = 'String'; Default = ''; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 1; Ccsid = 273 }
            # Ltz.Änd.Job-Na | CHAR(10) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GPJNAM'; Source = 'Header.GKJNAM'; Type = 'String'; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 10; Ccsid = 273 }
            # Ltz.Änd.JobDat | NUMERIC(8,0) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GPJDAT'; Source = 'Header.GKJDAT'; Type = 'Date'; SqlType = 'NUMERIC'; Nullable = $false; DbDefault = 0; Precision = 8; Scale = 0 }
            # Ltz.Änd.Job-Zt | NUMERIC(6,0) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GPJZEI'; Source = 'Header.GKJZEI'; Type = 'Time'; SqlType = 'NUMERIC'; Nullable = $false; DbDefault = 0; Precision = 6; Scale = 0 }
            # Ltz.Änd. User | CHAR(10) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GPUSER'; Source = 'Header.GKUSER'; Type = 'String'; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 10; Ccsid = 273 }
            # Ltz.Änd. Prog | CHAR(10) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GPPROG'; Source = ''; Type = 'String'; Default = 'TRAGPO'; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 10; Ccsid = 273 }
            # Ltz. Änd. Bibl | CHAR(10) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GPBIBL'; Source = ''; Type = 'String'; Default = 'TVPP'; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 10; Ccsid = 273 }
            # Firmen-Nr | CHAR(2) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GPFIRM'; Source = 'Header.GKFIRM'; Type = 'String'; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 2; Ccsid = 273 }
            # Kunden-Nr | CHAR(10) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GPKDNR'; Source = 'Header.GKKDNR'; Type = 'String'; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 10; Ccsid = 273 }
            # Vertrag Jahr | NUMERIC(4,0) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GPAGJJ'; Source = 'Header.GKAGJJ'; Type = 'Int'; SqlType = 'NUMERIC'; Nullable = $false; DbDefault = 0; Precision = 4; Scale = 0 }
            # Vertrags-Nr | CHAR(6) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GPAGNR'; Source = 'Header.GKAGNR'; Type = 'String'; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 6; Ccsid = 273 }
            # Vertrags-Pos | NUMERIC(4,0) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GPAGPO'; Source = 'Position.Number'; Type = 'Int'; SqlType = 'NUMERIC'; Nullable = $false; DbDefault = 0; Precision = 4; Scale = 0 }
            # Vertrags-Art | CHAR(3) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GPAGAR'; Source = 'Header.GKAGAR'; Type = 'String'; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 3; Ccsid = 273 }
            # Werks-Nr | CHAR(3) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GPWKNR'; Source = 'Header.GKWKNR'; Type = 'String'; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 3; Ccsid = 273 }
            # Abteilung | CHAR(3) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GPABTL'; Source = 'Header.GKABTL'; Type = 'String'; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 3; Ccsid = 273 }
            # Disponent | CHAR(3) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GPSABE'; Source = 'Header.GKSABE'; Type = 'String'; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 3; Ccsid = 273 }
            # Ausgabe-Art | CHAR(1) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GPABAR'; Source = 'Header.GKABAR'; Type = 'String'; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 1; Ccsid = 273 }
            # Währungs-Code | CHAR(3) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GPWACD'; Source = 'Header.GKWACD'; Type = 'String'; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 3; Ccsid = 273 }
            # Status | CHAR(2) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GPAGST'; Source = 'Header.GKAGST'; Type = 'String'; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 2; Ccsid = 273 }
            # Gültig ab | NUMERIC(8,0) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GPGADA'; Source = 'Header.GKGADA'; Type = 'Date'; SqlType = 'NUMERIC'; Nullable = $false; DbDefault = 0; Precision = 8; Scale = 0 }
            # Gültig bis | NUMERIC(8,0) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GPGBDA'; Source = 'Header.GKGBDA'; Type = 'Date'; SqlType = 'NUMERIC'; Nullable = $false; DbDefault = 0; Precision = 8; Scale = 0 }
            # Ident-Nr | CHAR(15) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GPTENR'; Source = 'Csv.article_number'; Type = 'String'; Default = '9600000038'; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 15; Ccsid = 273 }
            # Bestell-Menge | NUMERIC(11,2) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GPMENG'; Source = 'Csv.quantity'; Type = 'Decimal'; Default = 3; SqlType = 'NUMERIC'; Nullable = $false; DbDefault = 0; Precision = 11; Scale = 2 }
            # Liefer-Woche | NUMERIC(2,0) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GPLFKW'; Source = ''; Type = 'Int'; Default = 0; SqlType = 'NUMERIC'; Nullable = $false; DbDefault = 0; Precision = 2; Scale = 0 }
            # Vorlauf-Zeit | NUMERIC(3,0) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GPLFTG'; Source = ''; Type = 'Int'; Default = 0; SqlType = 'NUMERIC'; Nullable = $false; DbDefault = 0; Precision = 3; Scale = 0 }
            # Bezeichnung 1 | CHAR(30) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GPTBZ1'; Source = 'Article.Description1'; Type = 'String'; Default = ''; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 30; Ccsid = 273 }
            # Bezeichnung 2 | CHAR(30) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GPTBZ2'; Source = 'Article.Description2'; Type = 'String'; Default = ''; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 30; Ccsid = 273 }
            # Mengen-Einheit | CHAR(1) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GPMEIN'; Source = 'Article.QuantityUnit'; Type = 'String'; Default = 'S'; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 1; Ccsid = 273 }
            # ME Preis | CHAR(1) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GPMEPR'; Source = 'Article.PriceUnit'; Type = 'String'; Default = 'S'; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 1; Ccsid = 273 }
            # Faktor | NUMERIC(9,4) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GPUFK1'; Source = ''; Type = 'Decimal'; Default = 0; SqlType = 'NUMERIC'; Nullable = $false; DbDefault = 0; Precision = 9; Scale = 4 }
            # Faktor | NUMERIC(9,4) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GPUFK2'; Source = ''; Type = 'Decimal'; Default = 0; SqlType = 'NUMERIC'; Nullable = $false; DbDefault = 0; Precision = 9; Scale = 4 }
            # Bonus | CHAR(1) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GPBOKZ'; Source = ''; Type = 'String'; Default = 'J'; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 1; Ccsid = 273 }
            # Text | CHAR(1) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GPTXKZ'; Source = ''; Type = 'String'; Default = 'N'; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 1; Ccsid = 273 }
            # Gebinde-Größe | NUMERIC(7,2) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GPGBGR'; Source = ''; Type = 'Decimal'; Default = 0; SqlType = 'NUMERIC'; Nullable = $false; DbDefault = 0; Precision = 7; Scale = 2 }
            # Jahreszahl | NUMERIC(11,2) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GPJASZ'; Source = ''; Type = 'Decimal'; Default = 0; SqlType = 'NUMERIC'; Nullable = $false; DbDefault = 0; Precision = 11; Scale = 2 }
            # Prod-Freigabe | NUMERIC(11,2) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GPPRFG'; Source = ''; Type = 'Decimal'; Default = 0; SqlType = 'NUMERIC'; Nullable = $false; DbDefault = 0; Precision = 11; Scale = 2 }
            # Warenwert | NUMERIC(11,2) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GPWAWT'; Source = 'Calc.GoodsValue'; Type = 'Decimal'; SqlType = 'NUMERIC'; Nullable = $false; DbDefault = 0; Precision = 11; Scale = 2 }
            # Freifeld | NUMERIC(11,2) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GPTLWN'; Source = ''; Type = 'Decimal'; Default = 0; SqlType = 'NUMERIC'; Nullable = $false; DbDefault = 0; Precision = 11; Scale = 2 }
            # Freifeld | CHAR(1) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GPTLKZ'; Source = ''; Type = 'String'; Default = ''; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 1; Ccsid = 273 }
            # Bestell-Menge | NUMERIC(11,2) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GPBSMG'; Source = ''; Type = 'Decimal'; Default = 0; SqlType = 'NUMERIC'; Nullable = $false; DbDefault = 0; Precision = 11; Scale = 2 }
            # Liefer-Menge | NUMERIC(11,2) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GPGLMG'; Source = ''; Type = 'Decimal'; Default = 0; SqlType = 'NUMERIC'; Nullable = $false; DbDefault = 0; Precision = 11; Scale = 2 }
            # Kurs | NUMERIC(11,6) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GPKURS'; Source = ''; Type = 'Decimal'; Default = 0; SqlType = 'NUMERIC'; Nullable = $false; DbDefault = 0; Precision = 11; Scale = 6 }
            # Kurs-Dimension | CHAR(1) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GPKUPD'; Source = ''; Type = 'String'; Default = ''; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 1; Ccsid = 273 }
            # Berechn. Menge | NUMERIC(11,2) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GPBRMG'; Source = ''; Type = 'Decimal'; Default = 0; SqlType = 'NUMERIC'; Nullable = $false; DbDefault = 0; Precision = 11; Scale = 2 }
            # QS-Menge | NUMERIC(11,2) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GPQSMG'; Source = ''; Type = 'Decimal'; Default = 0; SqlType = 'NUMERIC'; Nullable = $false; DbDefault = 0; Precision = 11; Scale = 2 }
            # Änderungs-Dat | NUMERIC(8,0) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GPAEDA'; Source = ''; Type = 'Int'; Default = 0; SqlType = 'NUMERIC'; Nullable = $false; DbDefault = 0; Precision = 8; Scale = 0 }
            # Preis-Art | CHAR(3) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GPPRAR'; Source = ''; Type = 'String'; Default = 'AKD'; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 3; Ccsid = 273 }
            # Einzel-Preis | NUMERIC(11,3) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GPPREI'; Source = 'Csv.gross_unit_price'; Type = 'Decimal'; Default = 203.01; SqlType = 'NUMERIC'; Nullable = $false; DbDefault = 0; Precision = 11; Scale = 3 }
            # Netto-Summe | NUMERIC(11,2) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GPNESU'; Source = 'Calc.NetTotal'; Type = 'Decimal'; SqlType = 'NUMERIC'; Nullable = $false; DbDefault = 0; Precision = 11; Scale = 2 }
            # Ausführ-Wert | NUMERIC(11,2) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GPAFWT'; Source = ''; Type = 'Decimal'; Default = 0; SqlType = 'NUMERIC'; Nullable = $false; DbDefault = 0; Precision = 11; Scale = 2 }
            # Zuschlags-Wert | NUMERIC(11,2) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GPZSWT'; Source = ''; Type = 'Decimal'; Default = 0; SqlType = 'NUMERIC'; Nullable = $false; DbDefault = 0; Precision = 11; Scale = 2 }
            # Angebots-Preis | NUMERIC(11,2) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GPAGPR'; Source = ''; Type = 'Decimal'; Default = 0; SqlType = 'NUMERIC'; Nullable = $false; DbDefault = 0; Precision = 11; Scale = 2 }
            # Preis-Dim | CHAR(1) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GPPDIM'; Source = ''; Type = 'String'; Default = '1'; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 1; Ccsid = 273 }
            # Konditions-Art | CHAR(3) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GPKON1'; Source = ''; Type = 'String'; Default = 'RA5'; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 3; Ccsid = 273 }
            # Kond-Wert | NUMERIC(9,2) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GPKOW1'; Source = 'Csv.discount'; Type = 'Decimal'; Default = 0; SqlType = 'NUMERIC'; Nullable = $false; DbDefault = 0; Precision = 9; Scale = 2 }
            # Prozent | CHAR(1) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GPPRZ1'; Source = ''; Type = 'String'; Default = 'J'; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 1; Ccsid = 273 }
            # Konditions-Dim | CHAR(1) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GPPDI1'; Source = ''; Type = 'String'; Default = ''; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 1; Ccsid = 273 }
            # Kond-Basis | CHAR(3) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GPBAS1'; Source = ''; Type = 'String'; Default = ''; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 3; Ccsid = 273 }
            # Konditions-Art | CHAR(3) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GPKON2'; Source = ''; Type = 'String'; Default = ''; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 3; Ccsid = 273 }
            # Kond-Wert | NUMERIC(9,2) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GPKOW2'; Source = ''; Type = 'Decimal'; Default = 0; SqlType = 'NUMERIC'; Nullable = $false; DbDefault = 0; Precision = 9; Scale = 2 }
            # Prozent | CHAR(1) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GPPRZ2'; Source = ''; Type = 'String'; Default = ''; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 1; Ccsid = 273 }
            # Konditions-Dim | CHAR(1) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GPPDI2'; Source = ''; Type = 'String'; Default = ''; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 1; Ccsid = 273 }
            # Kond-Basis | CHAR(3) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GPBAS2'; Source = ''; Type = 'String'; Default = ''; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 3; Ccsid = 273 }
            # Konditions-Art | CHAR(3) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GPKON3'; Source = ''; Type = 'String'; Default = ''; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 3; Ccsid = 273 }
            # Kond-Wert | NUMERIC(9,2) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GPKOW3'; Source = ''; Type = 'Decimal'; Default = 0; SqlType = 'NUMERIC'; Nullable = $false; DbDefault = 0; Precision = 9; Scale = 2 }
            # Prozent | CHAR(1) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GPPRZ3'; Source = ''; Type = 'String'; Default = ''; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 1; Ccsid = 273 }
            # Konditions-Dim | CHAR(1) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GPPDI3'; Source = ''; Type = 'String'; Default = ''; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 1; Ccsid = 273 }
            # Kond-Basis | CHAR(3) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GPBAS3'; Source = ''; Type = 'String'; Default = ''; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 3; Ccsid = 273 }
            # Konditions-Art | CHAR(3) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GPKON4'; Source = ''; Type = 'String'; Default = ''; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 3; Ccsid = 273 }
            # Kond-Wert | NUMERIC(9,2) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GPKOW4'; Source = ''; Type = 'Decimal'; Default = 0; SqlType = 'NUMERIC'; Nullable = $false; DbDefault = 0; Precision = 9; Scale = 2 }
            # Prozent | CHAR(1) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GPPRZ4'; Source = ''; Type = 'String'; Default = ''; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 1; Ccsid = 273 }
            # Konditions-Dim | CHAR(1) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GPPDI4'; Source = ''; Type = 'String'; Default = ''; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 1; Ccsid = 273 }
            # Kond-Basis | CHAR(3) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GPBAS4'; Source = ''; Type = 'String'; Default = ''; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 3; Ccsid = 273 }
            # Konditions-Art | CHAR(3) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GPKON5'; Source = ''; Type = 'String'; Default = ''; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 3; Ccsid = 273 }
            # Kond-Wert | NUMERIC(9,2) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GPKOW5'; Source = ''; Type = 'Decimal'; Default = 0; SqlType = 'NUMERIC'; Nullable = $false; DbDefault = 0; Precision = 9; Scale = 2 }
            # Prozent | CHAR(1) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GPPRZ5'; Source = ''; Type = 'String'; Default = ''; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 1; Ccsid = 273 }
            # Konditions-Dim | CHAR(1) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GPPDI5'; Source = ''; Type = 'String'; Default = ''; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 1; Ccsid = 273 }
            # Kond-Basis | CHAR(3) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GPBAS5'; Source = ''; Type = 'String'; Default = ''; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 3; Ccsid = 273 }
            # Zeit-Basis | CHAR(1) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GPLVZA'; Source = ''; Type = 'String'; Default = ''; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 1; Ccsid = 273 }
            # Zwischensumme | CHAR(2) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GPZWSU'; Source = ''; Type = 'String'; Default = ''; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 2; Ccsid = 273 }
            # Edelmetall | CHAR(1) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GPEMKZ'; Source = ''; Type = 'String'; Default = 'N'; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 1; Ccsid = 273 }
            # Kz.Frei 05 | CHAR(1) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GPKZ05'; Source = ''; Type = 'String'; Default = ''; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 1; Ccsid = 273 }
            # Vertrags-Datum | NUMERIC(8,0) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GPAGDA'; Source = 'Header.GKAGDA'; Type = 'Date'; SqlType = 'NUMERIC'; Nullable = $false; DbDefault = 0; Precision = 8; Scale = 0 }
            # Ursprungs-Pr | NUMERIC(11,2) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GPURPR'; Source = 'Calc.OriginalPrice'; Type = 'Decimal'; SqlType = 'NUMERIC'; Nullable = $false; DbDefault = 0; Precision = 11; Scale = 2 }
            # Melde-Faktor | NUMERIC(5,2) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GPMEFK'; Source = ''; Type = 'Decimal'; Default = 0; SqlType = 'NUMERIC'; Nullable = $false; DbDefault = 0; Precision = 5; Scale = 2 }
            # Liefer-Termin | NUMERIC(8,0) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GPLFTE'; Source = ''; Type = 'Int'; Default = 0; SqlType = 'NUMERIC'; Nullable = $false; DbDefault = 0; Precision = 8; Scale = 0 }
            # Liefer-Jahr/KW | NUMERIC(4,0) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GPLFJK'; Source = ''; Type = 'Int'; Default = 0; SqlType = 'NUMERIC'; Nullable = $false; DbDefault = 0; Precision = 4; Scale = 0 }
            # Anliefer-Tag | CHAR(1) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GPLFTA'; Source = ''; Type = 'String'; Default = ''; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 1; Ccsid = 273 }
            # Freifeld | NUMERIC(3,0) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GPNU03'; Source = ''; Type = 'Int'; Default = 0; SqlType = 'NUMERIC'; Nullable = $false; DbDefault = 0; Precision = 3; Scale = 0 }
            # Datum Frei 05 | NUMERIC(8,0) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GPDA05'; Source = ''; Type = 'Int'; Default = 0; SqlType = 'NUMERIC'; Nullable = $false; DbDefault = 0; Precision = 8; Scale = 0 }
            # Natural-Rabatt | NUMERIC(11,2) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GPNRMG'; Source = ''; Type = 'Decimal'; Default = 0; SqlType = 'NUMERIC'; Nullable = $false; DbDefault = 0; Precision = 11; Scale = 2 }
            # KD-Auftrags-Kz | CHAR(1) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GPAFKZ'; Source = ''; Type = 'String'; Default = 'J'; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 1; Ccsid = 273 }
            # Produkt-Gruppe | CHAR(4) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GPPRGR'; Source = ''; Type = 'String'; Default = ''; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 4; Ccsid = 273 }
            # MwSt-Code | CHAR(2) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GPMWCD'; Source = ''; Type = 'String'; Default = '16'; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 2; Ccsid = 273 }
            # Langtext-Kz | CHAR(1) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GPLTKZ'; Source = ''; Type = 'String'; Default = 'N'; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 1; Ccsid = 273 }
            # Ges-Summe-Kz | CHAR(1) | NOT NULL
            # Bestehende fachliche Quelle/Vorbelegung bleibt erhalten; DB-Default ist nur Schema-Metadatum.
            @{ Field = 'GPGSKZ'; Source = ''; Type = 'String'; Default = 'J'; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 1; Ccsid = 273 }
            # Faktor | NUMERIC(4,2) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GPFKTR'; Source = ''; Type = 'Decimal'; Default = 0; SqlType = 'NUMERIC'; Nullable = $false; DbDefault = 0; Precision = 4; Scale = 2 }
            # Abruf-Größe | NUMERIC(11,2) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GPABGR'; Source = ''; Type = 'Decimal'; Default = 0; SqlType = 'NUMERIC'; Nullable = $false; DbDefault = 0; Precision = 11; Scale = 2 }
            # Disponent EK | CHAR(3) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GPDIEK'; Source = ''; Type = 'String'; Default = ''; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 3; Ccsid = 273 }
            # Duales System | CHAR(1) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GPDSKZ'; Source = ''; Type = 'String'; Default = ''; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 1; Ccsid = 273 }
            # DSD-Differenz. | CHAR(2) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GPDSDF'; Source = ''; Type = 'String'; Default = ''; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 2; Ccsid = 273 }
            # Sub-KD-Nr | CHAR(10) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GPKDSU'; Source = ''; Type = 'String'; Default = ''; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 10; Ccsid = 273 }
            # Freifeld int | CHAR(7) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GPFRIN'; Source = ''; Type = 'String'; Default = ''; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 7; Ccsid = 273 }
            # Freifeld ext | CHAR(20) | NOT NULL
            # Neu: explizite Vorbelegung entsprechend DB-Default.
            @{ Field = 'GPFREX'; Source = ''; Type = 'String'; Default = ''; SqlType = 'CHAR'; Nullable = $false; DbDefault = ''; MaxLength = 20; Ccsid = 273 }
        )
    }
}
