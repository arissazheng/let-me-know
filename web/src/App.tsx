import type { Session } from '@supabase/supabase-js'
import { APIProvider } from '@vis.gl/react-google-maps'
import { useEffect, useState } from 'react'
import { MapScreen } from './components/MapScreen'
import { SignIn } from './components/SignIn'
import { config } from './lib/config'
import { isCampusEmail, supabase } from './lib/supabase'

export function App() {
  const [session, setSession] = useState<Session | null | undefined>(undefined)
  const [linkError, setLinkError] = useState<string | null>(null)

  useEffect(() => {
    // A refused Google sign-in (e.g. not a berkeley.edu account) comes back with an error in the URL.
    const params = new URLSearchParams(window.location.search + window.location.hash.replace('#', '&'))
    const error = params.get('error_description')
    if (error)
      setLinkError(
        error.includes('berkeley.edu') || error.includes('saving new user')
          ? `Use your @${config.campusEmailDomain} Google account.`
          : `Couldn't sign in (${error}). Try again.`,
      )

    supabase.auth.getSession().then(({ data }) =>
      setSession(data.session?.user.email && isCampusEmail(data.session.user.email) ? data.session : null),
    )
    const { data } = supabase.auth.onAuthStateChange((_event, next) => {
      // Only berkeley.edu accounts (the database also refuses others).
      if (next?.user.email && !isCampusEmail(next.user.email)) {
        setLinkError(`Use your @${config.campusEmailDomain} Google account.`)
        supabase.auth.signOut()
        return
      }
      setSession(next)
      // Drop ?code=… from the address bar once Google has sent the student back.
      if (next && window.location.search.includes('code=')) window.history.replaceState(null, '', window.location.pathname)
    })
    return () => data.subscription.unsubscribe()
  }, [])

  if (session === undefined) return null
  if (!session) return <SignIn linkError={linkError} />
  return (
    <APIProvider apiKey={config.googleMapsApiKey} libraries={['places']}>
      <MapScreen email={session.user.email} />
    </APIProvider>
  )
}
