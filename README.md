# Central Superstore Data Warehouse

## Project Overview

This project implements a **Star Schema Data Warehouse** for the Central Superstore dataset using **Microsoft SQL Server (T-SQL)**.

The project includes:

* Raw data staging
* Dimension tables
* Fact table
* ETL process
* Views
* Stored procedures
* SQL analytical queries
* Performance optimization and indexing

---

# Requirements

* Microsoft SQL Server
* SQL Server Management Studio (SSMS)
* The provided Central Superstore dataset

---

# Project Files

The SQL scripts should be executed in the following order:

1. Create the database
2. Import the raw data into `staging_raw`
3. `Final_schema`
4. `views_procedures.sql`
5. `queries_joins_subqueries_sql.sql`
6. `queries_cte_case.sql`
7. `analytical_reports.sql`
8. `optimization.sql`

---

# How to Run the Project

## 1. Create the Database

Open **SQL Server Management Studio (SSMS)** and execute the following code:

```sql
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'CentralSuperstoreDW')
    CREATE DATABASE CentralSuperstoreDW;
GO

USE CentralSuperstoreDW;
GO
```

This creates an empty database named:

```text
CentralSuperstoreDW
```

At this stage, the database does not contain the Star Schema tables yet.

---

# 2. Import the Raw Data

Import the provided Central Superstore dataset into:

```text
CentralSuperstoreDW
```

The imported raw data should be stored in a table named:

```text
staging_raw
```

The staging table should contain the following columns:

```text
Row_ID
Order_ID
Order_Date
Ship_Date
Ship_Mode
Customer_ID
Customer_Name
Segment
Country
City
State
Postal_Code
Region
Product_ID
Category
Sub_Category
Product_Name
Sales
Quantity
Discount
Profit
```

### Important

The column names must use underscores.

For example:

```text
Customer_ID
Product_ID
Postal_Code
Row_ID
```

and not:

```text
Customer ID
Product ID
Postal Code
Row ID
```

This is required because `Schema_2.sql` references the underscore-based column names.

---

## 3. Verify the Imported Data

Before running the schema script, verify that `staging_raw` exists and contains the expected data:

```sql
USE CentralSuperstoreDW;
GO

SELECT TOP 10 *
FROM staging_raw;

SELECT COUNT(*) AS staging_rows
FROM staging_raw;
```

For the provided dataset, the expected number of rows is:

```text
2323
```

---

# 4. Run `Final_schema`

After successfully importing the raw data into `staging_raw`, execute:

```text
final_schema.sql
```

This script creates and populates the Star Schema.

### Dimension Tables

The script creates:

* `dim_date`
* `dim_customer`
* `dim_product`
* `dim_location`
* `dim_shipmode`

### Fact Table

The script creates:

* `fact_sales`

The script then loads the dimensions and fact table from `staging_raw` and connects the fact records to the dimension tables using surrogate keys.

---

# 5. Validate the Star Schema

At the end of `final_Schema`, validation queries display the row counts of the main tables.

The expected fact table row count is:

```text
fact_sales = 2323
```

The script also checks for orphaned fact rows.

The expected result is:

```text
orphaned_fact_rows = 0
```

This confirms that the fact records are correctly connected to the required dimension records.

---

# 6. Run Views and Stored Procedures

After `Final_schema` completes successfully, execute:

```text
views_procedures.sql
```

This creates the project's required views and stored procedures.

---

# 7. Run SQL Analysis Queries

Execute:

```text
queries_joins_subqueries_sql.sql
```

and:

```text
queries_cte_case.sql
```

These files contain SQL analysis using:

* Joins
* Subqueries
* CTEs
* CASE expressions

The order between these two files is not important.

---

# 8. Run Analytical Reports

Execute:

```text
analytical_reports.sql
```

This file contains the project's analytical and business-oriented reports based on the completed Star Schema.

---

# 9. Run Performance Optimization

Execute:

```text
optimization.sql
```

The performance analysis should be performed in two stages.

### Before Indexing

1. Run the queries in the **Before Indexing** section.
2. Record the `STATISTICS IO` and `STATISTICS TIME` results.

### After Indexing

1. Create the recommended indexes.
2. Run the same queries again.
3. Record the new execution statistics.
4. Compare the results before and after indexing.

The comparison can include:

* Logical reads
* CPU time
* Elapsed time

---

# Complete Execution Order

```text
Create CentralSuperstoreDW
        ↓
Import raw data into staging_raw
        ↓
Verify staging_raw
        ↓
Run Schema_2.sql
        ↓
Run views_procedures.sql
        ↓
Run queries_joins_subqueries_sql.sql
        ↓
Run queries_cte_case.sql
        ↓
Run analytical_reports.sql
        ↓
Run optimization.sql
```

---

# Important Notes

* `Schema_2.sql` depends on the existence of `staging_raw`.
* The raw data must be imported **before** running `Schema_2.sql`.
* Make sure the staging column names match the names expected by `Schema_2.sql`.
* `Schema_2.sql` drops and recreates the dimension and fact tables when it runs.
* The original raw dataset should be kept available in case the staging table needs to be recreated.

---

# Final Data Warehouse Model

The final Star Schema consists of:

```text
                    dim_date
                       |
                       |
dim_customer ---- fact_sales ---- dim_product
                       |
                       |
                dim_location
                       |
                       |
                 dim_shipmode
```

The `staging_raw` table acts as the raw staging layer and is used as the source for the ETL process.
