import { useState } from 'react'
import { Link } from 'react-router-dom'
import { useAuth } from '../AuthContext'
import { roles } from '../roles'
import '../styles/dashboard.css'

const navIcons = {
  overview: '📊',
  'inventory-title': '📦',
  'alerts-title': '⚠️',
  'orders-title': '📋',
  'assigned-orders': '🛵',
  'products-title': '🛍️',
  'cart-title': '🛒',
  'history-title': '🧾',
}

export default function DashboardLayout({ role, children }) {
  const { title, nav } = roles[role]
  const { session, signOut } = useAuth()
  const [active, setActive] = useState(nav[0]?.target || '')

  function jumpTo(event, target) {
    event.preventDefault()
    document.getElementById(target)?.scrollIntoView({ behavior: 'smooth', block: 'start' })
    setActive(target)
  }

  const roleEmoji = role === 'customer' ? '🛒' : role === 'rider' ? '🛵' : '🏬'

  return (
    <div className="dashboard">
      <aside className="sidebar">
        <div className="sidebar-brand">
          <Link to="/" className="brand">
            <span className="brand-badge">DS</span>
            <span>Dark Store</span>
          </Link>
          <div className="store-location-badge">
            <span className="store-pulse"></span>
            <span>QuickMart Kothrud · 411038</span>
          </div>
        </div>

        <nav aria-label={`${title} navigation`} className="sidebar-nav">
          <span className="nav-heading">Menu</span>
          <ul>
            {nav.map(({ label, target }) => (
              <li key={target}>
                <a
                  href={`#${target}`}
                  className="nav-item"
                  onClick={(event) => jumpTo(event, target)}
                  aria-current={target === active ? 'true' : undefined}
                >
                  <span className="nav-icon">{navIcons[target] || '•'}</span>
                  <span>{label}</span>
                </a>
              </li>
            ))}
          </ul>
        </nav>

        <div className="sidebar-footer">
          <div className="user-profile-badge">
            <span className="user-avatar">{roleEmoji}</span>
            <div className="user-info">
              <span className="user-name">
                {session?.user?.user_metadata?.full_name || session?.user?.email?.split('@')[0] || 'Demo User'}
              </span>
              <span className="user-role-label">{title}</span>
            </div>
          </div>
        </div>
      </aside>

      <div className="dashboard-body">
        <header className="topbar">
          <div className="topbar-left">
            <span className={`role-badge role-${role}`}>
              <span>{roleEmoji}</span>
              <span>{title} Portal</span>
            </span>
            <div className="delivery-guarantee-pill">
              <span className="zap-icon">⚡</span>
              <span>10-Min Fast Fulfilment</span>
            </div>
          </div>
          <div className="topbar-actions">
            <Link className="btn btn-ghost btn-small" to="/">Home</Link>
            <button type="button" className="btn btn-ghost btn-small" onClick={signOut}>Sign out</button>
          </div>
        </header>
        <main className="dashboard-main">{children}</main>
      </div>
    </div>
  )
}
