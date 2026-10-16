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

  // Create the account, then let the database create the profile and customer/rider row for it.
  async function signUp(role, fullName, email, password) {
    const { data, error } = await supabase.auth.signUp({ email, password })
    if (error) return { error }
    // No session means the project requires email confirmation first.
    if (!data.session) return { needsConfirmation: true }
    const { error: registerError } = await supabase.rpc('register_account', { p_role: role, p_full_name: fullName })
    if (registerError) return { error: registerError }
    setProfile({ userId: null, role: null, error: null })
    setRefreshKey((key) => key + 1) // re-read the role now that the profile exists
    return {}
  }

  const value = {
    session,
    role: userId ? profile.role : null,
    roleError: userId ? profile.error : null,
    loading: sessionLoading || (Boolean(userId) && profile.userId !== userId),
    signIn: (email, password) => supabase.auth.signInWithPassword({ email, password }),
    signUp,
    signOut: () => supabase.auth.signOut(),
  }

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export const useAuth = () => useContext(AuthContext)
