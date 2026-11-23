import type { Session } from '@supabase/supabase-js'
import { APIProvider } from '@vis.gl/react-google-maps'
import { useEffect, useState } from 'react'
import { MapScreen } from './components/MapScreen'
import { SignIn } from './components/SignIn'
import { config } from './lib/config'
import { supabase } from './lib/supabase'

export function App() {
  const [session, setSession] = useState<Session | null | undefined>(undefined)
  const [linkError, setLinkError] = useState<string | null>(null)

  useEffect(() => {
    // An expired or reused sign-in link comes back with an error in the URL.
    const params = new URLSearchParams(window.location.search + window.location.hash.replace('#', '&'))
    const error = params.get('error_description')
    if (error) setLinkError(`That sign-in link didn't work (${error}). Send a new one.`)

    supabase.auth.getSession().then(({ data }) => setSession(data.session))
    const { data } = supabase.auth.onAuthStateChange((_event, next) => {
      setSession(next)
      // Drop ?code=… from the address bar once the link has been used.
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
