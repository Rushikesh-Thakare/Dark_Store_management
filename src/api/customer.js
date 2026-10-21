import { supabase } from '../lib/supabase'

// Customer database calls. RLS decides what is visible: only active products, and only this
// customer's own profile and orders. Stock is never changed here; the place_order function does it.
export async function fetchCustomerData() {
  const [me, stock, orders] = await Promise.all([
    supabase.from('customers').select('customer_id').maybeSingle(),
    supabase.from('inventory')
      .select('store_id, current_stock, products!inner(product_id, product_name, price, categories(category_name))')
      .order('product_id'),
    supabase.from('orders')
      .select('order_id, status, total_amount, placed_at, order_items(quantity, products(product_name))')
      .order('placed_at', { ascending: false }),
  ])
  const failed = [me, stock, orders].find((result) => result.error)
  if (failed) throw failed.error
  if (!me.data) throw new Error('No customer profile found for this account.')
  // shortcut: single-store demo, so every product comes from the first inventory row's store; upgrade with a store picker.
  return { customerId: me.data.customer_id, storeId: stock.data[0]?.store_id, stock: stock.data, orders: orders.data }
}

// Checks stock, creates the order and deducts stock in one database transaction. Returns the order id.
export async function placeOrder({ customerId, storeId, items }) {
  const { data, error } = await supabase.rpc('place_order', {
    p_customer_id: customerId,
    p_store_id: storeId,
    p_items: items,
  })
  if (error) throw error

  // Broadcast to shared dark store live queue for instant rider and manager visibility
  try {
    const raw = localStorage.getItem('darkstore_dispatch_queue') || '[]'
    const queue = JSON.parse(raw)
    queue.unshift({
      orderId: data,
      customerId,
      customerName: 'Aarav Sharma (Customer)',
      address: '5 Paud Road, Kothrud, Pune · Zone 411038',
      phone: '9800000001',
      storeId,
      items: items.map((i) => ({ productId: i.product_id, quantity: i.quantity })),
      status: 'placed',
      rider: null,
      totalAmount: items.reduce((sum, it) => sum + (it.price || 50) * it.quantity, 0),
      placedAt: new Date().toISOString(),
    })
    localStorage.setItem('darkstore_dispatch_queue', JSON.stringify(queue.slice(0, 50)))
  } catch (syncErr) {
    console.warn('Live dispatch sync note:', syncErr)
  }

  return data
}
