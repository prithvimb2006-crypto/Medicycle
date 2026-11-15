
import mysql.connector
from mysql.connector import Error
from flask import current_app


def get_db_connection():
    """Create and return a MySQL database connection."""
    try:
        connection = mysql.connector.connect(
            host=current_app.config["DB_HOST"],
            port=current_app.config["DB_PORT"],
            user=current_app.config["DB_USER"],
            password=current_app.config["DB_PASSWORD"],
            database=current_app.config["DB_NAME"],
            connection_timeout=10,
            autocommit=False
        )

        return connection

    except Error as error:
        current_app.logger.error("Database connection failed: %s", error)
        raise
