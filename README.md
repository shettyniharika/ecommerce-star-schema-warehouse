# 🚀 Data Engineering Mastery: Star Schema & Forecasting Base
> **Hands-on curriculum & architectural blueprint inspired by Farrokh Ahmadi’s *"Decision Layer 1: Star Schema & Forecasting Base"***  
> **Dataset**: Brazilian E-Commerce Public Dataset by Olist (Kaggle)

---

## 📌 Project Overview & Objectives

In real-world enterprise environments (like retail and PIM systems), raw operational databases are optimized for **OLTP** (Online Transaction Processing) with strict normalization (3NF) to maximize transactional write throughput and eliminate data redundancy. 

However, analytical queries, business intelligence, and forecasting models struggle with 3NF because running complex analytical queries across 8+ joined transactional tables causes massive compute overhead and locking issues.

**Decision Layer 1** teaches you the core Data Engineering discipline of transforming raw, operational OLTP data into an **OLAP Dimensional Model (Star Schema)**, and subsequent **Forecasting Marts**.

```
┌────────────────────────────────┐       ┌────────────────────────────────┐       ┌────────────────────────────────┐
│        RAW OLTP SYSTEM         │       │       DIMENSIONAL WAREHOUSE    │       │        DECISION LAYER          │
│  (Normalized 3NF Relational)   │ ────> │          (Star Schema)         │ ────> │       (Forecasting Base)       │
│  9 Tables (Orders, Items, etc) │  ETL  │ Fact: fact_order_items         │  Mart │ Grain: Date x Category         │
│  High write speed, low BI perf │       │ Dims: Product, Customer, Date  │       │ Demand Signals & Feature Store │
└────────────────────────────────┘       └────────────────────────────────┘       └────────────────────────────────┘
```

---

## 📂 Project Structure

```
DataEngineering-StarSchema/
├── README.md                                  # Curriculum roadmap and architectural guide
├── 01_architecture_and_theory/
│   ├── 01_oltp_vs_olap_dimensional_modeling.md # Kimball vs Inmon, Fact vs Dimension, Star vs Snowflake
│   ├── 02_olist_schema_deep_dive.md            # Mapping the 9 raw Olist tables & identifying business grains
│   └── 03_forecasting_data_engineering.md      # Feature engineering, time-series scaffolding, zero-filling
├── 02_sql_transformations/
│   ├── 00_raw_tables_schema.sql                # DDL for raw Olist staging tables
│   ├── 01_dim_date.sql                         # Calendar dimension (seasonality, holiday flags, fiscal quarters)
│   ├── 02_dim_products.sql                     # Product dimension with category translation & surrogate keys
│   ├── 03_dim_customers.sql                    # Customer dimension (customer_id vs customer_unique_id)
│   ├── 04_dim_sellers.sql                      # Seller dimension with regional location data
│   ├── 05_fact_order_items.sql                 # Central Fact table: grain, additive metrics, SLA turnaround
│   └── 06_forecasting_base_mart.sql            # Aggregated analytics mart for demand forecasting baselines
├── 03_pipeline_code/
│   ├── sample_data_generator.py                # Generates a realistic local Olist sample dataset
│   ├── pipeline.py                             # Automated ETL pipeline (extracts, transforms, loads to SQLite/DuckDB)
│   └── requirements.txt                        # Python dependencies
└── 04_exercises_and_challenges/
    ├── lab_01_grain_and_surrogate_keys.md      # Hands-on exercises testing grain definition & key generation
    └── lab_02_slowly_changing_dimensions.md    # SCD Type 1 vs Type 2 tracking for price/category shifts
```

---

## 🗺️ Step-by-Step Learning Path

| Step | Topic | What You Will Learn |
| :--- | :--- | :--- |
| **Module 1** | **Dimensional Modeling Theory** | 4-step Kimball design process, determining the business grain, surrogate vs natural keys, additive vs semi-additive facts. |
| **Module 2** | **Olist Dataset Deconstruction** | Relational integrity of Olist's 9 tables, handling multi-item orders, multiple payment methods, and Portuguese category translations. |
| **Module 3** | **SQL Transformation Pipeline** | Writing production SQL DDL/DML to build `dim_date`, `dim_products`, `dim_customers`, and `fact_order_items`. |
| **Module 4** | **Forecasting Mart Engineering** | Time-series scaffolding (generating missing date rows with continuous zero-filling), avoiding future data leakage, and lag feature creation. |
| **Module 5** | **Hands-on Labs & Execution** | Running the Python/SQL pipeline locally, inspecting query performance, and implementing SCD Type 2 tracking. |

---

## 🔗 Resources & References
- **Kaggle Notebook**: [Decision Layer 1: Star Schema & Forecasting Base by Farrokh Ahmadi](https://www.kaggle.com/code/farrokhahmadi/decision-layer-1-star-schema-and-a-forecasting-ba/notebook)
- **Kaggle Dataset**: [Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)
