# MEDICYCLE — Database Architecture & Relational Design Specification

**System:** MEDICYCLE — Medicine Intelligence, Safety & Lifecycle Ecosystem  
**Database Name:** `medicycle_db`  
**Engine & Charset:** MySQL 8.0+ / 26.x (InnoDB, `utf8mb4`, Collation: `utf8mb4_unicode_ci`)  
**Target Environment:** macOS Apple Silicon / Local Dedicated MySQL Instance  
**Document Revision:** 2.1 (Phase 2 Comprehensive Enterprise Relational Architecture with Indian CPCB & Global Standards)  

---

## 1. Executive Architecture Summary

MEDICYCLE is a pharmaceutical intelligence, lifecycle monitoring, clinical safety awareness, and sustainable disposal platform. The database serves as the authoritative source of truth for medicine specifications, cold-chain logistics, drug-to-drug interactions, regulatory recalls, ecological toxicity, and barcode/OCR verification workflows.

### 1.1 Architectural Anchors: The Medicine Digital Passport

The relational model is anchored on two core hierarchy tiers:

1. **The Molecule & Product Tier (`medicines`, `ingredients`, `categories`, `manufacturers`):** Represents the abstract pharmacological entity, regulatory identities (NDC, UPC Barcode, CDSCO/FDA registration), active pharmaceutical ingredients (APIs), composition strengths, indications, and baseline storage/disposal rules.
2. **The Physical Lifecycle & Lot Tier (`medicine_batches`, `temperature_monitoring_logs`, `recall_medicines`, `scan_records`, `ocr_extraction_records`, `medicine_disposal_logs`):** Tracks serialized batch production, warehouse-to-patient shelf-life, real-time sensor temperature telemetry, barcode/OCR authenticity scans, lot-level recalls, and verified CPCB/EPA destruction manifests.

```
+----------------------------------------------------------------------------------------------------+
|                                    MEDICYCLE RELATIONAL ANCHORS                                    |
+----------------------------------------------------------------------------------------------------+
|                                                                                                    |
|   [categories] <------+                                                                            |
|                       |                                                                            |
|   [manufacturers] <---+---> [medicines] <----+---> [medicine_batches] <---> [temperature_logs]     |
|                       |        |     |       |          |                                          |
|   [source_references] +        |     |       +---> [recall_medicines] <---> [recall_records]       |
|                       |        |     |       |          |                                          |
|   [ingredients] <-----+--------+     |       +---> [scan_records] <-------> [ocr_extractions]      |
|        ^              |              |       |          |                                          |
|        |              |              |       +---> [disposal_logs] (CPCB / EPA)                    |
|   [drug_interactions] |              |                                                             |
|                       |              +---> [storage_rules]                                         |
|                       |              +---> [disposal_guidelines]                                   |
|                       |              +---> [environmental_impact_records]                           |
|                       |              +---> [safety_alerts]                                         |
|                       |              +---> [side_effects]                                          |
|                       |              +---> [contraindications]                                     |
|                       |              +---> [medicine_uses]                                         |
|                       |                                                                            |
|                       +---> [users] <---> [user_roles] <---> [roles] <---> [role_permissions]      |
|                                |                                                                   |
|                                +---> [audit_logs]                                                  |
+----------------------------------------------------------------------------------------------------+
```

---

## 2. Coverage of the 22 Required Functional Areas

The expanded relational schema addresses all 22 required functional areas without disrupting the existing 19 baseline tables or losing any existing data:

| # | Functional Domain Area | Primary Entities | Status & Architectural Role |
|---|---|---|---|
| **1** | **Medicines** | `medicines` | Core product catalog, dosage forms, routes, NDC codes, UPC barcodes. |
| **2** | **Medicine Categories** | `categories` | WHO ATC classification and therapeutic grouping. |
| **3** | **Manufacturers** | `manufacturers` | Pharmaceutical producers, country of origin, FDA/CDSCO approval status, licensing. |
| **4** | **Ingredients** | `ingredients` | Active Pharmaceutical Ingredients (APIs), CAS numbers, molecular formulas. |
| **5** | **Medicine Compositions** | `medicine_compositions` | Many-to-Many bridge defining ingredient concentrations per medicine unit. |
| **6** | **Medicine Uses** | `medicine_uses` | Approved clinical indications and target pathologies. |
| **7** | **Batches & Expiry Tracking** | `medicine_batches` | Physical production lots, shelf-life boundaries, quarantine/expiry statuses. |
| **8** | **Storage Requirements** | `storage_rules` | Temperature thresholds, refrigeration mandates, humidity & light sensitivities. |
| **9** | **Temperature Monitoring** | `temperature_monitoring_logs` *(Migration 03)* | IoT cold-chain sensor readings, timestamped excursions, and remediation logs. |
| **10** | **Drug Interactions** | `drug_interactions` | Bi-directional API pair matrix with clinical severity, mechanism, and advice. |
| **11** | **Side Effects** | `side_effects` | Documented adverse reactions classified by clinical frequency and severity. |
| **12** | **Contraindications** | `contraindications` | Pathological and physiological prohibitions (Absolute vs Relative). |
| **13** | **Disposal Guidelines** | `disposal_guidelines` | EPA/CPCB protocols (take-back, flush list, household inert mix, hazardous waste). |
| **14** | **Medicine Recalls** | `recall_records` | Regulatory alerts issued by FDA, CDSCO, MHRA, EMA with severity classes I, II, III. |
| **15** | **Recall-Affected Items** | `recall_medicines` | Granular junction supporting product-wide or batch-specific recall attachments. |
| **16** | **Users and Roles** | `users`, `roles`, `permissions`, `user_roles`, `role_permissions` *(Migration 02)* | Multi-tier RBAC preserving `users.role` ENUM while enabling granular capabilities. |
| **17** | **Medicine Scan Records** | `scan_records` | Audit log of physical barcode, QR, and OCR camera scans executed by users. |
| **18** | **OCR Extraction Records** | `ocr_extraction_records` *(Migration 04)* | Structured parser outputs, bounding box geometries, text segment confidences. |
| **19** | **Safety Alerts** | `safety_alerts` | Black box warnings, clinical advisories, and urgent pharmacovigilance notices. |
| **20** | **Environmental Impact** | `environmental_impact_records` *(Migration 05)* | Ecotoxicity metrics: WGK water hazard class, PBT criteria, PNEC, CPCB effluent standards. |
| **21** | **Source References** | `source_references` | Regulatory literature attributions (FDA, DailyMed, WHO EML, EPA, CPCB India). |
| **22** | **Audit Logs** | `audit_logs` | Tamper-evident transaction history capturing table, record, user, IP, and JSON delta. |

---

## 3. Relational Normalization Analysis (1NF through BCNF)

The schema adheres strictly to Boyce-Codd Normal Form (BCNF) principles across all relations, striking an engineering balance between mathematical purity and operational query performance.

### 3.1 First Normal Form (1NF) Compliance
- **Atomic Attributes:** All column values are atomic (scalar). Comma-separated ingredient lists, multi-indication strings, and multi-batch groupings have been decomposed into dedicated junction tables (`medicine_compositions`, `medicine_uses`, `recall_medicines`).
- **Unique Row Identity:** Every relation defines a surrogate or composite Primary Key (`BIGINT UNSIGNED AUTO_INCREMENT` or compound keys).
- **No Repeating Groups:** Multi-valued characteristics (e.g. adverse side effects, contraindications) are stored vertically across distinct rows rather than horizontally across repeating columns (`side_effect_1`, `side_effect_2`).

### 3.2 Second Normal Form (2NF) Compliance
- Every non-key attribute is **fully functionally dependent** on the entire primary key, completely eliminating partial dependencies:
  - In `medicine_compositions (medicine_id, ingredient_id)`, the attributes `strength_value`, `strength_unit`, and `is_active_ingredient` describe the specific combination, not merely the medicine or ingredient independently.
  - In `drug_interactions (ingredient1_id, ingredient2_id)`, the `severity`, `clinical_effect`, and `management_advice` depend strictly on the interactive pair.

### 3.3 Third Normal Form (3NF) Compliance
- Every non-key attribute depends **directly on the primary key** and not through any other non-key attribute (no transitive dependencies):
  - In `medicines`, manufacturer details (`country`, `license_number`, `is_fda_approved`) are not stored inline; rather, a foreign key `manufacturer_id` references `manufacturers`.
  - In `medicines`, therapeutic class descriptions are isolated in `categories` via `category_id`.
  - In `medicine_batches`, drug characteristics (e.g. brand name, dosage form) are not replicated; only the foreign key `medicine_id` is maintained.

### 3.4 Boyce-Codd Normal Form (BCNF) Compliance
- For every non-trivial functional dependency $X \rightarrow Y$, $X$ is a superkey:
  - In `recall_medicines`, the composite uniqueness constraint is enforced on `(recall_id, medicine_id, batch_id)`. The introduction of the surrogate key `recall_medicine_id` prevents nullability anomalies in composite primary keys while preserving strict superkey dependencies.
  - In `storage_rules`, `medicine_id` is designated as `UNIQUE`, ensuring that `medicine_id` acts as a candidate key for temperature and storage tolerances.

---

## 4. Entity Integrity, Referential Integrity & Constraint Rules

### 4.1 Primary Key Strategy
- **Surrogate Numerical Keys:** Standardized on `BIGINT UNSIGNED AUTO_INCREMENT` for high-volume operational and transactional entities (`medicines`, `medicine_batches`, `temperature_monitoring_logs`, `scan_records`, `ocr_extraction_records`, `medicine_disposal_logs`, `audit_logs`).
- **Domain Numerical Keys:** `INT UNSIGNED AUTO_INCREMENT` is utilized for reference catalogs with bounded cardinality (`categories`, `manufacturers`, `ingredients`, `roles`, `permissions`, `schema_migrations`).

### 4.2 Foreign Key Referential Actions
- `ON DELETE RESTRICT / NO ACTION`:
  - Enforced on fundamental clinical master data to prevent accidental cascade destruction:
    - Deleting a `category` or `manufacturer` is blocked if active `medicines` reference it.
    - Deleting an `ingredient` is blocked if referenced in `medicine_compositions` or `drug_interactions`.
    - Deleting a `medicine` is blocked if active `medicine_batches` exist.
- `ON DELETE CASCADE`:
  - Applied to strictly dependent child entities that have no independent clinical existence outside their parent:
    - Deleting a `medicine` cascades to its `medicine_compositions`, `medicine_uses`, `storage_rules`, `side_effects`, `contraindications`, `disposal_guidelines`, `safety_alerts`, and `environmental_impact_records`.
    - Deleting a `scan_record` cascades to its `ocr_extraction_records`.
    - Deleting a `role` cascades to `role_permissions` and `user_roles`.
- `ON DELETE SET NULL`:
  - Utilized for optional regulatory and attribution references (`reference_id`), audit actor links (`changed_by_user_id`, `logged_by_user_id`, `witnessed_by_user_id`), and optional batch attachments (`matched_batch_id`, `batch_id` in `recall_medicines`).

---

## 5. Cold-Chain Excursion & Environmental Scoring Engine

### 5.1 Real-Time Temperature Excursion Evaluation
When IoT telemetry inserts into `temperature_monitoring_logs`, temperature compliance is determined relative to the medicine's defined `storage_rules`:
$$\text{is\_excursion} = \begin{cases} 
\text{TRUE} & \text{if } T_{\text{recorded}} < T_{\text{min}} \lor T_{\text{recorded}} > T_{\text{max}} \\ 
\text{FALSE} & \text{otherwise} 
\end{cases}$$
If an excursion persists beyond `storage_rules.excursion_limit_hours`, downstream systems flag the batch in `medicine_batches` for immediate inspection or quarantine.

### 5.2 Environmental Hazard Classification & Indian CPCB Alignment
Environmental toxicity and pharmaceutical waste disposal conform to both Indian national statutes and international treaties:
1. **India Bio-Medical Waste Management Rules 2016 (Schedule I Yellow Category h):**
   - Mandates that expired, discarded, or contaminated pharmaceuticals must be disposed of via **Common Bio-medical Waste Treatment Facilities (CBWTF)** by high-temperature incineration ($> 1050^\circ\text{C}$ secondary chamber) or encapsulation/inertization.
   - Cytotoxic drugs require specialized yellow-coded leak-proof containers and $> 1200^\circ\text{C}$ incineration.
   - Every consignment requires Form-VI tracking manifests (`cpcb_manifest_number` in `medicine_disposal_logs`).
2. **Indian MoEFCC / CPCB Effluent Standards (GSR 543(E)):**
   - Evaluates active ingredient discharge limits, tracked via `cpcb_effluent_standard_compliant` in `environmental_impact_records`.
3. **Wassergefährdungsklasse (WGK) & REACH Criteria:**
   - Evaluates chemical persistence ($t_{1/2} > 60\text{ days}$ in water), bioaccumulation ($\text{BCF} > 2000$), and aquatic toxicity ($\text{EC}_{50} < 0.1\text{ mg/L}$).
   - Antimicrobial Resistance (AMR) risk: High-risk antibacterials (e.g. Amoxicillin) are marked with `CRITICAL` AMR risk, barring drain disposal.

---

## 6. Hybrid Role-Based Access Control (RBAC) Architecture

To satisfy enterprise authorization requirements without breaking the existing codebase (which inspects `users.role` ENUM), MEDICYCLE adopts a **non-destructive additive RBAC model**:

```
+---------------+           +-------------------+           +---------------+
|     users     | 1       * |    user_roles     | *       1 |     roles     |
|---------------|-----------|-------------------|-----------|---------------|
| user_id (PK)  |           | user_id (FK)      |           | role_id (PK)  |
| username      |           | role_id (FK)      |           | role_name     |
| email         |           | assigned_at       |           | description   |
| password_hash |           +-------------------+           +-------+-------+
| role (ENUM)   |                                                   | 1
| is_active     |                                                   |
+---------------+                                                   | *
                                                            +-------+-------+
                                                            |role_permission|
                                                            +---------------+
                                                            | role_id (FK)  |
                                                            | perm_id (FK)  |
                                                            +-------+-------+
                                                                    | *
                                                                    | 1
                                                            +-------+-------+
                                                            |  permissions  |
                                                            +---------------+
                                                            | perm_id (PK)  |
                                                            | perm_code     |
                                                            | module        |
                                                            +---------------+
```

1. **Backward Compatibility:** `users.role` ENUM remains active and populated with `'ADMIN'`, `'PHARMACIST'`, `'RESEARCHER'`, `'USER'`. Existing application code continues to function seamlessly.
2. **Granular Capabilities:** The new `roles`, `permissions`, `role_permissions`, and `user_roles` tables enable dynamic capability assignment (e.g. `MEDICINE_WRITE`, `RECALL_MANAGE`, `COLD_CHAIN_LOG`, `DISPOSAL_LOG`).
3. **Data Synchronization:** When a user is assigned an ENUM role, an initialization migration automatically links the user to the corresponding record in `roles`.

---

## 7. Storage Engine, Character Set & Indexing Optimization

### 7.1 Engine and Character Set Standards
- **Engine:** `ENGINE=InnoDB` across all tables to guarantee ACID transactions, row-level locking, foreign key constraint enforcement, and crash recovery.
- **Character Set:** `utf8mb4` to support full international pharmacopoeia naming, chemical symbols (e.g. $\alpha, \beta, \Delta$), multilingual instructions, and 4-byte unicode emojis.
- **Collation:** `utf8mb4_unicode_ci` for accent-insensitive, case-insensitive, clinically accurate linguistic sorting.

### 7.2 Strategic Indexing Architecture
1. **Natural Identifier Indexes (B-Tree):**
   - `medicines (barcode_upc)`: Enables $O(\log N)$ instant lookups for point-of-care barcode scanners.
   - `medicines (ndc_number)`: Enables rapid National Drug Code directory matching.
   - `medicine_batches (batch_number)`: Quick retrieval of batch cards during dispensary audits.
   - `recall_records (recall_reference_code)`: Instant search for regulatory recall notices.
2. **Composite Query Indexes:**
   - `medicine_batches (medicine_id, expiry_date, status)`: Accelerates warehouse inventory expiration screening.
   - `temperature_monitoring_logs (batch_id, reading_timestamp DESC)`: Optimizes real-time cold-chain telemetry dashboard graphs.
   - `temperature_monitoring_logs (is_excursion, reading_timestamp)`: Fast indexing for active cold-chain alerts.
   - `audit_logs (table_name, record_id, logged_at)`: Instant audit trail reconstruction for compliance investigations.
3. **Foreign Key Coverage Indexes:**
   - Every foreign key column in every child table is indexed to prevent table-level locks during cascade checks and relational joins.
