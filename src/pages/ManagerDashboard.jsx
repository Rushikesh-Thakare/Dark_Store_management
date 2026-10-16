import { useState } from 'react'
import { fetchDashboard, saveProduct, setProductActive } from '../api/manager'
import ProductForm from '../components/ProductForm'
import { formatDate, formatMoney, formatStatus } from '../format'
import { LoadGate, useLoad } from '../useLoad'
import '../styles/data.css'
import '../styles/product-form.css'

const emptyProduct = { productId: null, categoryId: '', name: '', price: '', stock: '', reorder: '5' }

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
  const productName = (productId) =>
    inventory.find((row) => row.product_id === productId)?.products.product_name ?? `Product ${productId}`

  const [formValues, setFormValues] = useState(emptyProduct) // what the form starts with
  const [formKey, setFormKey] = useState(0) // changing the key makes the form restart with new values
  const [saving, setSaving] = useState(false)
  const [formStatus, setFormStatus] = useState({}) // { error, message }
  const [busyId, setBusyId] = useState(null)
  const [tableStatus, setTableStatus] = useState({})

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
    document.getElementById('product-form-title')?.scrollIntoView()
  }

  async function handleSave(values) {
    setSaving(true)
    setFormStatus({})
    try {
      await saveProduct(values)
      setFormStatus({ message: `${values.name} saved.` })
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
      setTableStatus({ message: `${row.products.product_name} ${makeActive ? 'reactivated' : 'deactivated'}.` })
      reload()
    } catch (error) {
      setTableStatus({ error: error.message })
    }
    setBusyId(null)
  }

  const cards = [
    ['Products tracked', inventory.length],
    ['Low-stock items', lowStockKeys.size],
    ['Open restock alerts', alerts.length],
    ['Total orders', orderCount],
  ]

  return (
    <>
      <h1 id="overview">Overview</h1>

      <div className="summary-grid">
        {cards.map(([label, value]) => (
          <div className="card summary-card" key={label}>
            <span className="summary-value">{value}</span>
            <span className="summary-label">{label}</span>
          </div>
        ))}
      </div>

      <section className="card panel" aria-labelledby="product-form-title">
        <h2 id="product-form-title">{formValues.productId === null ? 'Add product' : `Edit ${formValues.name}`}</h2>
        <ProductForm key={formKey} categories={categories} initial={formValues} saving={saving}
          error={formStatus.error} message={formStatus.message} onSubmit={handleSave} onCancel={() => resetForm()} />
      </section>

      <section className="card panel" aria-labelledby="inventory-title">
        <h2 id="inventory-title">Inventory</h2>
        {tableStatus.error && <p className="form-error table-status" role="alert">{tableStatus.error}</p>}
        {tableStatus.message && <p className="form-success table-status" role="status">{tableStatus.message}</p>}
        <div className="table-wrap">
          <table>
            <thead>
              <tr><th>Product</th><th>Category</th><th>Price</th><th>Stock</th><th>Reorder at</th><th>Status</th><th>Actions</th></tr>
            </thead>
            <tbody>
              {inventory.length === 0 && <EmptyRow colSpan={7}>No inventory yet. Add your first product above.</EmptyRow>}
              {inventory.map((row) => {
                const { products: product } = row
                const low = lowStockKeys.has(`${row.store_id}-${row.product_id}`)
                return (
                  <tr key={`${row.store_id}-${row.product_id}`} className={product.is_active ? undefined : 'row-inactive'}>
                    <td>{product.product_name}</td>
                    <td>{product.categories.category_name}</td>
                    <td>{formatMoney(product.price)}</td>
                    <td>{row.current_stock}</td>
                    <td>{row.reorder_threshold}</td>
                    <td>
                      {product.is_active
                        ? <span className={`badge ${low ? 'badge-warn' : 'badge-ok'}`}>{low ? 'Low stock' : 'In stock'}</span>
                        : <span className="badge">Inactive</span>}
                    </td>
                    <td>
                      <div className="table-actions">
                        <button type="button" className="btn btn-ghost btn-small" onClick={() => startEdit(row)}>Edit</button>
                        <button type="button" className="btn btn-ghost btn-small" disabled={busyId === row.product_id}
                          onClick={() => toggleActive(row)}>
                          {busyId === row.product_id ? 'Updating…' : product.is_active ? 'Deactivate' : 'Reactivate'}
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

      <section className="card panel" aria-labelledby="alerts-title">
        <h2 id="alerts-title">Active restock alerts</h2>
        <div className="table-wrap">
          <table>
            <thead>
              <tr><th>Product</th><th>Stock when raised</th><th>Raised</th></tr>
            </thead>
            <tbody>
              {alerts.length === 0 && <EmptyRow colSpan={3}>No open restock alerts.</EmptyRow>}
              {alerts.map((alert) => (
                <tr key={alert.alert_id}>
                  <td>{productName(alert.product_id)}</td>
                  <td>{alert.stock_at_alert}</td>
                  <td>{formatDate(alert.created_at)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section className="card panel" aria-labelledby="orders-title">
        <h2 id="orders-title">Recent orders</h2>
        <div className="table-wrap">
          <table>
            <thead>
              <tr><th>Order</th><th>Customer</th><th>Rider</th><th>Status</th><th>Total</th><th>Placed</th></tr>
            </thead>
            <tbody>
              {orders.length === 0 && <EmptyRow colSpan={6}>No orders yet.</EmptyRow>}
              {orders.map((order) => (
                <tr key={order.order_id}>
                  <td>#{order.order_id}</td>
                  <td>{order.customers.full_name}</td>
                  <td>{order.riders?.full_name ?? 'Unassigned'}</td>
                  <td><span className={`badge badge-${order.status}`}>{formatStatus(order.status)}</span></td>
                  <td>{formatMoney(order.total_amount)}</td>
                  <td>{formatDate(order.placed_at)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </>
  )
}
