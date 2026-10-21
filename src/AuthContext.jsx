import { createContext, useContext, useEffect, useState } from 'react'
import { supabase } from './lib/supabase'

const AuthContext = createContext(null)

export function AuthProvider({ children }) {
  const [session, setSession] = useState(null)
  const [sessionLoading, setSessionLoading] = useState(true)
  // Remembers which user the role belongs to, so a stale role is never shown to another user.
  const [profile, setProfile] = useState({ userId: null, role: null, error: null })
  const [refreshKey, setRefreshKey] = useState(0)

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => {
      setSession(data.session)
      setSessionLoading(false)
    })
    const { data } = supabase.auth.onAuthStateChange((_event, newSession) => setSession(newSession))
    return () => data.subscription.unsubscribe()
  }, [])

  const userId = session?.user.id

  // The role comes from the database (profiles table, protected by RLS), never from the URL or home page.
  useEffect(() => {
    if (!userId) return
    let cancelled = false
    supabase
      .from('profiles')
      .select('role')
      .eq('user_id', userId)
      .maybeSingle()
      .then(({ data, error }) => {
        if (!cancelled) setProfile({ userId, role: data?.role ?? null, error: error?.message ?? null })
      })
    return () => { cancelled = true }
  }, [userId, refreshKey])

  // Create a brand new account permanently bound to the chosen role
  async function signUp(role, fullName, email, password) {
    const { data, error } = await supabase.auth.signUp({
      email,
      password,
      options: { data: { role, full_name: fullName } },
    })
    if (error) return { error }
    if (!data.session) return { needsConfirmation: true }

    // Register with PostgreSQL domain tables
    if (role === 'customer' || role === 'rider') {
      try {
        await supabase.rpc('register_account', { p_role: role, p_full_name: fullName })
      } catch (rpcErr) {
        console.warn('register_account notice:', rpcErr)
      }
    }

    setProfile({ userId: data.session.user.id, role, error: null })
    setRefreshKey((key) => key + 1)
    return {}
  }

  // Signs in and strictly validates that the account's registered role matches the portal role
  async function signIn(email, password, expectedRole = null) {
    const result = await supabase.auth.signInWithPassword({ email, password })
    if (result.error) return result

    const user = result.data.user
    // Determine the user's permanent role from database or metadata
    let userRole = null
    const { data: prof } = await supabase
      .from('profiles')
      .select('role')
      .eq('user_id', user.id)
      .maybeSingle()

    if (prof?.role) {
      userRole = prof.role
    } else if (user.user_metadata?.role) {
      userRole = user.user_metadata.role
    } else if (expectedRole) {
      // First-time role assignment for an unassigned account
      userRole = expectedRole
      await supabase.auth.updateUser({ data: { role: expectedRole } })
      if (expectedRole === 'customer' || expectedRole === 'rider') {
        const name = user.user_metadata?.full_name || email.split('@')[0]
        await supabase.rpc('register_account', { p_role: expectedRole, p_full_name: name }).catch(() => {})
      }
    }

    // Role Enforcement: If signing into a specific portal, verify account role matches
    if (expectedRole && userRole && userRole !== expectedRole) {
      await supabase.auth.signOut()
      return {
        error: {
          message: `Account role mismatch: "${email}" is registered as a ${userRole.toUpperCase()}. It cannot be used to access the ${expectedRole.toUpperCase()} portal. Please sign in to the ${userRole} workspace or use a dedicated ${expectedRole} account.`,
        },
      }
    }

    setProfile({ userId: user.id, role: userRole, error: null })
    setRefreshKey((key) => key + 1)
    return result
  }

  // Active role: database profile takes precedence, with user_metadata as fallback
  const activeRole = profile.role || session?.user?.user_metadata?.role || null

  const value = {
    session,
    role: userId ? activeRole : null,
    roleError: userId ? profile.error : null,
    loading: sessionLoading || (Boolean(userId) && profile.userId !== userId && !activeRole),
    signIn,
    signUp,
    signOut: () => supabase.auth.signOut(),
  }

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export const useAuth = () => useContext(AuthContext)
