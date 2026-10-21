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

  const Page = pages[role]
  return (
    <DashboardLayout role={role}>
      <Page />
    </DashboardLayout>
  )
}
