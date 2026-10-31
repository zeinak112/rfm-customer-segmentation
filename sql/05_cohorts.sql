-- =====================================================================
-- 05_cohorts.sql  |  Monthly acquisition cohorts and retention
-- Cohort = month of first purchase. Retention = % of the cohort that
-- placed at least one order in month N after acquisition.
-- NOTE: Dec-2011 is a partial month (data ends 9 Dec 2011).
-- =====================================================================
DROP TABLE IF EXISTS cohort_retention;
CREATE TABLE cohort_retention AS
WITH orders AS (
    SELECT DISTINCT CustomerID, strftime('%Y-%m', InvoiceDay) AS order_month
    FROM clean_sales
),
first_month AS (
    SELECT CustomerID, order_month,
           MIN(order_month) OVER (PARTITION BY CustomerID) AS cohort_month
    FROM orders
),
indexed AS (
    SELECT CustomerID, cohort_month, order_month,
           (CAST(substr(order_month,1,4) AS INTEGER) - CAST(substr(cohort_month,1,4) AS INTEGER)) * 12
         + (CAST(substr(order_month,6,2) AS INTEGER) - CAST(substr(cohort_month,6,2) AS INTEGER)) AS month_offset
    FROM first_month
),
sizes AS (
    SELECT cohort_month, COUNT(DISTINCT CustomerID) AS cohort_size
    FROM indexed WHERE month_offset = 0 GROUP BY cohort_month
)
SELECT i.cohort_month, i.month_offset,
       COUNT(DISTINCT i.CustomerID) AS active_customers,
       s.cohort_size,
       ROUND(100.0 * COUNT(DISTINCT i.CustomerID) / s.cohort_size, 1) AS retention_pct
FROM indexed i JOIN sizes s USING (cohort_month)
GROUP BY i.cohort_month, i.month_offset
ORDER BY i.cohort_month, i.month_offset;
