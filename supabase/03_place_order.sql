-- place_order: create an order, its items, and deduct stock, all or nothing.
--
-- Usage:  SELECT place_order(1, 1, '[{"product_id": 2, "quantity": 3}, {"product_id": 5, "quantity": 1}]');
-- Returns the new order_id. Any problem raises an error, and PostgreSQL then rolls back
-- everything this function did (a function always runs inside one transaction).
--
-- SECURITY DEFINER: customers have no RLS right to write orders or inventory, so the function
-- does it for them. That makes the customer check in Step 3 essential: the customer_id passed
-- in must belong to the signed-in user (auth.uid()). Grants at the bottom keep anon out.

CREATE OR REPLACE FUNCTION place_order(p_customer_id INT, p_store_id INT, p_items JSONB)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_order_id  INT;
    v_rider_id  INT;
    v_item      RECORD;
    v_price     NUMERIC(10, 2);
    v_available INT;
    v_total     NUMERIC(10, 2) := 0;
BEGIN
    -- Step 1: the item list must be a non-empty JSON array.
    IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' OR jsonb_array_length(p_items) = 0 THEN
        RAISE EXCEPTION 'Order must contain at least one item';
    END IF;

    -- Step 2: the same product may not appear twice (order_items has one row per product).
    IF (SELECT count(*) <> count(DISTINCT e ->> 'product_id') FROM jsonb_array_elements(p_items) e) THEN
        RAISE EXCEPTION 'Each product may appear only once in an order';
    END IF;

    -- Step 3: the customer must be the signed-in user's own, and the store must exist and be active.
    IF NOT EXISTS (SELECT 1 FROM customers WHERE customer_id = p_customer_id AND auth_user_id = auth.uid()) THEN
        RAISE EXCEPTION 'Customer % is not your customer account', p_customer_id;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM dark_stores WHERE store_id = p_store_id AND is_active) THEN
        RAISE EXCEPTION 'Store % does not exist or is not active', p_store_id;
    END IF;

    -- Step 4: pick a rider and create the order header; the total is filled in after the items.
    -- The rider is the store's least busy rider who is not offline and can sign in (has an auth
    -- account). If there is none, the order is still placed, just unassigned.
    SELECT r.rider_id INTO v_rider_id
    FROM riders r
    WHERE r.store_id = p_store_id AND r.status <> 'offline' AND r.auth_user_id IS NOT NULL
    ORDER BY (SELECT count(*) FROM orders o
              WHERE o.rider_id = r.rider_id AND o.status IN ('placed', 'packed', 'out_for_delivery')),
             r.rider_id
    LIMIT 1;

    INSERT INTO orders (customer_id, store_id, rider_id)
    VALUES (p_customer_id, p_store_id, v_rider_id)
    RETURNING order_id INTO v_order_id;

    -- Step 5: handle each item. Sorting by product_id means two simultaneous orders lock
    -- inventory rows in the same order, which avoids deadlocks.
    FOR v_item IN
        SELECT (e ->> 'product_id')::INT AS product_id,
               (e ->> 'quantity')::INT   AS quantity
        FROM jsonb_array_elements(p_items) e
        ORDER BY 1
    LOOP
        -- 5a: the item must be well-formed.
        IF v_item.product_id IS NULL OR v_item.quantity IS NULL OR v_item.quantity <= 0 THEN
            RAISE EXCEPTION 'Each item needs a product_id and a quantity greater than 0';
        END IF;

        -- 5b: the product must exist and be active; read its current price.
        SELECT price INTO v_price
        FROM products
        WHERE product_id = v_item.product_id AND is_active;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Product % does not exist or is not available', v_item.product_id;
        END IF;

        -- 5c: deduct stock only if enough is left. Check and deduct happen in ONE statement,
        -- so two customers can never both take the last unit.
        UPDATE inventory
        SET current_stock = current_stock - v_item.quantity
        WHERE store_id = p_store_id
          AND product_id = v_item.product_id
          AND current_stock >= v_item.quantity;

        IF NOT FOUND THEN
            -- Nothing was updated: work out why, to give a clear message.
            SELECT current_stock INTO v_available
            FROM inventory
            WHERE store_id = p_store_id AND product_id = v_item.product_id;

            IF NOT FOUND THEN
                RAISE EXCEPTION 'Product % is not sold at store %', v_item.product_id, p_store_id;
            END IF;
            RAISE EXCEPTION 'Not enough stock for product %: requested %, available %',
                v_item.product_id, v_item.quantity, v_available;
        END IF;

        -- 5d: save the line, keeping today's price (price_at_purchase), and add to the total.
        INSERT INTO order_items (order_id, product_id, quantity, price_at_purchase)
        VALUES (v_order_id, v_item.product_id, v_item.quantity, v_price);

        v_total := v_total + v_price * v_item.quantity;
    END LOOP;

    -- Step 6: store the final total and return the order id.
    UPDATE orders SET total_amount = v_total WHERE order_id = v_order_id;
    RETURN v_order_id;
END;
$$;

-- Only signed-in users may call it (Supabase grants new functions to anon by default).
REVOKE EXECUTE ON FUNCTION place_order(INT, INT, JSONB) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION place_order(INT, INT, JSONB) TO authenticated;
