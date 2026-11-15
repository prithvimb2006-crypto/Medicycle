-- ==============================================================================
-- MEDICYCLE: Medicine Intelligence, Safety & Lifecycle Ecosystem
-- Database Initialization & Security Isolation Script
-- File: database/schema/01_create_database.sql
-- ==============================================================================

-- 1. Create the dedicated MEDICYCLE database with utf8mb4 charset and unicode collation
CREATE DATABASE IF NOT EXISTS medicycle_db
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

-- 2. Create the application user with local access permissions (Role-Based Access Control)
CREATE USER IF NOT EXISTS 'medicycle_user'@'localhost' IDENTIFIED BY 'medicycle_secure_pass_2026';
CREATE USER IF NOT EXISTS 'medicycle_user'@'127.0.0.1' IDENTIFIED BY 'medicycle_secure_pass_2026';

-- 3. Grant scoped privileges on medicycle_db only (Least Privilege Principle)
GRANT ALL PRIVILEGES ON medicycle_db.* TO 'medicycle_user'@'localhost';
GRANT ALL PRIVILEGES ON medicycle_db.* TO 'medicycle_user'@'127.0.0.1';

-- 4. Flush privileges to ensure access tables take effect immediately
FLUSH PRIVILEGES;

USE medicycle_db;
