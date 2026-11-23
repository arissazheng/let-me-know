import { useCallback, useEffect, useRef, useState } from 'react'
import { distance, type LatLng } from './geo'
import { supabase } from './supabase'

/** A student-filed safety report (F3, F4). */
export type Report = {
  id: string
  lat: number
  lng: number
  description: string
  media_url: string | null
  media_type: 'image' | 'video' | null
  created_at: string
  is_demo?: boolean
}

/** Live reports from the last 24 hours (F3), plus realtime inserts (F8). */
export function useReports() {
  const [reports, setReports] = useState<Report[]>([])
  const [latestLive, setLatestLive] = useState<Report | null>(null)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    supabase
      .from('live_reports')
      .select()
      .then(({ data, error }) => {
        if (error) setError(`Couldn't load reports: ${error.message}`)
        else setReports(data as Report[])
      })

    const channel = supabase
      .channel('reports')
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'reports' }, (payload) => {
        const report = payload.new as Report
        setReports((current) => (current.some((r) => r.id === report.id) ? current : [...current, report]))
        setLatestLive(report)
      })
      .subscribe()
    return () => {
      supabase.removeChannel(channel)
    }
  }, [])

  return { reports, latestLive, error }
}

/** F4: uploads optional media, then files the report. */
export async function submitReport(description: string, at: LatLng, file: File | null) {
  let media_url: string | null = null
  let media_type: Report['media_type'] = null
  if (file) {
    const ext = file.name.split('.').pop() || (file.type.startsWith('video') ? 'mov' : 'jpg')
    const path = `${crypto.randomUUID()}.${ext}`
    const bucket = supabase.storage.from('report-media')
    const { error } = await bucket.upload(path, file, { contentType: file.type })
    if (error) throw error
    media_url = bucket.getPublicUrl(path).data.publicUrl
    media_type = file.type.startsWith('video') ? 'video' : 'image'
  }
  const { error } = await supabase.from('reports').insert({ lat: at.lat, lng: at.lng, description, media_url, media_type })
  if (error) throw error
}

export type PopulationCell = { lat: number; lng: number; weight: number }

/** Student population density from preference-based location tracking (blue glow). */
export function usePopulation() {
  const [cells, setCells] = useState<PopulationCell[]>([])

  useEffect(() => {
    const load = () =>
      supabase.rpc('population_cells').then(({ data }) => {
        if (data) setCells(data as PopulationCell[])
      })
    load()
    const timer = setInterval(load, 30_000)
    return () => clearInterval(timer)
  }, [])

  const maxWeight = Math.max(1, ...cells.map((c) => c.weight))
  /** 0 (empty) … 1 (busiest cell on the map), summed over nearby cells. */
  const crowdLevel = useCallback(
    (point: LatLng, radius = 40) => {
      const total = cells.filter((c) => distance(point, c) <= radius).reduce((sum, c) => sum + c.weight, 0)
      return Math.min(total / (maxWeight * 3), 1)
    },
    [cells, maxWeight],
  )

  return { cells, crowdLevel }
}

/**
 * Device location, plus — while sharing is on — an anonymous ping (rounded to ~11 m) whenever the
 * student has moved 25 m, or at least once a minute, so the density map tracks where people are now.
 */
export function useLocation(sharePings: boolean) {
  const [location, setLocation] = useState<LatLng | null>(null)
  const latest = useRef<LatLng | null>(null)

  useEffect(() => {
    if (!navigator.geolocation) return
    const id = navigator.geolocation.watchPosition(
      (pos) => {
        const here = { lat: pos.coords.latitude, lng: pos.coords.longitude }
        latest.current = here
        setLocation(here)
      },
      () => {},
      { enableHighAccuracy: true },
    )
    return () => navigator.geolocation.clearWatch(id)
  }, [])

  useEffect(() => {
    if (!sharePings) return
    let lastSent: { at: LatLng; time: number } | null = null
    const ping = () => {
      const c = latest.current
      if (!c) return
      const moved = !lastSent || distance(lastSent.at, c) >= 25
      const stale = !lastSent || Date.now() - lastSent.time >= 60_000
      if (!moved && !stale) return
      supabase
        .from('location_pings')
        .insert({ lat: Math.round(c.lat * 10_000) / 10_000, lng: Math.round(c.lng * 10_000) / 10_000 })
        .then(({ error }) => {
          if (!error) lastSent = { at: c, time: Date.now() }
        })
    }
    ping()
    const timer = setInterval(ping, 10_000)
    return () => clearInterval(timer)
  }, [sharePings])

  return location
}
