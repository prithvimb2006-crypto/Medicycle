# MEDICYCLE 💊
### Medicine Intelligence, Safety & Lifecycle Ecosystem

**An intelligent pharmaceutical information platform focused on medicine safety, lifecycle management, and environmental sustainability.**

[![Python](https://img.shields.io/badge/Python-3.11+-blue?logo=python)](https://www.python.org/)
[![Flask](https://img.shields.io/badge/Backend-Flask-black?logo=flask)](https://flask.palletsprojects.com/)
[![MySQL](https://img.shields.io/badge/Database-MySQL-4479A1?logo=mysql)](https://www.mysql.com/)
[![Frontend](https://img.shields.io/badge/Frontend-HTML%20%7C%20CSS%20%7C%20JavaScript-orange)](https://developer.mozilla.org/)

---

## 📌 Overview

MEDICYCLE is a medicine intelligence and lifecycle management platform designed to make pharmaceutical information more accessible, improve medicine safety awareness, and encourage responsible medicine disposal.

The platform brings medicine information, safety monitoring, batch and expiry tracking, recall management, and pharmaceutical database administration together in one application.

Unlike conventional pharmacy management systems, MEDICYCLE focuses on **pharmaceutical intelligence, medicine safety, structured information retrieval, and environmental responsibility.**

## 🎯 Objectives

- Build a centralized pharmaceutical information system.
- Provide structured medicine information and composition details.
- Improve awareness of medicine-related risks and drug interactions.
- Support batch and expiry monitoring.
- Provide information about medicine recalls and safety alerts.
- Encourage environmentally responsible pharmaceutical disposal.
- Implement secure database access and role-based permissions.
- Demonstrate advanced relational database administration concepts.

## ✨ Key Features

### 1. Medicine Intelligence
- Search and browse medicine records.
- View brand and generic names.
- Explore medicine categories, manufacturers, strength, and dosage forms.
- Manage medicine catalogue records.

### 2. Medicine Safety
- Access medicine safety information.
- Review documented side effects and contraindications.
- Support drug interaction awareness through structured medicine data.

### 3. Batch and Expiry Management
- Maintain medicine batch information.
- Track manufacturing and expiry dates.
- Support batch lifecycle monitoring.

### 4. Recall Management
- Maintain pharmaceutical recall records.
- Associate medicines with recall information.
- Support recall-related safety monitoring.

### 5. User Authentication and Authorization
- Secure login and registration.
- Password hashing using bcrypt.
- Session-based authentication.
- Role-Based Access Control (RBAC).
- Admin approval workflow for staff registration.
- Permission-protected API endpoints.

### 6. Admin Management
- View registered users.
- Approve or reject eligible staff accounts.
- Manage medicine catalogue records.
- Create, update, and deactivate medicines.

### 7. Database Intelligence
- Normalized relational database architecture.
- Primary keys and foreign key constraints.
- Database indexes and analytical views.
- Audit logging and database triggers.
- Incremental database migrations.
- Structured reference and demonstration data.

## 🛠️ Technology Stack

| Component | Technologies |
|---|---|
| Frontend | HTML5, CSS3, JavaScript |
| Backend | Python, Flask |
| Database | MySQL |
| Database Connectivity | MySQL Connector/Python |
| Authentication | bcrypt, Flask Sessions |
| API | RESTful APIs |
| Version Control | Git and GitHub |

## 🏗️ System Architecture

```text
             USER / ADMIN
                  |
                  v
          HTML / CSS / JavaScript
                  |
                  v
             Flask Backend
                  |
          REST API Endpoints
                  |
        Authentication & RBAC
                  |
                  v
             MySQL Database
                  |
      +-----------+-----------+
      |           |           |
   Medicines    Safety     Batches
      |           |           |
      +-----------+-----------+
                  |
          Recalls & Audit Logs
```

## 📂 Project Structure

```text
Medicycle/
│
├── backend/
│   ├── app.py
│   ├── config.py
│   ├── database/
│   │   └── connection.py
│   ├── routes/
│   │   ├── auth_routes.py
│   │   ├── medicine_routes.py
│   │   ├── safety_routes.py
│   │   ├── recall_routes.py
│   │   └── batch_routes.py
│   └── utils/
│       └── auth.py
│
├── database/
│   ├── docs/
│   ├── migrations/
│   ├── schema/
│   └── seeds/
│
├── frontend/
│   ├── templates/
│   │   └── index.html
│   └── static/
│       ├── css/
│       │   └── style.css
│       └── js/
│           └── app.js
│
├── tests/
│
├── .env.example
├── .gitignore
├── readme.md
└── requirement.txt
```

## ⚙️ Installation and Setup

### Prerequisites

Install the following:

- Python 3.11 or later
- MySQL Server
- Git
- A web browser

### 1. Clone the repository

```bash
git clone https://github.com/prithvimb2006-crypto/Medicycle.git
cd Medicycle
```

### 2. Create a virtual environment

```bash
python3 -m venv venv
```

Activate it:

**macOS / Linux**
```bash
source venv/bin/activate
```

**Windows**
```bash
venv\Scripts\activate
```

### 3. Install dependencies

```bash
pip install -r requirement.txt
```

### 4. Configure environment variables

Create your local environment file:

```bash
cp .env.example .env
```

Update `.env` with your local MySQL database credentials and the configuration values required by `backend/config.py`.

**Never upload your `.env` file or database passwords to GitHub.**

### 5. Set up the database

Start your MySQL server and create the MEDICYCLE database.

For a fresh installation, execute the SQL files in this order:

1. `database/schema/01_create_database.sql`
2. `database/schema/02_core_schema.sql`
3. Reference and demonstration seed scripts from `database/seeds/`
4. Migration scripts from `database/migrations/`, in numerical order from 01 to 08.

Example:

```bash
mysql -u root -p < database/schema/01_create_database.sql
mysql -u root -p medicycle_db < database/schema/02_core_schema.sql
```

Execute the seed and migration scripts against `medicycle_db` as appropriate.

**Important:** Do not rerun database initialization or migrations on an existing populated database without first checking its migration history and taking a backup.

### 6. Run the application

From the project root:

```bash
python -m backend.app
```

Open your browser:

```text
http://127.0.0.1:5000
```

The application should now be accessible locally.

## 🔐 Security

MEDICYCLE incorporates several security measures:

- bcrypt password hashing.
- Session-based authentication.
- Role-Based Access Control.
- Permission-protected backend routes.
- Environment-based configuration.
- Sensitive local files excluded through `.gitignore`.

## 🗄️ Database Documentation

Detailed database documentation is available in `database/docs/`:

- `database_design.md` — Database architecture and design.
- `entity_relationships.md` — Entity Relationship structure.
- `data_dictionary.md` — Database tables and attributes.

Database migration scripts are available in `database/migrations/`.

## 🧪 Testing

Run the database connection test:

```bash
python tests/test_db_connection.py
```

If pytest is installed, run:

```bash
python -m pytest
```

## 🚀 Future Enhancements

Potential future improvements include:

- OCR-based medicine label recognition.
- Barcode and QR-based medicine identification.
- Advanced drug interaction analysis.
- Real-time cold-chain monitoring using IoT sensors.
- AI-assisted pharmaceutical information retrieval.
- Environmental impact analytics.
- Enhanced medicine digital passports.
- Integration with verified pharmaceutical information sources.

## ⚠️ Disclaimer

MEDICYCLE is an academic software project intended for pharmaceutical information management and educational demonstration.

Information displayed by the system should not replace professional medical advice, diagnosis, or treatment. Users should consult qualified healthcare professionals before making medical decisions.

## 👨‍💻 Project

**MEDICYCLE — Medicine Intelligence, Safety & Lifecycle Ecosystem**

Developed as an academic project focused on Database System Administration, healthcare technology, and pharmaceutical information management.

**GitHub Repository:**  
https://github.com/prithvimb2006-crypto/Medicycle

---

⭐ If you find this project interesting, consider giving the repository a star!
