import { supabase } from '../lib/supabase'

// Fallback seed orders if queue is empty so the rider always sees live activity
const SEED_CUSTOMER_ORDERS = [
  {
    orderId: 8,
    customerName: 'Aarav Sharma',
    phone: '9800000001',
    address: '5 Paud Road, Kothrud, Pune · Zone 411038',
    items: [
      { name: 'Full Cream Milk 1L', quantity: 2 },
      { name: 'Paneer 200g', quantity: 1 },
    ],
    totalAmount: 231,
    status: 'placed',
    rider: null,
    placedAt: new Date(Date.now() - 4 * 60 * 1000).toISOString(),
    slaTarget: '10-Min Target',
  },
  {
    orderId: 7,
    customerName: 'Meera Iyer',
    phone: '9800000002',
    address: '22 Karve Nagar, Pune · Zone 411038',
    items: [
      { name: 'Bananas 1 dozen', quantity: 1 },
      { name: 'Orange Juice 1L', quantity: 1 },
    ],
    totalAmount: 180,
    status: 'packed',
    rider: null,
    placedAt: new Date(Date.now() - 7 * 60 * 1000).toISOString(),
    slaTarget: '10-Min Target',
  },
]

// 1. Fetch nearest Dark Store Hub details
export async function fetchHubDetails() {
  let store = null
  try {
    const { data } = await supabase
      .from('dark_stores')
      .select('store_id, store_name, address, is_active, zones(zone_name, pincode)')
      .limit(1)
      .maybeSingle()
    if (data) store = data
  } catch (e) {
    console.warn('Store fetch error:', e)
  }

  return {
    hubId: store?.store_id ?? 1,
    hubName: store?.store_name ?? 'QuickMart Kothrud Hub #1',
    address: store?.address ?? '12 Karve Road, Pune',
    zone: store?.zones?.zone_name ?? 'Kothrud',
    pincode: store?.zones?.pincode ?? '411038',
    radiusKm: 3.0,
    status: store?.is_active ?? true ? 'Operational (10-Min Fulfillment Active)' : 'Maintenance',
    activeRidersCount: 3,
    contactPhone: '+91 98111 22233',
    managerOnDuty: 'Kothrud Store Manager',
    operatingHours: '06:00 AM – 12:00 AM Daily',
    distanceFromRider: '0.4 km away (2 mins)',
  }
}

// 2. Fetch full rider data: Hub + Assigned Deliveries + Live Customer Orders
export async function fetchRiderDashboard() {
  const hub = await fetchHubDetails()

  // Assigned orders from Supabase RLS
  let dbAssigned = []
  try {
    const { data, error } = await supabase
      .from('orders')
      .select('order_id, status, total_amount, placed_at, dispatched_at, delivered_at, customers(full_name, phone, address), order_items(quantity, products(product_name))')
      .order('placed_at', { ascending: false })
    if (!error && data) {
      dbAssigned = data.map((o) => ({
        orderId: o.order_id,
        customerName: o.customers?.full_name ?? 'Customer',
        phone: o.customers?.phone ?? '9800000001',
        address: o.customers?.address ?? 'Zone 411038, Kothrud, Pune',
        items: o.order_items?.map((it) => ({
          name: it.products?.product_name ?? 'Product item',
          quantity: it.quantity,
        })) ?? [],
        totalAmount: o.total_amount,
        status: o.status,
        placedAt: o.placed_at,
        dispatchedAt: o.dispatched_at,
        deliveredAt: o.delivered_at,
        rider: 'Demo Rider',
      }))
    }
  } catch (err) {
    console.warn('DB assigned orders fetch error:', err)
  }

  // Load from local store dispatch queue
  let storeQueue = []
  try {
    const raw = localStorage.getItem('darkstore_dispatch_queue')
    if (raw) {
      storeQueue = JSON.parse(raw)
    } else {
      storeQueue = SEED_CUSTOMER_ORDERS
      localStorage.setItem('darkstore_dispatch_queue', JSON.stringify(storeQueue))
    }
  } catch (e) {
    storeQueue = SEED_CUSTOMER_ORDERS
  }

  // Split into:
  // - Live customer orders (unassigned or waiting for dispatch)
  // - Rider's active deliveries (assigned to Demo Rider, status != delivered)
  // - Rider's fulfilled history (assigned to Demo Rider, status == delivered)
  const myAssignedFromQueue = storeQueue.filter(
    (o) => o.rider === 'Demo Rider' || o.rider === 'Rohan Patil'
  )

  // Merge DB and queue assigned orders, deduplicating by orderId
  const assignedMap = new Map()
  for (const o of myAssignedFromQueue) assignedMap.set(o.orderId, o)
  for (const o of dbAssigned) assignedMap.set(o.orderId, o)

  const allMyDeliveries = Array.from(assignedMap.values())
  const activeDeliveries = allMyDeliveries.filter((o) => o.status !== 'delivered' && o.status !== 'cancelled')
  const completedDeliveries = allMyDeliveries.filter((o) => o.status === 'delivered')

  // Unassigned orders waiting for a rider
  const liveCustomerOrders = storeQueue.filter(
    (o) => !o.rider && (o.status === 'placed' || o.status === 'packed')
  )

  return {
    hub,
    liveCustomerOrders,
    activeDeliveries,
    completedDeliveries,
  }
}

// 3. Claim an order for this rider
export async function claimCustomerOrder(orderId) {
  try {
    const raw = localStorage.getItem('darkstore_dispatch_queue') || '[]'
    const queue = JSON.parse(raw)
    const target = queue.find((o) => o.orderId === orderId)
    if (target) {
      target.rider = 'Demo Rider'
      target.status = 'packed'
      localStorage.setItem('darkstore_dispatch_queue', JSON.stringify(queue))
    }
  } catch (e) {
    console.error('Claim order error:', e)
  }
}

// 4. Advance delivery status (packed -> out_for_delivery -> delivered)
export async function advanceDelivery(orderId) {
  // Call DB RPC if available
  try {
    await supabase.rpc('advance_delivery', { p_order_id: orderId })
  } catch (err) {
    // If not assigned in DB or RLS restricts, update local dispatch queue
  }

  // Update in local queue
  try {
    const raw = localStorage.getItem('darkstore_dispatch_queue') || '[]'
    const queue = JSON.parse(raw)
    const target = queue.find((o) => o.orderId === orderId)
    if (target) {
      if (target.status === 'placed' || target.status === 'packed') {
        target.status = 'out_for_delivery'
        target.dispatchedAt = new Date().toISOString()
      } else if (target.status === 'out_for_delivery') {
        target.status = 'delivered'
        target.deliveredAt = new Date().toISOString()
      }
      localStorage.setItem('darkstore_dispatch_queue', JSON.stringify(queue))
    }
  } catch (e) {
    console.error('Advance delivery queue error:', e)
  }
}
