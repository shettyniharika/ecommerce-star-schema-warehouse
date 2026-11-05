-- ============================================================================
-- 06_forecasting_base_mart.sql
-- Decision Layer 1: Production Forecasting Base Mart
-- Grain: One row per Calendar Date x Product Category
-- Features: Zero-filling, non-leaking lags, moving averages, and seasonality.
-- ============================================================================

CREATE TABLE IF NOT EXISTS forecasting_base_mart (
    mart_id INT PRIMARY KEY,
    snapshot_date DATE NOT NULL,
    date_sk INT NOT NULL,
    product_category_en VARCHAR(100) NOT NULL,
    
    -- Target Forecast Variables
    daily_units_sold INT NOT NULL,
    daily_gross_revenue DECIMAL(12, 2) NOT NULL,
    daily_avg_item_price DECIMAL(10, 2),
    
    -- Calendar & Seasonality Indicators
    day_of_week INT NOT NULL,
    is_weekend INT NOT NULL,
    month_num INT NOT NULL,
    day_of_month INT NOT NULL,
    
    -- Non-Leaking Time-Series Lags (T-1, T-7 weekly seasonal, T-14)
    lag_units_1d INT,
    lag_units_7d INT,
    lag_units_14d INT,
    
    -- Moving Averages (Preceding windows excluding current day T)
    rolling_avg_7d_units DECIMAL(10, 2),
    rolling_avg_14d_units DECIMAL(10, 2),
    rolling_avg_30d_units DECIMAL(10, 2),
    
    -- Demand Momentum Indicator
    momentum_7d_vs_30d_ratio DECIMAL(6, 3)
);

CREATE INDEX IF NOT EXISTS idx_forecast_date_cat ON forecasting_base_mart(snapshot_date, product_category_en);

-- Populate Mart with Zero-Filled Calendar Scaffolding
INSERT OR REPLACE INTO forecasting_base_mart
WITH 
-- Step 1: Define continuous active date range
calendar_spine AS (
    SELECT full_date, date_sk, day_of_week, is_weekend, month_num, day_of_month
    FROM dim_date
    WHERE full_date BETWEEN '2017-01-01' AND '2018-08-31'
),

-- Step 2: Extract active product categories
category_spine AS (
    SELECT DISTINCT product_category_en
    FROM dim_products
    WHERE product_category_en NOT IN ('unclassified', 'desconhecido')
),

-- Step 3: Scaffold Cartesian product (guarantees contiguous time-series)
scaffold AS (
    SELECT 
        c.full_date,
        c.date_sk,
        c.day_of_week,
        c.is_weekend,
        c.month_num,
        c.day_of_month,
        cat.product_category_en
    FROM calendar_spine c
    CROSS JOIN category_spine cat
),

-- Step 4: Aggregate actual transactions at Date x Category grain
daily_actuals AS (
    SELECT 
        d.full_date,
        dp.product_category_en,
        COUNT(f.fact_item_sk) AS units_sold,
        SUM(f.item_price) AS gross_revenue,
        AVG(f.item_price) AS avg_item_price
    FROM fact_order_items f
    JOIN dim_date d ON f.date_sk = d.date_sk
    JOIN dim_products dp ON f.product_sk = dp.product_sk
    WHERE f.order_status = 'delivered'
    GROUP BY d.full_date, dp.product_category_en
),

-- Step 5: Join actuals onto scaffold and zero-fill missing days
zero_filled AS (
    SELECT 
        s.full_date,
        s.date_sk,
        s.product_category_en,
        COALESCE(a.units_sold, 0) AS daily_units_sold,
        COALESCE(ROUND(a.gross_revenue, 2), 0.0) AS daily_gross_revenue,
        COALESCE(ROUND(a.avg_item_price, 2), 0.0) AS daily_avg_item_price,
        s.day_of_week,
        s.is_weekend,
        s.month_num,
        s.day_of_month
    FROM scaffold s
    LEFT JOIN daily_actuals a 
        ON s.full_date = a.full_date 
        AND s.product_category_en = a.product_category_en
),

-- Step 6: Compute windowed lags and rolling averages (strictly non-leaking)
engineered_features AS (
    SELECT 
        full_date,
        date_sk,
        product_category_en,
        daily_units_sold,
        daily_gross_revenue,
        daily_avg_item_price,
        day_of_week,
        is_weekend,
        month_num,
        day_of_month,
        
        -- Lags
        LAG(daily_units_sold, 1) OVER (
            PARTITION BY product_category_en ORDER BY full_date
        ) AS lag_units_1d,
        LAG(daily_units_sold, 7) OVER (
            PARTITION BY product_category_en ORDER BY full_date
        ) AS lag_units_7d,
        LAG(daily_units_sold, 14) OVER (
            PARTITION BY product_category_en ORDER BY full_date
        ) AS lag_units_14d,
        
        -- Rolling Averages (excluding current day: 1 preceding back)
        ROUND(AVG(daily_units_sold) OVER (
            PARTITION BY product_category_en ORDER BY full_date
            ROWS BETWEEN 7 PRECEDING AND 1 PRECEDING
        ), 2) AS rolling_avg_7d_units,
        
        ROUND(AVG(daily_units_sold) OVER (
            PARTITION BY product_category_en ORDER BY full_date
            ROWS BETWEEN 14 PRECEDING AND 1 PRECEDING
        ), 2) AS rolling_avg_14d_units,
        
        ROUND(AVG(daily_units_sold) OVER (
            PARTITION BY product_category_en ORDER BY full_date
            ROWS BETWEEN 30 PRECEDING AND 1 PRECEDING
        ), 2) AS rolling_avg_30d_units
        
    FROM zero_filled
)

SELECT 
    ROW_NUMBER() OVER (ORDER BY product_category_en, full_date) AS mart_id,
    full_date AS snapshot_date,
    date_sk,
    product_category_en,
    daily_units_sold,
    daily_gross_revenue,
    daily_avg_item_price,
    day_of_week,
    is_weekend,
    month_num,
    day_of_month,
    lag_units_1d,
    lag_units_7d,
    lag_units_14d,
    rolling_avg_7d_units,
    rolling_avg_14d_units,
    rolling_avg_30d_units,
    CASE 
        WHEN rolling_avg_30d_units > 0 
        THEN ROUND(rolling_avg_7d_units / rolling_avg_30d_units, 3)
        ELSE 1.000 
    END AS momentum_7d_vs_30d_ratio
FROM engineered_features;
