/*
==============================================================================
Stored Procedure: Load Silver Layer (Bronze -> Silver)
==============================================================================
Script Purpose:
  This stored procedure performs the ETL (Extract, Transform, Load) process to
  populate the "silver" schema tables from the "bronze" schema.

Actions Performed:
  - Truncates Silver tables.
  - Inserts transformed and cleansed data from Bronze into Silver tables.

Parameters: None.
This stored procedure does not accept any parameters or return any values.

Usage Example:
  EXEC Silver.load_silver;
==============================================================================
*/

CREATE OR ALTER PROCEDURE silver.load_silver AS
BEGIN
	DECLARE @start_time DATETIME, @end_time DATETIME;
	BEGIN TRY
		SET @start_time = GETDATE(); --[ For whole silver layer time calculation ]
		PRINT '=====================================================';
		PRINT 'Loading The Silver Layer';
		PRINT '=====================================================';

		PRINT '-----------------------------------------------------';
		PRINT 'Loading CRM Tables';
		PRINT '-----------------------------------------------------';
---------------------------CUSTOMER INFORMATION CRM -------------------------------------

		SET @start_time = GETDATE();
		PRINT '>> Truncating Table: silver.crm_cust_info';
		TRUNCATE TABLE silver.crm_cust_info;
		PRINT '>> Inserting Data Into: silver.crm_cust_info';

		INSERT INTO silver.crm_cust_info(
			Cust_id,
			Cust_key,
			Cust_Firstname,
			Cust_Lastname,
			Cust_gndr,
			Cust_marital_status,
			Cust_create_date
		)

		SELECT 
			Cust_id,
			Cust_key,
			TRIM(Cust_Firstname) AS Cust_Firstname,
			TRIM(Cust_Lastname) AS Cust_Lastname,
			CASE WHEN UPPER(TRIM(Cust_gndr)) = 'M' THEN 'Male'
				 WHEN UPPER(TRIM(Cust_gndr)) = 'F' THEN 'Female'
				 ELSE 'N/a'
			END Cust_gndr,
			CASE WHEN UPPER(TRIM(Cust_marital_status)) = 'M' THEN 'Married'
				 WHEN UPPER(TRIM(Cust_marital_status)) = 'S' THEN 'Single'
				 ELSE 'N/a'
			END Cust_maritial_status,
			Cust_create_date

		from (
			select *,
			Row_number() OVER( PARTITION BY cust_id ORDER BY Cust_create_date desc) AS Flag
			FROM bronze.crm_cust_info
			WHERE Cust_id IS NOT NULL
		)t
		where flag = 1
		SET @end_time = GETDATE()
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '-----------------';
---------------------------------------------------------------------------------------------------
--- PORDUCT INFO CRM

		SET @start_time = GETDATE();
		PRINT '>> Truncating Table: silver.crm_prd_info';
		TRUNCATE TABLE silver.crm_prd_info;
		PRINT '>> Inserting Data Into: silver.crm_prd_info';

		INSERT INTO silver.crm_prd_info(
			prd_id,
			prd_key,
			cat_id,
			prd_nm,
			prd_cost,
			prd_line,
			prd_start_dt,
			prd_end_dt
			)

		SELECT
			prd_id,
			SUBSTRING ( prd_key, 7, LEN(prd_key) ) AS Prd_Key,
			REPLACE ( SUBSTRING( prd_key, 1, 5 ), '-' , '_') AS Cat_ID,
			prd_nm,
			COALESCE(prd_cost, 0) Prd_Cost,
			CASE UPPER(TRIM(prd_line))
				WHEN 'R' THEN 'Road'
				WHEN 'M' THEN 'Mountain'
				WHEN 'S' THEN 'Other_sales'
				WHEN 'T' THEN 'Touring'
				ELSE 'N/a'
			END AS Prd_line,
			prd_start_dt,
			DATEADD(DAY, -1, LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt))
		FROM bronze.crm_prd_info
		SET @end_time = GETDATE()
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '-----------------';
---------------------------------------------------------------------------------------------------
---- SALES DETAILS CRM

		SET @start_time = GETDATE();
		PRINT '>> Truncating Table: silver.crm_sales_details';
		TRUNCATE TABLE silver.crm_sales_details;
		PRINT '>> Inserting Data Into: silver.crm_sales_details';

		INSERT INTO silver.crm_sales_details(
			sls_ord_num,
			sls_prd_key,
			sls_cust_id,
			sls_order_dt,
			sls_ship_dt,
			sls_due_dt,
			sls_sales,
			sls_quantity,
			sls_price
		)

		SELECT 
			sls_ord_num,
			sls_prd_key,
			sls_cust_id,
			CASE 
				WHEN sls_order_dt = 0 OR LEN(sls_order_dt) !=8 THEN NULL
				ELSE CAST(CAST( sls_order_dt AS VARCHAR ) AS DATE ) 
			END AS sls_order_dt,
			CASE 
				WHEN sls_ship_dt = 0 OR LEN(sls_ship_dt) !=8 THEN NULL
				ELSE CAST(CAST( sls_ship_dt AS VARCHAR ) AS DATE ) 
			END AS sls_ship_dt,
			CASE 
				WHEN sls_due_dt = 0 OR LEN(sls_due_dt) !=8 THEN NULL
				ELSE CAST(CAST( sls_due_dt AS VARCHAR ) AS DATE ) 
			END AS sls_due_dt,
			CASE 
				WHEN sls_sales IS NULL OR sls_sales <=0 OR sls_sales != ABS(sls_quantity * sls_price) 
				THEN ABS(sls_quantity * sls_price)
				ELSE sls_sales
			END AS sls_sales,
			sls_quantity,
			CASE 
				WHEN sls_price IS NULL OR sls_price <=0
				THEN (sls_sales/NULLIF(sls_quantity, 0))
				ELSE sls_price
			END AS sls_price
		FROM bronze.crm_sales_details
		SET @end_time = GETDATE()
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '-----------------';

		PRINT '-----------------------------------------------------';
		PRINT 'Loading ERP Tables';
		PRINT '-----------------------------------------------------';

---------------------------------------------------------------------------------------------------
---------- ERP CUST AZ12

		SET @start_time = GETDATE();
		PRINT '>> Truncating Table: silver.erp_cust_az12';
		TRUNCATE TABLE silver.erp_cust_az12;
		PRINT '>> Inserting Data Into: silver.erp_cust_az12';

		INSERT INTO silver.erp_cust_az12(
			cid,
			bdate,
			gen
		)

		SELECT 
			CASE 
				WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid))
				ELSE cid
			END cid,
			CASE 
				WHEN bdate > GETDATE() THEN NULL
				ELSE bdate
			END bdate,
			CASE
				WHEN UPPER(TRIM(gen)) IN ('M', 'MALE')  THEN 'Male'
				WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE')  THEN 'Female'
				ELSE 'N/a'
			END gen
		FROM bronze.erp_cust_az12
		SET @end_time = GETDATE()
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '-----------------';
---------------------------------------------------------------------------------------------------
-----------------------------ERP LOCATION-----------------------------

		SET @start_time = GETDATE();
		PRINT '>> Truncating Table: silver.erp_loc_a101';
		TRUNCATE TABLE silver.erp_loc_a101;
		PRINT '>> Inserting Data Into: silver.erp_loc_a101';

		INSERT INTO silver.erp_loc_a101(
			cid,
			cntry
		)
		SELECT 
			REPLACE(cid,'-','') cid,
			CASE 
				WHEN TRIM(cntry)= 'DE' THEN 'Germany'
				WHEN TRIM(cntry) IN ('US','USA') THEN 'United States'
				WHEN TRIM(cntry)= '' OR cntry IS NULL  THEN 'N/a'
				ELSE TRIM(cntry)
			END cntry
		FROM bronze.erp_loc_a101
		SET @end_time = GETDATE()
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '-----------------';
---------------------------------------------------------------------------------------------------
---------------------------------ERP CATEGORY ----------------------------------------------

		SET @start_time = GETDATE();
		PRINT '>> Truncating Table: silver.erp_px_cat_g1v2';
		TRUNCATE TABLE silver.erp_px_cat_g1v2;
		PRINT '>> Inserting Data Into: silver.erp_px_cat_g1v2';

		INSERT INTO silver.erp_px_cat_g1v2(
			id,
			cat,
			subcat,
			maintainance
		)
		SELECT 
			id,
			cat,
			subcat,
			maintainance
		FROM bronze.erp_px_cat_g1v2
		SET @end_time = GETDATE()
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '-----------------';

		SET @end_time = GETDATE(); -- [ whole layer calculation] 
		PRINT '=================================================================';
		PRINT '>> Loading Silver Layer is Completed'; 
		PRINT '>> Total Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '=================================================================';
	END TRY
	BEGIN CATCH
		PRINT '=================================================================';
		PRINT 'ERROR OCCURED DURING LOADING THE SILVER LAYER';
		PRINT 'ERROR MESSAGE' + ERROR_MESSAGE();
		PRINT 'ERROR NUMBER' + CAST(ERROR_NUMBER() AS NVARCHAR);
		PRINT 'ERROR STATE' + CAST(ERROR_STATE() AS NVARCHAR);
		PRINT '=================================================================';
	END CATCH
END
