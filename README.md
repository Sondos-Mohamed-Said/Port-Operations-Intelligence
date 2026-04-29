# PortOps Data Mart — Technical Assessment (Part 1)
**Analyst:** Sondos Mohamed Said Mohamed

---

## Project Summary
A dimensional data mart built on SQL Server and loaded via SSIS from a multi-sheet Excel workbook containing port operations data. The mart serves three analytical areas: operational throughput, vessel & berth performance, and gate activity.

---

## Environment

| Component | Version / Detail |
|---|---|
| Database | SQL Server 2021   21.6.17 Developer Edition |
| ETL Tool | SSIS — Visual Studio community 2022 / SSDT |
| Source | PortOps_SourceData.xlsx (8 sheets) |
| Target Schema | `mart.*` (dimensional) / `stg.*` (staging) |
| BI Tool | Power BI Desktop (Part 2) |

---

## Repository Structure

```
DP_WORLD/
├── SQL/
│   ├── DDL_.sql              # stg schema: staging tables + stg.BatchLog + stg.ErrorLog
│   ├── DWH_DDL.sql           # mart schema: all dimensions + facts + mart.BatchLog + mart.ErrorLog
│   ├── Dim_Date_Time.sql     # Dim_Date DDL + seed (2017-2027) + Dim_Time DDL + seed
│   ├── Initial_Setup.sql     # Unknown rows (SK = -1) for every dimension
│   └── SQLQuery2.sql         # Data quality validation & profiling queries
├── SSIS/
│   ├── Load_Staging.dtsx     # Excel to stg (all 8 sheets, parallel DFTs)
│   ├── Dim_Customer.dtsx     # Manual SCD Type 1 + Type 2 implementation
│   ├── Dim_Shifts.dtsx       # Type 1 + unit tested
│   ├── Dim_Terminal.dtsx     # Type 1
│   ├── Dim_Vessel.dtsx       # Type 1
│   ├── Dim_Equipment.dtsx    # Type 1 (SCD Wizard)
│   └── [Fact packages]       # In progress - see Partial Completion below
├── design_doc.docx           # Full design document + written question answers
└── README.md                 # This file
```

---

## Setup Instructions

### Step 1 — Database, Schemas & Staging Tables
```sql
-- Run: SQL/DDL_.sql
-- Creates: DPWorld_DataMart database, stg schema, mart schema
--          All stg.* staging tables (NVARCHAR(255) throughout)
--          stg.BatchLog + stg.ErrorLog
```

### Step 2 — Mart Tables
```sql
-- Run: SQL/DWH_DDL.sql
-- Creates: All mart.Dim_* and mart.Fact_* tables
--          Non-clustered indexes on all FK columns
--          mart.BatchLog + mart.ErrorLog

-- Run: SQL/Dim_Date_Time.sql
-- Creates and seeds:
--   mart.Dim_Date  -> 4,018 rows (2017-01-01 to 2027-12-31) + Unknown row (SK = -1)
--   mart.Dim_Time  -> 1,440 rows (one per minute) + Unknown row (SK = -1)

-- Run: SQL/Initial_Setup.sql
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
1. Load_Staging.dtsx        <- loads all 8 Excel sheets into stg (parallel)
2. Dim_Shifts.dtsx
3. Dim_Terminal.dtsx
4. Dim_Vessel.dtsx
5. Dim_Equipment.dtsx
6. Dim_Customer.dtsx        <- SCD Type 2, run after all other dims
```

---

## Key Design Decisions

| Decision | Rationale |
|---|---|
| **Weekend = Friday & Saturday** | UAE/Middle East operational calendar. SQL Server DATEFIRST=7: 6=Friday, 7=Saturday. |
| **Fiscal year starts 1 April** | Stated in assessment. Five fiscal columns built into Dim_Date. |
| **Dim_Date range: 2017-2027** | Derived from diagnostic query. Earliest = Equipment.acquired_date (2017-09-20). Latest = VesselCalls.atd (2026-04-01). One-year buffers added on each side. |
| **All staging columns NVARCHAR(255)** | Excel is loosely typed. Landing as raw strings prevents extraction failures. Type casting deferred to mart-load SSIS Data Flow. |
| **No FK constraints in mart** | Enforced in SSIS via Lookup transformations. Physical FKs create INSERT overhead on 90K+ rows and conflict with late-arriving dimension handling. |
| **SCD Wizard not used for Dim_Customer** | Assessment requirement + performance: Wizard issues one OLE DB Command per row (RBAR). Manual pattern is set-based and maintainable. |
| **turnaround_time_minutes not stored** | Calculated as DAX measure using gate_in_time_SK and gate_out_time_SK via USERELATIONSHIP on inactive relationship. |
| **effective_to = 9999-12-31 stored as INT 99991231** | Avoids SQL Server DATE overflow. Derived in SSIS using SUBSTRING on NVARCHAR string rather than DT_DBDATE cast. |
| **Dim_Container — new row per combination** | container_size and is_reefer are fast-changing. New SK per unique (container_no + container_size + is_reefer). Controlled container_no duplication is correct per Kimball. |
| **date_SK = YYYYMMDD INT** | Human-readable. Directly derivable in SSIS: (YEAR x 10000)+(MONTH x 100)+DAY. No Lookup needed to generate it. |

---

## Assumptions

| Assumption | Detail |
|---|---|
| Weekend | **Friday & Saturday** — not Saturday & Sunday |
| Fiscal year | Begins **1 April** each year |
| Staging data types | All NVARCHAR(255) — casting happens in SSIS, not in staging DDL |
| effective_to = 9999-12-31 | Currently-active SCD row sentinel. Filtered from date range diagnostic using WHERE effective_to < '9000-01-01' |
| Unknown member | SK = -1 row in every dimension. Cannot collide with YYYYMMDD or HHMM formulas |

---

## Data Quality Checks (Checks.sql)

All checks run against staging after Load_Staging.dtsx completes:

| Check | Tables | Result |
|---|---|---|
| Date format validity (ISDATE) | ContainerMovements, VesselCalls, GateTransactions | 0 violations |
| Logic: end before start | ContainerMovements, GateTransactions, VesselCalls | 0 violations |
| Numeric validation (ISNUMERIC) | weight_tons, total_moves_planned, capacity_tons | 0 violations |
| Null / whitespace (TRIM) | customer_name, terminal_name, shift_name | 0 violations |
| Orphan detection (LEFT JOIN) | ContainerMovements to VesselCalls, Customers, Equipment | 0 orphans |
| Weight outliers | ContainerMovements | Min=2.00t, Max=32.00t - valid range |
| Duplicate voyage_no | VesselCalls | Reviewed - expected pattern |
| Container size consistency | ContainerMovements | Confirms fast-changing dimension design |
| Row count reconciliation | All stg tables via sys.partitions | O(1) metadata query - no full scan |

---

## Audit & Error Framework

| Table | Purpose |
|---|---|
| stg.BatchLog | Per-execution audit: PackageName, TableName, StartTime, EndTime, Status, RowsRead, RowsWritten, RowsError |
| stg.ErrorLog | Row-level extraction errors: ErrorCode, ErrorColumnID, FlatRowData |
| mart.BatchLog | Mart-level audit - same structure, captures dim/fact load results |
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

## Partial Completion

The following items were not completed due to the submission deadline:

| Item | Status |
|---|---|
| Fact_Vessel_Calls.dtsx | Not started — DDL complete |
| Fact_Container_Movements.dtsx | Not started — DDL complete |
| Fact_Gate_Transactions.dtsx | Not started — DDL complete |
| Master control package | Not started |
| Power BI report (Part 2) | Not started |

See **design_doc.docx Section 9** for the full intended implementation approach for each item.

---

## Screenshots

> Insert before final submission:
> - Load_Staging.dtsx Control Flow (truncate + parallel DFTs)
> - Dim_Customer.dtsx Data Flow (Lookup + Conditional Split + SCD pattern)
> - Dim_Shifts.dtsx unit test run (green ticks)
> - stg.BatchLog SELECT after a successful run
> - mart.Dim_Customer SELECT showing SCD Type 2 rows (is_current=0 and is_current=1)
> - mart.Dim_Date SELECT showing fiscal attributes
> - mart.ErrorLog SELECT (should be empty for clean run)

---

## Written Question Answers

Q1 — SCD Type 1 vs Type 2: When to use each?
Type 1 overwrites the existing dimension row and preserves no history. Type 2 inserts a new row with new effective dates, flags the old row as expired (is_current=0), and assigns a new surrogate key. In this implementation, customer_tier and credit_limit use Type 2 because management needs to analyse container volumes against the tier a customer held at the time of the move. Overwriting would corrupt historical analysis. customer_name and country use Type 1 because they represent corrections to master data identity, not meaningful analytical state changes requiring a time-based trail.

Q2 — Why surrogate keys instead of natural keys in fact tables?
Two reasons specific to this model. First, Dim_Customer uses SCD Type 2, which produces multiple rows per customer_id. The surrogate key customer_SK uniquely identifies the historical version of the customer record. Joining a fact on customer_id would require additional effective-date filtering, defeating the purpose of the dimension. Second, surrogate keys insulate the mart from changes in source natural keys — if a customer_id is reassigned in the source, existing history in the mart remains intact and correct.

Q3 — How are out-of-range dates handled?
If a fact arrives with a date outside 2017–2027, the Lookup on Dim_Date returns No Match. The SSIS pipeline routes the No-Match output to a Derived Column that assigns date_SK = -1, pointing the row to the Unknown dimension member. The fact row is still loaded rather than dropped. The occurrence is recorded in mart.BatchLog and mart.ErrorLog. To prevent recurrence, the Dim_Date seed script is extended and the affected fact package re-run for impacted rows only.

Q4 — SCD Wizard vs manual: performance characteristics?
The SCD Wizard generates one OLE DB Command per changed row — a single parameterised UPDATE per record in a RBAR (row-by-row) loop. On thousands of Type 2 changes this creates thousands of SQL Server round-trips. A manual implementation processes all Type 2 changes as a batch via OLE DB Command with efficient parameter binding, and can be further optimised with staging tables and set-based UPDATE statements. The Wizard also generates opaque metadata that cannot be easily extended, version-controlled, or debugged. The manual pattern is transparent and production-grade.

Q5 — Row-count reconciliation approach?
At the end of each staging package, a Script Task or Execute SQL Task queries sys.partitions to retrieve post-load row counts and compares them against source row counts (captured before loading into SSIS variables). If the delta exceeds a configurable threshold, the package sets its result to Failure, halting all downstream fact packages via precedence constraints. The mismatch values (RowsRead vs RowsWritten) are recorded in stg.BatchLog with Status=FAILED. At the mart level, mart.BatchLog performs the same check per dimension and fact table.

Q6 — Role of the staging layer?
The staging layer provides three guarantees. First, it decouples source extraction from transformation — if a mart load fails, the source file does not need to be re-read; the pipeline restarts from staging. Second, it provides a clean surface for data quality validation: all profiling queries run against staging, not the mart, so defects are caught before they propagate. Third, it enables full pipeline observability — every row that enters staging can be reconciled against every row that exits to the mart, with any gap captured in the ErrorLog.

Q7 — Why can Power BI only have one active relationship between two tables?
Multiple active relationships between two tables would create ambiguous filter propagation. If Fact_Gate_Transactions had two active relationships to Dim_Date — on gate_in_date_SK and gate_out_date_SK — a date slicer selection would produce an OR filter across both columns simultaneously, returning incorrect aggregations. The inactive relationship on gate_out_date_SK is activated inside specific DAX measures via USERELATIONSHIP, which scopes the alternative filter path to that measure only, preventing cross-contamination.

Q8 — USERELATIONSHIP vs CROSSFILTER?
USERELATIONSHIP temporarily activates an inactive relationship for the duration of one measure evaluation, replacing the active one. It is the correct tool when a fact has two FK columns pointing to the same dimension (role-playing dimensions), such as gate_in_date_SK and gate_out_date_SK both referencing Dim_Date. CROSSFILTER changes the filter direction of an existing active relationship — switching one-directional to bidirectional to allow a dimension to filter across another fact table. CROSSFILTER is appropriate for bridging tables or many-to-many scenarios; USERELATIONSHIP is appropriate for role-playing date dimensions.

Q9 — A KPI does not respond to the date slicer. How do you debug it?
Investigation order: (1) Check if the measure uses hardcoded FILTER or CALCULATE with fixed date values rather than relying on filter context. (2) Verify the relationship between the fact table and Dim_Date is not inactive without a USERELATIONSHIP override in the measure. (3) Confirm the slicer field is from the table marked as Date Table in Power BI, not from a disconnected date column. (4) Check for page-level or report-level filters that override the slicer. (5) Verify the date_SK column in the fact table is INT matching Dim_Date.date_SK — a type mismatch causes the relationship join to silently produce no filter. (6) Use Performance Analyzer to inspect the DAX query and confirm filter context is reaching the measure.

