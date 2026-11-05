-- ============================================================================
-- 01_dim_date.sql
-- Calendar Dimension with Kimball-standard integer surrogate key (YYYYMMDD)
-- Supports temporal joins, seasonality, and zero-filling for time-series forecasting.
-- ============================================================================

CREATE TABLE IF NOT EXISTS dim_date (
    date_sk INT PRIMARY KEY,              -- Integer surrogate key: e.g. 20170115
    full_date DATE NOT NULL UNIQUE,       -- Date ISO string: '2017-01-15'
    year_num INT NOT NULL,               -- e.g. 2017
    quarter_num INT NOT NULL,            -- 1, 2, 3, 4
    month_num INT NOT NULL,              -- 1 to 12
    month_name VARCHAR(15) NOT NULL,     -- 'January', 'February', etc.
    week_of_year INT NOT NULL,           -- 1 to 53
    day_of_month INT NOT NULL,           -- 1 to 31
    day_of_week INT NOT NULL,            -- 0 = Sunday, 1 = Monday (or 1-7)
    day_name VARCHAR(15) NOT NULL,       -- 'Monday', 'Tuesday', etc.
    is_weekend BOOLEAN NOT NULL,         -- 1 if Saturday or Sunday, else 0
    is_month_start BOOLEAN NOT NULL,
    is_month_end BOOLEAN NOT NULL
);

-- Recursive CTE to populate calendar table across the entire Olist timeframe (2016-01-01 to 2018-12-31)
INSERT OR REPLACE INTO dim_date
WITH RECURSIVE date_series(curr_date) AS (
    SELECT DATE('2016-01-01')
    UNION ALL
    SELECT DATE(curr_date, '+1 day')
    FROM date_series
    WHERE curr_date < DATE('2018-12-31')
)
SELECT 
    CAST(STRFTIME('%Y%m%d', curr_date) AS INT) AS date_sk,
    curr_date AS full_date,
    CAST(STRFTIME('%Y', curr_date) AS INT) AS year_num,
    (CAST(STRFTIME('%m', curr_date) AS INT) - 1) / 3 + 1 AS quarter_num,
    CAST(STRFTIME('%m', curr_date) AS INT) AS month_num,
    CASE STRFTIME('%m', curr_date)
        WHEN '01' THEN 'January'
        WHEN '02' THEN 'February'
        WHEN '03' THEN 'March'
        WHEN '04' THEN 'April'
        WHEN '05' THEN 'May'
        WHEN '06' THEN 'June'
        WHEN '07' THEN 'July'
        WHEN '08' THEN 'August'
        WHEN '09' THEN 'September'
        WHEN '10' THEN 'October'
        WHEN '11' THEN 'November'
        WHEN '12' THEN 'December'
    END AS month_name,
    CAST(STRFTIME('%W', curr_date) AS INT) + 1 AS week_of_year,
    CAST(STRFTIME('%d', curr_date) AS INT) AS day_of_month,
    CAST(STRFTIME('%w', curr_date) AS INT) AS day_of_week,
    CASE STRFTIME('%w', curr_date)
        WHEN '0' THEN 'Sunday'
        WHEN '1' THEN 'Monday'
        WHEN '2' THEN 'Tuesday'
        WHEN '3' THEN 'Wednesday'
        WHEN '4' THEN 'Thursday'
        WHEN '5' THEN 'Friday'
        WHEN '6' THEN 'Saturday'
    END AS day_name,
    CASE WHEN STRFTIME('%w', curr_date) IN ('0', '6') THEN 1 ELSE 0 END AS is_weekend,
    CASE WHEN STRFTIME('%d', curr_date) = '01' THEN 1 ELSE 0 END AS is_month_start,
    CASE WHEN curr_date = DATE(curr_date, 'start of month', '+1 month', '-1 day') THEN 1 ELSE 0 END AS is_month_end
FROM date_series;
