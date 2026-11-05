# 📦 Module 2: Olist Brazilian E-Commerce Schema Deep Dive

## 1. Overview of the 9 Raw Relational Tables

The Olist dataset represents real, anonymized e-commerce orders placed between 2016 and 2018 in Brazil.

```
       olist_customers_dataset                olist_orders_dataset               olist_order_items_dataset
       ┌────────────────────────┐             ┌────────────────────────┐          ┌────────────────────────┐
       │customer_id (PK)        │────────────<│order_id (PK)           │─────────<│order_id (FK)           │
       │customer_unique_id      │             │customer_id (FK)        │          │order_item_id (PK)      │
       │customer_city           │             │order_status            │          │product_id (FK)         │
       │customer_state          │             │order_purchase_timestamp│          │seller_id (FK)          │
       └────────────────────────┘             │order_delivered_date    │          │price                   │
                                              └───────────┬────────────┘          │freight_value           │
                                                          │                       └───────────┬────────────┘
                         ┌────────────────────────────────┼───────────────┐                   │
                         │                                │               │                   ▼
                         ▼                                ▼               ▼          olist_products_dataset
              olist_order_payments            olist_order_reviews                 ┌────────────────────────┐
              ┌─────────────────────┐         ┌─────────────────────┐             │product_id (PK)         │
              │order_id (FK)        │         │review_id            │             │product_category_name   │
              │payment_sequential   │         │order_id (FK)        │             │product_weight_g        │
              │payment_type         │         │review_score         │             └───────────┬────────────┘
              │payment_value        │         └─────────────────────┘                         │
              └─────────────────────┘                                                         ▼
                                                                                   product_category_translation
                                                                                   ┌───────────────────────────┐
                                                                                   │product_category_name      │
                                                                                   │product_category_name_eng  │
                                                                                   └───────────────────────────┘
```

---

## 2. Critical Data Engineering Nuances & "Gotchas"

### ⚠️ Gotcha #1: `customer_id` vs. `customer_unique_id`
In `olist_customers_dataset`:
- `customer_id`: Assigned per order. Even if the same person makes 5 orders, they receive 5 different `customer_id` values!
- `customer_unique_id`: Identifies the physical human being across multiple purchases.
- **Data Engineering Rule**: In `dim_customers`, store both, but ensure Customer Lifetime Value (LTV), cohort analysis, and repeat-buyer flags are calculated using `customer_unique_id`.

### ⚠️ Gotcha #2: The Grain Mismatch (Order vs. Order Items)
- `orders` has 1 row per order.
- `order_items` has 1 row per item within an order (e.g., an order with 2 items has rows `order_item_id = 1` and `order_item_id = 2`).
- `payments` has 1 row per payment slice (an order can be split across a credit card and a voucher).
- **Data Engineering Rule**: If your Fact table is at the `order_items` grain, you cannot simply join `payments` directly without aggregating first, or you will cause a Cartesian product (fan-out) that duplicates revenue!

### ⚠️ Gotcha #3: Language Localization & Category Nulls
- Category names in `products` are in Portuguese (`cama_mesa_banho`, `relogios_presentes`).
- Some products have `NULL` categories.
- `product_category_name_translation` provides English equivalents (`bed_bath_table`, `watches_gifts`).
- **Data Engineering Rule**: Use `COALESCE` with a default unknown surrogate key (`-1` or `'unclassified'`) so missing categories do not drop records during `INNER JOIN` operations.

---

## 3. Designing the Target Dimensional Star Schema

```
              ┌───────────────────────────┐
              │         dim_date          │
              ├───────────────────────────┤
              │ date_sk (PK)              │
              │ full_date                 │
              │ year, quarter, month, day │
              │ day_of_week, is_weekend   │
              └─────────────┬─────────────┘
                            │
┌──────────────────┐        │        ┌──────────────────┐
│   dim_products   │        │        │  dim_customers   │
├──────────────────┤        ▼        ├──────────────────┤
│ product_sk (PK)  │   ┌─────────┐   │ customer_sk (PK) │
│ product_id (NK)  ├──>│  FACT   │<──┤ customer_id (NK) │
│ category_english │   │ ORDER   │   │ unique_id        │
│ weight_g, volume │   │  ITEMS  │   │ city, state      │
└──────────────────┘   └────┬────┘   └──────────────────┘
                            │
┌──────────────────┐        │        ┌──────────────────┐
│   dim_sellers    │        │        │  dim_order_status│
├──────────────────┤        ▼        ├──────────────────┤
│ seller_sk (PK)   │<───────┴───────>│ status_sk (PK)   │
│ seller_id (NK)   │                 │ status_name      │
│ city, state      │                 └──────────────────┘
└──────────────────┘
```

### Fact Table Grain:
**One row per item in an order.**
- Foreign Keys: `date_sk`, `product_sk`, `customer_sk`, `seller_sk`, `status_sk`
- Degenerate Dimensions: `order_id`, `order_item_id`
- Metrics: `price`, `freight_value`, `total_item_value`, `delivery_lead_time_days`, `review_score`
