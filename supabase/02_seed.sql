-- Dark Store Management System: seed data (run once, after 01_schema.sql)
-- Rows are looked up by name, so IDs come from the identity columns and nothing is hard-coded.

-- Guard: stop instead of inserting duplicates if the seed was already run.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM zones) THEN
        RAISE EXCEPTION 'Seed already applied (zones is not empty). Truncate the tables first to re-seed.';
    END IF;
END $$;

-- One zone and one active store
INSERT INTO zones (zone_name, pincode) VALUES ('Kothrud', '411038');

INSERT INTO dark_stores (store_name, address, zone_id)
SELECT 'QuickMart Kothrud', '12 Karve Road, Pune', zone_id FROM zones WHERE pincode = '411038';

-- Categories
INSERT INTO categories (category_name) VALUES
    ('Dairy'), ('Fruits & Vegetables'), ('Snacks'), ('Beverages');

-- Products (price in INR)
INSERT INTO products (product_name, category_id, price)
SELECT p.product_name, c.category_id, p.price
FROM (VALUES
    ('Full Cream Milk 1L',   'Dairy',               68.00),
    ('Paneer 200g',          'Dairy',               95.00),
    ('Curd 400g',            'Dairy',               45.00),
    ('Bananas 1 dozen',      'Fruits & Vegetables', 60.00),
    ('Tomatoes 500g',        'Fruits & Vegetables', 30.00),
    ('Potato Chips 100g',    'Snacks',              40.00),
    ('Salted Peanuts 200g',  'Snacks',              55.00),
    ('Orange Juice 1L',      'Beverages',          120.00),
    ('Cola 750ml',           'Beverages',           45.00),
    ('Mineral Water 1L',     'Beverages',           20.00)
) AS p (product_name, category_name, price)
JOIN categories c ON c.category_name = p.category_name;

-- Inventory for the one store.
-- Paneer (6 vs threshold 5) is one order away from a low-stock alert; Orange Juice is already below its threshold.
INSERT INTO inventory (store_id, product_id, current_stock, reorder_threshold)
SELECT s.store_id, pr.product_id, i.stock, i.threshold
FROM (VALUES
    ('Full Cream Milk 1L',  50, 10),
    ('Paneer 200g',          6,  5),
    ('Curd 400g',           30, 10),
    ('Bananas 1 dozen',     25,  8),
    ('Tomatoes 500g',       40, 10),
    ('Potato Chips 100g',   60, 15),
    ('Salted Peanuts 200g', 35, 10),
    ('Orange Juice 1L',      4,  8),
    ('Cola 750ml',          45, 12),
    ('Mineral Water 1L',   100, 20)
) AS i (product_name, stock, threshold)
JOIN products pr ON pr.product_name = i.product_name
CROSS JOIN dark_stores s;

-- Demo profiles. auth_user_id stays NULL until the Auth users exist (see the linking step below).
INSERT INTO customers (full_name, phone, address, zone_id)
SELECT c.full_name, c.phone, c.address, z.zone_id
FROM (VALUES
    ('Aarav Sharma', '9800000001', '5 Paud Road, Kothrud, Pune'),
    ('Meera Iyer',   '9800000002', '22 Karve Nagar, Pune')
) AS c (full_name, phone, address)
CROSS JOIN zones z;

INSERT INTO riders (full_name, phone, store_id)
SELECT r.full_name, r.phone, s.store_id
FROM (VALUES
    ('Rohan Patil', '9811111111'),
    ('Sana Khan',   '9822222222')
) AS r (full_name, phone)
CROSS JOIN dark_stores s;
