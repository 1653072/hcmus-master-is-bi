# Data Warehouse & Business Intelligence Guidelines

## Table of Contents
- [1. Overall Project Prerequisites](#1-overall-project-prerequisites)
  - [1.1 Source Data Quantity](#11-source-data-quantity)
  - [1.2 Source Data Quality](#12-source-data-quality)
  - [1.3 Bonus Criteria](#13-bonus-criteria)
  - [1.4 Infrastructure](#14-infrastructure)
  - [1.5 Mindset](#15-mindset)
- [2. Data Sources](#2-data-sources)
  - [2.1 Role](#21-role)
  - [2.2 Key Criteria for Project](#22-key-criteria-for-project)
- [3. ETL Process](#3-etl-process)
  - [3.1 Role](#31-role)
  - [3.2 Extract - Hybrid Extraction Mechanism (Push & Pull)](#32-extract---hybrid-extraction-mechanism-push---pull)
    - [3.2.1 Proactive PUSH for Master Data](#321-proactive-push-for-master-data)
    - [3.2.2 Incremental PULL for Transactional Data](#322-incremental-pull-for-transactional-data)
  - [3.3 Transform](#33-transform)
  - [3.4 Load](#34-load)
    - [3.4.1 Loading to Staging](#341-loading-to-staging)
    - [3.4.2 Loading to NDS (Normalized Data Store)](#342-loading-to-nds-normalized-data-store)
    - [3.4.3 Loading to DDS (Dimensional Data Store)](#343-loading-to-dds-dimensional-data-store)
  - [3.5 Handling Specific Scenarios](#35-handling-specific-scenarios)
    - [3.5.1 Handle Late Master Data (Late Arriving Dimensions)](#351-handle-late-master-data-late-arriving-dimensions)
    - [3.5.2 Handle Upsert Rules](#352-handle-upsert-rules)
    - [3.5.3 Detect Source Data Changes/Issues](#353-detect-source-data-changesissues)
    - [3.5.4 Handle Business Rules, Duplicate/Object Matching, and Data Leak Checks](#354-handle-business-rules-duplicateobject-matching-and-data-leak-checks)
- [4. Staging Area (Combined & Concise)](#4-staging-area-combined--concise)
  - [4.1 Role & Fundamentals](#41-role--fundamentals)
  - [4.2 Key Criteria for Project](#42-key-criteria-for-project)
- [5. ODS (Operational Data Store)](#5-ods-operational-data-store)
  - [5.1 Definition & Role](#51-definition--role)
  - [5.2 Architecture](#52-architecture)
  - [5.3 Structure](#53-structure)
- [6. NDS (Normalized Data Store)](#6-nds-normalized-data-store)
  - [6.1 Role](#61-role)
  - [6.2 Key Criteria for Project](#62-key-criteria-for-project)
- [7. DDS (Dimensional Data Store)](#7-dds-dimensional-data-store)
  - [7.1 Role](#71-role)
  - [7.2 Key Criteria for Project](#72-key-criteria-for-project)
- [8. CUBE & OLAP](#8-cube--olap)
  - [8.1 Role](#81-role)
  - [8.2 Key Criteria for Project](#82-key-criteria-for-project)
- [9. Users (BI Applications)](#9-users-bi-applications)
  - [9.1 Role](#91-role)
  - [9.2 Key Criteria for Project](#92-key-criteria-for-project)

## 1. Overall Project Prerequisites
Before diving into the specific stages, you must satisfy these overarching project requirements:

### 1.1 Source Data Quantity
- Use at least **3 different data sources** (e.g., Excel, database, text files).

### 1.2 Source Data Quality
- Choose **messy, uncleaned, low normal-form data** so you can perform ETL and upgrade it to the **3rd Normal Form (3NF)**.
- Do not use pre-cleaned datasets intended for data mining, such as those from Kaggle.

### 1.3 Bonus Criteria
- If you can successfully simulate **async data delay** arriving at the data source and show how it affects the ETL process, you will receive full points for the ETL grading column.

### 1.4 Infrastructure
- Set up at least **3 virtual machines (VMs)** to handle the flow: Source systems -> ETL -> DDS.

### 1.5 Mindset
- Assume the role of a manager and focus on how to use analytics to make decisions or create a competitive advantage.

## 2. Data Sources

### 2.1 Role
- The origin of your data, typically containing historical and daily operational transaction data (**OLTP**).

### 2.2 Key Criteria for Project
- Integrate data from disparate systems (e.g., **DB2, SQL Server, Oracle, or flat files**).
- Ensure the data has **inconsistencies, duplicates, or missing values** to justify your cleaning process.

## 3. ETL Process

### 3.1 Role
- Manage the full ETL pipeline from source systems into the data warehouse.
- This includes extracting source data, transforming it into a clean and normalized format, and loading it into staging, NDS, and DDS.

### 3.2 Extract - Hybrid Extraction Mechanism (Push & Pull)
- Extract data from source systems into the staging area using a hybrid approach that combines pulling bulk transactions and receiving pushed master data.
- This ensures real-time accuracy and performance.

#### 3.2.1 Proactive PUSH for Master Data
- Configure your source systems to actively **push master data changes** (e.g., new customers, updated addresses) to the staging area as soon as they occur.
- This prevents the **Late Arriving Dimension** problem and ensures your Master Data Management (MDM) is up to date.

#### 3.2.2 Incremental PULL for Transactional Data
- For heavy daily transactions (e.g., sales, orders), use the traditional **incremental extract method**.
- Strictly track the **LSET** (Last Successful Extraction Time) and **CET** (Current Extraction Time) to pull only the newly created or updated transactional records without overloading the system.

### 3.3 Transform
- This is where raw data is converted into a format suitable for your warehouse.
- Key actions include:
  - **Formatting:** Standardize data types, convert dates into a uniform format, and trim leading zeros or blank spaces.
  - **Lookup & Standardization:** Convert codes into readable formats using auxiliary reference tables (e.g., translate a customer status code "2" to "Active", or category "Pop music" to an ID such as "54").
  - **Aggregation:** Roll up data into higher levels of granularity if your warehouse requires summarized metrics rather than raw transaction lines.

### 3.4 Load
- The loading process happens in multiple phases depending on the architecture.

#### 3.4.1 Loading to Staging
- Data is moved into the staging area fast. You should **not arbitrarily create database indexes or constraints** here, because the goal is to evaluate data quality and catch bad data before it enters the warehouse.
- Storage should be managed effectively (for example, keeping 5 days of data) to allow quick recovery without re-extracting from the source.

#### 3.4.2 Loading to NDS (Normalized Data Store)
- Data is loaded here in 3rd Normal Form (3NF).
- You must enforce load ordering: **Master tables** (reference data like `store_type`) must be loaded before **Transaction tables** (like `store` or `sales`).
- You will implement **upsert rules** and manage surrogate keys at this stage.

#### 3.4.3 Loading to DDS (Dimensional Data Store)
- Data is pulled incrementally from the NDS.
- In this stage, you perform **denormalization** (for example, joining `store` and `store_type` back together).
- **Dimension tables must be loaded before Fact tables**, taking care of Slowly Changing Dimensions (SCD Types 1, 2, or 3).
- Once dimensions are updated, fact tables are loaded by looking up the appropriate surrogate keys from the dimension tables.

### 3.5 Handling Specific Scenarios

#### 3.5.1 Handle Late Master Data (Late Arriving Dimensions)
- This occurs when a transaction (like a sale) arrives at the warehouse before the master data (like a customer registration) has been synced.
- **Staging Fallback:** Query the customer master table. If the Customer SK is not found, temporarily hold the transaction in staging. Wait until the delayed master data arrives the next day, then push the transaction into the NDS/DDS.
- **Skeleton Creation (MDM approach):** Automatically generate a skeleton record in the dimension table containing only the newly discovered ID and leaving other attributes blank. The transaction can map to this skeleton and will be updated with full details once the actual master data is pushed.

#### 3.5.2 Handle Upsert Rules
- "Upsert" means updating a record if it already exists or inserting it if it is new.
- When loading external or messy data, identical objects may have slight spelling variations (e.g., "Congo" vs. "Congo (Zaire)"). Simply upserting may accidentally create a duplicate row.
- To handle this properly, your ETL tool should use **fuzzy matching** (approximate search) to identify the same entity and merge it effectively rather than inserting a redundant row.

#### 3.5.3 Detect Source Data Changes/Issues
- **Detecting New/Updated Data:** Use incremental extraction. Track the LSET (Last Successful Extraction Time) and CET (Current Extraction Time). Extract records where `create_timestamp` or `last_update_timestamp` is `>= LSET` and `< CET`.
- **Detecting Deleted Data:** To know if a record was deleted at the source, either compare primary keys between the source and the warehouse (if a key is missing, mark it as deleted in the DW) or use database triggers at the source to write deleted IDs to an audit table that the ETL process reads.

#### 3.5.4 Handle Business Rules, Duplicate/Object Matching, and Data Leak Checks
- **Business Rules (Data Quality):** Establish strict rules such as an email address must contain `@`, item prices cannot be 0, or an Amsterdam address cannot be in California state.
- Configure the staging firewall to either reject bad data, allow it with warnings, or correct it before it proceeds.
- **Duplicate/Object Matching:** Automate object matching for products using unique identifiers like barcodes or SKUs. For customers or entities where details change over time, combine automated matching with manual review to avoid merging the wrong financial or private data.
- **Data Leak Checks:** To ensure the ETL process did not drop or miss any records, implement a checksum technique or compare the `TotalRowCount` between source tables and destination tables.

## 4. Staging Area (Combined & Concise)

### 4.1 Role & Fundamentals
- A temporary storage zone designed to integrate data from multiple sources (e.g., SQL, Excel, ERP) while minimizing the performance impact on operational source systems.
- It acts as the central processing hub for data cleansing, formatting transformations, and quality validation before data enters the main warehouse.

### 4.2 Key Criteria for Project
- **No Indexes:** Do not arbitrarily create database indexes or complex constraints in the staging area, as it is optimized for fast data ingestion and processing rather than querying.
- **Strict Data Quality (DQ):** Implement DQ rules to act as a firewall against bad data.
  - Evaluate records to either reject them, allow them with warnings, or correct them before moving forward.
- **Data Recovery & Auditing:** Retain temporary data batches (e.g., keeping data from previous days) to ensure quick recovery if the data warehouse load fails, preventing the need to re-extract from source systems.
  - This temporary storage also supports data auditing by allowing you to compare the source data against the cleaned data.

## 5. ODS (Operational Data Store)

### 5.1 Definition & Role
- The ODS is an internal or hybrid database designed to temporarily organize data for the data warehouse.
- Unlike the main warehouse, the ODS is updated continuously during daily operations and is primarily used for **short-term operational decision-making**.

### 5.2 Architecture
- The ODS can be used as an integration layer between source systems and the DDS.
- When used alongside a DDS, the DDS can inherit surrogate key management from the ODS.

### 5.3 Structure
- Data in an ODS is typically normalized (for example, in 2nd Normal Form).
- When an ODS is used purely to integrate two source systems, it does not contain surrogate keys, dimensions, or fact tables; it simply unions reference and transaction data together.

## 6. NDS (Normalized Data Store)

### 6.1 Role
- The master data store that keeps transaction history and versions of transaction data for the entire organization.

### 6.2 Key Criteria for Project
- **Normalization:** The NDS must strictly adhere to the **3rd Normal Form (3NF)** with no redundant data.
- **Table Types:** Include **Master Tables** (reference data like products, customers) and **Transaction Tables** (business events like orders, payments).
- **Loading Rules:** Handle data deduplication and ensure the correct insertion order (e.g., load reference data like `store_type` before loading the actual `store` data).
- **Upsert Mechanism:** Use the **upsert rule** (update if it exists, insert if it does not) when loading data into the NDS.

## 7. DDS (Dimensional Data Store)

### 7.1 Role
- The user-facing data store designed for querying and analysis, organized in a denormalized format.

### 7.2 Key Criteria for Project
- **Dimensional Modeling:** Design your model using a **Star, Snowflake, or Galaxy schema**.
- **Fact Grain:** Clearly define the **Fact Grain** — the exact level of detail for a single row in the fact table (for example, one product sold at one store on one day).
- **SCD Implementation:** Implement **Slowly Changing Dimensions (SCD)** to handle historical changes.
  - Use **SCD Type 1** (overwrite) for simple corrections.
  - Use **SCD Type 2** (add new row) for fast-changing data you want to track.
  - Use **SCD Type 3** (add new column) for infrequent changes.
- **Data Mapping:** Create a mapping document that traces each column in the DDS back to its source system, including data types, source codes, and transformation rules to prevent data leakage.

## 8. CUBE & OLAP

### 8.1 Role
- Compressing and pre-calculating DDS data into a **Multidimensional Database (MDB)** for lightning-fast querying.

### 8.2 Key Criteria for Project
- **Cube Creation:** Automatically convert your DDS into cubes using tools like Microsoft SSAS.
- **OLAP Operations:** Ensure your cube supports interactive multidimensional operations: **Slice, Dice, Drill down/up, and Pivot**.
- **MDX Querying:** Be prepared to use **MDX (Multi-Dimensional Expressions)** to query the cube for specific business metrics.

## 9. Users (BI Applications)

### 9.1 Role
- The front-end interface where managers consume the processed data.

### 9.2 Key Criteria for Project
- Connect your Cube/DDS to BI tools to perform **Data Visualization, OLAP analysis, and Data Mining**.
- Design reports or dashboards that fulfill the three levels of business analytics:
  - **Descriptive** (what happened)
  - **Predictive** (what will happen)
  - **Prescriptive** (what should I do)
