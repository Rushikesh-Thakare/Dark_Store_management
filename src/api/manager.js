import { supabase } from '../lib/supabase'

// All manager database calls live here, so the components only show data and call these functions.
// Rules and permissions stay in the database (RLS, the low-stock view, the save_product function).

export async function fetchDashboard() {
  const [inventory, lowStock, alerts, orders, orderCount, categories] = await Promise.all([
    supabase.from('inventory')
      .select('store_id, product_id, current_stock, reorder_threshold, products(product_name, price, is_active, category_id, categories(category_name))')
      .order('product_id'),
    supabase.from('v_low_stock_inventory').select('store_id, product_id'),
    supabase.from('restock_alerts')
      .select('alert_id, product_id, stock_at_alert, created_at')
      .is('resolved_at', null)
      .order('created_at', { ascending: false }),
    supabase.from('orders')
      .select('order_id, status, total_amount, placed_at, customers(full_name), riders(full_name)')
      .order('placed_at', { ascending: false })
      .limit(10),
    supabase.from('orders').select('*', { count: 'exact', head: true }),
    supabase.from('categories').select('category_id, category_name').order('category_name'),
  ])
  const failed = [inventory, lowStock, alerts, orders, orderCount, categories].find((result) => result.error)
  if (failed) throw new Error(failed.error.message)
  return {
    inventory: inventory.data,
    lowStockKeys: new Set(lowStock.data.map((row) => `${row.store_id}-${row.product_id}`)),
    alerts: alerts.data,
    orders: orders.data,
    orderCount: orderCount.count,
    categories: categories.data,
  }
}

// Adds a product (productId null) or edits one, together with its stock, in one database transaction.
export async function saveProduct({ productId, categoryId, name, price, stock, reorder }) {
  const { error } = await supabase.rpc('save_product', {
    p_product_id: productId,
    p_category_id: categoryId,
    p_name: name,
    p_price: price,
    p_stock: stock,
    p_reorder: reorder,
  })
  if (error) throw error
}

// Deactivated products disappear from the customer shop but keep their order history.
export async function setProductActive(productId, isActive) {
  const { data, error } = await supabase.from('products')
    .update({ is_active: isActive })
    .eq('product_id', productId)
    .select('product_id')
  if (error) throw error
  // RLS hides rows you may not change instead of raising an error, so check something was updated.
  if (data.length === 0) throw new Error('This product could not be updated.')
}
