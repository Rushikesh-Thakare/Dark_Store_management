# Product Requirements Document (PRD)
**Project Name:** Hyper-Local Dark Store Management System
**Primary Focus:** Database Management System (DBMS) Implementation
**Team:** Rushikesh Thakare, Aashay Kulkarni, Nikita Dhokale

## 1. Project Overview
This project is a backend-heavy database engine simulating the high-concurrency operations of a 10-minute quick-commerce delivery platform (e.g., Zepto, Blinkit). The system focuses on preventing race conditions during checkout, managing multi-location inventory, enforcing data integrity via ACID transactions, and automating operational alerts.

## 2. Scope & Tech Stack Shift
*   **Database Engine:** PostgreSQL (Hosted via Supabase).
*   **API Layer:** Supabase automatically provides a REST API, allowing the team to focus entirely on DBMS logic rather than backend web development.
*   **Frontend UI:** A minimal React dashboard connected directly to the Supabase client.

### In-Scope (DBMS Syllabus Focus)
*   Strictly normalized relational schema (up to BCNF) executed in PostgreSQL.
*   Pessimistic concurrency control (`SELECT ... FOR UPDATE`) to handle simultaneous orders of limited-stock items.
*   Automated inventory monitoring using PL/pgSQL Database Triggers.
*   Managerial analytics via SQL Views.
*   Database Security: Implementing Role-Based Access Control (RBAC) using Supabase's native PostgreSQL Row Level Security (RLS) policies.

### Out of Scope
*   Writing custom Node.js/Express backend APIs.
*   Complex UI animations or customer-facing mobile applications.
*   Real payment gateway integrations.

## 3. User Personas (Database Roles)
1.  **Store Manager (Admin):** Queries real-time SQL Views to monitor active orders, inventory alerts, and delivery SLAs across their specific dark store.
2.  **Delivery Rider (Operational):** Updates order statuses (`DELIVERED`) to stamp exact database timestamps for SLA calculations.
3.  **Customer (Trigger):** Injects concurrent order requests to test PostgreSQL transaction atomicity and row locking.

## 4. Functional Database Requirements
*   **FR-1 (Transactions):** Order processing must be wrapped in a PL/pgSQL function block. If stock deduction fails, the entire transaction rolls back automatically.
*   **FR-2 (Constraints):** The inventory table must enforce a `CHECK (current_stock >= 0)` constraint.
*   **FR-3 (Automation):** A PostgreSQL Trigger must automatically insert a warning record into the `restock_alerts` table exactly when `current_stock` drops below the `reorder_threshold`.
*   **FR-4 (SLA Tracking):** SQL Date arithmetic must calculate the elapsed time between `placed_at` and `delivered_at`.

## 5. Non-Functional Requirements
*   **Data Integrity:** The database must never allow "phantom reads" or overselling.
*   **Direct Database Execution:** Core business logic must run directly on the database engine (via functions and triggers), not on the frontend client.