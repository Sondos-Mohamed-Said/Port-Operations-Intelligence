-- ============================================================
-- DIM_DATE & DIM_TIME — DDL + SEED SCRIPTS
-- Range: 2017-01-01 to 2027-12-31
-- Fiscal Year starts: 1 April
-- ============================================================


-- ============================================================
-- 1. DIM_DATE — DDL
-- ============================================================

DROP TABLE IF EXISTS mart.Dim_Date;

CREATE TABLE mart.Dim_Date (
    date_SK                 INT             NOT NULL,   -- Format: YYYYMMDD
    full_date               DATE            NOT NULL,

    -- Day Attributes
    day_of_month            TINYINT         NOT NULL,
    day_name                NVARCHAR(10)    NOT NULL,   -- Monday, Tuesday...
    day_of_week             TINYINT         NOT NULL,   -- 1=Sunday, 7=Saturday (SQL Server default)
    day_of_year             SMALLINT        NOT NULL,
    is_weekend              BIT             NOT NULL,
    is_weekday              BIT             NOT NULL,

    -- Week Attributes
    week_of_year            TINYINT         NOT NULL,
    week_of_month           TINYINT         NOT NULL,

    -- Month Attributes
    month_number            TINYINT         NOT NULL,
    month_name              NVARCHAR(10)    NOT NULL,
    month_short_name        NCHAR(3)        NOT NULL,   -- Jan, Feb...
    days_in_month           TINYINT         NOT NULL,
    is_last_day_of_month    BIT             NOT NULL,

    -- Calendar Quarter Attributes
    calendar_quarter        TINYINT         NOT NULL,   -- 1,2,3,4
    calendar_quarter_name   NCHAR(2)        NOT NULL,   -- Q1, Q2...
    calendar_year           SMALLINT        NOT NULL,
    cal_year_month          NCHAR(7)        NOT NULL,   -- 2024-01
    cal_year_quarter        NCHAR(7)        NOT NULL,   -- 2024-Q1

    -- Fiscal Attributes (Fiscal Year starts 1 April)
    fiscal_year             SMALLINT        NOT NULL,   -- e.g. April 2024 = FY2025
    fiscal_quarter          TINYINT         NOT NULL,   -- 1,2,3,4
    fiscal_quarter_name     NCHAR(9)        NOT NULL,   -- FY25-Q1
    fiscal_month            TINYINT         NOT NULL,   -- 1=April ... 12=March
    fiscal_year_label       NCHAR(6)        NOT NULL,   -- FY2025

    -- Working Day Flags
    is_public_holiday       BIT             NOT NULL    DEFAULT 0,
    is_working_day          BIT             NOT NULL,

    CONSTRAINT PK_dim_date PRIMARY KEY (date_SK)
);


-- ============================================================
-- 2. DIM_DATE — SEED SCRIPT
-- Range: 2017-01-01 to 2027-12-31 (MAXRECURSION 5000)
-- ============================================================

-- Unknown / Late-Arriving row
INSERT INTO mart.Dim_Date (
    date_SK, full_date,
    day_of_month, day_name, day_of_week, day_of_year,
    is_weekend, is_weekday,
    week_of_year, week_of_month,
    month_number, month_name, month_short_name, days_in_month, is_last_day_of_month,
    calendar_quarter, calendar_quarter_name, calendar_year, cal_year_month, cal_year_quarter,
    fiscal_year, fiscal_quarter, fiscal_quarter_name, fiscal_month, fiscal_year_label,
    is_public_holiday, is_working_day
) VALUES (
    -1, '1900-01-01',
    0, 'Unknown', 0, 0,
    0, 0,
    0, 0,
    0, 'Unknown', 'UNK', 0, 0,
    0, 'Q0', 0, 'Unknown', 'Unknown',
    0, 0, 'FY0000-Q0', 0, 'FY0000',
    0, 0
);

-- Main Date Rows
WITH DateSeries AS (
    SELECT CAST('2017-01-01' AS DATE) AS d
    UNION ALL
    SELECT DATEADD(DAY, 1, d)
    FROM DateSeries
    WHERE d < '2027-12-31'
)
INSERT INTO mart.Dim_Date (
    date_SK, full_date,
    day_of_month, day_name, day_of_week, day_of_year,
    is_weekend, is_weekday,
    week_of_year, week_of_month,
    month_number, month_name, month_short_name, days_in_month, is_last_day_of_month,
    calendar_quarter, calendar_quarter_name, calendar_year, cal_year_month, cal_year_quarter,
    fiscal_year, fiscal_quarter, fiscal_quarter_name, fiscal_month, fiscal_year_label,
    is_public_holiday, is_working_day
)
SELECT
    CONVERT(INT, FORMAT(d, 'yyyyMMdd'))                                         AS date_SK,
    d                                                                            AS full_date,

    -- Day
    DAY(d)                                                                       AS day_of_month,
    DATENAME(WEEKDAY, d)                                                         AS day_name,
    DATEPART(WEEKDAY, d)                                                         AS day_of_week,
    DATEPART(DAYOFYEAR, d)                                                       AS day_of_year,
    CASE WHEN DATEPART(WEEKDAY, d) IN (6, 7) THEN 1 ELSE 0 END                  AS is_weekend,
    CASE WHEN DATEPART(WEEKDAY, d) NOT IN (6, 7) THEN 1 ELSE 0 END              AS is_weekday,

    -- Week
    DATEPART(WEEK, d)                                                            AS week_of_year,
    DATEPART(WEEK, d) - DATEPART(WEEK, DATEADD(DAY, 1 - DAY(d), d)) + 1        AS week_of_month,

    -- Month
    MONTH(d)                                                                     AS month_number,
    DATENAME(MONTH, d)                                                           AS month_name,
    LEFT(DATENAME(MONTH, d), 3)                                                  AS month_short_name,
    DAY(EOMONTH(d))                                                              AS days_in_month,
    CASE WHEN d = EOMONTH(d) THEN 1 ELSE 0 END                                  AS is_last_day_of_month,

    -- Calendar Quarter
    DATEPART(QUARTER, d)                                                         AS calendar_quarter,
    'Q' + CAST(DATEPART(QUARTER, d) AS CHAR(1))                                 AS calendar_quarter_name,
    YEAR(d)                                                                      AS calendar_year,
    FORMAT(d, 'yyyy-MM')                                                         AS cal_year_month,
    CONCAT(YEAR(d), '-Q', DATEPART(QUARTER, d))                                 AS cal_year_quarter,

    -- Fiscal Year (starts 1 April)
    CASE WHEN MONTH(d) >= 4 THEN YEAR(d) + 1 ELSE YEAR(d) END                  AS fiscal_year,

    CASE
        WHEN MONTH(d) IN (4, 5, 6)    THEN 1
        WHEN MONTH(d) IN (7, 8, 9)    THEN 2
        WHEN MONTH(d) IN (10, 11, 12) THEN 3
        WHEN MONTH(d) IN (1, 2, 3)    THEN 4
    END                                                                          AS fiscal_quarter,

    CONCAT(
        'FY', RIGHT(CASE WHEN MONTH(d) >= 4 THEN YEAR(d) + 1 ELSE YEAR(d) END, 2),
        '-Q',
        CASE
            WHEN MONTH(d) IN (4, 5, 6)    THEN 1
            WHEN MONTH(d) IN (7, 8, 9)    THEN 2
            WHEN MONTH(d) IN (10, 11, 12) THEN 3
            ELSE 4
        END
    )                                                                            AS fiscal_quarter_name,

    CASE
        WHEN MONTH(d) = 4  THEN 1   WHEN MONTH(d) = 5  THEN 2
        WHEN MONTH(d) = 6  THEN 3   WHEN MONTH(d) = 7  THEN 4
        WHEN MONTH(d) = 8  THEN 5   WHEN MONTH(d) = 9  THEN 6
        WHEN MONTH(d) = 10 THEN 7   WHEN MONTH(d) = 11 THEN 8
        WHEN MONTH(d) = 12 THEN 9   WHEN MONTH(d) = 1  THEN 10
        WHEN MONTH(d) = 2  THEN 11  WHEN MONTH(d) = 3  THEN 12
    END                                                                          AS fiscal_month,

    CONCAT('FY', CASE WHEN MONTH(d) >= 4 THEN YEAR(d) + 1 ELSE YEAR(d) END)   AS fiscal_year_label,

    -- Working Day
    0                                                                            AS is_public_holiday,
    CASE WHEN DATEPART(WEEKDAY, d) IN (6, 7) THEN 0 ELSE 1 END                   AS is_working_day

FROM DateSeries
OPTION (MAXRECURSION 5000);


-- ============================================================
-- 3. DIM_TIME — DDL
-- Grain: 1 row per minute = 1,440 rows total
-- ============================================================

DROP TABLE IF EXISTS mart.Dim_Time;

CREATE TABLE mart.Dim_Time (
    time_SK         INT             NOT NULL,   -- Format: HHMM e.g. 1430
    full_time       TIME            NOT NULL,
    hour_24         TINYINT         NOT NULL,   -- 0-23
    hour_12         TINYINT         NOT NULL,   -- 1-12
    minute          TINYINT         NOT NULL,   -- 0-59
    am_pm           CHAR(2)         NOT NULL,   -- AM / PM
    time_label      NCHAR(5)        NOT NULL,   -- 14:30
    hour_bucket     NVARCHAR(15)    NOT NULL,   -- 00:00-06:00
    is_peak_hour    BIT             NOT NULL,

    CONSTRAINT PK_dim_time PRIMARY KEY (time_SK)
);


-- ============================================================
-- 4. DIM_TIME — SEED SCRIPT
-- ============================================================

-- Unknown / Late-Arriving row
INSERT INTO mart.Dim_Time (
    time_SK, full_time, hour_24, hour_12, minute,
    am_pm, time_label, hour_bucket, is_peak_hour
) VALUES (
    -1, '00:00', 0, 12, 0,
    'AM', 'UNK', 'Unknown', 0
);

-- Main Time Rows (1 per minute)
WITH mins AS (
    SELECT 0 AS m
    UNION ALL
    SELECT m + 1 FROM mins WHERE m < 1439
)
INSERT INTO mart.Dim_Time (
    time_SK, full_time, hour_24, hour_12, minute,
    am_pm, time_label, hour_bucket, is_peak_hour
)
SELECT
    (m / 60) * 100 + (m % 60)                                      AS time_SK,
    CAST(DATEADD(MINUTE, m, '00:00:00') AS TIME)                   AS full_time,
    m / 60                                                          AS hour_24,
    CASE WHEN (m / 60) % 12 = 0 THEN 12 ELSE (m / 60) % 12 END    AS hour_12,
    m % 60                                                          AS minute,
    CASE WHEN m < 720 THEN 'AM' ELSE 'PM' END                      AS am_pm,
    FORMAT(DATEADD(MINUTE, m, '00:00:00'), 'HH:mm')                AS time_label,

    CASE
        WHEN m / 60 BETWEEN 0  AND 5  THEN '00:00-06:00'
        WHEN m / 60 BETWEEN 6  AND 11 THEN '06:00-12:00'
        WHEN m / 60 BETWEEN 12 AND 17 THEN '12:00-18:00'
        ELSE                               '18:00-24:00'
    END                                                             AS hour_bucket,

    CASE WHEN m / 60 BETWEEN 7 AND 19 THEN 1 ELSE 0 END            AS is_peak_hour

FROM mins
OPTION (MAXRECURSION 2000);