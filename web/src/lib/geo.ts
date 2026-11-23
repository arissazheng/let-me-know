export type LatLng = { lat: number; lng: number }

/** Great-circle distance in meters. */
export function distance(a: LatLng, b: LatLng): number {
  const R = 6371000
  const toRad = (d: number) => (d * Math.PI) / 180
  const dLat = toRad(b.lat - a.lat)
  const dLng = toRad(b.lng - a.lng)
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(toRad(a.lat)) * Math.cos(toRad(b.lat)) * Math.sin(dLng / 2) ** 2
  return 2 * R * Math.asin(Math.sqrt(h))
}

/** Adds points so consecutive samples are at most `step` meters apart. */
export function densify(path: LatLng[], step = 20): LatLng[] {
  if (path.length === 0) return []
  const result = [path[0]]
  for (let i = 1; i < path.length; i++) {
    const prev = path[i - 1]
    const next = path[i]
    const pieces = Math.max(Math.floor(distance(prev, next) / step), 1)
    for (let p = 1; p <= pieces; p++) {
      const t = p / pieces
      result.push({ lat: prev.lat + (next.lat - prev.lat) * t, lng: prev.lng + (next.lng - prev.lng) * t })
    }
  }
  return result
}

/** ~55 m grid cells for fast nearby lookups. */
const GRID = 0.0005
export function gridKey(p: LatLng, dx = 0, dy = 0) {
  return `${Math.floor(p.lng / GRID) + dx}:${Math.floor(p.lat / GRID) + dy}`
}
export function neighborKeys(p: LatLng) {
  const keys: string[] = []
  for (let dx = -1; dx <= 1; dx++) for (let dy = -1; dy <= 1; dy++) keys.push(gridKey(p, dx, dy))
  return keys
}

/** Decodes Valhalla's precision-6 encoded polyline. */
export function decodePolyline6(encoded: string): LatLng[] {
  const coords: LatLng[] = []
  let index = 0
  let lat = 0
  let lng = 0
  const next = () => {
    let result = 0
    let shift = 0
    let byte: number
    do {
      byte = encoded.charCodeAt(index++) - 63
      result |= (byte & 0x1f) << shift
      shift += 5
    } while (byte >= 0x20 && index < encoded.length)
    return result & 1 ? ~(result >> 1) : result >> 1
  }
  while (index < encoded.length) {
    lat += next()
    lng += next()
    coords.push({ lat: lat / 1e6, lng: lng / 1e6 })
  }
  return coords
}
