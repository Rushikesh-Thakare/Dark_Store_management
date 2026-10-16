import { useState } from 'react'
import { Link } from 'react-router-dom'
import { useAuth } from '../AuthContext'
import { roles } from '../roles'
import '../styles/dashboard.css'

export default function DashboardLayout({ role, children }) {
  const { title, nav } = roles[role]
  const { signOut } = useAuth()
  const [active, setActive] = useState(nav[0].target)

  // Scroll to the section without changing the URL, so the router and sign-in guard are not disturbed.
  function jumpTo(event, target) {
    event.preventDefault()
    document.getElementById(target)?.scrollIntoView({ behavior: 'smooth', block: 'start' })
    setActive(target)
  }

  return (
    <div className="dashboard">
      <aside className="sidebar">
        <span className="brand">Dark Store</span>
        <nav aria-label={`${title} navigation`}>
          <ul>
            {nav.map(({ label, target }) => (
              <li key={target}>
                <a href={`#${target}`} className="nav-item" onClick={(event) => jumpTo(event, target)}
                  aria-current={target === active ? 'true' : undefined}>
                  {label}
                </a>
              </li>
            ))}
          </ul>
        </nav>
      </aside>

      <div className="dashboard-body">
        <header className="topbar">
          <span className="role-badge">{title}</span>
          <div className="topbar-actions">
            <Link className="btn btn-ghost" to="/">Home</Link>
            <button type="button" className="btn btn-ghost" onClick={signOut}>Sign out</button>
          </div>
        </header>
        <main className="dashboard-main">{children}</main>
      </div>
    </div>
  )
}
