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
  const { session, role: myRole, loading } = useAuth()

  if (!roles[role]) return <Navigate to="/" replace />
  if (loading) return <p className="notice">Loading…</p>
  // Not signed in, or no role in the database: the login page explains which.
  if (!session || !myRole) return <Navigate to={`/login/${role}`} replace />
  // Signed in as a different role: send them to their own dashboard.
  if (myRole !== role) return <Navigate to={`/dashboard/${myRole}`} replace />

  const Page = pages[role]
  return (
    <DashboardLayout role={role}>
      <Page />
    </DashboardLayout>
  )
}
