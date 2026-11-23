import { useState } from 'react'
import { config } from '../lib/config'
import { isCampusEmail, sendSignInLink } from '../lib/supabase'
import { Envelope, Walk } from './Icons'

/** F1: sign in with a verified campus email via an emailed link. */
export function SignIn({ linkError }: { linkError: string | null }) {
  const [email, setEmail] = useState('')
  const [sent, setSent] = useState(false)
  const [working, setWorking] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function send() {
    setError(null)
    if (!isCampusEmail(email)) {
      setError(`Use your @${config.campusEmailDomain} email.`)
      return
    }
    setWorking(true)
    try {
      await sendSignInLink(email)
      setSent(true)
    } catch (e) {
      setError((e as Error).message)
    } finally {
      setWorking(false)
    }
  }

  const message = error ?? linkError
  return (
    <div className="signin">
      <div className="signin-bg" />
      <div>
        {sent ? <Envelope className="hero" /> : <Walk className="hero" />}
        <h1>{sent ? 'Check your email' : 'Let Me Know'}</h1>
        <p className="sub">
          {sent ? `Tap the sign-in link we sent to ${email.trim()}. It opens this page signed in.` : 'Sign in with your campus email.'}
        </p>
      </div>
      {!sent && (
        <input
          className="glass"
          type="email"
          inputMode="email"
          autoCapitalize="none"
          autoCorrect="off"
          placeholder="you@berkeley.edu"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          onKeyDown={(e) => e.key === 'Enter' && send()}
        />
      )}
      {message && <div className="error">{message}</div>}
      <button className="btn-prominent" disabled={working || !email} onClick={send}>
        {working ? 'Sending…' : sent ? 'Resend Link' : 'Email Me a Sign-In Link'}
      </button>
      {sent && (
        <button className="link" onClick={() => setSent(false)}>
          Use a different email
        </button>
      )}
    </div>
  )
}
