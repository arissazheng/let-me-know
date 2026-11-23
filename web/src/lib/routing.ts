import { config } from './config'
import type { Report } from './data'
import { decodePolyline6, densify, distance, type LatLng } from './geo'
import { isLit } from './streetlights'

/** Settings-page preferences (F7). */
export type RoutePreferences = {
  avoidIncidents: boolean
  avoidPoorLighting: boolean
  preferBusierStreets: boolean
}

/** A walking route scored for safety (F6). */
export type SafeRoute = {
  id: string
  path: LatLng[]
  meters: number
  seconds: number
  /** Share of the route within ~35 m of a city streetlight. */
  litFraction: number
  /** 0 (empty) … 1 (busy), from population pings. */
  crowdLevel: number
  /** Live reports within 50 m of the route. */
  nearbyReports: number
  score: number
  /** Turn-by-turn steps, in order. */
  maneuvers: Maneuver[]
}

/** One turn-by-turn step from Valhalla. */
export type Maneuver = {
  /** Valhalla maneuver type (e.g. 10 = right, 15 = left, 4–6 = arrive). */
  type: number
  instruction: string
  /** Index into the route path where this step begins. */
  beginIndex: number
}

/** Arrow rotation in degrees for a maneuver type (null = destination pin). */
export function turnAngle(type: number): number | null {
  if (type >= 4 && type <= 6) return null
  if ([9, 20, 23].includes(type)) return 45
  if (type === 10) return 90
  if (type === 11) return 135
  if (type === 12 || type === 13) return 180
  if (type === 14) return -135
  if (type === 15) return -90
  if ([16, 21, 24].includes(type)) return -45
  return 0
}

/** Whether `point` lies within `meters` of `route`. */
export function passesNear(route: SafeRoute, point: LatLng, meters: number) {
  return densify(route.path).some((p) => distance(p, point) <= meters)
}

/**
 * Valhalla pedestrian routing that avoids live incidents and prefers lit streets,
 * then ranks the alternatives by lighting, crowds, and nearby reports.
 */
export async function safeRoutes(
  origin: LatLng,
  destination: LatLng,
  reports: Report[],
  crowdLevel: (p: LatLng) => number,
  prefs: RoutePreferences,
): Promise<SafeRoute[]> {
  // Valhalla can't exclude an area that contains the start or end, so skip those reports.
  const avoidable = prefs.avoidIncidents
    ? reports.filter((r) => distance(r, origin) > 60 && distance(r, destination) > 60)
    : []

  let trips: Trip[]
  try {
    trips = await request(origin, destination, avoidable, prefs.avoidPoorLighting)
  } catch (error) {
    // If avoiding every incident leaves no path, fall back to scoring unrestricted routes.
    if (avoidable.length === 0) throw error
    trips = await request(origin, destination, [], prefs.avoidPoorLighting)
  }

  return trips
    .map((trip) => {
      const samples = densify(trip.path)
      const lit = samples.length ? samples.filter((p) => isLit(p)).length / samples.length : 0
      const crowd = samples.length ? samples.reduce((sum, p) => sum + crowdLevel(p), 0) / samples.length : 0
      const nearby = reports.filter((r) => samples.some((p) => distance(p, r) <= 50)).length

      let score = trip.seconds / 60
      if (prefs.avoidIncidents) score += nearby * 100
      if (prefs.avoidPoorLighting) score += (1 - lit) * 50
      if (prefs.preferBusierStreets) score += (1 - crowd) * 30

      return {
        id: crypto.randomUUID(),
        path: trip.path,
        meters: trip.meters,
        seconds: trip.seconds,
        litFraction: lit,
        crowdLevel: crowd,
        nearbyReports: nearby,
        score,
        maneuvers: trip.maneuvers,
      }
    })
    .sort((a, b) => a.score - b.score)
}

type Trip = { path: LatLng[]; meters: number; seconds: number; maneuvers: Maneuver[] }

type ValhallaTrip = {
  summary: { length: number; time: number }
  legs: { shape: string; maneuvers?: { type: number; instruction: string; begin_shape_index: number }[] }[]
}

async function request(origin: LatLng, destination: LatLng, avoid: Report[], preferLit: boolean): Promise<Trip[]> {
  const response = await fetch(`${config.valhallaUrl}/route`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      locations: [
        { lat: origin.lat, lon: origin.lng },
        { lat: destination.lat, lon: destination.lng },
      ],
      costing: 'pedestrian',
      costing_options: { pedestrian: { use_lit: preferLit ? 1 : 0 } },
      exclude_polygons: avoid.map((r) => square(r, 40)),
      alternates: 2,
      units: 'kilometers',
    }),
  })
  const json = (await response.json()) as { trip?: ValhallaTrip; alternates?: { trip: ValhallaTrip }[]; error?: string }
  if (!json.trip) throw new Error(`No walking route found. ${json.error ?? ''}`.trim())
  return [json.trip, ...(json.alternates ?? []).map((a) => a.trip)].map((trip) => {
    // Two locations → a single leg, so maneuver shape indices index straight into `path`.
    const path = trip.legs.flatMap((leg) => decodePolyline6(leg.shape))
    return {
      path,
      meters: trip.summary.length * 1000,
      seconds: trip.summary.time,
      maneuvers: (trip.legs[0]?.maneuvers ?? []).map((m) => ({
        type: m.type,
        instruction: m.instruction,
        beginIndex: Math.min(m.begin_shape_index, Math.max(path.length - 1, 0)),
      })),
    }
  })
}

/** Closed lon/lat ring, as Valhalla's exclude_polygons expects. */
function square(c: LatLng, halfSide: number): number[][] {
  const dLat = halfSide / 111_320
  const dLng = halfSide / (111_320 * Math.cos((c.lat * Math.PI) / 180))
  return [
    [c.lng - dLng, c.lat - dLat],
    [c.lng + dLng, c.lat - dLat],
    [c.lng + dLng, c.lat + dLat],
    [c.lng - dLng, c.lat + dLat],
    [c.lng - dLng, c.lat - dLat],
  ]
}
