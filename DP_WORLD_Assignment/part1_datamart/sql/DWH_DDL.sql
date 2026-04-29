-- 1. Dim_Shifts
---------------------------------------------------------
IF OBJECT_ID('mart.Dim_Shifts', 'U') IS NOT NULL
    DROP TABLE mart.Dim_Shifts;
GO

CREATE TABLE mart.Dim_Shifts (
    shifts_SK INT IDENTITY(1,1) PRIMARY KEY, -- Surrogate Key
    shift_id INT,                            -- Business Key from source
    shift_name NVARCHAR(50),                 -- Morning, Afternoon, Night
    shift_code NVARCHAR(10),
    start_time TIME,                         
    end_time TIME                            
);
GO

-- 2. Dim_Container
---------------------------------------------------------
IF OBJECT_ID('mart.Dim_Container', 'U') IS NOT NULL
    DROP TABLE mart.Dim_Container;
GO

CREATE TABLE mart.Dim_Container (
    Container_SK INT IDENTITY(1,1) PRIMARY KEY, -- Unique SK for each size/reefer combination
    container_no NVARCHAR(50) NOT NULL,         -- Physical ID
    container_size INT,                         -- 20, 40, 45
    is_reefer BIT,                              -- 1 for Reefer, 0 for Dry
    container_type_desc NVARCHAR(20)            -- HC, Standard, etc.
);
GO

-- 3. Dim_Vessel
---------------------------------------------------------
IF OBJECT_ID('mart.Dim_Vessel', 'U') IS NOT NULL
    DROP TABLE mart.Dim_Vessel;
GO

CREATE TABLE mart.Dim_Vessel (
    Vessel_SK INT IDENTITY(1,1) PRIMARY KEY, 
    vessel_name NVARCHAR(255),               
);
GO


-- 4. Dim_Equipment
---------------------------------------------------------
IF OBJECT_ID('mart.Dim_Equipment', 'U') IS NOT NULL
    DROP TABLE mart.Dim_Equipment;
GO

CREATE TABLE mart.Dim_Equipment (
    equipment_SK INT IDENTITY(1,1) PRIMARY KEY, -- Surrogate Key
    equipment_id INT,                  -- Business Key
    equipment_code NVARCHAR(50),
    equipment_type NVARCHAR(100),               -- e.g., STS Crane, RTG
    terminal_SK INT,                            -- Foreign Key to Dim_Terminal
    acquired_date_id INT,                       -- Foreign Key to Dim_Date
    [status] NVARCHAR(50),                        -- e.g., Active, Maintenance
    capacity_tons DECIMAL(18,2)
);
GO

---------------------------------------------------------
-- 5. Dim_Terminal
---------------------------------------------------------
IF OBJECT_ID('mart.Dim_Terminal', 'U') IS NOT NULL
    DROP TABLE mart.Dim_Terminal;
GO

CREATE TABLE mart.Dim_Terminal (
    terminal_SK INT IDENTITY(1,1) PRIMARY KEY, -- Surrogate Key
    terminal_id INT,                            -- Business Key
    terminal_code NVARCHAR(20),                 -- Terminal Short Code
    terminal_name NVARCHAR(255),                -- Full Terminal Name
    [zone] NVARCHAR(50),                          
    terminal_type NVARCHAR(50)    );              
GO

---------------------------------------------------------
-- 6. Dim_move_type
---------------------------------------------------------
IF OBJECT_ID('mart.Dim_move_type', 'U') IS NOT NULL
    DROP TABLE mart.Dim_Move_Type;
GO

CREATE TABLE mart.Dim_move_type (
    move_type_SK INT IDENTITY(1,1) PRIMARY KEY, -- Surrogate Key
    move_type_name NVARCHAR(50)                 -- e.g., Loading, Discharging, Shifting
);
GO

---------------------------------------------------------
-- 7. Dim_Status
---------------------------------------------------------
IF OBJECT_ID('mart.Dim_Vessel_Status', 'U') IS NOT NULL
    DROP TABLE mart.Dim_Vessel_Status;
GO

CREATE TABLE mart.Dim_Vessel_Status (
    status_SK INT IDENTITY(1,1) PRIMARY KEY, -- Surrogate Key
    status_name NVARCHAR(50)                 -- e.g., Arrived, Completed, Cancelled
);
GO

---------------------------------------------------------
-- 8. Dim_Direction
---------------------------------------------------------
IF OBJECT_ID('mart.Dim_Direction', 'U') IS NOT NULL
    DROP TABLE mart.Dim_Direction;
GO

CREATE TABLE mart.Dim_Direction (
    direction_SK INT IDENTITY(1,1) PRIMARY KEY, -- Surrogate Key
    direction_name NVARCHAR(20)                 -- e.g., Inbound, Outbound
);
GO

---------------------------------------------------------
-- Dim_Customer (SCD Type 2 Implementation)
---------------------------------------------------------
IF OBJECT_ID('mart.Dim_Customer', 'U') IS NOT NULL
    DROP TABLE mart.Dim_Customer;
GO

CREATE TABLE mart.Dim_Customer (
    customer_SK INT IDENTITY(1,1) PRIMARY KEY, -- Surrogate Key
    customer_id INT NOT NULL,                  -- Business Key (from source)
    customer_code NVARCHAR(50),
    customer_name NVARCHAR(255),
    country NVARCHAR(100),
    customer_tier NVARCHAR(50),
    credit_limit DECIMAL(18,2),
    active_flag BIT,
    onboarded_date_SK INT,                     -- FK to Dim_Date (YYYYMMDD)
    
    -- SCD Type 2 Tracking Columns
    effective_from_id INT,                     -- Valid From (Date_SK)
    effective_to_id INT,                       -- Valid To (Date_SK, 99991231 for current)
    is_current BIT DEFAULT 1,                  -- 1 for latest record, 0 for history
    change_reason NVARCHAR(255)
);
GO
-- 9. Dim_Date
-- 10. Dim_Time 
-- IN File  Dim_Date_Time.sql

---------------------------------------------------------

-- Facts 

-- ============================================================
-- FACT_VESSEL_CALLS — DDL
-- Grain: One row per vessel call
-- Schema: mart
-- ============================================================

DROP TABLE IF EXISTS mart.Fact_Vessel_Calls;

CREATE TABLE mart.Fact_Vessel_Calls (

    -- ── Surrogate Key ────────────────────────────────────────
    Vessel_Calls_SK         BIGINT          IDENTITY(1,1)   NOT NULL,

    -- ── Business Key (Degenerate) ────────────────────────────
    vessel_call_id          NVARCHAR(50)    NOT NULL,   -- BK من الـ source
    voyage_no               NVARCHAR(50)    NULL,       -- DE — 

    -- ── Dimension FKs ───────────────────────────────────────
    vessel_name_SK          INT             NOT NULL    DEFAULT -1,
    customer_SK             INT             NOT NULL    DEFAULT -1,
    terminal_SK             INT             NOT NULL    DEFAULT -1,
    status_SK               INT             NOT NULL    DEFAULT -1,

    -- ETA
    eta_date_SK             INT             NOT NULL    DEFAULT -1,
    eta_time_SK             INT             NOT NULL    DEFAULT -1,

    -- ATA
    ata_date_SK             INT             NOT NULL    DEFAULT -1,
    ata_time_SK             INT             NOT NULL    DEFAULT -1,

    -- ATD
    atd_date_SK             INT             NOT NULL    DEFAULT -1,
    atd_time_SK             INT             NOT NULL    DEFAULT -1,

    -- ── Measures ─────────────────────────────────────────────
    total_moves_planned     INT             NULL,
    total_moves_actual      INT             NULL,
    moves_variance          INT             NULL,       -- SSIS: actual - planned
    berth_delay_hours       DECIMAL(10,2)   NULL,       -- SSIS: ata - eta (hours)
    stay_hours              DECIMAL(10,2)   NULL,       -- SSIS: atd - ata (hours)

    -- ── Audit ────────────────────────────────────────────────
    dw_created_at           DATETIME        NOT NULL    DEFAULT GETDATE(),
    dw_updated_at           DATETIME        NOT NULL    DEFAULT GETDATE(),

    CONSTRAINT PK_Fact_Vessel_Calls PRIMARY KEY (Vessel_Calls_SK)
);

-- ── Indexes for join performance ─────────────────────────────
CREATE NONCLUSTERED INDEX IX_FVC_vessel_name_SK  ON mart.Fact_Vessel_Calls (vessel_name_SK);
CREATE NONCLUSTERED INDEX IX_FVC_customer_SK     ON mart.Fact_Vessel_Calls (customer_SK);
CREATE NONCLUSTERED INDEX IX_FVC_terminal_SK     ON mart.Fact_Vessel_Calls (terminal_SK);
CREATE NONCLUSTERED INDEX IX_FVC_eta_date_SK     ON mart.Fact_Vessel_Calls (eta_date_SK);
CREATE NONCLUSTERED INDEX IX_FVC_ata_date_SK     ON mart.Fact_Vessel_Calls (ata_date_SK);
CREATE NONCLUSTERED INDEX IX_FVC_atd_date_SK     ON mart.Fact_Vessel_Calls (atd_date_SK);
CREATE NONCLUSTERED INDEX IX_FVC_vessel_call_id  ON mart.Fact_Vessel_Calls (vessel_call_id);



---------------------------------------------------------
-- Fact_Container_Movements
-- Grain: One row per container move (Discharge/Load/Shift)
---------------------------------------------------------
IF OBJECT_ID('mart.Fact_Container_Movements', 'U') IS NOT NULL
    DROP TABLE mart.Fact_Container_Movements;
GO

CREATE TABLE mart.Fact_Container_Movements (
    -- 1. Primary Key (Fact Surrogate Key)
    movement_SK BIGINT IDENTITY(1,1) PRIMARY KEY,

    -- 2. Business Key (Degenerate Dimension)
    movement_id INT NOT NULL,
    vessel_call_id INT NOT NULL ,

    -- 3. Dimension Foreign Keys (Linking to SKs)
    container_SK   INT NOT NULL DEFAULT -1,
    equipment_SK   INT NOT NULL DEFAULT -1,
    move_type_SK   INT NOT NULL DEFAULT -1,
    shift_SK       INT NOT NULL DEFAULT -1,
    customer_SK    INT NOT NULL DEFAULT -1,
    terminal_SK    INT NOT NULL DEFAULT -1,

    -- 4. Date & Time SKs (Role Playing Dimensions)
    move_start_date_SK INT NOT NULL DEFAULT -1,
    move_start_time_SK INT NOT NULL DEFAULT -1,
    move_end_date_SK   INT NOT NULL DEFAULT -1,
    move_end_time_SK   INT NOT NULL DEFAULT -1,

    -- 5. Measures (Numeric values for analysis)
    weight_tons              DECIMAL(10,2) NULL,
    crane_cycle_time_seconds INT           NULL, -- SSIS: move_end_time - move_start_time

    -- 6. Audit Columns
    dw_created_at DATETIME NOT NULL DEFAULT GETDATE(),
    dw_updated_at DATETIME NOT NULL DEFAULT GETDATE()
);
GO

---------------------------------------------------------
-- Indexes for High-Performance Reporting
---------------------------------------------------------
CREATE NONCLUSTERED INDEX IX_FactMove_VesselCall ON mart.Fact_Container_Movements (vessel_call_id);
CREATE NONCLUSTERED INDEX IX_FactMove_Container  ON mart.Fact_Container_Movements (container_SK);
CREATE NONCLUSTERED INDEX IX_FactMove_StartDate  ON mart.Fact_Container_Movements (move_start_date_SK);
CREATE NONCLUSTERED INDEX IX_FactMove_Customer   ON mart.Fact_Container_Movements (customer_SK);
GO


---------------------------------------------------------
-- Fact_Gate_Transactions
-- Grain: One row per truck gate transaction (In/Out)
---------------------------------------------------------
IF OBJECT_ID('mart.Fact_Gate_Transactions', 'U') IS NOT NULL
    DROP TABLE mart.Fact_Gate_Transactions;
GO

CREATE TABLE mart.Fact_Gate_Transactions (
    -- 1. Primary Key (Fact Surrogate Key)
    Gate_Transactions_SK BIGINT IDENTITY(1,1) PRIMARY KEY,

    -- 2. Business Key & Degenerate Dimensions
    gate_txn_id    INT NOT NULL,          -- BK from source
    truck_plate    NVARCHAR(50),          -- Degenerate Dimension
    container_no   NVARCHAR(50),          -- Degenerate Dimension

    -- 3. Dimension Foreign Keys
    customer_SK    INT NOT NULL DEFAULT -1,
    terminal_SK    INT NOT NULL DEFAULT -1,
    direction_SK   INT NOT NULL DEFAULT -1,
    shift_SK       INT NOT NULL DEFAULT -1,

    -- 4. Date & Time SKs (Gate In) - Active Relationship
    gate_in_date_SK INT NOT NULL DEFAULT -1,
    gate_in_time_SK INT NOT NULL DEFAULT -1,

    -- 5. Date & Time SKs (Gate Out) - Inactive Relationship (for Power BI)
    gate_out_date_SK INT NOT NULL DEFAULT -1,
    gate_out_time_SK INT NOT NULL DEFAULT -1,

    -- 6. Measures
    -- SSIS Calculation: DATEDIFF(minute, gate_in_time, gate_out_time)
    -- turnaround_time_minutes INT NULL,

    -- 7. Audit Columns
    dw_created_at DATETIME NOT NULL DEFAULT GETDATE(),
    dw_updated_at DATETIME NOT NULL DEFAULT GETDATE()
);
GO

---------------------------------------------------------
-- Indexes for Performance
---------------------------------------------------------
CREATE NONCLUSTERED INDEX IX_Gate_Customer ON mart.Fact_Gate_Transactions (customer_SK);
CREATE NONCLUSTERED INDEX IX_Gate_InDate   ON mart.Fact_Gate_Transactions (gate_in_date_SK);
CREATE NONCLUSTERED INDEX IX_Gate_OutDate  ON mart.Fact_Gate_Transactions (gate_out_date_SK);
CREATE NONCLUSTERED INDEX IX_Gate_Terminal ON mart.Fact_Gate_Transactions (terminal_SK);
GO




IF OBJECT_ID('mart.BatchLog', 'U') IS NOT NULL
    DROP TABLE mart.BatchLog;
GO

CREATE TABLE mart.BatchLog (
    LogID        INT IDENTITY(1,1) PRIMARY KEY,
    PackageName  NVARCHAR(255) NOT NULL, -- اسم البكدج (مثلاً Dim_Shifts.dtsx)
    TableName    NVARCHAR(255) NOT NULL, -- اسم جدول الوجهة (mart.Dim_Shifts)
    StartTime    DATETIME NOT NULL DEFAULT GETDATE(),
    EndTime      DATETIME NULL,
    Status       NVARCHAR(50) DEFAULT 'Running', -- الحالة: Running, Success, Failure
    RowsRead     INT DEFAULT 0, -- عدد السطور المسحوبة من المصدر
    RowsWritten  INT DEFAULT 0, -- عدد السطور اللي دخلت المارت فعلاً
    RowsError    INT DEFAULT 0  -- عدد السطور اللي راحت لجدول الـ Error
);
GO


IF OBJECT_ID('mart.ErrorLog', 'U') IS NOT NULL
    DROP TABLE mart.ErrorLog;
GO

CREATE TABLE mart.ErrorLog (
    ErrorID          INT IDENTITY(1,1) PRIMARY KEY,
    PackageName      NVARCHAR(255) NOT NULL,
    TableName        NVARCHAR(255) NOT NULL,
    ErrorCode        NVARCHAR(50) NULL,  -- كود الخطأ اللي بيطلعه الـ SSIS
    ErrorColumnID    INT NULL,           -- رقم العمود اللي فيه المشكلة
    FlatRowData      NVARCHAR(MAX) NULL, -- السطر بالكامل كـ Text (عشان نعرف الداتا اللي باظت)
    ErrorDescription NVARCHAR(MAX) NULL, -- وصف الخطأ
    ErrorDate        DATETIME DEFAULT GETDATE()
);
GO