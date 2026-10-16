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
