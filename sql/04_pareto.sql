-- =====================================================================
-- 04_pareto.sql  |  Do the top 20% of customers drive ~80% of revenue?
-- =====================================================================
DROP TABLE IF EXISTS pareto;
CREATE TABLE pareto AS
WITH ranked AS (
    SELECT CustomerID, Segment, Monetary,
           ROW_NUMBER() OVER (ORDER BY Monetary DESC) AS rn,
           COUNT(*)     OVER ()                       AS n,
           SUM(Monetary) OVER ()                      AS total
    FROM customer_segments
)
SELECT
    CustomerID, Segment, Monetary, rn,
    ROUND(100.0 * rn / n, 2)                                   AS Cum_Customers_Pct,
    ROUND(100.0 * SUM(Monetary) OVER (ORDER BY rn
          ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) / total, 2) AS Cum_Revenue_Pct
FROM ranked;

-- Headline numbers (top 10% / 20% / 50% of customers)
DROP TABLE IF EXISTS pareto_summary;
CREATE TABLE pareto_summary AS
SELECT 'Top 10% customers' AS Slice, MAX(Cum_Revenue_Pct) AS Revenue_Share_Pct FROM pareto WHERE Cum_Customers_Pct <= 10
UNION ALL
SELECT 'Top 20% customers', MAX(Cum_Revenue_Pct) FROM pareto WHERE Cum_Customers_Pct <= 20
UNION ALL
SELECT 'Top 50% customers', MAX(Cum_Revenue_Pct) FROM pareto WHERE Cum_Customers_Pct <= 50;
