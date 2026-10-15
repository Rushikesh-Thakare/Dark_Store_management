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
