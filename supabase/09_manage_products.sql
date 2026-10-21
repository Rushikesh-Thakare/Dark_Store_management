-- Manager product management. Run after 06_auth_rls.sql.

-- 1. Let managers write products (deactivating a product is a plain UPDATE of is_active).
--    Customers and riders still only have the read policy from 06.
CREATE POLICY products_manager_write ON products FOR ALL TO authenticated
    USING (is_manager()) WITH CHECK (is_manager());

-- 2. Add or edit a product together with its stock in the active store, all or nothing.
--    p_product_id NULL = add a new product; otherwise edit that product.
--    SECURITY INVOKER (default): RLS applies as well, and the is_manager() check below gives a
--    readable message instead of a raw policy error.
--    Stock is set to the number given (an adjustment), so a very recent sale can be overwritten.
CREATE OR REPLACE FUNCTION save_product(
    p_product_id  INT,
    p_category_id INT,
    p_name        TEXT,
    p_price       NUMERIC,
    p_stock       INT,
    p_reorder     INT
) RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
    v_store_id   INT;
    v_product_id INT;
BEGIN
    IF NOT is_manager() THEN
        RAISE EXCEPTION 'Only managers can change products';
    END IF;
    IF p_name IS NULL OR btrim(p_name) = '' THEN
        RAISE EXCEPTION 'Product name is required';
    END IF;
    IF p_price IS NULL OR p_price <= 0 THEN
        RAISE EXCEPTION 'Price must be greater than 0';
    END IF;
    IF p_stock IS NULL OR p_stock < 0 THEN
        RAISE EXCEPTION 'Stock cannot be negative';
    END IF;
    IF p_reorder IS NULL OR p_reorder < 0 THEN
        RAISE EXCEPTION 'Reorder threshold cannot be negative';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM categories WHERE category_id = p_category_id) THEN
        RAISE EXCEPTION 'Choose a category';
    END IF;

    SELECT store_id INTO v_store_id FROM dark_stores WHERE is_active ORDER BY store_id LIMIT 1;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No active store is set up yet';
    END IF;

    IF p_product_id IS NULL THEN
        INSERT INTO products (product_name, category_id, price)
        VALUES (btrim(p_name), p_category_id, p_price)
        RETURNING product_id INTO v_product_id;
    ELSE
        UPDATE products
        SET product_name = btrim(p_name), category_id = p_category_id, price = p_price
        WHERE product_id = p_product_id
        RETURNING product_id INTO v_product_id;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Product % does not exist', p_product_id;
        END IF;
    END IF;

    -- Insert the stock row, or update it if it exists (the low-stock trigger fires on the update).
    INSERT INTO inventory (store_id, product_id, current_stock, reorder_threshold)
    VALUES (v_store_id, v_product_id, p_stock, p_reorder)
    ON CONFLICT (store_id, product_id)
    DO UPDATE SET current_stock = EXCLUDED.current_stock, reorder_threshold = EXCLUDED.reorder_threshold;

    RETURN v_product_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION save_product(INT, INT, TEXT, NUMERIC, INT, INT) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION save_product(INT, INT, TEXT, NUMERIC, INT, INT) TO authenticated;
