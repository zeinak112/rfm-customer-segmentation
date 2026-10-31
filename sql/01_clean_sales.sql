-- =====================================================================
-- 01_clean_sales.sql  |  Customer Behavior Analysis & RFM Segmentation
-- Input : stg_online_retail  (UCI Online Retail after basic cleaning:
--         no missing CustomerID, no cancelled invoices, Quantity > 0,
--         UnitPrice > 0, duplicates removed. Loaded by run_pipeline.py)
-- Output: clean_sales, data_quality_log
-- Engine: SQLite (window functions need >= 3.25)
-- =====================================================================

-- Two giant orders that were fully reversed by cancellation invoices in
-- the raw file (74,215 and 80,995 units). The cancellation rows are dropped
-- upstream, which would leave the ORIGINAL order behind as 77k / 168k of
-- fake revenue and make both customers look like top spenders.
-- (Verify on raw: the matching 'C'-prefixed invoice has the same quantity.)
DROP TABLE IF EXISTS excluded_invoices;
CREATE TABLE excluded_invoices (InvoiceNo INTEGER PRIMARY KEY, CustomerID INTEGER, reason TEXT);
INSERT INTO excluded_invoices VALUES
  (541431, 12346, '74,215 units, fully cancelled in the raw file'),
  (581483, 16446, '80,995 units, fully cancelled in the raw file');

-- Final analysis table. Non-product StockCodes are removed: real product
-- codes start with 5 digits (e.g. 85123A); POST, M, C2, DOT, BANK CHARGES
-- and PADS are postage / manual adjustments / fees, not merchandise.
DROP TABLE IF EXISTS clean_sales;
CREATE TABLE clean_sales AS
SELECT
    InvoiceNo,
    StockCode,
    TRIM(Description)        AS Description,
    Quantity,
    InvoiceDate,
    DATE(InvoiceDate)        AS InvoiceDay,
    UnitPrice,
    CustomerID,
    Country,
    Quantity * UnitPrice     AS Revenue
FROM stg_online_retail
WHERE StockCode GLOB '[0-9][0-9][0-9][0-9][0-9]*'
  AND InvoiceNo NOT IN (SELECT InvoiceNo FROM excluded_invoices);

CREATE INDEX idx_clean_customer ON clean_sales (CustomerID);

-- Data-quality log: rows and revenue left after each rule
DROP TABLE IF EXISTS data_quality_log;
CREATE TABLE data_quality_log (step INTEGER, rule TEXT, rows_after INTEGER,
                               rows_removed INTEGER, revenue_after REAL);

INSERT INTO data_quality_log
SELECT 1, 'Basic cleaning (supplied file): no null CustomerID, no cancellations, Quantity>0, UnitPrice>0, no duplicates',
       COUNT(*), 0, ROUND(SUM(Quantity*UnitPrice),2)
FROM stg_online_retail;

INSERT INTO data_quality_log
SELECT 2, 'Remove non-product StockCodes (POST, M, C2, DOT, BANK CHARGES, PADS)',
       COUNT(*), (SELECT rows_after FROM data_quality_log WHERE step=1) - COUNT(*),
       ROUND(SUM(Quantity*UnitPrice),2)
FROM stg_online_retail
WHERE StockCode GLOB '[0-9][0-9][0-9][0-9][0-9]*';

INSERT INTO data_quality_log
SELECT 3, 'Remove 2 invoices that were fully cancelled in the raw file (541431, 581483)',
       COUNT(*), (SELECT rows_after FROM data_quality_log WHERE step=2) - COUNT(*),
       ROUND(SUM(Revenue),2)
FROM clean_sales;
