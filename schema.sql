/* ============================================================
   Central Superstore — Data Warehouse Schema (Star Schema)
   Mini-Project 2 | عضو 1: Database Architect
   DBMS: SQL Server (T-SQL)

   الغرض من الملف: تحويل الداتا الخام (شيت إكسل واحد) لـ Star
   Schema (جدول حقائق + 5 جداول أبعاد)، وتحميل البيانات فيها.
   اتعمل الملف عشان أي حد في الفريق يفهم كل جزء بيعمل إيه، حتى
   لو مش هو اللي هيشتغل على الـ SQL مباشرة.
   ============================================================ */


-- 0) إنشاء قاعدة بيانات الـ Data Warehouse لو مش موجودة أصلاً
--    (الشرط ده بيمنع خطأ لو حد شغّل السكريبت مرتين بالغلط)
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'CentralSuperstoreDW')
    CREATE DATABASE CentralSuperstoreDW;
GO

-- كل اللي جاي بعد كده هيتنفذ جوه الداتابيز دي بالذات
USE CentralSuperstoreDW;
GO


/* ============================================================
   DIMENSION TABLES
   دي جداول الأبعاد — كل واحدة فيها "وصف" لحاجة (عميل، منتج،
   مكان...) من غير تكرار. أي معلومة وصفية بتتكرر في الإكسل
   (زي اسم العميل) بتتسجل مرة واحدة بس هنا.
   ============================================================ */

-- 1) dim_date: صف واحد لكل يوم في التقويم
--    بنعمل جدول تاريخ كامل (مش بس التواريخ اللي في الداتا) عشان
--    نقدر نحلل الاتجاهات (شهري / ربع سنوي...) براحتنا من غير ما
--    نحسبها بالاستعلام كل مرة
CREATE TABLE dim_date (
    date_key      INT PRIMARY KEY,          -- المفتاح: التاريخ متحول لرقم YYYYMMDD (مثلاً 20130103) عشان يبقى سريع في الـ JOIN
    full_date     DATE NOT NULL,             -- نفس التاريخ لكن بصيغة DATE عادية للعرض والفلترة
    year          INT NOT NULL,              -- السنة لوحدها (مفيد لو حد عايز يجمع بالسنة)
    quarter       INT NOT NULL,              -- الربع السنوي 1..4
    month_num     INT NOT NULL,              -- رقم الشهر 1..12 (للترتيب)
    month_name    VARCHAR(20) NOT NULL,      -- اسم الشهر بالحروف (للعرض في التقارير)
    week_of_year  INT NOT NULL,              -- رقم الأسبوع في السنة
    day_of_month  INT NOT NULL,              -- رقم اليوم في الشهر
    day_name      VARCHAR(20) NOT NULL       -- اسم اليوم (السبت، الأحد...) لتحليل أيام الأسبوع
);
GO

-- 2) dim_customer: صف واحد لكل عميل (من غير تكرار)
CREATE TABLE dim_customer (
    customer_key  INT IDENTITY(1,1) PRIMARY KEY,  -- مفتاح داخلي بنعمله إحنا (surrogate key)، بيتولد تلقائي 1، 2، 3...
    customer_id   VARCHAR(20) NOT NULL UNIQUE,     -- الكود الأصلي بتاع العميل من الإكسل، UNIQUE عشان نضمن العميل يتسجل مرة واحدة بس ونقدر نـJOIN عليه براحة
    customer_name VARCHAR(100) NOT NULL,           -- اسم العميل
    segment       VARCHAR(50) NOT NULL             -- نوع العميل: Consumer / Corporate / Home Office
);
GO

-- 3) dim_product: صف واحد لكل منتج
CREATE TABLE dim_product (
    product_key   INT IDENTITY(1,1) PRIMARY KEY,   -- مفتاح داخلي تلقائي
    product_id    VARCHAR(25) NOT NULL UNIQUE,      -- كود المنتج الأصلي، UNIQUE عشان الـ JOIN يبقى بسيط وآمن
    product_name  VARCHAR(200) NOT NULL,            -- اسم المنتج الكامل
    category      VARCHAR(50) NOT NULL,             -- الفئة الرئيسية (Furniture / Technology / Office Supplies)
    sub_category  VARCHAR(50) NOT NULL              -- الفئة الفرعية (Chairs, Phones...)
);
GO

-- 4) dim_location: صف واحد لكل تركيبة مدينة + رمز بريدي
--    (نفس المدينة ممكن تتكرر لو فيها أكتر من postal code، فده طبيعي)
CREATE TABLE dim_location (
    location_key  INT IDENTITY(1,1) PRIMARY KEY,
    city          VARCHAR(100) NOT NULL,
    state         VARCHAR(50) NOT NULL,
    postal_code   VARCHAR(10) NOT NULL,             -- متسجل كـ نص مش رقم عشان نحافظ على الأصفار اللي في الأول لو موجودة
    region        VARCHAR(50) NOT NULL,
    country       VARCHAR(50) NOT NULL
);
GO

-- 5) dim_shipmode: صف واحد لكل طريقة شحن (4 طرق متوقعة بس)
CREATE TABLE dim_shipmode (
    ship_mode_key INT IDENTITY(1,1) PRIMARY KEY,
    ship_mode     VARCHAR(50) NOT NULL UNIQUE        -- UNIQUE عشان "Standard Class" مثلاً يتسجل مرة واحدة بس
);
GO


/* ============================================================
   FACT TABLE
   ده الجدول اللي فيه الأرقام (مبيعات، ربح...) وكل صف فيه بيمثل
   سطر واحد من سطور الأوردرات. بيربط كل الأبعاد فوق ببعض عن طريق
   الـ Foreign Keys.
   ============================================================ */
CREATE TABLE fact_sales (
    sales_row_id    INT PRIMARY KEY,             -- ده نفس "Row ID" الأصلي من الإكسل، فريد لكل سطر فاستخدمناه كـ Primary Key مباشرة (مش محتاجين surrogate تاني هنا)
    order_id        VARCHAR(25) NOT NULL,        -- رقم الأوردر (ممكن يتكرر لو الأوردر فيه أكتر من منتج) — ده degenerate dimension، يعني عمود وصفي عايش جوه الفاكت من غير ما يحتاج جدول بُعد منفصل ليه
    customer_key    INT NOT NULL,                -- FK على dim_customer
    product_key     INT NOT NULL,                -- FK على dim_product
    order_date_key  INT NOT NULL,                -- FK على dim_date (تاريخ الأوردر)
    ship_date_key   INT NOT NULL,                -- FK على dim_date برضه (تاريخ الشحن) — بنستخدم نفس جدول التاريخ مرتين بمعنيين مختلفين
    location_key    INT NOT NULL,                -- FK على dim_location
    ship_mode_key   INT NOT NULL,                -- FK على dim_shipmode
    sales           DECIMAL(12,2) NOT NULL,      -- قيمة المبيعات بالسطر ده
    quantity        INT NOT NULL,                -- الكمية المباعة
    discount        DECIMAL(4,2) NOT NULL,       -- نسبة الخصم (0.00 - 1.00 عادةً)
    profit          DECIMAL(12,2) NOT NULL,      -- الربح (ممكن يكون سالب لو في خسارة)

    -- تعريف كل الـ Foreign Keys مع أسماء واضحة عشان لو حصل خطأ نعرف مصدره فورًا
    CONSTRAINT FK_fact_customer   FOREIGN KEY (customer_key)   REFERENCES dim_customer(customer_key),
    CONSTRAINT FK_fact_product    FOREIGN KEY (product_key)    REFERENCES dim_product(product_key),
    CONSTRAINT FK_fact_orderdate  FOREIGN KEY (order_date_key) REFERENCES dim_date(date_key),
    CONSTRAINT FK_fact_shipdate   FOREIGN KEY (ship_date_key)  REFERENCES dim_date(date_key),
    CONSTRAINT FK_fact_location   FOREIGN KEY (location_key)   REFERENCES dim_location(location_key),
    CONSTRAINT FK_fact_shipmode   FOREIGN KEY (ship_mode_key)  REFERENCES dim_shipmode(ship_mode_key)
);
GO


/* ============================================================
   تعبئة dim_date من 2013-01-01 لـ 2017-01-31
   (بتغطي كل تواريخ الأوردر والشحن الموجودة في الداتا + هامش أمان)
   ============================================================ */
;WITH dates AS (
    -- نقطة البداية: أول يوم في المدى
    SELECT CAST('2013-01-01' AS DATE) AS d
    UNION ALL
    -- كل مرة بنضيف يوم على اللي قبله لحد ما نوصل للنهاية
    -- (recursive CTE = الاستعلام بيستدعي نفسه لحد ما الشرط يبقى غلط)
    SELECT DATEADD(DAY, 1, d) FROM dates WHERE d < '2017-01-31'
)
INSERT INTO dim_date (date_key, full_date, year, quarter, month_num, month_name, week_of_year, day_of_month, day_name)
SELECT
    YEAR(d) * 10000 + MONTH(d) * 100 + DAY(d),   -- بناء الـ date_key بصيغة YYYYMMDD
    d,
    YEAR(d),
    DATEPART(QUARTER, d),
    MONTH(d),
    DATENAME(MONTH, d),
    DATEPART(WEEK, d),
    DAY(d),
    DATENAME(WEEKDAY, d)
FROM dates
OPTION (MAXRECURSION 2000);  -- لازم نرفع الحد الأقصى لأن الافتراضي 100 يوم بس مش كفاية لسنين كتير
GO

-- ملحوظة: لو الداتا اتغيرت وبقى فيها تواريخ برا المدى ده،
-- بدل الأرقام الثابتة تقدر تجيب المدى تلقائي بالسطر ده:
-- SELECT MIN([Order Date]), MAX([Ship Date]) FROM staging_raw


/* ============================================================
   STAGING TABLE
   جدول مؤقت شكله زي الإكسل بالظبط (نفس أسماء الأعمدة)، بنستورد
   فيه البيانات الخام الأول قبل ما نوزعها على الجداول التانية.
   ============================================================ */
CREATE TABLE staging_raw (
    [Row ID]       INT,
    [Order ID]     NVARCHAR(50),
    [Order Date]   DATETIME,
    [Ship Date]    DATETIME,
    [Ship Mode]    NVARCHAR(100),
    [Customer ID]  NVARCHAR(50),
    [Customer Name] NVARCHAR(200),
    [Segment]      NVARCHAR(100),
    [Country]      NVARCHAR(100),
    [City]         NVARCHAR(200),
    [State]        NVARCHAR(100),
    [Postal Code]  NVARCHAR(50),
    [Region]       NVARCHAR(100),
    [Product ID]   NVARCHAR(50),
    [Category]     NVARCHAR(100),
    [Sub-Category] NVARCHAR(100),
    [Product Name] NVARCHAR(500),
    [Sales]        FLOAT,
    [Quantity]     INT,
    [Discount]     FLOAT,
    [Profit]       FLOAT
);
GO
-- الخطوة اللي جاية بعد إنشاء الجدول ده (برا الملف): استورد
-- ملف Central_Superstore.xlsx جواه عن طريق
-- SSMS > Right-click على الداتابيز > Tasks > Import Flat File
-- أسماء الأعمدة هتتظبط تلقائي لأنها مطابقة لأسماء الإكسل بالظبط


/* ============================================================
   تحميل الأبعاد (Dimensions) من الـ staging
   DISTINCT عشان كل عميل/منتج/مكان يتسجل مرة واحدة بس حتى لو
   ظهر في أكتر من سطر أوردر
   ============================================================ */

-- عملاء فريدين
INSERT INTO dim_customer (customer_id, customer_name, segment)
SELECT DISTINCT [Customer ID], [Customer Name], [Segment] FROM staging_raw;

-- منتجات فريدة
INSERT INTO dim_product (product_id, product_name, category, sub_category)
SELECT DISTINCT [Product ID], [Product Name], [Category], [Sub-Category] FROM staging_raw;

-- أماكن فريدة
INSERT INTO dim_location (city, state, postal_code, region, country)
SELECT DISTINCT [City], [State], CAST([Postal Code] AS VARCHAR(10)), [Region], [Country] FROM staging_raw;

-- طرق شحن فريدة
INSERT INTO dim_shipmode (ship_mode)
SELECT DISTINCT [Ship Mode] FROM staging_raw;
GO


/* ============================================================
   تحميل جدول الحقائق (fact_sales)
   بنربط كل سطر في الـ staging بالمفتاح الصحيح بتاعه في كل جدول
   بُعد، عن طريق الكود الأصلي (natural key) اللي دلوقتي UNIQUE
   في كل جدول بُعد، فالـ JOIN بقى بعمود واحد بس بدل 3
   ============================================================ */
INSERT INTO fact_sales (
    sales_row_id, order_id,
    customer_key, product_key, order_date_key, ship_date_key,
    location_key, ship_mode_key,
    sales, quantity, discount, profit
)
SELECT
    s.[Row ID],
    s.[Order ID],
    c.customer_key,
    p.product_key,
    -- تحويل تاريخ الأوردر والشحن لنفس صيغة الـ date_key (YYYYMMDD) عشان يطابق dim_date
    YEAR(s.[Order Date]) * 10000 + MONTH(s.[Order Date]) * 100 + DAY(s.[Order Date]),
    YEAR(s.[Ship Date])  * 10000 + MONTH(s.[Ship Date])  * 100 + DAY(s.[Ship Date]),
    l.location_key,
    m.ship_mode_key,
    s.[Sales], s.[Quantity], s.[Discount], s.[Profit]
FROM staging_raw s
-- الـ JOIN بقى بسيط: عمود واحد بس بفضل الـ UNIQUE اللي حطيناها فوق
JOIN dim_customer c
  ON c.customer_id   = s.[Customer ID]
JOIN dim_product p
  ON p.product_id    = s.[Product ID]
JOIN dim_location l
  ON l.city          = s.[City]
 AND l.postal_code   = CAST(s.[Postal Code] AS VARCHAR(10))
 AND l.state         = s.[State]
 -- location فضلت محتاجة أكتر من عمود لأن مفيش عمود واحد في الإكسل
 -- بيحدد المكان لوحده (المدينة ممكن تتكرر في ولايات مختلفة)
JOIN dim_shipmode m
  ON m.ship_mode     = s.[Ship Mode];
GO


/* ============================================================
   VERIFICATION — شغّل الاستعلامات دي بعد التحميل للتأكد إن كل
   حاجة سليمة قبل ما نبني فوقها باقي البروجكت
   ============================================================ */

-- 1) عدد الصفوف في كل جدول — لازم fact_sales يطابق عدد صفوف الإكسل بالظبط
SELECT 'fact_sales'    AS tbl, COUNT(*) AS n FROM fact_sales
UNION ALL SELECT 'dim_customer', COUNT(*) FROM dim_customer
UNION ALL SELECT 'dim_product',  COUNT(*) FROM dim_product
UNION ALL SELECT 'dim_location', COUNT(*) FROM dim_location
UNION ALL SELECT 'dim_shipmode', COUNT(*) FROM dim_shipmode
UNION ALL SELECT 'dim_date',     COUNT(*) FROM dim_date;
GO

-- 2) فحص الـ FK integrity: أي صف في fact_sales ملوش مطابقة في
--    جدول بُعد هيظهر هنا. لو الرقم صفر يبقى كل حاجة اتربطت صح 100%
SELECT COUNT(*) AS orphaned_fact_rows
FROM fact_sales f
LEFT JOIN dim_customer c  ON c.customer_key  = f.customer_key
LEFT JOIN dim_product  p  ON p.product_key   = f.product_key
LEFT JOIN dim_date     d1 ON d1.date_key     = f.order_date_key
LEFT JOIN dim_date     d2 ON d2.date_key     = f.ship_date_key
LEFT JOIN dim_location l  ON l.location_key  = f.location_key
LEFT JOIN dim_shipmode m  ON m.ship_mode_key = f.ship_mode_key
WHERE c.customer_key IS NULL OR p.product_key IS NULL
   OR d1.date_key IS NULL OR d2.date_key IS NULL
   OR l.location_key IS NULL OR m.ship_mode_key IS NULL;
-- المفروض النتيجة = 0
GO
