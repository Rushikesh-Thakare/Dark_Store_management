import { useState } from 'react'
import {
  assignRiderToOrder,
  fetchDashboard,
  quickRestock,
  saveProduct,
  setProductActive,
  updateOrderStatus,
} from '../api/manager'
import ProductForm from '../components/ProductForm'
import { formatDate, formatMoney, formatStatus } from '../format'
import { LoadGate, useLoad } from '../useLoad'
import '../styles/data.css'
import '../styles/product-form.css'

const emptyProduct = { productId: null, categoryId: '', name: '', price: '', stock: '', reorder: '5' }

const RIDERS_LIST = [
  { id: 3, name: 'Demo Rider' },
  { id: 1, name: 'Rohan Patil' },
  { id: 2, name: 'Sana Khan' },
]

function EmptyRow({ colSpan, children }) {
  return <tr><td colSpan={colSpan} className="empty">{children}</td></tr>
}

export default function ManagerDashboard() {
  const [state, reload] = useLoad(fetchDashboard)
  return (
    <LoadGate state={state} reload={reload}>
      <ManagerView data={state.data} reload={reload} />
    </LoadGate>
  )
}

function ManagerView({ data, reload }) {
  const { inventory, lowStockKeys, alerts, orders, orderCount, categories } = data

  const [formValues, setFormValues] = useState(emptyProduct)
  const [formKey, setFormKey] = useState(0)
  const [saving, setSaving] = useState(false)
  const [formStatus, setFormStatus] = useState({})
  const [busyId, setBusyId] = useState(null)
  const [tableStatus, setTableStatus] = useState({})
  const [actionNotice, setActionNotice] = useState(null)

  function resetForm(values = emptyProduct) {
    setFormValues(values)
    setFormKey((key) => key + 1)
  }

  function startEdit(row) {
    const { products: product } = row
    resetForm({
      productId: row.product_id,
      categoryId: String(product.category_id),
      name: product.product_name,
      price: String(product.price),
      stock: String(row.current_stock),
      reorder: String(row.reorder_threshold),
    })
    setFormStatus({})
    document.getElementById('product-form-title')?.scrollIntoView({ behavior: 'smooth' })
  }

  async function handleSave(values) {
    setSaving(true)
    setFormStatus({})
    try {
      await saveProduct(values)
      setFormStatus({ message: `${values.name} saved successfully.` })
      resetForm()
      reload()
    } catch (error) {
      setFormStatus({ error: error.message })
    }
    setSaving(false)
  }

  async function toggleActive(row) {
    const makeActive = !row.products.is_active
    setBusyId(row.product_id)
    setTableStatus({})
    try {
      await setProductActive(row.product_id, makeActive)
      setTableStatus({
        message: `${row.products.product_name} ${makeActive ? 'reactivated' : 'deactivated'}.`,
      })
      reload()
    } catch (error) {
      setTableStatus({ error: error.message })
    }
    setBusyId(null)
  }

  async function handleQuickRestock(productId, productName) {
    setBusyId(`restock-${productId}`)
    setActionNotice(null)
    try {
      await quickRestock(productId, 1, 50)
      setActionNotice(`✓ Restocked +50 units of ${productName}. Stock updated!`)
      reload()
    } catch (err) {
      setTableStatus({ error: err.message })
    }
    setBusyId(null)
  }

  async function handleAssignRider(orderId, riderName) {
    setBusyId(`rider-${orderId}`)
    try {
      await assignRiderToOrder(orderId, riderName)
      setActionNotice(`✓ Order #${orderId} assigned to ${riderName}. Status set to Packed.`)
      reload()
    } catch (err) {
      console.error(err)
    }
    setBusyId(null)
  }

  async function handleAdvanceOrder(orderId, nextStatus) {
    setBusyId(`status-${orderId}`)
    try {
      await updateOrderStatus(orderId, nextStatus)
      setActionNotice(`✓ Order #${orderId} advanced to ${formatStatus(nextStatus)}.`)
      reload()
    } catch (err) {
      console.error(err)
    }
    setBusyId(null)
  }

  const cards = [
    ['Products in catalog', inventory.length],
    ['Low-stock items', lowStockKeys.size],
    ['Restock alerts', alerts.length],
    ['Live store orders', orderCount],
  ]

  return (
    <>
      {/* Store Operations Hero */}
      <div className="card" style={{
        background: 'linear-gradient(135deg, var(--navy) 0%, #1a3a5f 100%)',
        color: '#ffffff',
        borderRadius: '16px',
        padding: '1.75rem',
        marginBottom: '1.75rem',
      }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', flexWrap: 'wrap', gap: '1rem' }}>
          <div>
            <span style={{
              display: 'inline-flex',
              alignItems: 'center',
              gap: '0.4rem',
              background: 'rgba(255,255,255,0.12)',
              padding: '0.25rem 0.75rem',
              borderRadius: '999px',
              fontSize: '0.8rem',
              fontWeight: 600,
              marginBottom: '0.5rem',
            }}>
              🏬 Central Dark Store Console
            </span>
            <h1 id="overview" style={{ margin: '0.25rem 0', color: '#ffffff', fontFamily: 'var(--font-heading)' }}>
              QuickMart Kothrud (Hub #1)
            </h1>
            <p style={{ margin: 0, opacity: 0.85, fontSize: '0.9rem' }}>
              📍 12 Karve Road, Pune · Zone: Kothrud (411038) · Coverage: 3.0 km Radius
            </p>
          </div>
          <div style={{ textAlign: 'right' }}>
            <span className="badge badge-ok" style={{ fontSize: '0.85rem', padding: '0.4rem 0.85rem' }}>
              🟢 Live & Fulfilling (10-Min SLA)
            </span>
            <p style={{ margin: '0.35rem 0 0', fontSize: '0.8rem', opacity: 0.8 }}>
              Store Manager: <strong>Kothrud Store Lead</strong>
            </p>
          </div>
        </div>
      </div>

      {actionNotice && (
        <div className="card" style={{
          background: '#e6f7f2',
          border: '1px solid #7cd6bf',
          color: '#0f6b66',
          padding: '0.875rem 1.25rem',
          marginBottom: '1.5rem',
          borderRadius: '12px',
          fontWeight: 500,
        }}>
          {actionNotice}
        </div>
      )}

      {/* Summary KPI Grid */}
      <div className="summary-grid">
        {cards.map(([label, value]) => (
          <div className="card summary-card" key={label}>
            <span className="summary-value">{value}</span>
            <span className="summary-label">{label}</span>
          </div>
        ))}
      </div>

      {/* 1. LIVE CUSTOMER ORDERS & RIDER DISPATCH CONSOLE */}
      <section className="card panel" id="orders-title" aria-labelledby="orders-title-heading">
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1rem', flexWrap: 'wrap', gap: '0.5rem' }}>
          <div>
            <h2 id="orders-title-heading" style={{ margin: 0 }}>Live Customer Orders & Rider Dispatch</h2>
            <p className="muted" style={{ margin: '0.25rem 0 0', fontSize: '0.85rem' }}>
              Assign delivery fleet partners and control 10-minute order fulfillment flow
            </p>
          </div>
          <span className="urgent-badge">⚡ {orders.length} Active in Queue</span>
        </div>

        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Order</th>
                <th>Customer</th>
                <th>Status</th>
                <th>Assign Delivery Partner</th>
                <th>Total</th>
                <th>Placed At</th>
                <th>Dispatch Action</th>
              </tr>
            </thead>
            <tbody>
              {orders.length === 0 && <EmptyRow colSpan={7}>No customer orders yet. Orders placed by customers will appear here.</EmptyRow>}
              {orders.map((order) => {
                const assignedRiderName = order.riders?.full_name ?? null
                const isBusy = busyId === `rider-${order.order_id}` || busyId === `status-${order.order_id}`
                return (
                  <tr key={order.order_id}>
                    <td>
                      <strong>#{order.order_id}</strong>
                    </td>
                    <td>
                      <div>
                        <strong>{order.customers?.full_name ?? 'Customer'}</strong>
                      </div>
                    </td>
                    <td>
                      <span className={`badge badge-${order.status}`}>
                        {order.status === 'placed' && '🟡 Placed'}
                        {order.status === 'packed' && '📦 Packed'}
                        {order.status === 'out_for_delivery' && '🛵 Out for Delivery'}
                        {order.status === 'delivered' && '✅ Delivered'}
                      </span>
                    </td>
                    <td>
                      <select
                        value={assignedRiderName || ''}
                        disabled={isBusy || order.status === 'delivered'}
                        onChange={(e) => handleAssignRider(order.order_id, e.target.value)}
                        style={{
                          padding: '0.35rem 0.5rem',
                          borderRadius: '8px',
                          border: '1px solid var(--border)',
                          fontSize: '0.85rem',
                          background: assignedRiderName ? '#e6f7f2' : '#ffffff',
                          fontWeight: assignedRiderName ? 600 : 400,
                        }}
                      >
                        <option value="">-- Assign Rider --</option>
                        {RIDERS_LIST.map((r) => (
                          <option key={r.id} value={r.name}>
                            🛵 {r.name} (Available)
                          </option>
                        ))}
                      </select>
                    </td>
                    <td><strong>{formatMoney(order.total_amount)}</strong></td>
                    <td>{formatDate(order.placed_at)}</td>
                    <td>
                      <div className="table-actions">
                        {order.status === 'placed' && (
                          <button
                            type="button"
                            className="btn btn-small"
                            disabled={isBusy}
                            onClick={() => handleAdvanceOrder(order.order_id, 'packed')}
                          >
                            Pack Order 📦
                          </button>
                        )}
                        {order.status === 'packed' && (
                          <button
                            type="button"
                            className="btn btn-small btn-dispatch"
                            disabled={isBusy}
                            onClick={() => handleAdvanceOrder(order.order_id, 'out_for_delivery')}
                          >
                            Dispatch 🛵
                          </button>
                        )}
                        {order.status === 'out_for_delivery' && (
                          <button
                            type="button"
                            className="btn btn-small btn-complete"
                            disabled={isBusy}
                            onClick={() => handleAdvanceOrder(order.order_id, 'delivered')}
                          >
                            Mark Delivered ✅
                          </button>
                        )}
                        {order.status === 'delivered' && (
                          <span className="badge badge-ok">Fulfilled</span>
                        )}
                      </div>
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        </div>
      </section>

      {/* 2. INVENTORY & STOCK MANAGEMENT */}
      <section className="card panel" id="inventory-title" aria-labelledby="inventory-title-heading">
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1rem', flexWrap: 'wrap', gap: '0.5rem' }}>
          <div>
            <h2 id="inventory-title-heading" style={{ margin: 0 }}>Inventory & Stock Controls</h2>
            <p className="muted" style={{ margin: '0.25rem 0 0', fontSize: '0.85rem' }}>
              Real-time dark store inventory, reorder thresholds, and 1-click restock actions
            </p>
          </div>
          <button
            type="button"
            className="btn btn-small"
            onClick={() => {
              resetForm()
              document.getElementById('product-form-title')?.scrollIntoView({ behavior: 'smooth' })
            }}
          >
            + Add New SKU
          </button>
        </div>

        {tableStatus.error && <p className="form-error table-status" role="alert">{tableStatus.error}</p>}
        {tableStatus.message && <p className="form-success table-status" role="status">{tableStatus.message}</p>}

        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Product</th>
                <th>Category</th>
                <th>Price</th>
                <th>Stock</th>
                <th>Reorder At</th>
                <th>Stock Health</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {inventory.length === 0 && <EmptyRow colSpan={7}>No inventory recorded yet.</EmptyRow>}
              {inventory.map((row) => {
                const { products: product } = row
                const low = lowStockKeys.has(`${row.store_id}-${row.product_id}`)
                const isRestocking = busyId === `restock-${row.product_id}`
                return (
                  <tr key={`${row.store_id}-${row.product_id}`} className={product.is_active ? undefined : 'row-inactive'}>
                    <td><strong>{product.product_name}</strong></td>
                    <td>{product.categories?.category_name ?? 'General'}</td>
                    <td>{formatMoney(product.price)}</td>
                    <td>
                      <span style={{
                        fontWeight: 700,
                        color: low ? '#b91c1c' : 'var(--navy)',
                      }}>
                        {row.current_stock} units
                      </span>
                    </td>
                    <td>{row.reorder_threshold}</td>
                    <td>
                      {product.is_active ? (
                        <span className={`badge ${low ? 'badge-warn' : 'badge-ok'}`}>
                          {low ? '⚠️ Low Stock' : '✓ Normal'}
                        </span>
                      ) : (
                        <span className="badge">Inactive</span>
                      )}
                    </td>
                    <td>
                      <div className="table-actions">
                        <button
                          type="button"
                          className="btn btn-small"
                          disabled={isRestocking}
                          onClick={() => handleQuickRestock(row.product_id, product.product_name)}
                          title="Instantly add 50 units of inventory"
                        >
                          {isRestocking ? 'Restocking…' : '+50 Restock'}
                        </button>
                        <button
                          type="button"
                          className="btn btn-ghost btn-small"
                          onClick={() => startEdit(row)}
                        >
                          Edit
                        </button>
                        <button
                          type="button"
                          className="btn btn-ghost btn-small"
                          disabled={busyId === row.product_id}
                          onClick={() => toggleActive(row)}
                        >
                          {busyId === row.product_id ? '…' : product.is_active ? 'Deactivate' : 'Reactivate'}
                        </button>
                      </div>
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        </div>
      </section>

      {/* 3. ACTIVE RESTOCK ALERTS */}
      <section className="card panel" id="alerts-title" aria-labelledby="alerts-title-heading">
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1rem' }}>
          <div>
            <h2 id="alerts-title-heading" style={{ margin: 0 }}>Automated Restock Alerts ({alerts.length})</h2>
            <p className="muted" style={{ margin: '0.25rem 0 0', fontSize: '0.85rem' }}>
              Triggered automatically when inventory drops at or below reorder threshold
            </p>
          </div>
          {alerts.length > 0 && <span className="urgent-badge">🚨 Action Needed</span>}
        </div>

        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Product</th>
                <th>Category</th>
                <th>Current Stock</th>
                <th>Reorder Threshold</th>
                <th>Status</th>
                <th>Action</th>
              </tr>
            </thead>
            <tbody>
              {alerts.length === 0 && <EmptyRow colSpan={6}>🎉 All inventory levels healthy. No open restock alerts.</EmptyRow>}
              {alerts.map((alert) => (
                <tr key={alert.alert_id}>
                  <td><strong>{alert.product_name}</strong></td>
                  <td>{alert.category_name}</td>
                  <td><span style={{ color: '#b91c1c', fontWeight: 700 }}>{alert.stock_at_alert} units</span></td>
                  <td>{alert.reorder_threshold} units</td>
                  <td><span className="badge badge-warn">🚨 Below Threshold</span></td>
                  <td>
                    <button
                      type="button"
                      className="btn btn-small"
                      disabled={busyId === `restock-${alert.product_id}`}
                      onClick={() => handleQuickRestock(alert.product_id, alert.product_name)}
                    >
                      {busyId === `restock-${alert.product_id}` ? 'Restocking…' : '⚡ Restock (+50 Units)'}
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      {/* 4. ADD / EDIT PRODUCT SKU */}
      <section className="card panel" id="product-form-title" aria-labelledby="form-heading">
        <h2 id="form-heading">{formValues.productId === null ? 'Add New Product to Store' : `Edit ${formValues.name}`}</h2>
        <ProductForm
          key={formKey}
          categories={categories}
          initial={formValues}
          saving={saving}
          error={formStatus.error}
          message={formStatus.message}
          onSubmit={handleSave}
          onCancel={() => resetForm()}
        />
      </section>
    </>
  )
}
