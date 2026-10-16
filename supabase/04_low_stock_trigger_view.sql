-- Low-stock trigger and manager view. Run after 01_schema.sql.

-- Trigger function: runs after an inventory row is updated and records a restock alert.
CREATE OR REPLACE FUNCTION create_restock_alert()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- If an open alert already exists for this store/product, the unique index
    -- uq_open_restock_alert makes ON CONFLICT skip the insert instead of failing the order.
    INSERT INTO restock_alerts (store_id, product_id, stock_at_alert)
    VALUES (NEW.store_id, NEW.product_id, NEW.current_stock)
    ON CONFLICT (store_id, product_id) WHERE resolved_at IS NULL DO NOTHING;
    RETURN NEW;
END;
$$;

-- The trigger. The WHEN clause is the "crossing" rule:
--   OLD.current_stock > NEW.reorder_threshold   stock WAS above the threshold
--   NEW.current_stock <= NEW.reorder_threshold  stock IS NOW at or below it
-- Both must be true, so it fires once at the crossing, not on every later reduction
-- (5 -> 4 -> 3 fire nothing because the old value was already at or below the threshold).
CREATE OR REPLACE TRIGGER trg_low_stock_alert
AFTER UPDATE OF current_stock ON inventory
FOR EACH ROW
WHEN (OLD.current_stock > NEW.reorder_threshold AND NEW.current_stock <= NEW.reorder_threshold)
EXECUTE FUNCTION create_restock_alert();

-- Manager view: every product at or below its reorder threshold, with its open alert if there is one.
-- security_invoker makes the view obey the caller's RLS instead of the view owner's.
CREATE OR REPLACE VIEW v_low_stock_inventory
WITH (security_invoker = true) AS
SELECT s.store_id,
       s.store_name,
       p.product_id,
       p.product_name,
       c.category_name,
       i.current_stock,
       i.reorder_threshold,
       a.alert_id,
       a.created_at AS alert_created_at
FROM inventory i
JOIN dark_stores s ON s.store_id   = i.store_id       -- which store holds the stock
JOIN products p    ON p.product_id = i.product_id     -- product name
JOIN categories c  ON c.category_id = p.category_id   -- product category
LEFT JOIN restock_alerts a                            -- LEFT: keep low items that have no alert yet
       ON a.store_id = i.store_id
      AND a.product_id = i.product_id
      AND a.resolved_at IS NULL                       -- only the open alert
WHERE i.current_stock <= i.reorder_threshold;
