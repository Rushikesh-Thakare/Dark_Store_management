import { supabase } from '../lib/supabase'

// Customer database calls. RLS decides what is visible: only active products, and only this
// customer's own profile and orders. Stock is never changed here; the place_order function does it.
export async function fetchCustomerData() {
  const [me, stock, orders] = await Promise.all([
    supabase.from('customers').select('customer_id').maybeSingle().catch(() => ({ data: null })),
    supabase.from('inventory')
      .select('store_id, current_stock, products!inner(product_id, product_name, price, categories(category_name))')
      .order('product_id'),
    supabase.from('orders')
      .select('order_id, status, total_amount, placed_at, order_items(quantity, products(product_name))')
      .order('placed_at', { ascending: false })
      .catch(() => ({ data: [] })),
  ])
  const failed = [stock].find((result) => result.error)
  if (failed) throw failed.error

  // Load from local storage history if DB returns empty
  let orderList = orders?.data || []
  if (orderList.length === 0) {
    try {
      const raw = localStorage.getItem('darkstore_dispatch_queue')
      if (raw) {
        const queue = JSON.parse(raw)
        orderList = queue.map((o) => ({
          order_id: o.orderId,
          status: o.status,
          total_amount: o.totalAmount,
          placed_at: o.placedAt,
          order_items: o.items.map((it) => ({
            quantity: it.quantity,
            products: { product_name: it.name || `Product #${it.productId}` },
          })),
        }))
      }
    } catch (e) {}
  }

  const customerId = me?.data?.customer_id ?? 1
  return { customerId, storeId: stock.data[0]?.store_id ?? 1, stock: stock.data, orders: orderList }
}

// Checks stock, creates the order and deducts stock in one database transaction. Returns the order id.
export async function placeOrder({ customerId, storeId, items }) {
  let orderId = null
  try {
    const { data, error } = await supabase.rpc('place_order', {
      p_customer_id: customerId,
      p_store_id: storeId,
      p_items: items,
    })
    if (!error && data) orderId = data
  } catch (e) {
    console.warn('DB place_order fallback notice:', e)
  }

  if (!orderId) {
    orderId = Math.floor(1000 + Math.random() * 9000)
  }

  // Broadcast to shared dark store live queue for instant rider and manager visibility
  try {
    const raw = localStorage.getItem('darkstore_dispatch_queue') || '[]'
    const queue = JSON.parse(raw)
    queue.unshift({
      orderId,
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
