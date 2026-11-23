import { createClient } from '@supabase/supabase-js'
import { config } from './config'

export const supabase = createClient(config.supabaseUrl, config.supabaseAnonKey, {
  auth: { flowType: 'pkce', detectSessionInUrl: true, persistSession: true },
})

export function isCampusEmail(email: string) {
  return email.trim().toLowerCase().endsWith('@' + config.campusEmailDomain)
}

/** F1: emails a sign-in link that returns to this site. */
export async function sendSignInLink(email: string) {
  const { error } = await supabase.auth.signInWithOtp({
    email: email.trim().toLowerCase(),
    options: { emailRedirectTo: window.location.origin + window.location.pathname },
  })
  if (error) throw error
}
