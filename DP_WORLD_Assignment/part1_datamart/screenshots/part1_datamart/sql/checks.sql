SELECT * FROM [stg].[BatchLog];
SELECT * FROM [stg].[Shifts];

SELECT * FROM [stg].[Customers];

-- Row Count Reconciliation
SELECT 'Shifts' AS TableName, COUNT(*) AS TotalRows FROM [stg].[Shifts]
UNION ALL
SELECT 'Terminals', COUNT(*) FROM [stg].[Terminals]
UNION ALL
SELECT 'Equipment', COUNT(*) FROM [stg].[Equipment]
UNION ALL
SELECT 'Customers', COUNT(*) FROM [stg].[Customers]
UNION ALL
SELECT 'CustomerHistory', COUNT(*) FROM [stg].[CustomerHistory]
UNION ALL
SELECT 'VesselCalls', COUNT(*) FROM [stg].[VesselCalls]
UNION ALL
SELECT 'GateTransactions', COUNT(*) FROM [stg].[GateTransactions]
UNION ALL
SELECT 'ContainerMovements', COUNT(*) FROM [stg].[ContainerMovements];

-- Logging
SELECT 
    LogID, 
    PackageName, 
    StartTime, 
    EndTime, 
    DATEDIFF(SECOND, StartTime, EndTime) AS DurationInSeconds,
    [Status]
FROM [stg].[BatchLog]
ORDER BY StartTime DESC;


--Error Tracking
-- لو الجدول ده فاضي، يبقى إنتي شغلك 10/10
SELECT * FROM [stg].[ErrorLog];


-- Row Count Reconciliation 
SELECT 
    t.name AS TableName, 
    SUM(p.rows) AS TotalRows
FROM sys.tables t
INNER JOIN sys.partitions p ON t.object_id = p.object_id
INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE s.name = 'stg' 
  AND p.index_id < 2 -- 0 for heap, 1 for clustered index
GROUP BY t.name;



SELECT 'VesselCalls' AS TableName, VesselCallID, ArrivalDate, DepartureDate
FROM [stg].[VesselCalls]
WHERE DepartureDate < ArrivalDate; 

SELECT TOP 1000 movement_id, container_no, move_start_time, move_end_time
FROM [stg].[ContainerMovements]
-- بنحول النص لتاريخ عشان نعرف نقارن
WHERE TRY_CAST(move_end_time AS DATETIME) < TRY_CAST(move_start_time AS DATETIME);


--21 s
SELECT weight_tons 
FROM [stg].[ContainerMovements] TABLESAMPLE (10 PERCENT)
WHERE weight_tons LIKE '%[a-zA-Z]%';
-- هيعدي على 10% بس من الداتا، وده أخف بكتير على الرامات

-- 1.5 m
SELECT 
    COUNT(*) AS TotalRows,
    COUNT(TRY_CAST(weight_tons AS DECIMAL(18,2))) AS ValidRows,
    COUNT(*) - COUNT(TRY_CAST(weight_tons AS DECIMAL(18,2))) AS DirtyRows
FROM [stg].[ContainerMovements];



-- 17 s
SELECT COUNT(*) 
FROM [stg].[ContainerMovements] 
WHERE ISNUMERIC(weight_tons) = 0 
  AND weight_tons IS NOT NULL;
-- فحص لو فيه تاريخ مكتوب بصيغة غلط تماماً (مش بادئ برقم مثلاً)
SELECT move_start_time 
FROM [stg].[ContainerMovements]
WHERE move_start_time NOT LIKE '[0-9]%';


-- فحص شامل لكل مشاكل الداتا في الـ Staging
SELECT 'ContainerMovements' AS TableName, 'weight_tons' AS ColumnName, COUNT(*) AS DirtyRowsCount
FROM [stg].[ContainerMovements] WHERE ISNUMERIC(weight_tons) = 0 AND weight_tons IS NOT NULL

UNION ALL
SELECT 'ContainerMovements', 'move_start_time', COUNT(*)
FROM [stg].[ContainerMovements] WHERE ISDATE(move_start_time) = 0 AND move_start_time IS NOT NULL

UNION ALL
SELECT 'VesselCalls', 'ArrivalDate', COUNT(*)
FROM [stg].[VesselCalls] WHERE ISDATE(ArrivalDate) = 0 AND ArrivalDate IS NOT NULL

UNION ALL
SELECT 'VesselCalls', 'DepartureDate', COUNT(*)
FROM [stg].[VesselCalls] WHERE ISDATE(DepartureDate) = 0 AND DepartureDate IS NOT NULL

UNION ALL
-- فحص الـ Logic (وقت النهاية قبل البداية)
SELECT 'ContainerMovements', 'Logic: End < Start', COUNT(*)
FROM [stg].[ContainerMovements] 
WHERE TRY_CAST(move_end_time AS DATETIME) < TRY_CAST(move_start_time AS DATETIME);


***********************************************************
--VesselCalls
-- 1. فحص هل التواريخ (ETA, ATA, ATD) مكتوبة بصيغة صحيحة؟
SELECT 'VesselCalls' AS Table1, 'ETA (Expected Arrival)' AS Column1, COUNT(*) AS DirtyRows 
FROM [stg].[VesselCalls] WHERE ISDATE(eta) = 0 AND eta IS NOT NULL

UNION ALL
SELECT 'VesselCalls', 'ATA (Actual Arrival)', COUNT(*) 
FROM [stg].[VesselCalls] WHERE ISDATE(ata) = 0 AND ata IS NOT NULL

UNION ALL
SELECT 'VesselCalls', 'ATD (Actual Departure)', COUNT(*) 
FROM [stg].[VesselCalls] WHERE ISDATE(atd) = 0 AND atd IS NOT NULL

UNION ALL
-- 2. فحص هل أعداد الحركات (Moves) فيها حروف أو قيم غلط؟
SELECT 'VesselCalls', 'Total Moves Planned', COUNT(*) 
FROM [stg].[VesselCalls] WHERE ISNUMERIC(total_moves_planned) = 0 AND total_moves_planned IS NOT NULL

UNION ALL
-- 3. فحص الـ Logic: هل وقت الرحيل (ATD) قبل وقت الوصول (ATA)؟
SELECT 'VesselCalls', 'Logic: ATD < ATA', COUNT(*) 
FROM [stg].[VesselCalls] 
WHERE TRY_CAST(atd AS DATETIME) < TRY_CAST(ata AS DATETIME);

***************************

-- 1. فحص جدول العملاء (Customers)
SELECT 'Customers' AS [Table], 'customer_name' AS [Column], COUNT(*) AS [Issues]
FROM [stg].[Customers] WHERE customer_name IS NULL 
OR TRIM(customer_name)  = '' 
OR customer_name <> trim(customer_name)

UNION ALL
-- 3. فحص جدول المحطات (Terminals)
SELECT 'Terminals', 'terminal_name', COUNT(*)
FROM [stg].[Terminals] 
WHERE terminal_name IS NULL 
OR TRIM(terminal_name) = '' 
OR terminal_name <> TRIM(terminal_name);

UNION ALL
-- 4. فحص جدول المعدات (Equipment)
SELECT 'Equipment', 'capacity_tons', COUNT(*)
FROM [stg].[Equipment] WHERE ISNUMERIC(capacity_tons) = 0 AND capacity_tons IS NOT NULL

UNION ALL
-- 5. فحص جدول الشفتات (Shifts)
SELECT 'Shifts', 'shift_name', COUNT(*)
FROM [stg].[Shifts] WHERE shift_name IS NULL 
OR TRIM(shift_name) = '' 
OR shift_name <> TRIM(shift_name)

--GateTransactions
-- 1. فحص التواريخ (Gate In & Gate Out)
SELECT 'GateTransactions' AS [Table], 'gate_in_time' AS [Column], COUNT(*) AS [Issues]
FROM [stg].[GateTransactions] WHERE ISDATE(gate_in_time) = 0 AND gate_in_time IS NOT NULL

UNION ALL
SELECT 'GateTransactions', 'gate_out_time', COUNT(*)
FROM [stg].[GateTransactions] WHERE ISDATE(gate_out_time) = 0 AND gate_out_time IS NOT NULL

UNION ALL
-- 2. فحص المنطق: هل خرجت قبل ما تدخل؟
--35 s
SELECT 'GateTransactions', 'Logic: Out < In', COUNT(*)
FROM [stg].[GateTransactions] 
WHERE TRY_CAST(gate_out_time AS DATETIME) < TRY_CAST(gate_in_time AS DATETIME)

UNION ALL
-- 3. فحص البيانات المفقودة في أعمدة الربط الأساسية
SELECT 'GateTransactions', 'Missing Container/Plate', COUNT(*)
FROM [stg].[GateTransactions] 
WHERE container_no IS NULL OR truck_plate IS NULL;


--Outliers
SELECT MIN(TRY_CAST(weight_tons AS DECIMAL(18,2))) AS MinWeight,
       MAX(TRY_CAST(weight_tons AS DECIMAL(18,2))) AS MaxWeight
FROM [stg].[ContainerMovements];

-- Orphan_Movements
SELECT COUNT(*) AS Orphan_Movements
FROM [stg].[ContainerMovements] cm
LEFT JOIN [stg].[VesselCalls] vc ON cm.vessel_call_id = vc.vessel_call_id
WHERE vc.vessel_call_id IS NULL -- يعني ملهاش بيانات في جدول السفن
  AND cm.vessel_call_id IS NOT NULL; -- وبنستبعد الصفوف اللي هي أصلاً NULL

-- Customer Check
SELECT COUNT(*) AS Orphan_Customers
FROM [stg].[ContainerMovements] cm
LEFT JOIN [stg].[Customers] c ON cm.customer_id = c.customer_id
WHERE c.customer_id IS NULL AND cm.customer_id IS NOT NULL;


-- Equipment Check
SELECT COUNT(*) AS Orphan_Equipment
FROM [stg].[ContainerMovements] cm
LEFT JOIN [stg].[Equipment] e ON cm.equipment_id = e.equipment_id
WHERE e.equipment_id IS NULL AND cm.equipment_id IS NOT NULL;

--Gate-Customer Check
SELECT COUNT(*) AS Orphan_Gate_Customers
FROM [stg].[GateTransactions] gt
LEFT JOIN [stg].[Customers] c ON gt.customer_id = c.customer_id
WHERE c.customer_id IS NULL AND gt.customer_id IS NOT NULL;



SELECT voyage_no, COUNT(*) as RepeatedTimes
FROM [stg].[VesselCalls]
WHERE voyage_no IS NOT NULL
GROUP BY voyage_no
HAVING COUNT(*) > 1;


SELECT 'VesselCalls' AS [Table], 'voyage_no (Uniqueness)' AS [Column], COUNT(*) AS [Issues]
FROM (
    SELECT voyage_no
    FROM [stg].[VesselCalls]
    WHERE voyage_no IS NOT NULL
    GROUP BY voyage_no
    HAVING COUNT(*) > 1
) AS DuplicateRecords;



SELECT * FROM [stg].[VesselCalls]
WHERE voyage_no IN (
    SELECT voyage_no 
    FROM [stg].[VesselCalls] 
    GROUP BY voyage_no 
    HAVING COUNT(*) > 1
)
ORDER BY voyage_no;



SELECT vessel_name, voyage_no, terminal_id, ata, atd, status, COUNT(*)
FROM [stg].[VesselCalls]
GROUP BY vessel_name, voyage_no, terminal_id, ata, atd, status
HAVING COUNT(*) > 1;



-- COUNT(container_size,Reefer_Status)
SELECT 
    container_no, 
    COUNT(DISTINCT container_size) AS Size_Variations, 
    COUNT(DISTINCT is_reefer) AS Reefer_Status_Variations
FROM [stg].[ContainerMovements] -- أو الجدول اللي فيه بيانات الحاويات
WHERE container_no IS NOT NULL
GROUP BY container_no
HAVING COUNT(DISTINCT container_size) > 1 
   OR COUNT(DISTINCT is_reefer) > 1;

***************************************

-- count(container_no_size)

WITH InconsistentContainers AS (
    -- 1. بنحدد الأول أرقام الحاويات اللي ليها أكتر من مقاس
    SELECT container_no
    FROM [stg].[ContainerMovements]
    GROUP BY container_no
    HAVING COUNT(DISTINCT container_size) > 1
)
-- 2. بنعرض تفاصيل الحاويات دي بس من الجدول الأصلي
SELECT 
    cm.container_no, 
    cm.container_size, 
    COUNT(*) AS HowManyTimes -- المقاس ده ظهر كام مرة للحاوية دي
FROM [stg].[ContainerMovements] cm
INNER JOIN InconsistentContainers ic ON cm.container_no = ic.container_no
GROUP BY cm.container_no, cm.container_size
ORDER BY cm.container_no, HowManyTimes DESC;




---------------------------------------------------------
-- find the overall Date Range across ALL source tables
---------------------------------------------------------

SELECT source_table, MIN(AllDates) AS Min_Date, MAX(AllDates) AS Max_Date, COUNT(*) AS date_count
FROM (
    SELECT 'ContainerMovements_start' AS source_table, 
           CAST(move_start_time AS DATE) AS AllDates 
    FROM stg.ContainerMovements WHERE move_start_time IS NOT NULL
    
    UNION ALL
    SELECT 'ContainerMovements_end', 
           CAST(move_end_time AS DATE) 
    FROM stg.ContainerMovements WHERE move_end_time IS NOT NULL
    
    UNION ALL
    SELECT 'VesselCalls_eta',  CAST(eta AS DATE) FROM stg.VesselCalls WHERE eta IS NOT NULL
    UNION ALL
    SELECT 'VesselCalls_ata',  CAST(ata AS DATE) FROM stg.VesselCalls WHERE ata IS NOT NULL
    UNION ALL
    SELECT 'VesselCalls_atd',  CAST(atd AS DATE) FROM stg.VesselCalls WHERE atd IS NOT NULL
    
    UNION ALL
    SELECT 'GateTransactions_in',  CAST(gate_in_time  AS DATE) FROM stg.GateTransactions WHERE gate_in_time  IS NOT NULL
    UNION ALL
    SELECT 'GateTransactions_out', CAST(gate_out_time AS DATE) FROM stg.GateTransactions WHERE gate_out_time IS NOT NULL
    
    UNION ALL
    SELECT 'Customers_onboarded', CAST(onboarded_date AS DATE) FROM stg.Customers WHERE onboarded_date IS NOT NULL
    
    UNION ALL
    SELECT 'CustomerHistory_from', CAST(effective_from AS DATE) FROM stg.CustomerHistory WHERE effective_from IS NOT NULL
    UNION ALL
    SELECT 'CustomerHistory_to',   CAST(effective_to   AS DATE) FROM stg.CustomerHistory 
    WHERE effective_to IS NOT NULL AND effective_to < '9000-01-01'
    
    UNION ALL
    SELECT 'Equipment_acquired', CAST(acquired_date AS DATE) FROM stg.Equipment WHERE acquired_date IS NOT NULL

) AS CombinedDates
GROUP BY source_table
ORDER BY Min_Date;