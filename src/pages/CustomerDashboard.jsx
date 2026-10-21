import { useState } from 'react'
import { fetchCustomerData, placeOrder } from '../api/customer'
import { formatDate, formatMoney, formatStatus } from '../format'
import { LoadGate, useLoad } from '../useLoad'
import '../styles/data.css'
import '../styles/customer.css'

const categoryIcons = {
  Dairy: '🥛',
  'Fruits & Vegetables': '🍎',
  Snacks: '🍿',
  Beverages: '🥤',
}

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
    <div className="qty-controls">
      <button
        type="button"
        className="qty-btn"
        aria-label={`Remove one ${name}`}
        onClick={() => onChange(-1)}
      >
        −
      </button>
      <span className="qty-value" aria-live="polite">{quantity}</span>
      <button
        type="button"
        className="qty-btn"
        aria-label={`Add one ${name}`}
        disabled={quantity >= max}
        onClick={() => onChange(1)}
      >
        +
      </button>
    </div>
  )
}

function Storefront({ data, reload }) {
  const [search, setSearch] = useState('')
  const [category, setCategory] = useState('')
  const [cart, setCart] = useState({})
  const [placing, setPlacing] = useState(false)
  const [error, setError] = useState(null)
  const [message, setMessage] = useState(null)

  const categories = [...new Set(data.stock.map((row) => row.products.categories.category_name))]
  const query = search.trim().toLowerCase()
  const visible = data.stock.filter(({ products: product }) =>
    (category === '' || product.categories.category_name === category) &&
    product.product_name.toLowerCase().includes(query)
  )

  const stockById = Object.fromEntries(data.stock.map((row) => [row.products.product_id, row]))
  const lines = Object.entries(cart)
    .filter(([id]) => stockById[id])
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
      setMessage(`Order #${orderId} confirmed! Our rider is packing your bag right now.`)
    } catch (orderError) {
      setError(orderError.message)
    }
    reload()
    setPlacing(false)
  }

  return (
    <div className="storefront-page">
      {/* Hyper-Local Storefront Banner */}
      <div className="store-banner">
        <div className="store-banner-content">
          <div className="store-tag">⚡ 10-Minute Instant Delivery</div>
          <h2>QuickMart Kothrud Hub</h2>
          <p className="store-address">
            📍 Delivering from 12 Karve Road to <strong>Zone 411038</strong> · Live inventory sync enabled
          </p>
        </div>
        <div className="store-stats-pills">
          <div className="stat-pill">
            <span className="stat-pill-icon">⏱️</span>
            <div>
              <span className="stat-pill-label">Avg Delivery</span>
              <span className="stat-pill-val">8-10 Mins</span>
            </div>
          </div>
          <div className="stat-pill">
            <span className="stat-pill-icon">🛵</span>
            <div>
              <span className="stat-pill-label">Fleet Status</span>
              <span className="stat-pill-val text-green">Riders Ready</span>
            </div>
          </div>
        </div>
      </div>

      <div className="shop-layout">
        <section className="catalog-section" aria-labelledby="products-title">
          <div className="catalog-header">
            <div>
              <h2 id="products-title">Fresh Groceries & Essentials</h2>
              <p className="section-subtitle">Real-time stock from the local micro-fulfilment center</p>
            </div>
          </div>

          <div className="shop-toolbar">
            <div className="search-wrap">
              <span className="search-icon">🔍</span>
              <input
                type="search"
                className="search-input"
                placeholder="Search milk, bread, paneer, drinks..."
                aria-label="Search products"
                value={search}
                onChange={(event) => setSearch(event.target.value)}
              />
              {search && (
                <button
                  type="button"
                  className="search-clear"
                  onClick={() => setSearch('')}
                  aria-label="Clear search"
                >
                  ✕
                </button>
              )}
            </div>

            <div className="chips" role="group" aria-label="Filter by category">
              <button
                type="button"
                className="chip"
                aria-pressed={category === ''}
                onClick={() => setCategory('')}
              >
                <span>🏷️</span>
                <span>All Items ({data.stock.length})</span>
              </button>
              {categories.map((name) => (
                <button
                  type="button"
                  key={name}
                  className="chip"
                  aria-pressed={category === name}
                  onClick={() => setCategory(name)}
                >
                  <span>{categoryIcons[name] || '📦'}</span>
                  <span>{name}</span>
                </button>
              ))}
            </div>
          </div>

          {data.stock.length === 0 && (
            <div className="card empty-card">
              <span className="empty-emoji">🏬</span>
              <h3>No products available</h3>
              <p>The shelves are being restocked. Please check back shortly.</p>
            </div>
          )}

          {data.stock.length > 0 && visible.length === 0 && (
            <div className="card empty-card">
              <span className="empty-emoji">🔍</span>
              <h3>No matching products</h3>
              <p>Try searching with another keyword or browse all categories.</p>
            </div>
          )}

          <div className="product-grid">
            {visible.map((row) => {
              const product = row.products
              const inCart = cart[product.product_id] ?? 0
              const isLowStock = row.current_stock > 0 && row.current_stock <= row.reorder_threshold
              const isOutOfStock = row.current_stock === 0

              return (
                <article className="card product-card" key={product.product_id}>
                  <div className="product-category-row">
                    <span className="product-cat-tag">
                      {categoryIcons[product.categories.category_name] || '•'} {product.categories.category_name}
                    </span>
                    {isLowStock && (
                      <span className="stock-alert-pill">⚡ Only {row.current_stock} left</span>
                    )}
                  </div>

                  <h3 className="product-name">{product.product_name}</h3>

                  <div className="product-pricing">
                    <span className="price-symbol">₹</span>
                    <span className="price-amount">{Number(product.price).toFixed(2)}</span>
                  </div>

                  <div className="product-stock-row">
                    {isOutOfStock ? (
                      <span className="stock-label out-of-stock">Sold out</span>
                    ) : (
                      <span className="stock-label in-stock">
                        <span className="stock-dot"></span>
                        {row.current_stock} in stock
                      </span>
                    )}
                  </div>

                  <div className="product-action-row">
                    {inCart === 0 ? (
                      <button
                        type="button"
                        className="btn btn-add"
                        disabled={isOutOfStock}
                        onClick={() => changeQuantity(product.product_id, 1)}
                      >
                        + Add to Cart
                      </button>
                    ) : (
                      <QuantityStepper
                        name={product.product_name}
                        quantity={inCart}
                        max={row.current_stock}
                        onChange={(delta) => changeQuantity(product.product_id, delta)}
                      />
                    )}
                  </div>
                </article>
              )
            })}
          </div>
        </section>

        {/* Live Express Cart Sidebar */}
        <aside className="card cart-panel" aria-labelledby="cart-title">
          <div className="cart-header">
            <h2 id="cart-title">
              <span>🛒</span> Your Basket {itemCount > 0 && <span className="cart-count-badge">{itemCount}</span>}
            </h2>
            <div className="cart-perk">
              <span className="perk-icon">⚡</span>
              <span>FREE 10-Min Delivery</span>
            </div>
          </div>

          {lines.length === 0 ? (
            <div className="empty-cart-state">
              <span className="empty-basket-icon">🧺</span>
              <p className="empty-cart-text">Your basket is currently empty.</p>
              <span className="empty-cart-sub">Add fresh items from the store to unlock superfast delivery.</span>
            </div>
          ) : (
            <>
              <div className="cart-lines-list">
                {lines.map((line) => (
                  <div className="cart-item" key={line.product_id}>
                    <div className="cart-item-info">
                      <span className="cart-item-name">{line.product_name}</span>
                      <span className="cart-item-unit-price">{formatMoney(line.price)} / unit</span>
                    </div>

                    <QuantityStepper
                      name={line.product_name}
                      quantity={line.quantity}
                      max={stockById[line.product_id].current_stock}
                      onChange={(delta) => changeQuantity(line.product_id, delta)}
                    />

                    <span className="cart-item-total">{formatMoney(line.price * line.quantity)}</span>
                  </div>
                ))}
              </div>

              {/* Bill Details */}
              <div className="cart-bill">
                <div className="bill-row">
                  <span>Item Subtotal</span>
                  <span>{formatMoney(estimatedTotal)}</span>
                </div>
                <div className="bill-row">
                  <span>10-Min Delivery Fee</span>
                  <span className="free-tag"><del>₹30.00</del> FREE</span>
                </div>
                <div className="bill-row">
                  <span>Handling & Bag</span>
                  <span className="free-tag">FREE</span>
                </div>
                <div className="bill-divider"></div>
                <div className="bill-row bill-total">
                  <span>To Pay</span>
                  <span className="total-val">{formatMoney(estimatedTotal)}</span>
                </div>
              </div>
            </>
          )}

          {error && <p className="form-error" role="alert">{error}</p>}
          {message && <p className="form-success" role="status">{message}</p>}

          <button
            type="button"
            className="btn btn-checkout btn-lg"
            disabled={placing || lines.length === 0}
            onClick={checkout}
          >
            {placing ? (
              'Processing atomic checkout…'
            ) : (
              <>
                <span>Place Order (₹{estimatedTotal.toFixed(2)})</span>
                <span>⚡</span>
              </>
            )}
          </button>
        </aside>
      </div>

      {/* Customer Order History */}
      <section className="card panel history-panel" aria-labelledby="history-title">
        <div className="history-header">
          <div>
            <h2 id="history-title">Past Orders & Live Tracking</h2>
            <p className="section-subtitle">Real-time status updates from our delivery fleet</p>
          </div>
          <span className="history-count">{data.orders.length} Total Orders</span>
        </div>

        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Order #</th>
                <th>Items Ordered</th>
                <th>Status</th>
                <th>Bill Amount</th>
                <th>Placed At</th>
              </tr>
            </thead>
            <tbody>
              {data.orders.length === 0 && (
                <tr>
                  <td colSpan={5} className="empty">
                    You have not placed any orders yet. Fresh groceries are waiting on the shelves!
                  </td>
                </tr>
              )}
              {data.orders.map((order) => (
                <tr key={order.order_id}>
                  <td className="order-id-cell">
                    <strong>#{order.order_id}</strong>
                  </td>
                  <td className="wrap-cell">
                    <div className="order-items-preview">
                      {order.order_items.map((item, idx) => (
                        <span className="item-pill" key={idx}>
                          {item.products?.product_name ?? 'Unavailable item'} × {item.quantity}
                        </span>
                      ))}
                    </div>
                  </td>
                  <td>
                    <span className={`badge badge-${order.status}`}>
                      {order.status === 'placed' && '🟡 '}
                      {order.status === 'packed' && '📦 '}
                      {order.status === 'out_for_delivery' && '🛵 '}
                      {order.status === 'delivered' && '✅ '}
                      {formatStatus(order.status)}
                    </span>
                  </td>
                  <td className="order-total-cell">{formatMoney(order.total_amount)}</td>
                  <td className="order-time-cell">{formatDate(order.placed_at)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  )
}
