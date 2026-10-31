"""Build the SQLite database, run every SQL file in order and export the
CSVs used by Tableau.   Usage:  python python/run_pipeline.py
"""
import sqlite3
from pathlib import Path
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "data" / "processed" / "clean_online_retail.csv"
DB = ROOT / "data" / "rfm.db"
OUT = ROOT / "data" / "processed"

EXPORTS = {                      # table -> csv name used in Tableau
    "customer_segments":        "customers_rfm.csv",
    "segment_summary":          "segment_summary.csv",
    "monthly_sales":            "monthly_sales.csv",
    "cohort_retention":         "cohort_retention.csv",
    "top_products_by_segment":  "top_products_by_segment.csv",
    "pareto":                   "pareto.csv",
    "pareto_summary":           "pareto_summary.csv",
    "country_sales":            "country_sales.csv",
    "monthly_segment_sales":    "monthly_segment_sales.csv",
    "revenue_at_risk":          "revenue_at_risk.csv",
    "data_quality_log":         "data_quality_log.csv",
}

def build(verbose=True):
    if DB.exists():
        DB.unlink()
    conn = sqlite3.connect(DB)
    pd.read_csv(SRC).to_sql("stg_online_retail", conn, index=False)
    for sql_file in sorted((ROOT / "sql").glob("*.sql")):
        conn.executescript(sql_file.read_text())
        if verbose:
            print("ran", sql_file.name)
    for table, name in EXPORTS.items():
        pd.read_sql_query(f"SELECT * FROM {table}", conn).to_csv(OUT / name, index=False)
    conn.commit()
    return conn

if __name__ == "__main__":
    build().close()
    print("done ->", OUT)
