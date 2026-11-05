-- ============================================================================
-- 02_dim_products.sql
-- Product Dimension: Generates integer surrogate key, translates Portuguese
-- categories to English, computes derived volumetric metrics, and handles NULLs.
-- ============================================================================

CREATE TABLE IF NOT EXISTS dim_products (
    product_sk INT PRIMARY KEY,                       -- Surrogate Key
    product_id VARCHAR(32) NOT NULL UNIQUE,          -- Natural Business Key
    product_category_pt VARCHAR(100) NOT NULL,
    product_category_en VARCHAR(100) NOT NULL,
    product_weight_kg DECIMAL(8, 3),
    product_volume_cm3 DECIMAL(12, 2),
    product_photos_qty INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert fallback record for missing/unmatched products
INSERT OR REPLACE INTO dim_products (
    product_sk, product_id, product_category_pt, product_category_en, 
    product_weight_kg, product_volume_cm3, product_photos_qty
) VALUES (
    -1, 'UNKNOWN_PRODUCT', 'desconhecido', 'unclassified', 0.0, 0.0, 0
);

-- Populate transformed dim_products
INSERT OR REPLACE INTO dim_products (
    product_sk,
    product_id,
    product_category_pt,
    product_category_en,
    product_weight_kg,
    product_volume_cm3,
    product_photos_qty
)
SELECT 
    ROW_NUMBER() OVER (ORDER BY p.product_id) AS product_sk,
    p.product_id,
    COALESCE(p.product_category_name, 'desconhecido') AS product_category_pt,
    COALESCE(t.product_category_name_english, 'unclassified') AS product_category_en,
    ROUND(COALESCE(p.product_weight_g, 0) / 1000.0, 3) AS product_weight_kg,
    ROUND(
        COALESCE(p.product_length_cm, 0) * 
        COALESCE(p.product_height_cm, 0) * 
        COALESCE(p.product_width_cm, 0), 2
    ) AS product_volume_cm3,
    COALESCE(p.product_photos_qty, 0) AS product_photos_qty
FROM raw_products p
LEFT JOIN raw_product_category_translation t
    ON p.product_category_name = t.product_category_name;
