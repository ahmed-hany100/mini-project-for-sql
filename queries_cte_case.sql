-- Central Superstore Data Warehouse
-- Mini-Project 2: CTEs, CASE Statements
-- Role: Query Developer - CTE / KPI (Member 3)
-- Built directly on the schema created by Member 1 (Schema_2.sql)
-- and follows the query style used by Member 2 (queries_joins_subqueries_sql.sql)

USE CentralSuperstoreDW;
GO

-- ============================================================
-- QUERY 1: Monthly Category Performance (CTE #1)
-- ============================================================
-- Business question:
-- Which product categories generate the strongest Sales and Profit
-- in each month, and what is their profit margin?
--
-- Why a CTE helps here:
-- The margin calculation (profit / sales) needs to reuse the same
-- aggregated total_sales and total_profit twice. A CTE lets us
-- calculate the aggregates once (monthly_category_sales) and then
-- reference them cleanly in the outer SELECT, instead of repeating
-- the SUM(...) expressions or nesting subqueries.
-- ============================================================

WITH monthly_category_sales AS (
    SELECT
        d.year,
        d.month_num,
        d.month_name,
        p.category,

        SUM(f.sales)  AS total_sales,
        SUM(f.profit) AS total_profit,
        SUM(f.quantity) AS total_quantity

    FROM fact_sales f

    JOIN dim_date d
        ON f.order_date_key = d.date_key

    JOIN dim_product p
        ON f.product_key = p.product_key

    GROUP BY
        d.year,
        d.month_num,
        d.month_name,
        p.category
)
SELECT
    year,
    month_name,
    category,
    total_sales,
    total_profit,
    total_quantity,

    ROUND(
        (total_profit / NULLIF(total_sales, 0)) * 100,
        2
    ) AS profit_margin_pct

FROM monthly_category_sales

ORDER BY
    year,
    month_num,
    total_sales DESC;
GO


-- ============================================================
-- QUERY 2: Customer Performance Classification (CTE #2 + #3 + CASE)
-- ============================================================
-- Business question:
-- Which customers are High / Medium / Low performers based on their
-- total profit compared to the average customer, and which customers
-- are actually losing the company money?
--
-- Why CTEs help here:
-- - "customer_profit" aggregates each customer's totals once.
-- - "avg_customer_profit" calculates a single company-wide average
--   profit-per-customer value.
-- Splitting these into two CTEs keeps the final SELECT simple: it
-- only needs to compare each customer's profit to the average,
-- instead of repeating an AVG(...) subquery inline.
--
-- Why the CASE is meaningful:
-- It does not just rename a value - it classifies customers into
-- real business tiers using thresholds relative to the actual data
-- (the average profit per customer), instead of made-up fixed numbers.
-- ============================================================

WITH customer_profit AS (
    SELECT
        c.customer_id,
        c.customer_name,
        c.segment,

        COUNT(DISTINCT f.order_id) AS total_orders,
        SUM(f.sales)  AS total_sales,
        SUM(f.profit) AS total_profit

    FROM fact_sales f

    JOIN dim_customer c
        ON f.customer_key = c.customer_key

    GROUP BY
        c.customer_id,
        c.customer_name,
        c.segment
),
avg_customer_profit AS (
    SELECT
        AVG(total_profit) AS avg_profit
    FROM customer_profit
)
SELECT
    cp.customer_id,
    cp.customer_name,
    cp.segment,
    cp.total_orders,
    ROUND(cp.total_sales, 2)  AS total_sales,
    ROUND(cp.total_profit, 2) AS total_profit,

    CASE
        WHEN cp.total_profit < 0                         THEN 'Loss-Making Customer'
        WHEN cp.total_profit >= a.avg_profit             THEN 'High Performer'
        WHEN cp.total_profit >= (a.avg_profit * 0.5)     THEN 'Medium Performer'
        ELSE 'Low Performer'
    END AS performance_tier

FROM customer_profit cp

CROSS JOIN avg_customer_profit a

ORDER BY
    cp.total_profit DESC;
GO
