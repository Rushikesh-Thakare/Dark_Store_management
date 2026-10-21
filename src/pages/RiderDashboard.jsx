import { useState } from 'react'
import { advanceDelivery, claimCustomerOrder, fetchRiderDashboard } from '../api/rider'
import { formatDate, formatMoney, formatStatus } from '../format'
import { LoadGate, useLoad } from '../useLoad'
import '../styles/data.css'
import '../styles/rider.css'

const nextAction = {
  placed: '🛵 Start Delivery (Dispatch)',
  packed: '🛵 Start Delivery (Dispatch)',
  out_for_delivery: '✅ Mark as Delivered (Complete)',
}

export default function RiderDashboard() {
  const [state, reload] = useLoad(fetchRiderDashboard)
  return (
    <LoadGate state={state} reload={reload}>
      <RiderView data={state.data} reload={reload} />
    </LoadGate>
  )
}

function RiderView({ data, reload }) {
  const { hub, liveCustomerOrders, activeDeliveries, completedDeliveries } = data
  const [busyId, setBusyId] = useState(null)
  const [error, setError] = useState(null)
  const [feedback, setFeedback] = useState(null)

  async function handleClaim(orderId) {
    setBusyId(orderId)
    setError(null)
    try {
      await claimCustomerOrder(orderId)
      setFeedback(`Order #${orderId} claimed! It is now in your Active Deliveries.`)
      reload()
    } catch (e) {
      setError(e.message)
    }
    setBusyId(null)
  }

  async function handleAdvance(orderId) {
    setBusyId(orderId)
    setError(null)
    try {
      await advanceDelivery(orderId)
      setFeedback(`Delivery status for Order #${orderId} updated successfully.`)
      reload()
    } catch (e) {
      setError(e.message)
    }
    setBusyId(null)
  }

  const earningsTotal = (completedDeliveries.length * 65) // ₹50 base + ₹15 on-time incentive

  return (
    <div className="rider-dashboard-page">
      {/* Fleet Hero Banner */}
      <div className="rider-hero-banner">
        <div className="rider-hero-content">
          <div className="rider-badge">🛵 Express Rider Partner Fleet</div>
          <h2>Delivery Partner Workspace</h2>
          <p className="rider-subtitle">
            🟢 Active on Duty · Connected to <strong>{hub.hubName}</strong> ({hub.zone} · {hub.pincode})
          </p>
        </div>

        <div className="rider-stats-grid">
          <div className="rider-stat-box">
            <span className="stat-number">{liveCustomerOrders.length}</span>
            <span className="stat-label">Store Queue</span>
          </div>
          <div className="rider-stat-box">
            <span className="stat-number">{activeDeliveries.length}</span>
            <span className="stat-label">My Active Tasks</span>
          </div>
          <div className="rider-stat-box">
            <span className="stat-number">{completedDeliveries.length}</span>
            <span className="stat-label">Completed</span>
          </div>
          <div className="rider-stat-box stat-highlight">
            <span className="stat-number">₹{earningsTotal}</span>
            <span className="stat-label">Today's Earnings</span>
          </div>
        </div>
      </div>

      {feedback && (
        <div className="card" style={{ background: '#e6f7f2', border: '1px solid #7cd6bf', color: '#0f6b66', padding: '0.875rem 1.25rem', marginBottom: '1.25rem', borderRadius: '12px' }}>
          ✓ {feedback}
        </div>
      )}

      {error && <p className="form-error" role="alert">{error}</p>}

      {/* 1. NEAREST DARK STORE HUB */}
      <section className="rider-section" id="dark-store-hub" aria-labelledby="dark-store-hub-title">
        <div className="section-head">
          <div>
            <h2 id="dark-store-hub-title">Nearest Dark Store Hub</h2>
            <p className="section-desc">Your designated fulfillment warehouse and dispatch base</p>
          </div>
          <span className="badge badge-ok">🟢 Operational</span>
        </div>

        <div className="card" style={{ background: 'var(--cream)', border: '1px solid var(--border)', borderRadius: '16px', padding: '1.5rem' }}>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))', gap: '1.25rem' }}>
            <div>
              <span className="muted" style={{ fontSize: '0.8rem', textTransform: 'uppercase', letterSpacing: '0.05em' }}>Hub Facility</span>
              <h3 style={{ margin: '0.25rem 0', color: 'var(--navy)', fontFamily: 'var(--font-heading)' }}>{hub.hubName}</h3>
              <p style={{ margin: 0, color: 'var(--muted)', fontSize: '0.9rem' }}>📍 {hub.address}</p>
              <p style={{ margin: '0.25rem 0 0', color: 'var(--muted)', fontSize: '0.85rem' }}>Zone: {hub.zone} (PIN: {hub.pincode}) · Coverage: {hub.radiusKm} km radius</p>
            </div>

            <div>
              <span className="muted" style={{ fontSize: '0.8rem', textTransform: 'uppercase', letterSpacing: '0.05em' }}>Hub Status & Dispatch</span>
              <p style={{ margin: '0.25rem 0', fontWeight: 600, color: 'var(--teal)' }}>⚡ {hub.status}</p>
              <p style={{ margin: 0, fontSize: '0.85rem', color: 'var(--navy)' }}>🕒 Operating Hours: {hub.operatingHours}</p>
              <p style={{ margin: '0.25rem 0 0', fontSize: '0.85rem', color: 'var(--muted)' }}>📍 Distance: {hub.distanceFromRider}</p>
            </div>

            <div>
              <span className="muted" style={{ fontSize: '0.8rem', textTransform: 'uppercase', letterSpacing: '0.05em' }}>Hub Dispatch Lead</span>
              <p style={{ margin: '0.25rem 0', fontWeight: 600, color: 'var(--navy)' }}>👤 {hub.managerOnDuty}</p>
              <a
                href={`tel:${hub.contactPhone}`}
                className="btn btn-small"
                style={{ display: 'inline-flex', alignItems: 'center', gap: '0.35rem', marginTop: '0.35rem' }}
              >
                📞 Call Hub Dispatch ({hub.contactPhone})
              </a>
            </div>
          </div>
        </div>
      </section>

      {/* 2. LIVE CUSTOMER ORDERS WAITING AT STORE */}
      <section className="rider-section" id="live-customer-orders" aria-labelledby="live-customer-orders-title">
        <div className="section-head">
          <div>
            <h2 id="live-customer-orders-title">Live Customer Orders at Hub</h2>
            <p className="section-desc">Orders placed by customers in Kothrud Zone (411038) ready for claiming</p>
          </div>
          {liveCustomerOrders.length > 0 && (
            <span className="urgent-badge">⚡ {liveCustomerOrders.length} Ready to Claim</span>
          )}
        </div>

        {liveCustomerOrders.length === 0 ? (
          <div className="card empty-rider-card">
            <span className="empty-fleet-icon">🛍️</span>
            <h3>No pending customer orders in queue</h3>
            <p>All current store orders have been dispatched or assigned. New checkouts will appear here instantly!</p>
          </div>
        ) : (
          <div className="task-grid">
            {liveCustomerOrders.map((order) => (
              <article key={order.orderId} className="card task-card">
                <div className="task-head">
                  <div className="task-title-group">
                    <span className="task-order-pill">Order #{order.orderId}</span>
                    <span className="task-delivery-target">⚡ 10-Min Target</span>
                  </div>
                  <span className={`badge badge-${order.status}`}>
                    {order.status === 'placed' && '🟡 Placed by Customer'}
                    {order.status === 'packed' && '📦 Packed at Hub'}
                  </span>
                </div>

                <div className="customer-info-box">
                  <div className="customer-header-row">
                    <span className="customer-icon">👤</span>
                    <span className="task-customer-name">{order.customerName}</span>
                  </div>
                  <div className="customer-contact-row">
                    <span className="contact-icon">📍</span>
                    <span className="task-address">{order.address}</span>
                  </div>
                  <div className="customer-contact-row">
                    <span className="contact-icon">📞</span>
                    <span className="task-phone">{order.phone}</span>
                  </div>
                </div>

                <div className="task-items-container">
                  <span className="items-heading">Customer Cart Items:</span>
                  <ul className="task-items">
                    {order.items.map((it, idx) => (
                      <li key={idx}>
                        <span className="item-check">✓</span>
                        <span className="item-name">{it.name || `SKU #${it.productId}`}</span>
                        <span className="item-qty-tag">× {it.quantity}</span>
                      </li>
                    ))}
                  </ul>
                </div>

                <div className="task-footer">
                  <div className="task-meta-info">
                    <span className="task-amount">{formatMoney(order.totalAmount)}</span>
                    <span className="task-payment-status">Prepaid Online</span>
                    <span className="task-time">Placed {formatDate(order.placedAt)}</span>
                  </div>

                  <button
                    type="button"
                    className="btn btn-lg btn-dispatch"
                    disabled={busyId === order.orderId}
                    onClick={() => handleClaim(order.orderId)}
                  >
                    {busyId === order.orderId ? 'Claiming order…' : '🛵 Claim & Deliver Order'}
                  </button>
                </div>
              </article>
            ))}
          </div>
        )}
      </section>

      {/* 3. MY ASSIGNED DELIVERIES */}
      <section className="rider-section" id="assigned-orders" aria-labelledby="assigned-orders-title">
        <div className="section-head">
          <div>
            <h2 id="assigned-orders-title">My Active Deliveries ({activeDeliveries.length})</h2>
            <p className="section-desc">Deliveries currently claimed by or assigned to you</p>
          </div>
          {activeDeliveries.length > 0 && (
            <span className="urgent-badge">🛵 On Delivery Duty</span>
          )}
        </div>

        {activeDeliveries.length === 0 ? (
          <div className="card empty-rider-card">
            <span className="empty-fleet-icon">🛵</span>
            <h3>No active deliveries assigned</h3>
            <p>Claim an order from the Live Customer Orders section above to start delivery.</p>
          </div>
        ) : (
          <div className="task-grid">
            {activeDeliveries.map((order) => {
              const action = nextAction[order.status] || '🛵 Start Delivery (Dispatch)'
              const isOutForDelivery = order.status === 'out_for_delivery'
              return (
                <article
                  key={order.orderId}
                  className={`card task-card ${isOutForDelivery ? 'task-card-active' : ''}`}
                >
                  <div className="task-head">
                    <div className="task-title-group">
                      <span className="task-order-pill">Order #{order.orderId}</span>
                      <span className="task-delivery-target">⚡ 10-Min Target</span>
                    </div>
                    <span className={`badge badge-${order.status}`}>
                      {order.status === 'placed' && '🟡 Placed'}
                      {order.status === 'packed' && '📦 Packed (Ready for pickup)'}
                      {order.status === 'out_for_delivery' && '🛵 Out for Delivery'}
                      {order.status === 'delivered' && '✅ Delivered'}
                    </span>
                  </div>

                  <div className="customer-info-box">
                    <div className="customer-header-row">
                      <span className="customer-icon">👤</span>
                      <span className="task-customer-name">{order.customerName}</span>
                    </div>
                    <div className="customer-contact-row">
                      <span className="contact-icon">📍</span>
                      <span className="task-address">{order.address}</span>
                    </div>
                    <div className="customer-contact-row">
                      <span className="contact-icon">📞</span>
                      <a href={`tel:${order.phone}`} className="phone-call-btn">
                        <span>{order.phone}</span>
                        <span className="call-pill">Call Customer ↗</span>
                      </a>
                    </div>
                  </div>

                  <div className="task-items-container">
                    <span className="items-heading">Items Checklist:</span>
                    <ul className="task-items">
                      {order.items.map((it, idx) => (
                        <li key={idx}>
                          <span className="item-check">✓</span>
                          <span className="item-name">{it.name || `SKU #${it.productId}`}</span>
                          <span className="item-qty-tag">× {it.quantity}</span>
                        </li>
                      ))}
                    </ul>
                  </div>

                  <div className="task-footer">
                    <div className="task-meta-info">
                      <span className="task-amount">{formatMoney(order.totalAmount)}</span>
                      <span className="task-payment-status">Prepaid Online</span>
                      <span className="task-time">Placed {formatDate(order.placedAt)}</span>
                    </div>

                    <button
                      type="button"
                      className={`btn btn-lg ${isOutForDelivery ? 'btn-complete' : 'btn-dispatch'}`}
                      disabled={busyId === order.orderId}
                      onClick={() => handleAdvance(order.orderId)}
                    >
                      {busyId === order.orderId ? 'Updating status…' : action}
                    </button>
                  </div>
                </article>
              )
            })}
          </div>
        )}
      </section>

      {/* 4. DELIVERY HISTORY & EARNINGS */}
      <section className="rider-section completed-section" id="delivery-history" aria-labelledby="history-title">
        <div className="section-head">
          <div>
            <h2 id="history-title">Delivery History & Payouts ({completedDeliveries.length})</h2>
            <p className="section-desc">Fulfilled drops with timestamps and confirmed delivery earnings</p>
          </div>
          <span className="badge badge-ok">💰 ₹65 / drop earned</span>
        </div>

        {completedDeliveries.length === 0 ? (
          <div className="card empty-rider-card">
            <span className="empty-fleet-icon">📦</span>
            <h3>No completed deliveries today yet</h3>
            <p>Your fulfilled orders and payout receipts will be summarized here.</p>
          </div>
        ) : (
          <div className="task-grid">
            {completedDeliveries.map((order) => (
              <article key={order.orderId} className="card task-card" style={{ opacity: 0.9 }}>
                <div className="task-head">
                  <div className="task-title-group">
                    <span className="task-order-pill">Order #{order.orderId}</span>
                    <span className="badge badge-ok">✅ Delivered</span>
                  </div>
                  <span style={{ fontSize: '0.85rem', fontWeight: 600, color: 'var(--teal)' }}>
                    +₹65 Earned
                  </span>
                </div>

                <div className="customer-info-box">
                  <div className="customer-header-row">
                    <span className="customer-icon">👤</span>
                    <span className="task-customer-name">{order.customerName}</span>
                  </div>
                  <div className="customer-contact-row">
                    <span className="contact-icon">📍</span>
                    <span className="task-address">{order.address}</span>
                  </div>
                </div>

                <div className="task-footer">
                  <div className="task-meta-info">
                    <span className="task-amount">{formatMoney(order.totalAmount)}</span>
                    <span className="task-time">Delivered {formatDate(order.deliveredAt || order.placedAt)}</span>
                  </div>
                  <span className="badge badge-ok">Fulfilled on Time (Under 10 mins)</span>
                </div>
              </article>
            ))}
          </div>
        )}
      </section>
    </div>
  )
}
