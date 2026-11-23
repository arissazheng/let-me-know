import { HeatmapLayer } from '@deck.gl/aggregation-layers'
import { GoogleMapsOverlay } from '@deck.gl/google-maps'
import { Marker, Polyline, useMap } from '@vis.gl/react-google-maps'
import { useEffect, useMemo, useRef, useState } from 'react'
import { colors } from '../lib/config'
import type { PopulationCell, Report } from '../lib/data'
import type { LatLng } from '../lib/geo'
import type { SafeRoute } from '../lib/routing'
import { streetlights, type Streetlight } from '../lib/streetlights'

/** Opacity rises with density: sparse areas stay see-through, only dense clusters are fully saturated. */
function glowRange([r, g, b]: readonly [number, number, number], alphas = [20, 60, 105, 150, 200, 245]) {
  return alphas.map((a) => [r, g, b, a] as [number, number, number, number])
}

/** Yellow streetlight glow and blue student-population glow, drawn with deck.gl over the Google map. */
export function GlowLayers({
  cells,
  showLights,
  showPopulation,
}: {
  cells: PopulationCell[]
  showLights: boolean
  showPopulation: boolean
}) {
  const map = useMap()
  const overlay = useRef<GoogleMapsOverlay | null>(null)

  const [ready, setReady] = useState(false)

  useEffect(() => {
    if (!map) return
    const instance = new GoogleMapsOverlay({ interleaved: false })
    let attached = false
    // Google Maps adds overlays asynchronously, so an overlay detached right after attaching
    // (React StrictMode's mount → unmount → mount) still gets onAdd with no map and throws.
    // Deferring by a tick means that throwaway first mount never touches the map. We also wait
    // for the rendering type, or deck.gl leaves its own 'renderingtype_changed' listener behind.
    const attach = () => {
      attached = true
      instance.setMap(map)
      overlay.current = instance
      setReady(true)
    }
    let listener: google.maps.MapsEventListener | null = null
    const timer = setTimeout(() => {
      if (map.getRenderingType() === google.maps.RenderingType.UNINITIALIZED) {
        listener = map.addListener('renderingtype_changed', () => {
          listener?.remove()
          listener = null
          attach()
        })
      } else {
        attach()
      }
    }, 0)
    return () => {
      clearTimeout(timer)
      listener?.remove()
      if (attached) instance.setMap(null)
      instance.finalize()
      overlay.current = null
      setReady(false)
    }
  }, [map])

  const layers = useMemo(
    () => [
      new HeatmapLayer<Streetlight>({
        id: 'streetlights',
        data: streetlights,
        visible: showLights,
        getPosition: (d) => d.position,
        getWeight: (d) => Math.max(d.wattage, 20) / 50,
        radiusPixels: 45,
        threshold: 0.02,
        // Lamps are spread evenly, so start the yellow ramp higher than the student glow's.
        colorRange: glowRange(colors.lightYellow, [50, 95, 140, 180, 215, 245]),
      }),
      new HeatmapLayer<PopulationCell>({
        id: 'population',
        data: cells,
        visible: showPopulation,
        getPosition: (d) => [d.lng, d.lat],
        getWeight: (d) => d.weight,
        radiusPixels: 50,
        threshold: 0.02,
        colorRange: glowRange(colors.populationBlue),
      }),
    ],
    [cells, showLights, showPopulation],
  )

  useEffect(() => {
    overlay.current?.setProps({ layers })
  }, [layers, ready])

  return null
}

/** F3: a red pin per live report. */
export function ReportPins({ reports, onSelect }: { reports: Report[]; onSelect: (r: Report) => void }) {
  return (
    <>
      {reports.map((r) => (
        <Marker key={r.id} position={{ lat: r.lat, lng: r.lng }} onClick={() => onSelect(r)} zIndex={2} />
      ))}
    </>
  )
}

const destinationIcon =
  'data:image/svg+xml;utf8,' +
  encodeURIComponent(
    '<svg xmlns="http://www.w3.org/2000/svg" width="30" height="40" viewBox="0 0 36 48"><path d="M18 0C8 0 0 7.8 0 17.5 0 30.6 18 48 18 48s18-17.4 18-30.5C36 7.8 28 0 18 0Z" fill="#34c759"/><circle cx="18" cy="17" r="6.5" fill="#fff"/></svg>',
  )

/** F6: the selected route in green over gray alternates, plus the destination pin. */
export function RouteLines({
  routes,
  selectedId,
  destination,
  onSelect,
}: {
  routes: SafeRoute[]
  selectedId: string | null
  destination: LatLng | null
  onSelect: (id: string) => void
}) {
  const map = useMap()
  const firstId = routes[0]?.id

  // Fit the camera to a newly planned route.
  useEffect(() => {
    if (!map || !routes[0]) return
    const bounds = new google.maps.LatLngBounds()
    routes[0].path.forEach((p) => bounds.extend(p))
    map.fitBounds(bounds, { top: 90, bottom: 400, left: 40, right: 40 })
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [map, firstId])

  return (
    <>
      {routes.map((route) => {
        const selected = route.id === selectedId
        return (
          <Polyline
            key={route.id}
            path={route.path}
            strokeColor={selected ? colors.safeGreen : '#8e8e93'}
            strokeOpacity={selected ? 1 : 0.75}
            strokeWeight={selected ? 7 : 5}
            zIndex={selected ? 3 : 1}
            onClick={() => onSelect(route.id)}
          />
        )
      })}
      {destination && <Marker position={destination} icon={destinationIcon} zIndex={4} />}
    </>
  )
}

/** The blue "you are here" dot. */
export function UserDot({ location }: { location: LatLng | null }) {
  if (!location) return null
  return (
    <Marker
      position={location}
      zIndex={5}
      icon={{
        path: google.maps.SymbolPath.CIRCLE,
        scale: 8,
        fillColor: '#0a84ff',
        fillOpacity: 1,
        strokeColor: '#fff',
        strokeWeight: 3,
      }}
    />
  )
}

/** Pans the map when `token` changes. */
export function FocusOn({ target, token }: { target: LatLng | null; token: number }) {
  const map = useMap()
  useEffect(() => {
    if (map && target && token > 0) map.panTo(target)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [map, token])
  return null
}
