
import os
from flask import Flask, jsonify, render_template
from mysql.connector import Error
from backend.config import Config
from backend.database.connection import get_db_connection

from backend.routes.auth_routes import auth_bp
from backend.routes.batch_routes import batch_bp
from backend.routes.recall_routes import recall_bp
from backend.routes.safety_routes import safety_bp
from backend.routes.medicine_routes import medicine_bp


# Project root directory
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def create_app():
    app = Flask(
        __name__,
        template_folder=os.path.join(BASE_DIR, "frontend", "templates"),
        static_folder=os.path.join(BASE_DIR, "frontend", "static"),
        static_url_path="/static"
    )

    app.config.from_object(Config)

    app.config.update(
        SESSION_COOKIE_HTTPONLY=True,
        SESSION_COOKIE_SAMESITE="Lax",
        SESSION_COOKIE_SECURE=False
    )

    # Register API blueprints
    app.register_blueprint(medicine_bp)
    app.register_blueprint(safety_bp, url_prefix="/api/medicines")
    app.register_blueprint(recall_bp, url_prefix="/api")
    app.register_blueprint(batch_bp, url_prefix="/api")
    app.register_blueprint(auth_bp)

    # Frontend dashboard
    @app.route("/")
    def index():
        return render_template("index.html")

    # Database health check
    @app.route("/api/health", methods=["GET"])
    def health():
        connection = None
        cursor = None

        try:
            connection = get_db_connection()
            cursor = connection.cursor(dictionary=True)

            cursor.execute("""
                SELECT DATABASE() AS database_name,
                       VERSION() AS mysql_version
            """)

            result = cursor.fetchone()

            return jsonify({
                "status": "healthy",
                "database": result
            }), 200

        except Error:
            return jsonify({
                "status": "unhealthy",
                "message": "Database connection failed"
            }), 503

        finally:
            if cursor:
                cursor.close()
            if connection and connection.is_connected():
                connection.close()

    return app


app = create_app()


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=5000, debug=True)
