
from flask import Blueprint, jsonify, request
from mysql.connector import Error
from backend.database.connection import get_db_connection

batch_bp = Blueprint("batches", __name__)


# 1. Get all medicine batches
@batch_bp.route("/batches", methods=["GET"])
def get_all_batches():
    connection = None
    cursor = None

    try:
        status = request.args.get("status", "").strip().upper()

        allowed_statuses = [
            "VALID",
            "EXPIRING_SOON",
            "EXPIRED",
            "RECALLED",
            "QUARANTINED"
        ]

        if status and status not in allowed_statuses:
            return jsonify({
                "status": "error",
                "message": "Invalid batch status"
            }), 400

        connection = get_db_connection()
        cursor = connection.cursor(dictionary=True)

        query = """
            SELECT
                mb.batch_id,
                mb.medicine_id,
                m.brand_name,
                m.generic_name,
                mb.batch_number,
                mb.manufacturing_date,
                mb.expiry_date,
                mb.initial_quantity,
                mb.status,
                CASE
                    WHEN mb.status = 'RECALLED' THEN 'RECALLED'
                    WHEN mb.status = 'QUARANTINED' THEN 'QUARANTINED'
                    WHEN mb.expiry_date < CURDATE() THEN 'EXPIRED_BY_DATE'
                    WHEN mb.expiry_date <= DATE_ADD(CURDATE(), INTERVAL 30 DAY)
                        THEN 'EXPIRING_WITHIN_30_DAYS'
                    ELSE 'NOT_EXPIRED_BY_DATE'
                END AS date_assessment
            FROM medicine_batches mb
            JOIN medicines m
                ON mb.medicine_id = m.medicine_id
        """

        params = []

        if status:
            query += " WHERE mb.status = %s"
            params.append(status)

        query += " ORDER BY mb.expiry_date ASC"

        cursor.execute(query, tuple(params))
        batches = cursor.fetchall()

        return jsonify({
            "status": "success",
            "count": len(batches),
            "data": batches
        }), 200

    except Error:
        return jsonify({
            "status": "error",
            "message": "Unable to retrieve medicine batches"
        }), 500

    finally:
        if cursor:
            cursor.close()
        if connection and connection.is_connected():
            connection.close()


# 2. Get batches expiring within a specified number of days
@batch_bp.route("/batches/expiring", methods=["GET"])
def get_expiring_batches():
    connection = None
    cursor = None

    days = request.args.get("days", default=30, type=int)

    if days is None or not 1 <= days <= 365:
        return jsonify({
            "status": "error",
            "message": "Days must be between 1 and 365"
        }), 400

    try:
        connection = get_db_connection()
        cursor = connection.cursor(dictionary=True)

        cursor.execute("""
            SELECT
                mb.batch_id,
                mb.medicine_id,
                m.brand_name,
                m.generic_name,
                mb.batch_number,
                mb.manufacturing_date,
                mb.expiry_date,
                mb.initial_quantity,
                mb.status,
                DATEDIFF(mb.expiry_date, CURDATE()) AS days_until_expiry
            FROM medicine_batches mb
            JOIN medicines m
                ON mb.medicine_id = m.medicine_id
            WHERE mb.expiry_date >= CURDATE()
              AND mb.expiry_date <= DATE_ADD(
                  CURDATE(), INTERVAL %s DAY
              )
              AND mb.status NOT IN ('RECALLED', 'QUARANTINED')
            ORDER BY mb.expiry_date ASC
        """, (days,))

        batches = cursor.fetchall()

        return jsonify({
            "status": "success",
            "days_checked": days,
            "count": len(batches),
            "data": batches
        }), 200

    except Error:
        return jsonify({
            "status": "error",
            "message": "Unable to retrieve expiring batches"
        }), 500

    finally:
        if cursor:
            cursor.close()
        if connection and connection.is_connected():
            connection.close()


# 3. Get individual batch details
@batch_bp.route("/batches/<int:batch_id>", methods=["GET"])
def get_batch_details(batch_id):
    connection = None
    cursor = None

    try:
        connection = get_db_connection()
        cursor = connection.cursor(dictionary=True)

        cursor.execute("""
            SELECT
                mb.batch_id,
                mb.medicine_id,
                m.brand_name,
                m.generic_name,
                m.dosage_form,
                m.strength,
                mb.batch_number,
                mb.manufacturing_date,
                mb.expiry_date,
                mb.initial_quantity,
                mb.status,
                mb.created_at,
                DATEDIFF(mb.expiry_date, CURDATE()) AS days_until_expiry
            FROM medicine_batches mb
            JOIN medicines m
                ON mb.medicine_id = m.medicine_id
            WHERE mb.batch_id = %s
        """, (batch_id,))

        batch = cursor.fetchone()

        if not batch:
            return jsonify({
                "status": "error",
                "message": "Batch not found"
            }), 404

        return jsonify({
            "status": "success",
            "data": batch
        }), 200

    except Error:
        return jsonify({
            "status": "error",
            "message": "Unable to retrieve batch details"
        }), 500

    finally:
        if cursor:
            cursor.close()
        if connection and connection.is_connected():
            connection.close()


# 4. Batch lifecycle summary
@batch_bp.route("/batches/summary", methods=["GET"])
def get_batch_summary():
    connection = None
    cursor = None

    try:
        connection = get_db_connection()
        cursor = connection.cursor(dictionary=True)

        cursor.execute("""
            SELECT
                COUNT(*) AS total_batches,

                SUM(
                    CASE WHEN status = 'VALID'
                    THEN 1 ELSE 0 END
                ) AS valid_batches,

                SUM(
                    CASE WHEN expiry_date < CURDATE()
                    THEN 1 ELSE 0 END
                ) AS expired_by_date,

                SUM(
                    CASE
                        WHEN expiry_date >= CURDATE()
                         AND expiry_date <= DATE_ADD(CURDATE(), INTERVAL 30 DAY)
                         AND status NOT IN ('RECALLED', 'QUARANTINED')
                        THEN 1 ELSE 0
                    END
                ) AS expiring_within_30_days,

                SUM(
                    CASE WHEN status = 'RECALLED'
                    THEN 1 ELSE 0 END
                ) AS recalled_batches,

                SUM(
                    CASE WHEN status = 'QUARANTINED'
                    THEN 1 ELSE 0 END
                ) AS quarantined_batches

            FROM medicine_batches
        """)

        summary = cursor.fetchone()

        return jsonify({
            "status": "success",
            "data": summary
        }), 200

    except Error:
        return jsonify({
            "status": "error",
            "message": "Unable to retrieve batch summary"
        }), 500

    finally:
        if cursor:
            cursor.close()
        if connection and connection.is_connected():
            connection.close()
