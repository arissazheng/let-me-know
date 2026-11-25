import { useCallback, useEffect, useRef, useState } from 'react'
import { distance, type LatLng } from './geo'
import { supabase } from './supabase'

export type MediaItem = { url: string; type: 'image' | 'video' }

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
  /** v2: optional title, any number of photos/videos, and the street it's on. */
  title?: string | null
  media?: MediaItem[] | null
  place_name?: string | null
}

/** All attachments, including a v1 report's single media_url. */
export function reportMedia(report: Report): MediaItem[] {
  if (report.media?.length) return report.media
  return report.media_url ? [{ url: report.media_url, type: report.media_type ?? 'image' }] : []
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

/** F4: uploads any photos/videos, looks up the street, then files the report. */
export async function submitReport(report: { title: string; description: string; at: LatLng; files: File[] }) {
  const bucket = supabase.storage.from('report-media')
  const media: MediaItem[] = []
  for (const file of report.files) {
    const isVideo = file.type.startsWith('video')
    const ext = file.name.split('.').pop() || (isVideo ? 'mov' : 'jpg')
    const path = `${crypto.randomUUID()}.${ext}`
    const { error } = await bucket.upload(path, file, { contentType: file.type })
    if (error) throw error
    media.push({ url: bucket.getPublicUrl(path).data.publicUrl, type: isVideo ? 'video' : 'image' })
  }
  const { error } = await supabase.from('reports').insert({
    lat: report.at.lat,
    lng: report.at.lng,
    title: report.title || null,
    description: report.description,
    media,
    // v1 apps read the first attachment from these columns.
    media_url: media[0]?.url ?? null,
    media_type: media[0]?.type ?? null,
    place_name: await streetName(report.at),
  })
  if (error) throw error
}

/** The street at a point, from OpenStreetMap (Nominatim); null if the lookup fails. */
async function streetName(at: LatLng): Promise<string | null> {
  try {
    const url = `https://nominatim.openstreetmap.org/reverse?format=jsonv2&zoom=17&lat=${at.lat}&lon=${at.lng}`
    const json = (await (await fetch(url)).json()) as { address?: { road?: string; pedestrian?: string; footway?: string } }
    return json.address?.road ?? json.address?.pedestrian ?? json.address?.footway ?? null
  } catch {
    return null
  }
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
  /** Direction of travel in degrees, from the device or from recent movement. */
  const [heading, setHeading] = useState<number | null>(null)
  const latest = useRef<LatLng | null>(null)

  useEffect(() => {
    if (!navigator.geolocation) return
    const id = navigator.geolocation.watchPosition(
      (pos) => {
        const here = { lat: pos.coords.latitude, lng: pos.coords.longitude }
        const previous = latest.current
        if (pos.coords.heading != null && !Number.isNaN(pos.coords.heading)) setHeading(pos.coords.heading)
        else if (previous && distance(previous, here) > 3) setHeading(bearing(previous, here))
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

  return { location, heading }
}

/** Initial compass bearing from `a` to `b`, in degrees. */
function bearing(a: LatLng, b: LatLng) {
  const toRad = (d: number) => (d * Math.PI) / 180
  const y = Math.sin(toRad(b.lng - a.lng)) * Math.cos(toRad(b.lat))
  const x = Math.cos(toRad(a.lat)) * Math.sin(toRad(b.lat)) - Math.sin(toRad(a.lat)) * Math.cos(toRad(b.lat)) * Math.cos(toRad(b.lng - a.lng))
  return ((Math.atan2(y, x) * 180) / Math.PI + 360) % 360
}
