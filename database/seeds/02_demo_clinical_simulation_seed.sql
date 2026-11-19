

USE medicycle_db;

-- 1. Simulated Cold-Chain Telemetry (Batch 8 - Lantus SoloStar Simulation)
INSERT INTO temperature_monitoring_logs 
    (batch_id, recorded_temperature_celsius, recorded_humidity_percent, sensor_device_id, storage_location, reading_timestamp, is_excursion, excursion_duration_minutes, action_taken, logged_by_user_id)
SELECT 
    8, 
    4.2, 
    45.0, 
    'SIM-IOT-COLD-01', 
    '[SIMULATION] Warehouse Cold Bay 2 - Shelf B', 
    NOW() - INTERVAL 2 HOUR, 
    FALSE, 
    0, 
    NULL, 
    2
WHERE EXISTS (SELECT 1 FROM medicine_batches WHERE batch_id = 8)
AND NOT EXISTS (SELECT 1 FROM temperature_monitoring_logs WHERE sensor_device_id = 'SIM-IOT-COLD-01' AND storage_location LIKE '[SIMULATION]%');

-- 2. Simulated OCR Extraction Artifact (Scan 1 - Crocin Advance Package Simulation)
INSERT INTO ocr_extraction_records 
    (scan_id, extracted_brand_name, extracted_generic_name, extracted_batch_number, extracted_mfg_date_raw, extracted_exp_date_raw, extracted_strength, extracted_dosage_form, ocr_engine, bounding_box_coordinates, raw_text_segments, overall_confidence, parsing_status)
SELECT 
    1, 
    '[SIMULATED] Crocin Advance', 
    'Paracetamol', 
    'CRO-2026-A101', 
    'SIM-MFG-01/26', 
    'SIM-EXP-01/28', 
    '500 mg', 
    'Fast Action Tablet', 
    'SIMULATED_VISION_ENGINE_V1',
    JSON_OBJECT('box_brand', JSON_ARRAY(120, 45, 340, 95), 'box_batch', JSON_ARRAY(150, 410, 280, 440)),
    JSON_ARRAY(
        JSON_OBJECT('token', 'Crocin', 'conf', 99.8),
        JSON_OBJECT('token', 'Advance', 'conf', 99.2),
        JSON_OBJECT('token', 'Paracetamol', 'conf', 98.9),
        JSON_OBJECT('token', '500mg', 'conf', 99.5)
    ),
    99.35,
    'PARSED_SUCCESSFULLY'
WHERE EXISTS (SELECT 1 FROM scan_records WHERE scan_id = 1)
AND NOT EXISTS (SELECT 1 FROM ocr_extraction_records WHERE extracted_brand_name LIKE '[SIMULATED]%');

-- 3. Simulated Environmental Impact Estimates (Unverified Research Estimates)
INSERT INTO environmental_impact_records 
    (medicine_id, ingredient_id, assessment_status, pbt_status, bioaccumulation_factor_bcf, half_life_water_days, half_life_soil_days, pnec_aquatic_ug_l, water_hazard_class_wgk, carbon_footprint_kg_co2e, packaging_recyclability_percent, antimicrobial_resistance_risk, cpcb_effluent_standard_compliant, impact_assessment_summary, reference_id)
SELECT 
    1, 
    1, 
    'UNVERIFIED_ESTIMATE', 
    'NOT_PBT', 
    3.16, 
    2.50, 
    4.00, 
    9.2000, 
    'CLASS_1_SLIGHT', 
    0.125, 
    85.00, 
    'LOW', 
    NULL, 
    '[SIMULATION] Synthetic benchmark data for paracetamol aquatic biodegradability modeling.', 
    NULL
WHERE EXISTS (SELECT 1 FROM medicines WHERE medicine_id = 1)
AND NOT EXISTS (SELECT 1 FROM environmental_impact_records WHERE impact_assessment_summary LIKE '[SIMULATION]%');

-- 4. Simulated Waste Decommissioning Record
INSERT INTO medicine_disposal_logs 
    (batch_id, quantity_disposed, reason_for_disposal, applied_method, cpcb_waste_category, verification_status, facility_name, certificate_of_destruction_ref, cpcb_manifest_number, witnessed_by_user_id, disposal_date)
SELECT 
    6, 
    800, 
    'EXPIRED', 
    'CBMWTF_YELLOW_CATEGORY_INCINERATION', 
    'YELLOW_CATEGORY_H_EXPIRED_DRUGS', 
    'PENDING_REGULATORY_VERIFICATION',
    '[SIMULATION] Demo EcoWaste CBWTF Staging Hub', 
    'SIM-CERT-DEST-2026-DEMO', 
    'SIM-CPCB-MANIFEST-2026-DEMO', 
    NULL, 
    '2026-04-10'
WHERE EXISTS (SELECT 1 FROM medicine_batches WHERE batch_id = 6)
AND NOT EXISTS (SELECT 1 FROM medicine_disposal_logs WHERE certificate_of_destruction_ref = 'SIM-CERT-DEST-2026-DEMO');
