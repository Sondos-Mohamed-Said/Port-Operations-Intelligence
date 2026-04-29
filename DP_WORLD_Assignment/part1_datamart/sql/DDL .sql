CREATE DATABASE DPWorld_DataMart;
GO
USE DPWorld_DataMart;
GO
CREATE SCHEMA stg;
GO
CREATE SCHEMA mart;
GO

-- VesselCalls
IF OBJECT_ID('stg.VesselCalls', 'U') IS NOT NULL
    DROP TABLE stg.VesselCalls;
GO

CREATE TABLE stg.VesselCalls (
    vessel_call_id NVARCHAR(255),
    vessel_name NVARCHAR(255),
    voyage_no NVARCHAR(255),
    customer_id NVARCHAR(255),
    terminal_id NVARCHAR(255),
    eta NVARCHAR(255),
    ata NVARCHAR(255),
    atd NVARCHAR(255),
    total_moves_planned NVARCHAR(255),
    total_moves_actual NVARCHAR(255),
    [status] NVARCHAR(255)
);


-- ContainerMovements
IF OBJECT_ID('stg.ContainerMovements', 'U') IS NOT NULL
    DROP TABLE stg.ContainerMovements;
GO

CREATE TABLE stg.ContainerMovements (
    movement_id      NVARCHAR(255),
    vessel_call_id   NVARCHAR(255),
    container_no     NVARCHAR(255),
    container_size   NVARCHAR(255),
    move_type        NVARCHAR(255),
    equipment_id     NVARCHAR(255),
    shift_id         NVARCHAR(255),
    customer_id      NVARCHAR(255),
    terminal_id      NVARCHAR(255),
    move_start_time  NVARCHAR(255),
    move_end_time    NVARCHAR(255),
    is_reefer        NVARCHAR(255),
    weight_tons      NVARCHAR(255)
);
GO

-- GateTransactions


IF OBJECT_ID('stg.GateTransactions', 'U') IS NOT NULL
    DROP TABLE stg.GateTransactions;
GO

CREATE TABLE stg.GateTransactions (
    gate_txn_id      NVARCHAR(255),
    truck_plate      NVARCHAR(255),
    container_no     NVARCHAR(255),
    customer_id      NVARCHAR(255),
    terminal_id      NVARCHAR(255),
    direction        NVARCHAR(255), 
    gate_in_time     NVARCHAR(255),
    gate_out_time    NVARCHAR(255),
    shift_id         NVARCHAR(255)
);
GO






--Shifts

IF OBJECT_ID('stg.Shifts', 'U') IS NOT NULL
    DROP TABLE stg.Shifts;
GO

CREATE TABLE stg.Shifts (
    shift_id    NVARCHAR(255),
    shift_code  NVARCHAR(255),
    shift_name  NVARCHAR(255), -- (Morning, Afternoon, Night)
    start_time  NVARCHAR(255),
    end_time    NVARCHAR(255)
);
GO


--Equipment
IF OBJECT_ID('stg.Equipment', 'U') IS NOT NULL
    DROP TABLE stg.Equipment;
GO

CREATE TABLE stg.Equipment (
    equipment_id    NVARCHAR(255),
    equipment_code  NVARCHAR(255),
    equipment_type  NVARCHAR(255), 
    terminal_id     NVARCHAR(255),
    capacity_tons   NVARCHAR(255),
    acquired_date   NVARCHAR(255),
    [status]          NVARCHAR(255)  
);
GO

--Terminals
IF OBJECT_ID('stg.Terminals', 'U') IS NOT NULL
    DROP TABLE stg.Terminals;
GO

CREATE TABLE stg.Terminals (
    terminal_id   NVARCHAR(255),
    terminal_code NVARCHAR(255),
    terminal_name NVARCHAR(255),
    [zone]         NVARCHAR(255), --[] to avoid reserved word
    terminal_type NVARCHAR(255)
);
GO

--Customers
IF OBJECT_ID('stg.Customers', 'U') IS NOT NULL
    DROP TABLE stg.Customers;
GO

CREATE TABLE stg.Customers (
    customer_id    NVARCHAR(255),
    customer_code  NVARCHAR(255),
    customer_name  NVARCHAR(255),
    country        NVARCHAR(255),
    customer_tier  NVARCHAR(255),
    credit_limit   NVARCHAR(255),
    active_flag    NVARCHAR(255),
    onboarded_date NVARCHAR(255)
);
GO
--CustomerHistory
IF OBJECT_ID('stg.CustomerHistory', 'U') IS NOT NULL
    DROP TABLE stg.CustomerHistory;
GO

CREATE TABLE stg.CustomerHistory (
    customer_id   NVARCHAR(255),
    effective_from NVARCHAR(255),
    effective_to   NVARCHAR(255),
    customer_tier  NVARCHAR(255),
    credit_limit   NVARCHAR(255),
    change_reason  NVARCHAR(255)
);
GO

-- Monitoring & Audit
-- 1. BatchLog
IF OBJECT_ID('[stg].[BatchLog]', 'U') IS NOT NULL
    DROP TABLE [stg].[BatchLog];
GO

CREATE TABLE [stg].[BatchLog] (
    [LogID] INT IDENTITY(1,1) PRIMARY KEY,
    [PackageName] NVARCHAR(255),
    [TableName]   NVARCHAR(255),
    [StartTime] DATETIME,
    [EndTime] DATETIME,
    [Status] NVARCHAR(50), 
    [RowsRead] INT,
    [RowsWritten] INT
);

GO

-- 2. ErrorLog
IF OBJECT_ID('[stg].[ErrorLog]', 'U') IS NOT NULL
    DROP TABLE [stg].[ErrorLog];
GO

CREATE TABLE [stg].[ErrorLog] (
    [ErrorID] INT IDENTITY(1,1) PRIMARY KEY,
    [PackageName] NVARCHAR(255),
    [TableName] NVARCHAR(255),
    [ErrorCode] NVARCHAR(50),
    [ErrorDescription] NVARCHAR(MAX),
    [ErrorDate] DATETIME DEFAULT GETDATE()
);
GO




