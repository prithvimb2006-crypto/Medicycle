from functools import wraps
from flask import session, jsonify
from mysql.connector import Error
from backend.database.connection import get_db_connection


def permission_required(permission_code):
    def decorator(view_function):
        @wraps(view_function)
        def wrapped(*args, **kwargs):
            user_id = session.get("user_id")

            if not user_id:
                return jsonify({
                    "success": False,
                    "message": "Authentication required."
                }), 401

            connection = None
            cursor = None

            try:
                connection = get_db_connection()
                cursor = connection.cursor(dictionary=True)

                cursor.execute("""
                    SELECT p.permission_code
                    FROM users u
                    JOIN user_roles ur
                        ON ur.user_id = u.user_id
                    JOIN roles r
                        ON r.role_id = ur.role_id
                    JOIN role_permissions rp
                        ON rp.role_id = r.role_id
                    JOIN permissions p
                        ON p.permission_id = rp.permission_id
                    WHERE u.user_id = %s
                      AND u.is_active = 1
                      AND p.permission_code = %s
                    LIMIT 1
                """, (user_id, permission_code))

                permission = cursor.fetchone()

                if not permission:
                    return jsonify({
                        "success": False,
                        "message": "You do not have permission to perform this action."
                    }), 403

            except Error:
                return jsonify({
                    "success": False,
                    "message": "Authorization service unavailable."
                }), 503

            finally:
                if cursor:
                    cursor.close()
                if connection and connection.is_connected():
                    connection.close()

            return view_function(*args, **kwargs)

        return wrapped
    return decorator
