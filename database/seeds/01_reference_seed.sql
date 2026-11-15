-- ==============================================================================
-- MEDICYCLE: Medicine Intelligence, Safety & Lifecycle Ecosystem
-- Reference Seed Data Script (Phase 1 Database Verification)
-- File: database/seeds/01_reference_seed.sql
-- ==============================================================================

USE medicycle_db;

SET FOREIGN_KEY_CHECKS = 0;

-- 1. Source References
TRUNCATE TABLE source_references;
INSERT INTO source_references 
    (reference_id, source_name, source_type, url, publication_title, edition_or_version, retrieval_date, verification_status)
VALUES
    (1, 'FDA Orange Book', 'REGULATORY', 'https://www.accessdata.fda.gov/scripts/cder/ob/', 'Approved Drug Products with Therapeutic Equivalence Evaluations', '44th Edition', '2026-01-15', 'VERIFIED'),
    (2, 'DailyMed - National Library of Medicine', 'REGULATORY', 'https://dailymed.nlm.nih.gov/', 'National Drug Label Repository', '2026 Rel 1', '2026-02-10', 'VERIFIED'),
    (3, 'WHO Model List of Essential Medicines', 'ACADEMIC', 'https://www.who.int/medicines/publications/essentialmedicines/', 'WHO Essential Medicines List 23rd Edition', '2025/2026', '2026-03-01', 'VERIFIED'),
    (4, 'EPA Pharmaceutical Disposal Guidelines', 'ENVIRONMENTAL', 'https://www.epa.gov/hwgenerators/management-standards-hazardous-waste-pharmaceuticals', 'Management Standards for Hazardous Waste Pharmaceuticals', 'RCRA Subpart P', '2026-01-20', 'VERIFIED'),
    (5, 'British National Formulary (BNF)', 'PHARMACOPOEIA', 'https://bnf.nice.org.uk/', 'BNF 87 Pharmaceutical Press', 'Issue 87', '2026-02-18', 'VERIFIED');

-- 2. Users (Role-Based Access Control)
TRUNCATE TABLE users;
INSERT INTO users 
    (user_id, username, email, password_hash, full_name, role, is_active)
VALUES
    (1, 'admin', 'admin@medicycle.org', '$2b$12$e9wT0mZ7bW9w2Q6z4q9IEOZzG8U9C7yH2z.o01.examplehashadmin', 'System Administrator', 'ADMIN', TRUE),
    (2, 'dr_sharma', 'asharma@medicycle.org', '$2b$12$e9wT0mZ7bW9w2Q6z4q9IEOZzG8U9C7yH2z.o02.examplehashpharm', 'Dr. Alok Sharma, PharmD', 'PHARMACIST', TRUE),
    (3, 'env_researcher', 'sustainability@medicycle.org', '$2b$12$e9wT0mZ7bW9w2Q6z4q9IEOZzG8U9C7yH2z.o03.examplehashres', 'Elena Rostova, MSc Environmental Science', 'RESEARCHER', TRUE),
    (4, 'student_demo', 'student@medicycle.org', '$2b$12$e9wT0mZ7bW9w2Q6z4q9IEOZzG8U9C7yH2z.o04.examplehashdemo', 'Prithvi Halder', 'USER', TRUE);

-- 3. Categories
TRUNCATE TABLE categories;
INSERT INTO categories 
    (category_id, category_name, atc_code_prefix, description)
VALUES
    (1, 'Analgesics & Antipyretics', 'N02BE', 'Pain relievers and fever reducers acting peripherally and centrally.'),
    (2, 'Beta-Lactam Antibacterials', 'J01CA', 'Broad-spectrum bactericidal antibiotics inhibiting bacterial cell wall synthesis.'),
    (3, 'Oral Blood Glucose Lowering Drugs (Biguanides)', 'A10BA', 'First-line medications for the treatment of type 2 diabetes mellitus.'),
    (4, 'Lipid Modifying Agents (Statins)', 'C10AA', 'HMG-CoA reductase inhibitors reducing LDL-C and cardiovascular morbidity.'),
    (5, 'Non-Steroidal Anti-Inflammatory Drugs (NSAIDs)', 'M01AE', 'Anti-inflammatory and analgesic compounds acting through COX inhibition.'),
    (6, 'Oral Anticoagulants (Vitamin K Antagonists)', 'B01AA', 'Agents preventing thrombosis through inhibition of vitamin K epoxide reductase.'),
    (7, 'Insulins and Analogues (Long-Acting)', 'A10AE', 'Recombinant long-acting basal insulins providing 24-hour glycemic control.');

-- 4. Manufacturers
TRUNCATE TABLE manufacturers;
INSERT INTO manufacturers 
    (manufacturer_id, name, country, contact_email, license_number, website, is_fda_approved)
VALUES
    (1, 'GlaxoSmithKline Pharmaceuticals', 'United Kingdom', 'medinfo@gsk.com', 'MFR-UK-001048', 'https://www.gsk.com', TRUE),
    (2, 'Pfizer Inc.', 'United States', 'medicalaffairs@pfizer.com', 'MFR-USA-009214', 'https://www.pfizer.com', TRUE),
    (3, 'Sun Pharmaceutical Industries Ltd.', 'India', 'compliance@sunpharma.com', 'MFR-IND-082419', 'https://www.sunpharma.com', TRUE),
    (4, 'Sanofi-Aventis S.A.', 'France', 'contact@sanofi.com', 'MFR-FRA-004128', 'https://www.sanofi.com', TRUE),
    (5, 'Novartis International AG', 'Switzerland', 'corporate@novartis.com', 'MFR-CHE-003391', 'https://www.novartis.com', TRUE);

-- 5. Ingredients (Active Pharmaceutical Ingredients)
TRUNCATE TABLE ingredients;
INSERT INTO ingredients 
    (ingredient_id, generic_name, chemical_formula, cas_number, drug_class, description, reference_id)
VALUES
    (1, 'Paracetamol', 'C8H9NO2', '103-90-2', 'Anilide Analgesic', 'Inhibits central prostaglandin synthesis; mild COX-1/COX-2 inhibitor.', 1),
    (2, 'Amoxicillin', 'C16H19N3O5S', '26787-78-0', 'Aminopenicillin', 'Bactericidal antibiotic inhibiting transpeptidase in bacterial wall formation.', 1),
    (3, 'Clavulanic Acid', 'C8H9NO5', '58001-44-8', 'Beta-Lactamase Inhibitor', 'Irreversible suicide inhibitor of bacterial beta-lactamase enzymes.', 1),
    (4, 'Metformin Hydrochloride', 'C4H11N5.HCl', '1115-70-4', 'Biguanide', 'Activates AMP-activated protein kinase (AMPK), lowering hepatic glucose production.', 1),
    (5, 'Atorvastatin Calcium', 'C66H68CaF2N4O10', '134523-03-8', 'HMG-CoA Reductase Inhibitor', 'Selectively and competitively inhibits 3-hydroxy-3-methylglutaryl-coenzyme A reductase.', 2),
    (6, 'Ibuprofen', 'C13H18O2', '15687-27-1', 'Propionic Acid NSAID', 'Non-selective reversible inhibition of cyclooxygenase enzymes (COX-1 & COX-2).', 1),
    (7, 'Warfarin Sodium', 'C19H15NaO4', '129-06-6', 'Coumarin Derivative', 'Inhibits Vitamin K epoxide reductase complex 1 (VKORC1), depleting factors II, VII, IX, X.', 2),
    (8, 'Insulin Glargine', 'C210H322N56O66S6', '160337-95-1', 'Human Insulin Analogue', 'Recombinant DNA analogue with microprecipitate formation providing flat 24-hr profile.', 2);

-- 6. Medicines (Digital Passport Anchor)
TRUNCATE TABLE medicines;
INSERT INTO medicines 
    (medicine_id, brand_name, generic_name, category_id, manufacturer_id, dosage_form, strength, administration_route, prescription_classification, barcode_upc, ndc_number, is_active, reference_id)
VALUES
    (1, 'Crocin Advance', 'Paracetamol', 1, 1, 'TABLET', '500 mg', 'Oral', 'OTC', '8901030588204', '0173-0820-01', TRUE, 1),
    (2, 'Augmentin 625 Duo', 'Amoxicillin and Potassium Clavulanate', 2, 1, 'TABLET', '625 mg', 'Oral', 'PRESCRIPTION_ONLY', '8901030612442', '0029-6086-12', TRUE, 1),
    (3, 'Glucophage 500', 'Metformin Hydrochloride', 3, 4, 'TABLET', '500 mg', 'Oral', 'PRESCRIPTION_ONLY', '3583310014023', '0087-6060-05', TRUE, 1),
    (4, 'Lipitor 20', 'Atorvastatin Calcium', 4, 2, 'TABLET', '20 mg', 'Oral', 'PRESCRIPTION_ONLY', '0071015623108', '0071-0156-23', TRUE, 2),
    (5, 'Advil Liqui-Gels', 'Ibuprofen', 5, 2, 'CAPSULE', '200 mg', 'Oral', 'OTC', '3057301642051', '0573-0164-20', TRUE, 1),
    (6, 'Coumadin 5mg', 'Warfarin Sodium', 6, 3, 'TABLET', '5 mg', 'Oral', 'PRESCRIPTION_ONLY', '0056017275019', '0056-0172-75', TRUE, 2),
    (7, 'Lantus SoloStar', 'Insulin Glargine', 7, 4, 'INJECTION', '100 units/mL (3 mL)', 'Subcutaneous', 'PRESCRIPTION_ONLY', '3008822190014', '0088-2219-00', TRUE, 2);

-- 7. Medicine Compositions
TRUNCATE TABLE medicine_compositions;
INSERT INTO medicine_compositions 
    (composition_id, medicine_id, ingredient_id, strength_value, strength_unit, is_active_ingredient)
VALUES
    (1, 1, 1, 500.000, 'mg', TRUE),
    (2, 2, 2, 500.000, 'mg', TRUE),
    (3, 2, 3, 125.000, 'mg', TRUE),
    (4, 3, 4, 500.000, 'mg', TRUE),
    (5, 4, 5, 20.000, 'mg', TRUE),
    (6, 5, 6, 200.000, 'mg', TRUE),
    (7, 6, 7, 5.000, 'mg', TRUE),
    (8, 7, 8, 300.000, 'IU', TRUE);

-- 8. Medicine Uses
TRUNCATE TABLE medicine_uses;
INSERT INTO medicine_uses 
    (use_id, medicine_id, indication, is_fda_approved, target_condition, reference_id)
VALUES
    (1, 1, 'Temporary relief of headache, toothache, muscle aches, and reduce fever', TRUE, 'Pyrexia and Mild Pain', 1),
    (2, 2, 'Treatment of lower respiratory tract infections, otitis media, sinusitis, skin infections', TRUE, 'Bacterial Infections', 1),
    (3, 3, 'Adjunct to diet and exercise to improve glycemic control in adults and children with T2DM', TRUE, 'Type 2 Diabetes Mellitus', 1),
    (4, 4, 'Prevention of cardiovascular events and hypercholesterolemia reduction', TRUE, 'Atherosclerotic Cardiovascular Disease', 2),
    (5, 5, 'Relief of pain, inflammation, and stiffness caused by osteoarthritis and dysmenorrhea', TRUE, 'Inflammatory Conditions', 1),
    (6, 6, 'Prophylaxis and treatment of venous thrombosis, pulmonary embolism, and atrial fibrillation thromboembolism', TRUE, 'Thromboembolism', 2),
    (7, 7, 'Improvement of glycemic control in adults and pediatric patients with type 1 and type 2 diabetes', TRUE, 'Diabetes Mellitus', 2);

-- 9. Medicine Batches (Shelf-Life and Expiry Intelligence)
TRUNCATE TABLE medicine_batches;
INSERT INTO medicine_batches 
    (batch_id, medicine_id, batch_number, manufacturing_date, expiry_date, initial_quantity, status)
VALUES
    -- Valid Batches
    (1, 1, 'CRO-2026-A101', '2026-01-10', '2028-01-09', 5000, 'VALID'),
    (2, 2, 'AUG-2025-X042', '2025-06-15', '2027-06-14', 2500, 'VALID'),
    (3, 3, 'GLU-2026-B812', '2026-02-01', '2029-01-31', 4000, 'VALID'),
    (4, 4, 'LIP-2025-K900', '2025-08-20', '2028-08-19', 3000, 'VALID'),
    -- Expiring Soon Batch (approx. within next 60 days)
    (5, 5, 'ADV-2024-C303', '2024-12-01', '2026-12-15', 1200, 'EXPIRING_SOON'),
    -- Expired Batch (already passed expiry)
    (6, 1, 'CRO-2024-E099', '2024-04-01', '2026-04-01', 800, 'EXPIRED'),
    -- Recalled Batch
    (7, 2, 'AUG-2025-RC01', '2025-09-01', '2027-08-31', 1500, 'RECALLED'),
    -- Cold Chain Batch
    (8, 7, 'LAN-2026-F550', '2026-03-01', '2028-02-28', 1000, 'VALID');

-- 10. Storage Rules (Cold Chain Intelligence)
TRUNCATE TABLE storage_rules;
INSERT INTO storage_rules 
    (rule_id, medicine_id, min_temp_celsius, max_temp_celsius, requires_refrigeration, light_sensitive, moisture_sensitive, storage_instructions, excursion_limit_hours)
VALUES
    (1, 1, 15.0, 25.0, FALSE, FALSE, TRUE, 'Store below 25°C in a dry place. Protect from moisture and excessive heat.', 720),
    (2, 2, 15.0, 25.0, FALSE, TRUE, TRUE, 'Store in original desiccated foil packaging. Highly sensitive to moisture.', 168),
    (3, 3, 20.0, 25.0, FALSE, FALSE, TRUE, 'Controlled room temperature between 20°C to 25°C. Excursions permitted between 15°C and 30°C.', 360),
    (4, 4, 20.0, 25.0, FALSE, FALSE, FALSE, 'Store at 20°C to 25°C in tight container away from direct sunlight.', 360),
    (5, 5, 15.0, 25.0, FALSE, TRUE, TRUE, 'Avoid excessive heat above 40°C. Protect from light and freezing.', 168),
    (6, 6, 15.0, 30.0, FALSE, TRUE, FALSE, 'Store at controlled room temperature 15°C to 30°C. Protect from light.', 720),
    (7, 7, 2.0, 8.0, TRUE, TRUE, FALSE, 'Cold chain required. Store unopened pens in refrigerator (2°C to 8°C). Do not freeze. Once in use, store below 30°C for up to 28 days.', 48);

-- 11. Drug Interactions (Active Ingredient Pair Screening)
TRUNCATE TABLE drug_interactions;
INSERT INTO drug_interactions 
    (interaction_id, ingredient1_id, ingredient2_id, severity, mechanism, clinical_effect, management_advice, reference_id)
VALUES
    (1, 7, 6, 'SEVERE', 'Pharmacodynamic synergism: Ibuprofen inhibits platelet aggregation and causes gastric mucosal injury while Warfarin depletes clotting factors.', 'Major gastrointestinal hemorrhage, elevated INR, and life-threatening bleeding risk.', 'Avoid concurrent use. Use Paracetamol for pain/fever if an analgesic is clinically necessary, while monitoring INR.', 2),
    (2, 4, 1, 'MILD', 'Metformin and Paracetamol share minor hepatic metabolic pathways.', 'Clinically insignificant at therapeutic doses; monitor renal/hepatic markers in organ failure.', 'No dosage adjustment routinely required under standard clinical doses.', 1),
    (3, 5, 2, 'MODERATE', 'Macrolide/inhibitor interactions alter hepatic CYP3A4 metabolism of Atorvastatin.', 'Elevated serum concentration of statin, increasing incidence of myalgia and rhabdomyolysis.', 'Temporarily withhold Atorvastatin or substitute with alternative antibiotic if potent inhibitor co-prescribed.', 2);

-- 12. Side Effects
TRUNCATE TABLE side_effects;
INSERT INTO side_effects 
    (side_effect_id, medicine_id, adverse_reaction, frequency, severity, requires_medical_attention)
VALUES
    (1, 1, 'Hepatotoxicity with supratherapeutic dose', 'RARE', 'LIFE_THREATENING', TRUE),
    (2, 1, 'Allergic skin rash / urticaria', 'UNCOMMON', 'MILD', FALSE),
    (3, 2, 'Diarrhea / gastrointestinal upset', 'COMMON', 'MILD', FALSE),
    (4, 2, 'Hypersensitivity anaphylaxis', 'RARE', 'LIFE_THREATENING', TRUE),
    (5, 3, 'Lactic Acidosis', 'VERY_RARE', 'LIFE_THREATENING', TRUE),
    (6, 3, 'Abdominal distension, nausea, flatulence', 'VERY_COMMON', 'MILD', FALSE),
    (7, 4, 'Myopathy / unexplained muscle soreness', 'UNCOMMON', 'MODERATE', TRUE),
    (8, 5, 'Gastric ulceration / epigastric burning', 'COMMON', 'MODERATE', TRUE),
    (9, 6, 'Major hemorrhage / hematuria / epistaxis', 'COMMON', 'SEVERE', TRUE),
    (10, 7, 'Hypoglycemia (blood glucose < 70 mg/dL)', 'VERY_COMMON', 'MODERATE', TRUE);

-- 13. Contraindications
TRUNCATE TABLE contraindications;
INSERT INTO contraindications 
    (contraindication_id, medicine_id, condition_name, type, clinical_rationale)
VALUES
    (1, 1, 'Severe Active Hepatic Impairment / Cirrhosis', 'ABSOLUTE', 'Toxic accumulation of N-acetyl-p-benzoquinone imine (NAPQI) due to depleted glutathione reserves.'),
    (2, 2, 'Immediate Hypersensitivity to Penicillins or Cephalosporins', 'ABSOLUTE', 'Cross-reacting IgE-mediated anaphylactic shock risk.'),
    (3, 3, 'Severe Renal Impairment (eGFR < 30 mL/min/1.73m2)', 'ABSOLUTE', 'Substantial risk of drug accumulation and development of fatal metformin-associated lactic acidosis (MALA).'),
    (4, 5, 'Active Peptic Ulcer Disease or GI Bleeding', 'ABSOLUTE', 'Inhibition of cytoprotective gastric prostaglandins exacerbates ulceration and precipitous perforation.'),
    (5, 6, 'Pregnancy (First and Third Trimester)', 'ABSOLUTE', 'Crosses placental barrier causing warfarin embryopathy (chondrodysplasia punctata) and fetal hemorrhage.');

-- 14. Disposal Guidelines (Eco-Disposal Intelligence)
TRUNCATE TABLE disposal_guidelines;
INSERT INTO disposal_guidelines 
    (guideline_id, medicine_id, disposal_method, environmental_hazard_rating, aquatic_toxicity_risk, mixing_instructions, take_back_instructions, regulatory_reference, reference_id)
VALUES
    (1, 1, 'HOUSEHOLD_TRASH_MIXED', 'LOW', FALSE, 'Mix uncrushed tablets with undesirable substance (used coffee grounds or cat litter). Seal in airtight bag before placing in general household waste.', 'Drop off at authorized pharmacy collection kiosk when available.', 'FDA Disposal Guidelines for Non-Flush Medicines', 4),
    (2, 2, 'TAKE_BACK_ONLY', 'HIGH', TRUE, 'Do NOT flush or dispose in household trash. Beta-lactams promote antimicrobial resistance (AMR) in sewage and aquatic ecosystems.', 'Return unused course to community pharmacy take-back bin or national take-back event.', 'EPA Management Standards 40 CFR Part 266', 4),
    (3, 3, 'HOUSEHOLD_TRASH_MIXED', 'LOW', FALSE, 'Mix tablets with coffee grounds in sealed bag. Do not flush.', 'Pharmacy take-back box preferred.', 'FDA Non-Flush Drug Disposal Guidelines', 4),
    (4, 4, 'HOUSEHOLD_TRASH_MIXED', 'MODERATE', TRUE, 'Place in solid waste mixed with dirt or coffee grounds. Never pour into storm drains or sink.', 'Authorized medicine drop-off location.', 'EPA RCRA Waste Minimization', 4),
    (5, 5, 'HOUSEHOLD_TRASH_MIXED', 'MODERATE', TRUE, 'Keep capsules in sealed pouch mixed with unpalatable matter. Toxic to aquatic invertebrates in high concentrations.', 'Pharmacy take-back preferred.', 'WHO Safe Disposal of Pharmaceuticals', 3),
    (6, 6, 'TAKE_BACK_ONLY', 'CRITICAL', TRUE, 'Do NOT place in residential trash or septic systems. Warfarin is an EPA RCRA P-listed acute hazardous waste (P001) with severe toxicity.', 'Mandatory hazardous waste drop-off or authorized DEA registered collector take-back box.', 'EPA RCRA 40 CFR 261.33 P-Listed Hazardous Waste', 4),
    (7, 7, 'HAZARDOUS_WASTE_FACILITY', 'HIGH', FALSE, 'Used needles/pens present biohazard puncture risks. Place immediately in FDA-cleared sharps disposal container.', 'Drop off sharps container at local community sharps collection site or hazardous waste facility. Never place in recycling.', 'FDA Sharps Disposal Guidelines', 4);

-- 15. Recall Records
TRUNCATE TABLE recall_records;
INSERT INTO recall_records 
    (recall_id, recall_reference_code, issuing_authority, recall_class, recall_reason, status, announcement_date, action_required, reference_id)
VALUES
    (1, 'FDA-REC-2026-084', 'US Food and Drug Administration', 'CLASS_II', 'Defective blister foil seal causing degradation and loss of antibacterial potency due to humidity exposure.', 'ACTIVE', '2026-02-14', 'Quarantine inventory immediately. Contact distributing wholesaler for full credit return.', 1);

-- 16. Recall-Medicine Relationships (Using surrogate primary key recall_medicine_id)
TRUNCATE TABLE recall_medicines;
INSERT INTO recall_medicines 
    (recall_medicine_id, recall_id, medicine_id, batch_id, affected_lot_description)
VALUES
    (1, 1, 2, 7, 'Batch AUG-2025-RC01 blister strips showing foil delamination under lot code 2509RC.');

-- 17. Safety Alerts
TRUNCATE TABLE safety_alerts;
INSERT INTO safety_alerts 
    (alert_id, medicine_id, alert_title, alert_level, description, effective_date, reference_id)
VALUES
    (1, 6, 'Bleeding Risk Warning (Black Box)', 'BLACK_BOX_WARNING', 'Warfarin can cause major or fatal bleeding. Perform regular monitoring of INR in all treated patients. Inform patients of dietary vitamin K interactions.', '2026-01-01', 2),
    (2, 3, 'Lactic Acidosis Alert', 'BLACK_BOX_WARNING', 'Post-marketing cases of hypothermia, hypotension, and resistant bradyarrhythmias with metformin-associated lactic acidosis. Discontinue immediately if metabolic acidosis is suspected.', '2026-01-15', 2);

-- 18. Scan Records
TRUNCATE TABLE scan_records;
INSERT INTO scan_records 
    (scan_id, user_id, scan_type, raw_scanned_data, matched_medicine_id, matched_batch_id, ocr_confidence_score, verification_status)
VALUES
    (1, 4, 'BARCODE_UPC', '8901030588204', 1, 1, 99.50, 'MATCH_CONFIRMED'),
    (2, 4, 'BARCODE_UPC', '8901030612442', 2, 7, 98.80, 'FLAGGED_INCONSISTENCY');

-- 19. Audit Logs
TRUNCATE TABLE audit_logs;
INSERT INTO audit_logs 
    (log_id, table_name, record_id, action_type, changed_by_user_id, old_values, new_values, ip_address)
VALUES
    (1, 'medicines', 1, 'INSERT', 1, NULL, JSON_OBJECT('brand_name', 'Crocin Advance', 'strength', '500 mg'), '127.0.0.1'),
    (2, 'recall_records', 1, 'INSERT', 1, NULL, JSON_OBJECT('recall_code', 'FDA-REC-2026-084', 'class', 'CLASS_II'), '127.0.0.1');

SET FOREIGN_KEY_CHECKS = 1;
