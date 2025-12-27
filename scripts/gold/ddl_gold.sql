/*
===============================================================================
DDL Script: Create Gold Views
===============================================================================
Script Purpose:
    This script creates views for the Gold layer in the data warehouse. 
    The Gold layer represents the final dimension and fact tables (Star Schema)

    Each view performs transformations and combines data from the Silver layer 
    to produce a clean, enriched, and business-ready dataset.

Usage:
    - These views can be queried directly for analytics and reporting.
===============================================================================
*/

-- =============================================================================
-- Create Dimension: gold.dim_customers
-- =============================================================================
IF OBJECT_ID('gold.dim_customers', 'V') IS NOT NULL
    DROP VIEW gold.dim_customers;
GO

CREATE VIEW gold.dim_customers AS
SELECT 
	ROW_NUMBER() OVER( ORDER BY Cust_id) AS customer_key,
	CI.Cust_id AS customer_id,
	CI.Cust_key AS customer_number,
	CI.Cust_Firstname AS first_name,
	CI.Cust_Lastname AS last_name,
	CA.bdate AS birth_date,
	CL.cntry AS country,
	CI.Cust_marital_status AS maritial_status,
	CASE 
		WHEN CI.Cust_gndr != 'N/a' THEN CI.Cust_gndr
		ELSE COALESCE(CA.gen, 'N/a')
	END AS gender,
	CI.Cust_create_date AS creation_date
FROM silver.crm_cust_info AS CI
LEFT JOIN silver.erp_cust_az12 AS CA
ON CI.Cust_key = CA.cid
LEFT JOIN silver.erp_loc_a101 AS CL
ON CI.Cust_key = CL.cid

-- =============================================================================
-- Create Dimension: gold.dim_products
-- =============================================================================
IF OBJECT_ID('gold.dim_products', 'V') IS NOT NULL
    DROP VIEW gold.dim_products;
GO
  
CREATE VIEW gold.dim_products AS
SELECT
	ROW_NUMBER() OVER( ORDER BY PI.prd_start_dt, PI.prd_id) AS product_key,
	PI.prd_id AS product_id,
	PI.prd_key AS product_number,
	PI.prd_nm AS product_name,
	PI.cat_id AS category_id,
	PC.cat AS category,
	PC.subcat AS subcategory,
	PC.maintainance,
	PI.prd_cost AS cost,
	PI.prd_line AS product_line,
	PI.prd_start_dt AS start_date
FROM silver.crm_prd_info AS PI
LEFT JOIN silver.erp_px_cat_g1v2 AS PC
ON PI.cat_id = PC.id

-- =============================================================================
-- Create Fact Table: gold.fact_sales
-- =============================================================================
IF OBJECT_ID('gold.fact_sales', 'V') IS NOT NULL
    DROP VIEW gold.fact_sales;
GO
  
CREATE VIEW gold.fact_sales AS
SELECT
	SD.sls_ord_num AS order_number,
	PR.product_key,
	CT.customer_key,
	SD.sls_order_dt AS order_date,
	SD.sls_ship_dt AS shipping_date,
	SD.sls_due_dt AS due_date,
	SD.sls_sales AS sales_amount,
	SD.sls_quantity AS quantitiy,
	SD.sls_price AS price
FROM silver.crm_sales_details AS SD
LEFT JOIN gold.dim_customers AS CT
ON SD.sls_cust_id = CT.customer_id
LEFT JOIN gold.dim_products AS PR
ON SD.sls_prd_key = PR.product_number
