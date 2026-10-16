import { supabase } from '../lib/supabase'

// Rider database calls. RLS returns only the orders assigned to the signed-in rider (and their customers).
export async function fetchAssignedOrders() {
  const { data, error } = await supabase
    .from('orders')
    .select('order_id, status, total_amount, placed_at, dispatched_at, customers(full_name, phone, address), order_items(quantity, products(product_name))')
    .order('placed_at')
  if (error) throw error
  return data
}

// The database decides the next valid step and stamps the time; the rider cannot pick any other status.
export async function advanceDelivery(orderId) {
  const { error } = await supabase.rpc('advance_delivery', { p_order_id: orderId })
  if (error) throw error
}
