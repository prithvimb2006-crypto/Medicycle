# MEDICYCLE — Medicine Intelligence, Safety & Lifecycle Ecosystem

A comprehensive pharmaceutical intelligence, lifecycle monitoring, safety awareness, and sustainable disposal platform built on a robust MySQL relational database foundation.

---

## 1. Project Directory & Architecture

```text
Medicycle/
├── database/
│   ├── schema/
│   │   ├── 01_create_database.sql   # Database initialization & RBAC user creation
│   │   └── 02_core_schema.sql       # 19 normalized 3NF/BCNF tables with constraints
│   ├── seeds/
│   │   └── 01_reference_seed.sql    # Verified clinical reference seed dataset
│   ├── procedures/                  # Stored procedures (Phase 2)
│   ├── triggers/                    # Audit & safety triggers (Phase 2)
│   ├── views/                       # High-performance reporting views (Phase 2)
│   ├── indexes/                     # Optimized index scripts (Phase 2)
│   └── backups/                     # Database dump scripts
├── backend/
│   ├── app.py                       # Flask entry point (Phase 3)
│   ├── config.py                    # App configuration
│   ├── database/                    # Connection pools & query wrappers
│   ├── routes/                      # Modular API controllers
│   ├── services/                    # Business & pharmaceutical intelligence layer
│   └── uploads/
├── frontend/
│   ├── templates/                   # Jinja2 HTML5 responsive UI views
│   └── static/                      # Custom CSS, JS, and UI assets
├── tests/
│   └── test_db_connection.py        # Database connectivity & integrity test suite
├── .env                             # Local environment credentials (excluded from git)
├── .env.example                     # Environment template
├── .gitignore
├── requirement.txt                  # Python dependencies
└── readme.md
```

---

## 2. Database Environment & Security Isolation

- **MySQL Server:** Local MySQL (Apple Silicon arm64, Homebrew managed)
- **Database Name:** `medicycle_db`
- **Application User:** `medicycle_user`
- **Default Port:** `3306`
- **Charset / Collation:** `utf8mb4` / `utf8mb4_unicode_ci`
- **Role-Based Isolation:** `medicycle_user` has scoped permissions strictly restricted to `medicycle_db.*`. Other existing local databases (e.g., `Flight_assistance`, `skydesk_reservation`) are completely isolated.

---

## 3. Database Execution & Verification

To verify the database connection and relational constraints:

```bash
# Activate virtual environment
source venv/bin/activate

# Run database verification test suite
python tests/test_db_connection.py
```
