# MSB Production Database
## System Architecture Overview

The MSB Production Database connects Light-O-Rama design data, operational inventory tracking, and volunteer workflows into a single system.

The goal is to replace spreadsheets and manual tracking with a centralized operational platform.

---

# System Data Flow

          Light-O-Rama Preview Files
                     │
                     │
                     ▼
            LOR Parsing Script
            (parse_props_v6.py)
                     │
                     │
                     ▼
          SQLite Staging Database
            lor_output_v6.db
                     │
                     │
                     ▼
           PostgreSQL Production DB
        ┌───────────────────────────────┐
        │          Database Schemas     │
        │                               │
        │  lor_snap  → LOR ingestion    │
        │  stage     → spreadsheet data │
        │  ref       → inventory data   │
        │  ops       → operations       │
        └───────────────────────────────┘
                     │
                     │
                     ▼
             Directus Web Interface
                     │
                     │
                     ▼
          Production Volunteers & Managers


---

# Operational Workflows Supported

The system now supports several key production workflows.

### Display Inventory

Tracks all MSB displays including:

• display names  
• stage assignments  
• lighting channel usage  
• estimated light counts

---

### Container Tracking

Manages physical storage containers including:

• container IDs  
• storage locations  
• rack assignments  
• container contents

---

### Container Pull Workflow

Allows production volunteers to:

• pull containers from storage  
• assign work locations  
• begin testing or repair

This replaces manual tracking previously handled through spreadsheets.

---

### Display Testing

Production crews can:

• create testing sessions  
• record display test results  
• flag repair issues

---

### Work Orders

When a problem is identified, a work order can be generated to track:

• repairs required  
• maintenance actions  
• status of repairs

---

### Audit Tracking

All system activity is tracked including:

• who created records  
• who updated records  
• when operational changes occurred

This ensures accountability and traceability across all workflows.

---

# Operational Users

The system is designed for multiple volunteer roles:

Admin  
Managers  
Production Crew  
Browsers

Each role has specific permissions to ensure system integrity.

---

# Current System Status

The system has progressed from architecture design to operational prototype.

Capabilities currently implemented include:

• LOR preview ingestion pipeline  
• normalized display inventory database  
• container tracking system  
• container pull workflow  
• testing session management  
• work order tracking  
• audit logging for operational activity  
• Directus web interface for volunteers

The system is now entering **operational testing with the production team**.

---

# Long-Term Goal

Provide a scalable operational system capable of supporting:

• larger display inventories  
• improved production efficiency  
• reduced manual tracking  
• better repair and maintenance visibility