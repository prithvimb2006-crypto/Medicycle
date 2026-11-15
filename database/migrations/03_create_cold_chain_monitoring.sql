-- ==============================================================================
-- MEDICYCLE: Medicine Intelligence, Safety & Lifecycle Ecosystem
-- Migration 03: Cold-Chain & Temperature Telemetry Monitoring (Pure DDL)
-- File: database/migrations/03_create_cold_chain_monitoring.sql
-- ==============================================================================
-- DDL TRANSACTIONAL LIMITATION NOTICE:
-- In MySQL, DDL statements cause implicit commits and are non-atomic. If this
-- script encounters an error, inspect the table state before retrying.
--
-- NOTE: Contains pure DDL table definition and schema constraints.
-- All simulated/demo telemetry data is isolated in separate demo seed files.
-- ==============================================================================

USE medicycle_db;

-- 1. Create Temperature Monitoring Logs Table
CREATE TABLE IF NOT EXISTS temperature_monitoring_logs (
    log_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    batch_id BIGINT UNSIGNED NOT NULL,
    recorded_temperature_celsius DECIMAL(4, 1) NOT NULL COMMENT 'Calibrated temperature in Celsius',
    recorded_humidity_percent DECIMAL(4, 1) NULL COMMENT 'Relative humidity percentage (0.0 to 100.0)',
    sensor_device_id VARCHAR(80) NOT NULL COMMENT 'IoT sensor identifier or wireless logger serial number',
    storage_location VARCHAR(120) NOT NULL COMMENT 'Warehouse zone, refrigerator unit, or transport vehicle container',
    reading_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Timestamp of temperature measurement',
    is_excursion BOOLEAN NOT NULL DEFAULT FALSE COMMENT 'Flagged TRUE if temperature breached storage rule limits',
    excursion_duration_minutes INT UNSIGNED NULL DEFAULT 0 COMMENT 'Duration in minutes outside allowed temperature range',
    action_taken TEXT NULL COMMENT 'Remediation or quarantine action executed if excursion detected',
    logged_by_user_id BIGINT UNSIGNED NULL COMMENT 'User or system account responsible for logging',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_temp_batch FOREIGN KEY (batch_id)
        REFERENCES medicine_batches(batch_id) ON DELETE RESTRICT,
    CONSTRAINT fk_temp_user FOREIGN KEY (logged_by_user_id)
        REFERENCES users(user_id) ON DELETE SET NULL,
    CONSTRAINT chk_humidity_range CHECK (
        recorded_humidity_percent IS NULL
        OR (
        recorded_humidity_percent >= 0.0
        AND recorded_humidity_percent <= 100.0
        )
        ),
    CONSTRAINT chk_temp_reasonable CHECK (
        recorded_temperature_celsius >= -80.0
        AND recorded_temperature_celsius <= 100.0
        ),
    CONSTRAINT chk_excursion_duration CHECK (
        is_excursion = FALSE
        OR excursion_duration_minutes IS NULL
        OR excursion_duration_minutes > 0
        ),

    INDEX idx_temp_batch_time (batch_id, reading_timestamp DESC),
    INDEX idx_temp_excursion (is_excursion),
    INDEX idx_temp_sensor (sensor_device_id)

   
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Cold-chain IoT telemetry and temperature excursion tracking';

-- 2. Register Migration strictly after DDL succeeds
INSERT INTO schema_migrations (migration_name, batch_number, execution_time_ms)
SELECT '03_create_cold_chain_monitoring.sql', 1, 0
WHERE NOT EXISTS (SELECT 1 FROM schema_migrations WHERE migration_name = '03_create_cold_chain_monitoring.sql');

-- ==============================================================================
-- ROLLBACK GUIDANCE:
-- DROP TABLE IF EXISTS temperature_monitoring_logs;
-- DELETE FROM schema_migrations WHERE migration_name = '03_create_cold_chain_monitoring.sql';
-- ==============================================================================
