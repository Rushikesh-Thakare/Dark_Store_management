-- Self-registration for customers and riders. Run after 06_auth_rls.sql.
--
-- The browser cannot write profiles/customers/riders itself (that would let anyone grant
-- themselves a role), so this SECURITY DEFINER function does it for the signed-in user.
-- Managers cannot be self-registered: they are added by hand (see the end of 06).
--
-- shortcut: single-store demo, new accounts attach to the one active store and its zone;
-- upgrade to a store/zone picker if more stores are added.

CREATE OR REPLACE FUNCTION register_account(p_role TEXT, p_full_name TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_store_id INT;
    v_zone_id  INT;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'You must be signed in';
    END IF;
    IF p_role NOT IN ('customer', 'rider') THEN
        RAISE EXCEPTION 'Only customer and rider accounts can be self-registered';
    END IF;
    IF p_full_name IS NULL OR btrim(p_full_name) = '' THEN
        RAISE EXCEPTION 'Full name is required';
    END IF;
    IF EXISTS (SELECT 1 FROM profiles WHERE user_id = auth.uid()) THEN
        RAISE EXCEPTION 'This account already has a role';
    END IF;

    SELECT store_id, zone_id INTO v_store_id, v_zone_id
    FROM dark_stores WHERE is_active ORDER BY store_id LIMIT 1;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No active store is set up yet';
    END IF;

    -- Role row and domain row are created together; if either fails, both roll back.
    INSERT INTO profiles (user_id, role) VALUES (auth.uid(), p_role);
    IF p_role = 'customer' THEN
        INSERT INTO customers (auth_user_id, full_name, zone_id)
        VALUES (auth.uid(), btrim(p_full_name), v_zone_id);
    ELSE
        INSERT INTO riders (auth_user_id, full_name, store_id)
        VALUES (auth.uid(), btrim(p_full_name), v_store_id);
    END IF;
END;
$$;

REVOKE EXECUTE ON FUNCTION register_account(TEXT, TEXT) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION register_account(TEXT, TEXT) TO authenticated;
