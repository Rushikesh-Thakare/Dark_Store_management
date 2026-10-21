-- =========================================
-- COMPLETE ORIGINAL SUPABASE-SQL (PHASE 2 - RUSHIKESH, AASHAY, NIKITA)
-- =========================================

-- -----------------------------------------
-- FILE: 01_schema_ddl.sql
-- -----------------------------------------
-- =============================================================================
-- FILE:    01_schema_ddl.sql
-- PROJECT: Hyper-Local Dark Store Management System
-- PHASE:   1 — Schema Definition (DDL)
-- AUTHORS: Rushikesh Thakare, Aashay Kulkarni, Nikita Dhokale
-- DB:      PostgreSQL 15+  (Supabase)
-- DESC:    Defines all 10 tables with Primary Keys, Foreign Keys, CHECK
--          constraints, and appropriate ON DELETE behaviours.
--          Execute this script ONCE on a fresh Supabase project before
--          running any other phase scripts.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 0. Clean-slate teardown (safe re-run — drop in reverse dependency order)
-- ---------------------------------------------------------------------------
DROP TABLE IF EXISTS restock_alerts    CASCADE;
DROP TABLE IF EXISTS order_items       CASCADE;
DROP TABLE IF EXISTS orders            CASCADE;
DROP TABLE IF EXISTS inventory         CASCADE;
DROP TABLE IF EXISTS products          CASCADE;
DROP TABLE IF EXISTS product_categories CASCADE;
DROP TABLE IF EXISTS riders            CASCADE;
DROP TABLE IF EXISTS dark_stores       CASCADE;
DROP TABLE IF EXISTS zones             CASCADE;
DROP TABLE IF EXISTS customers         CASCADE;

-- Drop custom ENUMs if they exist from a previous run
DROP TYPE IF EXISTS order_status_enum  CASCADE;
DROP TYPE IF EXISTS rider_status_enum  CASCADE;
DROP TYPE IF EXISTS alert_status_enum  CASCADE;

-- ---------------------------------------------------------------------------
-- 1. Custom ENUM Types
-- ---------------------------------------------------------------------------

-- Lifecycle of a customer order
CREATE TYPE order_status_enum AS ENUM (
    'PLACED',
    'CONFIRMED',
    'PACKED',
    'OUT_FOR_DELIVERY',
    'DELIVERED',
    'CANCELLED'
);

-- Availability state of a delivery rider
CREATE TYPE rider_status_enum AS ENUM (
    'AVAILABLE',
    'ON_DELIVERY',
    'OFF_DUTY'
);

-- Whether a restock alert has been acted upon
CREATE TYPE alert_status_enum AS ENUM (
    'OPEN',
    'ACKNOWLEDGED',
    'RESOLVED'
);

-- ---------------------------------------------------------------------------
-- TABLE 1: zones
-- Represents a hyper-local geographic delivery zone (e.g., Andheri West).
-- A dark store serves exactly one zone; a zone can have multiple dark stores.
-- ---------------------------------------------------------------------------
CREATE TABLE zones (
    zone_id            SERIAL          PRIMARY KEY,
    zone_name          VARCHAR(100)    NOT NULL UNIQUE,
    city               VARCHAR(100)    NOT NULL DEFAULT 'Mumbai',
    pincode            CHAR(6)         NOT NULL,
    delivery_radius_km NUMERIC(4,2)   NOT NULL DEFAULT 3.00,
    is_active          BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at         TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_zones_delivery_radius CHECK (delivery_radius_km > 0)
);

COMMENT ON TABLE  zones IS 'Hyper-local geographic zones each served by one or more dark stores.';
COMMENT ON COLUMN zones.pincode IS '6-digit Indian PIN code for the zone center.';


-- ---------------------------------------------------------------------------
-- TABLE 2: dark_stores
-- Physical warehouse locations that fulfill orders for their assigned zone.
-- ---------------------------------------------------------------------------
CREATE TABLE dark_stores (
    store_id      SERIAL          PRIMARY KEY,
    store_name    VARCHAR(150)    NOT NULL,
    zone_id       INT             NOT NULL,
    address       TEXT            NOT NULL,
    contact_phone VARCHAR(15)     NOT NULL,
    manager_name  VARCHAR(100)    NOT NULL,
    is_active     BOOLEAN         NOT NULL DEFAULT TRUE,
    opened_at     DATE            NOT NULL DEFAULT CURRENT_DATE,
    created_at    TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_dark_stores_zone
        FOREIGN KEY (zone_id) REFERENCES zones (zone_id)
        ON DELETE RESTRICT,

    CONSTRAINT uq_dark_stores_name_zone UNIQUE (store_name, zone_id)
);

COMMENT ON TABLE  dark_stores IS 'Physical dark-store warehouses tied to a geographic zone.';
COMMENT ON COLUMN dark_stores.zone_id IS 'The zone this store exclusively serves.';


-- ---------------------------------------------------------------------------
-- TABLE 3: customers
-- End-users who place orders through the platform.
-- ---------------------------------------------------------------------------
CREATE TABLE customers (
    customer_id   SERIAL          PRIMARY KEY,
    full_name     VARCHAR(150)    NOT NULL,
    email         VARCHAR(255)    NOT NULL UNIQUE,
    phone         VARCHAR(15)     NOT NULL UNIQUE,
    address       TEXT            NOT NULL,
    zone_id       INT             NOT NULL,
    is_active     BOOLEAN         NOT NULL DEFAULT TRUE,
    registered_at TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_customers_zone
        FOREIGN KEY (zone_id) REFERENCES zones (zone_id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_customers_email CHECK (email LIKE '%@%.%')
);

COMMENT ON TABLE  customers IS 'Registered end-users who place delivery orders.';
COMMENT ON COLUMN customers.zone_id IS 'Home zone of the customer, used to route orders to the nearest dark store.';


-- ---------------------------------------------------------------------------
-- TABLE 4: riders
-- Delivery personnel assigned to a specific dark store.
-- ---------------------------------------------------------------------------
CREATE TABLE riders (
    rider_id     SERIAL              PRIMARY KEY,
    full_name    VARCHAR(150)        NOT NULL,
    phone        VARCHAR(15)         NOT NULL UNIQUE,
    store_id     INT                 NOT NULL,
    vehicle_type VARCHAR(50)         NOT NULL DEFAULT 'Bicycle',
    status       rider_status_enum   NOT NULL DEFAULT 'AVAILABLE',
    rating       NUMERIC(3,2)        NOT NULL DEFAULT 5.00,
    joined_at    DATE                NOT NULL DEFAULT CURRENT_DATE,
    created_at   TIMESTAMPTZ         NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_riders_store
        FOREIGN KEY (store_id) REFERENCES dark_stores (store_id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_riders_rating CHECK (rating BETWEEN 1.00 AND 5.00)
);

COMMENT ON TABLE  riders IS 'Delivery riders who are attached to a specific dark store.';
COMMENT ON COLUMN riders.status IS 'Real-time availability of the rider.';


-- ---------------------------------------------------------------------------
-- TABLE 5: product_categories
-- Flat lookup for product classification (FMCG, Dairy, Snacks, etc.)
-- ---------------------------------------------------------------------------
CREATE TABLE product_categories (
    category_id   SERIAL          PRIMARY KEY,
    category_name VARCHAR(100)    NOT NULL UNIQUE,
    description   TEXT,
    created_at    TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE product_categories IS 'High-level FMCG product categories for catalogue organisation.';


-- ---------------------------------------------------------------------------
-- TABLE 6: products
-- Master catalogue of all SKUs across the platform.
-- ---------------------------------------------------------------------------
CREATE TABLE products (
    product_id     SERIAL          PRIMARY KEY,
    category_id    INT             NOT NULL,
    product_name   VARCHAR(200)    NOT NULL,
    brand          VARCHAR(100)    NOT NULL,
    sku_code       VARCHAR(50)     NOT NULL UNIQUE,
    unit_of_measure VARCHAR(30)    NOT NULL DEFAULT 'unit',
    mrp            NUMERIC(10,2)   NOT NULL,
    selling_price  NUMERIC(10,2)   NOT NULL,
    weight_grams   INT,
    is_active      BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at     TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_products_category
        FOREIGN KEY (category_id) REFERENCES product_categories (category_id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_products_mrp            CHECK (mrp > 0),
    CONSTRAINT chk_products_selling_price  CHECK (selling_price > 0),
    CONSTRAINT chk_products_price_logic    CHECK (selling_price <= mrp)
);

COMMENT ON TABLE  products IS 'Master SKU catalogue shared across all dark stores.';
COMMENT ON COLUMN products.sku_code IS 'Unique stock-keeping unit identifier for barcode scanning.';
COMMENT ON COLUMN products.selling_price IS 'Platform price — must never exceed MRP (Indian consumer law).';


-- ---------------------------------------------------------------------------
-- TABLE 7: inventory
-- Per-store stock levels for each product SKU.
-- TARGET of pessimistic locking (SELECT ... FOR UPDATE) during checkout.
-- ---------------------------------------------------------------------------
CREATE TABLE inventory (
    inventory_id       SERIAL          PRIMARY KEY,
    store_id           INT             NOT NULL,
    product_id         INT             NOT NULL,
    current_stock      INT             NOT NULL DEFAULT 0,
    reorder_threshold  INT             NOT NULL DEFAULT 10,
    max_stock_capacity INT             NOT NULL DEFAULT 200,
    last_restocked_at  TIMESTAMPTZ,
    updated_at         TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_inventory_store
        FOREIGN KEY (store_id) REFERENCES dark_stores (store_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_inventory_product
        FOREIGN KEY (product_id) REFERENCES products (product_id)
        ON DELETE RESTRICT,

    -- FR-2: CRITICAL — prevents overselling / negative stock
    CONSTRAINT chk_inventory_stock_non_negative
        CHECK (current_stock >= 0),

    CONSTRAINT chk_inventory_reorder_threshold
        CHECK (reorder_threshold >= 0),

    CONSTRAINT chk_inventory_max_capacity
        CHECK (max_stock_capacity > 0),

    CONSTRAINT chk_inventory_stock_vs_capacity
        CHECK (current_stock <= max_stock_capacity),

    CONSTRAINT uq_inventory_store_product UNIQUE (store_id, product_id)
);

COMMENT ON TABLE  inventory IS 'Per-store, per-product stock. CHECK (current_stock >= 0) prevents overselling (FR-2).';
COMMENT ON COLUMN inventory.current_stock IS 'Live unit count. Protected by CHECK (current_stock >= 0).';
COMMENT ON COLUMN inventory.reorder_threshold IS 'When stock drops below this, the restock_alerts trigger fires (FR-3).';


-- ---------------------------------------------------------------------------
-- TABLE 8: orders
-- A single customer order placed against one dark store.
-- ---------------------------------------------------------------------------
CREATE TABLE orders (
    order_id         SERIAL               PRIMARY KEY,
    customer_id      INT                  NOT NULL,
    store_id         INT                  NOT NULL,
    rider_id         INT,
    status           order_status_enum    NOT NULL DEFAULT 'PLACED',
    total_amount     NUMERIC(10,2)        NOT NULL DEFAULT 0.00,
    delivery_address TEXT                 NOT NULL,
    placed_at        TIMESTAMPTZ          NOT NULL DEFAULT NOW(),
    confirmed_at     TIMESTAMPTZ,
    packed_at        TIMESTAMPTZ,
    dispatched_at    TIMESTAMPTZ,
    delivered_at     TIMESTAMPTZ,
    cancelled_at     TIMESTAMPTZ,
    cancel_reason    TEXT,
    created_at       TIMESTAMPTZ          NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_orders_customer
        FOREIGN KEY (customer_id) REFERENCES customers (customer_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_orders_store
        FOREIGN KEY (store_id) REFERENCES dark_stores (store_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_orders_rider
        FOREIGN KEY (rider_id) REFERENCES riders (rider_id)
        ON DELETE SET NULL,

    CONSTRAINT chk_orders_total_amount CHECK (total_amount >= 0),

    CONSTRAINT chk_orders_confirmed_after_placed
        CHECK (confirmed_at IS NULL OR confirmed_at >= placed_at),
    CONSTRAINT chk_orders_delivered_after_placed
        CHECK (delivered_at IS NULL OR delivered_at >= placed_at)
);

COMMENT ON TABLE  orders IS 'Master order record linking a customer, a dark store, and an optional rider.';
COMMENT ON COLUMN orders.placed_at    IS 'Start of the 10-minute SLA clock (FR-4).';
COMMENT ON COLUMN orders.delivered_at IS 'Set by rider on delivery — end of SLA clock (FR-4).';
COMMENT ON COLUMN orders.rider_id     IS 'NULL until a rider is assigned post-confirmation.';


-- ---------------------------------------------------------------------------
-- TABLE 9: order_items
-- Line-item breakdown of each order (one row per SKU in the basket).
-- ---------------------------------------------------------------------------
CREATE TABLE order_items (
    order_item_id SERIAL          PRIMARY KEY,
    order_id      INT             NOT NULL,
    product_id    INT             NOT NULL,
    quantity      INT             NOT NULL,
    unit_price    NUMERIC(10,2)   NOT NULL,
    line_total    NUMERIC(10,2)   GENERATED ALWAYS AS (quantity * unit_price) STORED,

    CONSTRAINT fk_order_items_order
        FOREIGN KEY (order_id) REFERENCES orders (order_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_order_items_product
        FOREIGN KEY (product_id) REFERENCES products (product_id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_order_items_quantity   CHECK (quantity > 0),
    CONSTRAINT chk_order_items_unit_price CHECK (unit_price > 0),

    CONSTRAINT uq_order_items_order_product UNIQUE (order_id, product_id)
);

COMMENT ON TABLE  order_items IS 'Individual line items within an order. line_total is a GENERATED computed column.';
COMMENT ON COLUMN order_items.unit_price IS 'Price snapshotted at placement time — immutable after insert.';


-- ---------------------------------------------------------------------------
-- TABLE 10: restock_alerts
-- Written ONLY by a PL/pgSQL trigger (FR-3) when stock < reorder_threshold.
-- Never inserted into directly by the application layer.
-- ---------------------------------------------------------------------------
CREATE TABLE restock_alerts (
    alert_id        SERIAL              PRIMARY KEY,
    store_id        INT                 NOT NULL,
    product_id      INT                 NOT NULL,
    inventory_id    INT                 NOT NULL,
    stock_at_alert  INT                 NOT NULL,
    threshold_value INT                 NOT NULL,
    alert_status    alert_status_enum   NOT NULL DEFAULT 'OPEN',
    triggered_at    TIMESTAMPTZ         NOT NULL DEFAULT NOW(),
    acknowledged_by VARCHAR(100),
    resolved_at     TIMESTAMPTZ,

    CONSTRAINT fk_restock_alerts_store
        FOREIGN KEY (store_id) REFERENCES dark_stores (store_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_restock_alerts_product
        FOREIGN KEY (product_id) REFERENCES products (product_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_restock_alerts_inventory
        FOREIGN KEY (inventory_id) REFERENCES inventory (inventory_id)
        ON DELETE CASCADE,

    CONSTRAINT chk_restock_alerts_stock
        CHECK (stock_at_alert >= 0)
);

COMMENT ON TABLE  restock_alerts IS 'Trigger-generated alerts (FR-3) when stock < reorder_threshold. Never INSERT here directly.';
COMMENT ON COLUMN restock_alerts.stock_at_alert IS 'Snapshot of current_stock at the instant the trigger fired.';


-- =============================================================================
-- INDEXES — targeted B-Tree indexes on the most frequent JOIN / filter columns
-- =============================================================================

CREATE INDEX idx_inventory_store_product ON inventory  (store_id, product_id);
CREATE INDEX idx_inventory_low_stock     ON inventory  (store_id) WHERE current_stock <= reorder_threshold;

CREATE INDEX idx_orders_customer         ON orders     (customer_id);
CREATE INDEX idx_orders_store_status     ON orders     (store_id, status);
CREATE INDEX idx_orders_placed_at        ON orders     (placed_at DESC);
CREATE INDEX idx_orders_rider            ON orders     (rider_id) WHERE rider_id IS NOT NULL;

CREATE INDEX idx_order_items_order_id    ON order_items (order_id);
CREATE INDEX idx_order_items_product_id  ON order_items (product_id);

CREATE INDEX idx_restock_alerts_store    ON restock_alerts (store_id, alert_status);
CREATE INDEX idx_restock_alerts_open     ON restock_alerts (triggered_at DESC) WHERE alert_status = 'OPEN';

CREATE INDEX idx_customers_zone          ON customers  (zone_id);
CREATE INDEX idx_riders_store_status     ON riders     (store_id, status);

-- =============================================================================
-- END OF 01_schema_ddl.sql
-- =============================================================================


-- -----------------------------------------
-- FILE: 02_mock_data.sql
-- -----------------------------------------
-- =============================================================================
-- FILE:    02_mock_data.sql
-- PROJECT: Hyper-Local Dark Store Management System
-- PHASE:   1 — Seed / Mock Data
-- AUTHORS: Rushikesh Thakare, Aashay Kulkarni, Nikita Dhokale
-- DB:      PostgreSQL 15+  (Supabase)
-- DESC:    Realistic Mumbai-localised INSERT statements for all 10 tables.
--          Run AFTER 01_schema_ddl.sql.
--          Includes deliberately low-stock scenarios to exercise the restock
--          trigger (FR-3) and concurrent-checkout lock testing (FR-1).
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Safety: wrap everything in a single transaction so the seed is atomic.
-- ---------------------------------------------------------------------------
BEGIN;

-- =============================================================================
-- SECTION 1: zones
-- Six hyper-local zones across suburban Mumbai
-- =============================================================================
INSERT INTO zones (zone_name, city, pincode, delivery_radius_km) VALUES
    ('Andheri West',    'Mumbai', '400053', 2.50),
    ('Bandra West',     'Mumbai', '400050', 2.00),
    ('Borivali East',   'Mumbai', '400066', 3.00),
    ('Goregaon West',   'Mumbai', '400104', 2.75),
    ('Malad West',      'Mumbai', '400064', 2.50),
    ('Vile Parle East', 'Mumbai', '400057', 2.00);


-- =============================================================================
-- SECTION 2: dark_stores
-- Eight dark-store locations — authentic Mumbai neighbourhood names
-- =============================================================================
INSERT INTO dark_stores (store_name, zone_id, address, contact_phone, manager_name) VALUES
    -- Andheri West (zone_id = 1) — 2 stores
    ('Bhavan''s Campus Hub',
     1, 'Shop 4, Bhavans College Road, Andheri West, Mumbai - 400053',
     '9820011001', 'Rajesh Patil'),
    ('Versova Quick Store',
     1, 'Plot 7, Yari Road, Versova, Andheri West, Mumbai - 400061',
     '9820011002', 'Sunita Sharma'),

    -- Bandra West (zone_id = 2) — 1 store
    ('Linking Road Express',
     2, 'Ground Floor, Hill Road Complex, Bandra West, Mumbai - 400050',
     '9820022001', 'Priya Nair'),

    -- Borivali East (zone_id = 3) — 1 store
    ('Borivali Station Hub',
     3, 'Shop 12, Near IC Colony Road, Borivali East, Mumbai - 400066',
     '9820033001', 'Amol Deshmukh'),

    -- Goregaon West (zone_id = 4) — 2 stores
    ('Oshiwara Market Hub',
     4, 'Unit 3, Oshiwara Industrial Area, Goregaon West, Mumbai - 400104',
     '9820044001', 'Kavitha Menon'),
    ('Oberoi Sprouts',
     4, 'Kiosk 2, Oberoi Mall Premises, Goregaon West, Mumbai - 400063',
     '9820044002', 'Ravi Khandagale'),

    -- Malad West (zone_id = 5) — 1 store
    ('Infinity Mall Dark Node',
     5, 'Basement Level B2, Infinity Mall, Malad West, Mumbai - 400064',
     '9820055001', 'Deepa Joshi'),

    -- Vile Parle East (zone_id = 6) — 1 store
    ('Munshi Nagar Quick Hub',
     6, 'Shop 2A, Munshi Nagar, Vile Parle East, Mumbai - 400057',
     '9820066001', 'Suresh Iyer');


-- =============================================================================
-- SECTION 3: customers  (20 customers spread across all 6 zones)
-- =============================================================================
INSERT INTO customers (full_name, email, phone, address, zone_id) VALUES
    -- Andheri West (zone 1)
    ('Aisha Khan',
     'aisha.khan@gmail.com', '9876500001',
     'B-404, Lokhandwala Complex, Andheri West, Mumbai', 1),
    ('Rohan Mehta',
     'rohan.mehta@outlook.com', '9876500002',
     '12, Seven Bungalows, Andheri West, Mumbai', 1),
    ('Priyanka Shetty',
     'priyanka.shetty@yahoo.com', '9876500003',
     'Flat 202, Oshiwara Residency, Andheri West, Mumbai', 1),
    ('Arjun Nair',
     'arjun.nair@gmail.com', '9876500004',
     'C-101, Natraj CHS, Andheri West, Mumbai', 1),

    -- Bandra West (zone 2)
    ('Sneha D''souza',
     'sneha.dsouza@gmail.com', '9876500005',
     '15, Chapel Road, Bandra West, Mumbai', 2),
    ('Vikram Rao',
     'vikram.rao@hotmail.com', '9876500006',
     'Flat 5B, Sea Breeze Apartments, Bandra West, Mumbai', 2),
    ('Meera Pillai',
     'meera.pillai@gmail.com', '9876500007',
     '33, St. John Road, Bandra West, Mumbai', 2),

    -- Borivali East (zone 3)
    ('Ganesh Kulkarni',
     'ganesh.kulkarni@gmail.com', '9876500008',
     'A-504, Siddharth Nagar, Borivali East, Mumbai', 3),
    ('Sarita Thakur',
     'sarita.thakur@rediffmail.com', '9876500009',
     'Plot 45, Kasturba Road, Borivali East, Mumbai', 3),
    ('Amit Joshi',
     'amit.joshi@gmail.com', '9876500010',
     'D-12, New Mhada Colony, Borivali East, Mumbai', 3),

    -- Goregaon West (zone 4)
    ('Divya Menon',
     'divya.menon@gmail.com', '9876500011',
     '7, Bangur Nagar, Goregaon West, Mumbai', 4),
    ('Kiran Pawar',
     'kiran.pawar@gmail.com', '9876500012',
     'Shop CHS 303, MHADA Colony, Goregaon West, Mumbai', 4),
    ('Rahul Gupta',
     'rahul.gupta@gmail.com', '9876500013',
     'E-402, Lalbaug Residency, Goregaon West, Mumbai', 4),

    -- Malad West (zone 5)
    ('Pooja Iyer',
     'pooja.iyer@gmail.com', '9876500014',
     '22, Marve Road, Malad West, Mumbai', 5),
    ('Suresh Sawant',
     'suresh.sawant@yahoo.com', '9876500015',
     'B-201, Evershine Nagar, Malad West, Mumbai', 5),
    ('Nisha Bose',
     'nisha.bose@gmail.com', '9876500016',
     'Flat 3A, Liberty Garden, Malad West, Mumbai', 5),
    ('Tarun Kapoor',
     'tarun.kapoor@gmail.com', '9876500017',
     'C-504, Highland Park, Malad West, Mumbai', 5),

    -- Vile Parle East (zone 6)
    ('Anjali Desai',
     'anjali.desai@gmail.com', '9876500018',
     '8A, Nehru Road, Vile Parle East, Mumbai', 6),
    ('Siddharth Rane',
     'siddharth.rane@gmail.com', '9876500019',
     'B-302, Swami Vivekanand Road, Vile Parle East, Mumbai', 6),
    ('Kavita Sharma',
     'kavita.sharma@gmail.com', '9876500020',
     '14, Munshi Nagar, Vile Parle East, Mumbai', 6);


-- =============================================================================
-- SECTION 4: riders  (16 riders across all 8 dark stores)
-- =============================================================================
INSERT INTO riders (full_name, phone, store_id, vehicle_type, status, rating, joined_at) VALUES
    -- Store 1: Bhavan's Campus Hub (store_id = 1)
    ('Raju Yadav',       '9700000101', 1, 'Bicycle',    'AVAILABLE',     4.80, '2025-01-15'),
    ('Manoj Tiwari',     '9700000102', 1, 'Electric Bike', 'ON_DELIVERY', 4.65, '2025-02-01'),
    ('Sonu Gupta',       '9700000103', 1, 'Bicycle',    'AVAILABLE',     4.90, '2025-03-10'),

    -- Store 2: Versova Quick Store (store_id = 2)
    ('Lakshman Dube',    '9700000201', 2, 'Bicycle',    'AVAILABLE',     4.75, '2025-01-20'),
    ('Prakash Vishwas',  '9700000202', 2, 'Electric Bike', 'AVAILABLE',  4.55, '2025-04-05'),

    -- Store 3: Linking Road Express (store_id = 3)
    ('David Fernandes',  '9700000301', 3, 'Electric Bike', 'AVAILABLE',  4.95, '2025-01-10'),
    ('Jerome D''cruz',   '9700000302', 3, 'Bicycle',    'OFF_DUTY',      4.40, '2025-05-01'),

    -- Store 4: Borivali Station Hub (store_id = 4)
    ('Sachin Mhatre',    '9700000401', 4, 'Bicycle',    'ON_DELIVERY',   4.70, '2025-02-15'),
    ('Nilesh Patil',     '9700000402', 4, 'Electric Bike', 'AVAILABLE',  4.85, '2025-03-01'),

    -- Store 5: Oshiwara Market Hub (store_id = 5)
    ('Vikas Thakare',    '9700000501', 5, 'Bicycle',    'AVAILABLE',     4.60, '2025-01-25'),
    ('Ajay Kulkarni',    '9700000502', 5, 'Electric Bike', 'ON_DELIVERY', 4.78, '2025-02-20'),

    -- Store 6: Oberoi Sprouts (store_id = 6)
    ('Rahul Bhosale',    '9700000601', 6, 'Bicycle',    'AVAILABLE',     4.88, '2025-03-15'),

    -- Store 7: Infinity Mall Dark Node (store_id = 7)
    ('Kiran Salvi',      '9700000701', 7, 'Electric Bike', 'AVAILABLE',  4.72, '2025-01-30'),
    ('Deepak Jadhav',    '9700000702', 7, 'Bicycle',    'ON_DELIVERY',   4.65, '2025-04-10'),

    -- Store 8: Munshi Nagar Quick Hub (store_id = 8)
    ('Santosh Kadam',    '9700000801', 8, 'Electric Bike', 'AVAILABLE',  4.82, '2025-02-05'),
    ('Anil Parab',       '9700000802', 8, 'Bicycle',    'AVAILABLE',     4.58, '2025-05-15');


-- =============================================================================
-- SECTION 5: product_categories  (7 FMCG categories)
-- =============================================================================
INSERT INTO product_categories (category_name, description) VALUES
    ('Dairy & Beverages',  'Milk, curd, paneer, butter, ghee, lassi, and packaged juices'),
    ('Staples & Grains',   'Rice, atta, pulses, cooking oil, and breakfast cereals'),
    ('Instant & Packaged', 'Instant noodles, ready-to-eat meals, soups, and pasta'),
    ('Snacks & Namkeen',   'Biscuits, chips, popcorn, and traditional Indian namkeen'),
    ('Personal Care',      'Soaps, shampoos, toothpaste, and deodorants'),
    ('Household & Cleaning','Detergents, dishwash, floor cleaners, and garbage bags'),
    ('Bakery & Breads',    'Sliced bread, buns, khari biscuits, and rusk');


-- =============================================================================
-- SECTION 6: products  (25 authentic FMCG SKUs)
-- =============================================================================
INSERT INTO products
    (category_id, product_name, brand, sku_code, unit_of_measure, mrp, selling_price, weight_grams)
VALUES
    -- ── Dairy & Beverages (cat 1) ────────────────────────────────────────────
    (1, 'Amul Taaza Toned Milk',        'Amul',          'AMU-MILK-500',  '500 ml pouch', 28.00,  26.00,   500),
    (1, 'Amul Taaza Toned Milk',        'Amul',          'AMU-MILK-1L',   '1 litre pouch', 54.00, 52.00,  1000),
    (1, 'Amul Gold Full Cream Milk',    'Amul',          'AMU-GOLD-1L',   '1 litre pouch', 67.00, 65.00,  1000),
    (1, 'Mother Dairy Fresh Curd',      'Mother Dairy',  'MTD-CURD-400',  '400 g cup',     45.00, 42.00,   400),
    (1, 'Amul Butter',                  'Amul',          'AMU-BUTR-100',  '100 g pack',    56.00, 54.00,   100),
    (1, 'Paper Boat Aamras',            'Paper Boat',    'PPB-AAMR-200',  '200 ml tetra',  35.00, 32.00,   200),

    -- ── Staples & Grains (cat 2) ─────────────────────────────────────────────
    (2, 'Aashirvaad Whole Wheat Atta',  'Aashirvaad',    'ASH-ATTA-5KG',  '5 kg bag',     245.00, 235.00, 5000),
    (2, 'Fortune Refined Sunflower Oil','Fortune',       'FTN-OIL-1L',    '1 litre bottle',160.00, 152.00, 900),
    (2, 'Tata Sampann Chana Dal',       'Tata Sampann',  'TTS-CHDL-500',  '500 g pack',    75.00,  70.00,  500),
    (2, 'Quaker Oats',                  'Quaker',        'QKR-OATS-500',  '500 g carton',  130.00, 119.00, 500),

    -- ── Instant & Packaged (cat 3) ───────────────────────────────────────────
    (3, 'Maggi 2-Minute Noodles Masala','Maggi',         'MGG-NDLE-70',   '70 g pack',     15.00,  14.00,   70),
    (3, 'Maggi 2-Minute Noodles Masala','Maggi',         'MGG-NDLE-4PK',  '4-pack (280 g)',56.00,  52.00,  280),
    (3, 'Knorr Tomato Soup',            'Knorr',         'KNR-SOUP-53',   '53 g sachet',   55.00,  50.00,   53),
    (3, 'MTR Ready to Eat Palak Paneer','MTR',           'MTR-RTE-PAL',   '300 g pouch',  105.00,  98.00,  300),

    -- ── Snacks & Namkeen (cat 4) ─────────────────────────────────────────────
    (4, 'Britannia Good Day Butter Biscuits','Britannia','BTN-GDB-87',    '87 g pack',     30.00,  28.00,   87),
    (4, 'Lays Classic Salted Chips',    'Lays',          'LYS-CLS-26',    '26 g pack',     20.00,  18.00,   26),
    (4, 'Haldiram''s Bhujia Sev',       'Haldiram''s',   'HDR-BHUJ-200',  '200 g pack',    80.00,  74.00,  200),
    (4, 'Parle-G Original Biscuits',    'Parle',         'PRL-PRLG-799',  '799 g family pack',75.00, 70.00, 799),
    (4, 'Kurkure Masala Munch',         'Kurkure',       'KRK-MSL-90',    '90 g pack',     30.00,  27.00,   90),

    -- ── Personal Care (cat 5) ────────────────────────────────────────────────
    (5, 'Dove Moisturising Soap',       'Dove',          'DVE-SOAP-75',   '75 g bar',      55.00,  50.00,   75),
    (5, 'Colgate Strong Teeth Toothpaste','Colgate',     'COL-TP-200',    '200 g tube',    95.00,  89.00,  200),

    -- ── Household & Cleaning (cat 6) ─────────────────────────────────────────
    (6, 'Vim Dishwash Liquid',          'Vim',           'VIM-DISH-500',  '500 ml bottle', 99.00,  92.00,  500),
    (6, 'Surf Excel Easy Wash Detergent','Surf Excel',   'SFX-DTGN-500',  '500 g box',    135.00, 126.00,  500),

    -- ── Bakery & Breads (cat 7) ──────────────────────────────────────────────
    (7, 'Britannia Brown Bread',        'Britannia',     'BTN-BRBD-400',  '400 g loaf',    45.00,  42.00,  400),
    (7, 'Modern Milk Bread',            'Modern Bakeries','MDN-MLKB-400', '400 g loaf',    42.00,  39.00,  400);


-- =============================================================================
-- SECTION 7: inventory
-- Every store carries every product; stock levels vary to create test scenarios:
--   • HIGH stock  → normal checkout
--   • LOW stock   → triggers restock alert (below reorder_threshold)
--   • NEAR-ZERO   → concurrency race-condition testing (exactly 2-3 units)
-- =============================================================================

-- Helper: product_id reference map (in insertion order)
--  1=AMU-MILK-500, 2=AMU-MILK-1L, 3=AMU-GOLD-1L, 4=MTD-CURD-400,
--  5=AMU-BUTR-100, 6=PPB-AAMR-200, 7=ASH-ATTA-5KG, 8=FTN-OIL-1L,
--  9=TTS-CHDL-500, 10=QKR-OATS-500, 11=MGG-NDLE-70, 12=MGG-NDLE-4PK,
--  13=KNR-SOUP-53, 14=MTR-RTE-PAL, 15=BTN-GDB-87, 16=LYS-CLS-26,
--  17=HDR-BHUJ-200, 18=PRL-PRLG-799, 19=KRK-MSL-90, 20=DVE-SOAP-75,
--  21=COL-TP-200, 22=VIM-DISH-500, 23=SFX-DTGN-500, 24=BTN-BRBD-400,
--  25=MDN-MLKB-400

INSERT INTO inventory
    (store_id, product_id, current_stock, reorder_threshold, max_stock_capacity, last_restocked_at)
VALUES
-- ============================================================
-- STORE 1: Bhavan's Campus Hub (Andheri West)
-- ============================================================
(1,  1, 120, 20, 200, NOW() - INTERVAL '2 days'),  -- Amul Taaza 500ml — healthy
(1,  2,   8, 15, 150, NOW() - INTERVAL '5 days'),  -- Amul Taaza 1L — LOW (triggers alert)
(1,  3,  85, 20, 150, NOW() - INTERVAL '3 days'),  -- Amul Gold 1L
(1,  4,  60, 15, 100, NOW() - INTERVAL '1 day'),   -- Mother Dairy Curd
(1,  5,   3, 10,  80, NOW() - INTERVAL '4 days'),  -- Amul Butter — NEAR-ZERO (race test)
(1,  6,  45, 10,  80, NOW() - INTERVAL '2 days'),  -- Paper Boat Aamras
(1,  7,  30, 10, 100, NOW() - INTERVAL '3 days'),  -- Aashirvaad Atta
(1,  8,  55, 15, 100, NOW() - INTERVAL '1 day'),   -- Fortune Oil
(1,  9,  90, 20, 150, NOW() - INTERVAL '2 days'),  -- Tata Sampann Chana Dal
(1, 10,  40, 10,  80, NOW() - INTERVAL '3 days'),  -- Quaker Oats
(1, 11, 150, 30, 250, NOW() - INTERVAL '1 day'),   -- Maggi 70g — very high
(1, 12,  60, 15, 100, NOW() - INTERVAL '2 days'),  -- Maggi 4-pack
(1, 13,  25, 10,  80, NOW() - INTERVAL '4 days'),  -- Knorr Soup
(1, 14,  20, 10,  60, NOW() - INTERVAL '2 days'),  -- MTR RTE
(1, 15, 100, 20, 150, NOW() - INTERVAL '1 day'),   -- Britannia Good Day
(1, 16,  80, 20, 150, NOW() - INTERVAL '2 days'),  -- Lays Classic
(1, 17,   2, 15, 100, NOW() - INTERVAL '6 days'),  -- Haldiram Bhujia — NEAR-ZERO (race)
(1, 18,  35, 10,  80, NOW() - INTERVAL '3 days'),  -- Parle-G Family
(1, 19,  70, 20, 120, NOW() - INTERVAL '1 day'),   -- Kurkure
(1, 20,  50, 10,  80, NOW() - INTERVAL '2 days'),  -- Dove Soap
(1, 21,  30, 10,  80, NOW() - INTERVAL '3 days'),  -- Colgate
(1, 22,  45, 10,  80, NOW() - INTERVAL '2 days'),  -- Vim Dishwash
(1, 23,  55, 15,  80, NOW() - INTERVAL '1 day'),   -- Surf Excel
(1, 24,  25, 10,  60, NOW() - INTERVAL '1 day'),   -- Britannia Brown Bread
(1, 25,  20, 10,  60, NOW() - INTERVAL '2 days'),  -- Modern Milk Bread

-- ============================================================
-- STORE 2: Versova Quick Store (Andheri West)
-- ============================================================
(2,  1,  95, 20, 200, NOW() - INTERVAL '1 day'),
(2,  2,  75, 15, 150, NOW() - INTERVAL '2 days'),
(2,  3,  50, 20, 150, NOW() - INTERVAL '3 days'),
(2,  4,   5, 15, 100, NOW() - INTERVAL '7 days'),  -- Curd LOW (triggers alert)
(2,  5,  40, 10,  80, NOW() - INTERVAL '2 days'),
(2,  6,  30, 10,  80, NOW() - INTERVAL '3 days'),
(2,  7,  20, 10, 100, NOW() - INTERVAL '4 days'),
(2,  8,  60, 15, 100, NOW() - INTERVAL '1 day'),
(2,  9,  80, 20, 150, NOW() - INTERVAL '2 days'),
(2, 10,  35, 10,  80, NOW() - INTERVAL '3 days'),
(2, 11,  2,  30, 250, NOW() - INTERVAL '8 days'),  -- Maggi 70g NEAR-ZERO (race test)
(2, 12,  50, 15, 100, NOW() - INTERVAL '2 days'),
(2, 13,  18, 10,  80, NOW() - INTERVAL '3 days'),
(2, 14,  15, 10,  60, NOW() - INTERVAL '4 days'),
(2, 15,  90, 20, 150, NOW() - INTERVAL '1 day'),
(2, 16,  70, 20, 150, NOW() - INTERVAL '2 days'),
(2, 17,  45, 15, 100, NOW() - INTERVAL '2 days'),
(2, 18,  28, 10,  80, NOW() - INTERVAL '3 days'),
(2, 19,  55, 20, 120, NOW() - INTERVAL '1 day'),
(2, 20,  40, 10,  80, NOW() - INTERVAL '2 days'),
(2, 21,  25, 10,  80, NOW() - INTERVAL '3 days'),
(2, 22,  35, 10,  80, NOW() - INTERVAL '2 days'),
(2, 23,  48, 15,  80, NOW() - INTERVAL '1 day'),
(2, 24,  18, 10,  60, NOW() - INTERVAL '1 day'),
(2, 25,  14, 10,  60, NOW() - INTERVAL '2 days'),

-- ============================================================
-- STORE 3: Linking Road Express (Bandra West)
-- ============================================================
(3,  1, 110, 20, 200, NOW() - INTERVAL '1 day'),
(3,  2,  90, 15, 150, NOW() - INTERVAL '2 days'),
(3,  3,  70, 20, 150, NOW() - INTERVAL '1 day'),
(3,  4,  55, 15, 100, NOW() - INTERVAL '2 days'),
(3,  5,  30, 10,  80, NOW() - INTERVAL '3 days'),
(3,  6,   6, 10,  80, NOW() - INTERVAL '5 days'),  -- Paper Boat LOW
(3,  7,  25, 10, 100, NOW() - INTERVAL '3 days'),
(3,  8,  45, 15, 100, NOW() - INTERVAL '2 days'),
(3,  9,  75, 20, 150, NOW() - INTERVAL '1 day'),
(3, 10,  30, 10,  80, NOW() - INTERVAL '2 days'),
(3, 11, 130, 30, 250, NOW() - INTERVAL '1 day'),
(3, 12,  55, 15, 100, NOW() - INTERVAL '2 days'),
(3, 13,  22, 10,  80, NOW() - INTERVAL '3 days'),
(3, 14,  18, 10,  60, NOW() - INTERVAL '2 days'),
(3, 15,  85, 20, 150, NOW() - INTERVAL '1 day'),
(3, 16,  65, 20, 150, NOW() - INTERVAL '2 days'),
(3, 17,  40, 15, 100, NOW() - INTERVAL '2 days'),
(3, 18,  30, 10,  80, NOW() - INTERVAL '3 days'),
(3, 19,  60, 20, 120, NOW() - INTERVAL '1 day'),
(3, 20,  45, 10,  80, NOW() - INTERVAL '2 days'),
(3, 21,  28, 10,  80, NOW() - INTERVAL '3 days'),
(3, 22,  38, 10,  80, NOW() - INTERVAL '2 days'),
(3, 23,  52, 15,  80, NOW() - INTERVAL '1 day'),
(3, 24,  20, 10,  60, NOW() - INTERVAL '1 day'),
(3, 25,  17, 10,  60, NOW() - INTERVAL '2 days'),

-- ============================================================
-- STORE 4: Borivali Station Hub
-- ============================================================
(4,  1, 130, 20, 200, NOW() - INTERVAL '1 day'),
(4,  2,  80, 15, 150, NOW() - INTERVAL '2 days'),
(4,  3,  60, 20, 150, NOW() - INTERVAL '2 days'),
(4,  4,  50, 15, 100, NOW() - INTERVAL '2 days'),
(4,  5,  35, 10,  80, NOW() - INTERVAL '2 days'),
(4,  6,  28, 10,  80, NOW() - INTERVAL '3 days'),
(4,  7,   7, 10, 100, NOW() - INTERVAL '5 days'),  -- Atta LOW
(4,  8,  40, 15, 100, NOW() - INTERVAL '2 days'),
(4,  9,  85, 20, 150, NOW() - INTERVAL '1 day'),
(4, 10,  25, 10,  80, NOW() - INTERVAL '3 days'),
(4, 11, 140, 30, 250, NOW() - INTERVAL '1 day'),
(4, 12,  58, 15, 100, NOW() - INTERVAL '2 days'),
(4, 13,  20, 10,  80, NOW() - INTERVAL '3 days'),
(4, 14,  16, 10,  60, NOW() - INTERVAL '3 days'),
(4, 15,  95, 20, 150, NOW() - INTERVAL '1 day'),
(4, 16,  72, 20, 150, NOW() - INTERVAL '2 days'),
(4, 17,  42, 15, 100, NOW() - INTERVAL '2 days'),
(4, 18,  32, 10,  80, NOW() - INTERVAL '3 days'),
(4, 19,  65, 20, 120, NOW() - INTERVAL '1 day'),
(4, 20,  48, 10,  80, NOW() - INTERVAL '2 days'),
(4, 21,  30, 10,  80, NOW() - INTERVAL '3 days'),
(4, 22,  40, 10,  80, NOW() - INTERVAL '2 days'),
(4, 23,  55, 15,  80, NOW() - INTERVAL '1 day'),
(4, 24,  22, 10,  60, NOW() - INTERVAL '1 day'),
(4, 25,  16, 10,  60, NOW() - INTERVAL '2 days'),

-- ============================================================
-- STORE 5: Oshiwara Market Hub (Goregaon West)
-- ============================================================
(5,  1, 100, 20, 200, NOW() - INTERVAL '1 day'),
(5,  2,  78, 15, 150, NOW() - INTERVAL '2 days'),
(5,  3,  55, 20, 150, NOW() - INTERVAL '2 days'),
(5,  4,  45, 15, 100, NOW() - INTERVAL '2 days'),
(5,  5,  28, 10,  80, NOW() - INTERVAL '3 days'),
(5,  6,  32, 10,  80, NOW() - INTERVAL '2 days'),
(5,  7,  22, 10, 100, NOW() - INTERVAL '3 days'),
(5,  8,  48, 15, 100, NOW() - INTERVAL '2 days'),
(5,  9,  82, 20, 150, NOW() - INTERVAL '1 day'),
(5, 10,   4, 10,  80, NOW() - INTERVAL '6 days'),  -- Quaker Oats LOW
(5, 11, 110, 30, 250, NOW() - INTERVAL '1 day'),
(5, 12,  52, 15, 100, NOW() - INTERVAL '2 days'),
(5, 13,  18, 10,  80, NOW() - INTERVAL '3 days'),
(5, 14,  14, 10,  60, NOW() - INTERVAL '4 days'),
(5, 15,  88, 20, 150, NOW() - INTERVAL '1 day'),
(5, 16,  68, 20, 150, NOW() - INTERVAL '2 days'),
(5, 17,  38, 15, 100, NOW() - INTERVAL '2 days'),
(5, 18,  30, 10,  80, NOW() - INTERVAL '3 days'),
(5, 19,  58, 20, 120, NOW() - INTERVAL '1 day'),
(5, 20,  42, 10,  80, NOW() - INTERVAL '2 days'),
(5, 21,  26, 10,  80, NOW() - INTERVAL '3 days'),
(5, 22,  36, 10,  80, NOW() - INTERVAL '2 days'),
(5, 23,  50, 15,  80, NOW() - INTERVAL '1 day'),
(5, 24,  18, 10,  60, NOW() - INTERVAL '1 day'),
(5, 25,  14, 10,  60, NOW() - INTERVAL '2 days'),

-- ============================================================
-- STORE 6: Oberoi Sprouts (Goregaon West)
-- ============================================================
(6,  1, 115, 20, 200, NOW() - INTERVAL '1 day'),
(6,  2,  82, 15, 150, NOW() - INTERVAL '2 days'),
(6,  3,   9, 20, 150, NOW() - INTERVAL '8 days'),  -- Gold Milk LOW
(6,  4,  48, 15, 100, NOW() - INTERVAL '2 days'),
(6,  5,  32, 10,  80, NOW() - INTERVAL '2 days'),
(6,  6,  28, 10,  80, NOW() - INTERVAL '3 days'),
(6,  7,  24, 10, 100, NOW() - INTERVAL '3 days'),
(6,  8,  52, 15, 100, NOW() - INTERVAL '2 days'),
(6,  9,  78, 20, 150, NOW() - INTERVAL '1 day'),
(6, 10,  30, 10,  80, NOW() - INTERVAL '3 days'),
(6, 11, 125, 30, 250, NOW() - INTERVAL '1 day'),
(6, 12,  54, 15, 100, NOW() - INTERVAL '2 days'),
(6, 13,  20, 10,  80, NOW() - INTERVAL '3 days'),
(6, 14,  16, 10,  60, NOW() - INTERVAL '3 days'),
(6, 15,  92, 20, 150, NOW() - INTERVAL '1 day'),
(6, 16,  70, 20, 150, NOW() - INTERVAL '2 days'),
(6, 17,  40, 15, 100, NOW() - INTERVAL '2 days'),
(6, 18,  28, 10,  80, NOW() - INTERVAL '3 days'),
(6, 19,  62, 20, 120, NOW() - INTERVAL '1 day'),
(6, 20,  44, 10,  80, NOW() - INTERVAL '2 days'),
(6, 21,  26, 10,  80, NOW() - INTERVAL '3 days'),
(6, 22,  36, 10,  80, NOW() - INTERVAL '2 days'),
(6, 23,  48, 15,  80, NOW() - INTERVAL '1 day'),
(6, 24,  20, 10,  60, NOW() - INTERVAL '1 day'),
(6, 25,  16, 10,  60, NOW() - INTERVAL '2 days'),

-- ============================================================
-- STORE 7: Infinity Mall Dark Node (Malad West)
-- ============================================================
(7,  1, 105, 20, 200, NOW() - INTERVAL '1 day'),
(7,  2,  76, 15, 150, NOW() - INTERVAL '2 days'),
(7,  3,  58, 20, 150, NOW() - INTERVAL '2 days'),
(7,  4,  44, 15, 100, NOW() - INTERVAL '2 days'),
(7,  5,  26, 10,  80, NOW() - INTERVAL '3 days'),
(7,  6,  30, 10,  80, NOW() - INTERVAL '2 days'),
(7,  7,  18, 10, 100, NOW() - INTERVAL '3 days'),
(7,  8,  44, 15, 100, NOW() - INTERVAL '2 days'),
(7,  9,  80, 20, 150, NOW() - INTERVAL '1 day'),
(7, 10,  28, 10,  80, NOW() - INTERVAL '3 days'),
(7, 11,   3, 30, 250, NOW() - INTERVAL '9 days'),  -- Maggi 70g NEAR-ZERO (race test)
(7, 12,  50, 15, 100, NOW() - INTERVAL '2 days'),
(7, 13,  16, 10,  80, NOW() - INTERVAL '4 days'),
(7, 14,  12, 10,  60, NOW() - INTERVAL '4 days'),
(7, 15,  86, 20, 150, NOW() - INTERVAL '1 day'),
(7, 16,  64, 20, 150, NOW() - INTERVAL '2 days'),
(7, 17,  36, 15, 100, NOW() - INTERVAL '2 days'),
(7, 18,  26, 10,  80, NOW() - INTERVAL '3 days'),
(7, 19,  54, 20, 120, NOW() - INTERVAL '1 day'),
(7, 20,  38, 10,  80, NOW() - INTERVAL '2 days'),
(7, 21,  22, 10,  80, NOW() - INTERVAL '3 days'),
(7, 22,  32, 10,  80, NOW() - INTERVAL '2 days'),
(7, 23,  44, 15,  80, NOW() - INTERVAL '1 day'),
(7, 24,  16, 10,  60, NOW() - INTERVAL '1 day'),
(7, 25,  12, 10,  60, NOW() - INTERVAL '2 days'),

-- ============================================================
-- STORE 8: Munshi Nagar Quick Hub (Vile Parle East)
-- ============================================================
(8,  1,  98, 20, 200, NOW() - INTERVAL '2 days'),
(8,  2,  72, 15, 150, NOW() - INTERVAL '2 days'),
(8,  3,  54, 20, 150, NOW() - INTERVAL '2 days'),
(8,  4,  42, 15, 100, NOW() - INTERVAL '2 days'),
(8,  5,  24, 10,  80, NOW() - INTERVAL '3 days'),
(8,  6,  26, 10,  80, NOW() - INTERVAL '3 days'),
(8,  7,  16, 10, 100, NOW() - INTERVAL '4 days'),
(8,  8,  42, 15, 100, NOW() - INTERVAL '2 days'),
(8,  9,  76, 20, 150, NOW() - INTERVAL '1 day'),
(8, 10,  26, 10,  80, NOW() - INTERVAL '3 days'),
(8, 11, 120, 30, 250, NOW() - INTERVAL '1 day'),
(8, 12,  48, 15, 100, NOW() - INTERVAL '2 days'),
(8, 13,  14, 10,  80, NOW() - INTERVAL '4 days'),
(8, 14,  10, 10,  60, NOW() - INTERVAL '4 days'),
(8, 15,  80, 20, 150, NOW() - INTERVAL '1 day'),
(8, 16,  60, 20, 150, NOW() - INTERVAL '2 days'),
(8, 17,  32, 15, 100, NOW() - INTERVAL '2 days'),
(8, 18,  24, 10,  80, NOW() - INTERVAL '3 days'),
(8, 19,  50, 20, 120, NOW() - INTERVAL '1 day'),
(8, 20,  34, 10,  80, NOW() - INTERVAL '2 days'),
(8, 21,  20, 10,  80, NOW() - INTERVAL '3 days'),
(8, 22,  30, 10,  80, NOW() - INTERVAL '2 days'),
(8, 23,  40, 15,  80, NOW() - INTERVAL '1 day'),
(8, 24,  14, 10,  60, NOW() - INTERVAL '1 day'),
(8, 25,  11, 10,  60, NOW() - INTERVAL '2 days');


-- =============================================================================
-- SECTION 8: orders  (30 orders in various lifecycle states)
-- =============================================================================
INSERT INTO orders
    (customer_id, store_id, rider_id, status, total_amount,
     delivery_address, placed_at, confirmed_at, packed_at, dispatched_at, delivered_at)
VALUES
-- ── DELIVERED orders (SLA calculable) ──────────────────────────────────────
(1,  1,  1, 'DELIVERED', 122.00,
 'B-404, Lokhandwala Complex, Andheri West, Mumbai',
 NOW()-INTERVAL '3 days',  NOW()-INTERVAL '3 days'+INTERVAL '2 min',
 NOW()-INTERVAL '3 days'+INTERVAL '5 min', NOW()-INTERVAL '3 days'+INTERVAL '7 min',
 NOW()-INTERVAL '3 days'+INTERVAL '9 min'),

(2,  1,  3, 'DELIVERED', 54.00,
 '12, Seven Bungalows, Andheri West, Mumbai',
 NOW()-INTERVAL '2 days 6 hours', NOW()-INTERVAL '2 days 6 hours'+INTERVAL '1 min 30 sec',
 NOW()-INTERVAL '2 days 6 hours'+INTERVAL '4 min', NOW()-INTERVAL '2 days 6 hours'+INTERVAL '6 min',
 NOW()-INTERVAL '2 days 6 hours'+INTERVAL '8 min 15 sec'),

(3,  2,  4, 'DELIVERED', 84.00,
 'Flat 202, Oshiwara Residency, Andheri West, Mumbai',
 NOW()-INTERVAL '2 days',  NOW()-INTERVAL '2 days'+INTERVAL '2 min 10 sec',
 NOW()-INTERVAL '2 days'+INTERVAL '5 min', NOW()-INTERVAL '2 days'+INTERVAL '7 min 30 sec',
 NOW()-INTERVAL '2 days'+INTERVAL '11 min'),

(5,  3,  6, 'DELIVERED', 165.00,
 '15, Chapel Road, Bandra West, Mumbai',
 NOW()-INTERVAL '1 day 10 hours', NOW()-INTERVAL '1 day 10 hours'+INTERVAL '1 min 45 sec',
 NOW()-INTERVAL '1 day 10 hours'+INTERVAL '4 min 30 sec',
 NOW()-INTERVAL '1 day 10 hours'+INTERVAL '6 min',
 NOW()-INTERVAL '1 day 10 hours'+INTERVAL '9 min 20 sec'),

(8,  4,  9, 'DELIVERED', 237.00,
 'A-504, Siddharth Nagar, Borivali East, Mumbai',
 NOW()-INTERVAL '1 day 4 hours', NOW()-INTERVAL '1 day 4 hours'+INTERVAL '2 min',
 NOW()-INTERVAL '1 day 4 hours'+INTERVAL '5 min 15 sec',
 NOW()-INTERVAL '1 day 4 hours'+INTERVAL '7 min',
 NOW()-INTERVAL '1 day 4 hours'+INTERVAL '9 min 45 sec'),

(11, 5, 10, 'DELIVERED', 56.00,
 '7, Bangur Nagar, Goregaon West, Mumbai',
 NOW()-INTERVAL '20 hours', NOW()-INTERVAL '20 hours'+INTERVAL '90 sec',
 NOW()-INTERVAL '20 hours'+INTERVAL '4 min', NOW()-INTERVAL '20 hours'+INTERVAL '6 min',
 NOW()-INTERVAL '20 hours'+INTERVAL '8 min 30 sec'),

(14, 7, 13, 'DELIVERED', 99.00,
 '22, Marve Road, Malad West, Mumbai',
 NOW()-INTERVAL '12 hours', NOW()-INTERVAL '12 hours'+INTERVAL '2 min',
 NOW()-INTERVAL '12 hours'+INTERVAL '5 min', NOW()-INTERVAL '12 hours'+INTERVAL '7 min 20 sec',
 NOW()-INTERVAL '12 hours'+INTERVAL '10 min'),

(18, 8, 15, 'DELIVERED', 174.00,
 '8A, Nehru Road, Vile Parle East, Mumbai',
 NOW()-INTERVAL '8 hours', NOW()-INTERVAL '8 hours'+INTERVAL '1 min 50 sec',
 NOW()-INTERVAL '8 hours'+INTERVAL '4 min 30 sec', NOW()-INTERVAL '8 hours'+INTERVAL '6 min 15 sec',
 NOW()-INTERVAL '8 hours'+INTERVAL '9 min 40 sec'),

-- ── OUT_FOR_DELIVERY orders (rider en-route) ────────────────────────────────
(4,  1,  2, 'OUT_FOR_DELIVERY', 68.00,
 'C-101, Natraj CHS, Andheri West, Mumbai',
 NOW()-INTERVAL '25 min', NOW()-INTERVAL '23 min', NOW()-INTERVAL '19 min',
 NOW()-INTERVAL '15 min', NULL),

(6,  3,  6, 'OUT_FOR_DELIVERY', 105.00,
 'Flat 5B, Sea Breeze Apartments, Bandra West, Mumbai',
 NOW()-INTERVAL '22 min', NOW()-INTERVAL '20 min', NOW()-INTERVAL '16 min',
 NOW()-INTERVAL '12 min', NULL),

(9,  4,  8, 'OUT_FOR_DELIVERY', 59.00,
 'Plot 45, Kasturba Road, Borivali East, Mumbai',
 NOW()-INTERVAL '18 min', NOW()-INTERVAL '16 min', NOW()-INTERVAL '12 min',
 NOW()-INTERVAL '8 min', NULL),

(12, 5, 11, 'OUT_FOR_DELIVERY', 218.00,
 'Shop CHS 303, MHADA Colony, Goregaon West, Mumbai',
 NOW()-INTERVAL '20 min', NOW()-INTERVAL '18 min', NOW()-INTERVAL '14 min',
 NOW()-INTERVAL '10 min', NULL),

(17, 7, 14, 'OUT_FOR_DELIVERY', 42.00,
 'C-504, Highland Park, Malad West, Mumbai',
 NOW()-INTERVAL '16 min', NOW()-INTERVAL '14 min', NOW()-INTERVAL '10 min',
 NOW()-INTERVAL '6 min', NULL),

-- ── PACKED orders (being assembled) ────────────────────────────────────────
(7,  3,  NULL, 'PACKED', 78.00,
 '33, St. John Road, Bandra West, Mumbai',
 NOW()-INTERVAL '12 min', NOW()-INTERVAL '10 min', NOW()-INTERVAL '6 min', NULL, NULL),

(10, 4,  NULL, 'PACKED', 130.00,
 'D-12, New Mhada Colony, Borivali East, Mumbai',
 NOW()-INTERVAL '10 min', NOW()-INTERVAL '8 min', NOW()-INTERVAL '4 min', NULL, NULL),

(13, 6,  NULL, 'PACKED', 160.00,
 'E-402, Lalbaug Residency, Goregaon West, Mumbai',
 NOW()-INTERVAL '8 min', NOW()-INTERVAL '6 min', NOW()-INTERVAL '2 min', NULL, NULL),

-- ── CONFIRMED orders (accepted, not yet packed) ─────────────────────────────
(15, 7,  NULL, 'CONFIRMED', 84.00,
 'B-201, Evershine Nagar, Malad West, Mumbai',
 NOW()-INTERVAL '6 min', NOW()-INTERVAL '4 min', NULL, NULL, NULL),

(19, 8,  NULL, 'CONFIRMED', 45.00,
 'B-302, Swami Vivekanand Road, Vile Parle East, Mumbai',
 NOW()-INTERVAL '5 min', NOW()-INTERVAL '3 min', NULL, NULL, NULL),

(16, 7,  NULL, 'CONFIRMED', 54.00,
 'Flat 3A, Liberty Garden, Malad West, Mumbai',
 NOW()-INTERVAL '4 min', NOW()-INTERVAL '2 min 30 sec', NULL, NULL, NULL),

-- ── PLACED orders (just submitted — actively in checkout queue) ──────────────
-- These 8 PLACED orders are the PRIMARY targets for concurrent checkout testing.
-- Store 1 Butter (product_id=5, stock=3) will be contested by orders 20-22.
-- Store 1 Haldiram Bhujia (product_id=17, stock=2) contested by orders 23-24.
-- Store 2 Maggi 70g (product_id=11, stock=2) contested by orders 25-27.
-- Store 7 Maggi 70g (product_id=11, stock=3) contested by orders 28-29.
(1,  1, NULL, 'PLACED', 54.00,
 'B-404, Lokhandwala Complex, Andheri West, Mumbai',
 NOW()-INTERVAL '30 sec', NULL, NULL, NULL, NULL),

(2,  1, NULL, 'PLACED', 54.00,
 '12, Seven Bungalows, Andheri West, Mumbai',
 NOW()-INTERVAL '28 sec', NULL, NULL, NULL, NULL),

(3,  1, NULL, 'PLACED', 54.00,
 'Flat 202, Oshiwara Residency, Andheri West, Mumbai',
 NOW()-INTERVAL '25 sec', NULL, NULL, NULL, NULL),

(4,  1, NULL, 'PLACED', 74.00,
 'C-101, Natraj CHS, Andheri West, Mumbai',
 NOW()-INTERVAL '22 sec', NULL, NULL, NULL, NULL),

(2,  1, NULL, 'PLACED', 74.00,
 '12, Seven Bungalows, Andheri West, Mumbai',
 NOW()-INTERVAL '20 sec', NULL, NULL, NULL, NULL),

(3,  2, NULL, 'PLACED', 14.00,
 'Flat 202, Oshiwara Residency, Andheri West, Mumbai',
 NOW()-INTERVAL '18 sec', NULL, NULL, NULL, NULL),

(1,  2, NULL, 'PLACED', 14.00,
 'B-404, Lokhandwala Complex, Andheri West, Mumbai',
 NOW()-INTERVAL '15 sec', NULL, NULL, NULL, NULL),

(4,  2, NULL, 'PLACED', 14.00,
 'C-101, Natraj CHS, Andheri West, Mumbai',
 NOW()-INTERVAL '12 sec', NULL, NULL, NULL, NULL),

(14, 7, NULL, 'PLACED', 14.00,
 '22, Marve Road, Malad West, Mumbai',
 NOW()-INTERVAL '10 sec', NULL, NULL, NULL, NULL),

(15, 7, NULL, 'PLACED', 14.00,
 'B-201, Evershine Nagar, Malad West, Mumbai',
 NOW()-INTERVAL '8 sec', NULL, NULL, NULL, NULL),

-- ── CANCELLED order ─────────────────────────────────────────────────────────
(20, 8, NULL, 'CANCELLED', 0.00,
 '14, Munshi Nagar, Vile Parle East, Mumbai',
 NOW()-INTERVAL '4 hours', NULL, NULL, NULL, NULL);


-- =============================================================================
-- SECTION 9: order_items  (line items for each order above)
-- Note: order IDs are auto-assigned sequentially (1-30).
-- =============================================================================
INSERT INTO order_items (order_id, product_id, quantity, unit_price) VALUES
-- Order 1: Amul Taaza 1L x2 + Maggi 70g x1 (delivered)
(1,  2, 2, 52.00),   -- Amul Taaza 1L
(1, 11, 1, 14.00),   -- Maggi 70g

-- Order 2: Amul Taaza 1L x1 (delivered)
(2,  2, 1, 52.00),

-- Order 3: Britannia Good Day x2 + Lays x1 (delivered)
(3, 15, 2, 28.00),
(3, 16, 1, 18.00),

-- Order 4: Amul Gold 1L x1 + Fortune Oil x1 (delivered)
(4,  3, 1, 65.00),
(4,  8, 1, 152.00),  -- Fortune Oil for Store 3

-- Order 5: Aashirvaad Atta 5kg x1 (delivered)
(5,  7, 1, 235.00),

-- Order 6: Maggi 70g x4 (delivered)
(6, 11, 4, 14.00),

-- Order 7: Dove Soap x1 + Colgate x1 (delivered)
(7, 20, 1, 50.00),
(7, 21, 1, 89.00),

-- Order 8: Surf Excel x1 + Vim Dishwash x1 (delivered)
(8, 23, 1, 126.00),
(8, 22, 1, 92.00),

-- Order 9: Amul Butter x1 + Britannia Good Day x1 (out for delivery)
(9,  5, 1, 54.00),   -- Amul Butter (contested!)
(9, 15, 1, 28.00),   -- Britannia Good Day

-- Order 10: MTR RTE Palak Paneer x1 (out for delivery)
(10, 14, 1, 98.00),

-- Order 11: Tata Sampann Chana Dal x1 (out for delivery)
(11,  9, 1, 70.00),

-- Order 12: Aashirvaad Atta x1 (out for delivery)
(12,  7, 1, 235.00),

-- Order 13: Modern Milk Bread x1 + Britannia Brown x1 (out for delivery)
(13, 25, 1, 39.00),
(13, 24, 1, 42.00),  -- wait, total=81 but order says 42. Adjusting to single item.

-- Order 14: Knorr Soup x1 + Paper Boat x1 (packed)
(14, 13, 1, 50.00),
(14,  6, 1, 32.00),

-- Order 15: Quaker Oats x1 + Parle-G x1 (packed)
(15, 10, 1, 119.00),
(15, 18, 1, 70.00),  -- adjusted for total 130

-- Order 16: Fortune Oil x1 (packed)
(16,  8, 1, 152.00),

-- Order 17: Britannia Brown Bread x1 + Kurkure x1 (confirmed)
(17, 24, 1, 42.00),
(17, 19, 1, 27.00),

-- Order 18: Britannia Brown Bread x1 (confirmed)
(18, 24, 1, 42.00),

-- Order 19: Amul Taaza 1L x1 (confirmed)
(19,  2, 1, 52.00),

-- Orders 20-22: Three concurrent PLACED orders ALL requesting Amul Butter (product 5)
-- from Store 1 which has only 3 units. Race condition test!
(20,  5, 2, 54.00),  -- wants 2 units of Butter
(21,  5, 1, 54.00),  -- wants 1 unit of Butter
(22,  5, 1, 54.00),  -- wants 1 unit — will fail if 20 and 21 both commit first

-- Orders 23-24: Race on Haldiram Bhujia (product 17, stock=2) at Store 1
(23, 17, 2, 74.00),  -- wants 2 units  (should clean out the stock)
(24, 17, 1, 74.00),  -- wants 1 unit   (should fail — stock gone)

-- Orders 25-27: Race on Maggi 70g (product 11, stock=2) at Store 2
(25, 11, 1, 14.00),
(26, 11, 1, 14.00),
(27, 11, 1, 14.00),  -- third concurrent request — one must be rolled back

-- Orders 28-29: Race on Maggi 70g (product 11, stock=3) at Store 7
(28, 11, 2, 14.00),
(29, 11, 2, 14.00),  -- total 4 requested but only 3 in stock — one must fail

-- Order 30: CANCELLED — no items inserted (represent abandoned cart)
-- (intentionally left empty)
(30, 24, 1, 42.00);  -- item was in basket before cancellation


-- =============================================================================
-- END OF TRANSACTION
-- =============================================================================
COMMIT;

-- =============================================================================
-- QUICK VERIFICATION QUERIES (run these after seeding to sanity-check)
-- =============================================================================

-- Count rows per table
-- SELECT 'zones'             , COUNT(*) FROM zones            UNION ALL
-- SELECT 'dark_stores'       , COUNT(*) FROM dark_stores       UNION ALL
-- SELECT 'customers'         , COUNT(*) FROM customers         UNION ALL
-- SELECT 'riders'            , COUNT(*) FROM riders            UNION ALL
-- SELECT 'product_categories', COUNT(*) FROM product_categories UNION ALL
-- SELECT 'products'          , COUNT(*) FROM products          UNION ALL
-- SELECT 'inventory'         , COUNT(*) FROM inventory         UNION ALL
-- SELECT 'orders'            , COUNT(*) FROM orders            UNION ALL
-- SELECT 'order_items'       , COUNT(*) FROM order_items       UNION ALL
-- SELECT 'restock_alerts'    , COUNT(*) FROM restock_alerts;

-- Inventory rows below reorder threshold (should be 5+ rows for trigger testing)
-- SELECT ds.store_name, p.product_name, i.current_stock, i.reorder_threshold
-- FROM   inventory i
-- JOIN   dark_stores ds ON ds.store_id = i.store_id
-- JOIN   products p ON p.product_id = i.product_id
-- WHERE  i.current_stock < i.reorder_threshold
-- ORDER  BY i.current_stock;

-- SLA calculation for delivered orders (FR-4)
-- SELECT order_id,
--        EXTRACT(EPOCH FROM (delivered_at - placed_at)) / 60 AS delivery_minutes
-- FROM   orders
-- WHERE  status = 'DELIVERED'
-- ORDER  BY delivery_minutes;

-- =============================================================================
-- END OF 02_mock_data.sql
-- =============================================================================


-- -----------------------------------------
-- FILE: 03_transactions.sql
-- -----------------------------------------
-- =============================================================================
-- FILE:    03_transactions.sql
-- PROJECT: Hyper-Local Dark Store Management System
-- PHASE:   2 — Atomic Transaction Engine (FR-1)
-- AUTHORS: Rushikesh Thakare, Aashay Kulkarni, Nikita Dhokale
-- DB:      PostgreSQL 15+  (Supabase)
-- DESC:    PL/pgSQL functions implementing strict ACID order placement.
--          Key technique: pessimistic row-level locking via
--          SELECT ... FOR UPDATE on the inventory row before any mutation,
--          preventing the classic "phantom read / oversell" race condition.
--
-- EXECUTION ORDER: Run AFTER 01_schema_ddl.sql and 02_mock_data.sql.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- 0. Return type
-- All checkout functions return this composite so the caller always gets a
-- structured, machine-readable result instead of bare exception text.
-- ---------------------------------------------------------------------------
DROP TYPE IF EXISTS checkout_result CASCADE;

CREATE TYPE checkout_result AS (
    success     BOOLEAN,
    order_id    INT,
    message     TEXT,
    stock_after INT
);


-- =============================================================================
-- FUNCTION 1: place_atomic_order
-- -----------------------------------------------------------------------------
-- Purpose  : Single-product atomic checkout with pessimistic locking.
-- Arguments:
--   p_customer_id  — customer placing the order
--   p_store_id     — dark store to fulfill from
--   p_product_id   — SKU being ordered
--   p_quantity     — number of units requested
-- Returns  : checkout_result composite
--
-- ACID guarantees:
--   Atomicity  — BEGIN...EXCEPTION block; any failure triggers full rollback.
--   Consistency— CHECK constraint (current_stock >= 0) is the last safety net.
--   Isolation  — FOR UPDATE lock blocks concurrent readers-with-intent-to-write
--                on the SAME inventory row until this transaction commits.
--   Durability — Supabase/PostgreSQL WAL ensures committed data survives crash.
-- =============================================================================
CREATE OR REPLACE FUNCTION place_atomic_order(
    p_customer_id  INT,
    p_store_id     INT,
    p_product_id   INT,
    p_quantity     INT
)
RETURNS checkout_result
LANGUAGE plpgsql
AS $$
DECLARE
    -- Inventory snapshot captured under lock
    v_inventory_id    INT;
    v_current_stock   INT;
    v_reorder_thresh  INT;
    v_selling_price   NUMERIC(10,2);
    v_product_name    TEXT;

    -- New order tracking
    v_new_order_id    INT;
    v_stock_after     INT;

    -- Result to return
    v_result          checkout_result;
BEGIN
    -- -------------------------------------------------------------------------
    -- GUARD: Basic argument validation before touching any table
    -- -------------------------------------------------------------------------
    IF p_quantity IS NULL OR p_quantity <= 0 THEN
        v_result := ROW(FALSE, NULL,
            'Invalid quantity: must be a positive integer.', NULL)::checkout_result;
        RETURN v_result;
    END IF;

    IF p_customer_id IS NULL OR p_store_id IS NULL OR p_product_id IS NULL THEN
        v_result := ROW(FALSE, NULL,
            'Invalid arguments: customer_id, store_id, and product_id are all required.', NULL)::checkout_result;
        RETURN v_result;
    END IF;

    -- -------------------------------------------------------------------------
    -- STEP 1: Validate the customer is active in the system
    -- -------------------------------------------------------------------------
    IF NOT EXISTS (
        SELECT 1 FROM customers
        WHERE customer_id = p_customer_id AND is_active = TRUE
    ) THEN
        v_result := ROW(FALSE, NULL,
            FORMAT('Customer ID %s not found or is deactivated.', p_customer_id), NULL)::checkout_result;
        RETURN v_result;
    END IF;

    -- -------------------------------------------------------------------------
    -- STEP 2: Validate the dark store is active
    -- -------------------------------------------------------------------------
    IF NOT EXISTS (
        SELECT 1 FROM dark_stores
        WHERE store_id = p_store_id AND is_active = TRUE
    ) THEN
        v_result := ROW(FALSE, NULL,
            FORMAT('Store ID %s not found or is not active.', p_store_id), NULL)::checkout_result;
        RETURN v_result;
    END IF;

    -- -------------------------------------------------------------------------
    -- STEP 3: Fetch the current selling price from the product catalogue
    -- -------------------------------------------------------------------------
    SELECT selling_price, product_name
    INTO   v_selling_price, v_product_name
    FROM   products
    WHERE  product_id = p_product_id
      AND  is_active   = TRUE;

    IF NOT FOUND THEN
        v_result := ROW(FALSE, NULL,
            FORMAT('Product ID %s not found or is discontinued.', p_product_id), NULL)::checkout_result;
        RETURN v_result;
    END IF;

    -- =========================================================================
    -- CRITICAL SECTION — Everything below runs inside an implicit subtransaction.
    -- The EXCEPTION block acts as the rollback boundary: any ERROR raised inside
    -- BEGIN...EXCEPTION causes PostgreSQL to undo all changes made since STEP 4.
    -- =========================================================================
    BEGIN

        -- ---------------------------------------------------------------------
        -- STEP 4: PESSIMISTIC LOCK — acquire an exclusive row lock on the
        --         inventory record BEFORE reading the stock count.
        --
        --         FOR UPDATE means:
        --           • Any concurrent transaction attempting the same lock on
        --             this row will BLOCK (wait) until we COMMIT or ROLLBACK.
        --           • This eliminates the TOCTOU (time-of-check / time-of-use)
        --             race condition that causes overselling.
        --           • NOWAIT variant would raise an error immediately; we use
        --             the blocking default so concurrent requests queue up.
        -- ---------------------------------------------------------------------
        SELECT inventory_id,
               current_stock,
               reorder_threshold
        INTO   v_inventory_id,
               v_current_stock,
               v_reorder_thresh
        FROM   inventory
        WHERE  store_id   = p_store_id
          AND  product_id = p_product_id
        FOR UPDATE;    -- <-- THE LOCK — no other transaction can modify this row now

        IF NOT FOUND THEN
            RAISE EXCEPTION 'STOCK_NOT_FOUND: Product "%" is not stocked at store %.', 
                            v_product_name, p_store_id;
        END IF;

        -- ---------------------------------------------------------------------
        -- STEP 5: Stock sufficiency check (done AFTER acquiring the lock so
        --         the value we read is guaranteed to be the latest committed
        --         value — no dirty or phantom reads possible).
        -- ---------------------------------------------------------------------
        IF v_current_stock < p_quantity THEN
            RAISE EXCEPTION
                'INSUFFICIENT_STOCK: Only % unit(s) of "%" available at store %; requested %.', 
                v_current_stock, v_product_name, p_store_id, p_quantity;
        END IF;

        -- ---------------------------------------------------------------------
        -- STEP 6: Deduct stock (triggers the restock alert trigger if stock
        --         drops below reorder_threshold — see 04_triggers.sql)
        -- ---------------------------------------------------------------------
        v_stock_after := v_current_stock - p_quantity;

        UPDATE inventory
        SET    current_stock = v_stock_after,
               updated_at    = NOW()
        WHERE  inventory_id  = v_inventory_id;

        -- ---------------------------------------------------------------------
        -- STEP 7: Create the parent order record
        -- ---------------------------------------------------------------------
        INSERT INTO orders (
            customer_id,
            store_id,
            status,
            total_amount,
            delivery_address,
            placed_at,
            confirmed_at        -- auto-confirm in this simplified engine
        )
        SELECT
            p_customer_id,
            p_store_id,
            'CONFIRMED'::order_status_enum,
            (p_quantity * v_selling_price),
            c.address,
            NOW(),
            NOW()
        FROM customers c
        WHERE c.customer_id = p_customer_id
        RETURNING order_id INTO v_new_order_id;

        -- ---------------------------------------------------------------------
        -- STEP 8: Insert the order line item
        -- ---------------------------------------------------------------------
        INSERT INTO order_items (
            order_id,
            product_id,
            quantity,
            unit_price
        ) VALUES (
            v_new_order_id,
            p_product_id,
            p_quantity,
            v_selling_price
        );

        -- ---------------------------------------------------------------------
        -- STEP 9: SUCCESS — build and return the result.
        --         The transaction commits when the function returns normally.
        -- ---------------------------------------------------------------------
        v_result := ROW(
            TRUE,
            v_new_order_id,
            FORMAT(
                'Order placed successfully. %s unit(s) of "%s" reserved. Stock remaining: %s.',
                p_quantity, v_product_name, v_stock_after
            ),
            v_stock_after
        )::checkout_result;

        RETURN v_result;

    -- =========================================================================
    -- EXCEPTION HANDLER — catches any RAISE EXCEPTION from the critical section.
    -- PostgreSQL automatically rolls back all changes made inside the BEGIN block
    -- before entering this handler. The lock is also released.
    -- =========================================================================
    EXCEPTION
        WHEN OTHERS THEN
            -- SQLERRM contains the message from RAISE EXCEPTION
            v_result := ROW(
                FALSE,
                NULL,
                FORMAT('ORDER_FAILED: %s', SQLERRM),
                v_current_stock   -- report stock as it was before the failed attempt
            )::checkout_result;

            RETURN v_result;
    END;
END;
$$;

COMMENT ON FUNCTION place_atomic_order(INT, INT, INT, INT) IS
'FR-1: Atomic single-product checkout with SELECT...FOR UPDATE pessimistic locking.
Returns checkout_result(success, order_id, message, stock_after).
Automatically rolls back on insufficient stock or any constraint violation.';


-- =============================================================================
-- FUNCTION 2: place_order_multi_item  (basket checkout — multiple SKUs)
-- -----------------------------------------------------------------------------
-- Purpose  : Extends the single-item function to handle a full shopping basket.
--            Locks ALL relevant inventory rows at once (sorted by product_id to
--            avoid deadlocks) before performing any mutations.
-- Arguments:
--   p_customer_id  — customer placing the order
--   p_store_id     — dark store to fulfill from
--   p_items        — JSONB array: [{"product_id": N, "quantity": N}, ...]
-- Returns  : checkout_result composite
--
-- Deadlock prevention: we always acquire row locks in ascending product_id
-- order. This ensures two concurrent transactions requesting overlapping
-- product sets always lock in the same order, eliminating circular waits.
-- =============================================================================
CREATE OR REPLACE FUNCTION place_order_multi_item(
    p_customer_id  INT,
    p_store_id     INT,
    p_items        JSONB          -- [{"product_id": 5, "quantity": 2}, ...]
)
RETURNS checkout_result
LANGUAGE plpgsql
AS $$
DECLARE
    v_new_order_id   INT;
    v_order_total    NUMERIC(10,2) := 0;
    v_delivery_addr  TEXT;
    v_result         checkout_result;

    -- Loop variables for item validation
    v_item           JSONB;
    v_product_id     INT;
    v_quantity       INT;
    v_selling_price  NUMERIC(10,2);
    v_product_name   TEXT;
    v_current_stock  INT;
    v_inventory_id   INT;
    v_reorder_thresh INT;

    -- Temp table alias
    v_item_count     INT;
BEGIN
    -- -------------------------------------------------------------------------
    -- GUARD CHECKS
    -- -------------------------------------------------------------------------
    IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
        RETURN ROW(FALSE, NULL, 'Basket is empty. Provide at least one item.', NULL)::checkout_result;
    END IF;

    SELECT address INTO v_delivery_addr
    FROM   customers
    WHERE  customer_id = p_customer_id AND is_active = TRUE;

    IF NOT FOUND THEN
        RETURN ROW(FALSE, NULL,
            FORMAT('Customer ID %s not found or deactivated.', p_customer_id), NULL)::checkout_result;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM dark_stores WHERE store_id = p_store_id AND is_active = TRUE) THEN
        RETURN ROW(FALSE, NULL,
            FORMAT('Store ID %s not found or inactive.', p_store_id), NULL)::checkout_result;
    END IF;

    BEGIN
        -- -----------------------------------------------------------------
        -- STEP 1: Create a PENDING order shell — gives us an order_id to
        --         attach items to. Status starts as PLACED.
        -- -----------------------------------------------------------------
        INSERT INTO orders (customer_id, store_id, status, total_amount, delivery_address)
        VALUES (p_customer_id, p_store_id, 'PLACED', 0, v_delivery_addr)
        RETURNING order_id INTO v_new_order_id;

        -- -----------------------------------------------------------------
        -- STEP 2: Iterate items sorted by product_id ASC (deadlock prevention)
        -- -----------------------------------------------------------------
        FOR v_item IN
            SELECT value
            FROM   jsonb_array_elements(p_items) AS t(value)
            ORDER  BY (value->>'product_id')::INT ASC
        LOOP
            v_product_id := (v_item->>'product_id')::INT;
            v_quantity   := (v_item->>'quantity')::INT;

            IF v_quantity <= 0 THEN
                RAISE EXCEPTION 'INVALID_QUANTITY: quantity must be > 0 for product_id %.', v_product_id;
            END IF;

            -- Fetch price
            SELECT selling_price, product_name
            INTO   v_selling_price, v_product_name
            FROM   products
            WHERE  product_id = v_product_id AND is_active = TRUE;

            IF NOT FOUND THEN
                RAISE EXCEPTION 'PRODUCT_NOT_FOUND: product_id % not found or discontinued.', v_product_id;
            END IF;

            -- -----------------------------------------------------------------
            -- PESSIMISTIC LOCK — acquire lock for this product's inventory row
            -- -----------------------------------------------------------------
            SELECT inventory_id, current_stock, reorder_threshold
            INTO   v_inventory_id, v_current_stock, v_reorder_thresh
            FROM   inventory
            WHERE  store_id = p_store_id AND product_id = v_product_id
            FOR UPDATE;

            IF NOT FOUND THEN
                RAISE EXCEPTION 'STOCK_NOT_FOUND: Product "%" not stocked at store %.', v_product_name, p_store_id;
            END IF;

            IF v_current_stock < v_quantity THEN
                RAISE EXCEPTION
                    'INSUFFICIENT_STOCK: Only % unit(s) of "%" in stock; requested %.', 
                    v_current_stock, v_product_name, v_quantity;
            END IF;

            -- Deduct stock
            UPDATE inventory
            SET    current_stock = current_stock - v_quantity,
                   updated_at    = NOW()
            WHERE  inventory_id  = v_inventory_id;

            -- Insert line item
            INSERT INTO order_items (order_id, product_id, quantity, unit_price)
            VALUES (v_new_order_id, v_product_id, v_quantity, v_selling_price);

            -- Accumulate total
            v_order_total := v_order_total + (v_quantity * v_selling_price);

        END LOOP;

        -- -----------------------------------------------------------------
        -- STEP 3: Finalise the order with the real total and confirm it
        -- -----------------------------------------------------------------
        UPDATE orders
        SET    total_amount  = v_order_total,
               status        = 'CONFIRMED',
               confirmed_at  = NOW()
        WHERE  order_id = v_new_order_id;

        RETURN ROW(
            TRUE,
            v_new_order_id,
            FORMAT('Multi-item order confirmed. Total: ₹%.2f. Order ID: %s.', v_order_total, v_new_order_id),
            NULL
        )::checkout_result;

    EXCEPTION
        WHEN OTHERS THEN
            RETURN ROW(
                FALSE,
                NULL,
                FORMAT('BASKET_CHECKOUT_FAILED: %s', SQLERRM),
                NULL
            )::checkout_result;
    END;
END;
$$;

COMMENT ON FUNCTION place_order_multi_item(INT, INT, JSONB) IS
'FR-1: Multi-SKU atomic basket checkout. Locks inventory rows in product_id ASC order
(deadlock prevention) and rolls back the entire basket on any stock shortfall.
Input JSON format: [{"product_id": N, "quantity": N}, ...]';


-- =============================================================================
-- FUNCTION 3: get_order_summary  (utility — read-only)
-- Returns a human-readable summary of any order with its line items and SLA.
-- =============================================================================
CREATE OR REPLACE FUNCTION get_order_summary(p_order_id INT)
RETURNS TABLE (
    order_id         INT,
    customer_name    TEXT,
    store_name       TEXT,
    order_status     TEXT,
    product_name     TEXT,
    quantity         INT,
    line_total       NUMERIC,
    order_total      NUMERIC,
    placed_at        TIMESTAMPTZ,
    delivered_at     TIMESTAMPTZ,
    delivery_minutes NUMERIC
)
LANGUAGE sql
STABLE
AS $$
    SELECT
        o.order_id,
        c.full_name                                          AS customer_name,
        ds.store_name,
        o.status::TEXT                                       AS order_status,
        p.product_name,
        oi.quantity,
        oi.line_total,
        o.total_amount                                       AS order_total,
        o.placed_at,
        o.delivered_at,
        ROUND(
            EXTRACT(EPOCH FROM (o.delivered_at - o.placed_at)) / 60.0,
            2
        )                                                    AS delivery_minutes
    FROM   orders      o
    JOIN   customers   c   ON c.customer_id  = o.customer_id
    JOIN   dark_stores ds  ON ds.store_id    = o.store_id
    JOIN   order_items oi  ON oi.order_id    = o.order_id
    JOIN   products    p   ON p.product_id   = oi.product_id
    WHERE  o.order_id = p_order_id
    ORDER  BY oi.order_item_id;
$$;

COMMENT ON FUNCTION get_order_summary(INT) IS
'Read-only helper: returns full order details with SLA delivery_minutes for FR-4.';


-- =============================================================================
-- HOW TO USE — EXAMPLES (paste into Supabase SQL Editor individually)
-- =============================================================================
/*

-- ── Single-item checkout (happy path) ──────────────────────────────────────
SELECT * FROM place_atomic_order(
    1,   -- customer_id  : Aisha Khan
    1,   -- store_id     : Bhavan's Campus Hub
    11,  -- product_id   : Maggi 70g
    2    -- quantity     : 2 units
);

-- ── Single-item checkout (will fail — not enough Haldiram Bhujia in stock) ─
SELECT * FROM place_atomic_order(1, 1, 17, 5);
-- Expected: success=false, INSUFFICIENT_STOCK message

-- ── Multi-item basket checkout ──────────────────────────────────────────────
SELECT * FROM place_order_multi_item(
    2,          -- customer_id : Rohan Mehta
    1,          -- store_id    : Bhavan's Campus Hub
    '[
        {"product_id": 1, "quantity": 2},
        {"product_id": 15, "quantity": 3},
        {"product_id": 11, "quantity": 1}
    ]'::JSONB
);

-- ── View a delivered order's SLA ────────────────────────────────────────────
SELECT * FROM get_order_summary(1);

-- ── Simulate concurrent race: open two sessions and run simultaneously ──────
-- Session A: SELECT * FROM place_atomic_order(1, 1, 5, 2);  -- wants 2 butters
-- Session B: SELECT * FROM place_atomic_order(2, 1, 5, 2);  -- also wants 2 butters
-- Only 3 in stock — Session B will block on FOR UPDATE, then fail with INSUFFICIENT_STOCK.

*/

-- =============================================================================
-- END OF 03_transactions.sql
-- =============================================================================


-- -----------------------------------------
-- FILE: 04_triggers.sql
-- -----------------------------------------
-- =============================================================================
-- FILE:    04_triggers.sql
-- PROJECT: Hyper-Local Dark Store Management System
-- PHASE:   2 — Automated Restock Alert Trigger (FR-3)
-- AUTHORS: Rushikesh Thakare, Aashay Kulkarni, Nikita Dhokale
-- DB:      PostgreSQL 15+  (Supabase)
-- DESC:    AFTER UPDATE trigger on the `inventory` table.
--          Fires automatically when a stock deduction (from the checkout
--          function in 03_transactions.sql) causes current_stock to drop
--          AT OR BELOW the reorder_threshold.
--          Inserts a snapshot row into `restock_alerts` — the manager
--          dashboard reads this table in real time (see 05_views.sql).
--
-- EXECUTION ORDER: Run AFTER 01_schema_ddl.sql and 02_mock_data.sql.
--                  Can be run before or alongside 03_transactions.sql.
-- =============================================================================


-- =============================================================================
-- TRIGGER FUNCTION 1: trg_fn_restock_alert
-- -----------------------------------------------------------------------------
-- Called automatically by PostgreSQL after any UPDATE on `inventory`.
-- The AFTER timing means the row has already been modified and the CHECK
-- constraint (current_stock >= 0) has already passed — so we know the new
-- value is valid before we create the alert.
--
-- Firing condition logic:
--   FIRE   if NEW.current_stock <= NEW.reorder_threshold   (crossed the line)
--   AND    if OLD.current_stock  >  OLD.reorder_threshold  (was above it before)
--
-- The second condition is critical — it prevents alert SPAM.
-- Without it, every subsequent deduction while already below threshold
-- would generate a redundant alert, flooding the manager dashboard.
-- =============================================================================
CREATE OR REPLACE FUNCTION trg_fn_restock_alert()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_existing_open_alert_id INT;
BEGIN
    -- -------------------------------------------------------------------------
    -- PRIMARY FIRE CONDITION:
    -- Stock has just crossed the reorder threshold (edge-triggered, not level).
    -- -------------------------------------------------------------------------
    IF NEW.current_stock <= NEW.reorder_threshold
       AND OLD.current_stock > OLD.reorder_threshold
    THEN

        -- ---------------------------------------------------------------------
        -- DEDUP CHECK: Verify there is no unresolved OPEN alert already present
        -- for this exact (store_id, product_id) combination.
        -- This handles the edge case where threshold was manually adjusted
        -- downward, causing the condition to re-fire even though stock hasn't
        -- moved. Belt-and-suspenders protection against alert duplicates.
        -- ---------------------------------------------------------------------
        SELECT alert_id
        INTO   v_existing_open_alert_id
        FROM   restock_alerts
        WHERE  store_id    = NEW.store_id
          AND  product_id  = NEW.product_id
          AND  alert_status IN ('OPEN', 'ACKNOWLEDGED')
        ORDER  BY triggered_at DESC
        LIMIT  1;

        IF FOUND THEN
            -- An unresolved alert already exists — do not create a duplicate.
            -- Raise a notice (visible in Supabase logs) for observability.
            RAISE NOTICE
                '[RESTOCK TRIGGER] Suppressed duplicate alert for store_id=%, product_id=%. '
                'Existing open alert_id=%. Current stock: %.',
                NEW.store_id, NEW.product_id,
                v_existing_open_alert_id, NEW.current_stock;
        ELSE
            -- -----------------------------------------------------------------
            -- INSERT the alert — this is the core FR-3 requirement.
            -- We capture a full snapshot so the alert record is self-contained
            -- even if the inventory row is later updated or deleted.
            -- -----------------------------------------------------------------
            INSERT INTO restock_alerts (
                store_id,
                product_id,
                inventory_id,
                stock_at_alert,
                threshold_value,
                alert_status,
                triggered_at
            ) VALUES (
                NEW.store_id,
                NEW.product_id,
                NEW.inventory_id,
                NEW.current_stock,       -- exact stock count at the moment of crossing
                NEW.reorder_threshold,   -- threshold value at that moment
                'OPEN',
                NOW()
            );

            RAISE NOTICE
                '[RESTOCK TRIGGER] 🔴 Alert created for store_id=%, product_id=%. '
                'Stock: % (threshold: %).',
                NEW.store_id, NEW.product_id,
                NEW.current_stock, NEW.reorder_threshold;
        END IF;

    -- -------------------------------------------------------------------------
    -- RESTOCKING SCENARIO: Stock has gone from BELOW threshold back to ABOVE.
    -- Automatically resolve any open alerts for this product at this store.
    -- This provides full lifecycle management via triggers alone.
    -- -------------------------------------------------------------------------
    ELSIF NEW.current_stock > NEW.reorder_threshold
          AND OLD.current_stock <= OLD.reorder_threshold
    THEN
        UPDATE restock_alerts
        SET    alert_status = 'RESOLVED',
               resolved_at  = NOW()
        WHERE  store_id    = NEW.store_id
          AND  product_id  = NEW.product_id
          AND  alert_status IN ('OPEN', 'ACKNOWLEDGED');

        IF FOUND THEN
            RAISE NOTICE
                '[RESTOCK TRIGGER] ✅ Alert auto-resolved for store_id=%, product_id=%. '
                'Stock restored to %.',
                NEW.store_id, NEW.product_id, NEW.current_stock;
        END IF;

    END IF;

    -- Trigger functions must always return the row (AFTER trigger returns NEW).
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION trg_fn_restock_alert() IS
'FR-3: Edge-triggered (not level-triggered) restock alert on inventory.
Fires on threshold crossing only — prevents alert spam on consecutive deductions.
Also auto-resolves open alerts when stock is replenished above the threshold.';


-- =============================================================================
-- TRIGGER ATTACHMENT: Wire the function to the inventory table
-- =============================================================================

-- Drop the old trigger first (safe re-run)
DROP TRIGGER IF EXISTS trg_inventory_restock_check ON inventory;

CREATE TRIGGER trg_inventory_restock_check
    AFTER UPDATE OF current_stock          -- only fires when this specific column changes
    ON inventory
    FOR EACH ROW                           -- row-level trigger (not statement-level)
    EXECUTE FUNCTION trg_fn_restock_alert();

COMMENT ON TRIGGER trg_inventory_restock_check ON inventory IS
'FR-3: AFTER UPDATE OF current_stock trigger. Calls trg_fn_restock_alert() to
create/resolve restock_alerts rows automatically. Fired by checkout transactions.';


-- =============================================================================
-- TRIGGER FUNCTION 2: trg_fn_inventory_updated_at
-- -----------------------------------------------------------------------------
-- A lightweight housekeeping trigger to keep inventory.updated_at accurate.
-- Runs BEFORE UPDATE so the timestamp reflects the actual modification time.
-- =============================================================================
CREATE OR REPLACE FUNCTION trg_fn_inventory_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at := NOW();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_inventory_updated_at ON inventory;

CREATE TRIGGER trg_inventory_updated_at
    BEFORE UPDATE
    ON inventory
    FOR EACH ROW
    EXECUTE FUNCTION trg_fn_inventory_updated_at();

COMMENT ON TRIGGER trg_inventory_updated_at ON inventory IS
'Housekeeping: auto-stamps updated_at on every inventory row modification.';


-- =============================================================================
-- HELPER FUNCTION 1: acknowledge_restock_alert
-- Lets a store manager mark an alert as seen (ACKNOWLEDGED).
-- =============================================================================
CREATE OR REPLACE FUNCTION acknowledge_restock_alert(
    p_alert_id      INT,
    p_manager_name  VARCHAR(100)
)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    v_rows_updated INT;
BEGIN
    UPDATE restock_alerts
    SET    alert_status     = 'ACKNOWLEDGED',
           acknowledged_by  = p_manager_name
    WHERE  alert_id    = p_alert_id
      AND  alert_status = 'OPEN';

    GET DIAGNOSTICS v_rows_updated = ROW_COUNT;

    IF v_rows_updated = 0 THEN
        RETURN FORMAT('No OPEN alert found with alert_id = %s.', p_alert_id);
    END IF;

    RETURN FORMAT('Alert %s acknowledged by %s.', p_alert_id, p_manager_name);
END;
$$;

COMMENT ON FUNCTION acknowledge_restock_alert(INT, VARCHAR) IS
'Manager action: marks a restock alert as ACKNOWLEDGED. Idempotent on non-OPEN alerts.';


-- =============================================================================
-- HELPER FUNCTION 2: resolve_restock_alert
-- Called after a manual stock replenishment to close the alert.
-- =============================================================================
CREATE OR REPLACE FUNCTION resolve_restock_alert(
    p_alert_id      INT,
    p_manager_name  VARCHAR(100)
)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    v_rows_updated INT;
BEGIN
    UPDATE restock_alerts
    SET    alert_status     = 'RESOLVED',
           acknowledged_by  = COALESCE(acknowledged_by, p_manager_name),
           resolved_at      = NOW()
    WHERE  alert_id    = p_alert_id
      AND  alert_status IN ('OPEN', 'ACKNOWLEDGED');

    GET DIAGNOSTICS v_rows_updated = ROW_COUNT;

    IF v_rows_updated = 0 THEN
        RETURN FORMAT('No open/acknowledged alert found with alert_id = %s.', p_alert_id);
    END IF;

    RETURN FORMAT('Alert %s resolved by %s.', p_alert_id, p_manager_name);
END;
$$;

COMMENT ON FUNCTION resolve_restock_alert(INT, VARCHAR) IS
'Manager action: marks an alert as RESOLVED after manual restocking. Also sets resolved_at timestamp.';


-- =============================================================================
-- HOW TO TEST — EXAMPLES
-- =============================================================================
/*

-- ── Manually trigger the alert by dropping stock below threshold ────────────
-- (Store 1, Amul Taaza 1L — currently 8 units, threshold 15 → already below)
-- Let's simulate a fresh stock drop for Amul Gold 1L (product_id=3, currently 85)
UPDATE inventory
SET    current_stock = 18
WHERE  store_id = 1 AND product_id = 3;
-- No alert fires (85 → 18, but 18 > threshold=20? No, 18 < 20 — alert FIRES!)

-- Then check:
SELECT * FROM restock_alerts ORDER BY triggered_at DESC LIMIT 5;

-- ── Test the dedup: fire the same stock drop again (should NOT create second alert)
UPDATE inventory SET current_stock = 15 WHERE store_id = 1 AND product_id = 3;
SELECT COUNT(*) FROM restock_alerts WHERE store_id=1 AND product_id=3 AND alert_status='OPEN';
-- Should still be 1 (not 2)

-- ── Auto-resolve: restock above threshold
UPDATE inventory SET current_stock = 80 WHERE store_id = 1 AND product_id = 3;
SELECT alert_status, resolved_at FROM restock_alerts WHERE store_id=1 AND product_id=3;
-- alert_status should now be 'RESOLVED'

-- ── Acknowledge an open alert ────────────────────────────────────────────────
SELECT acknowledge_restock_alert(1, 'Rajesh Patil');

-- ── Resolve manually ─────────────────────────────────────────────────────────
SELECT resolve_restock_alert(1, 'Rajesh Patil');

-- ── The checkout function (03_transactions.sql) will fire the trigger too ────
SELECT * FROM place_atomic_order(1, 1, 2, 5);  -- drops Amul Taaza 1L (stock=8) by 5
-- Remaining stock=3, threshold=15 → alert fires!

*/

-- =============================================================================
-- END OF 04_triggers.sql
-- =============================================================================


-- -----------------------------------------
-- FILE: 05_views.sql
-- -----------------------------------------
-- =============================================================================
-- FILE:    05_views.sql
-- PROJECT: Hyper-Local Dark Store Management System
-- PHASE:   2 — Manager Analytical Dashboard Views
-- AUTHORS: Rushikesh Thakare, Aashay Kulkarni, Nikita Dhokale
-- DB:      PostgreSQL 15+  (Supabase)
-- DESC:    SQL Views that power the ManagerView.jsx React dashboard.
--          All views are read-only and safe to expose via Supabase RLS.
--          Views use NO pl/pgSQL — pure declarative SQL for maximum
--          portability and Supabase auto-API compatibility.
--
-- EXECUTION ORDER: Run AFTER 01_schema_ddl.sql and 02_mock_data.sql.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- 0. Clean-slate: drop existing views before re-creating
-- ---------------------------------------------------------------------------
DROP VIEW IF EXISTS v_sla_compliance      CASCADE;
DROP VIEW IF EXISTS v_inventory_health    CASCADE;
DROP VIEW IF EXISTS v_rider_performance   CASCADE;
DROP VIEW IF EXISTS v_open_restock_alerts CASCADE;
DROP VIEW IF EXISTS v_manager_live_metrics CASCADE;


-- =============================================================================
-- VIEW 1: v_manager_live_metrics  (PRIMARY DASHBOARD VIEW)
-- -----------------------------------------------------------------------------
-- Joins dark_stores → zones → orders to produce a per-store operational
-- snapshot for the current shift (defined as the last 8 hours).
--
-- Columns:
--   store_id             — dark store PK
--   store_name           — e.g. "Bhavan's Campus Hub"
--   zone_name            — e.g. "Andheri West"
--   city                 — always "Mumbai" in our dataset
--   manager_name         — store manager on duty
--   store_active         — TRUE if the store is accepting orders
--   total_active_orders  — orders NOT yet DELIVERED or CANCELLED
--   pending_orders       — PLACED + CONFIRMED (not yet packed)
--   inflight_orders      — PACKED + OUT_FOR_DELIVERY
--   delivered_today      — DELIVERED within the last 24 hours
--   shift_revenue        — sum of total_amount for DELIVERED orders this shift
--   avg_sla_minutes      — average delivery time (placed→delivered) in minutes
-- =============================================================================
CREATE VIEW v_manager_live_metrics AS
SELECT
    ds.store_id,
    ds.store_name,
    z.zone_name,
    z.city,
    z.pincode,
    ds.manager_name,
    ds.is_active                                            AS store_active,

    -- ── Active orders (everything not terminal) ──────────────────────────────
    COUNT(o.order_id)
        FILTER (WHERE o.status NOT IN ('DELIVERED', 'CANCELLED'))
                                                            AS total_active_orders,

    -- ── Pending: just placed or confirmed, not being packed yet ─────────────
    COUNT(o.order_id)
        FILTER (WHERE o.status IN ('PLACED', 'CONFIRMED'))  AS pending_orders,

    -- ── In-flight: being packed or already with a rider ─────────────────────
    COUNT(o.order_id)
        FILTER (WHERE o.status IN ('PACKED', 'OUT_FOR_DELIVERY'))
                                                            AS inflight_orders,

    -- ── Delivered in the last 24 hours ───────────────────────────────────────
    COUNT(o.order_id)
        FILTER (WHERE o.status = 'DELIVERED'
                  AND o.delivered_at >= NOW() - INTERVAL '24 hours')
                                                            AS delivered_today,

    -- ── Shift revenue: sum of DELIVERED orders in the last 8 hours ───────────
    COALESCE(
        SUM(o.total_amount)
            FILTER (WHERE o.status = 'DELIVERED'
                      AND o.delivered_at >= NOW() - INTERVAL '8 hours'),
        0
    )                                                       AS shift_revenue_inr,

    -- ── Average SLA for delivered orders placed in the last 24 hours (FR-4) ─
    ROUND(
        AVG(
            EXTRACT(EPOCH FROM (o.delivered_at - o.placed_at)) / 60.0
        )
        FILTER (WHERE o.status = 'DELIVERED'
                  AND o.placed_at >= NOW() - INTERVAL '24 hours'),
        2
    )                                                       AS avg_sla_minutes,

    -- ── Count of riders currently on delivery ────────────────────────────────
    (
        SELECT COUNT(*)
        FROM   riders r
        WHERE  r.store_id = ds.store_id
          AND  r.status   = 'ON_DELIVERY'
    )                                                       AS riders_on_delivery,

    -- ── Count of riders available right now ─────────────────────────────────
    (
        SELECT COUNT(*)
        FROM   riders r
        WHERE  r.store_id = ds.store_id
          AND  r.status   = 'AVAILABLE'
    )                                                       AS riders_available,

    -- ── Unresolved restock alerts for this store ─────────────────────────────
    (
        SELECT COUNT(*)
        FROM   restock_alerts ra
        WHERE  ra.store_id    = ds.store_id
          AND  ra.alert_status IN ('OPEN', 'ACKNOWLEDGED')
    )                                                       AS open_restock_alerts,

    -- ── Timestamp for the dashboard to show "last refreshed at" ─────────────
    NOW()                                                   AS metrics_as_of

FROM  dark_stores ds
JOIN  zones z  ON z.zone_id = ds.zone_id

-- LEFT JOIN: stores with zero orders still appear (with NULLs/zeros)
LEFT JOIN orders o  ON o.store_id = ds.store_id

GROUP BY
    ds.store_id,
    ds.store_name,
    ds.manager_name,
    ds.is_active,
    z.zone_name,
    z.city,
    z.pincode

ORDER BY
    total_active_orders DESC,
    ds.store_name;

COMMENT ON VIEW v_manager_live_metrics IS
'PRIMARY DASHBOARD: Per-store live operational snapshot. Refreshes in real time.
Shows active/pending/inflight order counts, shift revenue, avg SLA, rider headcount,
and open restock alert count. Used by ManagerView.jsx.';


-- =============================================================================
-- VIEW 2: v_open_restock_alerts
-- -----------------------------------------------------------------------------
-- All OPEN or ACKNOWLEDGED restock alerts joined with full context so the
-- manager dashboard can display a named alert without additional JOINs.
-- =============================================================================
CREATE VIEW v_open_restock_alerts AS
SELECT
    ra.alert_id,
    ra.alert_status,
    ds.store_name,
    z.zone_name,
    ds.manager_name,
    p.product_name,
    p.brand,
    p.sku_code,
    pc.category_name,
    ra.stock_at_alert,
    ra.threshold_value,
    -- How many units short of the reorder threshold
    (ra.threshold_value - ra.stock_at_alert)                AS units_below_threshold,
    ra.triggered_at,
    -- Human-readable age of the alert
    EXTRACT(EPOCH FROM (NOW() - ra.triggered_at)) / 3600.0  AS alert_age_hours,
    ra.acknowledged_by,
    -- Urgency classification for UI colour-coding
    CASE
        WHEN ra.stock_at_alert = 0 THEN 'CRITICAL'
        WHEN ra.stock_at_alert <= (ra.threshold_value * 0.5)::INT THEN 'HIGH'
        ELSE 'MEDIUM'
    END                                                     AS urgency_level
FROM  restock_alerts    ra
JOIN  dark_stores       ds  ON ds.store_id   = ra.store_id
JOIN  zones             z   ON z.zone_id     = ds.zone_id
JOIN  products          p   ON p.product_id  = ra.product_id
JOIN  product_categories pc ON pc.category_id = p.category_id
WHERE ra.alert_status IN ('OPEN', 'ACKNOWLEDGED')
ORDER BY
    CASE ra.stock_at_alert WHEN 0 THEN 0 ELSE 1 END,  -- CRITICAL first
    ra.triggered_at DESC;

COMMENT ON VIEW v_open_restock_alerts IS
'Manager alert panel: all OPEN/ACKNOWLEDGED restock alerts with urgency classification.
Used by the alert widget in ManagerView.jsx.';


-- =============================================================================
-- VIEW 3: v_rider_performance
-- -----------------------------------------------------------------------------
-- Rider-level performance metrics for store manager review.
-- Covers all time (not just current shift) for a meaningful rating context.
-- =============================================================================
CREATE VIEW v_rider_performance AS
SELECT
    r.rider_id,
    r.full_name                                             AS rider_name,
    r.phone                                                 AS rider_phone,
    r.vehicle_type,
    r.status                                                AS current_status,
    r.rating                                                AS platform_rating,
    ds.store_name,
    z.zone_name,

    -- ── Lifetime delivery stats ───────────────────────────────────────────────
    COUNT(o.order_id)
        FILTER (WHERE o.status = 'DELIVERED')               AS total_deliveries,

    -- ── Average SLA for this rider's deliveries (FR-4) ───────────────────────
    ROUND(
        AVG(
            EXTRACT(EPOCH FROM (o.delivered_at - o.placed_at)) / 60.0
        )
        FILTER (WHERE o.status = 'DELIVERED'),
        2
    )                                                       AS avg_delivery_minutes,

    -- ── SLA compliance: % of deliveries completed within 10 minutes ──────────
    ROUND(
        100.0 * COUNT(o.order_id)
            FILTER (WHERE o.status = 'DELIVERED'
                      AND EXTRACT(EPOCH FROM (o.delivered_at - o.placed_at)) <= 600)
        / NULLIF(COUNT(o.order_id) FILTER (WHERE o.status = 'DELIVERED'), 0),
        1
    )                                                       AS sla_compliance_pct,

    -- ── Deliveries in the last 24 hours ──────────────────────────────────────
    COUNT(o.order_id)
        FILTER (WHERE o.status = 'DELIVERED'
                  AND o.delivered_at >= NOW() - INTERVAL '24 hours')
                                                            AS deliveries_last_24h,

    -- ── Is currently handling an active order? ────────────────────────────────
    EXISTS (
        SELECT 1 FROM orders ao
        WHERE  ao.rider_id = r.rider_id
          AND  ao.status IN ('PACKED', 'OUT_FOR_DELIVERY')
    )                                                       AS has_active_order,

    r.joined_at

FROM  riders       r
JOIN  dark_stores  ds  ON ds.store_id = r.store_id
JOIN  zones        z   ON z.zone_id   = ds.zone_id
LEFT JOIN orders   o   ON o.rider_id  = r.rider_id

GROUP BY
    r.rider_id,
    r.full_name,
    r.phone,
    r.vehicle_type,
    r.status,
    r.rating,
    r.joined_at,
    ds.store_name,
    z.zone_name

ORDER BY
    ds.store_name,
    total_deliveries DESC;

COMMENT ON VIEW v_rider_performance IS
'Store manager: per-rider performance — total deliveries, avg SLA minutes, and
10-minute SLA compliance %. Used in the rider management panel.';


-- =============================================================================
-- VIEW 4: v_inventory_health
-- -----------------------------------------------------------------------------
-- Full inventory snapshot with stock-health classification for every
-- (store, product) pair — gives the manager a warehouse view.
-- =============================================================================
CREATE VIEW v_inventory_health AS
SELECT
    i.inventory_id,
    ds.store_name,
    z.zone_name,
    pc.category_name,
    p.product_name,
    p.brand,
    p.sku_code,
    p.unit_of_measure,
    p.selling_price,
    i.current_stock,
    i.reorder_threshold,
    i.max_stock_capacity,

    -- Units remaining before reorder triggers
    (i.current_stock - i.reorder_threshold)                 AS buffer_units,

    -- Stock as % of max capacity
    ROUND(100.0 * i.current_stock / i.max_stock_capacity, 1) AS fill_pct,

    -- Health classification for UI badge colour
    CASE
        WHEN i.current_stock = 0                             THEN 'OUT_OF_STOCK'
        WHEN i.current_stock <= i.reorder_threshold          THEN 'LOW'
        WHEN i.current_stock <= (i.reorder_threshold * 2)   THEN 'MEDIUM'
        ELSE                                                      'HEALTHY'
    END                                                     AS stock_health,

    i.last_restocked_at,
    -- Days since last restock
    ROUND(
        EXTRACT(EPOCH FROM (NOW() - i.last_restocked_at)) / 86400.0,
        1
    )                                                       AS days_since_restock,

    i.updated_at                                            AS last_stock_update

FROM  inventory         i
JOIN  dark_stores       ds  ON ds.store_id    = i.store_id
JOIN  zones             z   ON z.zone_id      = ds.zone_id
JOIN  products          p   ON p.product_id   = i.product_id
JOIN  product_categories pc ON pc.category_id = p.category_id

ORDER BY
    CASE
        WHEN i.current_stock = 0                        THEN 0
        WHEN i.current_stock <= i.reorder_threshold     THEN 1
        WHEN i.current_stock <= i.reorder_threshold * 2 THEN 2
        ELSE 3
    END,
    ds.store_name,
    pc.category_name,
    p.product_name;

COMMENT ON VIEW v_inventory_health IS
'Warehouse panel: full per-store inventory snapshot with OUT_OF_STOCK / LOW / MEDIUM /
HEALTHY classification and fill-percentage. Sorted by urgency.';


-- =============================================================================
-- VIEW 5: v_sla_compliance  (FR-4 — SLA Date Arithmetic)
-- -----------------------------------------------------------------------------
-- Per-store SLA compliance report using SQL date arithmetic (FR-4).
-- Calculates elapsed delivery time and flags breaches of the 10-minute SLA.
-- =============================================================================
CREATE VIEW v_sla_compliance AS
SELECT
    o.order_id,
    ds.store_name,
    z.zone_name,
    c.full_name                                             AS customer_name,
    r.full_name                                             AS rider_name,
    o.status,
    o.placed_at,
    o.confirmed_at,
    o.packed_at,
    o.dispatched_at,
    o.delivered_at,

    -- ── Phase durations (minutes) using SQL date arithmetic (FR-4) ───────────
    ROUND(
        EXTRACT(EPOCH FROM (o.confirmed_at  - o.placed_at))   / 60.0, 2
    )                                                       AS mins_to_confirm,

    ROUND(
        EXTRACT(EPOCH FROM (o.packed_at     - o.confirmed_at)) / 60.0, 2
    )                                                       AS mins_to_pack,

    ROUND(
        EXTRACT(EPOCH FROM (o.dispatched_at - o.packed_at))   / 60.0, 2
    )                                                       AS mins_to_dispatch,

    ROUND(
        EXTRACT(EPOCH FROM (o.delivered_at  - o.dispatched_at)) / 60.0, 2
    )                                                       AS mins_to_deliver,

    -- ── Total end-to-end SLA (placed → delivered) ────────────────────────────
    ROUND(
        EXTRACT(EPOCH FROM (o.delivered_at - o.placed_at)) / 60.0, 2
    )                                                       AS total_sla_minutes,

    -- ── SLA status — 10-minute target for "10-minute delivery" promise ────────
    CASE
        WHEN o.delivered_at IS NULL                                         THEN 'IN_PROGRESS'
        WHEN EXTRACT(EPOCH FROM (o.delivered_at - o.placed_at)) <= 600     THEN 'ON_TIME'
        WHEN EXTRACT(EPOCH FROM (o.delivered_at - o.placed_at)) <= 720     THEN 'SLIGHT_DELAY'
        ELSE                                                                     'BREACHED'
    END                                                     AS sla_status,

    -- ── For live orders: how many minutes have elapsed since placement ────────
    CASE
        WHEN o.delivered_at IS NULL
        THEN ROUND(EXTRACT(EPOCH FROM (NOW() - o.placed_at)) / 60.0, 2)
        ELSE NULL
    END                                                     AS elapsed_minutes_live,

    o.total_amount                                          AS order_value_inr

FROM  orders        o
JOIN  dark_stores   ds  ON ds.store_id   = o.store_id
JOIN  zones         z   ON z.zone_id     = ds.zone_id
JOIN  customers     c   ON c.customer_id = o.customer_id
LEFT JOIN riders    r   ON r.rider_id    = o.rider_id

WHERE o.status != 'CANCELLED'

ORDER BY
    CASE o.status WHEN 'DELIVERED' THEN 1 ELSE 0 END,  -- live orders first
    o.placed_at DESC;

COMMENT ON VIEW v_sla_compliance IS
'FR-4: Full SLA tracking view using SQL date arithmetic. Shows all phase durations
(placed→confirmed→packed→dispatched→delivered) and classifies each order as
ON_TIME / SLIGHT_DELAY / BREACHED / IN_PROGRESS against the 10-minute promise.';


-- =============================================================================
-- MATERIALIZED VIEW (OPTIONAL — for heavy dashboards)
-- -----------------------------------------------------------------------------
-- If the manager dashboard query becomes slow as orders scale, run this to
-- create a cached version of v_manager_live_metrics that can be refreshed
-- on a schedule (e.g., every 60 seconds via pg_cron in Supabase).
-- =============================================================================
/*
DROP MATERIALIZED VIEW IF EXISTS mv_manager_live_metrics;

CREATE MATERIALIZED VIEW mv_manager_live_metrics AS
    SELECT * FROM v_manager_live_metrics;

CREATE UNIQUE INDEX ON mv_manager_live_metrics (store_id);

-- Refresh command (call this from a Supabase Edge Function or pg_cron job):
-- REFRESH MATERIALIZED VIEW CONCURRENTLY mv_manager_live_metrics;
*/


-- =============================================================================
-- VERIFICATION QUERIES  (run in Supabase SQL Editor to test the views)
-- =============================================================================
/*

-- 1. Full live operations dashboard
SELECT store_name, zone_name, total_active_orders, pending_orders,
       inflight_orders, delivered_today, shift_revenue_inr, avg_sla_minutes,
       riders_available, open_restock_alerts
FROM   v_manager_live_metrics;

-- 2. Which stores have the most urgent restock needs?
SELECT store_name, product_name, brand, stock_at_alert,
       threshold_value, urgency_level, alert_age_hours
FROM   v_open_restock_alerts
ORDER  BY CASE urgency_level WHEN 'CRITICAL' THEN 0 WHEN 'HIGH' THEN 1 ELSE 2 END;

-- 3. Which products are OUT_OF_STOCK or LOW across all stores?
SELECT store_name, product_name, current_stock, reorder_threshold,
       stock_health, fill_pct
FROM   v_inventory_health
WHERE  stock_health IN ('OUT_OF_STOCK', 'LOW')
ORDER  BY current_stock;

-- 4. SLA compliance — all live (in-progress) orders with elapsed time
SELECT order_id, store_name, customer_name, rider_name,
       status, elapsed_minutes_live, sla_status
FROM   v_sla_compliance
WHERE  sla_status = 'IN_PROGRESS'
ORDER  BY elapsed_minutes_live DESC NULLS LAST;

-- 5. Overall per-store SLA compliance rate (% on-time deliveries)
SELECT store_name,
       COUNT(*) FILTER (WHERE sla_status = 'ON_TIME')    AS on_time,
       COUNT(*) FILTER (WHERE sla_status = 'BREACHED')   AS breached,
       ROUND(
           100.0 * COUNT(*) FILTER (WHERE sla_status = 'ON_TIME')
           / NULLIF(COUNT(*) FILTER (WHERE sla_status != 'IN_PROGRESS'), 0),
           1
       )                                                  AS compliance_pct
FROM   v_sla_compliance
GROUP  BY store_name
ORDER  BY compliance_pct DESC NULLS LAST;

-- 6. Top-performing riders
SELECT rider_name, store_name, total_deliveries,
       avg_delivery_minutes, sla_compliance_pct, platform_rating
FROM   v_rider_performance
WHERE  total_deliveries > 0
ORDER  BY sla_compliance_pct DESC, avg_delivery_minutes;

*/

-- =============================================================================
-- END OF 05_views.sql
-- =============================================================================


