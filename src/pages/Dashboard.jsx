import { Navigate, useParams } from 'react-router-dom'
import { useAuth } from '../AuthContext'
import DashboardLayout from '../components/DashboardLayout'
import { roles } from '../roles'
import CustomerDashboard from './CustomerDashboard'
import ManagerDashboard from './ManagerDashboard'
import RiderDashboard from './RiderDashboard'

const pages = { manager: ManagerDashboard, rider: RiderDashboard, customer: CustomerDashboard }

export default function Dashboard() {
  const { role } = useParams()
  const { session, role: myRole, loading, signOut } = useAuth()

  if (!roles[role]) return <Navigate to="/" replace />
  if (loading) return <div className="loading-container"><p className="notice">Loading dark store console…</p></div>
  // Not signed in: redirect to login for that role
  if (!session || !myRole) return <Navigate to={`/login/${role}`} replace />

  // Signed in as a different role: explain clearly instead of silently redirecting!
  if (myRole !== role) {
    const currentTitle = roles[myRole]?.title || myRole
    const targetTitle = roles[role]?.title || role
    return (
      <div className="login-page">
        <div className="login-container">
          <div className="card login-card" style={{ maxWidth: '540px' }}>
            <div className="login-header">
              <span className="brand-pill">🔒 Access Isolation</span>
              <h1>{targetTitle} Workspace</h1>
              <p className="login-desc">
                Role isolation is strictly enforced. You are currently signed in with a <strong>{currentTitle}</strong> account ({session?.user?.email}).
              </p>
            </div>

            <div style={{ padding: '1rem', background: 'var(--cream)', borderRadius: '12px', marginBottom: '1.5rem', border: '1px solid var(--border)' }}>
              <p style={{ margin: '0 0 0.5rem', fontSize: '0.9rem', color: 'var(--navy)' }}>
                👉 To protect dark store operations, a customer cannot access rider or store manager controls on the same account.
              </p>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '0.75rem' }}>
              <a
                href={`/dashboard/${myRole}`}
                className="btn btn-lg"
                style={{ textAlign: 'center', textDecoration: 'none' }}
              >
                Go to My {currentTitle} Dashboard →
              </a>
              <button
                type="button"
                className="btn btn-ghost"
                onClick={async () => {
                  await signOut()
                  window.location.href = `/login/${role}`
                }}
              >
                Sign Out & Switch to {targetTitle} Account
              </button>
            </div>
          </div>
        </div>
      </div>
    )
  }

  const Page = pages[role]
  return (
    <DashboardLayout role={role}>
      <Page />
    </DashboardLayout>
  )
}
