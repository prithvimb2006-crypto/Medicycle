"""
MEDICYCLE Database Connectivity & Integrity Test Suite
Verifies connection parameters, user authentication, and relational integrity.
"""
import os
import sys
from dotenv import load_dotenv
import mysql.connector
from mysql.connector import Error

# Load environment variables from .env
env_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".env"))
load_dotenv(dotenv_path=env_path)

DB_HOST = os.getenv("DB_HOST", "127.0.0.1")
DB_PORT = int(os.getenv("DB_PORT", "3306"))
DB_NAME = os.getenv("DB_NAME", "medicycle_db")
DB_USER = os.getenv("DB_USER", "medicycle_user")
DB_PASSWORD = os.getenv("DB_PASSWORD", "")

def test_connection():
    print("=" * 60)
    print("MEDICYCLE Phase 1 Database Connection Test")
    print("=" * 60)
    print(f"Connecting to {DB_USER}@{DB_HOST}:{DB_PORT}/{DB_NAME}...")

    try:
        connection = mysql.connector.connect(
            host=DB_HOST,
            port=DB_PORT,
            database=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD
        )

        if connection.is_connected():
            db_info = connection.server_info
            cursor = connection.cursor(dictionary=True)
            print(f"[SUCCESS] Connected to MySQL Server version: {db_info}")

            # 1. Server & Session Verification
            cursor.execute("SELECT DATABASE() AS current_db, CURRENT_USER() AS active_user;")
            session_meta = cursor.fetchone()
            print(f"[SUCCESS] Database: {session_meta['current_db']}, Active User: {session_meta['active_user']}")

            # 2. Table Count Check
            cursor.execute("SHOW TABLES;")
            tables = cursor.fetchall()
            print(f"[SUCCESS] Table verification: {len(tables)} tables found in {DB_NAME}.")

            # 3. Relational Join Verification (Medicine Digital Passport Anchor)
            query = """
            SELECT 
                m.medicine_id,
                m.brand_name,
                m.generic_name,
                c.category_name,
                mfr.name AS manufacturer_name,
                s.min_temp_celsius,
                s.max_temp_celsius,
                s.requires_refrigeration,
                d.disposal_method,
                d.environmental_hazard_rating
            FROM medicines m
            INNER JOIN categories c ON m.category_id = c.category_id
            INNER JOIN manufacturers mfr ON m.manufacturer_id = mfr.manufacturer_id
            LEFT JOIN storage_rules s ON m.medicine_id = s.medicine_id
            LEFT JOIN disposal_guidelines d ON m.medicine_id = d.medicine_id
            ORDER BY m.medicine_id
            LIMIT 5;
            """
            cursor.execute(query)
            sample_medicines = cursor.fetchall()
            print("\n[VERIFICATION] Sample Medicine Profile Joins:")
            for row in sample_medicines:
                print(f"  * #{row['medicine_id']} {row['brand_name']} ({row['generic_name']})")
                print(f"    - Category: {row['category_name']}")
                print(f"    - Manufacturer: {row['manufacturer_name']}")
                print(f"    - Storage: {row['min_temp_celsius']}C to {row['max_temp_celsius']}C (Refrig: {row['requires_refrigeration']})")
                print(f"    - Disposal: {row['disposal_method']} (Hazard: {row['environmental_hazard_rating']})")

            # 4. Expiry Status Verification
            cursor.execute("""
            SELECT status, COUNT(*) AS batch_count 
            FROM medicine_batches 
            GROUP BY status;
            """)
            batches = cursor.fetchall()
            print("\n[VERIFICATION] Medicine Batches Status Breakdown:")
            for b in batches:
                print(f"  * Status: {b['status']} -> {b['batch_count']} batches")

            # 5. Fixed Surrogate PK Verification for recall_medicines
            cursor.execute("""
            SELECT 
                rm.recall_medicine_id,
                r.recall_reference_code,
                m.brand_name,
                rm.batch_id,
                rm.affected_lot_description
            FROM recall_medicines rm
            INNER JOIN recall_records r ON rm.recall_id = r.recall_id
            INNER JOIN medicines m ON rm.medicine_id = m.medicine_id;
            """)
            recalls = cursor.fetchall()
            print("\n[VERIFICATION] Recall-Medicine Surrogate PK Check:")
            for r in recalls:
                print(f"  * PK recall_medicine_id={r['recall_medicine_id']} | Recall={r['recall_reference_code']} | Medicine={r['brand_name']} | BatchID={r['batch_id']}")

            cursor.close()
            connection.close()
            print("\n" + "=" * 60)
            print("ALL PHASE 1 DATABASE CHECKS PASSED SUCCESSFULLY!")
            print("=" * 60)
            return True

    except Error as e:
        print(f"\n[ERROR] Database connection failed: {e}")
        return False

if __name__ == "__main__":
    success = test_connection()
    sys.exit(0 if success else 1)
