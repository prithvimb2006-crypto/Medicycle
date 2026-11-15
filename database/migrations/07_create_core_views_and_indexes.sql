
USE medicycle_db;

-- 1. Routine Collision Pre-Check
SET @p07_collision = (
    SELECT COUNT(*) 
    FROM information_schema.ROUTINES 
    WHERE ROUTINE_SCHEMA = 'medicycle_db' 
      AND ROUTINE_NAME = 'sp_medicycle_tmp_check_m07_collisions'
);

SET @abort_p07 = IF(@p07_collision > 0, 
    'CALL `ABORT_ROUTINE_COLLISION_sp_medicycle_tmp_check_m07_collisions_ALREADY_EXISTS`()', 
    'SELECT 1'
);
PREPARE stmt_p07 FROM @abort_p07; 
EXECUTE stmt_p07; 
DEALLOCATE PREPARE stmt_p07;

DELIMITER $$
CREATE PROCEDURE sp_medicycle_tmp_check_m07_collisions()
BEGIN
    DECLARE v_table_count INT DEFAULT 0;
    DECLARE v_idx_count INT DEFAULT 0;

    -- Check information_schema.TABLES (detects both views and base tables with colliding names)
    SELECT COUNT(*) INTO v_table_count 
    FROM information_schema.TABLES 
    WHERE TABLE_SCHEMA = 'medicycle_db' 
      AND TABLE_NAME IN (
          'v_medicine_digital_passport', 
          'v_active_recalls_inventory', 
          'v_cold_chain_excursion_alerts', 
          'v_expiring_batches_summary'
      );

    IF v_table_count > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'ABORT: Target view or table collision detected in information_schema.TABLES. Migration 07 halted.';
    END IF;

    -- Check information_schema.STATISTICS for proposed index names
    SELECT COUNT(*) INTO v_idx_count 
    FROM information_schema.STATISTICS 
    WHERE TABLE_SCHEMA = 'medicycle_db' 
      AND (
        (TABLE_NAME = 'medicine_batches' AND INDEX_NAME = 'idx_batch_med_expiry_status')
        OR (TABLE_NAME = 'scan_records' AND INDEX_NAME = 'idx_scan_status_time')
      );

    IF v_idx_count > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'ABORT: Target index collision detected. Index already exists. Migration 07 halted to protect existing indexes.';
    END IF;
END$$
DELIMITER ;

CALL sp_medicycle_tmp_check_m07_collisions();
DROP PROCEDURE sp_medicycle_tmp_check_m07_collisions;

-- 2. View: Medicine Digital Passport 360-Degree Profile
CREATE VIEW v_medicine_digital_passport AS
SELECT 
    m.medicine_id,
    m.brand_name,
    m.generic_name,
    c.category_name,
    c.atc_code_prefix,
    mfr.name AS manufacturer_name,
    mfr.country AS manufacturer_country,
    m.dosage_form,
    m.strength,
    m.administration_route,
    m.prescription_classification,
    m.barcode_upc,
    m.ndc_number,
    m.is_active,
    s.min_temp_celsius,
    s.max_temp_celsius,
    s.requires_refrigeration,
    s.light_sensitive,
    s.moisture_sensitive,
    d.disposal_method,
    d.environmental_hazard_rating,
    d.aquatic_toxicity_risk,
    (
        SELECT GROUP_CONCAT(CONCAT(i.generic_name, ' (', mc.strength_value, ' ', mc.strength_unit, ')') SEPARATOR ', ')
        FROM medicine_compositions mc
        JOIN ingredients i ON mc.ingredient_id = i.ingredient_id
        WHERE mc.medicine_id = m.medicine_id
        AND mc.is_active_ingredient = 1
    ) AS active_composition_summary,
    (
        SELECT COUNT(*) 
        FROM safety_alerts sa 
        WHERE sa.medicine_id = m.medicine_id
    ) AS safety_alert_count,
    m.created_at,
    m.updated_at
FROM medicines m
JOIN categories c ON m.category_id = c.category_id
JOIN manufacturers mfr ON m.manufacturer_id = mfr.manufacturer_id
LEFT JOIN storage_rules s ON m.medicine_id = s.medicine_id
LEFT JOIN disposal_guidelines d ON m.medicine_id = d.medicine_id;

-- 3. View: Active Regulatory Recalls and Inventory Impact (Medicine-Wide vs Batch-Specific Scope)
CREATE VIEW v_active_recalls_inventory AS
SELECT 
    r.recall_id,
    r.recall_reference_code,
    r.issuing_authority,
    r.recall_class,
    r.status AS recall_status,
    r.announcement_date,
    m.medicine_id,
    m.brand_name,
    m.generic_name,
    CASE 
        WHEN rm.batch_id IS NULL THEN 'MEDICINE_WIDE' 
        ELSE 'BATCH_SPECIFIC' 
    END AS recall_scope,
    (rm.batch_id IS NULL) AS is_medicine_wide,
    rm.batch_id AS declared_recall_batch_id,
    b.batch_id AS affected_inventory_batch_id,
    b.batch_number AS affected_batch_number,
    b.expiry_date AS batch_expiry_date,
    b.initial_quantity AS batch_initial_quantity,
    b.status AS batch_inventory_status,
    rm.affected_lot_description,
    r.action_required
FROM recall_records r
JOIN recall_medicines rm ON r.recall_id = rm.recall_id
JOIN medicines m ON rm.medicine_id = m.medicine_id
LEFT JOIN medicine_batches b ON (
    (rm.batch_id IS NOT NULL AND rm.batch_id = b.batch_id)
    OR
    (rm.batch_id IS NULL AND m.medicine_id = b.medicine_id)
)
WHERE r.status = 'ACTIVE';

-- 4. View: Cold-Chain Active Excursions & Critical Alerts
CREATE VIEW v_cold_chain_excursion_alerts AS
SELECT 
    tl.log_id,
    b.batch_id,
    b.batch_number,
    m.medicine_id,
    m.brand_name,
    s.min_temp_celsius AS rule_min_temp,
    s.max_temp_celsius AS rule_max_temp,
    tl.recorded_temperature_celsius AS actual_temp,
    ROUND(
        CASE
            WHEN s.rule_id IS NULL THEN NULL
            WHEN tl.recorded_temperature_celsius > s.max_temp_celsius
                THEN tl.recorded_temperature_celsius - s.max_temp_celsius
            WHEN tl.recorded_temperature_celsius < s.min_temp_celsius
                THEN s.min_temp_celsius - tl.recorded_temperature_celsius
        ELSE 0
    END
    ) AS deviation_degrees_celsius,
    tl.recorded_humidity_percent,
    tl.sensor_device_id,
    tl.storage_location,
    tl.reading_timestamp,
    tl.excursion_duration_minutes,
    tl.action_taken
FROM temperature_monitoring_logs tl
JOIN medicine_batches b ON tl.batch_id = b.batch_id
JOIN medicines m ON b.medicine_id = m.medicine_id
LEFT JOIN storage_rules s ON m.medicine_id = s.medicine_id
WHERE tl.is_excursion = TRUE;

-- 5. View: Batch Expiration Risk Matrix
CREATE VIEW v_expiring_batches_summary AS
SELECT 
    b.batch_id,
    m.medicine_id,
    m.brand_name,
    m.generic_name,
    b.batch_number,
    b.manufacturing_date,
    b.expiry_date,
    DATEDIFF(b.expiry_date, CURDATE()) AS days_until_expiry,
    CASE 
        WHEN b.expiry_date < CURDATE() THEN 'EXPIRED'
        WHEN DATEDIFF(b.expiry_date, CURDATE()) <= 30 THEN 'EXPIRING_SOON'
        ELSE 'STABLE'
    END AS calculated_shelf_life_status,
    b.status AS registered_status,
    b.initial_quantity
FROM medicine_batches b
JOIN medicines m ON b.medicine_id = m.medicine_id;

-- 6. Add Secondary Indexes to Existing Tables (Collision pre-checked in Step 1)
ALTER TABLE medicine_batches 
    ADD INDEX idx_batch_med_expiry_status (medicine_id, expiry_date, status);

ALTER TABLE scan_records 
    ADD INDEX idx_scan_status_time (verification_status, scan_timestamp DESC);

-- 7. Register Migration strictly after DDL succeeds
INSERT INTO schema_migrations (migration_name, batch_number, execution_time_ms)
SELECT '07_create_core_views_and_indexes.sql', 1, 0
WHERE NOT EXISTS (SELECT 1 FROM schema_migrations WHERE migration_name = '07_create_core_views_and_indexes.sql');

