create database retail_intelligence_hub;
use retail_intelligence_hub;
select database();

# Import Data 

# Verify the number of records in all three tables
SELECT COUNT(*) AS total_orders
FROM orders_raw;
SELECT COUNT(*) AS total_people
FROM people_raw;
SELECT COUNT(*) AS total_returns
FROM returns_raw;

# Check structure of all three tables
describe orders_raw;
describe people_raw;
describe returns_raw;

# STEP 10 — COLUMN NAME STANDARDIZATION
ALTER TABLE returns_raw
RENAME COLUMN `ï»¿Returned`
TO Returned;
ALTER TABLE people_raw
RENAME COLUMN `ï»¿Managers`
TO Managers;

#DATA CLEANING: MISSING VALUE CHECK
#Check NULL values in important Orders columns

select count(*) as total_rows,
sum(case 
when `Order ID` is null 
or `Order ID` ='' 
THEN 1 ELSE 0 
END) 
as missing_order_id FROM orders_raw;

# Using this i'll have to same query for all colm of orders_raw instead 
# QUICK DATA CLEANING (Check Missing Values for All Columns)

select count(*) AS rows_with_missing_data
from orders_raw 
where 
`Order ID` IS NULL or `Order ID`=''
OR  `Order Date` IS NULL or `Order Date`=''
OR `Ship Date` IS NULL OR `Ship Date`=''
OR `Customer ID` IS NULL OR `Customer ID`=''
OR `Customer Name` IS NULL OR `Customer Name`=''
OR Sales IS NULL OR Sales=''
OR Profit IS NULL OR Profit=''

UNION ALL 

SELECT
COUNT(*) AS rows_with_missing_data
FROM returns_raw
WHERE
Returned IS NULL OR Returned=''
OR `Order ID` IS NULL OR `Order ID`=''
OR Region IS NULL OR Region=''

union all

SELECT
COUNT(*) AS rows_with_missing_data
FROM people_raw
WHERE
Managers IS NULL OR Managers=''
OR Region_Continent IS NULL OR Region_Continent=''
OR Region IS NULL OR Region=''
OR Continent IS NULL OR Continent='';

# DUPLICATE CHECK (ALL TABLES TOGETHER)
# subquery must have a temporary table name

select
'orders_raw' as table_name,
count(*) as duplicate_groups
from
(SELECT `Row ID`
from orders_raw
group by`Row ID`
having count(*) > 1) a

union ALL 

select 
'people_raw' AS table_name,
count(*) as duplicate_groups
from
(select `Managers`
from people_raw
group by Managers
having count(*)> 1)b 

union all

select 
'returns_raw' AS table_name,
count(*) as duplicate_groups
from
(select `Order ID`
from returns_raw
group by `Order ID`
having count(*)> 1)c ;

# Raw to clean after data cleaning 

create table orders_clean as 
select * from orders_raw;

CREATE TABLE people_clean AS
SELECT * FROM people_raw;

CREATE TABLE returns_clean AS
SELECT * FROM returns_raw;

# EDA: Dataset Overview FOR orders_clean

#Step 1 — Dataset Overview
select 
count(distinct `Order ID`) as unique_orders,
count(distinct`Customer ID`) as unique_customers,
count(distinct`Product ID`) as unique_products
from orders_clean;

#Step 2 — Business KPI Overview

SET SQL_SAFE_UPDATES = 0;
UPDATE orders_clean
SET
Sales = REPLACE(REPLACE(Sales,'$',''),',',''),
Profit = REPLACE(REPLACE(Profit,'$',''),',','');
SET SQL_SAFE_UPDATES = 1; 
ALTER TABLE orders_clean
MODIFY COLUMN Sales DECIMAL(10,2),
MODIFY COLUMN Profit DECIMAL(10,2);

select 
concat('$',round(sum(sales)/100000,2 ),'M')as TOTAL_SALES ,
concat('$',ROUND(sum(profit)/1000,2),'K') as TOTAL_PROFIT,
concat( '$' ,round(AVG(sales),2))as AVGL_SALES 
from orders_clean;


# Step 3 - Top 10 Regions by Sales
SELECT
Region,
CONCAT(
'$',
ROUND(SUM(Sales/1000),2),
'K')
AS total_sales
FROM orders_clean
GROUP BY Region
ORDER BY SUM(sales) DESC
LIMIT 10;

#Step 4 - Category-wise Profitability
SELECT
Category,
CONCAT(
'$ ',
ROUND(SUM(Profit)/1000,2),
' K'
) 
AS total_profit
FROM orders_clean
GROUP BY Category
ORDER BY SUM(Profit) DESC;

#Step 5 - Monthly Sales Trend

set sql_safe_updates =0;
update orders_clean
set`Order Date`=
str_to_date(`Order Date`,'%Y-%m-%d');
update orders_clean
set`Ship Date`=
str_to_date(`Ship Date`,'%m/%d/%Y');
set sql_safe_updates = 1;

ALTER TABLE orders_clean
MODIFY COLUMN `Order Date` DATE,
MODIFY COLUMN `Ship Date` DATE;

select
year(`Order Date`) as order_year,
month(`Order Date`) as order_month,
CONCAT(
'$ ',
ROUND(SUM(Sales)/1000,2),
' K'
) AS monthly_sales_k

from orders_clean
group by order_year,order_month
order by order_year,order_month;

# EDA: Dataset Overview FOR people_clean

#How many managers are assigned across regions?
select Region,
count(distinct Managers) as total_managers
from people_clean
group by Region
order by total_managers desc;

# EDA: Dataset Overview FOR returns_clean

# How many orders were returned overall?
select 
count(distinct `Order ID`) as total_returned_orders
from returns_clean;

# Which regions contribute the most to returns?
select
Region,
count(`Order ID`) AS total_returns
from returns_clean
group by Region
order by total_returns desc;

# JOIN 1 → Orders + Returns
# What percentage of orders get returned region wise?

select 
o.Region,
COUNT(DISTINCT r.`Order ID`) AS returned_orders,
COUNT(DISTINCT o.`Order ID`) AS total_orders,
concat(ROUND(
(
COUNT(DISTINCT r.`Order ID`)/COUNT(DISTINCT o.`Order ID`)
)*100,
2
),'%') as return_rate 

FROM orders_clean o
LEFT JOIN returns_clean r
ON o.`Order ID` = r.`Order ID`

GROUP BY o.Region
ORDER By return_rate DESC;

# JOIN 2 → Orders + People
# Which managers generate the highest sales and profit?

select
p.managers,
concat(ROUND(SUM(o.Sales/1000),2),'k') AS total_sales,
concat(ROUND(SUM(o.Profit/1000),2),'k') AS total_profit
from orders_clean o
INNER JOIN people_clean p
ON o.Region = p.Region
GROUP BY p.Managers
ORDER BY total_profit DESC;

# Shipping Performance
#How long does shipping take on average?

select 
Region,
round(avg(
DATEDIFF(`Ship Date`,`Order Date`)
),1) AS avg_shipping_days
FROM orders_clean
GROUP BY Region
ORDER BY avg_shipping_days DESC;

# One final SQL layer.

CREATE VIEW retail_dashboard_view AS
SELECT
    o.`Row ID`,
    o.`Order ID`,
    o.`Order Date`,
    o.`Ship Date`,

    YEAR(o.`Order Date`) AS order_year,
    MONTH(o.`Order Date`) AS order_month,
    MONTHNAME(o.`Order Date`) AS order_month_name,

    o.`Customer ID`,
    o.`Customer Name`,
    o.Segment,
    o.Region,
   
   p.Managers,
    p.Continent,

    o.Category,
    o.`Sub-Category`,
    o.`Product ID`,
    o.`Product Name`,
    o.Sales,
    o.Profit,

    r.Returned,

    CASE
        WHEN r.Returned = 'Yes' THEN 1
        ELSE 0
    END AS returned_flag,

    DATEDIFF(o.`Ship Date`, o.`Order Date`) AS shipping_days

FROM orders_clean o
LEFT JOIN people_clean p
    ON o.Region = p.Region
LEFT JOIN returns_clean r
    ON o.`Order ID` = r.`Order ID`;