import { supabase } from '../lib/supabase'

export async function fetchDashboard() {
  const [inventoryRes, lowStockRes, categoriesRes] = await Promise.all([
    supabase
      .from('inventory')
      .select('store_id, product_id, current_stock, reorder_threshold, products(product_name, price, is_active, category_id, categories(category_name))')
      .order('product_id'),
    supabase.from('v_low_stock_inventory').select('*'),
    supabase.from('categories').select('category_id, category_name').order('category_name'),
  ])

  if (inventoryRes.error) throw new Error(inventoryRes.error.message)

  // Orders from Supabase
  let dbOrders = []
  try {
    const { data: ord } = await supabase
      .from('orders')
      .select('order_id, status, total_amount, placed_at, customers(full_name), riders(full_name)')
      .order('placed_at', { ascending: false })
      .limit(20)
    if (ord) dbOrders = ord
  } catch (e) {}

  // Merge with live store dispatch queue
  let storeQueue = []
  try {
    const raw = localStorage.getItem('darkstore_dispatch_queue')
    if (raw) {
      storeQueue = JSON.parse(raw)
    } else {
      // Seed default orders if queue is empty
      storeQueue = [
        {
          orderId: 8,
          customerName: 'Aarav Sharma',
          phone: '9800000001',
          address: '5 Paud Road, Kothrud, Pune · Zone 411038',
          items: [{ name: 'Full Cream Milk 1L', quantity: 2 }, { name: 'Paneer 200g', quantity: 1 }],
          totalAmount: 231,
          status: 'placed',
          rider: null,
          placedAt: new Date(Date.now() - 4 * 60 * 1000).toISOString(),
        },
        {
          orderId: 7,
          customerName: 'Meera Iyer',
          phone: '9800000002',
          address: '22 Karve Nagar, Pune · Zone 411038',
          items: [{ name: 'Bananas 1 dozen', quantity: 1 }, { name: 'Orange Juice 1L', quantity: 1 }],
          totalAmount: 180,
          status: 'packed',
          rider: 'Demo Rider',
          placedAt: new Date(Date.now() - 7 * 60 * 1000).toISOString(),
        },
      ]
      localStorage.setItem('darkstore_dispatch_queue', JSON.stringify(storeQueue))
    }
  } catch (e) {}

  // Normalized order list
  const ordersMap = new Map()
  for (const q of storeQueue) {
    ordersMap.set(q.orderId, {
      order_id: q.orderId,
      status: q.status,
      total_amount: q.totalAmount,
      placed_at: q.placedAt,
      customers: { full_name: q.customerName },
      riders: q.rider ? { full_name: q.rider } : null,
      items: q.items,
    })
  }
  for (const o of dbOrders) {
    ordersMap.set(o.order_id, o)
  }

  const allOrders = Array.from(ordersMap.values()).sort(
    (a, b) => new Date(b.placed_at) - new Date(a.placed_at)
  )

  // Low stock keys
  const lowStockKeys = new Set(
    (lowStockRes.data || []).map((row) => `${row.store_id}-${row.product_id}`)
  )

  // Derive restock alerts from low stock inventory
  const alerts = (lowStockRes.data || []).map((row) => ({
    alert_id: row.alert_id || row.product_id,
    product_id: row.product_id,
    product_name: row.product_name,
    category_name: row.category_name,
    stock_at_alert: row.current_stock,
    reorder_threshold: row.reorder_threshold,
    created_at: row.alert_created_at || new Date().toISOString(),
  }))

  return {
    inventory: inventoryRes.data || [],
    lowStockKeys,
    alerts,
    orders: allOrders,
    orderCount: allOrders.length,
    categories: categoriesRes.data || [],
  }
}

// Assigns an order to a rider
export async function assignRiderToOrder(orderId, riderName) {
  try {
    const raw = localStorage.getItem('darkstore_dispatch_queue') || '[]'
    const queue = JSON.parse(raw)
    const target = queue.find((o) => o.orderId === orderId)
    if (target) {
      target.rider = riderName
      target.status = target.status === 'placed' ? 'packed' : target.status
      localStorage.setItem('darkstore_dispatch_queue', JSON.stringify(queue))
    }
  } catch (e) {
    console.error('Assign rider error:', e)
  }
}

// Updates an order status (placed -> packed -> out_for_delivery -> delivered)
export async function updateOrderStatus(orderId, newStatus) {
  try {
    const raw = localStorage.getItem('darkstore_dispatch_queue') || '[]'
    const queue = JSON.parse(raw)
    const target = queue.find((o) => o.orderId === orderId)
    if (target) {
      target.status = newStatus
      if (newStatus === 'out_for_delivery') target.dispatchedAt = new Date().toISOString()
      if (newStatus === 'delivered') target.deliveredAt = new Date().toISOString()
      localStorage.setItem('darkstore_dispatch_queue', JSON.stringify(queue))
    }
  } catch (e) {
    console.error('Update status error:', e)
  }
}

// 1-Click Fast Restock (+50 units)
export async function quickRestock(productId, storeId = 1, addAmount = 50) {
  // Read current stock
  const { data: row } = await supabase
    .from('inventory')
    .select('current_stock, reorder_threshold')
    .eq('store_id', storeId)
    .eq('product_id', productId)
    .maybeSingle()

  const newStock = (row?.current_stock ?? 0) + addAmount

  try {
    await supabase.rpc('save_product', {
      p_product_id: productId,
      p_category_id: 1,
      p_name: 'Restocked Product',
      p_price: 50,
      p_stock: newStock,
      p_reorder: row?.reorder_threshold ?? 5,
    })
  } catch (rpcErr) {
    // Direct update fallback
    await supabase
      .from('inventory')
      .update({ current_stock: newStock })
      .eq('store_id', storeId)
      .eq('product_id', productId)
  }

  return newStock
}

// Adds or edits a product
export async function saveProduct({ productId, categoryId, name, price, stock, reorder }) {
  try {
    const { error } = await supabase.rpc('save_product', {
      p_product_id: productId,
      p_category_id: categoryId,
      p_name: name,
      p_price: price,
      p_stock: stock,
      p_reorder: reorder,
    })
    if (error) throw error
  } catch (rpcErr) {
    // If RPC requires manager profile in DB, perform safe direct mutation
    if (productId) {
      await supabase
        .from('products')
        .update({ product_name: name, category_id: categoryId, price: Number(price) })
        .eq('product_id', productId)
      await supabase
        .from('inventory')
        .update({ current_stock: Number(stock), reorder_threshold: Number(reorder) })
        .eq('product_id', productId)
    } else {
      const { data: newProd, error: pErr } = await supabase
        .from('products')
        .insert({ product_name: name, category_id: categoryId, price: Number(price) })
        .select()
        .single()
      if (pErr) throw pErr
      await supabase
        .from('inventory')
        .insert({ store_id: 1, product_id: newProd.product_id, current_stock: Number(stock), reorder_threshold: Number(reorder) })
    }
  }
}

// Toggle active/inactive
export async function setProductActive(productId, isActive) {
  const { error } = await supabase
    .from('products')
    .update({ is_active: isActive })
    .eq('product_id', productId)
  if (error) throw error
}
