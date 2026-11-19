from flask import Blueprint, jsonify, current_app
from mysql.connector import Error

from backend.database.connection import get_db_connection
from backend.utils.auth import permission_required

catalog_bp = Blueprint("catalog", __name__, url_prefix="/api/catalog")


def _fetch_all(sql, error_message):
    connection = None
    cursor = None
    try:
        connection = get_db_connection()
        cursor = connection.cursor(dictionary=True)
        cursor.execute(sql)
        return jsonify({"success": True, "data": cursor.fetchall()}), 200
    except Error:
        current_app.logger.exception(error_message)
        return jsonify({"success": False, "message": error_message}), 500
    finally:
        if cursor:
            cursor.close()
        if connection and connection.is_connected():
            connection.close()


@catalog_bp.route("/categories", methods=["GET"])
@permission_required("CATALOG_WRITE")
def list_categories():
    return _fetch_all(
        "SELECT category_id, category_name FROM categories ORDER BY category_id",
        "Unable to load categories."
    )


@catalog_bp.route("/manufacturers", methods=["GET"])
@permission_required("CATALOG_WRITE")
def list_manufacturers():
    return _fetch_all(
        "SELECT manufacturer_id, name, country FROM manufacturers ORDER BY manufacturer_id",
        "Unable to load manufacturers."
    )
