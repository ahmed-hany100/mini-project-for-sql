
-- Central Superstore — Data Warehouse Schema
-- Mini-Project 2: Star Schema Implementation & ETL
-- DBMS: SQL Server (T-SQL)

IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'CentralSuperstoreDW')
    CREATE DATABASE CentralSuperstoreDW;
GO

USE CentralSuperstoreDW;
GO

-- تنظيف الجداول القديمة بترتيب عكسي لتفادي قيود الـ Foreign Keys
IF OBJECT_ID('dbo.fact_sales', 'U') IS NOT NULL DROP TABLE dbo.fact_sales;
IF OBJECT_ID('dbo.dim_customer', 'U') IS NOT NULL DROP TABLE dbo.dim_customer;
IF OBJECT_ID('dbo.dim_product', 'U') IS NOT NULL DROP TABLE dbo.dim_product;
IF OBJECT_ID('dbo.dim_location', 'U') IS NOT NULL DROP TABLE dbo.dim_location;
IF OBJECT_ID('dbo.dim_shipmode', 'U') IS NOT NULL DROP TABLE dbo.dim_shipmode;
IF OBJECT_ID('dbo.dim_date', 'U') IS NOT NULL DROP TABLE dbo.dim_date;
GO

-- ============================================================
-- 1. Dimension Tables
-- ============================================================

-- جدول التاريخ والتقويم
CREATE TABLE dim_date (
    date_key INT PRIMARY KEY,
    full_date DATE NOT NULL,
    year INT NOT NULL,
    quarter INT NOT NULL,
    month_num INT NOT NULL,
    month_name VARCHAR(20) NOT NULL,
    week_of_year INT NOT NULL,
    day_of_month INT NOT NULL,
    day_name VARCHAR(20) NOT NULL
);
GO

-- بيانات العملاء
CREATE TABLE dim_customer (
    customer_key INT IDENTITY(1,1) PRIMARY KEY,
    customer_id VARCHAR(20) NOT NULL UNIQUE,
    customer_name VARCHAR(100) NOT NULL,
    segment VARCHAR(50) NOT NULL
);
GO

-- تفاصيل المنتجات
CREATE TABLE dim_product (
    product_key INT IDENTITY(1,1) PRIMARY KEY,
    product_id VARCHAR(25) NOT NULL UNIQUE,
    product_name VARCHAR(200) NOT NULL,
    category VARCHAR(50) NOT NULL,
    sub_category VARCHAR(50) NOT NULL
);
GO

-- المواقع الجغرافية
CREATE TABLE dim_location (
    location_key INT IDENTITY(1,1) PRIMARY KEY,
    city VARCHAR(100) NOT NULL,
    state VARCHAR(50) NOT NULL,
    postal_code VARCHAR(10) NOT NULL,
    region VARCHAR(50) NOT NULL,
    country VARCHAR(50) NOT NULL
);
GO

-- طرق الشحن
CREATE TABLE dim_shipmode (
    ship_mode_key INT IDENTITY(1,1) PRIMARY KEY,
    ship_mode VARCHAR(50) NOT NULL UNIQUE
);
GO

-- ============================================================
-- 2. Fact Table
-- ============================================================

CREATE TABLE fact_sales (
    sales_row_id INT PRIMARY KEY,
    order_id VARCHAR(25) NOT NULL,
    customer_key INT NOT NULL,
    product_key INT NOT NULL,
    order_date_key INT NOT NULL,
    ship_date_key INT NOT NULL,
    location_key INT NOT NULL,
    ship_mode_key INT NOT NULL,
    sales DECIMAL(12,2) NOT NULL,
    quantity INT NOT NULL,
    discount DECIMAL(4,2) NOT NULL,
    profit DECIMAL(12,2) NOT NULL,

    CONSTRAINT FK_fact_customer
        FOREIGN KEY (customer_key)
        REFERENCES dim_customer(customer_key),

    CONSTRAINT FK_fact_product
        FOREIGN KEY (product_key)
        REFERENCES dim_product(product_key),

    CONSTRAINT FK_fact_orderdate
        FOREIGN KEY (order_date_key)
        REFERENCES dim_date(date_key),

    CONSTRAINT FK_fact_shipdate
        FOREIGN KEY (ship_date_key)
        REFERENCES dim_date(date_key),

    CONSTRAINT FK_fact_location
        FOREIGN KEY (location_key)
        REFERENCES dim_location(location_key),

    CONSTRAINT FK_fact_shipmode
        FOREIGN KEY (ship_mode_key)
        REFERENCES dim_shipmode(ship_mode_key)
);
GO

-- ============================================================
-- 3. Populate dim_date
-- ============================================================

;WITH dates AS (
    SELECT CAST('2013-01-01' AS DATE) AS d

    UNION ALL

    SELECT DATEADD(DAY, 1, d)
    FROM dates
    WHERE d < '2017-01-31'
)
INSERT INTO dim_date (
    date_key,
    full_date,
    year,
    quarter,
    month_num,
    month_name,
    week_of_year,
    day_of_month,
    day_name
)
SELECT
    YEAR(d) * 10000 + MONTH(d) * 100 + DAY(d),
    d,
    YEAR(d),
    DATEPART(QUARTER, d),
    MONTH(d),
    DATENAME(MONTH, d),
    DATEPART(WEEK, d),
    DAY(d),
    DATENAME(WEEKDAY, d)
FROM dates
OPTION (MAXRECURSION 2000);
GO

-- ============================================================
-- 4. Populate Dimensions from staging_raw
-- ============================================================

-- العملاء
-- Changed:
-- GROUP BY Customer_ID لضمان وجود صف واحد فقط لكل Customer_ID
INSERT INTO dim_customer (
    customer_id,
    customer_name,
    segment
)
SELECT
    TRIM([Customer_ID]),
    MAX(TRIM([Customer_Name])),
    MAX(TRIM([Segment]))
FROM staging_raw
GROUP BY TRIM([Customer_ID]);
GO


-- المنتجات
-- Changed:
-- GROUP BY Product_ID لضمان وجود صف واحد فقط لكل Product_ID
INSERT INTO dim_product (
    product_id,
    product_name,
    category,
    sub_category
)
SELECT
    TRIM([Product_ID]),
    MAX(TRIM([Product_Name])),
    MAX(TRIM([Category])),
    MAX(TRIM([Sub_Category]))
FROM staging_raw
GROUP BY TRIM([Product_ID]);
GO


-- المواقع
INSERT INTO dim_location (
    city,
    state,
    postal_code,
    region,
    country
)
SELECT DISTINCT
    TRIM([City]),
    TRIM([State]),
    CAST([Postal_Code] AS VARCHAR(10)),
    TRIM([Region]),
    TRIM([Country])
FROM staging_raw;
GO


-- طرق الشحن
INSERT INTO dim_shipmode (
    ship_mode
)
SELECT DISTINCT
    TRIM([Ship_Mode])
FROM staging_raw;
GO

-- ============================================================
-- 5. Populate fact_sales and connect surrogate keys
-- ============================================================

INSERT INTO fact_sales (
    sales_row_id,
    order_id,
    customer_key,
    product_key,
    order_date_key,
    ship_date_key,
    location_key,
    ship_mode_key,
    sales,
    quantity,
    discount,
    profit
)
SELECT
    s.[Row_ID],
    s.[Order_ID],
    c.customer_key,
    p.product_key,

    YEAR(s.[Order_Date]) * 10000
        + MONTH(s.[Order_Date]) * 100
        + DAY(s.[Order_Date]),

    YEAR(s.[Ship_Date]) * 10000
        + MONTH(s.[Ship_Date]) * 100
        + DAY(s.[Ship_Date]),

    l.location_key,
    m.ship_mode_key,

    CAST(ISNULL(s.[Sales], 0) AS DECIMAL(12,2)),
    s.[Quantity],
    CAST(s.[Discount] AS DECIMAL(4,2)),
    CAST(s.[Profit] AS DECIMAL(12,2))

FROM staging_raw s

JOIN dim_customer c
    ON c.customer_id = TRIM(s.[Customer_ID])

JOIN dim_product p
    ON p.product_id = TRIM(s.[Product_ID])

JOIN dim_location l
    ON l.city = TRIM(s.[City])
    AND l.postal_code = CAST(s.[Postal_Code] AS VARCHAR(10))
    AND l.state = TRIM(s.[State])
    AND l.region = TRIM(s.[Region])
    AND l.country = TRIM(s.[Country])

JOIN dim_shipmode m
    ON m.ship_mode = TRIM(s.[Ship_Mode]);
GO

-- ============================================================
-- 6. Validation and Row Counts
-- ============================================================

SELECT 'fact_sales' AS tbl, COUNT(*) AS n
FROM fact_sales

UNION ALL

SELECT 'dim_customer', COUNT(*)
FROM dim_customer

UNION ALL

SELECT 'dim_product', COUNT(*)
FROM dim_product

UNION ALL

SELECT 'dim_location', COUNT(*)
FROM dim_location

UNION ALL

SELECT 'dim_shipmode', COUNT(*)
FROM dim_shipmode

UNION ALL

SELECT 'dim_date', COUNT(*)
FROM dim_date;
GO


-- ============================================================
-- Check for orphaned fact rows
-- ============================================================
-- OR is correct here:
-- if ANY dimension relationship is missing,
-- the fact row is considered orphaned.

SELECT COUNT(*) AS orphaned_fact_rows
FROM fact_sales f

LEFT JOIN dim_customer c
    ON c.customer_key = f.customer_key

LEFT JOIN dim_product p
    ON p.product_key = f.product_key

LEFT JOIN dim_date d1
    ON d1.date_key = f.order_date_key

LEFT JOIN dim_date d2
    ON d2.date_key = f.ship_date_key

LEFT JOIN dim_location l
    ON l.location_key = f.location_key

LEFT JOIN dim_shipmode m
    ON m.ship_mode_key = f.ship_mode_key

WHERE c.customer_key IS NULL
   OR p.product_key IS NULL
   OR d1.date_key IS NULL
   OR d2.date_key IS NULL
   OR l.location_key IS NULL
   OR m.ship_mode_key IS NULL;
GO

