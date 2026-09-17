
USE CentralSuperstoreDW;
GO

-- ============================================================
-- Part 1: Measure Performance BEFORE Indexing
-- ============================================================

SET STATISTICS IO, TIME ON;
GO

-- Test query A: sales and profit by category (uses product_key)
SELECT
    p.category,
    SUM(f.sales)  AS total_sales,
    SUM(f.profit) AS total_profit
FROM fact_sales f
JOIN dim_product p
    ON f.product_key = p.product_key
GROUP BY
    p.category;
GO

-- Test query B: monthly sales for one year (uses order_date_key)
SELECT
    d.year,
    d.month_num,
    SUM(f.sales) AS total_sales
FROM fact_sales f
JOIN dim_date d
    ON f.order_date_key = d.date_key
WHERE d.year = 2015
GROUP BY
    d.year,
    d.month_num;
GO

-- Test query C: loss-making rows with a high discount
SELECT
    COUNT(*) AS loss_rows
FROM fact_sales f
WHERE f.profit < 0
  AND f.discount >= 0.20;
GO

SET STATISTICS IO, TIME OFF;
GO


-- ============================================================
-- Part 2: Create the Indexes
-- ============================================================

IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_fact_sales_customer_key')
    DROP INDEX IX_fact_sales_customer_key ON fact_sales;
GO

CREATE NONCLUSTERED INDEX IX_fact_sales_customer_key
    ON fact_sales (customer_key)
    INCLUDE (order_id, sales, profit, quantity);
GO


IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_fact_sales_product_key')
    DROP INDEX IX_fact_sales_product_key ON fact_sales;
GO

CREATE NONCLUSTERED INDEX IX_fact_sales_product_key
    ON fact_sales (product_key)
    INCLUDE (order_id, sales, profit, quantity);
GO


IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_fact_sales_order_date_key')
    DROP INDEX IX_fact_sales_order_date_key ON fact_sales;
GO

CREATE NONCLUSTERED INDEX IX_fact_sales_order_date_key
    ON fact_sales (order_date_key)
    INCLUDE (order_id, sales, profit, quantity);
GO


IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_fact_sales_location_key')
    DROP INDEX IX_fact_sales_location_key ON fact_sales;
GO

CREATE NONCLUSTERED INDEX IX_fact_sales_location_key
    ON fact_sales (location_key)
    INCLUDE (order_id, sales, profit, discount);
GO


IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_fact_sales_ship_mode_key')
    DROP INDEX IX_fact_sales_ship_mode_key ON fact_sales;
GO

CREATE NONCLUSTERED INDEX IX_fact_sales_ship_mode_key
    ON fact_sales (ship_mode_key)
    INCLUDE (order_id, sales, discount);
GO


-- Filtered index for the loss-making orders query.
-- Only the rows that match the WHERE condition are stored in this
-- index, so it stays very small compared to the full table.
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_fact_sales_loss_rows')
    DROP INDEX IX_fact_sales_loss_rows ON fact_sales;
GO

CREATE NONCLUSTERED INDEX IX_fact_sales_loss_rows
    ON fact_sales (customer_key)
    INCLUDE (order_id, sales, profit)
    WHERE profit < 0 AND discount >= 0.20;
GO


-- dim_location is the only dimension without a useful index.
-- dim_customer, dim_product and dim_shipmode already got one
-- automatically from the UNIQUE constraints in the schema, and
-- dim_date has its primary key. This index speeds up the ETL
-- join in Schema_2.sql, which matches on several columns.
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_dim_location_city_state')
    DROP INDEX IX_dim_location_city_state ON dim_location;
GO

CREATE NONCLUSTERED INDEX IX_dim_location_city_state
    ON dim_location (city, state, postal_code)
    INCLUDE (region, country);
GO


-- Refresh the statistics so the query optimizer knows about the
-- new indexes and picks the best plan for them.
UPDATE STATISTICS fact_sales;
UPDATE STATISTICS dim_location;
GO


-- ============================================================
-- Part 3: Measure Performance AFTER Indexing
-- ============================================================

SET STATISTICS IO, TIME ON;
GO

-- Test query A (after)
SELECT
    p.category,
    SUM(f.sales)  AS total_sales,
    SUM(f.profit) AS total_profit
FROM fact_sales f
JOIN dim_product p
    ON f.product_key = p.product_key
GROUP BY
    p.category;
GO

-- Test query B (after)
SELECT
    d.year,
    d.month_num,
    SUM(f.sales) AS total_sales
FROM fact_sales f
JOIN dim_date d
    ON f.order_date_key = d.date_key
WHERE d.year = 2015
GROUP BY
    d.year,
    d.month_num;
GO

-- Test query C (after)
SELECT
    COUNT(*) AS loss_rows
FROM fact_sales f
WHERE f.profit < 0
  AND f.discount >= 0.20;
GO

SET STATISTICS IO, TIME OFF;
GO


-- ============================================================
-- Part 4: Check That the Indexes Are Actually Used
-- ============================================================


SELECT
    i.name AS index_name,
    OBJECT_NAME(i.object_id) AS table_name,
    s.user_seeks,
    s.user_scans,
    s.user_lookups,
    s.user_updates
FROM sys.indexes i
LEFT JOIN sys.dm_db_index_usage_stats s
    ON i.object_id = s.object_id
    AND i.index_id = s.index_id
    AND s.database_id = DB_ID()
WHERE i.object_id = OBJECT_ID('dbo.fact_sales')
  AND i.name IS NOT NULL
ORDER BY
    i.name;
GO


-- ============================================================
-- Notes on other optimizations already applied in the project
-- ============================================================
-- 1. Star schema instead of one wide table: the descriptive text
--    columns are stored once in the dimensions, so fact_sales
--    holds only integer keys and numbers and stays small.
--
-- 2. Integer surrogate keys: joining on INT columns is faster
--    than joining on VARCHAR product or customer codes.
--
-- 3. date_key stored as YYYYMMDD INT: date filters compare
--    integers instead of calling date functions on every row.
--
-- 4. NULLIF in the margin calculations: avoids a divide by zero
--    error without needing an extra CASE on every row.
--
-- 5. SET NOCOUNT ON inside usp_GetYearlyKPIReport: stops the
--    server from sending an extra row count message back to the
--    client for every statement.
-- ============================================================
