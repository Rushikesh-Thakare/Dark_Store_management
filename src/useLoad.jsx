import { useCallback, useEffect, useState } from 'react'

// Runs `fetcher` (must be a stable, module-level function) and tracks loading / error / ready.
// Calling the returned reload() after data is shown refreshes quietly, without a loading flash.
export function useLoad(fetcher) {
  const [state, setState] = useState({ status: 'loading' })

  const load = useCallback(() => {
    setState((current) => (current.status === 'ready' ? current : { status: 'loading' }))
    fetcher()
      .then((data) => setState({ status: 'ready', data }))
      .catch((error) => setState({ status: 'error', message: error.message }))
  }, [fetcher])

  useEffect(load, [load])
  return [state, load]
}

// Shows the loading and error states; renders children only when the data is ready.
export function LoadGate({ state, reload, children }) {
  if (state.status === 'loading') return <p className="notice">Loading…</p>
  if (state.status === 'error') {
    return (
      <div className="card">
        <p className="form-error" role="alert">Could not load this page: {state.message}</p>
        <button type="button" className="btn" onClick={reload}>Try again</button>
      </div>
    )
  }
  return children
}
