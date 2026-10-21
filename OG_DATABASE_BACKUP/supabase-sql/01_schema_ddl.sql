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
