-- Central Superstore Data Warehouse
-- Mini-Project 2: Business Queries (Joins & Subqueries)
-- Role: Query Developer (Member 2)

USE CentralSuperstoreDW;
GO

-- ============================================================
-- Part 1: JOIN Queries
-- ============================================================


-- ============================================================
-- 1. أداء المنتجات حسب الفئات والفئات الفرعية
--    Sales, Profit, Orders, Units Sold, Profit Margin
-- ============================================================

SELECT
    p.category,
    p.sub_category,

    COUNT(DISTINCT f.order_id) AS total_orders,

    SUM(f.quantity) AS total_units_sold,

    ROUND(SUM(f.sales), 2) AS total_sales,

    ROUND(SUM(f.profit), 2) AS total_profit,

    ROUND(
        (SUM(f.profit) / NULLIF(SUM(f.sales), 0)) * 100,
        2
    ) AS profit_margin_pct

FROM fact_sales f

JOIN dim_product p
    ON f.product_key = p.product_key

GROUP BY
    p.category,
    p.sub_category

ORDER BY
    total_sales DESC;
GO


-- ============================================================
-- 2. تحليل مبيعات شرائح العملاء مع الولايات وطريقة الشحن
-- ============================================================
-- Changed:
-- COUNT(DISTINCT f.order_id)
-- بدل COUNT(f.sales_row_id)
-- لأن الـ Fact Table يحتوي على أكثر من row لنفس Order.

SELECT
    c.segment,
    l.state,
    sm.ship_mode,

    COUNT(DISTINCT f.order_id) AS orders_count,

    ROUND(SUM(f.sales), 2) AS total_sales,

    ROUND(AVG(f.discount), 2) AS avg_discount

FROM fact_sales f

JOIN dim_customer c
    ON f.customer_key = c.customer_key

JOIN dim_location l
    ON f.location_key = l.location_key

JOIN dim_shipmode sm
    ON f.ship_mode_key = sm.ship_mode_key

GROUP BY
    c.segment,
    l.state,
    sm.ship_mode

ORDER BY
    c.segment,
    total_sales DESC;
GO


-- ============================================================
-- 3. تتبع المبيعات والأرباح عبر الزمن
--    Year / Quarter / Month
-- ============================================================

SELECT
    d.year,
    d.quarter,
    d.month_name,

    COUNT(DISTINCT f.order_id) AS total_orders,

    ROUND(SUM(f.sales), 2) AS total_sales,

    ROUND(SUM(f.profit), 2) AS total_profit

FROM fact_sales f

JOIN dim_date d
    ON f.order_date_key = d.date_key

GROUP BY
    d.year,
    d.quarter,
    d.month_num,
    d.month_name

ORDER BY
    d.year,
    d.month_num;
GO


-- ============================================================
-- 4. إجمالي عدد الأوردرات لكل عميل
-- ============================================================
-- Changed:
-- COUNT(DISTINCT f.order_id)
-- لأننا نريد عدد الـ Orders وليس عدد الـ Fact Rows.

SELECT
    c.customer_id,
    c.customer_name,
    c.segment,

    COUNT(DISTINCT f.order_id) AS total_orders

FROM dim_customer c

LEFT JOIN fact_sales f
    ON c.customer_key = f.customer_key

GROUP BY
    c.customer_id,
    c.customer_name,
    c.segment

ORDER BY
    total_orders DESC;
GO


-- ============================================================
-- Part 2: Subqueries
-- ============================================================


-- ============================================================
-- 5. المنتجات التي حققت مبيعات أعلى من متوسط مبيعات المنتجات
--    Scalar Subquery
-- ============================================================

SELECT
    p.product_id,
    p.product_name,
    p.category,

    ROUND(SUM(f.sales), 2) AS total_sales

FROM fact_sales f

JOIN dim_product p
    ON f.product_key = p.product_key

GROUP BY
    p.product_id,
    p.product_name,
    p.category

HAVING SUM(f.sales) > (

    SELECT AVG(prod_sales)

    FROM (
        SELECT
            SUM(sales) AS prod_sales

        FROM fact_sales

        GROUP BY product_key
    ) AS avg_table
)

ORDER BY
    total_sales DESC;
GO


-- ============================================================
-- 6. العملاء الذين لديهم أوردرات خاسرة
--    بخصم 20% أو أكثر
--    Correlated Subquery + EXISTS
-- ============================================================

SELECT
    c.customer_id,
    c.customer_name,
    c.segment

FROM dim_customer c

WHERE EXISTS (

    SELECT 1

    FROM fact_sales f

    WHERE f.customer_key = c.customer_key
      AND f.profit < 0
      AND f.discount >= 0.20
)

ORDER BY
    c.customer_name;
GO


-- ============================================================
-- 7. ترتيب المدن حسب هامش الربح
--    للمدن التي حققت مبيعات فوق $1000
--    Derived Table
-- ============================================================

SELECT
    city_summary.city,
    city_summary.state,
    city_summary.total_sales,
    city_summary.total_profit,
    city_summary.profit_margin_pct

FROM (

    SELECT
        l.city,
        l.state,

        ROUND(SUM(f.sales), 2) AS total_sales,

        ROUND(SUM(f.profit), 2) AS total_profit,

        ROUND(
            (SUM(f.profit) / NULLIF(SUM(f.sales), 0)) * 100,
            2
        ) AS profit_margin_pct

    FROM fact_sales f

    JOIN dim_location l
        ON f.location_key = l.location_key

    GROUP BY
        l.city,
        l.state

) AS city_summary

WHERE city_summary.total_sales > 1000.00

ORDER BY
    city_summary.profit_margin_pct ASC;
GO