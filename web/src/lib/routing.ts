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
      }
    })
    .sort((a, b) => a.score - b.score)
}

type Trip = { path: LatLng[]; meters: number; seconds: number }

type ValhallaTrip = {
  summary: { length: number; time: number }
  legs: { shape: string }[]
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
  return [json.trip, ...(json.alternates ?? []).map((a) => a.trip)].map((trip) => ({
    path: trip.legs.flatMap((leg) => decodePolyline6(leg.shape)),
    meters: trip.summary.length * 1000,
    seconds: trip.summary.time,
  }))
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
