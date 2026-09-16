# Vollständiges ERP-Feldverzeichnis V16

Quelle: vom Benutzer gelieferte DDL vom 16.09.2026. Alle Felder NOT NULL.

## AGKO: 44 Felder

| Feld | ERP-Beschreibung | SQL-Typ | CCSID | DB-Default | Mapping |
|---|---|---|---|---|---|
| `GKLOCK` | Satz-Sperre | CHAR(1) | 1141 | `''` | Konstante; Default '' |
| `GKJNAM` | Ltz.Änd.Job-Na | CHAR(10) | 1141 | `''` | Konstante; Default 'APICAL' |
| `GKJDAT` | Ltz.Änd.JobDat | NUMERIC(8,0) | — | `0` | Runtime.Date |
| `GKJZEI` | Ltz.Änd.Job-Zt | NUMERIC(6,0) | — | `0` | Runtime.Time |
| `GKUSER` | Ltz.Änd.User | CHAR(10) | 1141 | `''` | Konstante; Default 'DILA' |
| `GKPROG` | Ltz.Änd.Prog | CHAR(10) | 1141 | `''` | Konstante; Default 'TRAGKO' |
| `GKBIBL` | Ltz.Änd.Bibl | CHAR(10) | 1141 | `''` | Konstante; Default 'TVPP1' |
| `GKFIRM` | Firmen-Nr | CHAR(2) | 1141 | `''` | Konstante; Default '01' |
| `GKAGAR` | Vertrags-Art | CHAR(3) | 1141 | `''` | Konstante; Default '150' |
| `GKAGJJ` | Vertrag-Jahr | NUMERIC(4,0) | — | `0` | Number.Year |
| `GKAGNN` | Vertrags-Nr | NUMERIC(6,0) | — | `0` | Number.Number |
| `GKAGNR` | Vertrags-Nr | CHAR(6) | 1141 | `''` | Number.Number |
| `GKKDNR` | Kunden-Nr | CHAR(10) | 1141 | `''` | Csv.customer_number; Default '001330' |
| `GKSABE` | Sachbearbeiter | CHAR(3) | 1141 | `''` | Csv.field_sales_id; Default 'TST' |
| `GKWKNR` | Werks-Nr | CHAR(3) | 1141 | `''` | Konstante; Default '001' |
| `GKABTL` | Abteilung | CHAR(3) | 1141 | `''` | Konstante; Default 'VK' |
| `GKABAR` | Ausgabe-Art | CHAR(1) | 1141 | `''` | Konstante; Default 'D' |
| `GKWACD` | Währungs-Code | CHAR(3) | 1141 | `''` | Customer.CurrencyCode; Default 'EUR' |
| `GKAGST` | Status | CHAR(2) | 1141 | `''` | Konstante; Default '00' |
| `GKGADA` | Gültig-ab | NUMERIC(8,0) | — | `0` | Csv.valid_from; Laufdatum-Fallback |
| `GKGBDA` | Gültig-bis | NUMERIC(8,0) | — | `0` | Csv.valid_to; Laufdatum-Fallback |
| `GKAGDA` | Vertrags-Datum | NUMERIC(8,0) | — | `0` | Csv.quote_date; Laufdatum-Fallback |
| `GKARF1` | Referenz-1 | CHAR(30) | 1141 | `''` | Csv.quote_number; Default '' |
| `GKARF2` | Referenz-2 | CHAR(30) | 1141 | `''` | Csv.reference_2; Default 'reference_2' |
| `GKVSBD` | Versand-Bed | CHAR(3) | 1141 | `''` | Customer.ShippingCondition; Default '220' |
| `GKLIBD` | Liefer-Bed | CHAR(3) | 1141 | `''` | Customer.DeliveryCondition; Default '060' |
| `GKZABD` | Zahlungs-Bed | CHAR(3) | 1141 | `''` | Customer.PaymentCondition; Default '012' |
| `GKVPEI` | Verp-Bedingung | CHAR(3) | 1141 | `''` | Konstante; Default '' |
| `GKAAGR` | KD-Af-Art-Grp | CHAR(3) | 1141 | `''` | Konstante; Default '' |
| `GKPJNR` | Projekt-Nr | CHAR(10) | 1141 | `''` | Konstante; Default '' |
| `GKPSLI` | Preis-Liste | CHAR(2) | 1141 | `''` | Konstante; Default '' |
| `GKLFTG` | Vorlauf-Zeit | NUMERIC(3,0) | — | `0` | Konstante; Default 0 |
| `GKLVZA` | Zeit-Basis | CHAR(1) | 1141 | `''` | Konstante; Default '' |
| `GKSPCD` | Sprach-Code | CHAR(1) | 1141 | `''` | Customer.LanguageCode; Default 'D' |
| `GKWVDA` | Wiedervorlage | NUMERIC(8,0) | — | `0` | Konstante; Default 0 |
| `GKKOND` | Kond.drucken | CHAR(1) | 1141 | `''` | Konstante; Default 'J' |
| `GKVTN1` | Vertreter-Nr | CHAR(10) | 1141 | `''` | Konstante; Default '' |
| `GKVTN2` | Vertreter-Nr | CHAR(10) | 1141 | `''` | Konstante; Default '' |
| `GKVTN3` | Vertreter-Nr | CHAR(10) | 1141 | `''` | Konstante; Default '' |
| `GKLNKZ` | Lotus-Notes | CHAR(1) | 1141 | `''` | Konstante; Default '' |
| `GKTLKZ` | Lief.Komplett | CHAR(1) | 1141 | `''` | Konstante; Default 'N' |
| `GKVSNR` | Versand-Adr-Nr | CHAR(3) | 1141 | `''` | Konstante; Default '' |
| `GKFRIN` | Freifeld-int | CHAR(15) | 1141 | `''` | Konstante; Default '' |
| `GKFREX` | Freifeld-ext | CHAR(20) | 1141 | `''` | Csv.quote_unique_id |

## AGPO: 104 Felder

| Feld | ERP-Beschreibung | SQL-Typ | CCSID | DB-Default | Mapping |
|---|---|---|---|---|---|
| `GPLOCK` | Satz-Sperre | CHAR(1) | 273 | `''` | Konstante; Default '' |
| `GPJNAM` | Ltz.Änd.Job-Na | CHAR(10) | 273 | `''` | Header.GKJNAM |
| `GPJDAT` | Ltz.Änd.JobDat | NUMERIC(8,0) | — | `0` | Header.GKJDAT |
| `GPJZEI` | Ltz.Änd.Job-Zt | NUMERIC(6,0) | — | `0` | Header.GKJZEI |
| `GPUSER` | Ltz.Änd. User | CHAR(10) | 273 | `''` | Header.GKUSER |
| `GPPROG` | Ltz.Änd. Prog | CHAR(10) | 273 | `''` | Konstante; Default 'TRAGPO' |
| `GPBIBL` | Ltz. Änd. Bibl | CHAR(10) | 273 | `''` | Konstante; Default 'TVPP' |
| `GPFIRM` | Firmen-Nr | CHAR(2) | 273 | `''` | Header.GKFIRM |
| `GPKDNR` | Kunden-Nr | CHAR(10) | 273 | `''` | Header.GKKDNR |
| `GPAGJJ` | Vertrag Jahr | NUMERIC(4,0) | — | `0` | Header.GKAGJJ |
| `GPAGNR` | Vertrags-Nr | CHAR(6) | 273 | `''` | Header.GKAGNR |
| `GPAGPO` | Vertrags-Pos | NUMERIC(4,0) | — | `0` | Position.Number |
| `GPAGAR` | Vertrags-Art | CHAR(3) | 273 | `''` | Header.GKAGAR |
| `GPWKNR` | Werks-Nr | CHAR(3) | 273 | `''` | Header.GKWKNR |
| `GPABTL` | Abteilung | CHAR(3) | 273 | `''` | Header.GKABTL |
| `GPSABE` | Disponent | CHAR(3) | 273 | `''` | Header.GKSABE |
| `GPABAR` | Ausgabe-Art | CHAR(1) | 273 | `''` | Header.GKABAR |
| `GPWACD` | Währungs-Code | CHAR(3) | 273 | `''` | Header.GKWACD |
| `GPAGST` | Status | CHAR(2) | 273 | `''` | Header.GKAGST |
| `GPGADA` | Gültig ab | NUMERIC(8,0) | — | `0` | Header.GKGADA |
| `GPGBDA` | Gültig bis | NUMERIC(8,0) | — | `0` | Header.GKGBDA |
| `GPTENR` | Ident-Nr | CHAR(15) | 273 | `''` | Csv.article_number; Default '9600000038' |
| `GPMENG` | Bestell-Menge | NUMERIC(11,2) | — | `0` | Csv.quantity; Default 3 |
| `GPLFKW` | Liefer-Woche | NUMERIC(2,0) | — | `0` | Konstante; Default 0 |
| `GPLFTG` | Vorlauf-Zeit | NUMERIC(3,0) | — | `0` | Konstante; Default 0 |
| `GPTBZ1` | Bezeichnung 1 | CHAR(30) | 273 | `''` | Article.Description1; Default '' |
| `GPTBZ2` | Bezeichnung 2 | CHAR(30) | 273 | `''` | Article.Description2; Default '' |
| `GPMEIN` | Mengen-Einheit | CHAR(1) | 273 | `''` | Article.QuantityUnit; Default 'S' |
| `GPMEPR` | ME Preis | CHAR(1) | 273 | `''` | Article.PriceUnit; Default 'S' |
| `GPUFK1` | Faktor | NUMERIC(9,4) | — | `0` | Konstante; Default 0 |
| `GPUFK2` | Faktor | NUMERIC(9,4) | — | `0` | Konstante; Default 0 |
| `GPBOKZ` | Bonus | CHAR(1) | 273 | `''` | Konstante; Default 'J' |
| `GPTXKZ` | Text | CHAR(1) | 273 | `''` | Konstante; Default 'N' |
| `GPGBGR` | Gebinde-Größe | NUMERIC(7,2) | — | `0` | Konstante; Default 0 |
| `GPJASZ` | Jahreszahl | NUMERIC(11,2) | — | `0` | Konstante; Default 0 |
| `GPPRFG` | Prod-Freigabe | NUMERIC(11,2) | — | `0` | Konstante; Default 0 |
| `GPWAWT` | Warenwert | NUMERIC(11,2) | — | `0` | Calc.GoodsValue |
| `GPTLWN` | Freifeld | NUMERIC(11,2) | — | `0` | Konstante; Default 0 |
| `GPTLKZ` | Freifeld | CHAR(1) | 273 | `''` | Konstante; Default '' |
| `GPBSMG` | Bestell-Menge | NUMERIC(11,2) | — | `0` | Konstante; Default 0 |
| `GPGLMG` | Liefer-Menge | NUMERIC(11,2) | — | `0` | Konstante; Default 0 |
| `GPKURS` | Kurs | NUMERIC(11,6) | — | `0` | Konstante; Default 0 |
| `GPKUPD` | Kurs-Dimension | CHAR(1) | 273 | `''` | Konstante; Default '' |
| `GPBRMG` | Berechn. Menge | NUMERIC(11,2) | — | `0` | Konstante; Default 0 |
| `GPQSMG` | QS-Menge | NUMERIC(11,2) | — | `0` | Konstante; Default 0 |
| `GPAEDA` | Änderungs-Dat | NUMERIC(8,0) | — | `0` | Konstante; Default 0 |
| `GPPRAR` | Preis-Art | CHAR(3) | 273 | `''` | Konstante; Default 'AKD' |
| `GPPREI` | Einzel-Preis | NUMERIC(11,3) | — | `0` | Csv.gross_unit_price; Default 203.01 |
| `GPNESU` | Netto-Summe | NUMERIC(11,2) | — | `0` | Calc.NetTotal |
| `GPAFWT` | Ausführ-Wert | NUMERIC(11,2) | — | `0` | Konstante; Default 0 |
| `GPZSWT` | Zuschlags-Wert | NUMERIC(11,2) | — | `0` | Konstante; Default 0 |
| `GPAGPR` | Angebots-Preis | NUMERIC(11,2) | — | `0` | Konstante; Default 0 |
| `GPPDIM` | Preis-Dim | CHAR(1) | 273 | `''` | Konstante; Default '1' |
| `GPKON1` | Konditions-Art | CHAR(3) | 273 | `''` | Konstante; Default 'RA5' |
| `GPKOW1` | Kond-Wert | NUMERIC(9,2) | — | `0` | Csv.discount; Default 0 |
| `GPPRZ1` | Prozent | CHAR(1) | 273 | `''` | Konstante; Default 'J' |
| `GPPDI1` | Konditions-Dim | CHAR(1) | 273 | `''` | Konstante; Default '' |
| `GPBAS1` | Kond-Basis | CHAR(3) | 273 | `''` | Konstante; Default '' |
| `GPKON2` | Konditions-Art | CHAR(3) | 273 | `''` | Konstante; Default '' |
| `GPKOW2` | Kond-Wert | NUMERIC(9,2) | — | `0` | Konstante; Default 0 |
| `GPPRZ2` | Prozent | CHAR(1) | 273 | `''` | Konstante; Default '' |
| `GPPDI2` | Konditions-Dim | CHAR(1) | 273 | `''` | Konstante; Default '' |
| `GPBAS2` | Kond-Basis | CHAR(3) | 273 | `''` | Konstante; Default '' |
| `GPKON3` | Konditions-Art | CHAR(3) | 273 | `''` | Konstante; Default '' |
| `GPKOW3` | Kond-Wert | NUMERIC(9,2) | — | `0` | Konstante; Default 0 |
| `GPPRZ3` | Prozent | CHAR(1) | 273 | `''` | Konstante; Default '' |
| `GPPDI3` | Konditions-Dim | CHAR(1) | 273 | `''` | Konstante; Default '' |
| `GPBAS3` | Kond-Basis | CHAR(3) | 273 | `''` | Konstante; Default '' |
| `GPKON4` | Konditions-Art | CHAR(3) | 273 | `''` | Konstante; Default '' |
| `GPKOW4` | Kond-Wert | NUMERIC(9,2) | — | `0` | Konstante; Default 0 |
| `GPPRZ4` | Prozent | CHAR(1) | 273 | `''` | Konstante; Default '' |
| `GPPDI4` | Konditions-Dim | CHAR(1) | 273 | `''` | Konstante; Default '' |
| `GPBAS4` | Kond-Basis | CHAR(3) | 273 | `''` | Konstante; Default '' |
| `GPKON5` | Konditions-Art | CHAR(3) | 273 | `''` | Konstante; Default '' |
| `GPKOW5` | Kond-Wert | NUMERIC(9,2) | — | `0` | Konstante; Default 0 |
| `GPPRZ5` | Prozent | CHAR(1) | 273 | `''` | Konstante; Default '' |
| `GPPDI5` | Konditions-Dim | CHAR(1) | 273 | `''` | Konstante; Default '' |
| `GPBAS5` | Kond-Basis | CHAR(3) | 273 | `''` | Konstante; Default '' |
| `GPLVZA` | Zeit-Basis | CHAR(1) | 273 | `''` | Konstante; Default '' |
| `GPZWSU` | Zwischensumme | CHAR(2) | 273 | `''` | Konstante; Default '' |
| `GPEMKZ` | Edelmetall | CHAR(1) | 273 | `''` | Konstante; Default 'N' |
| `GPKZ05` | Kz.Frei 05 | CHAR(1) | 273 | `''` | Konstante; Default '' |
| `GPAGDA` | Vertrags-Datum | NUMERIC(8,0) | — | `0` | Header.GKAGDA |
| `GPURPR` | Ursprungs-Pr | NUMERIC(11,2) | — | `0` | Calc.OriginalPrice |
| `GPMEFK` | Melde-Faktor | NUMERIC(5,2) | — | `0` | Konstante; Default 0 |
| `GPLFTE` | Liefer-Termin | NUMERIC(8,0) | — | `0` | Konstante; Default 0 |
| `GPLFJK` | Liefer-Jahr/KW | NUMERIC(4,0) | — | `0` | Konstante; Default 0 |
| `GPLFTA` | Anliefer-Tag | CHAR(1) | 273 | `''` | Konstante; Default '' |
| `GPNU03` | Freifeld | NUMERIC(3,0) | — | `0` | Konstante; Default 0 |
| `GPDA05` | Datum Frei 05 | NUMERIC(8,0) | — | `0` | Konstante; Default 0 |
| `GPNRMG` | Natural-Rabatt | NUMERIC(11,2) | — | `0` | Konstante; Default 0 |
| `GPAFKZ` | KD-Auftrags-Kz | CHAR(1) | 273 | `''` | Konstante; Default 'J' |
| `GPPRGR` | Produkt-Gruppe | CHAR(4) | 273 | `''` | Konstante; Default '' |
| `GPMWCD` | MwSt-Code | CHAR(2) | 273 | `''` | Konstante; Default '16' |
| `GPLTKZ` | Langtext-Kz | CHAR(1) | 273 | `''` | Konstante; Default 'N' |
| `GPGSKZ` | Ges-Summe-Kz | CHAR(1) | 273 | `''` | Konstante; Default 'J' |
| `GPFKTR` | Faktor | NUMERIC(4,2) | — | `0` | Konstante; Default 0 |
| `GPABGR` | Abruf-Größe | NUMERIC(11,2) | — | `0` | Konstante; Default 0 |
| `GPDIEK` | Disponent EK | CHAR(3) | 273 | `''` | Konstante; Default '' |
| `GPDSKZ` | Duales System | CHAR(1) | 273 | `''` | Konstante; Default '' |
| `GPDSDF` | DSD-Differenz. | CHAR(2) | 273 | `''` | Konstante; Default '' |
| `GPKDSU` | Sub-KD-Nr | CHAR(10) | 273 | `''` | Konstante; Default '' |
| `GPFRIN` | Freifeld int | CHAR(7) | 273 | `''` | Konstante; Default '' |
| `GPFREX` | Freifeld ext | CHAR(20) | 273 | `''` | Konstante; Default '' |

