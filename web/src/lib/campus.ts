import { createContext, useContext, useEffect, useState } from 'react'
import { supabase } from './supabase'

export type CampusResource = { label: string; detail: string; phone: string | null; url: string | null; source_url: string | null }
export type CampusSection = { title: string; footer: string | null; items: CampusResource[] }

/**
 * A school using Let Me Know, from the `campuses` table (006_campuses.sql). Set up automatically
 * the first time one of its students signs in.
 */
export type Campus = {
  domain: string
  name: string | null
  short_name: string | null
  lat: number | null
  lng: number | null
  police_name: string | null
  police_phone: string | null
  resources: CampusSection[]
  status: 'pending' | 'generating' | 'ready' | 'failed'
}

/** jane@g.ucla.edu → ucla.edu (same rule as public.campus_of). */
export function campusDomain(email: string | undefined | null) {
  return email?.trim().toLowerCase().match(/([a-z0-9-]+\.edu)$/)?.[1] ?? null
}

/**
 * The signed-in student's campus. A campus seen for the first time is looked up by the
 * campus-info Edge Function (about a minute); this asks for it once and checks back every few seconds.
 */
export function useCampusLoader(email: string | undefined) {
  const [campus, setCampus] = useState<Campus | null>(null)

  useEffect(() => {
    const domain = campusDomain(email)
    if (!domain) return
    let stopped = false
    let askedForLookup = false
    let timer: ReturnType<typeof setTimeout> | undefined
    let tries = 0

    async function check() {
      const { data } = await supabase.from('campuses').select().eq('domain', domain).maybeSingle()
      if (stopped) return
      const row = data as Campus | null
      setCampus(row)
      if (row?.status === 'ready' || (row?.status === 'failed' && askedForLookup) || ++tries > 60) return
      if (!askedForLookup && row?.status !== 'generating') {
        askedForLookup = true
        await supabase.functions.invoke('campus-info')
        if (!stopped) check()
        return
      }
      timer = setTimeout(check, 5000)
    }
    check()
    return () => {
      stopped = true
      clearTimeout(timer)
    }
  }, [email])

  return campus
}

export const CampusContext = createContext<Campus | null>(null)
export const useCampus = () => useContext(CampusContext)
