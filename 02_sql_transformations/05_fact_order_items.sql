-- ============================================================================
-- 05_fact_order_items.sql
-- Central Fact Table in Star Schema
-- Grain: Exactly one row per item in an order.
-- ============================================================================

CREATE TABLE IF NOT EXISTS fact_order_items (
    fact_item_sk INT PRIMARY KEY,
    
    -- Foreign Keys to Dimension Tables
    date_sk INT NOT NULL,
    product_sk INT NOT NULL,
    customer_sk INT NOT NULL,
    seller_sk INT NOT NULL,
    
    -- Degenerate Dimensions (Business identifiers kept in fact table)
    order_id VARCHAR(32) NOT NULL,
    order_item_id INT NOT NULL,
    order_status VARCHAR(20) NOT NULL,
    
    -- Timestamps
    order_purchase_timestamp TIMESTAMP NOT NULL,
    order_delivered_date TIMESTAMP,
    order_estimated_date TIMESTAMP,
    
    -- Numeric Facts (Additive Metrics)
    item_price DECIMAL(10, 2) NOT NULL,
    freight_value DECIMAL(10, 2) NOT NULL,
    total_item_cost DECIMAL(10, 2) NOT NULL,
    
    -- Operational Logistics Metrics
    delivery_lead_time_days DECIMAL(6, 2),
    estimated_lead_time_days DECIMAL(6, 2),
    delivery_sla_delta_days DECIMAL(6, 2),
    is_delivered_late INT,
    
    -- Customer Satisfaction Fact
    order_review_score INT,
    
    FOREIGN KEY (date_sk) REFERENCES dim_date(date_sk),
    FOREIGN KEY (product_sk) REFERENCES dim_products(product_sk),
    FOREIGN KEY (customer_sk) REFERENCES dim_customers(customer_sk),
    FOREIGN KEY (seller_sk) REFERENCES dim_sellers(seller_sk)
);

-- Index foreign keys for lightning-fast OLAP joins
CREATE INDEX IF NOT EXISTS idx_fact_date ON fact_order_items(date_sk);
CREATE INDEX IF NOT EXISTS idx_fact_product ON fact_order_items(product_sk);
CREATE INDEX IF NOT EXISTS idx_fact_customer ON fact_order_items(customer_sk);
CREATE INDEX IF NOT EXISTS idx_fact_seller ON fact_order_items(seller_sk);

-- Populate fact table with dimensional lookups and derived logistics metrics
INSERT OR REPLACE INTO fact_order_items
SELECT 
    ROW_NUMBER() OVER (ORDER BY oi.order_id, oi.order_item_id) AS fact_item_sk,
    
    -- Date SK lookup
    COALESCE(
        CAST(STRFTIME('%Y%m%d', o.order_purchase_timestamp) AS INT), 
        -1
    ) AS date_sk,
    
    -- Surrogate Key Lookups (with fallback to -1 for orphaned records)
    COALESCE(dp.product_sk, -1) AS product_sk,
    COALESCE(dc.customer_sk, -1) AS customer_sk,
    COALESCE(ds.seller_sk, -1) AS seller_sk,
    
    -- Degenerate Dimensions
    oi.order_id,
    oi.order_item_id,
    o.order_status,
    
    -- Timestamps
    o.order_purchase_timestamp,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    
    -- Additive Measures
    oi.price AS item_price,
    oi.freight_value,
    ROUND(oi.price + oi.freight_value, 2) AS total_item_cost,
    
    -- Logistics Performance Calculations
    CASE 
        WHEN o.order_delivered_customer_date IS NOT NULL 
        THEN ROUND(JULIANDAY(o.order_delivered_customer_date) - JULIANDAY(o.order_purchase_timestamp), 2)
        ELSE NULL 
    END AS delivery_lead_time_days,
    
    ROUND(JULIANDAY(o.order_estimated_delivery_date) - JULIANDAY(o.order_purchase_timestamp), 2) AS estimated_lead_time_days,
    
    CASE 
        WHEN o.order_delivered_customer_date IS NOT NULL 
        THEN ROUND(JULIANDAY(o.order_estimated_delivery_date) - JULIANDAY(o.order_delivered_customer_date), 2)
        ELSE NULL 
    END AS delivery_sla_delta_days,
    
    CASE 
        WHEN o.order_delivered_customer_date IS NOT NULL AND JULIANDAY(o.order_delivered_customer_date) > JULIANDAY(o.order_estimated_delivery_date) THEN 1
        WHEN o.order_delivered_customer_date IS NOT NULL THEN 0
        ELSE NULL
    END AS is_delivered_late,
    
    -- Aggregated Review Score per Order (preventing review duplicates)
    rev.avg_review_score AS order_review_score

FROM raw_order_items oi
JOIN raw_orders o ON oi.order_id = o.order_id
LEFT JOIN dim_products dp ON oi.product_id = dp.product_id
LEFT JOIN dim_customers dc ON o.customer_id = dc.customer_id
LEFT JOIN dim_sellers ds ON oi.seller_id = ds.seller_id
LEFT JOIN (
    SELECT order_id, ROUND(AVG(review_score)) AS avg_review_score
    FROM raw_order_reviews
    GROUP BY order_id
) rev ON oi.order_id = rev.order_id;
