import type { SafeRoute } from '../lib/routing'
import { Bulb, Close, People, Warning } from './Icons'

function crowdLabel(level: number) {
  if (level < 0.15) return 'Quiet'
  if (level < 0.45) return 'Some people'
  return 'Busy'
}

function formatDistance(meters: number) {
  const miles = meters / 1609.34
  return miles < 0.1 ? `${Math.round(meters * 3.281)} ft` : `${miles.toFixed(1)} mi`
}

/** F6: the suggested routes and what makes each one safer. */
export function RouteCard({
  destinationName,
  routes,
  selectedId,
  onSelect,
  onClose,
}: {
  destinationName: string
  routes: SafeRoute[]
  selectedId: string | null
  onSelect: (id: string) => void
  onClose: () => void
}) {
  return (
    <div className="route-card glass">
      <div className="route-head">
        <div style={{ flex: 1, minWidth: 0 }}>
          <div className="caption">Safer route to</div>
          <div className="name">{destinationName}</div>
        </div>
        <button className="circle glass glass-interactive" style={{ width: 44, height: 44 }} onClick={onClose} aria-label="End">
          <Close className="icon" />
        </button>
      </div>
      {routes.map((route, i) => (
        <button key={route.id} className={`route-row${route.id === selectedId ? ' selected' : ''}`} onClick={() => onSelect(route.id)}>
          <div className="line1">
            <span className="mins">{Math.round(route.seconds / 60)} min</span>
            <span className="dist">{formatDistance(route.meters)}</span>
            {i === 0 && <span className="best">Safest</span>}
          </div>
          <div className="chips">
            <span className="chip" style={{ background: route.nearbyReports ? 'rgba(255,59,48,0.2)' : 'rgba(52,199,89,0.2)' }}>
              <Warning />
              {route.nearbyReports === 0
                ? 'No reports nearby'
                : `${route.nearbyReports} report${route.nearbyReports === 1 ? '' : 's'} nearby`}
            </span>
            <span className="chip" style={{ background: 'rgba(255,204,0,0.3)' }}>
              <Bulb />
              {Math.round(route.litFraction * 100)}% lit
            </span>
            <span className="chip" style={{ background: 'rgba(10,132,255,0.2)' }}>
              <People />
              {crowdLabel(route.crowdLevel)}
            </span>
          </div>
        </button>
      ))}
    </div>
  )
}
