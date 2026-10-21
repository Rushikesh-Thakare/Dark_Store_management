-- Rider status update: move an order to its next delivery step. Run after 06_auth_rls.sql.
--
-- SECURITY INVOKER (default): the caller's RLS and column grants apply, so a rider can only
-- advance orders assigned to them (orders_update policy). The status rules and the timestamps
-- (database clock, not the browser's) live here, not in React.
--   placed / packed    -> out_for_delivery  (sets dispatched_at)
--   out_for_delivery   -> delivered         (sets delivered_at)
-- Delivered and cancelled orders cannot be advanced.

CREATE OR REPLACE FUNCTION advance_delivery(p_order_id INT)
RETURNS VARCHAR
LANGUAGE plpgsql
AS $$
DECLARE
    v_new_status VARCHAR;
BEGIN
    UPDATE orders
    SET status        = CASE status WHEN 'out_for_delivery' THEN 'delivered' ELSE 'out_for_delivery' END,
        dispatched_at = CASE WHEN status IN ('placed', 'packed') THEN now() ELSE dispatched_at END,
        delivered_at  = CASE WHEN status = 'out_for_delivery' THEN now() ELSE delivered_at END
    WHERE order_id = p_order_id
      AND status IN ('placed', 'packed', 'out_for_delivery')
    RETURNING status INTO v_new_status;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Order % cannot be updated: it is not assigned to you or is already finished', p_order_id;
    END IF;
    RETURN v_new_status;
END;
$$;

REVOKE EXECUTE ON FUNCTION advance_delivery(INT) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION advance_delivery(INT) TO authenticated;
