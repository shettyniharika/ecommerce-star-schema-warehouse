# 🧪 Lab 1: Defining Grains & Fact Table Fan-Out Traps

## 🎯 Objective
Learn how to identify and avoid the dreaded **Fact Table Fan-Out / Double-Counting Trap** when joining tables of differing granularities.

---

## 🛑 The Problem Scenario
An analytics engineer submits the following query to calculate total sales revenue and total payment value by state:

```sql
-- FLAWED QUERY:
SELECT 
    c.customer_state,
    SUM(oi.price) AS total_item_revenue,
    SUM(p.payment_value) AS total_payment_value
FROM raw_orders o
JOIN raw_order_items oi ON o.order_id = oi.order_id
JOIN raw_order_payments p ON o.order_id = p.order_id
JOIN raw_customers c ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state;
```

When finance audits this report against bank receipts, `total_item_revenue` is inflated by 35% and `total_payment_value` is inflated by 42%!

### Why did this happen?
1. An order can have **multiple items** (e.g., 3 items).
2. An order can have **multiple payments** (e.g., split across credit card and voucher = 2 payment rows).
3. Joining `order_items` (grain: item) to `order_payments` (grain: payment slice) creates a Cartesian product of $3 \times 2 = 6$ rows for that single order!
4. `SUM(oi.price)` sums each item price twice, and `SUM(p.payment_value)` sums each payment slice three times!

---

## 🛠️ The Data Engineering Solution
There are two production patterns to solve this:

### Pattern A: Pre-aggregate before joining
Aggregate the secondary child table to the `order_id` grain *before* joining:
```sql
WITH payment_agg AS (
    SELECT 
        order_id, 
        SUM(payment_value) AS order_total_payment
    FROM raw_order_payments
    GROUP BY order_id
),
items_agg AS (
    SELECT 
        order_id, 
        SUM(price) AS order_total_revenue
    FROM raw_order_items
    GROUP BY order_id
)
SELECT 
    c.customer_state,
    SUM(i.order_total_revenue) AS total_item_revenue,
    SUM(p.order_total_payment) AS total_payment_value
FROM raw_orders o
JOIN items_agg i ON o.order_id = i.order_id
JOIN payment_agg p ON o.order_id = p.order_id
JOIN raw_customers c ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state;
```

### Pattern B: Kimball Dimensional Separation
In Kimball design, **never mix distinct business processes into the same fact table**.
- `fact_order_items`: Captures sales transactions at the item grain.
- `fact_payments`: Captures payment transactions at the payment slice grain.
- If a report requires comparing revenue against collections, query both fact tables independently and join them at a conformed dimension level (e.g. `dim_date` or `dim_customers`).

---

## 📝 Practice Exercise for You:
1. Open the SQLite database at `data/olist_warehouse.db`.
2. Write a SQL query against `fact_order_items` and `dim_customers` to compute:
   - Total delivered item revenue per customer state.
   - Average delivery turnaround time (`delivery_lead_time_days`).
   - Late delivery rate (`is_delivered_late`).
3. Check if there are states where delivery SLA failure is significantly higher than the national average!
