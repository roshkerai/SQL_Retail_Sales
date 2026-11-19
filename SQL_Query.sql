/* =====================================================================
   RETAIL SALES ANALYSIS - SQL PROJECT
   Author   : Roshan Kerai
   Database : PostgreSQL (run in pgAdmin), database "Retail_Sales_Project"
   Dataset  : retail_sales.csv - 2,000 transactions, Jan 2022 - Dec 2023

   Credit   : The dataset, setup and Questions 1-10 come from a guided tutorial:
              Zero Analyst, "SQL Data Analysis Portfolio Project #01/10"
              (https://youtu.be/ChIQjGBI3AM).
              The cleaning checks, data quality checks, Questions 11-15
              and all result comments are my own work.

   Contents :
     1. Database and table setup
     2. Data cleaning
     3. Data exploration and data quality checks
     4. Guided business questions (Q1 - Q10)
     5. My own extension questions (Q11 - Q15)
   ===================================================================== */


/* =====================================================================
   1. DATABASE AND TABLE SETUP
   ===================================================================== */

-- Run this line on its own, then open a Query Tool connected to the new database.
CREATE DATABASE Retail_Sales_Project;

-- Create the table
DROP TABLE IF EXISTS retail_sales;
CREATE TABLE retail_sales
(
    transactions_id INT PRIMARY KEY,
    sale_date       DATE,
    sale_time       TIME,
    customer_id     INT,
    gender          VARCHAR(15),
    age             INT,
    category        VARCHAR(15),
    quantity        INT,
    price_per_unit  FLOAT,
    cogs            FLOAT,
    total_sale      FLOAT
);

-- Data import: the CSV was imported into retail_sales with pgAdmin's Import/Export tool.
-- The CSV dates are dd/mm/yyyy, so check they loaded correctly:
SELECT MIN(sale_date) AS first_sale, MAX(sale_date) AS last_sale
FROM retail_sales;
-- Result: Jan 2022 to Dec 2023, as expected.

-- Preview the data
SELECT * FROM retail_sales
LIMIT 10;


/* =====================================================================
   2. DATA CLEANING
   ===================================================================== */

-- Step 1: Back up the raw data so nothing is lost
DROP TABLE IF EXISTS retail_sales_backup;
CREATE TABLE retail_sales_backup AS
SELECT * FROM retail_sales;

-- Step 2: Row count before cleaning
SELECT COUNT(*) AS rows_before_cleaning
FROM retail_sales;
-- Result: 2,000 rows

-- Step 3: How many nulls are in each column?
SELECT
    COUNT(*) FILTER (WHERE customer_id IS NULL)    AS null_customer_id,
    COUNT(*) FILTER (WHERE gender IS NULL)         AS null_gender,
    COUNT(*) FILTER (WHERE age IS NULL)            AS null_age,
    COUNT(*) FILTER (WHERE category IS NULL)       AS null_category,
    COUNT(*) FILTER (WHERE quantity IS NULL)       AS null_quantity,
    COUNT(*) FILTER (WHERE price_per_unit IS NULL) AS null_price_per_unit,
    COUNT(*) FILTER (WHERE cogs IS NULL)           AS null_cogs,
    COUNT(*) FILTER (WHERE total_sale IS NULL)     AS null_total_sale
FROM retail_sales;
-- Result: 10 rows have a missing age; 3 rows have no quantity, price, COGS or total_sale.

-- Step 4: Look at the rows that will be removed
SELECT *
FROM retail_sales
WHERE quantity IS NULL
   OR price_per_unit IS NULL
   OR cogs IS NULL
   OR total_sale IS NULL;
-- Result: 3 rows (transactions_id 679, 746 and 1225)

-- Step 5: Remove only the rows with missing sales values.
-- The 10 rows with a missing age are KEPT: they are valid sales (3,490 in total)
-- and age is only used in Q4 and Q12.
DELETE FROM retail_sales
WHERE quantity IS NULL
   OR price_per_unit IS NULL
   OR cogs IS NULL
   OR total_sale IS NULL;

-- Step 6: Row count after cleaning
SELECT COUNT(*) AS rows_after_cleaning
FROM retail_sales;
-- Result: 1,997 rows (3 removed, 0.15% of the data)


/* =====================================================================
   3. DATA EXPLORATION AND DATA QUALITY CHECKS
   ===================================================================== */

-- How many sales do we have?
SELECT COUNT(*) AS total_records
FROM retail_sales;
-- Result: 1,997

-- How many unique customers do we have?
SELECT COUNT(DISTINCT customer_id) AS unique_customers
FROM retail_sales;
-- Result: 155

-- Which categories do we have?
SELECT DISTINCT category
FROM retail_sales;
-- Result: Beauty, Clothing, Electronics

-- Check 1: duplicate transaction IDs
SELECT transactions_id, COUNT(*) AS times_seen
FROM retail_sales
GROUP BY transactions_id
HAVING COUNT(*) > 1;
-- Result: 0 rows, no duplicates

-- Check 2: are the values in a sensible range?
SELECT
    MIN(age)        AS min_age,      MAX(age)        AS max_age,
    MIN(quantity)   AS min_quantity, MAX(quantity)   AS max_quantity,
    MIN(total_sale) AS min_sale,     MAX(total_sale) AS max_sale
FROM retail_sales;
-- Result: age 18-64, quantity 1-4, total_sale 25-2,000. No zero or negative values.

-- Check 3: are the gender values consistent?
SELECT DISTINCT gender
FROM retail_sales;
-- Result: Male, Female only, with no spelling variations

-- Check 4: does total_sale equal quantity x price_per_unit?
SELECT COUNT(*) AS mismatched_rows
FROM retail_sales
WHERE total_sale <> quantity * price_per_unit;
-- Result: 0, the totals are consistent

-- Check 5: transactions where the cost of goods is higher than the sale
SELECT COUNT(*) AS loss_making_rows
FROM retail_sales
WHERE cogs > total_sale;
-- Result: 70 rows (3.5%). I left them in because they could be genuine
-- loss-leaders, but they would be worth querying with the data owner.

-- Check 6: does each customer_id always have the same gender and age?
SELECT
    (SELECT COUNT(*) FROM (SELECT customer_id FROM retail_sales
                           GROUP BY customer_id
                           HAVING COUNT(DISTINCT gender) > 1) g) AS customers_with_several_genders,
    (SELECT COUNT(*) FROM (SELECT customer_id FROM retail_sales
                           GROUP BY customer_id
                           HAVING COUNT(DISTINCT age) > 1) a)    AS customers_with_several_ages;
-- Result: 151 and 155 (out of 155 customers). customer_id is not a reliable
-- identifier for one real person, so this looks like a practice dataset. I treat
-- customer_id as given in the customer questions (Q8, Q9, Q13).


/* =====================================================================
   4. GUIDED BUSINESS QUESTIONS (Q1 - Q10)
   ===================================================================== */

-- Q1. Retrieve all columns for sales made on '2022-11-05'
SELECT *
FROM retail_sales
WHERE sale_date = '2022-11-05';
-- Result: 11 transactions


-- Q2. Retrieve all Clothing transactions in Nov-2022 where the quantity sold is 4 or more
-- (the maximum quantity in the data is 4, so "more than 4" would return nothing)
SELECT *
FROM retail_sales
WHERE category = 'Clothing'
  AND TO_CHAR(sale_date, 'YYYY-MM') = '2022-11'
  AND quantity >= 4;
-- Result: 17 transactions


-- Q3. Total sales and number of orders for each category
SELECT
    category,
    SUM(total_sale) AS net_sale,
    COUNT(*)        AS total_orders
FROM retail_sales
GROUP BY category
ORDER BY net_sale DESC;
-- Result: Electronics 313,810 (684 orders), Clothing 311,070 (701), Beauty 286,840 (612)


-- Q4. Average age of customers who bought from the 'Beauty' category
-- (AVG ignores the one Beauty row with no recorded age)
SELECT ROUND(AVG(age), 2) AS avg_age
FROM retail_sales
WHERE category = 'Beauty';
-- Result: 40.42 years


-- Q5. All transactions where total_sale is greater than 1000
SELECT *
FROM retail_sales
WHERE total_sale > 1000;
-- Result: 306 transactions (Electronics 106, Clothing 104, Beauty 96)


-- Q6. Number of transactions made by each gender in each category
SELECT
    category,
    gender,
    COUNT(*) AS total_trans
FROM retail_sales
GROUP BY category, gender
ORDER BY category, gender;
-- Result: Beauty 330 female vs 282 male; Clothing 347 vs 354; Electronics 340 vs 344


-- Q7. Average sale for each month, and the month with the highest average sale in each year
-- (note: this ranks by AVERAGE sale; the best month by TOTAL sales is in Q15)
SELECT year, month, avg_sale
FROM (
    SELECT
        EXTRACT(YEAR FROM sale_date)  AS year,
        EXTRACT(MONTH FROM sale_date) AS month,
        AVG(total_sale)               AS avg_sale,
        RANK() OVER (PARTITION BY EXTRACT(YEAR FROM sale_date)
                     ORDER BY AVG(total_sale) DESC) AS rnk
    FROM retail_sales
    GROUP BY 1, 2
) AS t1
WHERE rnk = 1;
-- Result: July 2022 (541.34) and February 2023 (535.53)


-- Q8. Top 5 customers by total sales
SELECT
    customer_id,
    SUM(total_sale) AS total_sales
FROM retail_sales
GROUP BY customer_id
ORDER BY total_sales DESC
LIMIT 5;
-- Result: customers 3 (38,440), 1 (30,750), 5 (30,405), 2 (25,295), 4 (23,580)
-- Together they spent 148,470, about 16% of total sales.


-- Q9. Number of unique customers who bought from each category
SELECT
    category,
    COUNT(DISTINCT customer_id) AS cnt_unique_cs
FROM retail_sales
GROUP BY category
ORDER BY cnt_unique_cs DESC;
-- Result: Clothing 149, Electronics 144, Beauty 141 (out of 155 customers)


-- Q10. Number of orders in each shift
-- (Morning: before 12:00, Afternoon: 12:00-17:59, Evening: 18:00 onwards.
--  The query groups by hour, so everything from 17:00 to 17:59 counts as Afternoon.)
WITH hourly_sale AS (
    SELECT *,
        CASE
            WHEN EXTRACT(HOUR FROM sale_time) < 12 THEN 'Morning'
            WHEN EXTRACT(HOUR FROM sale_time) BETWEEN 12 AND 17 THEN 'Afternoon'
            ELSE 'Evening'
        END AS shift
    FROM retail_sales
)
SELECT
    shift,
    COUNT(*) AS total_orders
FROM hourly_sale
GROUP BY shift
ORDER BY total_orders DESC;
-- Result: Evening 1,062, Morning 558, Afternoon 377
-- Afternoon includes 213 orders placed between 17:00 and 17:59. Orders step up sharply at
-- 17:00 (about 33 an hour from 12:00 to 16:59), so 64% of orders come from 17:00 onwards.


/* =====================================================================
   5. MY OWN EXTENSION QUESTIONS (Q11 - Q15)
   ===================================================================== */

-- Q11. Revenue, profit and profit margin for each category
-- (cogs is the cost for the whole transaction, so profit = total_sale - cogs)
SELECT
    category,
    SUM(total_sale)              AS revenue,
    SUM(total_sale - cogs)       AS profit,
    ROUND((SUM(total_sale - cogs) * 100.0 / SUM(total_sale))::numeric, 1) AS margin_pct
FROM retail_sales
GROUP BY category
ORDER BY profit DESC;
-- Result: Clothing 246,680 (79.3%), Electronics 246,648 (78.6%), Beauty 228,630 (79.7%)
-- Margins are all close to 79%, which is unusually high for retail, so I would not
-- read much into the differences.


-- Q12. Orders and sales by age group
-- (rows with no recorded age go into 'Unknown' so they are not counted as 55+)
SELECT
    CASE WHEN age IS NULL THEN 'Unknown'
         WHEN age < 25 THEN 'Under 25'
         WHEN age BETWEEN 25 AND 39 THEN '25-39'
         WHEN age BETWEEN 40 AND 54 THEN '40-54'
         ELSE '55+' END AS age_group,
    COUNT(*)        AS orders,
    SUM(total_sale) AS total_sales
FROM retail_sales
GROUP BY 1
ORDER BY total_sales DESC;
-- Result: 40-54 (291,510), 25-39 (289,570), 55+ (177,990), Under 25 (149,160),
-- Unknown (3,490 from 10 orders). Ages 25-54 make up about 64% of sales.


-- Q13. How often do customers buy?
-- (replaces my original "repeat vs one-time" idea, as every customer bought at least twice)
WITH customer_orders AS (
    SELECT customer_id, COUNT(*) AS orders
    FROM retail_sales
    GROUP BY customer_id
)
SELECT
    COUNT(*)                    AS customers,
    MIN(orders)                 AS min_orders,
    ROUND(AVG(orders), 1)       AS avg_orders,
    MAX(orders)                 AS max_orders
FROM customer_orders;
-- Result: 155 customers, 2 to 76 orders each, 12.9 on average


-- Q14. Month-on-month change in total sales
WITH monthly AS (
    SELECT
        DATE_TRUNC('month', sale_date) AS month,
        SUM(total_sale)                AS total_sales
    FROM retail_sales
    GROUP BY 1
)
SELECT
    month,
    total_sales,
    total_sales - LAG(total_sales) OVER (ORDER BY month) AS change_vs_prev_month
FROM monthly
ORDER BY month;
-- Result: biggest rise Sep 2022 (+40,575); biggest fall Jan 2023 (-49,090).
-- Sales jump every September and drop every January.


-- Q15. Best month by TOTAL sales in each year
SELECT year, month, total_sales
FROM (
    SELECT
        EXTRACT(YEAR FROM sale_date)  AS year,
        EXTRACT(MONTH FROM sale_date) AS month,
        SUM(total_sale)               AS total_sales,
        RANK() OVER (PARTITION BY EXTRACT(YEAR FROM sale_date)
                     ORDER BY SUM(total_sale) DESC) AS rnk
    FROM retail_sales
    GROUP BY 1, 2
) AS t1
WHERE rnk = 1;
-- Result: December in both years (72,880 in 2022 and 69,145 in 2023)

-- End of project
