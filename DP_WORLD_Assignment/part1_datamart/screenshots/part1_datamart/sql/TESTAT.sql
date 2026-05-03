SELECT TOP (1000) [time_SK]
      ,[full_time]
      ,[hour_24]
      ,[hour_12]
      ,[minute]
      ,[am_pm]
      ,[time_label]
      ,[hour_bucket]
      ,[is_peak_hour]
  FROM [DPWorld_DataMart].[mart].[Dim_Time]



 SELECT TOP 10 
    atd,
    (YEAR(atd) * 10000 + MONTH(atd) * 100 + DAY(atd)) as atd_date_key,
    (DATEPART(HH, atd) * 60 + DATEPART(MI, atd)) as atd_time_key
FROM stg.VesselCalls
WHERE atd IS NOT NULL



SELECT COUNT(*) as missing_time_keys
FROM stg.VesselCalls v
WHERE v.atd IS NOT NULL
AND (DATEPART(HH, v.atd) * 60 + DATEPART(MI, v.atd)) 
    NOT IN (SELECT time_SK FROM mart.Dim_Time)


    SELECT MAX(time_SK), MIN(time_SK), COUNT(*) 
FROM mart.Dim_Time

SELECT COUNT(*) FROM mart.Dim_Time



SELECT DISTINCT 
    LTRIM(RTRIM(CAST(container_no AS NVARCHAR(50)))) AS container_no,
    ISNULL(TRY_CAST(container_size AS NVARCHAR(50)), 0) AS container_size,
    ISNULL(TRY_CAST(is_reefer AS INT), 0) AS is_reefer,
    LTRIM(RTRIM(CAST(move_type AS NVARCHAR(20)))) AS container_type_desc
FROM stg.ContainerMovements 
WHERE container_no IS NOT NULL;




-- تشيك سريع على وجود الـ -1 في الجداول الأساسية
SELECT 'Dim_Date' AS TableName, COUNT(*) AS Found FROM mart.Dim_Date WHERE Date_SK = -1
UNION ALL
SELECT 'Dim_Time' AS TableName, COUNT(*) AS Found FROM mart.Dim_Time WHERE Time_SK = -1
UNION ALL
SELECT 'Dim_Terminal' AS TableName, COUNT(*) AS Found FROM mart.Dim_Terminal WHERE terminal_SK = -1
UNION ALL
SELECT 'Dim_Customer' AS TableName, COUNT(*) AS Found FROM mart.Dim_Customer WHERE customer_SK = -1




SET IDENTITY_INSERT mart.Dim_Customer ON; 

INSERT INTO mart.Dim_Customer (customer_SK, customer_id) -- زودي أي أعمدة NOT NULL تانية
VALUES (-1, 0);

SET IDENTITY_INSERT mart.Dim_Customer OFF;