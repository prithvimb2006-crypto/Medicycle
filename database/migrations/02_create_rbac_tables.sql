-- ==============================================================================
-- MEDICYCLE: Medicine Intelligence, Safety & Lifecycle Ecosystem
-- Migration 02: Multi-Tier Role-Based Access Control (RBAC) System
-- File: database/migrations/02_create_rbac_tables.sql
-- ==============================================================================
-- DDL TRANSACTIONAL LIMITATION NOTICE:
-- In MySQL, DDL statements cause implicit commits and are non-atomic.
-- If this script encounters an error, inspect database state before retrying.
--
-- VALIDATION FIRST ARCHITECTURE:
-- Existing users and their roles are validated at the VERY START of this script,
-- before any table is created or seeded. If any unmapped or NULL role exists,
-- execution aborts immediately via SIGNAL SQLSTATE '45000' without altering the schema.
--
-- ROUTINE SAFETY:
-- Temporary procedures use unique 'sp_medicycle_tmp_' namespaces and check
-- information_schema.ROUTINES for collisions prior to creation. No DROP PROCEDURE IF EXISTS
-- is ever executed against unknown pre-existing routines.
-- ==============================================================================

USE medicycle_db;

-- ------------------------------------------------------------------------------
-- STEP 1: PRE-VALIDATE EXISTING USERS (Before Creating Any Tables)
-- ------------------------------------------------------------------------------

-- Check for routine name collision
SET @p02_pre_collision = (
    SELECT COUNT(*) 
    FROM information_schema.ROUTINES 
    WHERE ROUTINE_SCHEMA = 'medicycle_db' 
      AND ROUTINE_NAME = 'sp_medicycle_tmp_validate_existing_users'
);

SET @abort_p02_pre = IF(@p02_pre_collision > 0, 
    'CALL `ABORT_ROUTINE_COLLISION_sp_medicycle_tmp_validate_existing_users_ALREADY_EXISTS`()', 
    'SELECT 1'
);
PREPARE stmt_p02_pre FROM @abort_p02_pre; 
EXECUTE stmt_p02_pre; 
DEALLOCATE PREPARE stmt_p02_pre;

DELIMITER $$
CREATE PROCEDURE sp_medicycle_tmp_validate_existing_users()
BEGIN
    DECLARE v_invalid_count INT DEFAULT 0;

    -- Verify that all existing users have roles that map to known standard roles
    SELECT COUNT(*) INTO v_invalid_count
    FROM users
    WHERE role IS NULL OR role NOT IN ('ADMIN', 'PHARMACIST', 'RESEARCHER', 'USER');

    IF v_invalid_count > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'ABORT: Unmapped or NULL role found in users table. Halting migration 02 before creating any RBAC tables.';
    END IF;
END$$
DELIMITER ;

CALL sp_medicycle_tmp_validate_existing_users();
DROP PROCEDURE sp_medicycle_tmp_validate_existing_users;

-- ------------------------------------------------------------------------------
-- STEP 2: CREATE RBAC TABLES
-- ------------------------------------------------------------------------------

-- 1. Create Roles Master Table
CREATE TABLE IF NOT EXISTS roles (
    role_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    role_name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Master enterprise security roles';

-- 2. Create Permissions Master Table
CREATE TABLE IF NOT EXISTS permissions (
    permission_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    permission_code VARCHAR(80) NOT NULL UNIQUE,
    module VARCHAR(50) NOT NULL,
    description TEXT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_perm_module (module)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Atomic functional access capabilities';

-- 3. Create Role-Permissions Junction Table
CREATE TABLE IF NOT EXISTS role_permissions (
    role_id INT UNSIGNED NOT NULL,
    permission_id INT UNSIGNED NOT NULL,
    granted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (role_id, permission_id),
    CONSTRAINT fk_rp_role FOREIGN KEY (role_id) REFERENCES roles(role_id) ON DELETE CASCADE,
    CONSTRAINT fk_rp_perm FOREIGN KEY (permission_id) REFERENCES permissions(permission_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Associates permissions with roles';

-- 4. Create User-Roles Junction Table
CREATE TABLE IF NOT EXISTS user_roles (
    user_id BIGINT UNSIGNED NOT NULL,
    role_id INT UNSIGNED NOT NULL,
    assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, role_id),
    CONSTRAINT fk_ur_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_ur_role FOREIGN KEY (role_id) REFERENCES roles(role_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Assigns enterprise roles to users';

-- ------------------------------------------------------------------------------
-- STEP 3: SEED ROLES & CAPABILITIES
-- ------------------------------------------------------------------------------

-- 5. Seed Default Core Roles (Preserving Existing ENUM Roles)
INSERT INTO roles (role_name, description)
VALUES 
    ('ADMIN', 'Full system administrative authority, security configuration, and audit access.'),
    ('PHARMACIST', 'Authorized clinical dispensing, inventory management, recall execution, and storage verification.'),
    ('RESEARCHER', 'Ecotoxicity analysis, environmental impact auditing, and pharmacopoeia data curation.'),
    ('USER', 'General authenticated consumer accessing medicine scan, verification, and safety guides.')
ON DUPLICATE KEY UPDATE description = VALUES(description);

-- 6. Seed Foundational Permissions
INSERT INTO permissions (permission_code, module, description)
VALUES 
    ('CATALOG_READ', 'CATALOG', 'View medicines, ingredients, uses, and manufacturers'),
    ('CATALOG_WRITE', 'CATALOG', 'Create or edit medicine formulations and compositions'),
    ('BATCH_MANAGE', 'INVENTORY', 'Register batches, update quantities, and adjust statuses'),
    ('COLD_CHAIN_LOG', 'TELEMETRY', 'Submit IoT sensor temperature and humidity telemetry'),
    ('RECALL_MANAGE', 'SAFETY', 'Publish, update, or terminate regulatory recall campaigns'),
    ('SCAN_EXECUTE', 'VISION', 'Execute barcode and OCR camera authenticity scans'),
    ('DISPOSAL_LOG', 'ENVIRONMENTAL', 'Record pharmaceutical destruction and waste manifests'),
    ('AUDIT_VIEW', 'COMPLIANCE', 'Inspect administrative audit trails and change logs')
ON DUPLICATE KEY UPDATE description = VALUES(description);

-- 7. Grant Permission Sets to Roles
INSERT IGNORE INTO role_permissions (role_id, permission_id)
SELECT r.role_id, p.permission_id
FROM roles r CROSS JOIN permissions p
WHERE r.role_name = 'ADMIN';

INSERT IGNORE INTO role_permissions (role_id, permission_id)
SELECT r.role_id, p.permission_id
FROM roles r
JOIN permissions p ON p.permission_code IN ('CATALOG_READ', 'CATALOG_WRITE', 'BATCH_MANAGE', 'COLD_CHAIN_LOG', 'RECALL_MANAGE', 'SCAN_EXECUTE', 'DISPOSAL_LOG')
WHERE r.role_name = 'PHARMACIST';

INSERT IGNORE INTO role_permissions (role_id, permission_id)
SELECT r.role_id, p.permission_id
FROM roles r
JOIN permissions p ON p.permission_code IN ('CATALOG_READ', 'CATALOG_WRITE', 'DISPOSAL_LOG', 'AUDIT_VIEW')
WHERE r.role_name = 'RESEARCHER';

INSERT IGNORE INTO role_permissions (role_id, permission_id)
SELECT r.role_id, p.permission_id
FROM roles r
JOIN permissions p ON p.permission_code IN ('CATALOG_READ', 'SCAN_EXECUTE')
WHERE r.role_name = 'USER';

-- ------------------------------------------------------------------------------
-- STEP 4: MAP EXISTING USERS & POST-VERIFY
-- ------------------------------------------------------------------------------

-- 8. Synchronize Existing Users to user_roles
INSERT INTO user_roles (user_id, role_id)
SELECT u.user_id, r.role_id
FROM users u
JOIN roles r ON u.role = r.role_name
ON DUPLICATE KEY UPDATE assigned_at = user_roles.assigned_at;

-- 9. Post-Assignment Validation: Ensure 100% of existing users have an assigned role
SET @p02_post_collision = (
    SELECT COUNT(*) 
    FROM information_schema.ROUTINES 
    WHERE ROUTINE_SCHEMA = 'medicycle_db' 
      AND ROUTINE_NAME = 'sp_medicycle_tmp_verify_all_users_assigned'
);

SET @abort_p02_post = IF(@p02_post_collision > 0, 
    'CALL `ABORT_ROUTINE_COLLISION_sp_medicycle_tmp_verify_all_users_assigned_ALREADY_EXISTS`()', 
    'SELECT 1'
);
PREPARE stmt_p02_post FROM @abort_p02_post; 
EXECUTE stmt_p02_post; 
DEALLOCATE PREPARE stmt_p02_post;

DELIMITER $$
CREATE PROCEDURE sp_medicycle_tmp_verify_all_users_assigned()
BEGIN
    DECLARE v_unassigned_count INT DEFAULT 0;

    SELECT COUNT(*) INTO v_unassigned_count
    FROM users u
    LEFT JOIN user_roles ur ON u.user_id = ur.user_id
    WHERE ur.role_id IS NULL;

    IF v_unassigned_count > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'ABORT: One or more users failed to receive a role assignment. Halting migration 02.';
    END IF;
END$$
DELIMITER ;

CALL sp_medicycle_tmp_verify_all_users_assigned();
DROP PROCEDURE sp_medicycle_tmp_verify_all_users_assigned;

-- 10. Register Migration strictly after all operations succeed
INSERT INTO schema_migrations (migration_name, batch_number, execution_time_ms)
SELECT '02_create_rbac_tables.sql', 1, 0
WHERE NOT EXISTS (SELECT 1 FROM schema_migrations WHERE migration_name = '02_create_rbac_tables.sql');

-- ==============================================================================
-- ROLLBACK GUIDANCE:
-- DROP TABLE IF EXISTS user_roles;
-- DROP TABLE IF EXISTS role_permissions;
-- DROP TABLE IF EXISTS permissions;
-- DROP TABLE IF EXISTS roles;
-- DELETE FROM schema_migrations WHERE migration_name = '02_create_rbac_tables.sql';
-- ==============================================================================
