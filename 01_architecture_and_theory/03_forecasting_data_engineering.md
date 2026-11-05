# 📈 Module 3: Engineering the Forecasting Base Mart

## 1. The Bridge Between Dimensional Modeling and Forecasting

Farrokh Ahmadi’s *"Decision Layer 1"* highlights a crucial divide in enterprise data architectures:
- **The Data Warehouse (Star Schema)** captures historical transactions with high granularity (order item level).
- **The Forecasting Engine (Decision Layer)** requires clean, equidistant, non-interrupted time-series features.

A **Data Engineer's job** is to build the transformation mart that converts the transactional Star Schema into the ML-ready Feature Mart.

```
┌────────────────────────┐      Aggregation      ┌─────────────────────────┐      Windowing / Lags      ┌─────────────────────────┐
│   fact_order_items     │ ────────────────────> │  Intermediate Daily     │ ─────────────────────────> │   forecasting_base_mart │
│  (Grain: Item Level)   │  + Calendar Scaffold  │  (Grain: Day x Category)│      (Feature Store)       │  (Demand, Lags, RollAvg)│
└────────────────────────┘                       └─────────────────────────┘                            └─────────────────────────┘
```

---

## 2. The 3 Core Data Engineering Challenges in Forecasting

### Challenge #1: The Missing Dates Trap (Zero-Filling Scaffolding)
In raw transaction data, if no customer buys a product in a category on a Tuesday, there are simply no rows in the database for that day.
If you run:
```sql
SELECT order_date, category, SUM(revenue) 
FROM fact_order_items 
GROUP BY 1, 2;
```
Tuesday will be **completely missing**!
If an ML engineer feeds this directly into a forecasting model (like ARIMA, Prophet, or LSTM), the model will either crash or treat Wednesday as the day immediately following Monday, completely distorting time-series frequency and seasonality!

**The Data Engineering Solution (Cartesian Calendar Spine):**
```sql
WITH calendar_spine AS (
    SELECT full_date FROM dim_date WHERE full_date BETWEEN '2017-01-01' AND '2018-08-31'
),
category_spine AS (
    SELECT DISTINCT product_category_english FROM dim_products WHERE product_category_english IS NOT NULL
),
scaffold AS (
    -- Cross join guarantees EVERY category has an entry for EVERY single calendar day
    SELECT c.full_date, cat.product_category_english
    FROM calendar_spine c
    CROSS JOIN category_spine cat
)
SELECT 
    s.full_date,
    s.product_category_english,
    COALESCE(SUM(f.price), 0.0) AS daily_revenue,
    COALESCE(COUNT(f.fact_item_sk), 0) AS daily_units_sold
FROM scaffold s
LEFT JOIN fact_order_items f 
    ON s.full_date = f.order_date 
    AND s.product_category_english = f.product_category_english
GROUP BY 1, 2;
```

---

### Challenge #2: Preventing Temporal Data Leakage
Data leakage occurs when information from the future is inadvertently used to compute features for the past.
- **Leakage Violation**: Using the global mean of sales across the entire year to normalize features for March.
- **Correct DE Implementation**: Always use strictly windowed operations with `ROWS BETWEEN ... PRECEDING AND 1 PRECEDING`:
```sql
-- Correct lag and rolling 7-day demand calculation without peeking into the current day
AVG(daily_units_sold) OVER (
    PARTITION BY product_category_english 
    ORDER BY full_date 
    ROWS BETWEEN 7 PRECEDING AND 1 PRECEDING
) AS rolling_avg_7d_demand
```

---

### Challenge #3: Calendar Seasonality & Holiday Signals
Demand in e-commerce fluctuates heavily based on calendar effects:
- Day of Week (e.g., higher conversions on Sunday vs. Friday)
- Month of Year & End-of-Month paydays
- Special retail holidays (Black Friday, Cyber Monday, Christmas)

In `dim_date`, these are encoded as deterministic flags (`is_weekend`, `is_holiday_br`, `day_of_week`), allowing models to capture structural shifts effortlessly.
