/*

Data Cleaning Project for Laptop Sales

*/

-- Created duplicate staging table
CREATE TABLE laptop_staging
LIKE laptop_data;

INSERT laptop_staging
SELECT *
FROM laptop_data;

-- ------------------------------------------------------------------------------------------------
-- Renamed unnamed column to Id for readability

ALTER TABLE laptop_staging
RENAME COLUMN `Unnamed: 0` to `Id`;

-- ------------------------------------------------------------------------------------------------
-- Duplicates
-- ------------------------------------------------------------------------------------------------

-- Check for duplicates
WITH duplicate_cte AS
(SELECT *,
ROW_NUMBER() OVER(
PARTITION BY Company, TypeName, Inches,ScreenResolution, `Cpu`, Ram, `Memory`, Gpu, OpSys,Weight,Price 
ORDER BY Id
) AS row_num
FROM laptop_staging
)

SELECT *
FROM duplicate_cte
WHERE row_num > 1 
;

-- Delete duplicates 
WITH duplicate_cte AS
(SELECT id,
ROW_NUMBER() OVER(
PARTITION BY Company, TypeName, Inches,ScreenResolution, `Cpu`, Ram, `Memory`, Gpu, OpSys,Weight,Price 
ORDER BY Id
) AS row_num
FROM laptop_staging
)

DELETE FROM laptop_staging
WHERE Id IN (SELECT Id FROM duplicate_cte WHERE row_num >1);

-- ------------------------------------------------------------------------------------------------
-- Splitting Columns to improve efficiency
-- ------------------------------------------------------------------------------------------------

/* Different information available in the same column like display type, resolution and touch screen capabilities.
 Not all of the data contains display type, so we will keep the ScreenResolution column to not remove any important information
 We will split ScreenResolution to (Resolution, TouchScreen) */

-- Splitting to Resolution 
SELECT ScreenResolution, REGEXP_SUBSTR(screenResolution, '[0-9]+ *x *[0-9]+')
FROM laptop_staging;

ALTER TABLE laptop_staging
ADD COLUMN Resolution text;

UPDATE laptop_staging
SET Resolution =  REGEXP_SUBSTR(screenResolution, '[0-9]+ *x *[0-9]+');

-- Splitting to Touchscreen
ALTER TABLE laptop_staging
ADD COLUMN isTouchscreen ENUM('Yes','No') NOT NULL;

UPDATE laptop_staging
SET isTouchScreen = 
	CASE
		WHEN  ScreenResolution LIKE '%Touchscreen%' THEN 'Yes'
        ELSE 'No'
	END;


/* Memory column contains data like '128GB SSD +  1TB HDD', we will split them into two separate columns Primary and Secondary Drives. 
   Secondary Drive will show 'none' if the laptop does not have a secondary drive
 */

-- Split Memory into Primary and Secondary Drives
ALTER TABLE laptop_staging
ADD COLUMN (PrimaryDrive text,SecondaryDrive text);

-- Primary Drive
UPDATE laptop_staging
SET PrimaryDrive = 
	CASE 
		WHEN `Memory` LIKE '%+%' THEN SUBSTRING_INDEX(`Memory` ,'+', 1)
        ELSE `Memory`
	END;

-- Secondary Drive
UPDATE laptop_staging
SET SecondaryDrive = 
	CASE 
		WHEN `Memory` LIKE '%+%' THEN TRIM(SUBSTRING_INDEX(`Memory` ,'+', -1))
        ELSE "None"
	END;

-- ------------------------------------------------------------------------------------------------
-- Standardizing Data
-- ------------------------------------------------------------------------------------------------

-- Standardizing data for Cpu column
SELECT DISTINCT(`cpu`)
FROM laptop_staging
ORDER BY 1;

UPDATE laptop_staging
SET `cpu` = 'Intel Core i5 7200U 2.7GHz'
WHERE `cpu` = 'Intel Core i5 7200U 2.70GHz';

UPDATE laptop_staging
SET `cpu` = 'Intel Core i5 7200U 2.5GHz'
WHERE `cpu` = 'Intel Core i5 7200U 2.50GHz';

UPDATE laptop_staging
SET `cpu` = 'Intel Celeron Dual Core N3060 1.6GHz'
WHERE `cpu` = 'Intel Celeron Dual Core N3060 1.60GHz';

UPDATE laptop_staging
SET `cpu` = 'Intel Core i3 6006U 2.0GHz'
WHERE `cpu` = 'Intel Core i3 6006U 2GHz';

UPDATE laptop_staging
SET `cpu` = 'Intel Celeron Dual Core N3350 2GHz'
WHERE `cpu` = 'Intel Celeron Dual Core N3350 2.0GHz';

UPDATE laptop_staging
SET `cpu` = 'Intel Core i7 6500U 2.5GHz'
WHERE `cpu` = 'Intel Core i7 6500U 2.50GHz';

-- Standardizing data for GPU
SELECT DISTINCT(Gpu)
FROM laptop_staging
ORDER BY 1;

UPDATE laptop_staging
SET Gpu = TRIM(Gpu);

UPDATE laptop_staging
SET Gpu = 'Nvidia GeForce GTX 1050Ti'
WHERE Gpu IN('Nvidia GeForce GTX 1050 Ti','Nvidia GeForce GTX1050 Ti');


-- ------------------------------------------------------------------------------------------------
-- Identify outliers and anomalies
-- ------------------------------------------------------------------------------------------------


SELECT DISTINCT(Weight)
FROM laptop_Staging
ORDER BY 1;

SELECT Id,Weight
From laptop_staging
where Weight IN ('?','0.0002kg');
-- returns Id 208 and Id 349, to verify the weight from proper sources before updating

SELECT Id,Gpu 
FROM laptop_staging
WHERE Gpu = 'Nvidia GeForce GTX 960<U+039C>';
-- returns ID 611 and 1218, to verify version of GPU before updating



-- ------------------------------------------------------------------------------------------------
-- Data Type Conversion
-- ------------------------------------------------------------------------------------------------

-- Change data type to numberic type float for Weight 

UPDATE laptop_staging
SET weight = REPLACE(weight,'kg','');

UPDATE laptop_staging
SET weight = null
WHERE weight = '?';

ALTER TABLE laptop_staging
MODIFY COLUMN Weight FLOAT;

ALTER TABLE laptop_staging
RENAME COLUMN Weight TO `Weight(kg)`;

-- Update Price format for consistency
UPDATE laptop_staging
SET Price = CAST(Round(Price,2) AS DECIMAL(10,2));

