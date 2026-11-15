# MEDICYCLE — Enterprise Relational Data Dictionary

**Database Name:** `medicycle_db`  
**Engine:** MySQL InnoDB  
**Default Charset:** `utf8mb4`  
**Default Collation:** `utf8mb4_unicode_ci`  
**Document Revision:** 2.3 (Refined Schema Constraints & Non-Assumptive Defaults)  
**Total Base Tables:** 28 (19 Baseline Tables + 9 Migration Master/Junction/Ledger Tables)  
**Total Analytical Views:** 4  
**File Location:** `database/docs/data_dictionary.md`  

---

## Table of Contents
1. [Core Pharmacological Master Tables (6 Tables)](#1-core-pharmacological-master-tables)
   - `categories` (Baseline)
   - `manufacturers` (Baseline)
   - `ingredients` (Baseline)
   - `medicines` (Baseline)
   - `medicine_compositions` (Baseline)
   - `medicine_uses` (Baseline)
2. [Physical Lifecycle & Quality Control Tables (4 Tables)](#2-physical-lifecycle--quality-control-tables)
   - `medicine_batches` (Baseline)
   - `storage_rules` (Baseline)
   - `temperature_monitoring_logs` *(Migration 03)*
   - `medicine_disposal_logs` *(Migration 06)*
3. [Clinical Safety & Pharmacovigilance Tables (6 Tables)](#3-clinical-safety--pharmacovigilance-tables)
   - `drug_interactions` (Baseline)
   - `side_effects` (Baseline)
   - `contraindications` (Baseline)
   - `safety_alerts` (Baseline)
   - `recall_records` (Baseline)
   - `recall_medicines` (Baseline)
4. [Eco-Disposal & Environmental Intelligence Tables (2 Tables)](#4-eco-disposal--environmental-intelligence-tables)
   - `disposal_guidelines` (Baseline)
   - `environmental_impact_records` *(Migration 05)*
5. [Authenticity, Vision & OCR Pipeline Tables (2 Tables)](#5-authenticity-vision--ocr-pipeline-tables)
   - `scan_records` (Baseline)
   - `ocr_extraction_records` *(Migration 04)*
6. [Identity, Access Control & Audit Tables (8 Tables)](#6-identity-access-control--audit-tables)
   - `users` (Baseline)
   - `roles` *(Migration 02)*
   - `permissions` *(Migration 02)*
   - `user_roles` *(Migration 02)*
   - `role_permissions` *(Migration 02)*
   - `audit_logs` (Baseline)
   - `source_references` (Baseline)
   - `schema_migrations` *(Migration 01)*
7. [Enterprise Analytical Reporting Views (4 Views)](#7-enterprise-analytical-reporting-views)
   - `v_medicine_digital_passport` *(Migration 07)*
   - `v_active_recalls_inventory` *(Migration 07)*
   - `v_cold_chain_excursion_alerts` *(Migration 07)*
   - `v_expiring_batches_summary` *(Migration 07)*

---

## 1. Core Pharmacological Master Tables

### 1.1 `categories`
Stores therapeutic and anatomical classification categories for drugs based on the WHO ATC standard.

| Column Name | Data Type | Nullable | Default | Keys / Constraints | Description |
|---|---|---|---|---|---|
| `category_id` | `INT UNSIGNED` | NO | Auto Inc | **PRIMARY KEY** | Unique surrogate identifier for therapeutic category. |
| `category_name` | `VARCHAR(100)` | NO | None | **UNIQUE** | Canonical clinical category name (e.g. Analgesics, Statins). |
| `atc_code_prefix` | `VARCHAR(10)` | YES | NULL | None | WHO Anatomical Therapeutic Chemical code prefix (e.g. `N02BE`). |
| `description` | `TEXT` | YES | NULL | None | Detailed clinical scope and physiological mechanism summary. |
| `created_at` | `TIMESTAMP` | YES | `CURRENT_TIMESTAMP` | None | Record ingestion timestamp. |

---

### 1.2 `manufacturers`
Represents registered pharmaceutical manufacturing companies and legal marketing authorization holders.

| Column Name | Data Type | Nullable | Default | Keys / Constraints | Description |
|---|---|---|---|---|---|
| `manufacturer_id` | `INT UNSIGNED` | NO | Auto Inc | **PRIMARY KEY** | Unique surrogate identifier for manufacturer. |
| `name` | `VARCHAR(150)` | NO | None | **UNIQUE** | Registered commercial business name. |
| `country` | `VARCHAR(80)` | NO | None | None | Country of corporate headquarters. |
| `contact_email` | `VARCHAR(120)` | YES | NULL | None | Regulatory or medical affairs contact email. |
| `license_number` | `VARCHAR(80)` | YES | NULL | **UNIQUE** | Pharmaceutical establishment manufacturing license code. |
| `website` | `VARCHAR(255)` | YES | NULL | None | Official corporate portal URL. |
| `is_fda_approved` | `TINYINT(1)` | NO | `1` | None | Boolean flag: 1 = FDA/CDSCO/Regulatory certified, 0 = Uncertified. |
| `created_at` | `TIMESTAMP` | YES | `CURRENT_TIMESTAMP` | None | Audit timestamp when company was added. |

---

### 1.3 `ingredients`
Active Pharmaceutical Ingredients (APIs) and bioactive chemical entities.

| Column Name | Data Type | Nullable | Default | Keys / Constraints | Description |
|---|---|---|---|---|---|
| `ingredient_id` | `INT UNSIGNED` | NO | Auto Inc | **PRIMARY KEY** | Unique surrogate identifier for active ingredient. |
| `generic_name` | `VARCHAR(150)` | NO | None | **UNIQUE** | International Nonproprietary Name (INN). |
| `chemical_formula` | `VARCHAR(100)` | YES | NULL | None | Molecular empirical formula (e.g. `C8H9NO2`). |
| `cas_number` | `VARCHAR(30)` | YES | NULL | **UNIQUE** | Chemical Abstracts Service registry identifier (e.g. `103-90-2`). |
| `drug_class` | `VARCHAR(100)` | YES | NULL | None | Pharmacological class (e.g. `Anilide Analgesic`). |
| `description` | `TEXT` | YES | NULL | None | Pharmacodynamic overview and biological target description. |
| `reference_id` | `BIGINT UNSIGNED`| YES | NULL | **FK** -> `source_references` | Source documentation reference citation. |
| `created_at` | `TIMESTAMP` | YES | `CURRENT_TIMESTAMP` | None | Ingestion timestamp. |

---

### 1.4 `medicines`
The foundational core entity anchoring the Digital Passport for every finished pharmaceutical product.

| Column Name | Data Type | Nullable | Default | Keys / Constraints | Description |
|---|---|---|---|---|---|
| `medicine_id` | `BIGINT UNSIGNED`| NO | Auto Inc | **PRIMARY KEY** | Unique master identifier for the medicine product. |
| `brand_name` | `VARCHAR(150)` | NO | None | `INDEX` | Commercial brand/trade name (e.g. Crocin Advance). |
| `generic_name` | `VARCHAR(150)` | NO | None | `INDEX` | Standard generic descriptor or active combination. |
| `category_id` | `INT UNSIGNED` | NO | None | **FK** -> `categories` | Therapeutic classification link (`RESTRICT`). |
| `manufacturer_id` | `INT UNSIGNED` | NO | None | **FK** -> `manufacturers` | Producer/marketing authorization holder link (`RESTRICT`). |
| `dosage_form` | `ENUM` | NO | None | Values: `TABLET`, `CAPSULE`, `SYRUP`, `INJECTION`, `OINTMENT`, `DROPS`, `INHALER`, `PATCH` | Physical pharmaceutical delivery form. |
| `strength` | `VARCHAR(50)` | NO | None | None | Labeled commercial strength descriptor (e.g. `500 mg`). |
| `administration_route` | `VARCHAR(60)` | NO | None | None | Route of administration (e.g. `Oral`, `Subcutaneous`). |
| `prescription_classification` | `ENUM` | NO | `'PRESCRIPTION_ONLY'` | Values: `OTC`, `PRESCRIPTION_ONLY`, `CONTROLLED_SUBSTANCE` | Regulatory dispensing status (Schedule H/H1 in India). |
| `barcode_upc` | `VARCHAR(32)` | YES | NULL | **UNIQUE**, `INDEX` | Scannable GTIN/UPC/EAN-13 barcode sequence. |
| `ndc_number` | `VARCHAR(20)` | YES | NULL | **UNIQUE** | FDA NDC or national drug registration identifier. |
| `is_active` | `TINYINT(1)` | NO | `1` | None | Operational status: 1 = Active catalog, 0 = Discontinued. |
| `reference_id` | `BIGINT UNSIGNED`| YES | NULL | **FK** -> `source_references` | Regulatory package insert reference. |
| `created_at` | `TIMESTAMP` | YES | `CURRENT_TIMESTAMP` | None | Initial database ingestion timestamp. |
| `updated_at` | `TIMESTAMP` | YES | `CURRENT_TIMESTAMP ON UPDATE` | None | Timestamp of last metadata update. |

---

### 1.5 `medicine_compositions`
Normalized junction establishing the quantitative formulation of ingredients per medicine unit.

| Column Name | Data Type | Nullable | Default | Keys / Constraints | Description |
|---|---|---|---|---|---|
| `composition_id` | `BIGINT UNSIGNED`| NO | Auto Inc | **PRIMARY KEY** | Unique identifier for formulation entry. |
| `medicine_id` | `BIGINT UNSIGNED`| NO | None | **FK** -> `medicines`, `COMPOSITE UNIQUE(1)` | Referenced parent medicine (`CASCADE`). |
| `ingredient_id` | `INT UNSIGNED` | NO | None | **FK** -> `ingredients`, `COMPOSITE UNIQUE(2)` | Active or inactive ingredient reference (`RESTRICT`). |
| `strength_value` | `DECIMAL(10,3)` | NO | None | None | Exact numerical quantity of ingredient per dosage unit. |
| `strength_unit` | `VARCHAR(20)` | NO | None | None | Metric unit of measure (e.g. `mg`, `mcg`, `g`, `mL`, `IU`). |
| `is_active_ingredient` | `TINYINT(1)` | NO | `1` | None | Flag: 1 = Active Pharmaceutical Ingredient, 0 = Excipient. |

---

### 1.6 `medicine_uses`
Approved clinical indications, target pathologies, and disease states.

| Column Name | Data Type | Nullable | Default | Keys / Constraints | Description |
|---|---|---|---|---|---|
| `use_id` | `BIGINT UNSIGNED`| NO | Auto Inc | **PRIMARY KEY** | Unique identifier for clinical indication. |
| `medicine_id` | `BIGINT UNSIGNED`| NO | None | **FK** -> `medicines` | Referenced medicine (`CASCADE`). |
| `indication` | `VARCHAR(255)` | NO | None | None | Medical condition or disease symptom indicated for treatment. |
| `is_fda_approved` | `TINYINT(1)` | NO | `1` | None | 1 = Label-approved indication, 0 = Off-label evidence-based use. |
| `target_condition` | `VARCHAR(150)` | YES | NULL | None | Disease categorization (e.g. `Type 2 Diabetes Mellitus`). |
| `reference_id` | `BIGINT UNSIGNED`| YES | NULL | **FK** -> `source_references` | Clinical trial or pharmacopoeia citation. |

---

## 2. Physical Lifecycle & Quality Control Tables

### 2.1 `medicine_batches`
Represents physical manufacturing production lots, serialized packaging, and expiration tracking.

| Column Name | Data Type | Nullable | Default | Keys / Constraints | Description |
|---|---|---|---|---|---|
| `batch_id` | `BIGINT UNSIGNED`| NO | Auto Inc | **PRIMARY KEY** | Master batch surrogate identifier. |
| `medicine_id` | `BIGINT UNSIGNED`| NO | None | **FK** -> `medicines`, `COMPOSITE UNIQUE(1)` | Parent medicine link (`RESTRICT`). |
| `batch_number` | `VARCHAR(50)` | NO | None | `COMPOSITE UNIQUE(2)`, `INDEX` | Alphanumeric manufacturer lot/batch code. |
| `manufacturing_date` | `DATE` | NO | None | None | Official release date of batch production. |
| `expiry_date` | `DATE` | NO | None | `INDEX`, `CHECK (expiry_date > manufacturing_date)` | Date after which chemical stability is no longer guaranteed. |
| `initial_quantity` | `INT UNSIGNED` | NO | `0` | None | Total units produced/received in batch. |
| `status` | `ENUM` | NO | `'VALID'` | Values: `VALID`, `EXPIRING_SOON`, `EXPIRED`, `RECALLED`, `QUARANTINED` | Operational inventory quality status. |
| `created_at` | `TIMESTAMP` | YES | `CURRENT_TIMESTAMP` | None | Lot registration timestamp. |

---

### 2.2 `storage_rules`
Mandated environmental and cold-chain storage parameters per drug formulation.

| Column Name | Data Type | Nullable | Default | Keys / Constraints | Description |
|---|---|---|---|---|---|
| `rule_id` | `BIGINT UNSIGNED`| NO | Auto Inc | **PRIMARY KEY** | Unique storage rule identifier. |
| `medicine_id` | `BIGINT UNSIGNED`| NO | None | **FK** -> `medicines`, **UNIQUE** | One-to-one medicine link (`CASCADE`). |
| `min_temp_celsius` | `DECIMAL(4,1)` | NO | None | `CHECK (min_temp_celsius <= max_temp_celsius)` | Lower bound allowable temperature in °C. |
| `max_temp_celsius` | `DECIMAL(4,1)` | NO | None | None | Upper bound allowable temperature in °C. |
| `requires_refrigeration` | `TINYINT(1)` | NO | `0` | None | Flag: 1 = Mandatory cold chain (2°C to 8°C). |
| `light_sensitive` | `TINYINT(1)` | NO | `0` | None | Flag: 1 = Must store in light-protective packaging/amber vial. |
| `moisture_sensitive` | `TINYINT(1)` | NO | `0` | None | Flag: 1 = Highly hygroscopic; desiccated packaging required. |
| `storage_instructions` | `TEXT` | NO | None | None | Human-readable clinical storage directives. |
| `excursion_limit_hours` | `INT UNSIGNED`| YES | NULL | None | Max permitted cumulative hours outside range before degradation. |

---

### 2.3 `temperature_monitoring_logs` *(Migration 03)*
Real-time cold-chain IoT telemetry recording sensor measurements, thermal excursions, and corrective interventions.

| Column Name | Data Type | Nullable | Default | Keys / Constraints | Description |
|---|---|---|---|---|---|
| `log_id` | `BIGINT UNSIGNED`| NO | Auto Inc | **PRIMARY KEY** | Unique sensor reading identifier. |
| `batch_id` | `BIGINT UNSIGNED`| NO | None | **FK** -> `medicine_batches` | Specific lot being tracked (`RESTRICT`). |
| `recorded_temperature_celsius` | `DECIMAL(4,1)` | NO | None | None | Calibrated sensor reading at timestamp. |
| `recorded_humidity_percent` | `DECIMAL(4,1)` | YES | NULL | `CHECK (humidity BETWEEN 0 AND 100)` | Relative humidity percentage reading. |
| `sensor_device_id` | `VARCHAR(80)` | NO | None | None | Hardware UUID or serial number of telemetry logger. |
| `storage_location` | `VARCHAR(120)` | NO | None | None | Physical location (e.g. `Walk-in Cooler A`, `Transport Reefer 4`). |
| `reading_timestamp` | `TIMESTAMP` | NO | `CURRENT_TIMESTAMP` | `INDEX` | Exact moment of telemetry capture. |
| `is_excursion` | `TINYINT(1)` | NO | `0` | `INDEX` | Flag: 1 = Temperature breached authorized storage rule bounds. |
| `excursion_duration_minutes` | `INT UNSIGNED`| YES | `0` | None | Duration in minutes that temperature stayed out of limits. |
| `action_taken` | `TEXT` | YES | NULL | None | Corrective QA action (e.g. `Quarantine batch`, `Transferred cooler`). |
| `logged_by_user_id` | `BIGINT UNSIGNED`| YES | NULL | **FK** -> `users` | User or automated service account (`SET NULL`). |
| `created_at` | `TIMESTAMP` | YES | `CURRENT_TIMESTAMP` | None | Ingestion timestamp. |

---

### 2.4 `medicine_disposal_logs` *(Migration 06)*
Auditable record of physical pharmaceutical decommissioning complying with Indian CPCB Bio-Medical Waste Rules 2016 and US EPA RCRA.

| Column Name | Data Type | Nullable | Default | Keys / Constraints | Description |
|---|---|---|---|---|---|
| `disposal_log_id` | `BIGINT UNSIGNED`| NO | Auto Inc | **PRIMARY KEY** | Unique disposal record identifier. |
| `batch_id` | `BIGINT UNSIGNED`| NO | None | **FK** -> `medicine_batches` | Physical lot being destroyed (`RESTRICT`). |
| `quantity_disposed` | `INT UNSIGNED` | NO | None | `CHECK (quantity_disposed > 0)` | Number of dosage units/packs decommissioned. |
| `reason_for_disposal` | `ENUM` | NO | None | Values: `EXPIRED`, `COLD_CHAIN_EXCURSION`, `RECALLED`, `DAMAGED_PACKAGING`, `CONTAMINATED`, `PATIENT_RETURN` | Reason for inventory destruction. |
| `applied_method` | `ENUM` | NO | `'UNKNOWN'` | Values: `INCINERATION_HIGH_TEMP`, `CBMWTF_YELLOW_CATEGORY_INCINERATION`, `ENCAPSULATION_INERTIZATION`, `CHEMICAL_INACTIVATION`, `HAZARDOUS_FACILITY_TRANSFER`, `AUTHORIZED_TAKE_BACK_KIOSK`, `UNKNOWN` | Physical destruction method used under CPCB/EPA protocols. |
| `cpcb_waste_category` | `ENUM` | NO | `'UNKNOWN'` | Values: `YELLOW_CATEGORY_H_EXPIRED_DRUGS`, `CYTOTOXIC_EXP_DRUGS`, `GENERAL_SOLID_PHARMA`, `CONTROLLED_SUBSTANCE_DESTRUCTION`, `UNKNOWN` | Indian Bio-Medical Waste Rules Schedule I classification. |
| `verification_status` | `ENUM` | NO | `'PENDING_REGULATORY_VERIFICATION'` | Values: `PENDING_REGULATORY_VERIFICATION`, `COMPLIANT_VERIFIED`, `NON_COMPLIANT_FLAGGED` | Regulatory compliance state. |
| `facility_name` | `VARCHAR(150)` | YES | NULL | None | Authorized CBWTF facility name (nullable pending facility selection and dispatch). |
| `certificate_of_destruction_ref` | `VARCHAR(100)` | YES | NULL | `UNIQUE` | Official regulatory manifest or certificate code. |
| `cpcb_manifest_number` | `VARCHAR(100)` | YES | NULL | None | SPCB/CPCB Form-VI consignment tracking code. |
| `witnessed_by_user_id` | `BIGINT UNSIGNED`| YES | NULL | **FK** -> `users` | Verifying licensed pharmacist or Pollution Control compliance officer (`SET NULL`). |
| `disposal_date` | `DATE` | NO | None | None | Date destruction was executed or initiated. |
| `created_at` | `TIMESTAMP` | YES | `CURRENT_TIMESTAMP` | None | Audit record creation timestamp. |

*Constraints:* `CONSTRAINT chk_compliance_evidence CHECK (verification_status <> 'COMPLIANT_VERIFIED' OR (witnessed_by_user_id IS NOT NULL AND facility_name IS NOT NULL AND certificate_of_destruction_ref IS NOT NULL))`

---

## 3. Clinical Safety & Pharmacovigilance Tables

### 3.1 `drug_interactions`
Active ingredient pair matrix documenting mechanism, clinical effect, and contraindications.

| Column Name | Data Type | Nullable | Default | Keys / Constraints | Description |
|---|---|---|---|---|---|
| `interaction_id` | `BIGINT UNSIGNED`| NO | Auto Inc | **PRIMARY KEY** | Unique interaction record identifier. |
| `ingredient1_id` | `INT UNSIGNED` | NO | None | **FK** -> `ingredients`, `COMPOSITE UNIQUE(1)` | First interacting active substance. |
| `ingredient2_id` | `INT UNSIGNED` | NO | None | **FK** -> `ingredients`, `COMPOSITE UNIQUE(2)` | Second interacting active substance. |
| `severity` | `ENUM` | NO | None | Values: `MILD`, `MODERATE`, `SEVERE`, `CONTRAINDICATED` | Clinical risk severity classification. |
| `mechanism` | `TEXT` | YES | NULL | None | Pharmacological rationale (CYP inhibition, receptor competition). |
| `clinical_effect` | `TEXT` | NO | None | None | Manifesting symptoms and physiological impact. |
| `management_advice` | `TEXT` | NO | None | None | Clinical guidance for prescribers and pharmacists. |
| `reference_id` | `BIGINT UNSIGNED`| YES | NULL | **FK** -> `source_references` | Pharmacopoeia attribution (`SET NULL`). |

*Constraints:* `CONSTRAINT chk_diff_ing CHECK (ingredient1_id <> ingredient2_id)`

---

### 3.2 `side_effects`
Adverse drug reactions cataloged with epidemiological frequency and clinical severity.

| Column Name | Data Type | Nullable | Default | Keys / Constraints | Description |
|---|---|---|---|---|---|
| `side_effect_id` | `BIGINT UNSIGNED`| NO | Auto Inc | **PRIMARY KEY** | Unique adverse event identifier. |
| `medicine_id` | `BIGINT UNSIGNED`| NO | None | **FK** -> `medicines` | Parent medicine link (`CASCADE`). |
| `adverse_reaction` | `VARCHAR(200)` | NO | None | None | Clinical name of adverse event (e.g. `Hepatotoxicity`). |
| `frequency` | `ENUM` | NO | `'COMMON'` | Values: `VERY_COMMON`, `COMMON`, `UNCOMMON`, `RARE`, `VERY_RARE` | CIOMS epidemiological occurrence rate. |
| `severity` | `ENUM` | NO | `'MILD'` | Values: `MILD`, `MODERATE`, `SEVERE`, `LIFE_THREATENING` | Clinical severity grading. |
| `requires_medical_attention` | `TINYINT(1)` | NO | `0` | None | Flag: 1 = Patient must seek emergency clinical care. |

---

### 3.3 `contraindications`
Conditions where administration of the medicine introduces unacceptable medical risks.

| Column Name | Data Type | Nullable | Default | Keys / Constraints | Description |
|---|---|---|---|---|---|
| `contraindication_id`| `BIGINT UNSIGNED`| NO | Auto Inc | **PRIMARY KEY** | Unique contraindication identifier. |
| `medicine_id` | `BIGINT UNSIGNED`| NO | None | **FK** -> `medicines` | Parent medicine link (`CASCADE`). |
| `condition_name` | `VARCHAR(200)` | NO | None | None | Pathology or physiological state (e.g. `Severe Hepatic Cirrhosis`). |
| `type` | `ENUM` | NO | `'ABSOLUTE'`| Values: `ABSOLUTE`, `RELATIVE` | Absolute = Never administer; Relative = Weigh risk/benefit. |
| `clinical_rationale` | `TEXT` | NO | None | None | Biological rationale explaining elevated morbidity/mortality. |

---

### 3.4 `safety_alerts`
High-priority pharmacovigilance advisories, Boxed Warnings, and newly discovered risks.

| Column Name | Data Type | Nullable | Default | Keys / Constraints | Description |
|---|---|---|---|---|---|
| `alert_id` | `BIGINT UNSIGNED`| NO | Auto Inc | **PRIMARY KEY** | Unique safety alert identifier. |
| `medicine_id` | `BIGINT UNSIGNED`| NO | None | **FK** -> `medicines` | Target medicine (`CASCADE`). |
| `alert_title` | `VARCHAR(200)` | NO | None | None | Formal clinical alert heading. |
| `alert_level` | `ENUM` | NO | None | Values: `BLACK_BOX_WARNING`, `WARNING`, `PRECAUTION`, `SAFETY_ADVISORY` | Severity hierarchy tier. |
| `description` | `TEXT` | NO | None | None | Detailed clinical warning text. |
| `effective_date` | `DATE` | NO | None | None | Date advisory takes legal/clinical effect. |
| `reference_id` | `BIGINT UNSIGNED`| YES | NULL | **FK** -> `source_references` | Regulatory bulletin link (`SET NULL`). |

---

### 3.5 `recall_records`
Official recall campaigns issued by regulatory agencies (FDA, CDSCO, MHRA, EMA).

| Column Name | Data Type | Nullable | Default | Keys / Constraints | Description |
|---|---|---|---|---|---|
| `recall_id` | `BIGINT UNSIGNED`| NO | Auto Inc | **PRIMARY KEY** | Master recall campaign identifier. |
| `recall_reference_code` | `VARCHAR(50)` | NO | None | **UNIQUE** | Regulatory publication docket code (e.g. `FDA-REC-2026-084`). |
| `issuing_authority` | `VARCHAR(100)` | NO | None | None | Agency (e.g. `US Food and Drug Administration`, `CDSCO India`). |
| `recall_class` | `ENUM` | NO | None | Values: `CLASS_I`, `CLASS_II`, `CLASS_III` | Class I = High risk of death; Class III = Minor infraction. |
| `recall_reason` | `TEXT` | NO | None | None | Official statement of chemical/packaging defect. |
| `status` | `ENUM` | NO | `'ACTIVE'` | Values: `ACTIVE`, `COMPLETED`, `TERMINATED` | Current administrative status of campaign. |
| `announcement_date` | `DATE` | NO | None | None | Date campaign was publicly posted. |
| `action_required` | `TEXT` | NO | None | None | Directive for distributors, pharmacies, and patients. |
| `reference_id` | `BIGINT UNSIGNED`| YES | NULL | **FK** -> `source_references` | Regulatory link (`SET NULL`). |

---

### 3.6 `recall_medicines`
Targeted junction connecting recalls to specific medicines and (optionally) specific production lots.

| Column Name | Data Type | Nullable | Default | Keys / Constraints | Description |
|---|---|---|---|---|---|
| `recall_medicine_id` | `BIGINT UNSIGNED`| NO | Auto Inc | **PRIMARY KEY** | Surrogate primary key resolving composite nullability issues. |
| `recall_id` | `BIGINT UNSIGNED`| NO | None | **FK** -> `recall_records`, `COMPOSITE UNIQUE(1)` | Parent recall campaign (`CASCADE`). |
| `medicine_id` | `BIGINT UNSIGNED`| NO | None | **FK** -> `medicines`, `COMPOSITE UNIQUE(2)` | Recalled medicine product (`RESTRICT`). |
| `batch_id` | `BIGINT UNSIGNED`| YES | NULL | **FK** -> `medicine_batches`, `COMPOSITE UNIQUE(3)` | Specific quarantined lot (`SET NULL`); `NULL` = all batches. |
| `affected_lot_description`| `VARCHAR(255)` | YES | NULL | None | Specific packaging or serial ranges affected. |
| `created_at` | `TIMESTAMP` | YES | `CURRENT_TIMESTAMP` | None | Ingestion timestamp. |

---

## 4. Eco-Disposal & Environmental Intelligence Tables

### 4.1 `disposal_guidelines`
Authoritative disposal pathways aligning with EPA RCRA and Indian CPCB Bio-Medical Waste standards.

| Column Name | Data Type | Nullable | Default | Keys / Constraints | Description |
|---|---|---|---|---|---|
| `guideline_id` | `BIGINT UNSIGNED`| NO | Auto Inc | **PRIMARY KEY** | Unique disposal guideline identifier. |
| `medicine_id` | `BIGINT UNSIGNED`| NO | None | **FK** -> `medicines`, **UNIQUE** | One-to-one medicine link (`CASCADE`). |
| `disposal_method` | `ENUM` | NO | None | Values: `FLUSH_LIST`, `HOUSEHOLD_TRASH_MIXED`, `TAKE_BACK_ONLY`, `HAZARDOUS_WASTE_FACILITY` | Regulatory prescribed disposal channel. |
| `environmental_hazard_rating` | `ENUM` | NO | None | Values: `LOW`, `MODERATE`, `HIGH`, `CRITICAL` | Overall ecotoxicity severity rating. |
| `aquatic_toxicity_risk` | `TINYINT(1)` | NO | `0` | None | Flag: 1 = Toxic to aquatic flora and fauna. |
| `mixing_instructions` | `TEXT` | YES | NULL | None | Instructions for household inerting (coffee grounds, cat litter). |
| `take_back_instructions` | `TEXT` | YES | NULL | None | Protocols for returning unused stock to pharmacies. |
| `regulatory_reference` | `VARCHAR(255)` | YES | NULL | None | Governing environmental statute reference (EPA / CPCB). |
| `reference_id` | `BIGINT UNSIGNED`| YES | NULL | **FK** -> `source_references` | Source documentation citation (`SET NULL`). |

---

### 4.2 `environmental_impact_records` *(Migration 05)*
Detailed ecotoxicology metrics, degradation half-lives, and carbon footprint tracking complying with REACH and CPCB GSR 543(E).

| Column Name | Data Type | Nullable | Default | Keys / Constraints | Description |
|---|---|---|---|---|---|
| `impact_id` | `BIGINT UNSIGNED`| NO | Auto Inc | **PRIMARY KEY** | Unique ecotox record identifier. |
| `medicine_id` | `BIGINT UNSIGNED`| NO | None | **FK** -> `medicines`, `INDEX` | Associated commercial medicine (`CASCADE`). |
| `ingredient_id` | `INT UNSIGNED` | YES | NULL | **FK** -> `ingredients`, `INDEX` | Specific API if impact is chemically isolated (`SET NULL`). |
| `assessment_status` | `ENUM` | NO | `'UNVERIFIED_ESTIMATE'` | Values: `UNVERIFIED_ESTIMATE`, `LABORATORY_VERIFIED`, `REGULATORY_OFFICIAL` | Audit validation tier of ecotoxicity metrics. |
| `pbt_status` | `ENUM` | NO | `'UNKNOWN'` | Values: `PERSISTENT`, `BIOACCUMULATIVE`, `TOXIC`, `VERY_PERSISTENT_VERY_BIOACCUMULATIVE`, `NOT_PBT`, `UNKNOWN` | REACH Annex XIII criteria classification. |
| `bioaccumulation_factor_bcf` | `DECIMAL(8,2)` | YES | NULL | `CHECK (bcf >= 0)` | Bioconcentration factor in fish/aquatic organisms. |
| `half_life_water_days` | `DECIMAL(8,2)` | YES | NULL | `CHECK (half_life_water >= 0)` | Photolytic/biodegradation half-life in freshwater (days). |
| `half_life_soil_days` | `DECIMAL(8,2)` | YES | NULL | `CHECK (half_life_soil >= 0)` | Biodegradation persistence in soil (days). |
| `pnec_aquatic_ug_l` | `DECIMAL(10,4)`| YES | NULL | `CHECK (pnec >= 0)` | Predicted No-Effect Concentration in aquatic ecosystems ($\mu\text{g/L}$). |
| `water_hazard_class_wgk` | `ENUM` | NO | `'UNKNOWN'` | Values: `NOT_HAZARDOUS`, `CLASS_1_SLIGHT`, `CLASS_2_OBVIOUS`, `CLASS_3_SEVERE`, `UNKNOWN` | German Federal Water Hazard Class. |
| `carbon_footprint_kg_co2e` | `DECIMAL(8,3)` | YES | NULL | `CHECK (carbon >= 0)` | Cradle-to-grave emissions per packaged commercial unit (kg $\text{CO}_2\text{e}$). |
| `packaging_recyclability_percent` | `DECIMAL(5,2)` | YES | NULL | `CHECK (pct BETWEEN 0 AND 100)` | Percentage of outer packaging material recyclable. |
| `antimicrobial_resistance_risk` | `ENUM` | NO | `'UNKNOWN'` | Values: `LOW`, `MEDIUM`, `HIGH`, `CRITICAL`, `UNKNOWN` | Risk of driving environmental AMR selection. |
| `cpcb_effluent_standard_compliant` | `BOOLEAN` | YES | NULL | None | NULL = Pending Audit, 1 = Compliant with GSR 543(E), 0 = Non-Compliant. |
| `impact_assessment_summary` | `TEXT` | YES | NULL | None | Qualitative narrative explaining ecological hazards. |
| `reference_id` | `BIGINT UNSIGNED`| YES | NULL | **FK** -> `source_references` | Peer-reviewed environmental study link (`SET NULL`). |
| `created_at` | `TIMESTAMP` | YES | `CURRENT_TIMESTAMP` | None | Registration timestamp. |

*Constraints:* `CONSTRAINT chk_verified_needs_ref CHECK (assessment_status = 'UNVERIFIED_ESTIMATE' OR reference_id IS NOT NULL)`

---

## 5. Authenticity, Vision & OCR Pipeline Tables

### 5.1 `scan_records`
Audit trail of user scans (barcode, QR, OCR) capturing authentication outcomes.

| Column Name | Data Type | Nullable | Default | Keys / Constraints | Description |
|---|---|---|---|---|---|
| `scan_id` | `BIGINT UNSIGNED`| NO | Auto Inc | **PRIMARY KEY** | Unique scan event identifier. |
| `user_id` | `BIGINT UNSIGNED`| YES | NULL | **FK** -> `users` | Authenticated user executing scan (`SET NULL`). |
| `scan_type` | `ENUM` | NO | None | Values: `BARCODE_UPC`, `QR_CODE`, `OCR_IMAGE`, `MANUAL_TEXT` | Capture modality. |
| `raw_scanned_data` | `TEXT` | NO | None | None | Exact string decoded by scanner or OCR buffer. |
| `matched_medicine_id` | `BIGINT UNSIGNED`| YES | NULL | **FK** -> `medicines` | Resolved medicine profile (`SET NULL`). |
| `matched_batch_id` | `BIGINT UNSIGNED`| YES | NULL | **FK** -> `medicine_batches` | Resolved batch profile (`SET NULL`). |
| `ocr_confidence_score`| `DECIMAL(5,2)` | YES | NULL | `CHECK (confidence BETWEEN 0 AND 100)` | Confidence score (0.00 to 100.00%). |
| `verification_status` | `ENUM` | NO | None | Values: `MATCH_CONFIRMED`, `AMBIGUOUS_MATCH`, `NO_MATCH_FOUND`, `FLAGGED_INCONSISTENCY` | Clinical authenticity evaluation result. |
| `scan_timestamp` | `TIMESTAMP` | YES | `CURRENT_TIMESTAMP` | None | Exact moment scan took place. |

---

### 5.2 `ocr_extraction_records` *(Migration 04)*
Detailed parsing artifacts, spatial coordinates, and token-level confidences generated from medicine packaging OCR.

| Column Name | Data Type | Nullable | Default | Keys / Constraints | Description |
|---|---|---|---|---|---|
| `extraction_id` | `BIGINT UNSIGNED`| NO | Auto Inc | **PRIMARY KEY** | Unique OCR extraction artifact identifier. |
| `scan_id` | `BIGINT UNSIGNED`| NO | None | **FK** -> `scan_records`, `INDEX` | Parent scan event link (`CASCADE`). |
| `extracted_brand_name` | `VARCHAR(150)` | YES | NULL | None | Brand name identified by OCR parser. |
| `extracted_generic_name`| `VARCHAR(150)` | YES | NULL | None | Generic name identified by OCR parser. |
| `extracted_batch_number`| `VARCHAR(50)` | YES | NULL | `INDEX` | Lot/Batch code isolated on package. |
| `extracted_mfg_date_raw`| `VARCHAR(40)` | YES | NULL | None | Raw date string extracted from foil/carton. |
| `extracted_exp_date_raw`| `VARCHAR(40)` | YES | NULL | None | Raw expiration string extracted from foil/carton. |
| `extracted_strength` | `VARCHAR(50)` | YES | NULL | None | Extracted dosage strength token (e.g. `625 mg`). |
| `extracted_dosage_form` | `VARCHAR(50)` | YES | NULL | None | Extracted form token (e.g. `Film-coated Tablets`). |
| `ocr_engine` | `VARCHAR(50)` | NO | `'TESSERACT_V5'`| None | Vision engine version (Tesseract, Google Vision, EasyOCR). |
| `bounding_box_coordinates`| `JSON` | YES | NULL | None | Normalized polygon/rectangle spatial coordinates. |
| `raw_text_segments` | `JSON` | YES | NULL | None | Array of all tokenized words with individual confidence scores. |
| `overall_confidence` | `DECIMAL(5,2)` | NO | None | `CHECK (overall_confidence BETWEEN 0 AND 100)` | Weighted composite extraction confidence. |
| `parsing_status` | `ENUM` | NO | `'PENDING'` | Values: `PENDING`, `PARSED_SUCCESSFULLY`, `PARTIAL_EXTRACTION`, `EXTRACTION_FAILED` | Asynchronous vision parser lifecycle status. |
| `created_at` | `TIMESTAMP` | YES | `CURRENT_TIMESTAMP` | None | Ingestion timestamp. |

---

## 6. Identity, Access Control & Audit Tables

### 6.1 `users`
Authenticated personnel accounts across the ecosystem.

| Column Name | Data Type | Nullable | Default | Keys / Constraints | Description |
|---|---|---|---|---|---|
| `user_id` | `BIGINT UNSIGNED`| NO | Auto Inc | **PRIMARY KEY** | Master user surrogate identifier. |
| `username` | `VARCHAR(50)` | NO | None | **UNIQUE** | Unique login handle. |
| `email` | `VARCHAR(120)` | NO | None | **UNIQUE** | Official corporate/user email. |
| `password_hash` | `VARCHAR(255)` | NO | None | None | Bcrypt/Argon2 one-way cryptographically salted password hash. |
| `full_name` | `VARCHAR(100)` | NO | None | None | User's legal full name. |
| `role` | `ENUM` | NO | `'USER'` | Values: `ADMIN`, `PHARMACIST`, `RESEARCHER`, `USER` | Backward-compatible primary role ENUM. |
| `is_active` | `TINYINT(1)` | NO | `1` | None | Account status: 1 = Active, 0 = Suspended. |
| `last_login_at` | `TIMESTAMP` | YES | NULL | None | Timestamp of most recent authentication session. |
| `created_at` | `TIMESTAMP` | YES | `CURRENT_TIMESTAMP` | None | Account creation timestamp. |
| `updated_at` | `TIMESTAMP` | YES | `CURRENT_TIMESTAMP ON UPDATE` | None | Timestamp of last account profile modification. |

---

### 6.2 `roles` *(Migration 02)*
Enterprise security roles defining access tiers.

| Column Name | Data Type | Nullable | Default | Keys / Constraints | Description |
|---|---|---|---|---|---|
| `role_id` | `INT UNSIGNED` | NO | Auto Inc | **PRIMARY KEY** | Unique role identifier. |
| `role_name` | `VARCHAR(50)` | NO | None | **UNIQUE** | Role title (e.g. `ADMIN`, `PHARMACIST`, `RESEARCHER`, `USER`). |
| `description` | `TEXT` | YES | NULL | None | Detailed functional charter of the role. |
| `created_at` | `TIMESTAMP` | YES | `CURRENT_TIMESTAMP` | None | Registration timestamp. |

---

### 6.3 `permissions` *(Migration 02)*
Atomic, granular capabilities governing API routes and database mutations.

| Column Name | Data Type | Nullable | Default | Keys / Constraints | Description |
|---|---|---|---|---|---|
| `permission_id` | `INT UNSIGNED` | NO | Auto Inc | **PRIMARY KEY** | Unique permission identifier. |
| `permission_code` | `VARCHAR(80)` | NO | None | **UNIQUE** | Symbolic machine code (e.g. `MEDICINE_WRITE`, `COLD_CHAIN_ALERT`). |
| `module` | `VARCHAR(50)` | NO | None | None | Functional subsystem (e.g. `CATALOG`, `COLD_CHAIN`, `SAFETY`). |
| `description` | `TEXT` | YES | NULL | None | Description of privileged action permitted by code. |
| `created_at` | `TIMESTAMP` | YES | `CURRENT_TIMESTAMP` | None | Registration timestamp. |

---

### 6.4 `user_roles` *(Migration 02)*
Maps users to their assigned roles.

| Column Name | Data Type | Nullable | Default | Keys / Constraints | Description |
|---|---|---|---|---|---|
| `user_id` | `BIGINT UNSIGNED`| NO | None | **PK (1)**, **FK** -> `users` | Referenced user account (`CASCADE`). |
| `role_id` | `INT UNSIGNED` | NO | None | **PK (2)**, **FK** -> `roles` | Referenced enterprise role (`CASCADE`). |
| `assigned_at` | `TIMESTAMP` | YES | `CURRENT_TIMESTAMP` | None | Timestamp role assignment was authorized. |

---

### 6.5 `role_permissions` *(Migration 02)*
Maps roles to their authorized capabilities.

| Column Name | Data Type | Nullable | Default | Keys / Constraints | Description |
|---|---|---|---|---|---|
| `role_id` | `INT UNSIGNED` | NO | None | **PK (1)**, **FK** -> `roles` | Referenced role (`CASCADE`). |
| `permission_id` | `INT UNSIGNED` | NO | None | **PK (2)**, **FK** -> `permissions` | Referenced permission (`CASCADE`). |
| `granted_at` | `TIMESTAMP` | YES | `CURRENT_TIMESTAMP` | None | Timestamp permission was attached to role. |

---

### 6.6 `audit_logs`
Tamper-evident transaction ledger recording all DDL/DML mutations across critical entities.

| Column Name | Data Type | Nullable | Default | Keys / Constraints | Description |
|---|---|---|---|---|---|
| `log_id` | `BIGINT UNSIGNED`| NO | Auto Inc | **PRIMARY KEY** | Unique audit record identifier. |
| `table_name` | `VARCHAR(64)` | NO | None | `INDEX(1)` | Database table targeted by mutation. |
| `record_id` | `BIGINT UNSIGNED`| NO | None | `INDEX(2)` | Primary key value of mutated record. |
| `action_type` | `ENUM` | NO | None | Values: `INSERT`, `UPDATE`, `DELETE` | Database operation type. |
| `changed_by_user_id`| `BIGINT UNSIGNED`| YES | NULL | **FK** -> `users` | Authenticated user account triggering change (`SET NULL`). |
| `old_values` | `JSON` | YES | NULL | None | Pre-mutation JSON snapshot (for `UPDATE` and `DELETE`). |
| `new_values` | `JSON` | YES | NULL | None | Post-mutation JSON snapshot (for `INSERT` and `UPDATE`). |
| `ip_address` | `VARCHAR(45)` | YES | NULL | None | IPv4 or IPv6 client origin address. |
| `logged_at` | `TIMESTAMP` | YES | `CURRENT_TIMESTAMP` | `INDEX` | Exact timestamp mutation was recorded. |

---

### 6.7 `source_references`
Authoritative clinical, pharmacopoeial, and environmental references grounding system intelligence.

| Column Name | Data Type | Nullable | Default | Keys / Constraints | Description |
|---|---|---|---|---|---|
| `reference_id` | `BIGINT UNSIGNED`| NO | Auto Inc | **PRIMARY KEY** | Unique reference citation identifier. |
| `source_name` | `VARCHAR(150)` | NO | None | None | Publishing body (e.g. `FDA Orange Book`, `WHO EML`, `EPA`, `CPCB India`). |
| `source_type` | `ENUM` | NO | None | Values: `REGULATORY`, `ACADEMIC`, `PHARMACOPOEIA`, `MANUFACTURER`, `ENVIRONMENTAL` | Category of citation. |
| `url` | `VARCHAR(500)` | YES | NULL | None | Direct authoritative web link. |
| `publication_title` | `VARCHAR(255)` | YES | NULL | None | Official title of reference book, journal, or regulation. |
| `edition_or_version`| `VARCHAR(50)` | YES | NULL | None | Volume, edition, or revision number. |
| `retrieval_date` | `DATE` | NO | None | None | Date information was retrieved and verified. |
| `verification_status`| `ENUM` | NO | `'VERIFIED'` | Values: `VERIFIED`, `PENDING_REVIEW`, `SUPERSEDED` | Current clinical curation validity. |
| `created_at` | `TIMESTAMP` | YES | `CURRENT_TIMESTAMP` | None | Initial database ingestion timestamp. |

---

### 6.8 `schema_migrations` *(Migration 01)*
State tracking table recording all executed incremental migration scripts.

| Column Name | Data Type | Nullable | Default | Keys / Constraints | Description |
|---|---|---|---|---|---|
| `migration_id` | `INT UNSIGNED` | NO | Auto Inc | **PRIMARY KEY** | Sequential identifier of executed migration. |
| `migration_name` | `VARCHAR(150)` | NO | None | **UNIQUE** | Filename of migration script (e.g. `02_create_rbac_tables.sql`). |
| `batch_number` | `INT UNSIGNED` | NO | `1` | `INDEX` | Execution batch grouping. |
| `executed_at` | `TIMESTAMP` | YES | `CURRENT_TIMESTAMP` | None | Timestamp migration was applied. |
| `execution_time_ms`| `INT UNSIGNED` | NO | `0` | None | Duration of migration script execution in milliseconds (0 initialized). |

---

## 7. Enterprise Analytical Reporting Views

### 7.1 `v_medicine_digital_passport` *(Migration 07)*
Consolidated 360-degree digital passport view joining `medicines`, `categories`, `manufacturers`, `storage_rules`, `disposal_guidelines`, active ingredients count, and primary indications.

### 7.2 `v_active_recalls_inventory` *(Migration 07)*
Real-time regulatory recall alert view correlating active recall campaigns (`recall_records`, `recall_medicines`) with physical warehouse lots (`medicine_batches`), explicitly exposing `recall_scope` (`MEDICINE_WIDE` vs `BATCH_SPECIFIC`) and `is_medicine_wide`.

### 7.3 `v_cold_chain_excursion_alerts` *(Migration 07)*
IoT cold-chain telemetry view filtering all batches currently in breach of their defined `storage_rules` with calculated temperature deviations in °C.

### 7.4 `v_expiring_batches_summary` *(Migration 07)*
Inventory shelf-life risk matrix categorizing batches as `EXPIRED`, `EXPIRING_SOON` ($\le 60\text{ days}$), or `STABLE` with real-time day counts.
