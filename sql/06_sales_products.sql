-- =====================================================================
-- 06_sales_products.sql  |  Monthly sales, countries, top products per segment
-- =====================================================================
DROP TABLE IF EXISTS monthly_sales;
CREATE TABLE monthly_sales AS
SELECT
    strftime('%Y-%m', InvoiceDay)           AS Month,
    ROUND(SUM(Revenue), 2)                  AS Revenue,
    COUNT(DISTINCT InvoiceNo)               AS Orders,
    COUNT(DISTINCT CustomerID)              AS Active_Customers,
    ROUND(SUM(Revenue) / COUNT(DISTINCT InvoiceNo), 2) AS AOV,
    ROUND(SUM(Revenue) - LAG(SUM(Revenue)) OVER (ORDER BY strftime('%Y-%m', InvoiceDay)), 2) AS MoM_Change,
    CASE WHEN strftime('%Y-%m', InvoiceDay) = '2011-12' THEN 'Partial (to 9 Dec)' ELSE 'Full' END AS Month_Status
FROM clean_sales
GROUP BY Month
ORDER BY Month;

DROP TABLE IF EXISTS country_sales;
CREATE TABLE country_sales AS
SELECT Country,
       COUNT(DISTINCT CustomerID) AS Customers,
       COUNT(DISTINCT InvoiceNo)  AS Orders,
       ROUND(SUM(Revenue), 2)     AS Revenue,
       ROUND(100.0 * SUM(Revenue) / SUM(SUM(Revenue)) OVER (), 2) AS Revenue_Pct
FROM clean_sales
GROUP BY Country
ORDER BY Revenue DESC;

DROP TABLE IF EXISTS top_products_by_segment;
CREATE TABLE top_products_by_segment AS
WITH prod AS (
    SELECT c.Segment, s.StockCode, MAX(s.Description) AS Description,
           SUM(s.Quantity) AS Units, ROUND(SUM(s.Revenue), 2) AS Revenue
    FROM clean_sales s JOIN customer_segments c USING (CustomerID)
    GROUP BY c.Segment, s.StockCode
),
ranked AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY Segment ORDER BY Revenue DESC) AS rn FROM prod
)
SELECT Segment, rn AS Rank, StockCode, Description, Units, Revenue
FROM ranked WHERE rn <= 10
ORDER BY Segment, rn;

-- Revenue by month and segment (lets Tableau's trend react to a segment filter)
DROP TABLE IF EXISTS monthly_segment_sales;
CREATE TABLE monthly_segment_sales AS
SELECT strftime('%Y-%m', s.InvoiceDay) AS Month,
       c.Segment,
       ROUND(SUM(s.Revenue), 2)        AS Revenue,
       COUNT(DISTINCT s.InvoiceNo)     AS Orders,
       COUNT(DISTINCT s.CustomerID)    AS Active_Customers
FROM clean_sales s JOIN customer_segments c USING (CustomerID)
GROUP BY Month, c.Segment
ORDER BY Month, c.Segment;
