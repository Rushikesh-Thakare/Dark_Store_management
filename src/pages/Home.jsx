import { useState } from 'react'
import { Link } from 'react-router-dom'
import { roles } from '../roles'
import '../styles/home.css'
import '../styles/sections.css'
import '../styles/team.css'
import '../styles/footer.css'
import '../styles/motion.css'

const trust = ['Live inventory', 'Safe order handling', 'Role-based access']

// Hero preview: a mock-up of the manager dashboard using the seeded demo numbers.
const previewStats = [['10', 'Products'], ['1', 'Low stock'], ['2', 'Riders'], ['1', 'Store']]
const previewRows = [
  ['Full cream milk', '50', false],
  ['Paneer 200g', '6', false],
  ['Orange juice 1L', '4', true],
  ['Curd 400g', '30', false],
]

const capabilities = [
  ['Inventory control', 'Stock is tracked per store and product, with reorder levels, and can never go negative.'],
  ['Order management', 'Orders are checked against live stock and confirmed in full, or not at all.'],
  ['Rider delivery', 'Assigned riders see their orders and move them from dispatch to delivered.'],
  ['Low-stock alerts', 'An alert is raised automatically the moment an item reaches its reorder level.'],
  ['Manager dashboard', 'Summary cards, inventory status, open alerts and recent orders in one view.'],
  ['Role-based access', 'Managers, riders and customers each see only the data they are allowed to.'],
]

const steps = [
  ['Order placed', 'The request is checked against live stock and confirmed completely, or rejected with a clear reason.'],
  ['Stock updated', 'Inventory drops automatically, and a low-stock item raises a restock alert for the manager.'],
  ['Rider delivers', 'The assigned rider updates the order through dispatch to delivered, with times recorded.'],
]

const core = [
  ['PostgreSQL', 'A relational core with keys and constraints that keep every record valid.'],
  ['Transactions', 'Order placement either succeeds completely or leaves no trace.'],
  ['Triggers', 'Restock alerts are raised by the database itself, without duplicates.'],
  ['Row Level Security', 'Access rules are enforced inside the database, not just on screen.'],
]

const roleOrder = ['manager', 'rider', 'customer']
const roleIcons = { manager: '📊', rider: '🛵', customer: '🛒' }

// Photos live in public/team/<Full Name>.png.
const team = ['Rushikesh Thakare', 'Aashay Kulkarni', 'Nikita Dokhale']

// Shows the photo; if the file is missing or broken, shows the person's initials instead.
function Avatar({ name }) {
  const [failed, setFailed] = useState(false)

  if (failed) {
    const initials = name.split(' ').map((word) => word[0]).join('')
    return <span className="avatar avatar-initials" aria-hidden="true">{initials}</span>
  }
  return (
    <img className="avatar" width="96" height="96" loading="lazy" src={`/team/${encodeURIComponent(name)}.png`}
      alt={`Photo of ${name}`} onError={() => setFailed(true)} />
  )
}

export default function Home() {
  return (
    <div className="home">
      <header className="home-header">
        <div className="container header-inner">
          <span className="brand"><span className="brand-mark" aria-hidden="true">DS</span>Dark Store Management</span>
          <nav aria-label="Page sections" className="home-nav">
            <a href="#features">Platform</a>
            <a href="#how-it-works">How it works</a>
            <a href="#core">Technology</a>
            <a href="#team">Team</a>
          </nav>
          <a className="btn btn-small" href="#roles">Get started</a>
        </div>
      </header>

      <main>
        <section className="container hero">
          <div className="hero-copy">
            <p className="eyebrow">Dark store operations platform</p>
            <h1>Run your dark store with complete control.</h1>
            <p className="lead">
              One system for inventory, orders, riders and restock alerts. Accurate stock, safe order
              handling and the right access for every member of your team.
            </p>
            <div className="hero-actions">
              <a className="btn btn-lg" href="#roles">Choose your role</a>
              <a className="btn btn-lg btn-ghost" href="#how-it-works">See how it works</a>
            </div>
            <ul className="trust-row">
              {trust.map((item) => <li key={item}>{item}</li>)}
            </ul>
          </div>

          <div className="hero-visual" aria-hidden="true">
            <div className="preview">
              <p className="preview-bar">Manager dashboard</p>
              <div className="preview-stats">
                {previewStats.map(([value, label]) => (
                  <div key={label}>
                    <strong>{value}</strong>
                    <span>{label}</span>
                  </div>
                ))}
              </div>
              <ul className="preview-rows">
                {previewRows.map(([name, stock, low]) => (
                  <li key={name}>
                    <span>{name}</span>
                    <span>{stock}</span>
                    <span className={low ? 'preview-badge preview-badge-low' : 'preview-badge'}>{low ? 'Low stock' : 'In stock'}</span>
                  </li>
                ))}
              </ul>
            </div>
            <p className="preview-alert">⚠ Orange juice reached its reorder level</p>
          </div>
        </section>

        <section id="features" className="container" aria-labelledby="features-title">
          <div className="section-head reveal">
            <h2 id="features-title">Everything a dark store runs on</h2>
            <p className="lead">Inventory, orders and deliveries in one connected system.</p>
          </div>
          <ul className="feature-grid reveal">
            {capabilities.map(([name, text], index) => (
              <li className="card feature-card" key={name}>
                <span className="feature-number">0{index + 1}</span>
                <h3>{name}</h3>
                <p>{text}</p>
              </li>
            ))}
          </ul>
        </section>

        <section id="how-it-works" className="container" aria-labelledby="steps-title">
          <div className="section-head reveal">
            <h2 id="steps-title">How it works</h2>
            <p className="lead">From a new order to a completed delivery.</p>
          </div>
          <ol className="steps reveal">
            {steps.map(([name, text], index) => (
              <li className="step" key={name}>
                <span className="step-number">{index + 1}</span>
                <h3>{name}</h3>
                <p>{text}</p>
              </li>
            ))}
          </ol>
        </section>

        <section id="roles" className="container" aria-labelledby="roles-title">
          <div className="section-head reveal">
            <h2 id="roles-title">Choose your role</h2>
            <p className="lead">Each role gets its own workspace.</p>
          </div>
          <div className="role-grid reveal">
            {roleOrder.map((key) => (
              <article className="card role-card" key={key}>
                <span className="role-icon" aria-hidden="true">{roleIcons[key]}</span>
                <h3>{roles[key].title}</h3>
                <p>{roles[key].description}</p>
                <Link className="btn" to={`/dashboard/${key}`}>Open {roles[key].title} Workspace</Link>
              </article>
            ))}
          </div>
          <p className="note">Choosing a role only opens the sign-in page. Access is decided after you sign in.</p>
        </section>

        <section id="core" className="container">
          <div className="core-band">
            <div className="section-head">
              <h2>Built on a reliable database core</h2>
              <p>The rules that keep a store honest are enforced in the database itself.</p>
            </div>
            <ul className="core-grid">
              {core.map(([name, text]) => (
                <li key={name}>
                  <h3>{name}</h3>
                  <p>{text}</p>
                </li>
              ))}
            </ul>
          </div>
        </section>

        <section id="team" className="container team" aria-labelledby="team-title">
          <h2 id="team-title">The team</h2>
          <ul className="team-grid">
            {team.map((name) => (
              <li className="team-member" key={name}>
                <Avatar name={name} />
                <p className="team-name">{name}</p>
              </li>
            ))}
          </ul>
          <p className="guide-line">Under the guidance of Prof. Rupali Sawant.</p>
        </section>
      </main>

      <footer className="home-footer">
        <div className="container footer-grid">
          <div>
            <span className="brand"><span className="brand-mark" aria-hidden="true">DS</span>Dark Store Management</span>
            <p>Inventory, orders and riders for the modern dark store.</p>
          </div>
          <div>
            <h3>Platform</h3>
            <a href="#features">Capabilities</a>
            <a href="#how-it-works">How it works</a>
            <a href="#core">Technology</a>
          </div>
          <div>
            <h3>Sign in</h3>
            {roleOrder.map((key) => <Link key={key} to={`/login/${key}`}>{roles[key].title}</Link>)}
          </div>
        </div>
        <p className="container footer-bottom">
          © 2026 Dark Store Management System · A DBMS academic project, built with PostgreSQL, Supabase and React.
        </p>
      </footer>
    </div>
  )
}
