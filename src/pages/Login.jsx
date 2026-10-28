import { useEffect, useRef, useState } from 'react'
import { Link, Navigate, useParams } from 'react-router-dom'
import { useAuth } from '../AuthContext'
import { roles } from '../roles'
import '../styles/login.css'

export default function Login() {
  const { role: chosenRole } = useParams()
  const { session, role, roleError, loading, signIn, signUp, completeProfile, signOut } = useAuth()
  const [signingUp, setSigningUp] = useState(false)
  const [fullName, setFullName] = useState('')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState(null)
  const [message, setMessage] = useState(null)
  const [submitting, setSubmitting] = useState(false)
  const [setupError, setSetupError] = useState(null)
  const setupTried = useRef(null) // user id we already tried to set up, so it runs only once

  // Managers are added by hand, so only customers and riders can register themselves.
  const canSignUp = chosenRole === 'customer' || chosenRole === 'rider'

  // Signed in but no role row yet (for example they confirmed their email before first sign-in):
  // create it now, using the role chosen at sign-up, or the page they signed in on.
  useEffect(() => {
    if (loading || !session || role || roleError || !canSignUp || setupTried.current === session.user.id) return
    setupTried.current = session.user.id
    const signedUpAs = session.user.user_metadata.role
    completeProfile(signedUpAs === 'customer' || signedUpAs === 'rider' ? signedUpAs : chosenRole)
      .then(({ error: registerError }) => registerError && setSetupError(registerError.message))
  }, [loading, session, role, roleError, canSignUp, chosenRole, completeProfile])

  if (!roles[chosenRole]) return <Navigate to="/" replace />
  if (loading) return <p className="notice">Loading…</p>
  // The dashboard comes from the role stored in the database, not from the card that was clicked.
  if (session && role) return <Navigate to={`/dashboard/${role}`} replace />

  async function handleSubmit(event) {
    event.preventDefault()
    setSubmitting(true)
    setError(null)
    setMessage(null)
    const result = signingUp
      ? await signUp(chosenRole, fullName, email, password)
      : await signIn(email, password)
    if (result.error) setError(result.error.message)
    if (result.needsConfirmation) {
      setMessage('Account created. Check your email to confirm it, then sign in.')
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
      <div className="card login-card">
        <h1>{roles[chosenRole].title} {signingUp ? 'sign up' : 'sign in'}</h1>

        {session && canSignUp && !roleError && !setupError ? (
          <p role="status">Setting up your account…</p>
        ) : session ? (
          <>
            <p className="form-error" role="alert">
              {roleError ?? setupError ?? 'Your account has no role assigned yet. Ask the store manager to set it up.'}
            </p>
            <button type="button" className="btn" onClick={signOut}>Sign out</button>
          </>
        ) : (
          <form onSubmit={handleSubmit}>
            {signingUp && (
              <>
                <label htmlFor="fullName">Full name</label>
                <input id="fullName" type="text" autoComplete="name" required value={fullName}
                  onChange={(e) => setFullName(e.target.value)} />
              </>
            )}

            <label htmlFor="email">Email</label>
            <input id="email" type="email" autoComplete="email" required value={email}
              onChange={(e) => setEmail(e.target.value)} />

            <label htmlFor="password">Password</label>
            <input id="password" type="password" required minLength={signingUp ? 8 : undefined}
              autoComplete={signingUp ? 'new-password' : 'current-password'} value={password}
              onChange={(e) => setPassword(e.target.value)} />

            {message && <p className="form-success" role="status">{message}</p>}
            {error && <p className="form-error" role="alert">{error}</p>}

            <button type="submit" className="btn" disabled={submitting}>
              {submitting ? 'Please wait…' : signingUp ? 'Create account' : 'Sign in'}
            </button>
          </form>
        )}

        {!session && canSignUp && (
          <button type="button" className="link-button" onClick={toggleMode}>
            {signingUp ? 'Already have an account? Sign in' : 'First time here? Create an account'}
          </button>
        )}
        <Link to="/">Back to home</Link>
      </div>
    </main>
  )
}
