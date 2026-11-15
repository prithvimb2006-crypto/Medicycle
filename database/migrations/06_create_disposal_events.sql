-- ==============================================================================
-- MEDICYCLE: Medicine Intelligence, Safety & Lifecycle Ecosystem
-- Migration 06: Medicine Disposal Event Logging & Destruction Manifests (Pure DDL)
-- File: database/migrations/06_create_disposal_events.sql
-- ==============================================================================
-- DDL TRANSACTIONAL LIMITATION NOTICE:
-- In MySQL, DDL statements cause implicit commits and are non-atomic. If this
-- script encounters an error, inspect the table state before retrying.
--
-- REGULATORY COMPLIANCE & VERIFICATION GOVERNANCE:
-- 1. Facility Flexibility: facility_name is nullable because a decommissioning event
--    can be logged in inventory before dispatch to a certified CBWTF facility.
-- 2. Non-Assumptive Defaults: applied_method and cpcb_waste_category default to 'UNKNOWN'.
-- 3. Strict Compliance Rule: A witness alone DOES NOT establish regulatory compliance.
--    To transition from 'PENDING_REGULATORY_VERIFICATION' to 'COMPLIANT_VERIFIED',
--    the record must provide documentary evidence (certificate_of_destruction_ref),
--    designated facility identity (facility_name), and an authorized witness (witnessed_by_user_id).
-- ==============================================================================

USE medicycle_db;

-- 1. Create Medicine Disposal Logs Table
CREATE TABLE IF NOT EXISTS medicine_disposal_logs (
    disposal_log_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    batch_id BIGINT UNSIGNED NOT NULL COMMENT 'Physical batch lot decommissioned',
    quantity_disposed INT UNSIGNED NOT NULL COMMENT 'Number of units or retail packs decommissioned',
    reason_for_disposal ENUM(
        'EXPIRED', 
        'COLD_CHAIN_EXCURSION', 
        'RECALLED', 
        'DAMAGED_PACKAGING', 
        'CONTAMINATED', 
        'PATIENT_RETURN'
    ) NOT NULL,
    applied_method ENUM(
        'INCINERATION_HIGH_TEMP', 
        'CBMWTF_YELLOW_CATEGORY_INCINERATION',
        'ENCAPSULATION_INERTIZATION', 
        'CHEMICAL_INACTIVATION', 
        'HAZARDOUS_FACILITY_TRANSFER', 
        'AUTHORIZED_TAKE_BACK_KIOSK',
        'UNKNOWN'
    ) NOT NULL DEFAULT 'UNKNOWN' COMMENT 'Destruction method complying with CPCB & EPA protocols',
    cpcb_waste_category ENUM(
        'YELLOW_CATEGORY_H_EXPIRED_DRUGS',
        'CYTOTOXIC_EXP_DRUGS',
        'GENERAL_SOLID_PHARMA',
        'CONTROLLED_SUBSTANCE_DESTRUCTION',
        'UNKNOWN'
    ) NOT NULL DEFAULT 'UNKNOWN' COMMENT 'Indian Bio-Medical Waste Rules Schedule I classification',
    verification_status ENUM(
        'PENDING_REGULATORY_VERIFICATION',
        'COMPLIANT_VERIFIED',
        'NON_COMPLIANT_FLAGGED'
    ) NOT NULL DEFAULT 'PENDING_REGULATORY_VERIFICATION' COMMENT 'Regulatory compliance state; requires documentary proof for COMPLIANT_VERIFIED',
    facility_name VARCHAR(150) NULL COMMENT 'Authorized CBWTF or TSDF facility name (nullable pending facility selection and dispatch)',
    certificate_of_destruction_ref VARCHAR(100) NULL UNIQUE COMMENT 'Regulatory tracking manifest / Certificate of Destruction code',
    cpcb_manifest_number VARCHAR(100) NULL COMMENT 'CPCB / SPCB Form-VI hazardous waste consignment tracking number',
    witnessed_by_user_id BIGINT UNSIGNED NULL COMMENT 'Licensed pharmacist or Pollution Control compliance officer witnessing disposal',
    disposal_date DATE NOT NULL COMMENT 'Date destruction occurred or initiated',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_disp_batch FOREIGN KEY (batch_id) REFERENCES medicine_batches(batch_id) ON DELETE RESTRICT,
    CONSTRAINT fk_disp_witness FOREIGN KEY (witnessed_by_user_id) REFERENCES users(user_id) ON DELETE RESTRICT,
    CONSTRAINT chk_qty_disposed CHECK (quantity_disposed > 0),
    CONSTRAINT chk_compliance_evidence CHECK (
        verification_status <> 'COMPLIANT_VERIFIED' 
        OR (witnessed_by_user_id IS NOT NULL AND facility_name IS NOT NULL AND certificate_of_destruction_ref IS NOT NULL)
    ),
    INDEX idx_disp_batch (batch_id),
    INDEX idx_disp_date (disposal_date),
    INDEX idx_disp_reason (reason_for_disposal),
    INDEX idx_disp_cpcb_cat (cpcb_waste_category),
    INDEX idx_disp_verification (verification_status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Auditable logs of physical pharmaceutical waste destruction under CPCB and EPA protocols';

-- 2. Register Migration strictly after DDL succeeds
INSERT INTO schema_migrations (migration_name, batch_number, execution_time_ms)
SELECT '06_create_disposal_events.sql', 1, 0
WHERE NOT EXISTS (SELECT 1 FROM schema_migrations WHERE migration_name = '06_create_disposal_events.sql');

-- ==============================================================================
-- ROLLBACK GUIDANCE:
-- DROP TABLE IF EXISTS medicine_disposal_logs;
-- DELETE FROM schema_migrations WHERE migration_name = '06_create_disposal_events.sql';
-- ==============================================================================
