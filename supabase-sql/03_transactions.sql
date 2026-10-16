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
