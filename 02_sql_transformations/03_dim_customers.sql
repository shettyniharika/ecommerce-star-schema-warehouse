-- ============================================================================
-- 03_dim_customers.sql
-- Customer Dimension: Bridges transaction-level customer_id with persistent
-- customer_unique_id, enabling both order-grain joins and customer LTV analysis.
-- ============================================================================

CREATE TABLE IF NOT EXISTS dim_customers (
    customer_sk INT PRIMARY KEY,                     -- Surrogate Key
    customer_id VARCHAR(32) NOT NULL UNIQUE,         -- Order-level transaction key
    customer_unique_id VARCHAR(32) NOT NULL,         -- Persistent human customer ID
    customer_zip_prefix VARCHAR(10),
    customer_city VARCHAR(100),
    customer_state VARCHAR(2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Fallback record for unmatched customer keys
INSERT OR REPLACE INTO dim_customers (
    customer_sk, customer_id, customer_unique_id, 
    customer_zip_prefix, customer_city, customer_state
) VALUES (
    -1, 'UNKNOWN_CUSTOMER', 'UNKNOWN_HUMAN', '00000', 'Unknown', 'NA'
);

-- Populate transformed dim_customers
INSERT OR REPLACE INTO dim_customers (
    customer_sk,
    customer_id,
    customer_unique_id,
    customer_zip_prefix,
    customer_city,
    customer_state
)
SELECT 
    ROW_NUMBER() OVER (ORDER BY c.customer_id) AS customer_sk,
    c.customer_id,
    c.customer_unique_id,
    c.customer_zip_code_prefix,
    UPPER(TRIM(c.customer_city)) AS customer_city,
    UPPER(TRIM(c.customer_state)) AS customer_state
FROM raw_customers c;
