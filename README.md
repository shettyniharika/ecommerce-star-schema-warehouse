# E-Commerce Dimensional Data Warehouse & Forecasting Baseline

An end-to-end data engineering project focused on transforming raw relational e-commerce transactional data into an optimized **Star Schema (Dimensional Model)**, paired with an analytical baseline for demand and temporal forecasting. 

This repository demonstrates the design pattern of decoupling raw ingestion from analytical consumption, optimizing query performance for heavy BI workloads, and establishing a robust semantic foundation for predictive modeling.

---

## 🛠️ Architecture & Data Engineering Workflow
```text
[ Raw Transactional Sources (Olist Dataset) ]
│
▼
[ Ingestion & Staging Layer ]
│
▼
[ Dimensional Modeling (Star Schema) ]
├── Fact Tables (Orders, Order Items, Payments)
└── Dimension Tables (Customer, Product, Temporal, Geography)
│
▼
[ Analytical / Decision Layer (Forecasting Baseline) ]
```

1. **Staging & Cleansing:** Handled missing attributes, standardized date-time hierarchies, and resolved referential integrity issues from multi-source operational records.
2. **Dimensional Design (Star Schema):** 
   - Structured **Fact Tables** to capture granular operational metrics, order items, and payment transactions without data duplication.
   - Designed standardized **Dimension Tables** to facilitate fast filtering, rollups, and aggregations across temporal, geographical, and product hierarchies.
3. **Analytical & Forecasting Baseline:** Integrated an exploratory baseline layer to evaluate temporal sales patterns and intermittent demand behaviors, ensuring the warehouse model easily feeds downstream predictive pipelines.

---

## 📂 Repository Layout

```text
├── data/                    # Sample datasets / instructions for pipeline execution
├── notebooks/               # Step-by-step EDA, data transformation, and modeling logic
├── sql/                     # DDL scripts, table creation, and dimensional queries
└── src/                     # Reusable Python scripts for pipeline automation and processing
```

---

## ⚙️ Key Technical Highlights & Learnings

**Performance-First Modeling:** Designed normalized dimension and fact structures to eliminate costly table joins, reduce query latency, and optimize scan costs for large-scale analytical tools (e.g., Snowflake, BigQuery, Power BI).

**Handling Data Quality & Granularity:** Implemented robust handling for missing keys, data type mismatches, and grain-matching across disparate order and item-level relations.

**Bridging Engineering & Analytics:** Built a clean architectural boundary where data engineering outputs (the star schema) seamlessly power downstream data science workloads (forecasting models) without tight coupling.

---

## 🚀 Tech Stack

**Languages:** Python, SQL

**Data Manipulation:** Pandas, NumPy

**Database / Query Engine:** DuckDB / SQLite / Relational Storage

**Architecture Concepts:** Star Schema, Fact/Dimension Normalization, Dimensional Modeling, Time-Series Feature Baselines
