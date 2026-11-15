USE medicycle_db;


SET @rb_collision = (
    SELECT COUNT(*) 
    FROM information_schema.ROUTINES 
    WHERE ROUTINE_SCHEMA = 'medicycle_db' 
      AND ROUTINE_NAME = 'sp_medicycle_tmp_validate_rollback_ownership'
);

SET @abort_rb = IF(@rb_collision > 0, 
    'CALL `ABORT_ROUTINE_COLLISION_sp_medicycle_tmp_validate_rollback_ownership_ALREADY_EXISTS`()', 
    'SELECT 1'
);
PREPARE stmt_rb FROM @abort_rb; 
EXECUTE stmt_rb; 
DEALLOCATE PREPARE stmt_rb;

DELIMITER $$
CREATE PROCEDURE sp_medicycle_tmp_validate_rollback_ownership()
BEGIN
    DECLARE v_has_schema_migrations INT DEFAULT 0;
    DECLARE v_orig_count INT DEFAULT 0;
    DECLARE v_unknown_mig INT DEFAULT 0;

    -- Migration 08 checks
    DECLARE v_m08_reg INT DEFAULT 0;
    DECLARE v_m08_trg_count INT DEFAULT 0;

    -- Migration 07 checks
    DECLARE v_m07_reg INT DEFAULT 0;
    DECLARE v_m07_view_count INT DEFAULT 0;
    DECLARE v_m07_idx_count INT DEFAULT 0;

    -- Migration 06-03 checks
    DECLARE v_m06_reg INT DEFAULT 0;
    DECLARE v_m06_tbl_count INT DEFAULT 0;
    DECLARE v_m05_reg INT DEFAULT 0;
    DECLARE v_m05_tbl_count INT DEFAULT 0;
    DECLARE v_m04_reg INT DEFAULT 0;
    DECLARE v_m04_tbl_count INT DEFAULT 0;
    DECLARE v_m03_reg INT DEFAULT 0;
    DECLARE v_m03_tbl_count INT DEFAULT 0;

    -- Migration 02 checks
    DECLARE v_m02_reg INT DEFAULT 0;
    DECLARE v_m02_tbl_count INT DEFAULT 0;

    -- 1. Ensure schema_migrations table exists
    SELECT COUNT(*) INTO v_has_schema_migrations
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = 'medicycle_db' AND TABLE_NAME = 'schema_migrations';

    IF v_has_schema_migrations = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'ABORT: schema_migrations table does not exist. Cannot verify migration registration or ownership. Manual inspection required.';
    END IF;

    -- 2. Verify all 19 original master tables exist intact
    SELECT COUNT(*) INTO v_orig_count
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = 'medicycle_db'
      AND TABLE_TYPE = 'BASE TABLE'
      AND TABLE_NAME IN (
          'source_references', 'users', 'categories', 'manufacturers', 'ingredients',
          'medicines', 'medicine_compositions', 'medicine_uses', 'medicine_batches',
          'storage_rules', 'drug_interactions', 'side_effects', 'contraindications',
          'disposal_guidelines', 'recall_records', 'recall_medicines', 'safety_alerts',
          'scan_records', 'audit_logs'
      );

    IF v_orig_count <> 19 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'ABORT: Baseline table count mismatch. One or more original MEDICYCLE master tables are missing. Halting rollback.';
    END IF;

    -- 3. Detect any unrecognized migration names in schema_migrations
    SELECT COUNT(*) INTO v_unknown_mig
    FROM schema_migrations
    WHERE migration_name NOT IN (
        '01_migration_metadata.sql',
        '02_create_rbac_tables.sql',
        '03_create_cold_chain_monitoring.sql',
        '04_create_ocr_extractions.sql',
        '05_create_environmental_impact_records.sql',
        '06_create_disposal_events.sql',
        '07_create_core_views_and_indexes.sql',
        '08_create_audit_triggers.sql'
    );

    IF v_unknown_mig > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'ABORT: Unrecognized migration entries detected in schema_migrations. Manual inspection required.';
    END IF;

    -- 4. Ambiguity Check: Migration 08
    SELECT COUNT(*) INTO v_m08_reg FROM schema_migrations WHERE migration_name = '08_create_audit_triggers.sql';
    SELECT COUNT(*) INTO v_m08_trg_count FROM information_schema.TRIGGERS
    WHERE TRIGGER_SCHEMA = 'medicycle_db'
      AND TRIGGER_NAME IN ('trg_medicycle_medicines_audit_update', 'trg_medicycle_batches_audit_update', 'trg_medicycle_recalls_audit_insert');
    IF v_m08_reg = 0 AND v_m08_trg_count > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'ABORT: Ambiguous state - Migration 08 is not registered in schema_migrations, but Phase 2 audit triggers exist. Manual inspection required.';
    END IF;

    -- 5. Ambiguity Check: Migration 07
    SELECT COUNT(*) INTO v_m07_reg FROM schema_migrations WHERE migration_name = '07_create_core_views_and_indexes.sql';
    SELECT COUNT(*) INTO v_m07_view_count FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = 'medicycle_db'
      AND TABLE_NAME IN ('v_medicine_digital_passport', 'v_active_recalls_inventory', 'v_cold_chain_excursion_alerts', 'v_expiring_batches_summary');
    SELECT COUNT(*) INTO v_m07_idx_count FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = 'medicycle_db'
      AND ((TABLE_NAME = 'medicine_batches' AND INDEX_NAME = 'idx_batch_med_expiry_status')
           OR (TABLE_NAME = 'scan_records' AND INDEX_NAME = 'idx_scan_status_time'));
    IF v_m07_reg = 0 AND (v_m07_view_count > 0 OR v_m07_idx_count > 0) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'ABORT: Ambiguous state - Migration 07 is not registered in schema_migrations, but target views or indexes exist. Manual inspection required.';
    END IF;

    -- 6. Ambiguity Check: Migration 06
    SELECT COUNT(*) INTO v_m06_reg FROM schema_migrations WHERE migration_name = '06_create_disposal_events.sql';
    SELECT COUNT(*) INTO v_m06_tbl_count FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = 'medicycle_db' AND TABLE_NAME = 'medicine_disposal_logs';
    IF v_m06_reg = 0 AND v_m06_tbl_count > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'ABORT: Ambiguous state - Migration 06 is not registered, but medicine_disposal_logs exists. Manual inspection required.';
    END IF;

    -- 7. Ambiguity Check: Migration 05
    SELECT COUNT(*) INTO v_m05_reg FROM schema_migrations WHERE migration_name = '05_create_environmental_impact_records.sql';
    SELECT COUNT(*) INTO v_m05_tbl_count FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = 'medicycle_db' AND TABLE_NAME = 'environmental_impact_records';
    IF v_m05_reg = 0 AND v_m05_tbl_count > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'ABORT: Ambiguous state - Migration 05 is not registered, but environmental_impact_records exists. Manual inspection required.';
    END IF;

    -- 8. Ambiguity Check: Migration 04
    SELECT COUNT(*) INTO v_m04_reg FROM schema_migrations WHERE migration_name = '04_create_ocr_extractions.sql';
    SELECT COUNT(*) INTO v_m04_tbl_count FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = 'medicycle_db' AND TABLE_NAME = 'ocr_extraction_records';
    IF v_m04_reg = 0 AND v_m04_tbl_count > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'ABORT: Ambiguous state - Migration 04 is not registered, but ocr_extraction_records exists. Manual inspection required.';
    END IF;

    -- 9. Ambiguity Check: Migration 03
    SELECT COUNT(*) INTO v_m03_reg FROM schema_migrations WHERE migration_name = '03_create_cold_chain_monitoring.sql';
    SELECT COUNT(*) INTO v_m03_tbl_count FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = 'medicycle_db' AND TABLE_NAME = 'temperature_monitoring_logs';
    IF v_m03_reg = 0 AND v_m03_tbl_count > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'ABORT: Ambiguous state - Migration 03 is not registered, but temperature_monitoring_logs exists. Manual inspection required.';
    END IF;

    -- 10. Ambiguity Check: Migration 02
    SELECT COUNT(*) INTO v_m02_reg FROM schema_migrations WHERE migration_name = '02_create_rbac_tables.sql';
    SELECT COUNT(*) INTO v_m02_tbl_count FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = 'medicycle_db'
      AND TABLE_NAME IN ('user_roles', 'role_permissions', 'permissions', 'roles');
    IF v_m02_reg = 0 AND v_m02_tbl_count > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'ABORT: Ambiguous state - Migration 02 is not registered, but RBAC tables exist. Manual inspection required.';
    END IF;

END$$
DELIMITER ;

CALL sp_medicycle_tmp_validate_rollback_ownership();
DROP PROCEDURE sp_medicycle_tmp_validate_rollback_ownership;

-- ------------------------------------------------------------------------------
-- STEP 3: EXECUTE VERIFIED REVERSE MIGRATIONS (08 -> 01)
-- ------------------------------------------------------------------------------

-- 1. Rollback Migration 08 (Audit Triggers - Verified Ownership)
SET @m08_reg = (
    SELECT COUNT(*)
    FROM schema_migrations
    WHERE migration_name = '08_create_audit_triggers.sql'
);

SET @drop_m08_triggers = IF(
    @m08_reg > 0,
    'DROP TRIGGER IF EXISTS trg_medicycle_recalls_audit_insert',
    'SELECT 1'
);
PREPARE stmt_m08_1 FROM @drop_m08_triggers;
EXECUTE stmt_m08_1;
DEALLOCATE PREPARE stmt_m08_1;

SET @drop_m08_triggers = IF(
    @m08_reg > 0,
    'DROP TRIGGER IF EXISTS trg_medicycle_batches_audit_update',
    'SELECT 1'
);
PREPARE stmt_m08_2 FROM @drop_m08_triggers;
EXECUTE stmt_m08_2;
DEALLOCATE PREPARE stmt_m08_2;

SET @drop_m08_triggers = IF(
    @m08_reg > 0,
    'DROP TRIGGER IF EXISTS trg_medicycle_medicines_audit_update',
    'SELECT 1'
);
PREPARE stmt_m08_3 FROM @drop_m08_triggers;
EXECUTE stmt_m08_3;
DEALLOCATE PREPARE stmt_m08_3;

DELETE FROM schema_migrations
WHERE migration_name = '08_create_audit_triggers.sql'
AND @m08_reg > 0;

-- 2. Rollback Migration 07 (Analytical Views & Secondary Indexes - Verified Ownership)
-- 2. Rollback Migration 07 (Analytical Views & Secondary Indexes - Verified Ownership)

SET @m07_reg = (
    SELECT COUNT(*)
    FROM schema_migrations
    WHERE migration_name = '07_create_core_views_and_indexes.sql'
);

-- Drop only confirmed views, and only when Migration 07 is registered.

SET @drop_view = IF(
    @m07_reg > 0
    AND EXISTS (
        SELECT 1 FROM information_schema.TABLES
        WHERE TABLE_SCHEMA = 'medicycle_db'
        AND TABLE_NAME = 'v_expiring_batches_summary'
        AND TABLE_TYPE = 'VIEW'
    ),
    'DROP VIEW v_expiring_batches_summary',
    'SELECT 1'
);
PREPARE stmt_view1 FROM @drop_view;
EXECUTE stmt_view1;
DEALLOCATE PREPARE stmt_view1;

SET @drop_view = IF(
    @m07_reg > 0
    AND EXISTS (
        SELECT 1 FROM information_schema.TABLES
        WHERE TABLE_SCHEMA = 'medicycle_db'
        AND TABLE_NAME = 'v_cold_chain_excursion_alerts'
        AND TABLE_TYPE = 'VIEW'
    ),
    'DROP VIEW v_cold_chain_excursion_alerts',
    'SELECT 1'
);
PREPARE stmt_view2 FROM @drop_view;
EXECUTE stmt_view2;
DEALLOCATE PREPARE stmt_view2;

SET @drop_view = IF(
    @m07_reg > 0
    AND EXISTS (
        SELECT 1 FROM information_schema.TABLES
        WHERE TABLE_SCHEMA = 'medicycle_db'
        AND TABLE_NAME = 'v_active_recalls_inventory'
        AND TABLE_TYPE = 'VIEW'
    ),
    'DROP VIEW v_active_recalls_inventory',
    'SELECT 1'
);
PREPARE stmt_view3 FROM @drop_view;
EXECUTE stmt_view3;
DEALLOCATE PREPARE stmt_view3;

SET @drop_view = IF(
    @m07_reg > 0
    AND EXISTS (
        SELECT 1 FROM information_schema.TABLES
        WHERE TABLE_SCHEMA = 'medicycle_db'
        AND TABLE_NAME = 'v_medicine_digital_passport'
        AND TABLE_TYPE = 'VIEW'
    ),
    'DROP VIEW v_medicine_digital_passport',
    'SELECT 1'
);
PREPARE stmt_view4 FROM @drop_view;
EXECUTE stmt_view4;
DEALLOCATE PREPARE stmt_view4;

-- Drop indexes only if migration 07 is verified as registered and index exists
SET @drop_idx1 = IF(@m07_reg > 0, 
    (SELECT IF(COUNT(*) > 0, 'ALTER TABLE medicine_batches DROP INDEX idx_batch_med_expiry_status', 'SELECT 1')
     FROM information_schema.STATISTICS 
     WHERE TABLE_SCHEMA = 'medicycle_db' AND TABLE_NAME = 'medicine_batches' AND INDEX_NAME = 'idx_batch_med_expiry_status'),
    'SELECT 1'
);
PREPARE stmt_drop_idx1 FROM @drop_idx1; 
EXECUTE stmt_drop_idx1; 
DEALLOCATE PREPARE stmt_drop_idx1;

SET @drop_idx2 = IF(@m07_reg > 0, 
    (SELECT IF(COUNT(*) > 0, 'ALTER TABLE scan_records DROP INDEX idx_scan_status_time', 'SELECT 1')
     FROM information_schema.STATISTICS 
     WHERE TABLE_SCHEMA = 'medicycle_db' AND TABLE_NAME = 'scan_records' AND INDEX_NAME = 'idx_scan_status_time'),
    'SELECT 1'
);
PREPARE stmt_drop_idx2 FROM @drop_idx2; 
EXECUTE stmt_drop_idx2; 
DEALLOCATE PREPARE stmt_drop_idx2;

DELETE FROM schema_migrations WHERE migration_name = '07_create_core_views_and_indexes.sql'
AND @m07_reg > 0;

-- 3. Rollback Migration 06 (Medicine Disposal Logs - Verified Ownership)
SET @m06_reg = (SELECT COUNT(*) FROM schema_migrations WHERE migration_name = '06_create_disposal_events.sql');
SET @drop_m06 = IF(@m06_reg > 0, 'DROP TABLE IF EXISTS medicine_disposal_logs', 'SELECT 1');
PREPARE stmt_drop_m06 FROM @drop_m06; 
EXECUTE stmt_drop_m06; 
DEALLOCATE PREPARE stmt_drop_m06;
DELETE FROM schema_migrations WHERE migration_name = '06_create_disposal_events.sql'
AND @m06_reg > 0;

-- 4. Rollback Migration 05 (Environmental Impact Records - Verified Ownership)
SET @m05_reg = (SELECT COUNT(*) FROM schema_migrations WHERE migration_name = '05_create_environmental_impact_records.sql');
SET @drop_m05 = IF(@m05_reg > 0, 'DROP TABLE IF EXISTS environmental_impact_records', 'SELECT 1');
PREPARE stmt_drop_m05 FROM @drop_m05; 
EXECUTE stmt_drop_m05; 
DEALLOCATE PREPARE stmt_drop_m05;
DELETE FROM schema_migrations WHERE migration_name = '05_create_environmental_impact_records.sql'
AND @m05_reg > 0;

-- 5. Rollback Migration 04 (OCR Extraction Records - Verified Ownership)
SET @m04_reg = (SELECT COUNT(*) FROM schema_migrations WHERE migration_name = '04_create_ocr_extractions.sql');
SET @drop_m04 = IF(@m04_reg > 0, 'DROP TABLE IF EXISTS ocr_extraction_records', 'SELECT 1');
PREPARE stmt_drop_m04 FROM @drop_m04; 
EXECUTE stmt_drop_m04; 
DEALLOCATE PREPARE stmt_drop_m04;
DELETE FROM schema_migrations WHERE migration_name = '04_create_ocr_extractions.sql'
AND @m04_reg > 0;

-- 6. Rollback Migration 03 (Cold-Chain Logs - Verified Ownership)
SET @m03_reg = (SELECT COUNT(*) FROM schema_migrations WHERE migration_name = '03_create_cold_chain_monitoring.sql');
SET @drop_m03 = IF(@m03_reg > 0, 'DROP TABLE IF EXISTS temperature_monitoring_logs', 'SELECT 1');
PREPARE stmt_drop_m03 FROM @drop_m03; 
EXECUTE stmt_drop_m03; 
DEALLOCATE PREPARE stmt_drop_m03;
DELETE FROM schema_migrations WHERE migration_name = '03_create_cold_chain_monitoring.sql'
AND @m03_reg > 0;

-- 7. Rollback Migration 02 (RBAC Framework - Verified Ownership, Child-to-Parent)
SET @m02_reg = (SELECT COUNT(*) FROM schema_migrations WHERE migration_name = '02_create_rbac_tables.sql');

SET @drop_m02_ur = IF(@m02_reg > 0, 'DROP TABLE IF EXISTS user_roles', 'SELECT 1');
PREPARE stmt_drop_m02_ur FROM @drop_m02_ur; EXECUTE stmt_drop_m02_ur; DEALLOCATE PREPARE stmt_drop_m02_ur;

SET @drop_m02_rp = IF(@m02_reg > 0, 'DROP TABLE IF EXISTS role_permissions', 'SELECT 1');
PREPARE stmt_drop_m02_rp FROM @drop_m02_rp; EXECUTE stmt_drop_m02_rp; DEALLOCATE PREPARE stmt_drop_m02_rp;

SET @drop_m02_p = IF(@m02_reg > 0, 'DROP TABLE IF EXISTS permissions', 'SELECT 1');
PREPARE stmt_drop_m02_p FROM @drop_m02_p; EXECUTE stmt_drop_m02_p; DEALLOCATE PREPARE stmt_drop_m02_p;

SET @drop_m02_r = IF(@m02_reg > 0, 'DROP TABLE IF EXISTS roles', 'SELECT 1');
PREPARE stmt_drop_m02_r FROM @drop_m02_r; EXECUTE stmt_drop_m02_r; DEALLOCATE PREPARE stmt_drop_m02_r;

DELETE FROM schema_migrations WHERE migration_name = '02_create_rbac_tables.sql'
AND @m02_reg > 0;

-- 8. Rollback Migration 01 (Schema Migration Ledger - Only if no other migrations remain)
SET @m01_reg = (
    SELECT COUNT(*)
    FROM schema_migrations
    WHERE migration_name = '01_migration_metadata.sql'
);

SET @remaining_mig = (
    SELECT COUNT(*)
    FROM schema_migrations
    WHERE migration_name <> '01_migration_metadata.sql'
);

SET @drop_m01 = IF(
    @m01_reg > 0 AND @remaining_mig = 0,
    'DROP TABLE schema_migrations',
    'SELECT 1'
);

PREPARE stmt_drop_m01 FROM @drop_m01;
EXECUTE stmt_drop_m01;
DEALLOCATE PREPARE stmt_drop_m01;
SHOW FULL TABLES;
