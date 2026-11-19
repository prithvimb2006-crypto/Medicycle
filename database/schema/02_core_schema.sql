
USE medicycle_db;

SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS source_references;
CREATE TABLE source_references (
    reference_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    source_name VARCHAR(150) NOT NULL COMMENT 'e.g. FDA Orange Book, DailyMed, WHO, EPA',
    source_type ENUM('REGULATORY', 'ACADEMIC', 'PHARMACOPOEIA', 'MANUFACTURER', 'ENVIRONMENTAL') NOT NULL,
    url VARCHAR(500) NULL,
    publication_title VARCHAR(255) NULL,
    edition_or_version VARCHAR(50) NULL,
    retrieval_date DATE NOT NULL,
    verification_status ENUM('VERIFIED', 'PENDING_REVIEW', 'SUPERSEDED') NOT NULL DEFAULT 'VERIFIED',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


DROP TABLE IF EXISTS users;
CREATE TABLE users (
    user_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(120) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(100) NOT NULL,
    role ENUM('ADMIN', 'PHARMACIST', 'RESEARCHER', 'USER') NOT NULL DEFAULT 'USER',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    last_login_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS categories;
CREATE TABLE categories (
    category_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL UNIQUE COMMENT 'Therapeutic class name',
    atc_code_prefix VARCHAR(10) NULL COMMENT 'WHO ATC anatomical/therapeutic classification code',
    description TEXT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS manufacturers;
CREATE TABLE manufacturers (
    manufacturer_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(150) NOT NULL UNIQUE,
    country VARCHAR(80) NOT NULL,
    contact_email VARCHAR(120) NULL,
    license_number VARCHAR(80) NULL UNIQUE,
    website VARCHAR(255) NULL,
    is_fda_approved BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS ingredients;
CREATE TABLE ingredients (
    ingredient_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    generic_name VARCHAR(150) NOT NULL UNIQUE,
    chemical_formula VARCHAR(100) NULL,
    cas_number VARCHAR(30) NULL UNIQUE COMMENT 'Chemical Abstracts Service Registry Number',
    drug_class VARCHAR(100) NULL,
    description TEXT NULL,
    reference_id BIGINT UNSIGNED NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_ing_ref FOREIGN KEY (reference_id) REFERENCES source_references(reference_id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS medicines;
CREATE TABLE medicines (
    medicine_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    brand_name VARCHAR(150) NOT NULL,
    generic_name VARCHAR(150) NOT NULL,
    category_id INT UNSIGNED NOT NULL,
    manufacturer_id INT UNSIGNED NOT NULL,
    dosage_form ENUM('TABLET', 'CAPSULE', 'SYRUP', 'INJECTION', 'OINTMENT', 'DROPS', 'INHALER', 'PATCH') NOT NULL,
    strength VARCHAR(50) NOT NULL,
    administration_route VARCHAR(60) NOT NULL,
    prescription_classification ENUM('OTC', 'PRESCRIPTION_ONLY', 'CONTROLLED_SUBSTANCE') NOT NULL DEFAULT 'PRESCRIPTION_ONLY',
    barcode_upc VARCHAR(32) NULL UNIQUE,
    ndc_number VARCHAR(20) NULL UNIQUE COMMENT 'National Drug Code',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    reference_id BIGINT UNSIGNED NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_med_cat FOREIGN KEY (category_id) REFERENCES categories(category_id) ON DELETE RESTRICT,
    CONSTRAINT fk_med_mfr FOREIGN KEY (manufacturer_id) REFERENCES manufacturers(manufacturer_id) ON DELETE RESTRICT,
    CONSTRAINT fk_med_ref FOREIGN KEY (reference_id) REFERENCES source_references(reference_id) ON DELETE SET NULL,
    INDEX idx_med_brand (brand_name),
    INDEX idx_med_generic (generic_name),
    INDEX idx_med_barcode (barcode_upc)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS medicine_compositions;
CREATE TABLE medicine_compositions (
    composition_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    medicine_id BIGINT UNSIGNED NOT NULL,
    ingredient_id INT UNSIGNED NOT NULL,
    strength_value DECIMAL(10, 3) NOT NULL,
    strength_unit VARCHAR(20) NOT NULL COMMENT 'mg, mcg, g, mL, IU',
    is_active_ingredient BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT fk_comp_med FOREIGN KEY (medicine_id) REFERENCES medicines(medicine_id) ON DELETE CASCADE,
    CONSTRAINT fk_comp_ing FOREIGN KEY (ingredient_id) REFERENCES ingredients(ingredient_id) ON DELETE RESTRICT,
    CONSTRAINT uq_comp_med_ing UNIQUE (medicine_id, ingredient_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS medicine_uses;
CREATE TABLE medicine_uses (
    use_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    medicine_id BIGINT UNSIGNED NOT NULL,
    indication VARCHAR(255) NOT NULL,
    is_fda_approved BOOLEAN NOT NULL DEFAULT TRUE,
    target_condition VARCHAR(150) NULL,
    reference_id BIGINT UNSIGNED NULL,
    CONSTRAINT fk_use_med FOREIGN KEY (medicine_id) REFERENCES medicines(medicine_id) ON DELETE CASCADE,
    CONSTRAINT fk_use_ref FOREIGN KEY (reference_id) REFERENCES source_references(reference_id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS medicine_batches;
CREATE TABLE medicine_batches (
    batch_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    medicine_id BIGINT UNSIGNED NOT NULL,
    batch_number VARCHAR(50) NOT NULL,
    manufacturing_date DATE NOT NULL,
    expiry_date DATE NOT NULL,
    initial_quantity INT UNSIGNED NOT NULL DEFAULT 0,
    status ENUM('VALID', 'EXPIRING_SOON', 'EXPIRED', 'RECALLED', 'QUARANTINED') NOT NULL DEFAULT 'VALID',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_batch_med FOREIGN KEY (medicine_id) REFERENCES medicines(medicine_id) ON DELETE RESTRICT,
    CONSTRAINT uq_batch_med_num UNIQUE (medicine_id, batch_number),
    CONSTRAINT chk_exp_after_mfg CHECK (expiry_date > manufacturing_date),
    INDEX idx_batch_expiry (expiry_date),
    INDEX idx_batch_number (batch_number)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------------------------
-- 10. Storage Rules (Cold-Chain & Storage Precautions)
-- ------------------------------------------------------------------------------
DROP TABLE IF EXISTS storage_rules;
CREATE TABLE storage_rules (
    rule_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    medicine_id BIGINT UNSIGNED NOT NULL UNIQUE,
    min_temp_celsius DECIMAL(4, 1) NOT NULL,
    max_temp_celsius DECIMAL(4, 1) NOT NULL,
    requires_refrigeration BOOLEAN NOT NULL DEFAULT FALSE,
    light_sensitive BOOLEAN NOT NULL DEFAULT FALSE,
    moisture_sensitive BOOLEAN NOT NULL DEFAULT FALSE,
    storage_instructions TEXT NOT NULL,
    excursion_limit_hours INT UNSIGNED NULL COMMENT 'Permissible hours outside optimal range',
    CONSTRAINT fk_store_med FOREIGN KEY (medicine_id) REFERENCES medicines(medicine_id) ON DELETE CASCADE,
    CONSTRAINT chk_temp_range CHECK (min_temp_celsius <= max_temp_celsius)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------------------------
-- 11. Drug Interactions (Active Ingredient Pair Screening)
-- ------------------------------------------------------------------------------
DROP TABLE IF EXISTS drug_interactions;
CREATE TABLE drug_interactions (
    interaction_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    ingredient1_id INT UNSIGNED NOT NULL,
    ingredient2_id INT UNSIGNED NOT NULL,
    severity ENUM('MILD', 'MODERATE', 'SEVERE', 'CONTRAINDICATED') NOT NULL,
    mechanism TEXT NULL,
    clinical_effect TEXT NOT NULL,
    management_advice TEXT NOT NULL,
    reference_id BIGINT UNSIGNED NULL,
    CONSTRAINT fk_inter_ing1 FOREIGN KEY (ingredient1_id) REFERENCES ingredients(ingredient_id) ON DELETE RESTRICT,
    CONSTRAINT fk_inter_ing2 FOREIGN KEY (ingredient2_id) REFERENCES ingredients(ingredient_id) ON DELETE RESTRICT,
    CONSTRAINT fk_inter_ref FOREIGN KEY (reference_id) REFERENCES source_references(reference_id) ON DELETE SET NULL,
    CONSTRAINT chk_diff_ing CHECK (ingredient1_id <> ingredient2_id),
    CONSTRAINT uq_inter_pair UNIQUE (ingredient1_id, ingredient2_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------------------------
-- 12. Side Effects (Documented Adverse Reactions)
-- ------------------------------------------------------------------------------
DROP TABLE IF EXISTS side_effects;
CREATE TABLE side_effects (
    side_effect_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    medicine_id BIGINT UNSIGNED NOT NULL,
    adverse_reaction VARCHAR(200) NOT NULL,
    frequency ENUM('VERY_COMMON', 'COMMON', 'UNCOMMON', 'RARE', 'VERY_RARE') NOT NULL DEFAULT 'COMMON',
    severity ENUM('MILD', 'MODERATE', 'SEVERE', 'LIFE_THREATENING') NOT NULL DEFAULT 'MILD',
    requires_medical_attention BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT fk_se_med FOREIGN KEY (medicine_id) REFERENCES medicines(medicine_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------------------------
-- 13. Contraindications (Prohibited Conditions)
-- ------------------------------------------------------------------------------
DROP TABLE IF EXISTS contraindications;
CREATE TABLE contraindications (
    contraindication_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    medicine_id BIGINT UNSIGNED NOT NULL,
    condition_name VARCHAR(200) NOT NULL,
    type ENUM('ABSOLUTE', 'RELATIVE') NOT NULL DEFAULT 'ABSOLUTE',
    clinical_rationale TEXT NOT NULL,
    CONSTRAINT fk_ci_med FOREIGN KEY (medicine_id) REFERENCES medicines(medicine_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------------------------
-- 14. Disposal Guidelines (Eco-Disposal Intelligence)
-- ------------------------------------------------------------------------------
DROP TABLE IF EXISTS disposal_guidelines;
CREATE TABLE disposal_guidelines (
    guideline_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    medicine_id BIGINT UNSIGNED NOT NULL UNIQUE,
    disposal_method ENUM('FLUSH_LIST', 'HOUSEHOLD_TRASH_MIXED', 'TAKE_BACK_ONLY', 'HAZARDOUS_WASTE_FACILITY') NOT NULL,
    environmental_hazard_rating ENUM('LOW', 'MODERATE', 'HIGH', 'CRITICAL') NOT NULL,
    aquatic_toxicity_risk BOOLEAN NOT NULL DEFAULT FALSE,
    mixing_instructions TEXT NULL COMMENT 'Instructions for household disposal (e.g., seal with coffee grounds)',
    take_back_instructions TEXT NULL,
    regulatory_reference VARCHAR(255) NULL,
    reference_id BIGINT UNSIGNED NULL,
    CONSTRAINT fk_disp_med FOREIGN KEY (medicine_id) REFERENCES medicines(medicine_id) ON DELETE CASCADE,
    CONSTRAINT fk_disp_ref FOREIGN KEY (reference_id) REFERENCES source_references(reference_id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------------------------
-- 15. Recall Records (Pharmaceutical Safety Recalls)
-- ------------------------------------------------------------------------------
DROP TABLE IF EXISTS recall_records;
CREATE TABLE recall_records (
    recall_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    recall_reference_code VARCHAR(50) NOT NULL UNIQUE,
    issuing_authority VARCHAR(100) NOT NULL COMMENT 'e.g. US FDA, MHRA, EMA',
    recall_class ENUM('CLASS_I', 'CLASS_II', 'CLASS_III') NOT NULL COMMENT 'Class I: Serious injury/death risk',
    recall_reason TEXT NOT NULL,
    status ENUM('ACTIVE', 'COMPLETED', 'TERMINATED') NOT NULL DEFAULT 'ACTIVE',
    announcement_date DATE NOT NULL,
    action_required TEXT NOT NULL,
    reference_id BIGINT UNSIGNED NULL,
    CONSTRAINT fk_rec_ref FOREIGN KEY (reference_id) REFERENCES source_references(reference_id) ON DELETE SET NULL,
    INDEX idx_rec_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------------------------
-- 16. Recall-Medicine Relationships (Corrected with Surrogate Primary Key)
-- ------------------------------------------------------------------------------
-- NOTE: Corrected known issue from starter zip where nullable batch_id was in composite PK.
-- Surrogate PK 'recall_medicine_id' allows valid nullable batch relationships.
DROP TABLE IF EXISTS recall_medicines;
CREATE TABLE recall_medicines (
    recall_medicine_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    recall_id BIGINT UNSIGNED NOT NULL,
    medicine_id BIGINT UNSIGNED NOT NULL,
    batch_id BIGINT UNSIGNED NULL COMMENT 'Nullable: recall can target entire medicine line or specific batch',
    affected_lot_description VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_rm_recall FOREIGN KEY (recall_id) REFERENCES recall_records(recall_id) ON DELETE CASCADE,
    CONSTRAINT fk_rm_medicine FOREIGN KEY (medicine_id) REFERENCES medicines(medicine_id) ON DELETE RESTRICT,
    CONSTRAINT fk_rm_batch FOREIGN KEY (batch_id) REFERENCES medicine_batches(batch_id) ON DELETE SET NULL,
    CONSTRAINT uq_recall_med_batch UNIQUE (recall_id, medicine_id, batch_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------------------------
-- 17. Safety Alerts (Black Box & Clinical Warnings)
-- ------------------------------------------------------------------------------
DROP TABLE IF EXISTS safety_alerts;
CREATE TABLE safety_alerts (
    alert_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    medicine_id BIGINT UNSIGNED NOT NULL,
    alert_title VARCHAR(200) NOT NULL,
    alert_level ENUM('BLACK_BOX_WARNING', 'WARNING', 'PRECAUTION', 'SAFETY_ADVISORY') NOT NULL,
    description TEXT NOT NULL,
    effective_date DATE NOT NULL,
    reference_id BIGINT UNSIGNED NULL,
    CONSTRAINT fk_alert_med FOREIGN KEY (medicine_id) REFERENCES medicines(medicine_id) ON DELETE CASCADE,
    CONSTRAINT fk_alert_ref FOREIGN KEY (reference_id) REFERENCES source_references(reference_id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------------------------
-- 18. Scan Records (Authenticity Screening & OCR History)
-- ------------------------------------------------------------------------------
DROP TABLE IF EXISTS scan_records;
CREATE TABLE scan_records (
    scan_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT UNSIGNED NULL,
    scan_type ENUM('BARCODE_UPC', 'QR_CODE', 'OCR_IMAGE', 'MANUAL_TEXT') NOT NULL,
    raw_scanned_data TEXT NOT NULL,
    matched_medicine_id BIGINT UNSIGNED NULL,
    matched_batch_id BIGINT UNSIGNED NULL,
    ocr_confidence_score DECIMAL(5, 2) NULL COMMENT 'Confidence percentage 0.00 to 100.00',
    verification_status ENUM('MATCH_CONFIRMED', 'AMBIGUOUS_MATCH', 'NO_MATCH_FOUND', 'FLAGGED_INCONSISTENCY') NOT NULL,
    scan_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_scan_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE SET NULL,
    CONSTRAINT fk_scan_med FOREIGN KEY (matched_medicine_id) REFERENCES medicines(medicine_id) ON DELETE SET NULL,
    CONSTRAINT fk_scan_batch FOREIGN KEY (matched_batch_id) REFERENCES medicine_batches(batch_id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------------------------
-- 19. Audit Logs (Tamper-Evident Administrative & DBSA Logging)
-- ------------------------------------------------------------------------------
DROP TABLE IF EXISTS audit_logs;
CREATE TABLE audit_logs (
    log_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    table_name VARCHAR(64) NOT NULL,
    record_id BIGINT UNSIGNED NOT NULL,
    action_type ENUM('INSERT', 'UPDATE', 'DELETE') NOT NULL,
    changed_by_user_id BIGINT UNSIGNED NULL,
    old_values JSON NULL,
    new_values JSON NULL,
    ip_address VARCHAR(45) NULL,
    logged_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_audit_user FOREIGN KEY (changed_by_user_id) REFERENCES users(user_id) ON DELETE SET NULL,
    INDEX idx_audit_table_record (table_name, record_id),
    INDEX idx_audit_timestamp (logged_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Re-enable foreign key checks
SET FOREIGN_KEY_CHECKS = 1;
