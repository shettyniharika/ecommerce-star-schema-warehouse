# 📥 How to Ingest the Full Kaggle Olist Dataset (100,000+ Orders)

While the repository already includes a realistic generator (`03_pipeline_code/sample_data_generator.py`) for offline local development, you can also download the full **100,000+ real Brazilian e-commerce orders** directly from Kaggle.

---

## 1. Downloading from Kaggle

### Option A: Via Browser
1. Visit the official Kaggle dataset page: [Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)
2. Click **Download (Archive.zip)** (approx. 50 MB compressed, 120 MB uncompressed).
3. Unzip the CSV files into:
   ```
   DataEngineering-StarSchema/data/raw_kaggle/
   ```

### Option B: Via Kaggle API (CLI)
```bash
# Install kaggle cli if needed
pip install kaggle

# Download dataset
kaggle datasets download -d olistbr/brazilian-ecommerce -p ./data/raw_kaggle --unzip
```

---

## 2. The 9 Raw CSV Files You Will Find:
- `olist_orders_dataset.csv`
- `olist_order_items_dataset.csv`
- `olist_order_payments_dataset.csv`
- `olist_order_reviews_dataset.csv`
- `olist_products_dataset.csv`
- `olist_customers_dataset.csv`
- `olist_sellers_dataset.csv`
- `olist_geolocation_dataset.csv`
- `product_category_name_translation.csv`

---

## 3. Loading the CSVs into SQLite or DuckDB
You can load the CSVs in one line using Python's `pandas` or `duckdb`:

```python
import sqlite3
import pandas as pd
import glob
import os

conn = sqlite3.connect("./data/olist_warehouse.db")

# Map CSV files to raw table names
files = {
    "olist_orders_dataset.csv": "raw_orders",
    "olist_order_items_dataset.csv": "raw_order_items",
    "olist_products_dataset.csv": "raw_products",
    "olist_customers_dataset.csv": "raw_customers",
    "olist_sellers_dataset.csv": "raw_sellers",
    "olist_order_payments_dataset.csv": "raw_order_payments",
    "olist_order_reviews_dataset.csv": "raw_order_reviews",
    "product_category_name_translation.csv": "raw_product_category_translation"
}

for filename, table_name in files.items():
    filepath = os.path.join("./data/raw_kaggle", filename)
    if os.path.exists(filepath):
        print(f"Loading {filename} into {table_name}...")
        df = pd.read_csv(filepath)
        df.to_sql(table_name, conn, if_exists="replace", index=False)

print("Ingestion complete! Now run `pipeline.py` to build the Star Schema!")
```
