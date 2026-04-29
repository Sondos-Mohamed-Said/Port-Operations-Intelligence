/*
===============================================================================
Script Name: Initial_Setup.sql
Description: 
    This script initializes the Data Mart dimensions with "Unknown" records (SK = -1).
    These records are essential for handling "Late-Arriving Dimensions" and 
    maintaining referential integrity when business keys are missing or invalid 
    during the Fact table loading process in SSIS.
===============================================================================
*/

-- 1. Dim_Shifts
SET IDENTITY_INSERT mart.Dim_Shifts ON;
INSERT INTO mart.Dim_Shifts (shifts_SK, shift_id, shift_name)
VALUES (-1, 0, 'Unknown');
SET IDENTITY_INSERT mart.Dim_Shifts OFF;
GO

-- 2. Dim_Container
SET IDENTITY_INSERT mart.Dim_Container ON;
INSERT INTO mart.Dim_Container (container_SK, container_no, container_size, is_reefer)
VALUES (-1, 'UNKNOWN', '0', 0);
SET IDENTITY_INSERT mart.Dim_Container OFF;
GO

-- 3. Dim_Vessel
SET IDENTITY_INSERT mart.Dim_Vessel ON;
INSERT INTO mart.Dim_Vessel (vessel_SK, vessel_name)
VALUES (-1, 'Unknown Vessel');
SET IDENTITY_INSERT mart.Dim_Vessel OFF;
GO

-- 4. Dim_Terminal
SET IDENTITY_INSERT mart.Dim_Terminal ON;
INSERT INTO mart.Dim_Terminal (terminal_SK, terminal_id, terminal_code, terminal_name)
VALUES (-1, 0, 'UNK', 'Unknown Terminal');
SET IDENTITY_INSERT mart.Dim_Terminal OFF;
GO

-- 5. Dim_Equipment
SET IDENTITY_INSERT mart.Dim_Equipment ON;
INSERT INTO mart.Dim_Equipment (equipment_SK, equipment_id, equipment_code, equipment_type)
VALUES (-1, '0', 'UNK', 'Unknown Equipment');
SET IDENTITY_INSERT mart.Dim_Equipment OFF;
GO

-- 6. Dim_Customer (SCD Type 2 Placeholder)
SET IDENTITY_INSERT mart.Dim_Customer ON;
INSERT INTO mart.Dim_Customer (customer_SK, customer_id, customer_name, customer_tier, active_flag)
VALUES (-1, 0, 'Unknown Customer', 'N/A', 0);
SET IDENTITY_INSERT mart.Dim_Customer OFF;
GO

-- 7. Dim_Status (Lookup)
SET IDENTITY_INSERT mart.Dim_Vessel_Status ON;
INSERT INTO mart.Dim_Vessel_Status (status_SK, status_name)
VALUES (-1, 'Unknown');
SET IDENTITY_INSERT mart.Dim_Vessel_Status OFF;
GO

-- 8. Dim_move_type (Lookup)
SET IDENTITY_INSERT mart.Dim_move_type ON;
INSERT INTO mart.Dim_move_type (move_type_SK, move_type_name)
VALUES (-1, 'Unknown');
SET IDENTITY_INSERT mart.Dim_move_type OFF;
GO

-- 9. Dim_Direction (Lookup)
SET IDENTITY_INSERT mart.Dim_Direction ON;
INSERT INTO mart.Dim_Direction (direction_SK, direction_name)
VALUES (-1, 'Unknown');
SET IDENTITY_INSERT mart.Dim_Direction OFF;
GO

-- 10. Dim_Date 
-- 11. Dim_Date 
-- Dim_Date_Time.sql file

-- Dim_Customer
SET IDENTITY_INSERT mart.Dim_Customer ON;

INSERT INTO mart.Dim_Customer (
    customer_SK, 
    customer_id, 
    customer_name, 
    customer_tier, 
    active_flag, 
    is_current,
    effective_from_id,
    effective_to_id
)
VALUES (-1, 0, 'Unknown Customer', 'N/A', 0, 1, 19000101, 99991231);

SET IDENTITY_INSERT mart.Dim_Customer OFF;
GO
