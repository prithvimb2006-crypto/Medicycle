-- ==============================================================================
-- MEDICYCLE: Medicine Intelligence, Safety & Lifecycle Ecosystem
-- Migration 04: OCR Vision Extraction Records & Parsing Artifacts (Pure DDL)
-- File: database/migrations/04_create_ocr_extractions.sql
-- ==============================================================================
-- DDL TRANSACTIONAL LIMITATION NOTICE:
-- In MySQL, DDL statements cause implicit commits and are non-atomic. If this
-- script encounters an error, inspect the table state before retrying.
--
-- PIPELINE STATUS DEFAULT:
-- parsing_status defaults to 'PENDING' when an OCR camera scan record is created,
-- transitioning to 'PARSED_SUCCESSFULLY', 'PARTIAL_EXTRACTION', or 'EXTRACTION_FAILED'
-- as computer vision and parser pipelines process the image.
-- ==============================================================================

USE medicycle_db;

-- 1. Create OCR Extraction Records Table
CREATE TABLE IF NOT EXISTS ocr_extraction_records (
    extraction_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    scan_id BIGINT UNSIGNED NOT NULL COMMENT 'Parent scan event link',
    extracted_brand_name VARCHAR(150) NULL,
    extracted_generic_name VARCHAR(150) NULL,
    extracted_batch_number VARCHAR(50) NULL,
    extracted_mfg_date_raw VARCHAR(40) NULL COMMENT 'Raw unparsed text string extracted from image',
    extracted_exp_date_raw VARCHAR(40) NULL COMMENT 'Raw unparsed expiry string extracted from image',
    extracted_strength VARCHAR(50) NULL,
    extracted_dosage_form VARCHAR(50) NULL,
    ocr_engine VARCHAR(50) NOT NULL DEFAULT 'TESSERACT_V5' COMMENT 'OCR Engine identifier',
    bounding_box_coordinates JSON NULL COMMENT 'Spatial bounding boxes for verified token zones',
    raw_text_segments JSON NULL COMMENT 'Array of token strings and confidence scores',
    overall_confidence DECIMAL(5, 2) NOT NULL COMMENT 'Composite confidence percentage (0.00 to 100.00)',
    parsing_status ENUM('PENDING', 'PARSED_SUCCESSFULLY', 'PARTIAL_EXTRACTION', 'EXTRACTION_FAILED') NOT NULL DEFAULT 'PENDING' COMMENT 'Asynchronous vision parser lifecycle status',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_ocr_scan FOREIGN KEY (scan_id)
    REFERENCES scan_records(scan_id) ON DELETE RESTRICT,
    CONSTRAINT chk_ocr_confidence CHECK (
        overall_confidence >= 0.00
        AND overall_confidence <= 100.00
    ),
    CONSTRAINT chk_ocr_engine_not_empty CHECK (
        CHAR_LENGTH(TRIM(ocr_engine)) > 0
    ),
    INDEX idx_ocr_scan (scan_id),
    INDEX idx_ocr_batch (extracted_batch_number),
    INDEX idx_ocr_status (parsing_status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Deep OCR extraction tokens, coordinates, and ML confidence data';

-- 2. Register Migration strictly after DDL succeeds
INSERT INTO schema_migrations (migration_name, batch_number, execution_time_ms)
SELECT '04_create_ocr_extractions.sql', 1, 0
WHERE NOT EXISTS (SELECT 1 FROM schema_migrations WHERE migration_name = '04_create_ocr_extractions.sql');

-- ==============================================================================
-- ROLLBACK GUIDANCE:
-- DROP TABLE IF EXISTS ocr_extraction_records;
-- DELETE FROM schema_migrations WHERE migration_name = '04_create_ocr_extractions.sql';
-- ==============================================================================
