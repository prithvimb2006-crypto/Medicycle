
USE medicycle_db;
SET @p08_collision = (
    SELECT COUNT(*) 
    FROM information_schema.ROUTINES 
    WHERE ROUTINE_SCHEMA = 'medicycle_db' 
      AND ROUTINE_NAME = 'sp_medicycle_tmp_check_m08_trigger_collisions'
);

SET @abort_p08 = IF(@p08_collision > 0, 
    'CALL `ABORT_ROUTINE_COLLISION_sp_medicycle_tmp_check_m08_trigger_collisions_ALREADY_EXISTS`()', 
    'SELECT 1'
);
PREPARE stmt_p08 FROM @abort_p08; 
EXECUTE stmt_p08; 
DEALLOCATE PREPARE stmt_p08;

DELIMITER $$
CREATE PROCEDURE sp_medicycle_tmp_check_m08_trigger_collisions()
BEGIN
    DECLARE v_trg_count INT DEFAULT 0;

    SELECT COUNT(*) INTO v_trg_count 
    FROM information_schema.TRIGGERS 
    WHERE TRIGGER_SCHEMA = 'medicycle_db' 
      AND TRIGGER_NAME IN (
          'trg_medicycle_medicines_audit_update', 
          'trg_medicycle_batches_audit_update', 
          'trg_medicycle_recalls_audit_insert'
      );

    IF v_trg_count > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'ABORT: Trigger collision detected. One or more namespaced audit triggers already exist in medicycle_db. Migration 08 halted.';
    END IF;
END$$
DELIMITER ;

CALL sp_medicycle_tmp_check_m08_trigger_collisions();
DROP PROCEDURE sp_medicycle_tmp_check_m08_trigger_collisions;

DELIMITER $$

-- 2. Trigger: Capture Medicine Updates into audit_logs
CREATE TRIGGER trg_medicycle_medicines_audit_update
AFTER UPDATE ON medicines
FOR EACH ROW
BEGIN
    DECLARE v_actor_user_id BIGINT UNSIGNED DEFAULT NULL;

    -- Safely resolve user actor using MAX() to prevent runtime failure
    IF @current_user_id IS NOT NULL THEN
        SELECT MAX(user_id) INTO v_actor_user_id 
        FROM users 
        WHERE user_id = @current_user_id;
    END IF;

    INSERT INTO audit_logs (
        table_name,
        record_id,
        action_type,
        changed_by_user_id,
        old_values,
        new_values,
        ip_address,
        logged_at
    ) VALUES (
        'medicines',
        NEW.medicine_id,
        'UPDATE',
        v_actor_user_id,
        JSON_OBJECT(
            'brand_name', OLD.brand_name,
            'generic_name', OLD.generic_name,
            'strength', OLD.strength,
            'dosage_form', OLD.dosage_form,
            'is_active', OLD.is_active
        ),
        JSON_OBJECT(
            'brand_name', NEW.brand_name,
            'generic_name', NEW.generic_name,
            'strength', NEW.strength,
            'dosage_form', NEW.dosage_form,
            'is_active', NEW.is_active
        ),
        CASE 
            WHEN @client_ip IS NOT NULL AND CHAR_LENGTH(TRIM(@client_ip)) > 0 
            THEN SUBSTRING(TRIM(@client_ip), 1, 45) 
            ELSE NULL 
        END,
        CURRENT_TIMESTAMP
    );
END$$

-- 3. Trigger: Capture Batch Status, Expiry & Quantity Changes with Null-Safe Operator (<=>)
CREATE TRIGGER trg_medicycle_batches_audit_update
AFTER UPDATE ON medicine_batches
FOR EACH ROW
BEGIN
    DECLARE v_actor_user_id BIGINT UNSIGNED DEFAULT NULL;

    -- Null-safe evaluation: NOT (A <=> B) is TRUE if either value changes, handling NULLs safely
    IF NOT (OLD.status <=> NEW.status) 
       OR NOT (OLD.expiry_date <=> NEW.expiry_date) 
       OR NOT (OLD.initial_quantity <=> NEW.initial_quantity) THEN

        IF @current_user_id IS NOT NULL THEN
            SELECT MAX(user_id) INTO v_actor_user_id 
            FROM users 
            WHERE user_id = @current_user_id;
        END IF;

        INSERT INTO audit_logs (
            table_name,
            record_id,
            action_type,
            changed_by_user_id,
            old_values,
            new_values,
            ip_address,
            logged_at
        ) VALUES (
            'medicine_batches',
            NEW.batch_id,
            'UPDATE',
            v_actor_user_id,
            JSON_OBJECT(
                'batch_number', OLD.batch_number,
                'status', OLD.status,
                'expiry_date', OLD.expiry_date,
                'initial_quantity', OLD.initial_quantity
            ),
            JSON_OBJECT(
                'batch_number', NEW.batch_number,
                'status', NEW.status,
                'expiry_date', NEW.expiry_date,
                'initial_quantity', NEW.initial_quantity
            ),
            CASE 
                WHEN @client_ip IS NOT NULL AND CHAR_LENGTH(TRIM(@client_ip)) > 0 
                THEN SUBSTRING(TRIM(@client_ip), 1, 45) 
                ELSE NULL 
            END,
            CURRENT_TIMESTAMP
        );
    END IF;
END$$

-- 4. Trigger: Capture New Regulatory Recall Issuances
CREATE TRIGGER trg_medicycle_recalls_audit_insert
AFTER INSERT ON recall_records
FOR EACH ROW
BEGIN
    DECLARE v_actor_user_id BIGINT UNSIGNED DEFAULT NULL;

    IF @current_user_id IS NOT NULL THEN
        SELECT MAX(user_id) INTO v_actor_user_id 
        FROM users 
        WHERE user_id = @current_user_id;
    END IF;

    INSERT INTO audit_logs (
        table_name,
        record_id,
        action_type,
        changed_by_user_id,
        old_values,
        new_values,
        ip_address,
        logged_at
    ) VALUES (
        'recall_records',
        NEW.recall_id,
        'INSERT',
        v_actor_user_id,
        NULL,
        JSON_OBJECT(
            'recall_reference_code', NEW.recall_reference_code,
            'issuing_authority', NEW.issuing_authority,
            'recall_class', NEW.recall_class,
            'status', NEW.status,
            'announcement_date', NEW.announcement_date
        ),
        CASE 
            WHEN @client_ip IS NOT NULL AND CHAR_LENGTH(TRIM(@client_ip)) > 0 
            THEN SUBSTRING(TRIM(@client_ip), 1, 45) 
            ELSE NULL 
        END,
        CURRENT_TIMESTAMP
    );
END$$

DELIMITER ;

-- 5. Register Migration strictly after all triggers are created
INSERT INTO schema_migrations (migration_name, batch_number, execution_time_ms)
SELECT '08_create_audit_triggers.sql', 1, 0
WHERE NOT EXISTS (SELECT 1 FROM schema_migrations WHERE migration_name = '08_create_audit_triggers.sql');