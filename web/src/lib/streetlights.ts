import rows from '../data/streetlights.json'
import { distance, gridKey, neighborKeys, type LatLng } from './geo'

/** City of Berkeley streetlights (dataset dz4s-un9u), bundled as [[lat, lng, wattage], …]. */
export type Streetlight = { position: [number, number]; wattage: number }

export const streetlights: Streetlight[] = (rows as number[][]).map(([lat, lng, w]) => ({
  position: [lng, lat],
  wattage: w,
}))

const grid = new Map<string, LatLng[]>()
for (const [lat, lng] of rows as number[][]) {
  const key = gridKey({ lat, lng })
  const cell = grid.get(key) ?? []
  cell.push({ lat, lng })
  grid.set(key, cell)
}

/** Whether any streetlight lies within `radius` meters of `point`. */
export function isLit(point: LatLng, radius = 35) {
  return neighborKeys(point).some((key) => grid.get(key)?.some((light) => distance(point, light) <= radius))
}
