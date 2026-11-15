from backend.utils.auth import permission_required
import re
import bcrypt

from flask import Blueprint, request, jsonify, session
from mysql.connector import Error, IntegrityError

from backend.database.connection import get_db_connection

auth_bp = Blueprint("auth", __name__, url_prefix="/api/auth")

STAFF_ROLES = ("DOCTOR", "NURSE", "RECEPTIONIST")


@auth_bp.route("/register", methods=["POST"])
def register():
    data = request.get_json(silent=True) or {}

    full_name = str(data.get("full_name", "")).strip()
    username = str(data.get("username", "")).strip()
    email = str(data.get("email", "")).strip().lower()
    password = data.get("password", "")
    role = str(data.get("role", "")).strip().upper()

    if not all([full_name, username, email, password, role]):
        return jsonify({
            "success": False,
            "message": "All fields are required."
        }), 400

    if role not in STAFF_ROLES:
        return jsonify({
            "success": False,
            "message": "Select Doctor, Nurse or Receptionist."
        }), 400

    if len(full_name) > 100 or len(username) > 50:
        return jsonify({
            "success": False,
            "message": "Name or username is too long."
        }), 400

    if not re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+", email):
        return jsonify({
            "success": False,
            "message": "Enter a valid email address."
        }), 400

    if len(email) > 120:
        return jsonify({
            "success": False,
            "message": "Email address is too long."
        }), 400

    if not isinstance(password, str) or len(password.encode("utf-8")) < 8:
        return jsonify({
            "success": False,
            "message": "Password must contain at least 8 bytes."
        }), 400

    if len(password.encode("utf-8")) > 72:
        return jsonify({
            "success": False,
            "message": "Password is too long."
        }), 400

    connection = None
    cursor = None

    try:
        connection = get_db_connection()
        cursor = connection.cursor(dictionary=True)

        cursor.execute(
            "SELECT role_id FROM roles WHERE role_name = %s",
            (role,)
        )
        role_record = cursor.fetchone()

        if not role_record:
            return jsonify({
                "success": False,
                "message": "Selected role is unavailable."
            }), 400

        password_hash = bcrypt.hashpw(
            password.encode("utf-8"),
            bcrypt.gensalt()
        ).decode("utf-8")

        cursor.execute("""
            INSERT INTO users
                (username, email, password_hash, full_name,
                 role, is_active, account_status)
            VALUES (%s, %s, %s, %s, %s, 1, 'PENDING')
        """, (username, email, password_hash, full_name, role))

        user_id = cursor.lastrowid

        cursor.execute("""
            INSERT INTO user_roles (user_id, role_id)
            VALUES (%s, %s)
        """, (user_id, role_record["role_id"]))

        connection.commit()

        return jsonify({
            "success": True,
            "message": "Registration submitted. Wait for Admin approval before logging in."
        }), 201

    except IntegrityError:
        if connection:
            connection.rollback()
        return jsonify({
            "success": False,
            "message": "Username or email already exists."
        }), 409

    except Error:
        if connection:
            connection.rollback()
        return jsonify({
            "success": False,
            "message": "Registration service temporarily unavailable."
        }), 503

    finally:
        if cursor:
            cursor.close()
        if connection and connection.is_connected():
            connection.close()


@auth_bp.route("/login", methods=["POST"])
def login():
    data = request.get_json(silent=True) or {}
    identifier = str(data.get("identifier", "")).strip()
    password = data.get("password", "")

    if not identifier or not isinstance(password, str) or not password:
        return jsonify({
            "success": False,
            "message": "Username/email and password are required."
        }), 400

    connection = None
    cursor = None

    try:
        connection = get_db_connection()
        cursor = connection.cursor(dictionary=True)

        cursor.execute("""
            SELECT user_id, username, email, password_hash,
                   full_name, role, is_active, account_status
            FROM users
            WHERE username = %s OR email = %s
            LIMIT 1
        """, (identifier, identifier))

        user = cursor.fetchone()

        if not user or not user["is_active"]:
            return jsonify({
                "success": False,
                "message": "Invalid credentials or inactive account."
            }), 401

        try:
            password_valid = bcrypt.checkpw(
                password.encode("utf-8"),
                user["password_hash"].encode("utf-8")
            )
        except (ValueError, TypeError):
            password_valid = False

        if not password_valid:
            return jsonify({
                "success": False,
                "message": "Invalid credentials or inactive account."
            }), 401

        if user["account_status"] == "PENDING":
            return jsonify({
                "success": False,
                "message": "Your account is awaiting Admin approval."
            }), 403

        if user["account_status"] != "APPROVED":
            return jsonify({
                "success": False,
                "message": "Your account has not been approved."
            }), 403

        cursor.execute(
            "UPDATE users SET last_login_at = CURRENT_TIMESTAMP WHERE user_id = %s",
            (user["user_id"],)
        )
        connection.commit()

        session.clear()
        session["user_id"] = user["user_id"]
        session["username"] = user["username"]
        session["role"] = user["role"]

        return jsonify({
            "success": True,
            "message": "Login successful.",
            "user": {
                "user_id": user["user_id"],
                "username": user["username"],
                "full_name": user["full_name"],
                "email": user["email"],
                "role": user["role"]
            }
        }), 200

    except Error:
        if connection:
            connection.rollback()
        return jsonify({
            "success": False,
            "message": "Authentication service temporarily unavailable."
        }), 503

    finally:
        if cursor:
            cursor.close()
        if connection and connection.is_connected():
            connection.close()


@auth_bp.route("/logout", methods=["POST"])
def logout():
    session.clear()
    return jsonify({
        "success": True,
        "message": "Logout successful."
    }), 200


@auth_bp.route("/me", methods=["GET"])
def current_user():
    user_id = session.get("user_id")

    if not user_id:
        return jsonify({
            "authenticated": False,
            "message": "Authentication required."
        }), 401

    connection = None
    cursor = None

    try:
        connection = get_db_connection()
        cursor = connection.cursor(dictionary=True)

        cursor.execute("""
            SELECT user_id, username, email, full_name,
                   role, is_active, account_status
            FROM users
            WHERE user_id = %s
        """, (user_id,))

        user = cursor.fetchone()

        if (
            not user
            or not user["is_active"]
            or user["account_status"] != "APPROVED"
        ):
            session.clear()
            return jsonify({
                "authenticated": False,
                "message": "Account unavailable or awaiting approval."
            }), 401

        return jsonify({
            "authenticated": True,
            "user": user
        }), 200

    except Error:
        return jsonify({
            "authenticated": False,
            "message": "Unable to verify session."
        }), 503

    finally:
        if cursor:
            cursor.close()
        if connection and connection.is_connected():
            connection.close()

@auth_bp.route("/admin/users", methods=["GET"])
@permission_required("USER_MANAGE")
def admin_list_users():
    connection = None
    cursor = None

    try:
        connection = get_db_connection()
        cursor = connection.cursor(dictionary=True)

        cursor.execute("""
            SELECT
                user_id,
                username,
                full_name,
                email,
                role,
                account_status,
                is_active,
                last_login_at,
                created_at
            FROM users
            ORDER BY created_at DESC
        """)

        users = cursor.fetchall()

        return jsonify({
            "success": True,
            "users": users
        }), 200

    except Error:
        return jsonify({
            "success": False,
            "message": "Could not retrieve users."
        }), 500

    finally:
        if cursor:
            cursor.close()
        if connection and connection.is_connected():
            connection.close()


@auth_bp.route("/admin/users/<int:user_id>/status", methods=["PATCH"])
@permission_required("USER_MANAGE")
def admin_update_user_status(user_id):
    data = request.get_json(silent=True) or {}
    new_status = str(data.get("status", "")).upper()

    if new_status not in ("APPROVED", "REJECTED"):
        return jsonify({
            "success": False,
            "message": "Status must be APPROVED or REJECTED."
        }), 400

    if user_id == session.get("user_id"):
        return jsonify({
            "success": False,
            "message": "You cannot change your own account status."
        }), 400

    connection = None
    cursor = None

    try:
        connection = get_db_connection()
        cursor = connection.cursor(dictionary=True)

        cursor.execute("""
            SELECT user_id, role
            FROM users
            WHERE user_id=%s
        """, (user_id,))

        user = cursor.fetchone()

        if not user:
            return jsonify({
                "success": False,
                "message": "User not found."
            }), 404

        if user["role"] not in ("DOCTOR", "NURSE", "RECEPTIONIST"):
            return jsonify({
                "success": False,
                "message": "Only staff registrations can be approved or rejected here."
            }), 403

        cursor.execute("""
            UPDATE users
            SET account_status=%s,
                is_active=%s
            WHERE user_id=%s
        """, (
            new_status,
            1 if new_status == "APPROVED" else 0,
            user_id
        ))

        connection.commit()

        return jsonify({
            "success": True,
            "message": f"User {new_status.lower()} successfully."
        }), 200

    except Error:
        if connection:
            connection.rollback()

        return jsonify({
            "success": False,
            "message": "Could not update user status."
        }), 500

    finally:
        if cursor:
            cursor.close()
        if connection and connection.is_connected():
            connection.close()
