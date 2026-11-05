# 🔄 Lab 2: Slowly Changing Dimensions (SCD Type 1 vs. Type 2)

## 🎯 Objective
Understand how dimension attributes evolve over time, how to preserve historical accuracy for financial and forecasting audits, and how SCD Type 2 is implemented in retail & PIM.

---

## 1. The Real-World Scenario
In luxury retail or e-commerce marketplaces (like Olist or Coach/Tapestry):
- A merchant re-categorizes a handbag from `"totes"` to `"crossbody"`.
- A seller moves their warehouse from `"SP"` (São Paulo) to `"RJ"` (Rio de Janeiro).
- A supplier updates product dimensions or MSRP.

If you simply run an `UPDATE` statement on `dim_products`:
```sql
-- SCD Type 1: Overwrites history
UPDATE dim_products 
SET product_category_en = 'crossbody' 
WHERE product_id = 'prod_0042';
```
**Historical Distortion**: When finance runs sales reports for 2017, all items sold under `"totes"` in 2017 are now retroactively counted under `"crossbody"`! All historical category forecasting models are invalidated because the training ground truth shifted!

---

## 2. The 3 Standard Kimball SCD Types

| SCD Type | Mechanism | Pros | Cons | Use Case |
| :--- | :--- | :--- | :--- | :--- |
| **Type 1** | Overwrite existing record in-place | Simple, no row explosion | Erases historical truth | Correcting typos, phone numbers |
| **Type 2** | Insert a new row with date validity flags (`valid_from`, `valid_to`, `is_current`) | Full audit trail & point-in-time accuracy | Multiple rows per business key, requires surrogate key management | Category reclassification, customer address moves, price tier changes |
| **Type 3** | Add a new column (`previous_category`, `current_category`) | Easy previous-vs-current comparison | Only tracks 1 historical change | Department reorganizations |

---

## 3. Implementing SCD Type 2 in SQL

In an SCD Type 2 table, the Natural Key (`product_id`) appears multiple times, but each row has a unique Surrogate Key (`product_sk`):

```sql
CREATE TABLE dim_products_scd2 (
    product_sk INT PRIMARY KEY,
    product_id VARCHAR(32) NOT NULL,
    product_category_en VARCHAR(100) NOT NULL,
    
    -- SCD Type 2 Metadata Columns
    valid_from TIMESTAMP NOT NULL,
    valid_to TIMESTAMP,              -- NULL or '9999-12-31' indicates current active row
    is_current BOOLEAN NOT NULL       -- 1 if active, 0 if historical
);
```

### When a change occurs:
1. **Expire the old row**:
   ```sql
   UPDATE dim_products_scd2
   SET valid_to = CURRENT_TIMESTAMP,
       is_current = 0
   WHERE product_id = 'prod_0042' AND is_current = 1;
   ```
2. **Insert the new row**:
   ```sql
   INSERT INTO dim_products_scd2 (
       product_sk, product_id, product_category_en, valid_from, valid_to, is_current
   ) VALUES (
       (SELECT COALESCE(MAX(product_sk), 0) + 1 FROM dim_products_scd2),
       'prod_0042', 'crossbody', CURRENT_TIMESTAMP, NULL, 1
   );
   ```

### Point-in-Time Fact Table Join:
When loading historical facts, join using the timestamp of the transaction:
```sql
SELECT 
    f.order_id,
    f.item_price,
    p.product_category_en
FROM fact_order_items f
JOIN dim_products_scd2 p 
    ON f.product_id = p.product_id
    AND f.order_purchase_timestamp >= p.valid_from
    AND (f.order_purchase_timestamp < p.valid_to OR p.valid_to IS NULL);
```

---

## 📝 Practice Exercise for You:
1. Review `02_dim_products.sql` in `02_sql_transformations/`. Currently it is modeled as SCD Type 1.
2. Draft an updated DDL script `02b_dim_products_scd2.sql` that adds `valid_from`, `valid_to`, and `is_current`.
3. How would you join this SCD Type 2 dimension into `fact_order_items` without creating duplicate join rows?
