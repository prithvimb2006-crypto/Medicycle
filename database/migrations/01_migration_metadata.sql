-- ==============================================================================
-- MEDICYCLE: Medicine Intelligence, Safety & Lifecycle Ecosystem
-- Migration 01: Schema Migrations Management Metadata
-- File: database/migrations/01_migration_metadata.sql
-- ==============================================================================
-- DDL TRANSACTIONAL LIMITATION NOTICE:
-- In MySQL, DDL statements cause implicit commits and are non-atomic.
-- If this script encounters an error, inspect database state before retrying.
--
-- COMPATIBILITY DEFENSE:
-- Prior to creating schema_migrations, this script checks if a table with that name
-- already exists. If it exists but has an incompatible schema (missing required columns),
-- execution ABORTS immediately via an intentional unresolvable call to halt execution.
-- ==============================================================================

USE medicycle_db;

-- 1. Pre-Check: If schema_migrations already exists, verify structural compatibility
SET @tbl_exists = (
    SELECT COUNT(*) 
    FROM information_schema.TABLES 
    WHERE TABLE_SCHEMA = 'medicycle_db' 
      AND TABLE_NAME = 'schema_migrations'
);

SET @col_count = (
    SELECT COUNT(*) 
    FROM information_schema.COLUMNS 
    WHERE TABLE_SCHEMA = 'medicycle_db' 
      AND TABLE_NAME = 'schema_migrations' 
      AND COLUMN_NAME IN ('migration_id', 'migration_name', 'batch_number', 'executed_at', 'execution_time_ms')
);

-- Abort if table exists but has an incompatible structure (fewer than 5 matching required columns)
SET @abort_incompatible = IF(@tbl_exists > 0 AND @col_count <> 5, 
    'CALL `ABORT_INCOMPATIBLE_schema_migrations_TABLE_ALREADY_EXISTS_IN_medicycle_db`()', 
    'SELECT 1'
);
PREPARE stmt_compat FROM @abort_incompatible;
EXECUTE stmt_compat;
DEALLOCATE PREPARE stmt_compat;

-- 2. Create Migration Ledger Table if not present
CREATE TABLE IF NOT EXISTS schema_migrations (
    migration_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    migration_name VARCHAR(150) NOT NULL UNIQUE,
    batch_number INT UNSIGNED NOT NULL DEFAULT 1,
    executed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    execution_time_ms INT UNSIGNED NOT NULL DEFAULT 0,
    INDEX idx_migration_batch (batch_number)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Audit ledger of executed database migrations';

-- 3. Register Migration 01 strictly after table creation succeeds
-- NOTE: execution_time_ms is initialized to 0; timing is measured by execution harnesses
INSERT INTO schema_migrations (migration_name, batch_number, execution_time_ms)
SELECT '01_migration_metadata.sql', 1, 0
WHERE NOT EXISTS (
    SELECT 1 FROM schema_migrations WHERE migration_name = '01_migration_metadata.sql'
);

-- ==============================================================================
-- ROLLBACK GUIDANCE:
-- DROP TABLE IF EXISTS schema_migrations;
-- ==============================================================================
