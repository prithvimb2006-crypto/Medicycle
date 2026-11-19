
CREATE DATABASE IF NOT EXISTS medicycle_db
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS 'medicycle_user'@'localhost' IDENTIFIED BY 'medicycle_secure_pass_2026';
CREATE USER IF NOT EXISTS 'medicycle_user'@'127.0.0.1' IDENTIFIED BY 'medicycle_secure_pass_2026';

GRANT ALL PRIVILEGES ON medicycle_db.* TO 'medicycle_user'@'localhost';
GRANT ALL PRIVILEGES ON medicycle_db.* TO 'medicycle_user'@'127.0.0.1';
FLUSH PRIVILEGES;

USE medicycle_db;
