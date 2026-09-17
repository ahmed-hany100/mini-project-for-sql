-- Central Superstore Data Warehouse
-- Mini-Project 2: SQL View + Stored Procedure
-- Role: Query Developer - CTE / KPI (Member 3)
-- Built directly on the schema created by Member 1 (Schema_2.sql)

USE CentralSuperstoreDW;
GO

-- ============================================================
-- VIEW: vw_monthly_sales_kpi
-- ============================================================
-- Business purpose:
-- A single reusable dataset showing the company's overall monthly
-- KPI performance (Sales, Profit, Quantity, Profit Margin), so
-- anyone on the team (or the professor) can query it without
-- rewriting the join/aggregation logic every time.
--
-- Note: SQL Server views cannot contain an ORDER BY on their own,
-- so this view is intentionally unordered. When querying it, add
-- ORDER BY year, month_num.
-- ============================================================

IF OBJECT_ID('dbo.vw_monthly_sales_kpi', 'V') IS NOT NULL
    DROP VIEW dbo.vw_monthly_sales_kpi;
GO

CREATE VIEW vw_monthly_sales_kpi AS
SELECT
    d.year,
    d.month_num,
    d.month_name,

    SUM(f.sales)    AS total_sales,
    SUM(f.profit)   AS total_profit,
    SUM(f.quantity) AS total_quantity,

    CAST(
        ROUND(
            (SUM(f.profit) / NULLIF(SUM(f.sales), 0)) * 100,
            2
        ) AS DECIMAL(6,2)
    ) AS profit_margin_pct

FROM fact_sales f

JOIN dim_date d
    ON f.order_date_key = d.date_key

GROUP BY
    d.year,
    d.month_num,
    d.month_name;
GO

-- Example usage:
-- SELECT * FROM vw_monthly_sales_kpi ORDER BY year, month_num;


-- ============================================================
-- STORED PROCEDURE: usp_GetYearlyKPIReport
-- ============================================================
-- Business purpose:
-- Returns a monthly KPI report (Sales, Profit, Quantity, Margin)
-- for a chosen Year, broken down by Category. An optional Category
-- parameter lets the user narrow the report to a single category
-- without needing a separate procedure.
--
-- @Year     - required. Filters the report to this year.
-- @Category - optional (defaults to NULL). If NULL, all categories
--             are returned; if provided, only that category.
--
-- If @Year does not exist in the data, the procedure simply
-- returns an empty result set (no error), since the WHERE clause
-- just finds no matching rows.
-- ============================================================

IF OBJECT_ID('dbo.usp_GetYearlyKPIReport', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_GetYearlyKPIReport;
GO

CREATE PROCEDURE usp_GetYearlyKPIReport
    @Year INT,
    @Category VARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        d.year,
        d.month_num,
        d.month_name,
        p.category,

        ROUND(SUM(f.sales), 2)  AS total_sales,
        ROUND(SUM(f.profit), 2) AS total_profit,
        SUM(f.quantity)         AS total_quantity,

        ROUND(
            (SUM(f.profit) / NULLIF(SUM(f.sales), 0)) * 100,
            2
        ) AS profit_margin_pct

    FROM fact_sales f

    JOIN dim_date d
        ON f.order_date_key = d.date_key

    JOIN dim_product p
        ON f.product_key = p.product_key

    WHERE d.year = @Year
        AND (@Category IS NULL OR p.category = @Category)

    GROUP BY
        d.year,
        d.month_num,
        d.month_name,
        p.category

    ORDER BY
        d.month_num;
END
GO

-- Example usage:
-- EXEC usp_GetYearlyKPIReport @Year = 2015;
-- EXEC usp_GetYearlyKPIReport @Year = 2015, @Category = 'Furniture';
