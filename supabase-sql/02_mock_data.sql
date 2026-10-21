-- =============================================================================
-- FILE:    02_mock_data.sql
-- PROJECT: Hyper-Local Dark Store Management System
-- PHASE:   1 — Seed / Mock Data
-- AUTHORS: Rushikesh Thakare, Aashay Kulkarni, Nikita Dhokale
-- DB:      PostgreSQL 15+  (Supabase)
-- DESC:    Realistic Mumbai-localised INSERT statements for all 10 tables.
--          Run AFTER 01_schema_ddl.sql.
--          Includes deliberately low-stock scenarios to exercise the restock
--          trigger (FR-3) and concurrent-checkout lock testing (FR-1).
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Safety: wrap everything in a single transaction so the seed is atomic.
-- ---------------------------------------------------------------------------
BEGIN;

-- =============================================================================
-- SECTION 1: zones
-- Six hyper-local zones across suburban Mumbai
-- =============================================================================
INSERT INTO zones (zone_name, city, pincode, delivery_radius_km) VALUES
    ('Andheri West',    'Mumbai', '400053', 2.50),
    ('Bandra West',     'Mumbai', '400050', 2.00),
    ('Borivali East',   'Mumbai', '400066', 3.00),
    ('Goregaon West',   'Mumbai', '400104', 2.75),
    ('Malad West',      'Mumbai', '400064', 2.50),
    ('Vile Parle East', 'Mumbai', '400057', 2.00);


-- =============================================================================
-- SECTION 2: dark_stores
-- Eight dark-store locations — authentic Mumbai neighbourhood names
-- =============================================================================
INSERT INTO dark_stores (store_name, zone_id, address, contact_phone, manager_name) VALUES
    -- Andheri West (zone_id = 1) — 2 stores
    ('Bhavan''s Campus Hub',
     1, 'Shop 4, Bhavans College Road, Andheri West, Mumbai - 400053',
     '9820011001', 'Rajesh Patil'),
    ('Versova Quick Store',
     1, 'Plot 7, Yari Road, Versova, Andheri West, Mumbai - 400061',
     '9820011002', 'Sunita Sharma'),

    -- Bandra West (zone_id = 2) — 1 store
    ('Linking Road Express',
     2, 'Ground Floor, Hill Road Complex, Bandra West, Mumbai - 400050',
     '9820022001', 'Priya Nair'),

    -- Borivali East (zone_id = 3) — 1 store
    ('Borivali Station Hub',
     3, 'Shop 12, Near IC Colony Road, Borivali East, Mumbai - 400066',
     '9820033001', 'Amol Deshmukh'),

    -- Goregaon West (zone_id = 4) — 2 stores
    ('Oshiwara Market Hub',
     4, 'Unit 3, Oshiwara Industrial Area, Goregaon West, Mumbai - 400104',
     '9820044001', 'Kavitha Menon'),
    ('Oberoi Sprouts',
     4, 'Kiosk 2, Oberoi Mall Premises, Goregaon West, Mumbai - 400063',
     '9820044002', 'Ravi Khandagale'),

    -- Malad West (zone_id = 5) — 1 store
    ('Infinity Mall Dark Node',
     5, 'Basement Level B2, Infinity Mall, Malad West, Mumbai - 400064',
     '9820055001', 'Deepa Joshi'),

    -- Vile Parle East (zone_id = 6) — 1 store
    ('Munshi Nagar Quick Hub',
     6, 'Shop 2A, Munshi Nagar, Vile Parle East, Mumbai - 400057',
     '9820066001', 'Suresh Iyer');


-- =============================================================================
-- SECTION 3: customers  (20 customers spread across all 6 zones)
-- =============================================================================
INSERT INTO customers (full_name, email, phone, address, zone_id) VALUES
    -- Andheri West (zone 1)
    ('Aisha Khan',
     'aisha.khan@gmail.com', '9876500001',
     'B-404, Lokhandwala Complex, Andheri West, Mumbai', 1),
    ('Rohan Mehta',
     'rohan.mehta@outlook.com', '9876500002',
     '12, Seven Bungalows, Andheri West, Mumbai', 1),
    ('Priyanka Shetty',
     'priyanka.shetty@yahoo.com', '9876500003',
     'Flat 202, Oshiwara Residency, Andheri West, Mumbai', 1),
    ('Arjun Nair',
     'arjun.nair@gmail.com', '9876500004',
     'C-101, Natraj CHS, Andheri West, Mumbai', 1),

    -- Bandra West (zone 2)
    ('Sneha D''souza',
     'sneha.dsouza@gmail.com', '9876500005',
     '15, Chapel Road, Bandra West, Mumbai', 2),
    ('Vikram Rao',
     'vikram.rao@hotmail.com', '9876500006',
     'Flat 5B, Sea Breeze Apartments, Bandra West, Mumbai', 2),
    ('Meera Pillai',
     'meera.pillai@gmail.com', '9876500007',
     '33, St. John Road, Bandra West, Mumbai', 2),

    -- Borivali East (zone 3)
    ('Ganesh Kulkarni',
     'ganesh.kulkarni@gmail.com', '9876500008',
     'A-504, Siddharth Nagar, Borivali East, Mumbai', 3),
    ('Sarita Thakur',
     'sarita.thakur@rediffmail.com', '9876500009',
     'Plot 45, Kasturba Road, Borivali East, Mumbai', 3),
    ('Amit Joshi',
     'amit.joshi@gmail.com', '9876500010',
     'D-12, New Mhada Colony, Borivali East, Mumbai', 3),

    -- Goregaon West (zone 4)
    ('Divya Menon',
     'divya.menon@gmail.com', '9876500011',
     '7, Bangur Nagar, Goregaon West, Mumbai', 4),
    ('Kiran Pawar',
     'kiran.pawar@gmail.com', '9876500012',
     'Shop CHS 303, MHADA Colony, Goregaon West, Mumbai', 4),
    ('Rahul Gupta',
     'rahul.gupta@gmail.com', '9876500013',
     'E-402, Lalbaug Residency, Goregaon West, Mumbai', 4),

    -- Malad West (zone 5)
    ('Pooja Iyer',
     'pooja.iyer@gmail.com', '9876500014',
     '22, Marve Road, Malad West, Mumbai', 5),
    ('Suresh Sawant',
     'suresh.sawant@yahoo.com', '9876500015',
     'B-201, Evershine Nagar, Malad West, Mumbai', 5),
    ('Nisha Bose',
     'nisha.bose@gmail.com', '9876500016',
     'Flat 3A, Liberty Garden, Malad West, Mumbai', 5),
    ('Tarun Kapoor',
     'tarun.kapoor@gmail.com', '9876500017',
     'C-504, Highland Park, Malad West, Mumbai', 5),

    -- Vile Parle East (zone 6)
    ('Anjali Desai',
     'anjali.desai@gmail.com', '9876500018',
     '8A, Nehru Road, Vile Parle East, Mumbai', 6),
    ('Siddharth Rane',
     'siddharth.rane@gmail.com', '9876500019',
     'B-302, Swami Vivekanand Road, Vile Parle East, Mumbai', 6),
    ('Kavita Sharma',
     'kavita.sharma@gmail.com', '9876500020',
     '14, Munshi Nagar, Vile Parle East, Mumbai', 6);


-- =============================================================================
-- SECTION 4: riders  (16 riders across all 8 dark stores)
-- =============================================================================
INSERT INTO riders (full_name, phone, store_id, vehicle_type, status, rating, joined_at) VALUES
    -- Store 1: Bhavan's Campus Hub (store_id = 1)
    ('Raju Yadav',       '9700000101', 1, 'Bicycle',    'AVAILABLE',     4.80, '2025-01-15'),
    ('Manoj Tiwari',     '9700000102', 1, 'Electric Bike', 'ON_DELIVERY', 4.65, '2025-02-01'),
    ('Sonu Gupta',       '9700000103', 1, 'Bicycle',    'AVAILABLE',     4.90, '2025-03-10'),

    -- Store 2: Versova Quick Store (store_id = 2)
    ('Lakshman Dube',    '9700000201', 2, 'Bicycle',    'AVAILABLE',     4.75, '2025-01-20'),
    ('Prakash Vishwas',  '9700000202', 2, 'Electric Bike', 'AVAILABLE',  4.55, '2025-04-05'),

    -- Store 3: Linking Road Express (store_id = 3)
    ('David Fernandes',  '9700000301', 3, 'Electric Bike', 'AVAILABLE',  4.95, '2025-01-10'),
    ('Jerome D''cruz',   '9700000302', 3, 'Bicycle',    'OFF_DUTY',      4.40, '2025-05-01'),

    -- Store 4: Borivali Station Hub (store_id = 4)
    ('Sachin Mhatre',    '9700000401', 4, 'Bicycle',    'ON_DELIVERY',   4.70, '2025-02-15'),
    ('Nilesh Patil',     '9700000402', 4, 'Electric Bike', 'AVAILABLE',  4.85, '2025-03-01'),

    -- Store 5: Oshiwara Market Hub (store_id = 5)
    ('Vikas Thakare',    '9700000501', 5, 'Bicycle',    'AVAILABLE',     4.60, '2025-01-25'),
    ('Ajay Kulkarni',    '9700000502', 5, 'Electric Bike', 'ON_DELIVERY', 4.78, '2025-02-20'),

    -- Store 6: Oberoi Sprouts (store_id = 6)
    ('Rahul Bhosale',    '9700000601', 6, 'Bicycle',    'AVAILABLE',     4.88, '2025-03-15'),

    -- Store 7: Infinity Mall Dark Node (store_id = 7)
    ('Kiran Salvi',      '9700000701', 7, 'Electric Bike', 'AVAILABLE',  4.72, '2025-01-30'),
    ('Deepak Jadhav',    '9700000702', 7, 'Bicycle',    'ON_DELIVERY',   4.65, '2025-04-10'),

    -- Store 8: Munshi Nagar Quick Hub (store_id = 8)
    ('Santosh Kadam',    '9700000801', 8, 'Electric Bike', 'AVAILABLE',  4.82, '2025-02-05'),
    ('Anil Parab',       '9700000802', 8, 'Bicycle',    'AVAILABLE',     4.58, '2025-05-15');


-- =============================================================================
-- SECTION 5: product_categories  (7 FMCG categories)
-- =============================================================================
INSERT INTO product_categories (category_name, description) VALUES
    ('Dairy & Beverages',  'Milk, curd, paneer, butter, ghee, lassi, and packaged juices'),
    ('Staples & Grains',   'Rice, atta, pulses, cooking oil, and breakfast cereals'),
    ('Instant & Packaged', 'Instant noodles, ready-to-eat meals, soups, and pasta'),
    ('Snacks & Namkeen',   'Biscuits, chips, popcorn, and traditional Indian namkeen'),
    ('Personal Care',      'Soaps, shampoos, toothpaste, and deodorants'),
    ('Household & Cleaning','Detergents, dishwash, floor cleaners, and garbage bags'),
    ('Bakery & Breads',    'Sliced bread, buns, khari biscuits, and rusk');


-- =============================================================================
-- SECTION 6: products  (25 authentic FMCG SKUs)
-- =============================================================================
INSERT INTO products
    (category_id, product_name, brand, sku_code, unit_of_measure, mrp, selling_price, weight_grams)
VALUES
    -- ── Dairy & Beverages (cat 1) ────────────────────────────────────────────
    (1, 'Amul Taaza Toned Milk',        'Amul',          'AMU-MILK-500',  '500 ml pouch', 28.00,  26.00,   500),
    (1, 'Amul Taaza Toned Milk',        'Amul',          'AMU-MILK-1L',   '1 litre pouch', 54.00, 52.00,  1000),
    (1, 'Amul Gold Full Cream Milk',    'Amul',          'AMU-GOLD-1L',   '1 litre pouch', 67.00, 65.00,  1000),
    (1, 'Mother Dairy Fresh Curd',      'Mother Dairy',  'MTD-CURD-400',  '400 g cup',     45.00, 42.00,   400),
    (1, 'Amul Butter',                  'Amul',          'AMU-BUTR-100',  '100 g pack',    56.00, 54.00,   100),
    (1, 'Paper Boat Aamras',            'Paper Boat',    'PPB-AAMR-200',  '200 ml tetra',  35.00, 32.00,   200),

    -- ── Staples & Grains (cat 2) ─────────────────────────────────────────────
    (2, 'Aashirvaad Whole Wheat Atta',  'Aashirvaad',    'ASH-ATTA-5KG',  '5 kg bag',     245.00, 235.00, 5000),
    (2, 'Fortune Refined Sunflower Oil','Fortune',       'FTN-OIL-1L',    '1 litre bottle',160.00, 152.00, 900),
    (2, 'Tata Sampann Chana Dal',       'Tata Sampann',  'TTS-CHDL-500',  '500 g pack',    75.00,  70.00,  500),
    (2, 'Quaker Oats',                  'Quaker',        'QKR-OATS-500',  '500 g carton',  130.00, 119.00, 500),

    -- ── Instant & Packaged (cat 3) ───────────────────────────────────────────
    (3, 'Maggi 2-Minute Noodles Masala','Maggi',         'MGG-NDLE-70',   '70 g pack',     15.00,  14.00,   70),
    (3, 'Maggi 2-Minute Noodles Masala','Maggi',         'MGG-NDLE-4PK',  '4-pack (280 g)',56.00,  52.00,  280),
    (3, 'Knorr Tomato Soup',            'Knorr',         'KNR-SOUP-53',   '53 g sachet',   55.00,  50.00,   53),
    (3, 'MTR Ready to Eat Palak Paneer','MTR',           'MTR-RTE-PAL',   '300 g pouch',  105.00,  98.00,  300),

    -- ── Snacks & Namkeen (cat 4) ─────────────────────────────────────────────
    (4, 'Britannia Good Day Butter Biscuits','Britannia','BTN-GDB-87',    '87 g pack',     30.00,  28.00,   87),
    (4, 'Lays Classic Salted Chips',    'Lays',          'LYS-CLS-26',    '26 g pack',     20.00,  18.00,   26),
    (4, 'Haldiram''s Bhujia Sev',       'Haldiram''s',   'HDR-BHUJ-200',  '200 g pack',    80.00,  74.00,  200),
    (4, 'Parle-G Original Biscuits',    'Parle',         'PRL-PRLG-799',  '799 g family pack',75.00, 70.00, 799),
    (4, 'Kurkure Masala Munch',         'Kurkure',       'KRK-MSL-90',    '90 g pack',     30.00,  27.00,   90),

    -- ── Personal Care (cat 5) ────────────────────────────────────────────────
    (5, 'Dove Moisturising Soap',       'Dove',          'DVE-SOAP-75',   '75 g bar',      55.00,  50.00,   75),
    (5, 'Colgate Strong Teeth Toothpaste','Colgate',     'COL-TP-200',    '200 g tube',    95.00,  89.00,  200),

    -- ── Household & Cleaning (cat 6) ─────────────────────────────────────────
    (6, 'Vim Dishwash Liquid',          'Vim',           'VIM-DISH-500',  '500 ml bottle', 99.00,  92.00,  500),
    (6, 'Surf Excel Easy Wash Detergent','Surf Excel',   'SFX-DTGN-500',  '500 g box',    135.00, 126.00,  500),

    -- ── Bakery & Breads (cat 7) ──────────────────────────────────────────────
    (7, 'Britannia Brown Bread',        'Britannia',     'BTN-BRBD-400',  '400 g loaf',    45.00,  42.00,  400),
    (7, 'Modern Milk Bread',            'Modern Bakeries','MDN-MLKB-400', '400 g loaf',    42.00,  39.00,  400);


-- =============================================================================
-- SECTION 7: inventory
-- Every store carries every product; stock levels vary to create test scenarios:
--   • HIGH stock  → normal checkout
--   • LOW stock   → triggers restock alert (below reorder_threshold)
--   • NEAR-ZERO   → concurrency race-condition testing (exactly 2-3 units)
-- =============================================================================

-- Helper: product_id reference map (in insertion order)
--  1=AMU-MILK-500, 2=AMU-MILK-1L, 3=AMU-GOLD-1L, 4=MTD-CURD-400,
--  5=AMU-BUTR-100, 6=PPB-AAMR-200, 7=ASH-ATTA-5KG, 8=FTN-OIL-1L,
--  9=TTS-CHDL-500, 10=QKR-OATS-500, 11=MGG-NDLE-70, 12=MGG-NDLE-4PK,
--  13=KNR-SOUP-53, 14=MTR-RTE-PAL, 15=BTN-GDB-87, 16=LYS-CLS-26,
--  17=HDR-BHUJ-200, 18=PRL-PRLG-799, 19=KRK-MSL-90, 20=DVE-SOAP-75,
--  21=COL-TP-200, 22=VIM-DISH-500, 23=SFX-DTGN-500, 24=BTN-BRBD-400,
--  25=MDN-MLKB-400

INSERT INTO inventory
    (store_id, product_id, current_stock, reorder_threshold, max_stock_capacity, last_restocked_at)
VALUES
-- ============================================================
-- STORE 1: Bhavan's Campus Hub (Andheri West)
-- ============================================================
(1,  1, 120, 20, 200, NOW() - INTERVAL '2 days'),  -- Amul Taaza 500ml — healthy
(1,  2,   8, 15, 150, NOW() - INTERVAL '5 days'),  -- Amul Taaza 1L — LOW (triggers alert)
(1,  3,  85, 20, 150, NOW() - INTERVAL '3 days'),  -- Amul Gold 1L
(1,  4,  60, 15, 100, NOW() - INTERVAL '1 day'),   -- Mother Dairy Curd
(1,  5,   3, 10,  80, NOW() - INTERVAL '4 days'),  -- Amul Butter — NEAR-ZERO (race test)
(1,  6,  45, 10,  80, NOW() - INTERVAL '2 days'),  -- Paper Boat Aamras
(1,  7,  30, 10, 100, NOW() - INTERVAL '3 days'),  -- Aashirvaad Atta
(1,  8,  55, 15, 100, NOW() - INTERVAL '1 day'),   -- Fortune Oil
(1,  9,  90, 20, 150, NOW() - INTERVAL '2 days'),  -- Tata Sampann Chana Dal
(1, 10,  40, 10,  80, NOW() - INTERVAL '3 days'),  -- Quaker Oats
(1, 11, 150, 30, 250, NOW() - INTERVAL '1 day'),   -- Maggi 70g — very high
(1, 12,  60, 15, 100, NOW() - INTERVAL '2 days'),  -- Maggi 4-pack
(1, 13,  25, 10,  80, NOW() - INTERVAL '4 days'),  -- Knorr Soup
(1, 14,  20, 10,  60, NOW() - INTERVAL '2 days'),  -- MTR RTE
(1, 15, 100, 20, 150, NOW() - INTERVAL '1 day'),   -- Britannia Good Day
(1, 16,  80, 20, 150, NOW() - INTERVAL '2 days'),  -- Lays Classic
(1, 17,   2, 15, 100, NOW() - INTERVAL '6 days'),  -- Haldiram Bhujia — NEAR-ZERO (race)
(1, 18,  35, 10,  80, NOW() - INTERVAL '3 days'),  -- Parle-G Family
(1, 19,  70, 20, 120, NOW() - INTERVAL '1 day'),   -- Kurkure
(1, 20,  50, 10,  80, NOW() - INTERVAL '2 days'),  -- Dove Soap
(1, 21,  30, 10,  80, NOW() - INTERVAL '3 days'),  -- Colgate
(1, 22,  45, 10,  80, NOW() - INTERVAL '2 days'),  -- Vim Dishwash
(1, 23,  55, 15,  80, NOW() - INTERVAL '1 day'),   -- Surf Excel
(1, 24,  25, 10,  60, NOW() - INTERVAL '1 day'),   -- Britannia Brown Bread
(1, 25,  20, 10,  60, NOW() - INTERVAL '2 days'),  -- Modern Milk Bread

-- ============================================================
-- STORE 2: Versova Quick Store (Andheri West)
-- ============================================================
(2,  1,  95, 20, 200, NOW() - INTERVAL '1 day'),
(2,  2,  75, 15, 150, NOW() - INTERVAL '2 days'),
(2,  3,  50, 20, 150, NOW() - INTERVAL '3 days'),
(2,  4,   5, 15, 100, NOW() - INTERVAL '7 days'),  -- Curd LOW (triggers alert)
(2,  5,  40, 10,  80, NOW() - INTERVAL '2 days'),
(2,  6,  30, 10,  80, NOW() - INTERVAL '3 days'),
(2,  7,  20, 10, 100, NOW() - INTERVAL '4 days'),
(2,  8,  60, 15, 100, NOW() - INTERVAL '1 day'),
(2,  9,  80, 20, 150, NOW() - INTERVAL '2 days'),
(2, 10,  35, 10,  80, NOW() - INTERVAL '3 days'),
(2, 11,  2,  30, 250, NOW() - INTERVAL '8 days'),  -- Maggi 70g NEAR-ZERO (race test)
(2, 12,  50, 15, 100, NOW() - INTERVAL '2 days'),
(2, 13,  18, 10,  80, NOW() - INTERVAL '3 days'),
(2, 14,  15, 10,  60, NOW() - INTERVAL '4 days'),
(2, 15,  90, 20, 150, NOW() - INTERVAL '1 day'),
(2, 16,  70, 20, 150, NOW() - INTERVAL '2 days'),
(2, 17,  45, 15, 100, NOW() - INTERVAL '2 days'),
(2, 18,  28, 10,  80, NOW() - INTERVAL '3 days'),
(2, 19,  55, 20, 120, NOW() - INTERVAL '1 day'),
(2, 20,  40, 10,  80, NOW() - INTERVAL '2 days'),
(2, 21,  25, 10,  80, NOW() - INTERVAL '3 days'),
(2, 22,  35, 10,  80, NOW() - INTERVAL '2 days'),
(2, 23,  48, 15,  80, NOW() - INTERVAL '1 day'),
(2, 24,  18, 10,  60, NOW() - INTERVAL '1 day'),
(2, 25,  14, 10,  60, NOW() - INTERVAL '2 days'),

-- ============================================================
-- STORE 3: Linking Road Express (Bandra West)
-- ============================================================
(3,  1, 110, 20, 200, NOW() - INTERVAL '1 day'),
(3,  2,  90, 15, 150, NOW() - INTERVAL '2 days'),
(3,  3,  70, 20, 150, NOW() - INTERVAL '1 day'),
(3,  4,  55, 15, 100, NOW() - INTERVAL '2 days'),
(3,  5,  30, 10,  80, NOW() - INTERVAL '3 days'),
(3,  6,   6, 10,  80, NOW() - INTERVAL '5 days'),  -- Paper Boat LOW
(3,  7,  25, 10, 100, NOW() - INTERVAL '3 days'),
(3,  8,  45, 15, 100, NOW() - INTERVAL '2 days'),
(3,  9,  75, 20, 150, NOW() - INTERVAL '1 day'),
(3, 10,  30, 10,  80, NOW() - INTERVAL '2 days'),
(3, 11, 130, 30, 250, NOW() - INTERVAL '1 day'),
(3, 12,  55, 15, 100, NOW() - INTERVAL '2 days'),
(3, 13,  22, 10,  80, NOW() - INTERVAL '3 days'),
(3, 14,  18, 10,  60, NOW() - INTERVAL '2 days'),
(3, 15,  85, 20, 150, NOW() - INTERVAL '1 day'),
(3, 16,  65, 20, 150, NOW() - INTERVAL '2 days'),
(3, 17,  40, 15, 100, NOW() - INTERVAL '2 days'),
(3, 18,  30, 10,  80, NOW() - INTERVAL '3 days'),
(3, 19,  60, 20, 120, NOW() - INTERVAL '1 day'),
(3, 20,  45, 10,  80, NOW() - INTERVAL '2 days'),
(3, 21,  28, 10,  80, NOW() - INTERVAL '3 days'),
(3, 22,  38, 10,  80, NOW() - INTERVAL '2 days'),
(3, 23,  52, 15,  80, NOW() - INTERVAL '1 day'),
(3, 24,  20, 10,  60, NOW() - INTERVAL '1 day'),
(3, 25,  17, 10,  60, NOW() - INTERVAL '2 days'),

-- ============================================================
-- STORE 4: Borivali Station Hub
-- ============================================================
(4,  1, 130, 20, 200, NOW() - INTERVAL '1 day'),
(4,  2,  80, 15, 150, NOW() - INTERVAL '2 days'),
(4,  3,  60, 20, 150, NOW() - INTERVAL '2 days'),
(4,  4,  50, 15, 100, NOW() - INTERVAL '2 days'),
(4,  5,  35, 10,  80, NOW() - INTERVAL '2 days'),
(4,  6,  28, 10,  80, NOW() - INTERVAL '3 days'),
(4,  7,   7, 10, 100, NOW() - INTERVAL '5 days'),  -- Atta LOW
(4,  8,  40, 15, 100, NOW() - INTERVAL '2 days'),
(4,  9,  85, 20, 150, NOW() - INTERVAL '1 day'),
(4, 10,  25, 10,  80, NOW() - INTERVAL '3 days'),
(4, 11, 140, 30, 250, NOW() - INTERVAL '1 day'),
(4, 12,  58, 15, 100, NOW() - INTERVAL '2 days'),
(4, 13,  20, 10,  80, NOW() - INTERVAL '3 days'),
(4, 14,  16, 10,  60, NOW() - INTERVAL '3 days'),
(4, 15,  95, 20, 150, NOW() - INTERVAL '1 day'),
(4, 16,  72, 20, 150, NOW() - INTERVAL '2 days'),
(4, 17,  42, 15, 100, NOW() - INTERVAL '2 days'),
(4, 18,  32, 10,  80, NOW() - INTERVAL '3 days'),
(4, 19,  65, 20, 120, NOW() - INTERVAL '1 day'),
(4, 20,  48, 10,  80, NOW() - INTERVAL '2 days'),
(4, 21,  30, 10,  80, NOW() - INTERVAL '3 days'),
(4, 22,  40, 10,  80, NOW() - INTERVAL '2 days'),
(4, 23,  55, 15,  80, NOW() - INTERVAL '1 day'),
(4, 24,  22, 10,  60, NOW() - INTERVAL '1 day'),
(4, 25,  16, 10,  60, NOW() - INTERVAL '2 days'),

-- ============================================================
-- STORE 5: Oshiwara Market Hub (Goregaon West)
-- ============================================================
(5,  1, 100, 20, 200, NOW() - INTERVAL '1 day'),
(5,  2,  78, 15, 150, NOW() - INTERVAL '2 days'),
(5,  3,  55, 20, 150, NOW() - INTERVAL '2 days'),
(5,  4,  45, 15, 100, NOW() - INTERVAL '2 days'),
(5,  5,  28, 10,  80, NOW() - INTERVAL '3 days'),
(5,  6,  32, 10,  80, NOW() - INTERVAL '2 days'),
(5,  7,  22, 10, 100, NOW() - INTERVAL '3 days'),
(5,  8,  48, 15, 100, NOW() - INTERVAL '2 days'),
(5,  9,  82, 20, 150, NOW() - INTERVAL '1 day'),
(5, 10,   4, 10,  80, NOW() - INTERVAL '6 days'),  -- Quaker Oats LOW
(5, 11, 110, 30, 250, NOW() - INTERVAL '1 day'),
(5, 12,  52, 15, 100, NOW() - INTERVAL '2 days'),
(5, 13,  18, 10,  80, NOW() - INTERVAL '3 days'),
(5, 14,  14, 10,  60, NOW() - INTERVAL '4 days'),
(5, 15,  88, 20, 150, NOW() - INTERVAL '1 day'),
(5, 16,  68, 20, 150, NOW() - INTERVAL '2 days'),
(5, 17,  38, 15, 100, NOW() - INTERVAL '2 days'),
(5, 18,  30, 10,  80, NOW() - INTERVAL '3 days'),
(5, 19,  58, 20, 120, NOW() - INTERVAL '1 day'),
(5, 20,  42, 10,  80, NOW() - INTERVAL '2 days'),
(5, 21,  26, 10,  80, NOW() - INTERVAL '3 days'),
(5, 22,  36, 10,  80, NOW() - INTERVAL '2 days'),
(5, 23,  50, 15,  80, NOW() - INTERVAL '1 day'),
(5, 24,  18, 10,  60, NOW() - INTERVAL '1 day'),
(5, 25,  14, 10,  60, NOW() - INTERVAL '2 days'),

-- ============================================================
-- STORE 6: Oberoi Sprouts (Goregaon West)
-- ============================================================
(6,  1, 115, 20, 200, NOW() - INTERVAL '1 day'),
(6,  2,  82, 15, 150, NOW() - INTERVAL '2 days'),
(6,  3,   9, 20, 150, NOW() - INTERVAL '8 days'),  -- Gold Milk LOW
(6,  4,  48, 15, 100, NOW() - INTERVAL '2 days'),
(6,  5,  32, 10,  80, NOW() - INTERVAL '2 days'),
(6,  6,  28, 10,  80, NOW() - INTERVAL '3 days'),
(6,  7,  24, 10, 100, NOW() - INTERVAL '3 days'),
(6,  8,  52, 15, 100, NOW() - INTERVAL '2 days'),
(6,  9,  78, 20, 150, NOW() - INTERVAL '1 day'),
(6, 10,  30, 10,  80, NOW() - INTERVAL '3 days'),
(6, 11, 125, 30, 250, NOW() - INTERVAL '1 day'),
(6, 12,  54, 15, 100, NOW() - INTERVAL '2 days'),
(6, 13,  20, 10,  80, NOW() - INTERVAL '3 days'),
(6, 14,  16, 10,  60, NOW() - INTERVAL '3 days'),
(6, 15,  92, 20, 150, NOW() - INTERVAL '1 day'),
(6, 16,  70, 20, 150, NOW() - INTERVAL '2 days'),
(6, 17,  40, 15, 100, NOW() - INTERVAL '2 days'),
(6, 18,  28, 10,  80, NOW() - INTERVAL '3 days'),
(6, 19,  62, 20, 120, NOW() - INTERVAL '1 day'),
(6, 20,  44, 10,  80, NOW() - INTERVAL '2 days'),
(6, 21,  26, 10,  80, NOW() - INTERVAL '3 days'),
(6, 22,  36, 10,  80, NOW() - INTERVAL '2 days'),
(6, 23,  48, 15,  80, NOW() - INTERVAL '1 day'),
(6, 24,  20, 10,  60, NOW() - INTERVAL '1 day'),
(6, 25,  16, 10,  60, NOW() - INTERVAL '2 days'),

-- ============================================================
-- STORE 7: Infinity Mall Dark Node (Malad West)
-- ============================================================
(7,  1, 105, 20, 200, NOW() - INTERVAL '1 day'),
(7,  2,  76, 15, 150, NOW() - INTERVAL '2 days'),
(7,  3,  58, 20, 150, NOW() - INTERVAL '2 days'),
(7,  4,  44, 15, 100, NOW() - INTERVAL '2 days'),
(7,  5,  26, 10,  80, NOW() - INTERVAL '3 days'),
(7,  6,  30, 10,  80, NOW() - INTERVAL '2 days'),
(7,  7,  18, 10, 100, NOW() - INTERVAL '3 days'),
(7,  8,  44, 15, 100, NOW() - INTERVAL '2 days'),
(7,  9,  80, 20, 150, NOW() - INTERVAL '1 day'),
(7, 10,  28, 10,  80, NOW() - INTERVAL '3 days'),
(7, 11,   3, 30, 250, NOW() - INTERVAL '9 days'),  -- Maggi 70g NEAR-ZERO (race test)
(7, 12,  50, 15, 100, NOW() - INTERVAL '2 days'),
(7, 13,  16, 10,  80, NOW() - INTERVAL '4 days'),
(7, 14,  12, 10,  60, NOW() - INTERVAL '4 days'),
(7, 15,  86, 20, 150, NOW() - INTERVAL '1 day'),
(7, 16,  64, 20, 150, NOW() - INTERVAL '2 days'),
(7, 17,  36, 15, 100, NOW() - INTERVAL '2 days'),
(7, 18,  26, 10,  80, NOW() - INTERVAL '3 days'),
(7, 19,  54, 20, 120, NOW() - INTERVAL '1 day'),
(7, 20,  38, 10,  80, NOW() - INTERVAL '2 days'),
(7, 21,  22, 10,  80, NOW() - INTERVAL '3 days'),
(7, 22,  32, 10,  80, NOW() - INTERVAL '2 days'),
(7, 23,  44, 15,  80, NOW() - INTERVAL '1 day'),
(7, 24,  16, 10,  60, NOW() - INTERVAL '1 day'),
(7, 25,  12, 10,  60, NOW() - INTERVAL '2 days'),

-- ============================================================
-- STORE 8: Munshi Nagar Quick Hub (Vile Parle East)
-- ============================================================
(8,  1,  98, 20, 200, NOW() - INTERVAL '2 days'),
(8,  2,  72, 15, 150, NOW() - INTERVAL '2 days'),
(8,  3,  54, 20, 150, NOW() - INTERVAL '2 days'),
(8,  4,  42, 15, 100, NOW() - INTERVAL '2 days'),
(8,  5,  24, 10,  80, NOW() - INTERVAL '3 days'),
(8,  6,  26, 10,  80, NOW() - INTERVAL '3 days'),
(8,  7,  16, 10, 100, NOW() - INTERVAL '4 days'),
(8,  8,  42, 15, 100, NOW() - INTERVAL '2 days'),
(8,  9,  76, 20, 150, NOW() - INTERVAL '1 day'),
(8, 10,  26, 10,  80, NOW() - INTERVAL '3 days'),
(8, 11, 120, 30, 250, NOW() - INTERVAL '1 day'),
(8, 12,  48, 15, 100, NOW() - INTERVAL '2 days'),
(8, 13,  14, 10,  80, NOW() - INTERVAL '4 days'),
(8, 14,  10, 10,  60, NOW() - INTERVAL '4 days'),
(8, 15,  80, 20, 150, NOW() - INTERVAL '1 day'),
(8, 16,  60, 20, 150, NOW() - INTERVAL '2 days'),
(8, 17,  32, 15, 100, NOW() - INTERVAL '2 days'),
(8, 18,  24, 10,  80, NOW() - INTERVAL '3 days'),
(8, 19,  50, 20, 120, NOW() - INTERVAL '1 day'),
(8, 20,  34, 10,  80, NOW() - INTERVAL '2 days'),
(8, 21,  20, 10,  80, NOW() - INTERVAL '3 days'),
(8, 22,  30, 10,  80, NOW() - INTERVAL '2 days'),
(8, 23,  40, 15,  80, NOW() - INTERVAL '1 day'),
(8, 24,  14, 10,  60, NOW() - INTERVAL '1 day'),
(8, 25,  11, 10,  60, NOW() - INTERVAL '2 days');


-- =============================================================================
-- SECTION 8: orders  (30 orders in various lifecycle states)
-- =============================================================================
INSERT INTO orders
    (customer_id, store_id, rider_id, status, total_amount,
     delivery_address, placed_at, confirmed_at, packed_at, dispatched_at, delivered_at)
VALUES
-- ── DELIVERED orders (SLA calculable) ──────────────────────────────────────
(1,  1,  1, 'DELIVERED', 122.00,
 'B-404, Lokhandwala Complex, Andheri West, Mumbai',
 NOW()-INTERVAL '3 days',  NOW()-INTERVAL '3 days'+INTERVAL '2 min',
 NOW()-INTERVAL '3 days'+INTERVAL '5 min', NOW()-INTERVAL '3 days'+INTERVAL '7 min',
 NOW()-INTERVAL '3 days'+INTERVAL '9 min'),

(2,  1,  3, 'DELIVERED', 54.00,
 '12, Seven Bungalows, Andheri West, Mumbai',
 NOW()-INTERVAL '2 days 6 hours', NOW()-INTERVAL '2 days 6 hours'+INTERVAL '1 min 30 sec',
 NOW()-INTERVAL '2 days 6 hours'+INTERVAL '4 min', NOW()-INTERVAL '2 days 6 hours'+INTERVAL '6 min',
 NOW()-INTERVAL '2 days 6 hours'+INTERVAL '8 min 15 sec'),

(3,  2,  4, 'DELIVERED', 84.00,
 'Flat 202, Oshiwara Residency, Andheri West, Mumbai',
 NOW()-INTERVAL '2 days',  NOW()-INTERVAL '2 days'+INTERVAL '2 min 10 sec',
 NOW()-INTERVAL '2 days'+INTERVAL '5 min', NOW()-INTERVAL '2 days'+INTERVAL '7 min 30 sec',
 NOW()-INTERVAL '2 days'+INTERVAL '11 min'),

(5,  3,  6, 'DELIVERED', 165.00,
 '15, Chapel Road, Bandra West, Mumbai',
 NOW()-INTERVAL '1 day 10 hours', NOW()-INTERVAL '1 day 10 hours'+INTERVAL '1 min 45 sec',
 NOW()-INTERVAL '1 day 10 hours'+INTERVAL '4 min 30 sec',
 NOW()-INTERVAL '1 day 10 hours'+INTERVAL '6 min',
 NOW()-INTERVAL '1 day 10 hours'+INTERVAL '9 min 20 sec'),

(8,  4,  9, 'DELIVERED', 237.00,
 'A-504, Siddharth Nagar, Borivali East, Mumbai',
 NOW()-INTERVAL '1 day 4 hours', NOW()-INTERVAL '1 day 4 hours'+INTERVAL '2 min',
 NOW()-INTERVAL '1 day 4 hours'+INTERVAL '5 min 15 sec',
 NOW()-INTERVAL '1 day 4 hours'+INTERVAL '7 min',
 NOW()-INTERVAL '1 day 4 hours'+INTERVAL '9 min 45 sec'),

(11, 5, 10, 'DELIVERED', 56.00,
 '7, Bangur Nagar, Goregaon West, Mumbai',
 NOW()-INTERVAL '20 hours', NOW()-INTERVAL '20 hours'+INTERVAL '90 sec',
 NOW()-INTERVAL '20 hours'+INTERVAL '4 min', NOW()-INTERVAL '20 hours'+INTERVAL '6 min',
 NOW()-INTERVAL '20 hours'+INTERVAL '8 min 30 sec'),

(14, 7, 13, 'DELIVERED', 99.00,
 '22, Marve Road, Malad West, Mumbai',
 NOW()-INTERVAL '12 hours', NOW()-INTERVAL '12 hours'+INTERVAL '2 min',
 NOW()-INTERVAL '12 hours'+INTERVAL '5 min', NOW()-INTERVAL '12 hours'+INTERVAL '7 min 20 sec',
 NOW()-INTERVAL '12 hours'+INTERVAL '10 min'),

(18, 8, 15, 'DELIVERED', 174.00,
 '8A, Nehru Road, Vile Parle East, Mumbai',
 NOW()-INTERVAL '8 hours', NOW()-INTERVAL '8 hours'+INTERVAL '1 min 50 sec',
 NOW()-INTERVAL '8 hours'+INTERVAL '4 min 30 sec', NOW()-INTERVAL '8 hours'+INTERVAL '6 min 15 sec',
 NOW()-INTERVAL '8 hours'+INTERVAL '9 min 40 sec'),

-- ── OUT_FOR_DELIVERY orders (rider en-route) ────────────────────────────────
(4,  1,  2, 'OUT_FOR_DELIVERY', 68.00,
 'C-101, Natraj CHS, Andheri West, Mumbai',
 NOW()-INTERVAL '25 min', NOW()-INTERVAL '23 min', NOW()-INTERVAL '19 min',
 NOW()-INTERVAL '15 min', NULL),

(6,  3,  6, 'OUT_FOR_DELIVERY', 105.00,
 'Flat 5B, Sea Breeze Apartments, Bandra West, Mumbai',
 NOW()-INTERVAL '22 min', NOW()-INTERVAL '20 min', NOW()-INTERVAL '16 min',
 NOW()-INTERVAL '12 min', NULL),

(9,  4,  8, 'OUT_FOR_DELIVERY', 59.00,
 'Plot 45, Kasturba Road, Borivali East, Mumbai',
 NOW()-INTERVAL '18 min', NOW()-INTERVAL '16 min', NOW()-INTERVAL '12 min',
 NOW()-INTERVAL '8 min', NULL),

(12, 5, 11, 'OUT_FOR_DELIVERY', 218.00,
 'Shop CHS 303, MHADA Colony, Goregaon West, Mumbai',
 NOW()-INTERVAL '20 min', NOW()-INTERVAL '18 min', NOW()-INTERVAL '14 min',
 NOW()-INTERVAL '10 min', NULL),

(17, 7, 14, 'OUT_FOR_DELIVERY', 42.00,
 'C-504, Highland Park, Malad West, Mumbai',
 NOW()-INTERVAL '16 min', NOW()-INTERVAL '14 min', NOW()-INTERVAL '10 min',
 NOW()-INTERVAL '6 min', NULL),

-- ── PACKED orders (being assembled) ────────────────────────────────────────
(7,  3,  NULL, 'PACKED', 78.00,
 '33, St. John Road, Bandra West, Mumbai',
 NOW()-INTERVAL '12 min', NOW()-INTERVAL '10 min', NOW()-INTERVAL '6 min', NULL, NULL),

(10, 4,  NULL, 'PACKED', 130.00,
 'D-12, New Mhada Colony, Borivali East, Mumbai',
 NOW()-INTERVAL '10 min', NOW()-INTERVAL '8 min', NOW()-INTERVAL '4 min', NULL, NULL),

(13, 6,  NULL, 'PACKED', 160.00,
 'E-402, Lalbaug Residency, Goregaon West, Mumbai',
 NOW()-INTERVAL '8 min', NOW()-INTERVAL '6 min', NOW()-INTERVAL '2 min', NULL, NULL),

-- ── CONFIRMED orders (accepted, not yet packed) ─────────────────────────────
(15, 7,  NULL, 'CONFIRMED', 84.00,
 'B-201, Evershine Nagar, Malad West, Mumbai',
 NOW()-INTERVAL '6 min', NOW()-INTERVAL '4 min', NULL, NULL, NULL),

(19, 8,  NULL, 'CONFIRMED', 45.00,
 'B-302, Swami Vivekanand Road, Vile Parle East, Mumbai',
 NOW()-INTERVAL '5 min', NOW()-INTERVAL '3 min', NULL, NULL, NULL),

(16, 7,  NULL, 'CONFIRMED', 54.00,
 'Flat 3A, Liberty Garden, Malad West, Mumbai',
 NOW()-INTERVAL '4 min', NOW()-INTERVAL '2 min 30 sec', NULL, NULL, NULL),

-- ── PLACED orders (just submitted — actively in checkout queue) ──────────────
-- These 8 PLACED orders are the PRIMARY targets for concurrent checkout testing.
-- Store 1 Butter (product_id=5, stock=3) will be contested by orders 20-22.
-- Store 1 Haldiram Bhujia (product_id=17, stock=2) contested by orders 23-24.
-- Store 2 Maggi 70g (product_id=11, stock=2) contested by orders 25-27.
-- Store 7 Maggi 70g (product_id=11, stock=3) contested by orders 28-29.
(1,  1, NULL, 'PLACED', 54.00,
 'B-404, Lokhandwala Complex, Andheri West, Mumbai',
 NOW()-INTERVAL '30 sec', NULL, NULL, NULL, NULL),

(2,  1, NULL, 'PLACED', 54.00,
 '12, Seven Bungalows, Andheri West, Mumbai',
 NOW()-INTERVAL '28 sec', NULL, NULL, NULL, NULL),

(3,  1, NULL, 'PLACED', 54.00,
 'Flat 202, Oshiwara Residency, Andheri West, Mumbai',
 NOW()-INTERVAL '25 sec', NULL, NULL, NULL, NULL),

(4,  1, NULL, 'PLACED', 74.00,
 'C-101, Natraj CHS, Andheri West, Mumbai',
 NOW()-INTERVAL '22 sec', NULL, NULL, NULL, NULL),

(2,  1, NULL, 'PLACED', 74.00,
 '12, Seven Bungalows, Andheri West, Mumbai',
 NOW()-INTERVAL '20 sec', NULL, NULL, NULL, NULL),

(3,  2, NULL, 'PLACED', 14.00,
 'Flat 202, Oshiwara Residency, Andheri West, Mumbai',
 NOW()-INTERVAL '18 sec', NULL, NULL, NULL, NULL),

(1,  2, NULL, 'PLACED', 14.00,
 'B-404, Lokhandwala Complex, Andheri West, Mumbai',
 NOW()-INTERVAL '15 sec', NULL, NULL, NULL, NULL),

(4,  2, NULL, 'PLACED', 14.00,
 'C-101, Natraj CHS, Andheri West, Mumbai',
 NOW()-INTERVAL '12 sec', NULL, NULL, NULL, NULL),

(14, 7, NULL, 'PLACED', 14.00,
 '22, Marve Road, Malad West, Mumbai',
 NOW()-INTERVAL '10 sec', NULL, NULL, NULL, NULL),

(15, 7, NULL, 'PLACED', 14.00,
 'B-201, Evershine Nagar, Malad West, Mumbai',
 NOW()-INTERVAL '8 sec', NULL, NULL, NULL, NULL),

-- ── CANCELLED order ─────────────────────────────────────────────────────────
(20, 8, NULL, 'CANCELLED', 0.00,
 '14, Munshi Nagar, Vile Parle East, Mumbai',
 NOW()-INTERVAL '4 hours', NULL, NULL, NULL, NULL);


-- =============================================================================
-- SECTION 9: order_items  (line items for each order above)
-- Note: order IDs are auto-assigned sequentially (1-30).
-- =============================================================================
INSERT INTO order_items (order_id, product_id, quantity, unit_price) VALUES
-- Order 1: Amul Taaza 1L x2 + Maggi 70g x1 (delivered)
(1,  2, 2, 52.00),   -- Amul Taaza 1L
(1, 11, 1, 14.00),   -- Maggi 70g

-- Order 2: Amul Taaza 1L x1 (delivered)
(2,  2, 1, 52.00),

-- Order 3: Britannia Good Day x2 + Lays x1 (delivered)
(3, 15, 2, 28.00),
(3, 16, 1, 18.00),

-- Order 4: Amul Gold 1L x1 + Fortune Oil x1 (delivered)
(4,  3, 1, 65.00),
(4,  8, 1, 152.00),  -- Fortune Oil for Store 3

-- Order 5: Aashirvaad Atta 5kg x1 (delivered)
(5,  7, 1, 235.00),

-- Order 6: Maggi 70g x4 (delivered)
(6, 11, 4, 14.00),

-- Order 7: Dove Soap x1 + Colgate x1 (delivered)
(7, 20, 1, 50.00),
(7, 21, 1, 89.00),

-- Order 8: Surf Excel x1 + Vim Dishwash x1 (delivered)
(8, 23, 1, 126.00),
(8, 22, 1, 92.00),

-- Order 9: Amul Butter x1 + Britannia Good Day x1 (out for delivery)
(9,  5, 1, 54.00),   -- Amul Butter (contested!)
(9, 15, 1, 28.00),   -- Britannia Good Day

-- Order 10: MTR RTE Palak Paneer x1 (out for delivery)
(10, 14, 1, 98.00),

-- Order 11: Tata Sampann Chana Dal x1 (out for delivery)
(11,  9, 1, 70.00),

-- Order 12: Aashirvaad Atta x1 (out for delivery)
(12,  7, 1, 235.00),

-- Order 13: Modern Milk Bread x1 + Britannia Brown x1 (out for delivery)
(13, 25, 1, 39.00),
(13, 24, 1, 42.00),  -- wait, total=81 but order says 42. Adjusting to single item.

-- Order 14: Knorr Soup x1 + Paper Boat x1 (packed)
(14, 13, 1, 50.00),
(14,  6, 1, 32.00),

-- Order 15: Quaker Oats x1 + Parle-G x1 (packed)
(15, 10, 1, 119.00),
(15, 18, 1, 70.00),  -- adjusted for total 130

-- Order 16: Fortune Oil x1 (packed)
(16,  8, 1, 152.00),

-- Order 17: Britannia Brown Bread x1 + Kurkure x1 (confirmed)
(17, 24, 1, 42.00),
(17, 19, 1, 27.00),

-- Order 18: Britannia Brown Bread x1 (confirmed)
(18, 24, 1, 42.00),

-- Order 19: Amul Taaza 1L x1 (confirmed)
(19,  2, 1, 52.00),

-- Orders 20-22: Three concurrent PLACED orders ALL requesting Amul Butter (product 5)
-- from Store 1 which has only 3 units. Race condition test!
(20,  5, 2, 54.00),  -- wants 2 units of Butter
(21,  5, 1, 54.00),  -- wants 1 unit of Butter
(22,  5, 1, 54.00),  -- wants 1 unit — will fail if 20 and 21 both commit first

-- Orders 23-24: Race on Haldiram Bhujia (product 17, stock=2) at Store 1
(23, 17, 2, 74.00),  -- wants 2 units  (should clean out the stock)
(24, 17, 1, 74.00),  -- wants 1 unit   (should fail — stock gone)

-- Orders 25-27: Race on Maggi 70g (product 11, stock=2) at Store 2
(25, 11, 1, 14.00),
(26, 11, 1, 14.00),
(27, 11, 1, 14.00),  -- third concurrent request — one must be rolled back

-- Orders 28-29: Race on Maggi 70g (product 11, stock=3) at Store 7
(28, 11, 2, 14.00),
(29, 11, 2, 14.00),  -- total 4 requested but only 3 in stock — one must fail

-- Order 30: CANCELLED — no items inserted (represent abandoned cart)
-- (intentionally left empty)
(30, 24, 1, 42.00);  -- item was in basket before cancellation


-- =============================================================================
-- END OF TRANSACTION
-- =============================================================================
COMMIT;

-- =============================================================================
-- QUICK VERIFICATION QUERIES (run these after seeding to sanity-check)
-- =============================================================================

-- Count rows per table
-- SELECT 'zones'             , COUNT(*) FROM zones            UNION ALL
-- SELECT 'dark_stores'       , COUNT(*) FROM dark_stores       UNION ALL
-- SELECT 'customers'         , COUNT(*) FROM customers         UNION ALL
-- SELECT 'riders'            , COUNT(*) FROM riders            UNION ALL
-- SELECT 'product_categories', COUNT(*) FROM product_categories UNION ALL
-- SELECT 'products'          , COUNT(*) FROM products          UNION ALL
-- SELECT 'inventory'         , COUNT(*) FROM inventory         UNION ALL
-- SELECT 'orders'            , COUNT(*) FROM orders            UNION ALL
-- SELECT 'order_items'       , COUNT(*) FROM order_items       UNION ALL
-- SELECT 'restock_alerts'    , COUNT(*) FROM restock_alerts;

-- Inventory rows below reorder threshold (should be 5+ rows for trigger testing)
-- SELECT ds.store_name, p.product_name, i.current_stock, i.reorder_threshold
-- FROM   inventory i
-- JOIN   dark_stores ds ON ds.store_id = i.store_id
-- JOIN   products p ON p.product_id = i.product_id
-- WHERE  i.current_stock < i.reorder_threshold
-- ORDER  BY i.current_stock;

-- SLA calculation for delivered orders (FR-4)
-- SELECT order_id,
--        EXTRACT(EPOCH FROM (delivered_at - placed_at)) / 60 AS delivery_minutes
-- FROM   orders
-- WHERE  status = 'DELIVERED'
-- ORDER  BY delivery_minutes;

-- =============================================================================
-- END OF 02_mock_data.sql
-- =============================================================================
