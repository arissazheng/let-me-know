import { useSyncExternalStore } from 'react'
import { supabase } from './supabase'

/** A place the student starred or searched for. Same shape as the iOS app's, so both share it. */
export type SavedPlace = { name: string; lat: number; lng: number }

type AccountData = { favorites: SavedPlace[]; recents: SavedPlace[]; preferences: Record<string, boolean> }

/**
 * Favorites, recent searches, and settings, kept with the student's account (user_data table) so
 * signing back in with the same email, on any browser or the iOS app, brings them back. A copy is
 * cached in this browser.
 */
const CACHE = 'lmk.account'
const EMPTY: AccountData = { favorites: [], recents: [], preferences: {} }
let data: AccountData = readCache()
let userId: string | null = null
let pending: ReturnType<typeof setTimeout> | undefined
const listeners = new Set<() => void>()

function readCache(): AccountData {
  try {
    return { ...EMPTY, ...(JSON.parse(localStorage.getItem(CACHE) ?? '{}') as Partial<AccountData>) }
  } catch {
    return EMPTY
  }
}

function set(next: AccountData) {
  data = next
  try {
    localStorage.setItem(CACHE, JSON.stringify(next))
  } catch {
    // Private windows can block storage; the account copy still saves.
  }
  listeners.forEach((l) => l())
}

/** Changes the account's data and sends it (batched over half a second). */
export function updateAccount(patch: Partial<AccountData>) {
  set({ ...data, ...patch })
  if (!userId) return
  const id = userId
  clearTimeout(pending)
  pending = setTimeout(() => {
    supabase.from('user_data').upsert({ user_id: id, ...data, updated_at: new Date().toISOString() }).then(() => {})
  }, 500)
}

supabase.auth.onAuthStateChange((_event, session) => {
  const id = session?.user.id ?? null
  if (id === userId) return
  userId = id
  // The next student to sign in on this browser starts with nothing of the last one's.
  if (!id) return set(EMPTY)
  // Let the auth client finish signing in before querying with the new session.
  setTimeout(async () => {
    const { data: row, error } = await supabase.from('user_data').select('favorites, recents, preferences').eq('user_id', id).maybeSingle()
    if (error || userId !== id) return // Offline or not set up yet: keep this browser's copy.
    if (row) set({ ...EMPTY, ...(row as AccountData) })
    else updateAccount({}) // First sign-in: start the account from this browser's copy.
  })
})

/** A setting's current value outside React (e.g. in a live-update callback). */
export function getPreference(key: string, initial = false) {
  return data.preferences[key] ?? initial
}

export function useAccount(): AccountData {
  return useSyncExternalStore(
    (listener) => {
      listeners.add(listener)
      return () => listeners.delete(listener)
    },
    () => data,
  )
}
