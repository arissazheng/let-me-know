import { useState } from 'react'
import { config } from '../lib/config'
import { signInWithGoogle } from '../lib/supabase'
import { Walk } from './Icons'

/** F1: sign in with a UC Berkeley Google account. */
export function SignIn({ linkError }: { linkError: string | null }) {
  const [stay, setStay] = useState(true)
  const [working, setWorking] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function signIn() {
    setError(null)
    setWorking(true)
    try {
      await signInWithGoogle(stay) // Leaves the page for Google on success.
    } catch (e) {
      setError((e as Error).message)
      setWorking(false)
    }
  }

  const message = error ?? linkError
  return (
    <div className="signin">
      <div className="signin-bg" />
      <div>
        <Walk className="hero" />
        <h1>Let Me Know</h1>
        <p className="sub">Sign in with your @{config.campusEmailDomain} Google account.</p>
      </div>
      {message && <div className="error">{message}</div>}
      <button className="btn-prominent" disabled={working} onClick={signIn}>
        {working ? 'Opening Google…' : 'Continue with Google'}
      </button>
      <label className="checkbox">
        <input type="checkbox" checked={stay} onChange={(e) => setStay(e.target.checked)} />
        Stay logged in
      </label>
    </div>
  )
}
