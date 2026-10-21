-- Auth + RLS setup for manager / rider / customer. Run after 01-04, then re-run 03_place_order.sql.
--
-- Model: Supabase Auth owns emails and passwords (never stored in our tables).
--   profiles               user -> role (manager | rider | customer)
--   customers.auth_user_id user -> their customer row   (already in the schema)
--   riders.auth_user_id    user -> their rider row      (already in the schema)
-- Customers and riders never write orders or inventory directly; place_order does it for them.

-- 1. Role mapping. No INSERT/UPDATE policy exists, so users cannot give themselves a role.
CREATE TABLE profiles (
    user_id UUID PRIMARY KEY REFERENCES auth.users (id) ON DELETE CASCADE,
    role    VARCHAR(20) NOT NULL CHECK (role IN ('manager', 'rider', 'customer'))
);

-- 2. Helpers. SECURITY DEFINER lets policies look up the caller's role/IDs without recursing
--    through RLS (customers' policy reads orders, orders' policy reads customers, and so on).
CREATE FUNCTION is_manager() RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
    SELECT EXISTS (SELECT 1 FROM profiles WHERE user_id = auth.uid() AND role = 'manager');
$$;

CREATE FUNCTION my_customer_id() RETURNS INT
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
    SELECT customer_id FROM customers WHERE auth_user_id = auth.uid();
$$;

CREATE FUNCTION my_rider_id() RETURNS INT
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
    SELECT rider_id FROM riders WHERE auth_user_id = auth.uid();
$$;

-- 3. Turn RLS on (a table with RLS on and no matching policy returns no rows).
ALTER TABLE profiles       ENABLE ROW LEVEL SECURITY;
ALTER TABLE zones          ENABLE ROW LEVEL SECURITY;
ALTER TABLE dark_stores    ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories     ENABLE ROW LEVEL SECURITY;
ALTER TABLE products       ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory      ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers      ENABLE ROW LEVEL SECURITY;
ALTER TABLE riders         ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders         ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items    ENABLE ROW LEVEL SECURITY;
ALTER TABLE restock_alerts ENABLE ROW LEVEL SECURITY;

-- 4. Policies (all TO authenticated, so anonymous visitors get nothing).

-- profiles: you can read only your own row (the app uses it to pick the dashboard).
CREATE POLICY profiles_read_own ON profiles FOR SELECT TO authenticated
    USING (user_id = auth.uid());

-- Shared reference data: any signed-in user can read it.
CREATE POLICY zones_read       ON zones       FOR SELECT TO authenticated USING (true);
CREATE POLICY dark_stores_read ON dark_stores FOR SELECT TO authenticated USING (true);
CREATE POLICY categories_read  ON categories  FOR SELECT TO authenticated USING (true);
-- Customers see only active products; the manager sees all.
CREATE POLICY products_read    ON products    FOR SELECT TO authenticated
    USING (is_active OR is_manager());

-- inventory: everyone signed in can read stock (the customer page shows it); only the manager changes it.
CREATE POLICY inventory_read ON inventory FOR SELECT TO authenticated USING (true);
CREATE POLICY inventory_manager_write ON inventory FOR ALL TO authenticated
    USING (is_manager()) WITH CHECK (is_manager());

-- customers: you see your own row; the manager sees all; a rider sees only customers on their assigned orders.
CREATE POLICY customers_read ON customers FOR SELECT TO authenticated
    USING (customer_id = my_customer_id()
           OR is_manager()
           OR customer_id IN (SELECT customer_id FROM orders WHERE rider_id = my_rider_id()));

-- riders: you see your own row; the manager sees all.
CREATE POLICY riders_read ON riders FOR SELECT TO authenticated
    USING (rider_id = my_rider_id() OR is_manager());

-- orders: customers see their own, riders see the ones assigned to them, the manager sees all.
CREATE POLICY orders_read ON orders FOR SELECT TO authenticated
    USING (customer_id = my_customer_id() OR rider_id = my_rider_id() OR is_manager());

-- orders update: the manager (assigns riders) or the assigned rider (updates status).
-- WITH CHECK stops a rider handing their order to someone else. There is no INSERT or DELETE
-- policy: orders are created only by place_order.
CREATE POLICY orders_update ON orders FOR UPDATE TO authenticated
    USING      (is_manager() OR rider_id = my_rider_id())
    WITH CHECK (is_manager() OR rider_id = my_rider_id());

-- RLS limits rows, not columns, so restrict columns too: nobody can edit totals or customers.
REVOKE UPDATE ON orders FROM authenticated;
GRANT  UPDATE (rider_id, status, dispatched_at, delivered_at) ON orders TO authenticated;

-- order_items: visible exactly when the parent order is visible (the subquery obeys orders' RLS).
CREATE POLICY order_items_read ON order_items FOR SELECT TO authenticated
    USING (EXISTS (SELECT 1 FROM orders o WHERE o.order_id = order_items.order_id));

-- restock_alerts: manager only (read and resolve).
CREATE POLICY restock_alerts_manager ON restock_alerts FOR ALL TO authenticated
    USING (is_manager()) WITH CHECK (is_manager());

-- 5. DEMO ACCOUNT SETUP (edit the emails to match what you create):
--    a) Authentication > Users > Add user: three users with email + password (Auto Confirm on).
--    b) Then run, with your emails:
-- INSERT INTO profiles (user_id, role)
-- SELECT id, 'manager'  FROM auth.users WHERE email = 'manager@demo.com';
-- INSERT INTO profiles (user_id, role)
-- SELECT id, 'customer' FROM auth.users WHERE email = 'customer@demo.com';
-- INSERT INTO profiles (user_id, role)
-- SELECT id, 'rider'    FROM auth.users WHERE email = 'rider@demo.com';
-- UPDATE customers SET auth_user_id = (SELECT id FROM auth.users WHERE email = 'customer@demo.com')
-- WHERE full_name = 'Aarav Sharma';
-- UPDATE riders SET auth_user_id = (SELECT id FROM auth.users WHERE email = 'rider@demo.com')
-- WHERE full_name = 'Rohan Patil';
