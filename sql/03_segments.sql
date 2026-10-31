-- =====================================================================
-- 03_segments.sql  |  Rule-based segments (mutually exclusive, exhaustive)
-- Rules use R and F scores; M is used to profile value, not to assign.
--   R>=4  F>=4 Champions            | R<=2 F>=4 Cant Lose Them
--   R>=3  F>=3 Loyal                | R<=2 F=3  At Risk
--   R>=3  F=2  Potential Loyalists  | R<=2 F<=2 Hibernating
--   R>=4  F=1  New Customers        | R=3  F=1  About to Sleep
-- (CASE order matters: first match wins.)
-- =====================================================================
DROP TABLE IF EXISTS customer_segments;
CREATE TABLE customer_segments AS
SELECT
    c.*,
    CAST(R_Score AS TEXT) || F_Score || M_Score        AS RFM_Code,
    R_Score + F_Score + M_Score                         AS RFM_Total,
    ROUND(Monetary * 1.0 / Frequency, 2)                AS AOV,
    CASE
        WHEN R_Score >= 4 AND F_Score >= 4 THEN 'Champions'
        WHEN R_Score >= 3 AND F_Score >= 3 THEN 'Loyal'
        WHEN R_Score <= 2 AND F_Score >= 4 THEN 'Cant Lose Them'
        WHEN R_Score <= 2 AND F_Score  = 3 THEN 'At Risk'
        WHEN R_Score >= 4 AND F_Score  = 1 THEN 'New Customers'
        WHEN R_Score >= 3 AND F_Score  = 2 THEN 'Potential Loyalists'
        WHEN R_Score  = 3 AND F_Score  = 1 THEN 'About to Sleep'
        ELSE 'Hibernating'
    END AS Segment
FROM customer_rfm c;

DROP TABLE IF EXISTS segment_summary;
CREATE TABLE segment_summary AS
SELECT
    Segment,
    COUNT(*)                                               AS Customers,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)     AS Customers_Pct,
    ROUND(SUM(Monetary), 2)                                AS Revenue,
    ROUND(100.0 * SUM(Monetary) / SUM(SUM(Monetary)) OVER (), 1) AS Revenue_Pct,
    ROUND(AVG(Recency), 1)                                 AS Avg_Recency,
    ROUND(AVG(Frequency), 1)                               AS Avg_Frequency,
    ROUND(AVG(Monetary), 0)                                AS Avg_Monetary,
    ROUND(SUM(Monetary) / SUM(Frequency), 2)               AS AOV
FROM customer_segments
GROUP BY Segment
ORDER BY Revenue DESC;

-- Revenue-at-risk: historical spend of customers we are about to lose
DROP TABLE IF EXISTS revenue_at_risk;
CREATE TABLE revenue_at_risk AS
SELECT
    Segment,
    COUNT(*)                 AS Customers,
    ROUND(SUM(Monetary), 2)  AS Historical_Revenue,
    ROUND(SUM(Monetary) * 0.10, 2) AS Recover_10pct
FROM customer_segments
WHERE Segment IN ('At Risk', 'Cant Lose Them')
GROUP BY Segment;
