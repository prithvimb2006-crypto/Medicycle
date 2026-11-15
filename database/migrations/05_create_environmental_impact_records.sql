USE medicycle_db;

-- 1. Create Environmental Impact Records Table
CREATE TABLE IF NOT EXISTS environmental_impact_records (
    impact_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    medicine_id BIGINT UNSIGNED NOT NULL COMMENT 'Commercial medicine product link',
    ingredient_id INT UNSIGNED NULL COMMENT 'Specific active pharmaceutical ingredient link if isolated',
    assessment_status ENUM('UNVERIFIED_ESTIMATE', 'LABORATORY_VERIFIED', 'REGULATORY_OFFICIAL') NOT NULL DEFAULT 'UNVERIFIED_ESTIMATE' COMMENT 'Audit validation tier of ecotoxicity metrics',
    pbt_status ENUM('PERSISTENT', 'BIOACCUMULATIVE', 'TOXIC', 'VERY_PERSISTENT_VERY_BIOACCUMULATIVE', 'NOT_PBT', 'UNKNOWN') NOT NULL DEFAULT 'UNKNOWN' COMMENT 'REACH Annex XIII PBT criteria',
    bioaccumulation_factor_bcf DECIMAL(8, 2) NULL COMMENT 'Bioconcentration factor in aquatic organisms (L/kg)',
    half_life_water_days DECIMAL(8, 2) NULL COMMENT 'Biodegradation half-life in surface waters (days)',
    half_life_soil_days DECIMAL(8, 2) NULL COMMENT 'Aerobic biodegradation persistence in soil (days)',
    pnec_aquatic_ug_l DECIMAL(10, 4) NULL COMMENT 'Predicted No-Effect Concentration in aquatic ecosystems (micrograms/liter)',
    water_hazard_class_wgk ENUM('NOT_HAZARDOUS', 'CLASS_1_SLIGHT', 'CLASS_2_OBVIOUS', 'CLASS_3_SEVERE', 'UNKNOWN') NOT NULL DEFAULT 'UNKNOWN' COMMENT 'German Water Hazard Class (WGK)',
    carbon_footprint_kg_co2e DECIMAL(8, 3) NULL COMMENT 'Estimated lifecycle greenhouse gas footprint per pack (kg CO2e)',
    packaging_recyclability_percent DECIMAL(5, 2) NULL COMMENT 'Percentage of packaging by weight recyclable',
    antimicrobial_resistance_risk ENUM('LOW', 'MEDIUM', 'HIGH', 'CRITICAL', 'UNKNOWN') NOT NULL DEFAULT 'UNKNOWN' COMMENT 'Risk of driving environmental AMR selection',
    cpcb_effluent_standard_compliant BOOLEAN NULL DEFAULT NULL COMMENT 'NULL = Unverified / Pending Audit, TRUE = Compliant, FALSE = Non-Compliant with GSR 543(E)',
    impact_assessment_summary TEXT NULL COMMENT 'Clinical and ecological assessment narrative',
    reference_id BIGINT UNSIGNED NULL COMMENT 'Peer-reviewed environmental scientific reference link',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_env_med FOREIGN KEY (medicine_id) REFERENCES medicines(medicine_id) ON DELETE RESTRICT,
    CONSTRAINT fk_env_ing FOREIGN KEY (ingredient_id) REFERENCES ingredients(ingredient_id) ON DELETE SET NULL,
    CONSTRAINT fk_env_ref FOREIGN KEY (reference_id) REFERENCES source_references(reference_id) ON DELETE RESTRICT,
    CONSTRAINT chk_bcf_nonneg CHECK (bioaccumulation_factor_bcf IS NULL OR bioaccumulation_factor_bcf >= 0),
    CONSTRAINT chk_half_life_water CHECK (half_life_water_days IS NULL OR half_life_water_days >= 0),
    CONSTRAINT chk_half_life_soil CHECK (half_life_soil_days IS NULL OR half_life_soil_days >= 0),
    CONSTRAINT chk_pnec_nonneg CHECK (pnec_aquatic_ug_l IS NULL OR pnec_aquatic_ug_l >= 0),
    CONSTRAINT chk_carbon_nonneg CHECK (carbon_footprint_kg_co2e IS NULL OR carbon_footprint_kg_co2e >= 0),
    CONSTRAINT chk_packaging_pct CHECK (packaging_recyclability_percent IS NULL OR (packaging_recyclability_percent >= 0.0 AND packaging_recyclability_percent <= 100.0)),
    CONSTRAINT chk_verified_needs_ref CHECK (assessment_status = 'UNVERIFIED_ESTIMATE' OR reference_id IS NOT NULL),
    INDEX idx_env_med (medicine_id),
    INDEX idx_env_ing (ingredient_id),
    INDEX idx_env_wgk (water_hazard_class_wgk),
    INDEX idx_env_amr (antimicrobial_resistance_risk),
    INDEX idx_env_status (assessment_status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Ecotoxicity, chemical persistence, and carbon footprint metrics';

-- 2. Register Migration strictly after DDL succeeds
INSERT INTO schema_migrations (migration_name, batch_number, execution_time_ms)
SELECT '05_create_environmental_impact_records.sql', 1, 0
WHERE NOT EXISTS (SELECT 1 FROM schema_migrations WHERE migration_name = '05_create_environmental_impact_records.sql');

-- ==============================================================================
-- ROLLBACK GUIDANCE:
-- DROP TABLE IF EXISTS environmental_impact_records;
-- DELETE FROM schema_migrations WHERE migration_name = '05_create_environmental_impact_records.sql';
-- ==============================================================================
