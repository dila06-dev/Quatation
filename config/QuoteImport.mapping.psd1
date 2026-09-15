@{
    SchemaVersion = '1.0'

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
}
