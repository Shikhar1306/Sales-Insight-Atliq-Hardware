use gdb023;
-- 1. Provide the list of markets in which customer "Atliq Exclusive" operates its business in the APAC region.

SELECT DISTINCT market
FROM dim_customer
WHERE customer = 'Atliq Exclusive' AND region = 'APAC';

-- 2. What is the percentage of unique product increase in 2021 vs. 2020? 

WITH unique_products_2020 AS
(
	SELECT COUNT(DISTINCT product_code) unique_products_2020
	FROM fact_sales_monthly
	WHERE fiscal_year = 2020	
),
unique_products_2021 AS
(
	SELECT COUNT(DISTINCT product_code) unique_products_2021
	FROM fact_sales_monthly
	WHERE fiscal_year = 2021	
)
SELECT u1.unique_products_2020, u2.unique_products_2021, 
ROUND(100 * (u2.unique_products_2021 - u1.unique_products_2020)/u1.unique_products_2020,2) percentage_chg
FROM unique_products_2020 u1
CROSS JOIN unique_products_2021 u2;

-- 3. Provide a report with all the unique product counts for each segment and sort them in descending order of product counts.

SELECT segment, COUNT(DISTINCT product_code) unique_product_counts
FROM dim_product
GROUP BY segment
ORDER BY 2 DESC;

-- 4. Follow-up: Which segment had the most increase in unique products in 2021 vs 2020?

WITH cte AS
(
	SELECT dp.segment, dp.product_code, fsm.fiscal_year
	FROM dim_product dp
	INNER JOIN fact_sales_monthly fsm
	ON dp.product_code = fsm.product_code
),
unique_products_2020 AS
(
	SELECT segment,COUNT(DISTINCT product_code) product_count_2020
	FROM cte    
	WHERE fiscal_year = 2020
	GROUP BY segment
),
unique_products_2021 AS
(
	SELECT segment, COUNT(DISTINCT product_code) product_count_2021
	FROM cte
	WHERE fiscal_year = 2021	
    GROUP BY segment
)
SELECT u1.segment, u1.product_count_2020, u2.product_count_2021, 
u2.product_count_2021 - u1.product_count_2020 difference
FROM unique_products_2020 u1
INNER JOIN unique_products_2021 u2
ON u1.segment = u2.segment
ORDER BY 4 DESC;

-- 5. Get the products that have the highest and lowest manufacturing costs.

WITH manu_cost_cte AS
(
	SELECT product_code, ROUND(manufacturing_cost,2) manufacturing_cost,
    ROW_NUMBER() OVER(ORDER BY manufacturing_cost DESC) rn
	FROM fact_manufacturing_cost
)
SELECT mcc.product_code, dp.product, mcc.manufacturing_cost
FROM manu_cost_cte mcc
INNER JOIN dim_product dp
ON mcc.product_code = dp.product_code
WHERE rn in (1, (SELECT COUNT(product_code) FROM manu_cost_cte));

-- 6. Generate a report which contains the top 5 customers who received an average high pre_invoice_discount_pct for the fiscal year 2021 and in the Indian market.

SELECT dc.customer_code, dc.customer, CONCAT(ROUND(fpid.pre_invoice_discount_pct * 100,2), '%') average_discount_percentage
FROM dim_customer dc
INNER JOIN fact_pre_invoice_deductions fpid
ON dc.customer_code = fpid.customer_code
WHERE dc.market = 'India' AND fpid.fiscal_year = 2021
ORDER BY fpid.pre_invoice_discount_pct DESC
LIMIT 5;

-- 7. Get the complete report of the Gross sales amount for the customer “Atliq Exclusive” for each month . This analysis helps to get an idea of low and high-performing months and take strategic decisions.

SELECT MONTHNAME(fsm.date) 'month', YEAR(fsm.date) 'year', ROUND(SUM(fsm.sold_quantity * fgp.gross_price),2) gross_sales_amount
FROM fact_sales_monthly fsm
INNER JOIN fact_gross_price fgp
ON fsm.product_code = fgp.product_code
INNER JOIN dim_customer dc
ON fsm.customer_code = dc.customer_code
WHERE dc.customer = 'Atliq Exclusive'
GROUP BY fsm.date
ORDER BY fsm.date;

-- 8. In which quarter of 2020, got the maximum total_sold_quantity? The final output contains these fields sorted by the total_sold_quantity.

WITH quarter_wise_cte AS
(
	SELECT sold_quantity,
	CASE
		WHEN MONTH(date) IN (9,10,11) THEN 1
		WHEN MONTH(date) IN (12,1,2) THEN 2
		WHEN MONTH(date) IN (3,4,5) THEN 3
		WHEN MONTH(date) IN (6,7,8) THEN 4
	END AS 'quarter'
	FROM fact_sales_monthly
	WHERE fiscal_year = 2020
)
SELECT quarter , SUM(sold_quantity) total_sold_quantity
FROM quarter_wise_cte
GROUP BY quarter
ORDER BY 2 DESC;

-- 9. Which channel helped to bring more gross sales in the fiscal year 2021 and the percentage of contribution?

WITH fsm_2021 AS
(
	SELECT product_code, customer_code, sold_quantity
	FROM fact_sales_monthly
	WHERE fiscal_year = 2021
),
fgp_2021 AS
(
	SELECT product_code, gross_price
	FROM fact_gross_price
	WHERE fiscal_year = 2021
),
channel_cte AS 
(
	SELECT dc.channel, ROUND(SUM(fgp.gross_price * fsm.sold_quantity)/1000000,2) AS gross_sales_mln
	FROM fsm_2021 fsm
	INNER JOIN dim_customer dc
	ON fsm.customer_code = dc.customer_code
	INNER JOIN fgp_2021 fgp
	ON fsm.product_code = fgp.product_code 
	GROUP BY dc.channel
)
SELECT channel, gross_sales_mln, 
gross_sales_mln * 100/ SUM(gross_sales_mln) OVER() AS percentage
FROM channel_cte;

-- 10. Get the Top 3 products in each division that have a high total_sold_quantity in the fiscal_year 2021?

WITH top_3_prod AS
(
	SELECT dp.division, dp.product_code, dp.product, SUM(fsm.sold_quantity) total_sold_quantity,
	DENSE_RANK() OVER(PARTITION BY dp.division ORDER BY SUM(fsm.sold_quantity) DESC) rank_order
	FROM dim_product dp 
	INNER JOIN fact_sales_monthly fsm
	ON dp.product_code = fsm.product_code
	WHERE fsm.fiscal_year = 2021
	GROUP by dp.division, dp.product_code, dp.product
)
SELECT division, product_code, product, total_sold_quantity, rank_order
FROM top_3_prod 
WHERE rank_order <= 3;



