import { useState } from 'react'
import { advanceDelivery, fetchAssignedOrders } from '../api/rider'
import { formatDate, formatMoney, formatStatus } from '../format'
import { LoadGate, useLoad } from '../useLoad'
import '../styles/data.css'
import '../styles/rider.css'

// Button text only. An order with no entry here is finished; the database function
// advance_delivery decides which step is actually valid, so no other status can be chosen.
const nextAction = { placed: 'Start delivery', packed: 'Start delivery', out_for_delivery: 'Mark delivered' }

export default function RiderDashboard() {
  const [state, reload] = useLoad(fetchAssignedOrders)
  return (
    <LoadGate state={state} reload={reload}>
      <RiderView orders={state.data} reload={reload} />
    </LoadGate>
  )
}

function OrderCard({ order, busy, onAdvance }) {
  const { customers: customer } = order
  const action = nextAction[order.status]
  return (
    <article className="card task-card">
      <div className="task-head">
        <h3>Order #{order.order_id}</h3>
        <span className={`badge badge-${order.status}`}>{formatStatus(order.status)}</span>
      </div>

      <p className="task-customer">{customer.full_name}</p>
      <p className="task-detail">
        {customer.phone ? <a href={`tel:${customer.phone}`}>{customer.phone}</a> : 'No phone on file'}
      </p>
      <p className="task-detail">{customer.address ?? 'No address on file'}</p>

      <ul className="task-items">
        {order.order_items.map((item, index) => (
          // products is empty if the item was later deactivated (RLS hides inactive products).
          <li key={index}>{item.products?.product_name ?? 'Unavailable item'} × {item.quantity}</li>
        ))}
      </ul>

      <p className="task-meta">
        {formatMoney(order.total_amount)} · placed {formatDate(order.placed_at)}
        {order.dispatched_at && ` · dispatched ${formatDate(order.dispatched_at)}`}
      </p>

      {action && (
        <button type="button" className="btn" disabled={busy} onClick={() => onAdvance(order.order_id)}>
          {busy ? 'Updating…' : action}
        </button>
      )}
    </article>
  )
}

function RiderView({ orders, reload }) {
  const [updatingId, setUpdatingId] = useState(null)
  const [error, setError] = useState(null)

  const active = orders.filter((order) => nextAction[order.status])
  const finished = orders.filter((order) => !nextAction[order.status]).reverse() // newest first

  async function advance(orderId) {
    setUpdatingId(orderId)
    setError(null)
    try {
      await advanceDelivery(orderId)
      reload()
    } catch (rpcError) {
      setError(rpcError.message)
    }
    setUpdatingId(null)
  }

  const renderCards = (list) => list.map((order) => (
    <OrderCard key={order.order_id} order={order} busy={updatingId === order.order_id} onAdvance={advance} />
  ))

  return (
    <>
      <h1 id="assigned-orders">Assigned orders</h1>
      <p className="muted">
        {active.length === 0 ? 'No active deliveries.' : `${active.length} active ${active.length === 1 ? 'delivery' : 'deliveries'}, oldest first.`}
      </p>
      {error && <p className="form-error" role="alert">{error}</p>}

      {orders.length === 0 && <p className="card">No orders are assigned to you yet. New assignments appear here.</p>}
      <div className="task-grid">{renderCards(active)}</div>

      {finished.length > 0 && (
        <>
          <h2 className="task-section">Completed</h2>
          <div className="task-grid">{renderCards(finished)}</div>
        </>
      )}
    </>
  )
}
