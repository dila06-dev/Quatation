# Feldmapping Workist CSV → Trend IFGK / IFGP

## Grundsatz

Dieses Projekt befüllt ausschließlich `IFGK` und `IFGP`.
`AGKO` und `AGPO` werden nicht direkt beschrieben.

Die Trend-Projektdokumentation definiert `IFGK` als Kopf des
„Interface KD-Angebot, Rahmenvertrag“ und `IFGP` als
„Interface KD-Angebots-, RV-Position“.

## IFGK

| IFGK-Feld | Typ | Quelle / Initialwert |
|---|---|---|
| IFGKTSTP | TIMESTAMP | selbst erzeugter eindeutiger DB2-Timestamp |
| IFGKIFFI | CHAR(5) | `Interface.InterfaceCompany` |
| IFGKIFNR | CHAR(32) | `quote_unique_id` |
| IFGKERUS | CHAR(10) | `CaptureUser`, Standard DILA |
| IFGKERDA | NUMERIC(8,0) | Tagesdatum yyyyMMdd |
| IFGKEZEI | NUMERIC(6,0) | Uhrzeit HHmmss |
| IFGKFIRM | CHAR(2) | Standard 01 |
| IFGKAGJJ | NUMERIC(4,0) | initial 0 |
| IFGKAGNR | CHAR(6) | initial leer |
| IFGKAGAR | CHAR(3) | Standard 150 |
| IFGKFENR | CHAR(4) | initial leer |
| IFGKFFLD | CHAR(10) | initial leer |
| IFGKUEDA | NUMERIC(8,0) | initial 0 |
| IFGKUEUZ | NUMERIC(6,0) | initial 0 |
| IFGKIFST | CHAR(2) | **00** |
| IFGKIFKO | CHAR(2) | **00** |
| IFGKIFPO | CHAR(2) | **00** |
| IFGKFR01 | CHAR(10) | leer |
| IFGKKDNR | CHAR(10) | `customer_number`, Pflicht |
| IFGKVSNR | CHAR(3) | optionale CSV `shipping_address_number` bzw. Config |
| IFGKSABE | CHAR(3) | `field_sales_id`, sonst TIK |
| IFGKWKNR | CHAR(3) | 001 |
| IFGKABTL | CHAR(3) | VK |
| IFGKABAR | CHAR(1) | D |
| IFGKWACD | CHAR(3) | EUR |
| IFGKGADA | NUMERIC(8,0) | `valid_from` |
| IFGKGBDA | NUMERIC(8,0) | `valid_to`, Pflicht und >= IFGKGADA |
| IFGKAGDA | NUMERIC(8,0) | `quote_date` |
| IFGKARF1 | CHAR(30) | `quote_number` |
| IFGKARF2 | CHAR(30) | `reference_2` |
| IFGKVSBD | CHAR(3) | 220 |
| IFGKLIBD | CHAR(3) | 060 |
| IFGKZABD | CHAR(3) | 012 |
| IFGKVPEI | CHAR(3) | Config |
| IFGKAAGR | CHAR(3) | Config |
| IFGKPJNR | CHAR(10) | Config |
| IFGKPSLI | CHAR(2) | Config |
| IFGKLFTG | NUMERIC(3,0) | Config, Standard 0 |
| IFGKLVZA | CHAR(1) | Config |
| IFGKSPCD | CHAR(1) | D |
| IFGKWVDA | NUMERIC(8,0) | Config, Standard 0 |
| IFGKKOND | CHAR(1) | J |
| IFGKFREI | CHAR(512) | Config |

## IFGP

| IFGP-Feld | Typ | Quelle / Initialwert |
|---|---|---|
| IFGPIFGK | TIMESTAMP | exakt IFGKTSTP des Kopfes |
| IFGPIFGP | NUMERIC(4,0) | 1,2,3,... |
| IFGPTSTP | TIMESTAMP | eigener eindeutiger Timestamp |
| IFGPIFFI | CHAR(5) | IFGKIFFI |
| IFGPIFNR | CHAR(32) | IFGKIFNR |
| IFGPERUS | CHAR(10) | CaptureUser |
| IFGPERDA | NUMERIC(8,0) | gleiches Erfassungsdatum wie Kopf |
| IFGPEZEI | NUMERIC(6,0) | gleiche Erfassungszeit wie Kopf |
| IFGPFIRM | CHAR(2) | 01 |
| IFGPAGJJ | NUMERIC(4,0) | initial 0 |
| IFGPAGNR | CHAR(6) | initial leer |
| IFGPAGPO | NUMERIC(4,0) | initial 0 |
| IFGPFENR | CHAR(4) | initial leer |
| IFGPFFLD | CHAR(10) | initial leer |
| IFGPPA03..07 | CHAR(10) | initial leer |
| IFGPUEDA | NUMERIC(8,0) | initial 0 |
| IFGPUEUZ | NUMERIC(6,0) | initial 0 |
| IFGPIFST | CHAR(2) | **10** |
| IFGPIFPO | CHAR(2) | **10** |
| IFGPFR01 | CHAR(10) | leer |
| IFGPTENR | CHAR(15) | `article_number`, Pflicht |
| IFGPTEKZ | CHAR(1) | optional / Standard 0 |
| IFGPTBZ1 | CHAR(30) | optionale CSV `article_description1` |
| IFGPTBZ2 | CHAR(30) | optionale CSV `article_description2` |
| IFGPMENG | NUMERIC(11,2) | `quantity`, Pflicht |
| IFGPMEIN | CHAR(1) | optionale CSV `quantity_unit`; leer erlaubt für Trend-Vorbelegung |
| IFGPPRAR | CHAR(3) | AKD bzw. optionale CSV |
| IFGPPREI | NUMERIC(11,3) | ausgewählter Einzelpreis |
| IFGPPDIM | CHAR(1) | 1 bzw. optionale CSV |
| IFGPFREI | CHAR(512) | Config |

## Nicht automatisch gemappt

Die bestehende Workist-CSV enthält freie Lieferadressbestandteile.
Die Trend-Dokumentation beschreibt im IFGK dafür nur `IFGKVSNR`
(Versand-Adress-Nr.). Deshalb werden Name/Straße/PLZ/Ort/Land/E-Mail/Telefon
nicht stillschweigend in Freifelder geschrieben.

Ebenso enthält IFGP laut Dokumentation kein Rabattfeld. Bei unterschiedlichen
Brutto-/Nettopreisen oder Rabatt != 0 stoppt das Projekt standardmäßig, bis die
fachliche Preisregel bestätigt ist.
