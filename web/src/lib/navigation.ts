import { useCallback, useRef, useState } from 'react'
import { distance, type LatLng } from './geo'
import type { Maneuver, SafeRoute } from './routing'

export type NavigationState = {
  route: SafeRoute
  /** The upcoming step (or the arrival step near the end). */
  nextManeuver: Maneuver | null
  metersToManeuver: number
  remainingMeters: number
  remainingSeconds: number
  hasArrived: boolean
}

/**
 * Turn-by-turn guidance along a SafeRoute: progress, the next turn, spoken
 * instructions, arrival, and detecting when the student has walked off the route.
 */
export function useNavigator() {
  const [state, setState] = useState<NavigationState | null>(null)
  const [muted, setMuted] = useState(false)
  const internal = useRef({ cumulative: [] as number[], progressIndex: 0, offRouteFixes: 0, spoken: -1, muted: false })
  internal.current.muted = muted

  const speak = useCallback((text: string) => {
    if (internal.current.muted || !('speechSynthesis' in window)) return
    window.speechSynthesis.speak(new SpeechSynthesisUtterance(text))
  }, [])

  const load = useCallback((route: SafeRoute, keepArrival = false) => {
    const cumulative = [0]
    for (let i = 1; i < route.path.length; i++) cumulative.push(cumulative[i - 1] + distance(route.path[i - 1], route.path[i]))
    Object.assign(internal.current, { cumulative, progressIndex: 0, offRouteFixes: 0, spoken: 0 })
    const next = route.maneuvers[1] ?? route.maneuvers[0] ?? null
    setState((current) => ({
      route,
      nextManeuver: next,
      metersToManeuver: next ? cumulative[next.beginIndex] : 0,
      remainingMeters: cumulative[cumulative.length - 1] ?? route.meters,
      remainingSeconds: route.seconds,
      hasArrived: keepArrival ? (current?.hasArrived ?? false) : false,
    }))
  }, [])

  const start = useCallback(
    (route: SafeRoute) => {
      load(route)
      if (route.maneuvers[0]) speak(route.maneuvers[0].instruction)
    },
    [load, speak],
  )

  /** Swap in a re-planned route without leaving navigation. */
  const replace = useCallback((route: SafeRoute) => load(route, true), [load])

  const stop = useCallback(() => {
    setState(null)
    if ('speechSynthesis' in window) window.speechSynthesis.cancel()
  }, [])

  /**
   * Updates progress for a new location fix. Returns true when the student has been off the
   * route for two fixes in a row and the route should be re-planned.
   */
  const update = useCallback(
    (here: LatLng): boolean => {
      if (!state || state.hasArrived || state.route.path.length < 2) return false
      const { route } = state
      const nav = internal.current
      const { along, offBy, index } = project(here, route.path, nav.cumulative, nav.progressIndex)
      nav.progressIndex = index

      const total = nav.cumulative[nav.cumulative.length - 1] || route.meters
      const remainingMeters = Math.max(total - along, 0)
      const remainingSeconds = total > 0 ? (route.seconds * remainingMeters) / total : 0

      if (remainingMeters < 20) {
        setState({ ...state, hasArrived: true, nextManeuver: route.maneuvers.at(-1) ?? null, metersToManeuver: 0, remainingMeters, remainingSeconds })
        speak('You have arrived.')
        return false
      }

      // The next step is the first one that begins ahead of the student.
      const i = route.maneuvers.findIndex((m) => nav.cumulative[m.beginIndex] > along + 5)
      const next = i >= 0 ? route.maneuvers[i] : state.nextManeuver
      const metersToManeuver = i >= 0 ? nav.cumulative[route.maneuvers[i].beginIndex] - along : 0
      if (i >= 0 && metersToManeuver < 40 && nav.spoken !== i) {
        nav.spoken = i
        speak(route.maneuvers[i].instruction)
      }
      setState({ ...state, nextManeuver: next, metersToManeuver, remainingMeters, remainingSeconds })

      nav.offRouteFixes = offBy > 40 ? nav.offRouteFixes + 1 : 0
      if (nav.offRouteFixes >= 2) {
        nav.offRouteFixes = 0
        return true
      }
      return false
    },
    [state, speak],
  )

  return { state, muted, setMuted, start, replace, stop, update }
}

/**
 * Projects `point` onto the nearest path segment at or after the last known progress.
 * Returns the distance along the path, the distance off it, and the segment index.
 */
function project(point: LatLng, path: LatLng[], cumulative: number[], from: number) {
  const mLat = 111_320
  const mLng = 111_320 * Math.cos((point.lat * Math.PI) / 180)
  let best = { along: 0, offBy: Infinity, index: from }
  for (let i = Math.max(from - 2, 0); i < path.length - 1; i++) {
    const ax = (path[i].lng - point.lng) * mLng
    const ay = (path[i].lat - point.lat) * mLat
    const bx = (path[i + 1].lng - point.lng) * mLng
    const by = (path[i + 1].lat - point.lat) * mLat
    const dx = bx - ax
    const dy = by - ay
    const lengthSquared = dx * dx + dy * dy
    const t = lengthSquared > 0 ? Math.min(Math.max(-(ax * dx + ay * dy) / lengthSquared, 0), 1) : 0
    const offBy = Math.hypot(ax + t * dx, ay + t * dy)
    if (offBy < best.offBy) best = { along: cumulative[i] + t * (cumulative[i + 1] - cumulative[i]), offBy, index: i }
  }
  return best
}
