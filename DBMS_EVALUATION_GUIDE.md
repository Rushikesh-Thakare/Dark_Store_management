# Database Evaluation & Academic Syllabus Documentation
**Course:** SPIT MDM-26 (M261: Database Management Systems)  
**Project:** Hyper-Local Dark Store Management System (High-Speed Quick-Commerce Inventory & Transaction Engine)  
**Team Members:**  
- Rushikesh Thakare (2026201019)  
- Nikita Dokhale (2026201002)  
- Aashay Kulkarni (2026201009)  
**Department:** Electronics & Telecommunication Engineering, Sardar Patel Institute of Technology, Mumbai  

---

## 1. Schema Design & Normalization Analysis (1NF to BCNF)

The project schema is normalized to **Boyce-Codd Normal Form (BCNF)** across all 10 core entities.

```
                    ┌──────────────┐
                    │    zones     │
                    └──────┬───────┘
                           │ 1:N
           ┌───────────────┴───────────────┐
           ▼                               ▼
    ┌─────────────┐                 ┌─────────────┐
    │ dark_stores │                 │  customers  │
    └──────┬──────┘                 └──────┬──────┘
           │ 1:N                           │ 1:N
     ┌─────┴──────────────┐                │
     ▼                    ▼                │
┌─────────┐         ┌───────────┐          │
│ riders  │         │ inventory │          │
└────┬────┘         └─────▲─────┘          │
     │ 1:N                │ M:N            │
     │              ┌─────┴─────┐          │
     │              │ products  │          │
     │              └─────▲─────┘          │
     │                    │ M:1            │
     │             ┌──────┴───────────┐    │
     │             │product_categories│    │
     │             └──────────────────┘    │
     │                                     │
     └─────────────────┬───────────────────┘
                       ▼
                 ┌───────────┐
                 │  orders   │
                 └─────┬─────┘
                       │ 1:N
                 ┌─────┴───────┐
                 │ order_items │
                 └─────────────┘
```

### Normal Form Breakdown:

### 1. First Normal Form (1NF)
* **Atomicity**: Every column stores single atomic values (no composite structures or comma-delimited items). Multi-item baskets are split into `order_items` rather than stored in `orders`.
* **Unique Identification**: Every table has a well-defined single-column primary key (`zone_id`, `store_id`, `product_id`, `order_id`, etc.).
* **No Repeating Groups**: Product entries and inventory items are recorded as separate rows.

### 2. Second Normal Form (2NF)
* **Pre-requisite**: Relation is in 1NF.
* **Elimination of Partial Dependencies**:
  * In tables with composite candidate keys like `inventory` (candidate key: `store_id, product_id`):
    * Store details (`address`, `manager_name`, `zone_id`) depend solely on `store_id` $\rightarrow$ factored out into `dark_stores`.
    * Product details (`product_name`, `selling_price`, `brand`) depend solely on `product_id` $\rightarrow$ factored out into `products`.
    * Only attributes depending on the **entire composite key** (`current_stock`, `reorder_threshold`, `max_stock_capacity`) remain in `inventory`.
  * In `order_items` (candidate key: `order_id, product_id`):
    * Only `quantity`, `unit_price`, and `line_total` remain, avoiding redundancy of product descriptions or order statuses.

### 3. Third Normal Form (3NF)
* **Pre-requisite**: Relation is in 2NF.
* **Elimination of Transitive Dependencies ($X \rightarrow Y$ and $Y \rightarrow Z$)**:
  * In `products`: Products reference `category_id`. If `category_name` and `category_description` were stored in `products`, then `product_id -> category_id -> category_name` would constitute a transitive dependency. Decomposing into `product_categories(category_id, category_name, description)` satisfies 3NF.
  * In `customers` and `dark_stores`: Both reference `zone_id`. Zone attributes (`zone_name`, `pincode`, `delivery_radius_km`) reside in `zones`, eliminating `customer_id -> zone_id -> pincode` transitivity.

### 4. Boyce-Codd Normal Form (BCNF)
* **Condition**: For every non-trivial functional dependency $X \rightarrow Y$, $X$ must be a superkey.
* In all relations, the determinants are exclusively candidate keys:
  * `zones`: `zone_id` $\rightarrow$ all attributes; `zone_name` $\rightarrow$ all attributes.
  * `dark_stores`: `store_id` $\rightarrow$ all attributes; `(store_name, zone_id)` $\rightarrow$ all attributes.
  * `products`: `product_id` $\rightarrow$ all attributes; `sku_code` $\rightarrow$ all attributes.
  * `inventory`: `inventory_id` $\rightarrow$ all attributes; `(store_id, product_id)` $\rightarrow$ all attributes.
  * `orders`: `order_id` $\rightarrow$ all attributes.
  * `order_items`: `order_item_id` $\rightarrow$ all attributes; `(order_id, product_id)` $\rightarrow$ all attributes.

---

## 2. Lab Experiments Matrix (SPIT M261 Syllabus Mapping)

| Exp No. | Experiment Title | Implementation in Codebase |
| :---: | :--- | :--- |
| **1** | **DDL & Constraints** | `01_schema_ddl.sql`: `PRIMARY KEY`, `FOREIGN KEY (ON DELETE CASCADE/RESTRICT/SET NULL)`, `CHECK (current_stock >= 0)`, `CHECK (selling_price <= mrp)`, `UNIQUE`, `NOT NULL`, `DEFAULT`. |
| **2** | **DML Operations** | `02_mock_data.sql` and `06_dbms_syllabus_experiments.sql`: Comprehensive `INSERT`, `UPDATE`, `DELETE`, and filtered `SELECT` statements with discount percentages. |
| **3** | **Date, Time, Arithmetic & Set Operations** | `05_views.sql` and `06_dbms_syllabus_experiments.sql`: SQL date math with `EXTRACT(EPOCH FROM ...) / 60.0` for 10-minute SLA validation; Set operations: `UNION`, `EXCEPT` for served vs unserved zones. |
| **4** | **Aggregate Functions & GROUP BY / HAVING** | `05_views.sql`: `COUNT(*) FILTER (...)`, `AVG(...)`, `SUM(total_amount)` in `v_manager_live_metrics` and `v_rider_performance`; `HAVING SUM(o.total_amount) >= 500.00`. |
| **5** | **Join Operations** | `06_dbms_syllabus_experiments.sql`: Equi-Joins, `LEFT OUTER JOIN` (stores without riders), Non-Equi Joins (stock threshold ranges), Self-Joins (rider pair assignment), and Cross Joins (cartesian audit matrix). |
| **6** | **Subqueries** | `06_dbms_syllabus_experiments.sql`: Correlated subqueries with `EXISTS` (customers with breached SLAs), Scalar subqueries (products above category average), and `NOT IN` (unpurchased SKUs). |
| **7** | **SQL Views** | `05_views.sql`: 5 operational views (`v_manager_live_metrics`, `v_open_restock_alerts`, `v_rider_performance`, `v_inventory_health`, `v_sla_compliance`). |
| **8** | **Integrity using Triggers** | `04_triggers.sql`: `trg_inventory_restock_check` executing `trg_fn_restock_alert()` on `AFTER UPDATE OF current_stock` to generate restock warnings; auto-resolves alerts upon restock. |
| **9** | **SQL vs NoSQL (MongoDB)** | `06_dbms_syllabus_experiments.sql`: Relational ACID and row locks vs MongoDB JSON document representation, discussing tradeoffs in consistency vs horizontal scaling. |
| **10**| **Database Design & Concurrency** | `03_transactions.sql`: ACID compliance via `SELECT ... FOR UPDATE` (Pessimistic Locking) preventing race conditions, phantom reads, and negative stock overselling. |

---

## 3. Concurrency Control & ACID Transaction Proof

### The Phantom Read / Oversell Problem in Quick-Commerce:
When two customers try to purchase the last available unit of a product simultaneously:
1. Session A reads `current_stock = 1`.
2. Session B reads `current_stock = 1`.
3. Session A updates `current_stock = 0` and confirms order.
4. Session B updates `current_stock = -1` (or fails at delivery).

### PostgreSQL Engine Solution:
```sql
-- Step 1: Pessimistic Row-Level Lock
SELECT inventory_id, current_stock, reorder_threshold
INTO   v_inventory_id, v_current_stock, v_reorder_thresh
FROM   inventory
WHERE  store_id   = p_store_id
  AND  product_id = p_product_id
FOR UPDATE; -- Blocks concurrent checkout transactions on this exact row

-- Step 2: In-Engine Stock Validation
IF v_current_stock < p_quantity THEN
    RAISE EXCEPTION 'Insufficient stock. Requested: %, Available: %', p_quantity, v_current_stock;
END IF;

-- Step 3: Stock Deduction and Order Creation
UPDATE inventory SET current_stock = current_stock - p_quantity WHERE inventory_id = v_inventory_id;
INSERT INTO orders (...) VALUES (...);
INSERT INTO order_items (...) VALUES (...);
```
If anything fails, the entire transaction is rolled back, adhering to **Atomicity, Consistency, Isolation, and Durability (ACID)**.
