"""
pipeline.py
Automated Data Engineering Pipeline:
1. Executes SQL dimensional transformations (dim_date, dim_products, dim_customers, dim_sellers)
2. Loads Fact Table (fact_order_items)
3. Builds Forecasting Base Mart (forecasting_base_mart) with zero-filling and non-leaking lags
4. Runs automated Data Quality (DQ) tests
5. Prints analytical audit metrics
"""

import sqlite3
import os
import sys
import time

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB_PATH = os.path.join(BASE_DIR, "data", "olist_warehouse.db")
SQL_DIR = os.path.join(BASE_DIR, "02_sql_transformations")

TRANSFORMATION_SCRIPTS = [
    ("dim_date", "01_dim_date.sql"),
    ("dim_products", "02_dim_products.sql"),
    ("dim_customers", "03_dim_customers.sql"),
    ("dim_sellers", "04_dim_sellers.sql"),
    ("fact_order_items", "05_fact_order_items.sql"),
    ("forecasting_base_mart", "06_forecasting_base_mart.sql")
]

def run_pipeline():
    print("=" * 70)
    print("🚀 STARTING DATA ENGINEERING DIMENSIONAL ETL PIPELINE")
    print(f"Target Database: {DB_PATH}")
    print("=" * 70)
    
    if not os.path.exists(DB_PATH):
        print("⚠️ Database not found! Generating sample raw dataset first...")
        from sample_data_generator import seed_database
        seed_database()

    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    
    # Enable WAL mode for high performance
    cur.execute("PRAGMA journal_mode=WAL;")
    
    start_total = time.time()
    
    # 1. Execute transformations
    for model_name, script_file in TRANSFORMATION_SCRIPTS:
        script_path = os.path.join(SQL_DIR, script_file)
        print(f"\n⚙️ Running [{model_name}] from {script_file}...")
        t0 = time.time()
        
        with open(script_path, "r") as f:
            sql_script = f.read()
            
        cur.executescript(sql_script)
        conn.commit()
        
        # Check row count
        cur.execute(f"SELECT COUNT(*) FROM {model_name};")
        count = cur.fetchone()[0]
        elapsed = time.time() - t0
        print(f"   ✅ Done! {count:,} records in {model_name} ({elapsed:.2f}s)")
        
    # 2. Automated Data Quality (DQ) Tests
    print("\n" + "=" * 70)
    print("🧪 RUNNING AUTOMATED DATA QUALITY (DQ) ASSERTS")
    print("=" * 70)
    
    tests = [
        ("No Orphan Products in Fact", 
         "SELECT COUNT(*) FROM fact_order_items WHERE product_sk = -1;", 
         0),
        ("No Orphan Customers in Fact", 
         "SELECT COUNT(*) FROM fact_order_items WHERE customer_sk = -1;", 
         0),
        ("Fact Revenue Matches Item + Freight", 
         "SELECT COUNT(*) FROM fact_order_items WHERE ABS(total_item_cost - (item_price + freight_value)) > 0.01;", 
         0),
        ("Forecasting Mart Has No Missing Category Gaps", 
         "SELECT COUNT(*) FROM forecasting_base_mart WHERE daily_units_sold IS NULL;", 
         0),
        ("Non-Negative Units Sold", 
         "SELECT COUNT(*) FROM forecasting_base_mart WHERE daily_units_sold < 0;", 
         0)
    ]
    
    all_passed = True
    for test_name, query, expected in tests:
        cur.execute(query)
        result = cur.fetchone()[0]
        if result == expected:
            print(f"   [PASS] {test_name}: {result} (Expected: {expected})")
        else:
            print(f"   [FAIL] {test_name}: Got {result}, expected {expected}!")
            all_passed = False
            
    # 3. Top Analytical Insights
    print("\n" + "=" * 70)
    print("📊 STAR SCHEMA SUMMARY & FORECASTING BASE SNAPSHOT")
    print("=" * 70)
    
    # Top 5 Categories by Revenue
    print("\n🏆 Top 5 Categories by Total Revenue:")
    cur.execute("""
        SELECT 
            dp.product_category_en,
            COUNT(f.fact_item_sk) AS items_sold,
            ROUND(SUM(f.item_price), 2) AS total_revenue,
            ROUND(AVG(f.delivery_lead_time_days), 1) AS avg_delivery_days
        FROM fact_order_items f
        JOIN dim_products dp ON f.product_sk = dp.product_sk
        GROUP BY 1
        ORDER BY total_revenue DESC
        LIMIT 5;
    """)
    for row in cur.fetchall():
        print(f"   - {row[0]:<25} | Units: {row[1]:<5} | Rev: ${row[2]:<10,.2f} | Lead Time: {row[3]} days")
        
    # Sample Forecasting Mart Rows
    print("\n📈 Sample Forecasting Mart Rows (Continuous Equidistant Features):")
    cur.execute("""
        SELECT 
            snapshot_date, 
            product_category_en, 
            daily_units_sold, 
            daily_gross_revenue,
            lag_units_1d, 
            lag_units_7d, 
            rolling_avg_7d_units,
            momentum_7d_vs_30d_ratio
        FROM forecasting_base_mart
        WHERE daily_units_sold > 0
        LIMIT 5;
    """)
    for row in cur.fetchall():
        print(f"   Date: {row[0]} | Cat: {row[1]:<20} | Units: {row[2]} | Rev: ${row[3]:<7} | Lags: (1d={row[4]}, 7d={row[5]}) | Roll7d: {row[6]} | Momentum: {row[7]}")
        
    total_elapsed = time.time() - start_total
    print("\n" + "=" * 70)
    if all_passed:
        print(f"🎉 PIPELINE COMPLETED SUCCESSFULLY IN {total_elapsed:.2f}s!")
    else:
        print("⚠️ Pipeline finished with Data Quality warnings.")
    print("=" * 70)
    conn.close()

if __name__ == "__main__":
    run_pipeline()
