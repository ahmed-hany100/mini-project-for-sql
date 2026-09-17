

USE CentralSuperstoreDW;
GO

-- ============================================================
-- Part 1: Profitability Reports
-- ============================================================


-- ============================================================
-- 8. تأثير الخصم على الربح
--    بنقسم الخصومات لشرايح ونشوف كل شريحة بتربح ولا بتخسر
-- ============================================================

SELECT
    CASE
        WHEN f.discount = 0    THEN 'No Discount'
        WHEN f.discount <= 0.20 THEN '1% - 20%'
        WHEN f.discount <= 0.40 THEN '21% - 40%'
        ELSE 'Over 40%'
    END AS discount_band,

    COUNT(DISTINCT f.order_id) AS orders_count,

    ROUND(SUM(f.sales), 2) AS total_sales,

    ROUND(SUM(f.profit), 2) AS total_profit,

    ROUND(
        (SUM(f.profit) / NULLIF(SUM(f.sales), 0)) * 100,
        2
    ) AS profit_margin_pct

FROM fact_sales f

GROUP BY
    CASE
        WHEN f.discount = 0    THEN 'No Discount'
        WHEN f.discount <= 0.20 THEN '1% - 20%'
        WHEN f.discount <= 0.40 THEN '21% - 40%'
        ELSE 'Over 40%'
    END

ORDER BY
    total_sales DESC;
GO


-- ============================================================
-- 9. أكتر 10 منتجات بتخسر فلوس
--    HAVING عشان نجيب بس اللي إجمالي ربحه سالب
-- ============================================================

SELECT TOP 10
    p.product_name,
    p.category,
    p.sub_category,

    SUM(f.quantity) AS total_units_sold,

    ROUND(SUM(f.sales), 2) AS total_sales,

    ROUND(SUM(f.profit), 2) AS total_loss

FROM fact_sales f

JOIN dim_product p
    ON f.product_key = p.product_key

GROUP BY
    p.product_name,
    p.category,
    p.sub_category

HAVING SUM(f.profit) < 0

ORDER BY
    total_loss ASC;
GO


-- ============================================================
-- 10. ربحية المناطق
--     Member 2 عمل تحليل على مستوى المدن، هنا على مستوى Region
-- ============================================================

SELECT
    l.region,

    COUNT(DISTINCT f.order_id) AS total_orders,

    ROUND(SUM(f.sales), 2) AS total_sales,

    ROUND(SUM(f.profit), 2) AS total_profit,

    ROUND(AVG(f.discount), 2) AS avg_discount,

    ROUND(
        (SUM(f.profit) / NULLIF(SUM(f.sales), 0)) * 100,
        2
    ) AS profit_margin_pct

FROM fact_sales f

JOIN dim_location l
    ON f.location_key = l.location_key

GROUP BY
    l.region

ORDER BY
    profit_margin_pct DESC;
GO


-- ============================================================
-- Part 2: Customer Behavior Reports
-- ============================================================


-- ============================================================
-- 11. العملاء المتكررين مقابل اللي اشتروا مرة واحدة
--     CTE عشان نحسب عدد أوردرات كل عميل الأول
--     وبعدين نلخص على مستوى الـ Segment
-- ============================================================

WITH customer_orders AS (
    SELECT
        c.customer_key,
        c.segment,

        COUNT(DISTINCT f.order_id) AS orders_count

    FROM fact_sales f

    JOIN dim_customer c
        ON f.customer_key = c.customer_key

    GROUP BY
        c.customer_key,
        c.segment
)
SELECT
    segment,

    COUNT(*) AS total_customers,

    SUM(CASE WHEN orders_count = 1 THEN 1 ELSE 0 END) AS one_time_customers,

    SUM(CASE WHEN orders_count > 1 THEN 1 ELSE 0 END) AS repeat_customers,

    ROUND(
        AVG(CAST(orders_count AS DECIMAL(10,2))),
        2
    ) AS avg_orders_per_customer

FROM customer_orders

GROUP BY
    segment

ORDER BY
    repeat_customers DESC;
GO


-- ============================================================
-- 12. متوسط قيمة الأوردر لكل Segment
--     لازم نجمع الأوردر الأول لأن الأوردر الواحد
--     ممكن يكون فيه أكتر من صف في الـ Fact Table
-- ============================================================

WITH order_totals AS (
    SELECT
        f.order_id,
        c.segment,

        SUM(f.sales) AS order_value

    FROM fact_sales f

    JOIN dim_customer c
        ON f.customer_key = c.customer_key

    GROUP BY
        f.order_id,
        c.segment
)
SELECT
    segment,

    COUNT(*) AS orders_count,

    ROUND(AVG(order_value), 2) AS avg_order_value,

    ROUND(MIN(order_value), 2) AS smallest_order,

    ROUND(MAX(order_value), 2) AS biggest_order

FROM order_totals

GROUP BY
    segment

ORDER BY
    avg_order_value DESC;
GO


-- ============================================================
-- 13. أهم 20 عميل: أول وآخر أوردر وفترة نشاطه
--     DATEDIFF بتدينا كام شهر فضل العميل بيشتري خلالهم
-- ============================================================

SELECT TOP 20
    c.customer_id,
    c.customer_name,
    c.segment,

    MIN(d.full_date) AS first_order_date,
    MAX(d.full_date) AS last_order_date,

    DATEDIFF(MONTH, MIN(d.full_date), MAX(d.full_date)) AS active_months,

    COUNT(DISTINCT f.order_id) AS total_orders,

    ROUND(SUM(f.sales), 2) AS total_sales

FROM fact_sales f

JOIN dim_customer c
    ON f.customer_key = c.customer_key

JOIN dim_date d
    ON f.order_date_key = d.date_key

GROUP BY
    c.customer_id,
    c.customer_name,
    c.segment

ORDER BY
    total_sales DESC;
GO


-- ============================================================
-- Part 3: Sales Trend Reports
-- ============================================================


-- ============================================================
-- 14. نمو المبيعات من سنة للي بعدها
--     LAG بتجيب مبيعات السنة السابقة في نفس الصف
--     فنقدر نحسب نسبة النمو بسهولة
-- ============================================================

WITH yearly_sales AS (
    SELECT
        d.year,

        SUM(f.sales)  AS total_sales,
        SUM(f.profit) AS total_profit

    FROM fact_sales f

    JOIN dim_date d
        ON f.order_date_key = d.date_key

    GROUP BY
        d.year
),
yearly_with_previous AS (
    SELECT
        year,
        total_sales,
        total_profit,

        LAG(total_sales) OVER (ORDER BY year) AS previous_year_sales

    FROM yearly_sales
)
SELECT
    year,

    ROUND(total_sales, 2)   AS total_sales,
    ROUND(total_profit, 2)  AS total_profit,

    ROUND(previous_year_sales, 2) AS previous_year_sales,

    ROUND(
        ((total_sales - previous_year_sales) / NULLIF(previous_year_sales, 0)) * 100,
        2
    ) AS growth_pct

FROM yearly_with_previous

ORDER BY
    year;
GO


-- ============================================================
-- 15. اتجاه كل فئة على مدار السنين
--     يوضح الفئة اللي بتكبر والفئة اللي بتقل
-- ============================================================

SELECT
    p.category,
    d.year,

    COUNT(DISTINCT f.order_id) AS total_orders,

    ROUND(SUM(f.sales), 2)  AS total_sales,

    ROUND(SUM(f.profit), 2) AS total_profit

FROM fact_sales f

JOIN dim_product p
    ON f.product_key = p.product_key

JOIN dim_date d
    ON f.order_date_key = d.date_key

GROUP BY
    p.category,
    d.year

ORDER BY
    p.category,
    d.year;
GO
