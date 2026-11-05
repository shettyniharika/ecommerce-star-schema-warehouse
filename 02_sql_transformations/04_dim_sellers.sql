-- ============================================================================
-- 04_dim_sellers.sql
-- Seller Dimension: Manages vendor geographic locations and surrogate keys.
-- ============================================================================

CREATE TABLE IF NOT EXISTS dim_sellers (
    seller_sk INT PRIMARY KEY,                      -- Surrogate Key
    seller_id VARCHAR(32) NOT NULL UNIQUE,          -- Natural Business Key
    seller_zip_prefix VARCHAR(10),
    seller_city VARCHAR(100),
    seller_state VARCHAR(2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Fallback record for unmatched sellers
INSERT OR REPLACE INTO dim_sellers (
    seller_sk, seller_id, seller_zip_prefix, seller_city, seller_state
) VALUES (
    -1, 'UNKNOWN_SELLER', '00000', 'Unknown', 'NA'
);

-- Populate transformed dim_sellers
INSERT OR REPLACE INTO dim_sellers (
    seller_sk,
    seller_id,
    seller_zip_prefix,
    seller_city,
    seller_state
)
SELECT 
    ROW_NUMBER() OVER (ORDER BY s.seller_id) AS seller_sk,
    s.seller_id,
    s.seller_zip_code_prefix,
    UPPER(TRIM(s.seller_city)) AS seller_city,
    UPPER(TRIM(s.seller_state)) AS seller_state
FROM raw_sellers s;
