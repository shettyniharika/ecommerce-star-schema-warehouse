"""
sample_data_generator.py
Generates a realistic synthetic slice of Olist Brazilian E-Commerce data
for immediate local development, testing, and hands-on learning.
Zero third-party dependencies required (pure standard library).
"""

import sqlite3
import random
import uuid
from datetime import datetime, timedelta
import os

DB_PATH = os.path.join(os.path.dirname(__file__), "..", "data", "olist_warehouse.db")

CATEGORIES = [
    ("cama_mesa_banho", "bed_bath_table"),
    ("beleza_saude", "health_beauty"),
    ("esporte_lazer", "sports_leisure"),
    ("moveis_decoracao", "furniture_decor"),
    ("informatica_acessorios", "computers_accessories"),
    ("relogios_presentes", "watches_gifts"),
    ("telefonia", "telephony"),
    ("ferramentas_jardim", "garden_tools")
]

CITIES = [
    ("sao paulo", "SP", "01000"),
    ("rio de janeiro", "RJ", "20000"),
    ("belo horizonte", "MG", "30000"),
    ("curitiba", "PR", "80000"),
    ("porto alegre", "RS", "90000"),
    ("salvador", "BA", "40000"),
    ("recife", "PE", "50000"),
    ("brasilia", "DF", "70000")
]

def seed_database():
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    
    print(f"📦 Initializing database at: {DB_PATH}")
    
    # Run DDL
    ddl_path = os.path.join(os.path.dirname(__file__), "..", "02_sql_transformations", "00_raw_tables_schema.sql")
    if os.path.exists(ddl_path):
        with open(ddl_path, "r") as f:
            cur.executescript(f.read())
            
    print("✨ Seeding raw reference tables (categories, products, customers, sellers)...")
    
    # 1. Product Category Translations
    for pt, en in CATEGORIES:
        cur.execute(
            "INSERT OR REPLACE INTO raw_product_category_translation VALUES (?, ?)",
            (pt, en)
        )
        
    # 2. Products
    product_ids = []
    for i in range(1, 101):
        pid = f"prod_{i:04d}_{uuid.uuid4().hex[:8]}"
        cat_pt, _ = random.choice(CATEGORIES)
        weight = random.randint(200, 15000)
        l, h, w = random.randint(10, 80), random.randint(10, 50), random.randint(10, 60)
        cur.execute(
            """INSERT OR REPLACE INTO raw_products 
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            (pid, cat_pt, random.randint(20, 60), random.randint(100, 1000), 
             random.randint(1, 6), weight, l, h, w)
        )
        product_ids.append(pid)
        
    # 3. Customers
    customer_records = []
    for i in range(1, 201):
        cid = f"cust_{i:04d}_{uuid.uuid4().hex[:8]}"
        uid = f"user_{random.randint(1, 150):04d}" # Some share unique_id (repeat buyers!)
        city, state, zip_code = random.choice(CITIES)
        cur.execute(
            """INSERT OR REPLACE INTO raw_customers VALUES (?, ?, ?, ?, ?)""",
            (cid, uid, zip_code, city, state)
        )
        customer_records.append(cid)
        
    # 4. Sellers
    seller_ids = []
    for i in range(1, 21):
        sid = f"seller_{i:03d}_{uuid.uuid4().hex[:6]}"
        city, state, zip_code = random.choice(CITIES)
        cur.execute(
            """INSERT OR REPLACE INTO raw_sellers VALUES (?, ?, ?, ?)""",
            (sid, zip_code, city, state)
        )
        seller_ids.append(sid)
        
    # 5. Orders & Order Items across 2017 - 2018
    print("🛒 Generating realistic orders and line-item transactions...")
    start_date = datetime(2017, 1, 1)
    end_date = datetime(2018, 6, 30)
    delta_days = (end_date - start_date).days
    
    order_count = 0
    item_count = 0
    
    for day_offset in range(delta_days):
        current_day = start_date + timedelta(days=day_offset)
        # Random daily orders between 5 and 25
        daily_orders = random.randint(5, 25)
        
        for _ in range(daily_orders):
            order_count += 1
            oid = f"ord_{order_count:05d}_{uuid.uuid4().hex[:8]}"
            cid = random.choice(customer_records)
            
            # Purchase timestamp
            hour = random.randint(8, 23)
            minute = random.randint(0, 59)
            purchase_dt = current_day.replace(hour=hour, minute=minute)
            
            # Status: mostly delivered
            status = random.choices(["delivered", "shipped", "canceled"], weights=[92, 6, 2])[0]
            
            lead_days = random.randint(3, 20)
            delivery_dt = purchase_dt + timedelta(days=lead_days) if status == "delivered" else None
            est_lead_days = random.randint(10, 25)
            estimated_dt = purchase_dt + timedelta(days=est_lead_days)
            
            cur.execute(
                """INSERT OR REPLACE INTO raw_orders VALUES (?, ?, ?, ?, ?, ?, ?, ?)""",
                (oid, cid, status, 
                 purchase_dt.strftime("%Y-%m-%d %H:%M:%S"),
                 (purchase_dt + timedelta(hours=2)).strftime("%Y-%m-%d %H:%M:%S"),
                 (purchase_dt + timedelta(days=1)).strftime("%Y-%m-%d %H:%M:%S"),
                 delivery_dt.strftime("%Y-%m-%d %H:%M:%S") if delivery_dt else None,
                 estimated_dt.strftime("%Y-%m-%d %H:%M:%S"))
            )
            
            # 1 to 3 items per order
            num_items = random.choices([1, 2, 3], weights=[75, 20, 5])[0]
            for item_idx in range(1, num_items + 1):
                item_count += 1
                pid = random.choice(product_ids)
                sid = random.choice(seller_ids)
                price = round(random.uniform(15.0, 350.0), 2)
                freight = round(random.uniform(10.0, 45.0), 2)
                
                cur.execute(
                    """INSERT OR REPLACE INTO raw_order_items VALUES (?, ?, ?, ?, ?, ?, ?)""",
                    (oid, item_idx, pid, sid, 
                     (purchase_dt + timedelta(days=5)).strftime("%Y-%m-%d %H:%M:%S"),
                     price, freight)
                )
                
            # Payment
            cur.execute(
                """INSERT OR REPLACE INTO raw_order_payments VALUES (?, ?, ?, ?, ?)""",
                (oid, 1, random.choice(["credit_card", "boleto", "voucher", "debit_card"]),
                 random.randint(1, 6), round(price * num_items + freight, 2))
            )
            
            # Review (80% leave a review)
            if random.random() < 0.8:
                score = random.choices([5, 4, 3, 2, 1], weights=[58, 20, 8, 5, 9])[0]
                cur.execute(
                    """INSERT OR REPLACE INTO raw_order_reviews VALUES (?, ?, ?, ?, ?, ?, ?)""",
                    (f"rev_{order_count:05d}", oid, score, "", "", 
                     (purchase_dt + timedelta(days=lead_days + 1)).strftime("%Y-%m-%d %H:%M:%S"),
                     (purchase_dt + timedelta(days=lead_days + 2)).strftime("%Y-%m-%d %H:%M:%S"))
                )

    conn.commit()
    conn.close()
    print(f"✅ Database successfully seeded with {order_count} orders and {item_count} items across {delta_days} days!")

if __name__ == "__main__":
    seed_database()
