-- ============================================================================
-- IFGK / IFGP manuelle Kontrolle
-- Werte vor Ausführung anpassen.
-- ============================================================================

SELECT
    IFGKTSTP,
    IFGKIFFI,
    IFGKIFNR,
    IFGKERUS,
    IFGKERDA,
    IFGKEZEI,
    IFGKFIRM,
    IFGKAGJJ,
    IFGKAGNR,
    IFGKAGAR,
    IFGKIFST,
    IFGKIFKO,
    IFGKIFPO,
    IFGKFENR,
    IFGKFFLD,
    IFGKKDNR,
    IFGKARF1,
    IFGKGADA,
    IFGKGBDA,
    IFGKUEDA,
    IFGKUEUZ
FROM TVPFTEST.IFGK
WHERE IFGKIFFI = 'SETME'
  AND IFGKIFNR = 'WK-20260929-0001';

SELECT
    IFGPIFGK,
    IFGPIFGP,
    IFGPTSTP,
    IFGPIFFI,
    IFGPIFNR,
    IFGPERUS,
    IFGPERDA,
    IFGPEZEI,
    IFGPIFST,
    IFGPIFPO,
    IFGPFENR,
    IFGPFFLD,
    IFGPTENR,
    IFGPMENG,
    IFGPMEIN,
    IFGPPRAR,
    IFGPPREI,
    IFGPPDIM,
    IFGPAGJJ,
    IFGPAGNR,
    IFGPAGPO
FROM TVPFTEST.IFGP
WHERE IFGPIFFI = 'SETME'
  AND IFGPIFNR = 'WK-20260929-0001'
ORDER BY IFGPIFGP;
