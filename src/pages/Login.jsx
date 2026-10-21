import { useState } from 'react'
import { Link, Navigate, useNavigate, useParams } from 'react-router-dom'
import { useAuth } from '../AuthContext'
import { roles } from '../roles'
import '../styles/login.css'

const DEMO_CREDENTIALS = {
  customer: {
    email: 'test_customer_demo123@example.com',
    password: 'Password123!',
    label: 'Test Customer',
  },
  rider: {
    email: 'demo_rider@example.com',
    password: 'Password123!',
    label: 'Demo Rider (#3)',
  },
  manager: {
    email: 'manager@demo.com',
    password: 'Password123!',
    label: 'Kothrud Store Manager',
  },
}

export default function Login() {
  const { role: chosenRole } = useParams()
  const navigate = useNavigate()
  const { session, role: activeRole, loading, signIn, signUp, signOut } = useAuth()
  const [signingUp, setSigningUp] = useState(false)
  const [fullName, setFullName] = useState('')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState(null)
  const [message, setMessage] = useState(null)
  const [submitting, setSubmitting] = useState(false)

  if (!roles[chosenRole]) return <Navigate to="/" replace />
  if (loading) return <div className="login-page"><p className="notice">Loading authentication…</p></div>

  // If already logged in and role matches the chosen portal, proceed to dashboard
  if (session && activeRole === chosenRole) {
    return <Navigate to={`/dashboard/${chosenRole}`} replace />
  }

  const roleMeta = roles[chosenRole]
  const demoCreds = DEMO_CREDENTIALS[chosenRole]

  function fillDemo() {
    if (demoCreds) {
      setEmail(demoCreds.email)
      setPassword(demoCreds.password)
      setError(null)
      setMessage(`Loaded credentials for ${demoCreds.label}`)
    }
  }

  async function handleSubmit(event) {
    event.preventDefault()
    setSubmitting(true)
    setError(null)
    setMessage(null)

    const result = signingUp
      ? await signUp(chosenRole, fullName, email, password)
      : await signIn(email, password, chosenRole)

    if (result?.error) setError(result.error.message)
    if (result?.needsConfirmation) {
      setMessage('Account created! Please check your email to confirm, then sign in.')
      setSigningUp(false)
    }
    setSubmitting(false)
  }

  function toggleMode() {
    setSigningUp(!signingUp)
    setError(null)
    setMessage(null)
  }

  return (
    <main className="login-page">
      <div className="login-container">
        {/* Quick Role Switcher Tabs */}
        <div className="role-switcher" role="tablist" aria-label="Select portal role">
          {Object.entries(roles).map(([rKey, rVal]) => (
            <button
              key={rKey}
              type="button"
              className={`role-tab ${chosenRole === rKey ? 'active' : ''}`}
              onClick={() => {
                setError(null)
                setMessage(null)
                navigate(`/login/${rKey}`)
              }}
            >
              {rKey === 'customer' && '🛒'}
              {rKey === 'rider' && '🛵'}
              {rKey === 'manager' && '🏬'}
              <span>{rVal.title}</span>
            </button>
          ))}
        </div>

        <div className="card login-card">
          <div className="login-header">
            <span className="brand-pill">
              {chosenRole === 'customer' && '⚡ Express Storefront'}
              {chosenRole === 'rider' && '🛵 Fleet Partner'}
              {chosenRole === 'manager' && '🏬 Store Management'}
            </span>
            <h1>{roleMeta.title} {signingUp ? 'Sign Up' : 'Portal'}</h1>
            <p className="login-desc">{roleMeta.description}</p>
          </div>

          {/* If signed in as a DIFFERENT role: provide seamless switch account screen */}
          {session && activeRole && activeRole !== chosenRole ? (
            <div className="activation-box">
              <div className="activation-notice">
                <span className="activation-icon">🔒</span>
                <div>
                  <strong>Role Isolation Enforced</strong>
                  <p>
                    You are signed in as <strong>{roles[activeRole]?.title || activeRole}</strong> ({session.user.email}).
                  </p>
                  <p style={{ marginTop: '0.25rem', fontSize: '0.85rem', color: 'var(--muted)' }}>
                    Each role requires a separate dedicated account. Please sign out to log into the {roleMeta.title} workspace.
                  </p>
                </div>
              </div>

              <div style={{ display: 'flex', flexDirection: 'column', gap: '0.75rem', marginTop: '1.25rem' }}>
                <button
                  type="button"
                  className="btn btn-lg"
                  disabled={submitting}
                  onClick={async () => {
                    setSubmitting(true)
                    await signOut()
                    setSubmitting(false)
                  }}
                >
                  Sign Out & Sign in as {roleMeta.title}
                </button>

                <a
                  href={`/dashboard/${activeRole}`}
                  className="btn btn-ghost"
                  style={{ textAlign: 'center', textDecoration: 'none' }}
                >
                  Continue to My {roles[activeRole]?.title || activeRole} Dashboard →
                </a>
              </div>
            </div>
          ) : (
            <>
              {/* Demo Account Quick-Fill Card */}
              {demoCreds && !signingUp && (
                <div style={{
                  background: 'var(--cream)',
                  border: '1px solid var(--border)',
                  borderRadius: '12px',
                  padding: '0.75rem 1rem',
                  marginBottom: '1.25rem',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  gap: '0.5rem',
                }}>
                  <div style={{ fontSize: '0.85rem' }}>
                    <span style={{ fontWeight: 600, color: 'var(--navy)', display: 'block' }}>
                      🔑 Demo Account Available
                    </span>
                    <span style={{ color: 'var(--muted)', fontSize: '0.8rem' }}>
                      {demoCreds.email}
                    </span>
                  </div>
                  <button
                    type="button"
                    className="btn btn-small"
                    onClick={fillDemo}
                    style={{ whiteSpace: 'nowrap' }}
                  >
                    1-Click Fill
                  </button>
                </div>
              )}

              <form onSubmit={handleSubmit}>
                {signingUp && (
                  <div className="input-group">
                    <label htmlFor="fullName">Full Name</label>
                    <input
                      id="fullName"
                      type="text"
                      autoComplete="name"
                      required
                      placeholder="e.g. Aarav Sharma"
                      value={fullName}
                      onChange={(e) => setFullName(e.target.value)}
                    />
                  </div>
                )}

                <div className="input-group">
                  <label htmlFor="email">Email Address</label>
                  <input
                    id="email"
                    type="email"
                    autoComplete="email"
                    required
                    placeholder="name@example.com"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                  />
                </div>

                <div className="input-group">
                  <label htmlFor="password">Password</label>
                  <input
                    id="password"
                    type="password"
                    required
                    minLength={signingUp ? 8 : undefined}
                    autoComplete={signingUp ? 'new-password' : 'current-password'}
                    placeholder="••••••••"
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                  />
                </div>

                {message && <p className="form-success" role="status">{message}</p>}
                {error && <p className="form-error" role="alert">{error}</p>}

                <button type="submit" className="btn btn-lg" disabled={submitting}>
                  {submitting
                    ? 'Please wait…'
                    : signingUp
                    ? `Create ${roleMeta.title} Account`
                    : `Sign In as ${roleMeta.title}`}
                </button>
              </form>
            </>
          )}

          {!session && (
            <div className="login-footer">
              {chosenRole !== 'manager' ? (
                <button type="button" className="link-button" onClick={toggleMode}>
                  {signingUp ? 'Already have an account? Sign in' : "Don't have an account? Sign up in 10s"}
                </button>
              ) : (
                <span className="muted" style={{ fontSize: '0.85rem' }}>
                  🏬 Manager accounts are pre-authorized for dark store staff.
                </span>
              )}
              <Link to="/" className="home-link">← Return to Home</Link>
            </div>
          )}
        </div>
      </div>
    </main>
  )
}
