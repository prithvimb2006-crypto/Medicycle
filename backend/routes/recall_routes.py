
from flask import Blueprint, jsonify, request
from mysql.connector import Error
from backend.database.connection import get_db_connection

recall_bp = Blueprint("recalls", __name__)


# 1. Get all recall records
@recall_bp.route("/recalls", methods=["GET"])
def get_all_recalls():
    connection = None
    cursor = None

    try:
        status = request.args.get("status", "").strip().upper()

        if status and status not in ["ACTIVE", "COMPLETED", "TERMINATED"]:
            return jsonify({
                "status": "error",
                "message": "Invalid recall status"
            }), 400

        connection = get_db_connection()
        cursor = connection.cursor(dictionary=True)

        query = """
            SELECT
                rr.recall_id,
                rr.recall_reference_code,
                rr.issuing_authority,
                rr.recall_class,
                rr.recall_reason,
                rr.status,
                rr.announcement_date,
                rr.action_required,
                rr.reference_id,
                sr.source_name,
                sr.url AS reference_url
            FROM recall_records rr
            LEFT JOIN source_references sr
                ON rr.reference_id = sr.reference_id
        """

        params = []

        if status:
            query += " WHERE rr.status = %s"
            params.append(status)

        query += " ORDER BY rr.announcement_date DESC"

        cursor.execute(query, tuple(params))
        recalls = cursor.fetchall()

        return jsonify({
            "status": "success",
            "count": len(recalls),
            "data": recalls
        }), 200

    except Error:
        return jsonify({
            "status": "error",
            "message": "Unable to retrieve recall records"
        }), 500

    finally:
        if cursor:
            cursor.close()
        if connection and connection.is_connected():
            connection.close()


# 2. Get complete details of one recall
@recall_bp.route("/recalls/<int:recall_id>", methods=["GET"])
def get_recall_details(recall_id):
    connection = None
    cursor = None

    try:
        connection = get_db_connection()
        cursor = connection.cursor(dictionary=True)

        cursor.execute("""
            SELECT
                rr.*,
                sr.source_name,
                sr.source_type,
                sr.url AS reference_url,
                sr.verification_status
            FROM recall_records rr
            LEFT JOIN source_references sr
                ON rr.reference_id = sr.reference_id
            WHERE rr.recall_id = %s
        """, (recall_id,))

        recall = cursor.fetchone()

        if not recall:
            return jsonify({
                "status": "error",
                "message": "Recall record not found"
            }), 404

        cursor.execute("""
            SELECT
                rm.recall_medicine_id,
                rm.medicine_id,
                m.brand_name,
                m.generic_name,
                rm.batch_id,
                mb.batch_number,
                mb.expiry_date,
                mb.status AS batch_status,
                rm.affected_lot_description
            FROM recall_medicines rm
            JOIN medicines m
                ON rm.medicine_id = m.medicine_id
            LEFT JOIN medicine_batches mb
                ON rm.batch_id = mb.batch_id
            WHERE rm.recall_id = %s
        """, (recall_id,))

        affected_medicines = cursor.fetchall()

        return jsonify({
            "status": "success",
            "data": {
                "recall": recall,
                "affected_medicines": affected_medicines,
                "affected_count": len(affected_medicines)
            }
        }), 200

    except Error:
        return jsonify({
            "status": "error",
            "message": "Unable to retrieve recall details"
        }), 500

    finally:
        if cursor:
            cursor.close()
        if connection and connection.is_connected():
            connection.close()


# 3. Check recalls for a particular medicine
@recall_bp.route(
    "/medicines/<int:medicine_id>/recalls",
    methods=["GET"]
)
def get_medicine_recalls(medicine_id):
    connection = None
    cursor = None

    try:
        connection = get_db_connection()
        cursor = connection.cursor(dictionary=True)

        cursor.execute("""
            SELECT medicine_id, brand_name
            FROM medicines
            WHERE medicine_id = %s AND is_active = 1
        """, (medicine_id,))

        medicine = cursor.fetchone()

        if not medicine:
            return jsonify({
                "status": "error",
                "message": "Medicine not found"
            }), 404

        cursor.execute("""
            SELECT
                rr.recall_id,
                rr.recall_reference_code,
                rr.issuing_authority,
                rr.recall_class,
                rr.recall_reason,
                rr.status,
                rr.announcement_date,
                rr.action_required,
                rm.batch_id,
                mb.batch_number,
                mb.expiry_date,
                mb.status AS batch_status,
                rm.affected_lot_description
            FROM recall_records rr
            JOIN recall_medicines rm
                ON rr.recall_id = rm.recall_id
            LEFT JOIN medicine_batches mb
                ON rm.batch_id = mb.batch_id
            WHERE rm.medicine_id = %s
            ORDER BY rr.announcement_date DESC
        """, (medicine_id,))

        recalls = cursor.fetchall()

        return jsonify({
            "status": "success",
            "medicine": medicine,
            "recall_count": len(recalls),
            "data": recalls
        }), 200

    except Error:
        return jsonify({
            "status": "error",
            "message": "Unable to check medicine recalls"
        }), 500

    finally:
        if cursor:
            cursor.close()
        if connection and connection.is_connected():
            connection.close()


# 4. Get all batches associated with active recalls
@recall_bp.route("/recalls/active/batches", methods=["GET"])
def get_active_recalled_batches():
    connection = None
    cursor = None

    try:
        connection = get_db_connection()
        cursor = connection.cursor(dictionary=True)

        cursor.execute("""
            SELECT
                rr.recall_id,
                rr.recall_reference_code,
                rr.issuing_authority,
                rr.recall_class,
                rr.status AS recall_status,
                rm.medicine_id,
                m.brand_name,
                m.generic_name,
                rm.batch_id,
                mb.batch_number,
                mb.expiry_date,
                mb.status AS batch_status,
                rm.affected_lot_description
            FROM recall_records rr
            JOIN recall_medicines rm
                ON rr.recall_id = rm.recall_id
            JOIN medicines m
                ON rm.medicine_id = m.medicine_id
            LEFT JOIN medicine_batches mb
                ON rm.batch_id = mb.batch_id
            WHERE rr.status = 'ACTIVE'
            ORDER BY rr.announcement_date DESC
        """)

        batches = cursor.fetchall()

        return jsonify({
            "status": "success",
            "count": len(batches),
            "data": batches
        }), 200

    except Error:
        return jsonify({
            "status": "error",
            "message": "Unable to retrieve recalled batches"
        }), 500

    finally:
        if cursor:
            cursor.close()
        if connection and connection.is_connected():
            connection.close()
