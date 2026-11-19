# Retail Sales Analysis (SQL)

> **Note:** The dataset, database setup and Questions 1–10 come from a guided tutorial ([Zero Analyst – SQL Data Analysis Portfolio Project #01/10](https://youtu.be/ChIQjGBI3AM)). The extra cleaning checks, Questions 11–15, the findings and the recommendations are my own work.

## Overview

I used PostgreSQL to build and clean a retail sales database, then answered 15 business questions about sales, customers and timing. I wanted to practise aggregations, `CASE` statements, CTEs and window functions on a realistic dataset.

**Database:** `Retail_Sales_Project` (PostgreSQL, run in pgAdmin)
**Dataset:** 2,000 transactions (1,997 after cleaning), Jan 2022 – Dec 2023, 155 customers, 3 categories (Beauty, Clothing, Electronics)
**Skills practised:** aggregation, date functions, `CASE`, CTEs, window functions (`RANK`, `LAG`), null handling

## Key Findings

A one-page summary with charts is in [`Retail_Sales_Findings.pdf`](Retail_Sales_Findings.pdf).

- **Seasonality:** September to December made up 57% of total sales (60% in 2022, 55% in 2023) and 57% of orders. Order value stayed about the same all year (about 461 in Sep–Dec vs 451 in other months), so the peak is driven by more orders, not bigger baskets.
- **Categories are close:** Electronics 313,810, Clothing 311,070, Beauty 286,840 (total 911,720). Beauty earns about 9% less than Electronics, but it has the highest average order value (469) and the highest margin (79.7%). It simply gets fewer orders (612 vs 684 and 701).
- **Time of day:** Evening (18:00 onwards) was the busiest shift with 1,062 of 1,997 orders (53%), ahead of Morning (558) and Afternoon (377). Orders step up sharply at 17:00 (213 between 17:00 and 17:59, against about 33 an hour from 12:00 to 16:59), so 64% of orders come from 17:00 onwards.
- **Customers:** All 155 customers bought at least twice (median 10 orders). The top 5 customers spent 148,470, or 16% of total sales.
- **Age:** Customers aged 25–54 generated 64% of sales. Under-25s generated 16%. (10 transactions with no recorded age, worth 0.4% of sales, are kept in the data and grouped as "Unknown".)
- **Growth:** Sales grew 1.3% from 452,825 in 2022 to 458,895 in 2023.

## Recommendations

1. **Finding:** Sep–Dec brings 57% of sales, and sales fell by 49,090 from Dec 2022 to Jan 2023. **Action:** plan stock and staffing around Sep–Dec, and run a January promotion to soften the drop.
2. **Finding:** Orders step up sharply at 17:00, with 64% placed from 17:00 onwards, while 12:00–16:59 is the quietest period (8% of orders). **Action:** focus staffing and promotions from 17:00, and test offers to lift the quiet early afternoon.
3. **Finding:** Beauty has the highest order value and margin but the fewest orders. **Action:** invest in marketing to raise Beauty order volume.
4. **Finding:** 25–54 year olds account for 64% of sales while under-25s account for 16%. **Action:** keep campaigns aimed at 25–54, and test whether a youth offer can grow the under-25 group.

## Repository Structure

```
SQL_Retail_Sales/
├── README.md
├── SQL_Query.sql               (full script: setup, cleaning, data checks, 15 questions)
└── Retail_Sales_Findings.pdf   (one-page summary with charts)
```

The dataset (`retail_sales.csv`) is provided by the tutorial creator in the video description, so it is not re-hosted here.

To run it: create the database, run the setup section of `SQL_Query.sql`, then import the CSV into `retail_sales` using pgAdmin's Import/Export tool (or `\copy` in psql). **The dates in the CSV are in dd/mm/yyyy format**, so check a few dates after importing (the script includes a check); if they are misread, run `SET datestyle = 'DMY';` before importing. Then run the rest of the script, which covers cleaning, data quality checks and all 15 questions.

## 1. Database Setup

```sql
CREATE DATABASE Retail_Sales_Project;

CREATE TABLE retail_sales
(
    transactions_id INT PRIMARY KEY,
    sale_date DATE,
    sale_time TIME,
    customer_id INT,
    gender VARCHAR(15),
    age INT,
    category VARCHAR(15),
    quantity INT,
    price_per_unit FLOAT,
    cogs FLOAT,
    total_sale FLOAT
);
```

## 2. Data Cleaning

I backed up the table, counted the problem rows, then deleted only the rows that were missing sales values (rows missing just the age are kept).

```sql
CREATE TABLE retail_sales_backup AS SELECT * FROM retail_sales;

SELECT COUNT(*) AS total_rows FROM retail_sales;

SELECT COUNT(*) AS rows_with_nulls
FROM retail_sales
WHERE sale_date IS NULL OR sale_time IS NULL OR customer_id IS NULL
   OR gender IS NULL OR age IS NULL OR category IS NULL
   OR quantity IS NULL OR price_per_unit IS NULL OR cogs IS NULL
   OR total_sale IS NULL;

SELECT
    COUNT(*) FILTER (WHERE age IS NULL) AS null_age,
    COUNT(*) FILTER (WHERE quantity IS NULL) AS null_quantity,
    COUNT(*) FILTER (WHERE price_per_unit IS NULL) AS null_price,
    COUNT(*) FILTER (WHERE cogs IS NULL) AS null_cogs,
    COUNT(*) FILTER (WHERE total_sale IS NULL) AS null_total_sale
FROM retail_sales;

DELETE FROM retail_sales
WHERE quantity IS NULL OR price_per_unit IS NULL
   OR cogs IS NULL OR total_sale IS NULL;
```

**Result:** 13 of 2,000 rows (0.65%) contained nulls. 10 of them were only missing the customer's age, so I **kept** them: they are valid sales (3,490 in total) and age is only needed for Q4 and Q12. The other 3 rows (transaction IDs 679, 746 and 1225) had no quantity, price, COGS or total sale, so they were unusable for sales analysis and I removed them, leaving 1,997 rows. There were no duplicate transaction IDs.

### Data quality checks

After cleaning I checked the data for problems (all in the script): no duplicate transaction IDs; age 18–64 and quantity 1–4 with no zero or negative values; gender values consistent; `total_sale` always equals quantity × price. Two things stood out. 70 transactions (3.5%) have a cost of goods higher than the sale, and I left them in. Also, `customer_id` is not a reliable identifier for one person: 151 of the 155 customers appear with more than one gender and all 155 with more than one age, so this looks like a practice dataset. I treat `customer_id` as given in the customer questions.

## 3. Guided Questions (1–10)

**Q1. All sales made on 2022-11-05**
```sql
SELECT * FROM retail_sales WHERE sale_date = '2022-11-05';
```
Result: 11 transactions.

**Q2. Clothing transactions in Nov 2022 where quantity is 4 or more**
```sql
SELECT *
FROM retail_sales
WHERE category = 'Clothing'
  AND TO_CHAR(sale_date, 'YYYY-MM') = '2022-11'
  AND quantity >= 4;
```
Result: 17 transactions. The maximum quantity in the data is 4, so "more than 4" would return nothing; `>= 4` is the correct filter.

**Q3. Total sales by category**
```sql
SELECT category, SUM(total_sale) AS net_sale, COUNT(*) AS total_orders
FROM retail_sales
GROUP BY 1;
```
Result: Electronics 313,810 (684 orders), Clothing 311,070 (701), Beauty 286,840 (612).

**Q4. Average age of Beauty customers**
```sql
SELECT ROUND(AVG(age), 2) AS avg_age
FROM retail_sales
WHERE category = 'Beauty';
```
Result: 40.42 years. (`AVG` ignores the one Beauty transaction with no recorded age.)

**Q5. Transactions with total_sale above 1000**
```sql
SELECT * FROM retail_sales WHERE total_sale > 1000;
```
Result: 306 transactions (Electronics 106, Clothing 104, Beauty 96).

**Q6. Transactions by gender and category**
```sql
SELECT category, gender, COUNT(*) AS total_trans
FROM retail_sales
GROUP BY category, gender
ORDER BY 1;
```
Result: Beauty is the only category with a clear gender gap (330 female vs 282 male). Clothing (347 vs 354) and Electronics (340 vs 344) are almost even.

**Q7. Month with the highest average sale in each year**
```sql
SELECT year, month, avg_sale
FROM (
    SELECT
        EXTRACT(YEAR FROM sale_date) AS year,
        EXTRACT(MONTH FROM sale_date) AS month,
        AVG(total_sale) AS avg_sale,
        RANK() OVER (PARTITION BY EXTRACT(YEAR FROM sale_date)
                     ORDER BY AVG(total_sale) DESC) AS rnk
    FROM retail_sales
    GROUP BY 1, 2
) t
WHERE rnk = 1;
```
Result: July 2022 (541.34) and February 2023 (535.53). This is the month with the highest *average* sale, which is different from the best month by *total* sales (see Q15).

**Q8. Top 5 customers by total sales**
```sql
SELECT customer_id, SUM(total_sale) AS total_sales
FROM retail_sales
GROUP BY 1
ORDER BY 2 DESC
LIMIT 5;
```
Result: customer 3 spent most (38,440), then customers 1 (30,750), 5 (30,405), 2 (25,295) and 4 (23,580). Together they spent 148,470.

**Q9. Unique customers per category**
```sql
SELECT category, COUNT(DISTINCT customer_id) AS cnt_unique_cs
FROM retail_sales
GROUP BY category;
```
Result: Clothing 149, Electronics 144, Beauty 141 (out of 155 customers).

**Q10. Orders by shift (Morning before 12:00, Afternoon 12:00–17:59, Evening 18:00 onwards)**
```sql
WITH hourly_sale AS (
    SELECT *,
        CASE
            WHEN EXTRACT(HOUR FROM sale_time) < 12 THEN 'Morning'
            WHEN EXTRACT(HOUR FROM sale_time) BETWEEN 12 AND 17 THEN 'Afternoon'
            ELSE 'Evening'
        END AS shift
    FROM retail_sales
)
SELECT shift, COUNT(*) AS total_orders
FROM hourly_sale
GROUP BY shift;
```
Result: Evening 1,062, Morning 558, Afternoon 377. The Afternoon figure includes the 213 orders placed between 17:00 and 17:59, because the query groups by hour (hour 17 counts as Afternoon).

## 4. My Own Extension (11–15)

**Q11. Profit and margin by category**
```sql
SELECT category,
       SUM(total_sale) AS revenue,
       SUM(total_sale - cogs) AS profit,
       ROUND(SUM(total_sale - cogs) * 100.0 / SUM(total_sale), 1) AS margin_pct
FROM retail_sales
GROUP BY category
ORDER BY profit DESC;
```
Result: Clothing 246,680 profit (79.3% margin), Electronics 246,648 (78.6%), Beauty 228,630 (79.7%). Margins are all close to 79%, which is unusually high for retail, so this looks like a simplified practice dataset and I would not read much into the margin differences.

**Q12. Sales by age group**
```sql
SELECT
    CASE WHEN age IS NULL THEN 'Unknown'
         WHEN age < 25 THEN 'Under 25'
         WHEN age BETWEEN 25 AND 39 THEN '25-39'
         WHEN age BETWEEN 40 AND 54 THEN '40-54'
         ELSE '55+' END AS age_group,
    COUNT(*) AS orders,
    SUM(total_sale) AS total_sales
FROM retail_sales
GROUP BY 1
ORDER BY total_sales DESC;
```
Result: 40–54 (291,510), 25–39 (289,570), 55+ (177,990), Under 25 (149,160), Unknown (3,490 from 10 orders with no recorded age).

**Q13. How often do customers buy?** *(I replaced my original "repeat vs one-time" question because every customer had bought at least twice.)*
```sql
WITH customer_orders AS (
    SELECT customer_id, COUNT(*) AS orders
    FROM retail_sales
    GROUP BY customer_id
)
SELECT COUNT(*) AS customers,
       MIN(orders) AS min_orders,
       ROUND(AVG(orders), 1) AS avg_orders,
       MAX(orders) AS max_orders
FROM customer_orders;
```
Result: 155 customers, 2 to 76 orders each, 12.9 on average (median 10).

**Q14. Month-on-month change in sales**
```sql
WITH monthly AS (
    SELECT DATE_TRUNC('month', sale_date) AS month,
           SUM(total_sale) AS total_sales
    FROM retail_sales
    GROUP BY 1
)
SELECT month, total_sales,
       total_sales - LAG(total_sales) OVER (ORDER BY month) AS change_vs_prev_month
FROM monthly
ORDER BY month;
```
Result: the biggest rise was September 2022 (+40,575, from 21,195 to 61,770) and the biggest fall was January 2023 (−49,090). The same pattern repeats in 2023.

**Q15. Best month by total sales in each year**
```sql
SELECT year, month, total_sales
FROM (
    SELECT
        EXTRACT(YEAR FROM sale_date) AS year,
        EXTRACT(MONTH FROM sale_date) AS month,
        SUM(total_sale) AS total_sales,
        RANK() OVER (PARTITION BY EXTRACT(YEAR FROM sale_date)
                     ORDER BY SUM(total_sale) DESC) AS rnk
    FROM retail_sales
    GROUP BY 1, 2
) t
WHERE rnk = 1;
```
Result: December in both years (72,880 in 2022 and 69,145 in 2023).

## What I Learned

- The "best month" depends on the measure: July 2022 has the highest *average* sale (Q7), but December has the highest *total* sales (Q15). I now check what a question is really asking before writing the query.
- Counting and inspecting null rows before deleting them showed that only 3 of the 13 rows were unusable. The other 10 were just missing an age, so I kept them and handled them in the age question.
- Checking the data first (date format on import, duplicates, impossible values) found problems I would have missed, such as `customer_id` not matching a single gender or age.
- Using `RANK() OVER (PARTITION BY ...)`, `LAG()`, CTEs and `CASE` to answer business questions.
