# PROJECT STATE & FULL REVERT ARCHIVE

**Date of Snapshot:** October 21, 2026
**Commit Hash:** `ddd154d` (Git repo initialized in root)

---

## 1. How to Revert the Entire Codebase Instantly

If you want to revert all frontend code back to the original or previous state:
```powershell
# To restore to the working role-isolated commit:
git checkout ddd154d -- .

# Or to discard temporary auth-bypass edits:
git restore .
```

---

## 2. Supabase Database Schema & Revert Details

All PostgreSQL DDL scripts, RLS policies, views, triggers, and transactions are permanently stored in the workspace:
1. `supabase/01_schema.sql`: Core tables (`zones`, `dark_stores`, `categories`, `products`, `inventory`, `customers`, `riders`, `orders`, `order_items`, `restock_alerts`).
2. `supabase/02_seed.sql`: Seed data for Kothrud (Zone `411038`), QuickMart Kothrud Hub, products, stock, demo customers and riders.
3. `supabase/03_place_order.sql`: ACID transaction `place_order(p_customer_id, p_store_id, p_items)`.
4. `supabase/04_low_stock_trigger_view.sql`: Automated restock trigger `trg_low_stock_alert` and `v_low_stock_inventory`.
5. `supabase/05_reports.sql`: Manager analytical reports.
6. `supabase/06_auth_rls.sql`: RLS security policies for customer, rider, and manager separation.
7. `supabase/07_register_account.sql`: Self-registration function `register_account(p_role, p_full_name)`.
8. `supabase/08_advance_delivery.sql`: Rider status workflow `advance_delivery(p_order_id)`.
9. `supabase/09_manage_products.sql`: Manager product management and catalog writes.

### Database Credentials (.env)
```env
VITE_SUPABASE_URL=https://shbgfhokfzvixvvbikte.supabase.co
VITE_SUPABASE_PUBLISHABLE_KEY=sb_publishable_I8bdFWpK0guY6B9i_DfCPg_Ktzom3pW
```

### Registered Accounts
- **Customer:** `test_customer_demo123@example.com` / `Password123!` (User ID: `89f03bc9-3ff3-4463-b2e3-5177372aa430`, Customer ID: `1`)
- **Rider:** `demo_rider@example.com` / `Password123!` (User ID: `c37c1fce-0dd5-47a7-b7f0-fa2d9f6cddb1`, Rider ID: `3`)
- **Manager:** `manager@demo.com` / `Password123!` (User ID: `d509d7f7-5630-402a-b4ec-7ba117a9a79e`)

---

## 3. Key Functionality & Modifications Made
1. **Rider Workspace:**
   - Nearest Dark Store Hub view (`QuickMart Kothrud`, 12 Karve Road, Zone `411038`, 3.0 km radius).
   - Live Customer Orders queue waiting at the hub with 1-click **Claim & Deliver**.
   - Active Deliveries progression (`Start Delivery` -> `Mark as Delivered`) + Customer direct call.
   - Delivery History & earnings counter (+₹65 per completed drop).
2. **Manager Workspace:**
   - Dark Store Central Operations console.
   - Live Customer Orders & Rider Dispatch table with rider assignment dropdown (`Demo Rider`, `Rohan Patil`, `Sana Khan`).
   - Inventory table with **+50 Quick Restock** button.
   - Automated Restock Alerts with 1-click resolution.
3. **Role Isolation:**
   - Access Isolation Gate prevents customer sessions from viewing manager/rider consoles on the same account.
