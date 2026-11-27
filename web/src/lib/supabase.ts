import { createClient } from '@supabase/supabase-js'
import { campusDomain } from './campus'
import { config } from './config'

/** Whether to keep the session after the browser closes ("Stay logged in" on the sign-in page). */
const STAY_SIGNED_IN = 'lmk.staySignedIn'

function staySignedIn() {
  try {
    return localStorage.getItem(STAY_SIGNED_IN) !== 'false'
  } catch {
    return true
  }
}

/**
 * Keeps the sign-in in localStorage (survives closing the browser) or sessionStorage (ends with the
 * tab), depending on "Stay logged in".
 */
const authStorage = {
  getItem(key: string) {
    try {
      return localStorage.getItem(key) ?? sessionStorage.getItem(key)
    } catch {
      return null
    }
  },
  setItem(key: string, value: string) {
    try {
      ;(staySignedIn() ? localStorage : sessionStorage).setItem(key, value)
      ;(staySignedIn() ? sessionStorage : localStorage).removeItem(key)
    } catch {
      // Storage blocked: the session lasts only while the page is open.
    }
  },
  removeItem(key: string) {
    try {
      localStorage.removeItem(key)
      sessionStorage.removeItem(key)
    } catch {
      // Nothing stored.
    }
  },
}

export const supabase = createClient(config.supabaseUrl, config.supabaseAnonKey, {
  auth: { flowType: 'pkce', detectSessionInUrl: true, persistSession: true, storage: authStorage },
})

/** Any school (.edu) account; the database refuses others too. */
export function isCampusEmail(email: string) {
  return campusDomain(email) !== null
}

/** F1: sends the student to Google to pick their school account, and back to this site. */
export async function signInWithGoogle(stay: boolean) {
  try {
    localStorage.setItem(STAY_SIGNED_IN, String(stay))
  } catch {
    // Storage blocked: keep the default.
  }
  const { error } = await supabase.auth.signInWithOAuth({
    provider: 'google',
    options: {
      redirectTo: window.location.origin + window.location.pathname,
      queryParams: { prompt: 'select_account' },
    },
  })
  if (error) throw error
}
