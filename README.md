# PortOps Data Mart — Technical Assessment (Part 1 + Part 2)

**Analyst:** Sondos Mohamed Said Mohamed

---

## Assumptions

| Assumption | Detail |
|---|---|
| **Weekend = Friday & Saturday** | UAE/Middle East operational calendar. SQL Server DATEFIRST=7: 6=Friday, 7=Saturday. |
| **Fiscal year starts 1 April** | Stated explicitly in assessment. Five fiscal columns built into Dim_Date. |
| **Dim_Date range: 2017–2027** | Derived from diagnostic query across all staging date columns. Earliest = Equipment.acquired_date (2017-09-20). Latest = VesselCalls.atd (2026-04-01). One-year buffers added on each side. |
| **All staging columns NVARCHAR(255)** | Excel is loosely typed. Landing as raw strings prevents extraction failures. Type casting deferred to mart-load SSIS Data Flow. |
| **No FK constraints in mart** | Referential integrity enforced in SSIS via Lookup transformations. Physical FKs create INSERT overhead on 90K+ rows and conflict with late-arriving dimension handling. |
| **SCD Wizard not used for Dim_Customer** | Assessment requirement + performance: Wizard issues one OLE DB Command per row (RBAR). Manual pattern is set-based and maintainable. |
| **turnaround_time_minutes not stored** | Calculated as DAX measure using gate_in_date_SK and gate_out_date_SK via USERELATIONSHIP on the inactive relationship to Dim_Date. |
| **effective_to = 9999-12-31 stored as INT 99991231** | Avoids SQL Server DATE overflow. Derived in SSIS using SUBSTRING on NVARCHAR string rather than DT_DBDATE cast. |
| **Dim_Container — new row per combination** | container_size and is_reefer are fast-changing. New SK per unique (container_no + container_size + is_reefer). Controlled container_no duplication is correct per Kimball. |
| **date_SK = YYYYMMDD INT** | Human-readable. Directly derivable in SSIS: (YEAR × 10000) + (MONTH × 100) + DAY. No Lookup needed to generate it. |
| **Source workbook has 9 sheets** | VesselCalls, ContainerMovements, GateTransactions, Customers, CustomerHistory, Terminals, Equipment, Shifts, README. The README sheet is reference only and not staged. |

---

## Environment

| Component | Version / Detail |
|---|---|
| Database | SQL Server 2019+ Developer Edition |
| ETL Tool | SSIS — Visual Studio Community 2022 / SSDT |
| Source | PortOps_SourceData.xlsx (9 sheets, 8 staged) |
| Target Schema | `mart.*` (dimensional) / `stg.*` (staging) |
| BI Tool | Power BI Desktop (Part 2) |

---

## Repository Structure

```
submission_SondosMohamedSaid/
├── README.md                          ← This file
├── part1_datamart/
│   ├── ssis/                          ← SSIS solution (.sln + all .dtsx packages)
│   │   └── DP_WORLD/
│   │       └── DP_WORLD/
│   │           ├── Load_Staging.dtsx
│   │           ├── Dim_Customer.dtsx
│   │           ├── Dim_Shifts.dtsx
│   │           ├── Dim_Terminal.dtsx
│   │           ├── Dim_Vessel.dtsx
│   │           ├── Dim_Equipment.dtsx
│   │           ├── Dim_Container.dtsx
│   │           ├── Dim_move_types.dtsx
│   │           ├── Fact_Vessel_Calls.dtsx
│   │           ├── Fact_Container_Movement.dtsx
│   │           └── Fact_Gate_Transaction.dtsx
│   ├── sql/
│   │   ├── DDL_.sql                   ← stg schema: staging tables + stg.BatchLog + stg.ErrorLog
│   │   ├── DWH_DDL.sql                ← mart schema: all dimensions + facts + mart.BatchLog + mart.ErrorLog
│   │   ├── Dim_Date_Time.sql          ← Dim_Date DDL + seed (2017–2027) + Dim_Time DDL + seed
│   │   ├── Initial_Setup.sql          ← Unknown rows (SK = -1) for every dimension
│   │   └── checks.sql                 ← Data quality validation & profiling queries
│   ├── design_doc.docx                ← Full design document + written question answers
│   └── screenshots/
│       ├── DWH SCHEMA.png
│       ├── SSIS Packages.png
│       ├── Load_Staging.png
│       ├── Connection Managers.png
│       ├── SQL Schema & Tables.png
│       ├── Dim_Customer_DF.png
│       ├── Dim_Shifts_DF.png
│       ├── Dim_Terminal_CF.png
│       ├── Dim_Terminal_DF.png
│       ├── Dim_Vessel.png
│       └── Fact_Vessel_Calls.png
└── part2_powerbi/
    ├── dashboard.pbix/
    │   └── DP_WORLD.pbix
    ├── dax_measures.md                ← All DAX measures with code and explanations
    └── screenshots/
        ├── Operations Overview.png
        ├── Gate Performance.png
        └── Customer & Vessel Performance.png
```

---

## Setup Instructions

### Step 1 — Database, Schemas & Staging Tables

```sql
-- Run: part1_datamart/sql/DDL_.sql
-- Creates: DPWorld_DataMart database, stg schema, mart schema
--          All stg.* staging tables (NVARCHAR(255) throughout)
--          stg.BatchLog + stg.ErrorLog
```

### Step 2 — Mart Tables

```sql
-- Run: part1_datamart/sql/DWH_DDL.sql
-- Creates: All mart.Dim_* and mart.Fact_* tables
--          Non-clustered indexes on all FK columns
--          mart.BatchLog + mart.ErrorLog

-- Run: part1_datamart/sql/Dim_Date_Time.sql
-- Creates and seeds:
--   mart.Dim_Date  → 4,018 rows (2017-01-01 to 2027-12-31) + Unknown row (SK = -1)
--   mart.Dim_Time  → 1,440 rows (one per minute)           + Unknown row (SK = -1)

-- Run: part1_datamart/sql/Initial_Setup.sql
-- Inserts Unknown row (SK = -1) into every remaining dimension
```

### Step 3 — SSIS Packages

> **Before running:** Update the two Project Parameters to match your environment:
> - `ExcelSource_Path` — full path to PortOps_SourceData.xlsx
> - `DB_ConnectionString` — your SQL Server connection string
>
> No .dtsx files need to be modified.

Run packages in this order:

```
1. Load_Staging.dtsx            ← loads all 8 Excel sheets into stg (parallel)
2. Dim_Shifts.dtsx
3. Dim_Terminal.dtsx
4. Dim_Vessel.dtsx
5. Dim_Equipment.dtsx
6. Dim_Container.dtsx
7. Dim_move_types.dtsx
8. Dim_Customer.dtsx            ← SCD Type 2; run after all other dims
9. Fact_Vessel_Calls.dtsx
10. Fact_Container_Movement.dtsx
11. Fact_Gate_Transaction.dtsx
```

### Step 4 — Power BI

Open `part2_powerbi/dashboard.pbix/DP_WORLD.pbix` in Power BI Desktop. Update the data source connection to point to your SQL Server instance and refresh. The model connects in Import mode to the `mart.*` schema.

---

## Key Design Decisions

| Decision | Rationale |
|---|---|
| **Weekend = Friday & Saturday** | UAE/Middle East operational calendar. SQL Server DATEFIRST=7: 6=Friday, 7=Saturday. |
| **Fiscal year starts 1 April** | Stated in assessment. Five fiscal columns built into Dim_Date. |
| **Dim_Date range: 2017–2027** | Derived from diagnostic query. Earliest = Equipment.acquired_date (2017-09-20). Latest = VesselCalls.atd (2026-04-01). One-year buffers added on each side. |
| **All staging columns NVARCHAR(255)** | Excel is loosely typed. Landing as raw strings prevents extraction failures. Type casting deferred to mart-load SSIS Data Flow. |
| **No FK constraints in mart** | Enforced in SSIS via Lookup transformations. Physical FKs create INSERT overhead on 90K+ rows and conflict with late-arriving dimension handling. |
| **SCD Wizard not used for Dim_Customer** | Assessment requirement + performance: Wizard issues one OLE DB Command per row (RBAR). Manual pattern is set-based and maintainable. |
| **turnaround_time_minutes not stored** | Calculated as DAX measure using gate_in_date_SK and gate_out_date_SK via USERELATIONSHIP on inactive relationship. |
| **effective_to = 9999-12-31 stored as INT 99991231** | Avoids SQL Server DATE overflow. Derived in SSIS using SUBSTRING on NVARCHAR string rather than DT_DBDATE cast. |
| **Dim_Container — new row per combination** | container_size and is_reefer are fast-changing. New SK per unique (container_no + container_size + is_reefer). Controlled container_no duplication is correct per Kimball. |
| **date_SK = YYYYMMDD INT** | Human-readable. Directly derivable in SSIS: (YEAR × 10000) + (MONTH × 100) + DAY. No Lookup needed to generate it. |
| **fact_gate_transaction carries two date FKs** | gate_in_date_SK (active relationship) and gate_out_date_SK (inactive relationship) both reference mart.Dim_Date. Enables USERELATIONSHIP in DAX for gate-out measures without importing Dim_Date twice. |

---

## Data Quality Checks (checks.sql)

All checks run against staging after Load_Staging.dtsx completes:

| Check | Tables | Result |
|---|---|---|
| Date format validity (ISDATE) | ContainerMovements, VesselCalls, GateTransactions | 0 violations |
| Logic: end before start | ContainerMovements, GateTransactions, VesselCalls | 0 violations |
| Numeric validation (ISNUMERIC) | weight_tons, total_moves_planned, capacity_tons | 0 violations |
| Null / whitespace (TRIM) | customer_name, terminal_name, shift_name | 0 violations |
| Orphan detection (LEFT JOIN) | ContainerMovements to VesselCalls, Customers, Equipment | 0 orphans |
| Weight outliers | ContainerMovements | Min=2.00t, Max=32.00t — valid range |
| Duplicate voyage_no | VesselCalls | Reviewed — expected pattern (same voyage, multiple terminals) |
| Container size consistency | ContainerMovements | Confirms fast-changing dimension design |
| Row count reconciliation | All stg tables via sys.partitions | O(1) metadata query — no full scan |

---

## Audit & Error Framework

| Table | Purpose |
|---|---|
| stg.BatchLog | Per-execution audit: PackageName, TableName, StartTime, EndTime, Status, RowsRead, RowsWritten, RowsError |
| stg.ErrorLog | Row-level extraction errors: ErrorCode, ErrorColumnID, FlatRowData |
| mart.BatchLog | Mart-level audit — same structure, captures dim/fact load results |
| mart.ErrorLog | Mart-level row errors from Data Conversion and Lookup components |

**Reconciliation formula enforced:** RowsRead = RowsWritten + RowsError

---

## Unit Test Results — Dim_Shifts.dtsx

| Scenario | Result |
|---|---|
| A — 3 valid rows, normal load | PASSED: RowsRead=3, RowsWritten=3, RowsError=0 |
| B — shift_id='ERROR' (type mismatch) | PASSED: Row to ErrorLog, pipeline non-blocking |
| C — shift_name > 50 chars (truncation) | PASSED: Row to ErrorLog, not silently truncated |
| D — Row-count reconciliation | PASSED: RowsRead(4) = RowsWritten(3) + RowsError(1) |

---

## Written Question Answers

### Data Warehousing

**Q1 — SCD Type 1 vs Type 2: When to use each?**

Type 1 overwrites the existing dimension row and preserves no history. Type 2 inserts a new row with new effective dates, flags the old row as expired (is_current=0), and assigns a new surrogate key. In this implementation, customer_tier and credit_limit use Type 2 because management needs to analyse container volumes against the tier a customer held at the time of the move — overwriting would corrupt historical analysis. customer_name and country use Type 1 because they represent corrections to master data identity, not meaningful analytical state changes that require a time-based trail. The SCD type was chosen attribute-by-attribute based on whether the change carries analytical meaning or is simply a data correction.

**Q2 — Why surrogate keys instead of natural keys in fact tables?**

Two reasons specific to this model. First, Dim_Customer uses SCD Type 2, which produces multiple rows per customer_id — the surrogate key customer_SK uniquely identifies the historical version of the customer record, and joining on customer_id alone would require additional effective-date filtering, defeating the purpose of the dimension. Second, surrogate keys insulate the mart from changes in source natural keys: if a customer_id is reassigned in the source system, existing history in the mart remains intact and correct because the fact rows still point to valid SK values that cannot be overwritten.

**Q3 — Dim_Date is bounded. What happens if a fact arrives with a date outside that range?**

If a fact arrives with a date outside 2017–2027, the Lookup on Dim_Date returns No Match. The SSIS pipeline routes the No-Match output to a Derived Column that assigns date_SK = -1, pointing the row to the Unknown dimension member. The fact row is still loaded rather than dropped. The occurrence is recorded in mart.BatchLog and mart.ErrorLog with the offending date value in FlatRowData, so operations can identify and investigate the source. To prevent recurrence, the Dim_Date seed script is extended for the new range and the affected fact packages re-run for impacted rows only using the ErrorLog as the reconciliation source.

### SSIS

**Q4 — Why is the built-in SSIS SCD Wizard not suitable for a production Type 2 load at scale?**

The SCD Wizard generates one OLE DB Command per changed row — a single parameterised UPDATE per record executed in a row-by-row loop. On thousands of Type 2 changes this creates thousands of SQL Server round-trips, making load time proportional to change volume rather than constant. The Wizard also does not expose granular Error Outputs on its internal components, so failed rows cannot be redirected to the ErrorLog — they cause the entire pipeline to fail. The Wizard generates opaque metadata that cannot be easily extended, version-controlled, or debugged in production. A manual implementation using Lookup, Conditional Split, and OLE DB Destination is set-based, exposable, and transparent.

**Q5 — How would you implement automated row-count reconciliation between source, staging, and target?**

At the start of each SSIS package, a Script Task captures the source row count into a User variable (RowsRead). At the end, an Execute SQL Task queries sys.partitions on the target table to retrieve the post-load count in O(1) without a full table scan. A second Script Task compares RowsWritten + RowsError against RowsRead: if the delta exceeds zero, the package sets its result to Failure, which propagates via Precedence Constraints to halt all downstream fact packages. The counts (RowsRead, RowsWritten, RowsError) are written to stg.BatchLog and mart.BatchLog on every run so mismatches are permanently auditable and correctable without re-reading the source.

**Q6 — What is the role of the staging layer?**

The staging layer provides three guarantees. First, it decouples source extraction from transformation — if a mart load fails mid-run, the source Excel file does not need to be re-read; the pipeline restarts from staging, which is already loaded. Second, it provides a clean, stable surface for data quality validation: all profiling and business-rule checks run against staging before any mart table is touched, so defects are caught before they propagate. Third, it enables full pipeline observability — every row that enters staging can be reconciled against every row that exits to the mart, with any gap permanently captured in the ErrorLog. Loading directly into fact tables would remove all of these guarantees and make any extraction failure destructive.

### Power BI

**Q7 — Why does Power BI allow only one active relationship between two tables?**

Multiple active relationships between two tables would create ambiguous filter propagation. If Fact_Gate_Transactions had two active relationships to Dim_Date — one on gate_in_date_SK and one on gate_out_date_SK — a date slicer selection would produce an OR filter across both columns simultaneously, returning incorrect and uninterpretable aggregations: a measure would count transactions where either the gate-in or gate-out date matched the selection, not one or the other. The inactive relationship on gate_out_date_SK is activated inside specific DAX measures via USERELATIONSHIP, which scopes the alternative filter path to that measure evaluation only, preventing cross-contamination with measures that must use the active gate-in relationship.

**Q8 — Explain the difference between USERELATIONSHIP and CROSSFILTER.**

USERELATIONSHIP temporarily activates an inactive relationship for the duration of one measure evaluation, replacing the active one. It is the correct tool when a fact has two FK columns pointing to the same dimension — as in gate_in_date_SK and gate_out_date_SK both referencing Dim_Date — because it allows each measure to choose which path to traverse without ambiguity. CROSSFILTER changes the filter direction of an existing active relationship, switching it from one-directional to bidirectional so that a dimension can filter across bridge tables or reach a second fact table. CROSSFILTER is appropriate for many-to-many scenarios or shared dimensions across fact tables; USERELATIONSHIP is appropriate for role-playing date dimensions where one column must respond to a slicer independently of the other.

**Q9 — A KPI does not respond to the date slicer. List the most likely causes in investigation order.**

Investigation order: (1) Check whether the measure uses a hardcoded FILTER or CALCULATE with fixed date values rather than relying on implicit filter context propagation. (2) Verify the relationship between the fact table and Dim_Date is not the inactive one without a USERELATIONSHIP override inside the measure. (3) Confirm the slicer field originates from the table marked as Date Table in Power BI Modeling settings — a disconnected date column does not propagate filter context through the model. (4) Check for page-level or report-level filters that conflict with or override the slicer selection. (5) Verify the date_SK column in the fact table is INT matching Dim_Date.date_SK — a type mismatch causes the relationship join to silently produce no filter. (6) Open Performance Analyzer, capture the DAX query for the affected visual, and inspect whether the filter context from the slicer is reaching the measure at all.
