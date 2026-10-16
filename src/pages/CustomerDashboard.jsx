import { useState } from 'react'
import { fetchCustomerData, placeOrder } from '../api/customer'
import { formatDate, formatMoney, formatStatus } from '../format'
import { LoadGate, useLoad } from '../useLoad'
import '../styles/data.css'
import '../styles/customer.css'

export default function CustomerDashboard() {
  const [state, reload] = useLoad(fetchCustomerData)
  return (
    <LoadGate state={state} reload={reload}>
      <Storefront data={state.data} reload={reload} />
    </LoadGate>
  )
}

function QuantityStepper({ name, quantity, max, onChange }) {
  return (
    <span className="qty-controls">
      <button type="button" className="btn btn-ghost btn-small" aria-label={`Remove one ${name}`}
        onClick={() => onChange(-1)}>−</button>
      <span aria-live="polite">{quantity}</span>
      <button type="button" className="btn btn-ghost btn-small" aria-label={`Add one ${name}`}
        disabled={quantity >= max} onClick={() => onChange(1)}>+</button>
    </span>
  )
}

function Storefront({ data, reload }) {
  const [search, setSearch] = useState('')
  const [category, setCategory] = useState('') // '' = all categories
  const [cart, setCart] = useState({}) // product_id -> quantity
  const [placing, setPlacing] = useState(false)
  const [error, setError] = useState(null)
  const [message, setMessage] = useState(null)

  const categories = [...new Set(data.stock.map((row) => row.products.categories.category_name))]
  const query = search.trim().toLowerCase()
  const visible = data.stock.filter(({ products: product }) =>
    (category === '' || product.categories.category_name === category) &&
    product.product_name.toLowerCase().includes(query))

  const stockById = Object.fromEntries(data.stock.map((row) => [row.products.product_id, row]))
  const lines = Object.entries(cart)
    .filter(([id]) => stockById[id]) // drop items that vanished after a refresh
    .map(([id, quantity]) => ({ ...stockById[id].products, quantity }))
  const itemCount = lines.reduce((sum, line) => sum + line.quantity, 0)
  const estimatedTotal = lines.reduce((sum, line) => sum + line.price * line.quantity, 0)

  function changeQuantity(productId, delta) {
    setMessage(null)
    setCart((current) => {
      const { [productId]: oldQuantity = 0, ...others } = current
      const quantity = oldQuantity + delta
      return quantity > 0 ? { ...others, [productId]: quantity } : others
    })
  }

  // Stock checks and the order itself happen inside the place_order database function, in one transaction.
  async function checkout() {
    setPlacing(true)
    setError(null)
    setMessage(null)
    try {
      const orderId = await placeOrder({
        customerId: data.customerId,
        storeId: data.storeId,
        items: lines.map((line) => ({ product_id: line.product_id, quantity: line.quantity })),
      })
      setCart({})
      setMessage(`Order #${orderId} placed.`)
    } catch (orderError) {
      setError(orderError.message)
    }
    reload() // stock may have changed either way
    setPlacing(false)
  }

  return (
    <>
      <h1>Shop</h1>

      <div className="shop-layout">
        <section aria-labelledby="products-title">
          <h2 id="products-title">Products</h2>

          <div className="shop-toolbar">
            <input type="search" className="search-input" placeholder="Search products" aria-label="Search products"
              value={search} onChange={(event) => setSearch(event.target.value)} />
            <div className="chips" role="group" aria-label="Filter by category">
              {['', ...categories].map((name) => (
                <button type="button" key={name || 'all'} className="chip" aria-pressed={category === name}
                  onClick={() => setCategory(name)}>
                  {name || 'All'}
                </button>
              ))}
            </div>
          </div>

          {data.stock.length === 0 && <p className="card">No products are available right now.</p>}
          {data.stock.length > 0 && visible.length === 0 && <p className="card">No products match your search.</p>}

          <div className="product-grid">
            {visible.map((row) => {
              const product = row.products
              const inCart = cart[product.product_id] ?? 0
              return (
                <article className="card product-card" key={product.product_id}>
                  <h3>{product.product_name}</h3>
                  <p className="muted">{product.categories.category_name}</p>
                  <p className="price">{formatMoney(product.price)}</p>
                  <p className={row.current_stock > 0 ? 'muted' : 'out-of-stock'}>
                    {row.current_stock > 0 ? `${row.current_stock} in stock` : 'Out of stock'}
                  </p>
                  {inCart === 0 ? (
                    <button type="button" className="btn btn-small" disabled={row.current_stock === 0}
                      onClick={() => changeQuantity(product.product_id, 1)}>
                      Add
                    </button>
                  ) : (
                    <QuantityStepper name={product.product_name} quantity={inCart} max={row.current_stock}
                      onChange={(delta) => changeQuantity(product.product_id, delta)} />
                  )}
                </article>
              )
            })}
          </div>
        </section>

        <aside className="card cart" aria-labelledby="cart-title">
          <h2 id="cart-title">Your cart{itemCount > 0 && ` (${itemCount})`}</h2>
          {lines.length === 0 && <p className="muted">Your cart is empty. Add something from the shelves.</p>}
          {lines.map((line) => (
            <div className="cart-line" key={line.product_id}>
              <span>{line.product_name}</span>
              <QuantityStepper name={line.product_name} quantity={line.quantity} max={stockById[line.product_id].current_stock}
                onChange={(delta) => changeQuantity(line.product_id, delta)} />
              <span>{formatMoney(line.price * line.quantity)}</span>
            </div>
          ))}
          {lines.length > 0 && <p className="cart-total">Estimated total: {formatMoney(estimatedTotal)}</p>}
          {error && <p className="form-error" role="alert">{error}</p>}
          {message && <p className="form-success" role="status">{message}</p>}
          <button type="button" className="btn" disabled={placing || lines.length === 0} onClick={checkout}>
            {placing ? 'Placing order…' : 'Place order'}
          </button>
        </aside>
      </div>

      <section className="card panel" aria-labelledby="history-title">
        <h2 id="history-title">Order history</h2>
        <div className="table-wrap">
          <table>
            <thead>
              <tr><th>Order</th><th>Items</th><th>Status</th><th>Total</th><th>Placed</th></tr>
            </thead>
            <tbody>
              {data.orders.length === 0 && <tr><td colSpan={5} className="empty">You have not placed any orders yet.</td></tr>}
              {data.orders.map((order) => (
                <tr key={order.order_id}>
                  <td>#{order.order_id}</td>
                  <td className="wrap-cell">
                    {/* products is empty if the item was later deactivated (RLS hides inactive products). */}
                    {order.order_items.map((item) => `${item.products?.product_name ?? 'Unavailable item'} × ${item.quantity}`).join(', ')}
                  </td>
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
