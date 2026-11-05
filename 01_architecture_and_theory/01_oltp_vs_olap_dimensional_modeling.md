# 📐 Module 1: OLTP vs. OLAP & Dimensional Modeling (The Kimball Methodology)

## 1. Why Dimensional Modeling Exists: The Friction Between OLTP and OLAP

In production engineering, you frequently encounter two vastly different database workloads:

| Characteristic | OLTP (Online Transaction Processing) | OLAP (Online Analytical Processing) |
| :--- | :--- | :--- |
| **Primary Goal** | Fast, reliable writes, ACID compliance, zero redundancy | Lightning-fast aggregations, reporting, model training |
| **Design Paradigm** | 3rd Normal Form (3NF) — highly normalized | Dimensional Modeling (Star / Snowflake Schema) |
| **Typical Queries** | `INSERT`, `UPDATE`, single-record `SELECT WHERE id = ?` | `SELECT category, SUM(revenue) ... GROUP BY 1, 2` |
| **Join Complexity** | Joins are kept to small lookups; normalized tables | Denormalized or flat stars; predictable 1-hop joins |
| **Data Integrity** | Enforced by foreign key constraints & cascading rules | Enforced at ETL ingestion & surrogate key generation |

### The Problem with Querying OLTP for Analytics:
Imagine computing monthly revenue by product category in a normalized 3NF database:
```sql
-- In 3NF: You must join 5+ tables, causing table scans and locking production tables
SELECT 
    t.product_category_name_english,
    STRFTIME('%Y-%m', o.order_purchase_timestamp) AS order_month,
    SUM(oi.price) AS total_revenue
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
JOIN product_category_name_translation t ON p.product_category_name = t.product_category_name
JOIN order_payments py ON o.order_id = py.order_id
WHERE o.order_status = 'delivered'
GROUP BY 1, 2;
```
If thousands of orders are being written concurrently, this query creates read-locks, consumes server memory, and executes slowly. 

---

## 2. The Kimball 4-Step Dimensional Design Process

Ralph Kimball established the industry-standard four-step process for building data warehouses:

### Step 1: Select the Business Process
Identify the real-world operational activity that generates data.
- *In Olist*: Customers placing orders and purchasing items.

### Step 2: Declare the Grain
**The grain is the most critical decision in Data Engineering.** It defines exactly what one individual row in the Fact table represents.
- *Option A*: One row per Order. (Too coarse: what if an order contains 3 different products?)
- *Option B*: One row per Order Item. (**Correct Grain**: captures distinct products, individual prices, and seller fulfillment).

### Step 3: Identify the Dimensions
Dimensions answer the *who, what, where, when, why, and how* of the business event:
- **Who**: `dim_customers`, `dim_sellers`
- **What**: `dim_products`
- **When**: `dim_date` (or `dim_time`)
- **How**: `dim_payment`

### Step 4: Identify the Facts (Numeric Measurements)
Facts are the quantitative measurements resulting from the business event at the declared grain:
- `price` (fully additive)
- `freight_value` (fully additive)
- `delivery_lead_time_days` (semi-additive / non-additive: averaging makes sense, summing does not)

---

## 3. Star Schema vs. Snowflake Schema

```
        STAR SCHEMA                             SNOWFLAKE SCHEMA
   (Preferred for OLAP/Warehouses)            (Partially Normalized Dimensions)

        ┌──────────────┐                            ┌──────────────┐
        │  dim_date    │                            │  dim_date    │
        └──────┬───────┘                            └──────┬───────┘
               │                                           │
  ┌────────────┴───┐   ┌──────────────┐      ┌─────────────┴──┐   ┌────────────────┐
  │fact_order_items│───┤dim_customers │      │fact_order_items├───┤ dim_customers  │
  └────────────┬───┘   └──────────────┘      └─────────────┬──┘   └───────┬────────┘
               │                                           │              │
        ┌──────┴───────┐                            ┌──────┴───────┐   ┌──┴────────────┐
        │ dim_products │                            │ dim_products │   │dim_cities/geo │
        └──────────────┘                            └──────┬───────┘   └───────────────┘
                                                           │
                                                    ┌──────┴───────────┐
                                                    │dim_subcategories │
                                                    └──────────────────┘
```

* **Star Schema**: Dimensions are completely denormalized. Each dimension links directly to the central Fact table with a single join. Modern analytical engines (Snowflake, BigQuery, DuckDB, ClickHouse) perform best on Star Schemas due to vectorization and reduced join overhead.
* **Snowflake Schema**: Dimensions are normalized into sub-tables (e.g., separating cities from customers). Rarely used today because compute savings do not justify the query complexity.

---

## 4. Surrogate Keys vs. Natural Keys

- **Natural Key (Business Key)**: The ID from the source system (e.g., `product_id = "1e9e8ef04daac454f0d18f9027eec304"`).
- **Surrogate Key (Warehouse Key)**: A synthetic, warehouse-managed integer (e.g., `product_sk = 1042`).

### Why use Surrogate Keys?
1. **Performance**: Joining on 4-byte or 8-byte integers (`INT`) is much faster than joining on 32-character UUID strings.
2. **System Independence**: Protects the warehouse if operational systems change formats or reset ID counters.
3. **Slowly Changing Dimensions (SCD Type 2)**: If a product's category changes, you keep two rows with the same natural key but different surrogate keys and date validity ranges (`valid_from`, `valid_to`).
