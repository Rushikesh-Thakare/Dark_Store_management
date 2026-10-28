-- =============================================================================
-- FILE:    06_dbms_syllabus_experiments.sql
-- PROJECT: Hyper-Local Dark Store Management System
-- PURPOSE: Academic DBMS Evaluation Script (SPIT MDM-26 / M261 Syllabus)
-- AUTHORS: Rushikesh Thakare, Aashay Kulkarni, Nikita Dhokale
-- =============================================================================

-- =============================================================================
-- SECTION 1: RELATIONAL SCHEMA NORMALIZATION PROOFS (1NF -> 2NF -> 3NF -> BCNF)
-- =============================================================================
/*
THEORETICAL EVALUATION NOTES FOR EXTERNAL / FACULTY EXAMINER:

1. FIRST NORMAL FORM (1NF):
   - All attribute domains are atomic (e.g., individual item quantities are not stored
     as CSV strings in orders, but separated into `order_items`).
   - Every table has a designated Primary Key (`zone_id`, `product_id`, `order_id`, etc.).
   - No repeating groups.

2. SECOND NORMAL FORM (2NF):
   - The schema is in 1NF.
   - Elimination of Partial Functional Dependencies on composite keys.
   - Example 1: `order_items` composite candidate key is (order_id, product_id).
     Non-prime attributes like product_name, category, brand, and mrp are NOT in
     `order_items`. They reside in `products(product_id)`.
     The only attributes in `order_items` are `quantity`, `unit_price`, and `line_total`,
     which depend on the full composite key (order_id, product_id).
   - Example 2: `inventory` key is (store_id, product_id).
     Store details (`address`, `zone_id`) depend solely on `store_id`, hence extracted to `dark_stores`.
     Product details depend on `product_id`, hence extracted to `products`.

3. THIRD NORMAL FORM (3NF):
   - The schema is in 2NF.
   - Elimination of Transitive Functional Dependencies (X -> Y and Y -> Z where Z is non-prime).
   - In a naive design: `products(product_id, category_name, category_description)`.
     Dependency: `product_id -> category_id -> category_name`.
     Resolution: Decomposed into `products(product_id, category_id, ...)` and
     `product_categories(category_id, category_name, description)`.
   - In `dark_stores` and `customers`: Both reference `zone_id`.
     Zone metadata (`zone_name`, `pincode`, `delivery_radius_km`) is stored in `zones`,
     eliminating `customer_id -> zone_id -> pincode` transitivity.

4. BOYCE-CODD NORMAL FORM (BCNF):
   - For every non-trivial functional dependency X -> Y, X is a Superkey.
   - All functional dependencies across `zones`, `dark_stores`, `products`,
     `product_categories`, `inventory`, `orders`, and `riders` strictly have candidate keys
     as their determinants.
*/

-- =============================================================================
-- SECTION 2: ACADEMIC EXPERIMENT QUERIES (COVERING SYLLABUS EXPERIMENTS 1 TO 8)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- EXPERIMENT 2: DML & Data Retrieval with Complex Filtering
-- -----------------------------------------------------------------------------
-- Find all active products priced under MRP with their profit margin percentage:
SELECT 
    p.product_id,
    p.product_name,
    p.brand,
    pc.category_name,
    p.mrp,
    p.selling_price,
    ROUND(((p.mrp - p.selling_price) / p.mrp) * 100.0, 2) AS discount_pct
FROM products p
JOIN product_categories pc ON pc.category_id = p.category_id
WHERE p.is_active = TRUE AND p.selling_price <= p.mrp
ORDER BY discount_pct DESC;


-- -----------------------------------------------------------------------------
-- EXPERIMENT 3: Date, Time, Arithmetic, and Set Operations
-- -----------------------------------------------------------------------------
-- Part A: Date Arithmetic - Order Fulfillment SLA computation in seconds and minutes
SELECT 
    o.order_id,
    o.customer_id,
    o.status,
    o.placed_at,
    o.delivered_at,
    ROUND(EXTRACT(EPOCH FROM (o.delivered_at - o.placed_at))::NUMERIC, 2) AS duration_seconds,
    ROUND((EXTRACT(EPOCH FROM (o.delivered_at - o.placed_at)) / 60.0)::NUMERIC, 2) AS duration_minutes,
    CASE 
        WHEN EXTRACT(EPOCH FROM (o.delivered_at - o.placed_at)) <= 600 THEN 'MET 10-MIN SLA'
        ELSE 'SLA BREACHED'
    END AS sla_evaluation
FROM orders o
WHERE o.status = 'DELIVERED' AND o.delivered_at IS NOT NULL;

-- Part B: Set Operations (UNION, INTERSECT, EXCEPT)
-- Active zones that have at least one Dark Store UNION zones that have customers:
SELECT zone_id FROM dark_stores WHERE is_active = TRUE
UNION
SELECT zone_id FROM customers WHERE is_active = TRUE;

-- Zones that have customers EXCEPT zones that have dark stores (Unserved Zones):
SELECT zone_id FROM customers
EXCEPT
SELECT zone_id FROM dark_stores;


-- -----------------------------------------------------------------------------
-- EXPERIMENT 4: Aggregate Functions with GROUP BY and HAVING Clause
-- -----------------------------------------------------------------------------
-- Find Dark Stores that have generated more than INR 500 in delivered sales:
SELECT 
    ds.store_id,
    ds.store_name,
    z.zone_name,
    COUNT(o.order_id) AS total_orders_fulfilled,
    ROUND(AVG(o.total_amount), 2) AS avg_order_value_inr,
    SUM(o.total_amount) AS total_revenue_inr
FROM dark_stores ds
JOIN zones z ON z.zone_id = ds.zone_id
JOIN orders o ON o.store_id = ds.store_id
WHERE o.status = 'DELIVERED'
GROUP BY ds.store_id, ds.store_name, z.zone_name
HAVING SUM(o.total_amount) >= 500.00
ORDER BY total_revenue_inr DESC;


-- -----------------------------------------------------------------------------
-- EXPERIMENT 5: SQL Join Operations (Equi, Non-Equi, Self-Join, Outer, Cross)
-- -----------------------------------------------------------------------------
-- 1. Equi-Join & Outer Join (LEFT OUTER JOIN):
-- Dark stores and their assigned riders (including stores with zero riders)
SELECT 
    ds.store_id,
    ds.store_name,
    r.rider_id,
    r.full_name AS rider_name,
    r.status AS rider_status
FROM dark_stores ds
LEFT OUTER JOIN riders r ON r.store_id = ds.store_id
ORDER BY ds.store_id;

-- 2. Non-Equi Join:
-- Matching products to stock reorder severity brackets
SELECT 
    p.product_name,
    i.current_stock,
    i.reorder_threshold,
    bracket.severity_level
FROM inventory i
JOIN products p ON p.product_id = i.product_id
JOIN (
    VALUES 
        (0, 0, 'ZERO STOCK - EMERGENCY'),
        (1, 10, 'CRITICAL RESTOCK'),
        (11, 30, 'MODERATE WARNING')
) AS bracket(min_val, max_val, severity_level)
  ON i.current_stock BETWEEN bracket.min_val AND bracket.max_val;

-- 3. Self-Join:
-- Find pairs of riders working at the same dark store with identical vehicle types
SELECT 
    r1.rider_id AS rider_1_id,
    r1.full_name AS rider_1_name,
    r2.rider_id AS rider_2_id,
    r2.full_name AS rider_2_name,
    r1.store_id,
    r1.vehicle_type
FROM riders r1
JOIN riders r2 
  ON r1.store_id = r2.store_id 
 AND r1.vehicle_type = r2.vehicle_type 
 AND r1.rider_id < r2.rider_id;

-- 4. Cross Join (Cartesian Product):
-- Generate audit matrix of all products across all dark stores
SELECT 
    ds.store_name,
    p.sku_code,
    p.product_name
FROM dark_stores ds
CROSS JOIN products p
LIMIT 20;


-- -----------------------------------------------------------------------------
-- EXPERIMENT 6: Subqueries (Correlated, Non-Correlated, IN, EXISTS, Scalar)
-- -----------------------------------------------------------------------------
-- Part A: Correlated Subquery with EXISTS
-- Find all customers who have placed at least one order that breached the 10-minute SLA:
SELECT 
    c.customer_id,
    c.full_name,
    c.phone
FROM customers c
WHERE EXISTS (
    SELECT 1 
    FROM orders o
    WHERE o.customer_id = c.customer_id
      AND o.status = 'DELIVERED'
      AND EXTRACT(EPOCH FROM (o.delivered_at - o.placed_at)) > 600
);

-- Part B: Scalar Subquery with Comparison Operator
-- Find products whose selling price is strictly higher than the average selling price of their category:
SELECT 
    p.product_name,
    p.category_id,
    p.selling_price,
    ROUND((SELECT AVG(p2.selling_price) FROM products p2 WHERE p2.category_id = p.category_id), 2) AS category_avg_price
FROM products p
WHERE p.selling_price > (
    SELECT AVG(p_sub.selling_price)
    FROM products p_sub
    WHERE p_sub.category_id = p.category_id
);

-- Part C: Subquery with NOT IN
-- Find products that have never been ordered:
SELECT 
    product_id, 
    product_name, 
    sku_code
FROM products
WHERE product_id NOT IN (
    SELECT DISTINCT product_id FROM order_items
);


-- -----------------------------------------------------------------------------
-- EXPERIMENT 9: MongoDB Document Representation (SQL vs NoSQL Mapping)
-- -----------------------------------------------------------------------------
/*
SYLLABUS COMPARISON: Relational Normalization vs. MongoDB Document Model
For an order checkout document in MongoDB:

db.orders.insertOne({
  _id: ObjectId("653fd28a9b1c2d3e4f5a6b7c"),
  order_id: 101,
  placed_at: ISODate("2026-10-25T14:30:00Z"),
  status: "DELIVERED",
  total_amount: 320.00,
  customer: {
    customer_id: 1,
    name: "Aarav Sharma",
    phone: "9800000001",
    zone: "Andheri West"
  },
  store: {
    store_id: 1,
    name: "Bhavan's Campus Hub"
  },
  items: [
    { product_id: 1, sku: "DAI-MILK-AMUL-01", name: "Amul Taaza Milk 500ml", quantity: 2, unit_price: 35.00, line_total: 70.00 },
    { product_id: 4, sku: "SNK-CHIP-LAYS-01", name: "Lay's Classic Salted", quantity: 5, unit_price: 50.00, line_total: 250.00 }
  ],
  delivery_sla: {
    duration_minutes: 8.5,
    on_time: true
  }
});

EVALUATION INSIGHT:
- Relational (RDBMS/Postgres): Guarantees strict ACID consistency, row-level locks on stock deduction (`SELECT ... FOR UPDATE`), and zero data redundancy via 3NF/BCNF.
- Document (NoSQL/MongoDB): Provides denormalized, single-read efficiency for order history, but requires distributed 2-phase commits to update stock across multiple stores safely without race conditions.
*/
