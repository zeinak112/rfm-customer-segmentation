-- =====================================================================
-- 02_rfm.sql  |  Recency / Frequency / Monetary + 1-5 scores
-- Analysis date = day after the last invoice (2011-12-10)
-- Scoring uses PERCENT_RANK instead of NTILE: NTILE splits customers
-- with identical values (e.g. all one-invoice customers) across
-- different buckets. PERCENT_RANK gives ties the same rank, so equal
-- behaviour always gets an equal score.
--   score = MIN(INT(percent_rank * 5), 4) + 1     (5 = best)
-- =====================================================================
DROP TABLE IF EXISTS analysis_date;
CREATE TABLE analysis_date AS
SELECT DATE(MAX(InvoiceDay), '+1 day') AS ref_date FROM clean_sales;

DROP TABLE IF EXISTS rfm_base;
CREATE TABLE rfm_base AS
SELECT
    CustomerID,
    MAX(Country)                              AS Country,
    MIN(InvoiceDay)                           AS FirstPurchase,
    MAX(InvoiceDay)                           AS LastPurchase,
    CAST(julianday((SELECT ref_date FROM analysis_date))
         - julianday(MAX(InvoiceDay)) AS INTEGER) AS Recency,
    COUNT(DISTINCT InvoiceNo)                 AS Frequency,
    ROUND(SUM(Revenue), 2)                    AS Monetary
FROM clean_sales
GROUP BY CustomerID;

DROP TABLE IF EXISTS customer_rfm;
CREATE TABLE customer_rfm AS
WITH ranked AS (
    SELECT *,
        PERCENT_RANK() OVER (ORDER BY Recency DESC) AS pr_r,   -- recent = high
        PERCENT_RANK() OVER (ORDER BY Frequency)    AS pr_f,
        PERCENT_RANK() OVER (ORDER BY Monetary)     AS pr_m
    FROM rfm_base
)
SELECT
    CustomerID, Country, FirstPurchase, LastPurchase,
    Recency, Frequency, Monetary,
    MIN(CAST(pr_r * 5 AS INTEGER), 4) + 1 AS R_Score,
    MIN(CAST(pr_f * 5 AS INTEGER), 4) + 1 AS F_Score,
    MIN(CAST(pr_m * 5 AS INTEGER), 4) + 1 AS M_Score
FROM ranked;
