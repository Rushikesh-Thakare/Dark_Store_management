# Project Blueprint & Implementation Plan
**Project Name:** Hyper-Local Dark Store Management System

## 1. Technology Stack
*   **Database Hosting:** Supabase (PostgreSQL 15+).
*   **Database Logic:** PL/pgSQL (Functions, Triggers, Views, Row Level Security).
*   **Frontend UI:** React.js (Vite) integrating the `@supabase/supabase-js` client.

## 2. Directory Structure (Antigravity Workspace)
```text
/dark-store-dbms
├── /supabase-sql              # Core database execution scripts
│   ├── 01_schema_ddl.sql      # Postgres tables, keys, and CHECK constraints
│   ├── 02_mock_data.sql       # INSERT statements for sample catalog/zones
│   ├── 03_transactions.sql    # PL/pgSQL functions for atomic order placement
│   ├── 04_triggers.sql        # PL/pgSQL triggers for restock automation
│   ├── 05_views.sql           # Analytical views for the manager dashboard
│   └── 06_rls_security.sql    # Row Level Security (RLS) policies for RBAC
└── /frontend                  # React Dashboard
    ├── src/
    │   ├── supabaseClient.js  # Supabase connection configuration
    │   ├── App.jsx            # Main dashboard container
    │   ├── ManagerView.jsx    # Reads SQL Views & Restock Alerts
    │   ├── RiderView.jsx      # Updates delivery timestamps
    │   └── CustomerView.jsx   # Invokes the Postgres checkout function