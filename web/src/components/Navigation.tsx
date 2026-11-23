import type { NavigationState } from '../lib/navigation'
import { turnAngle } from '../lib/routing'
import { formatDistance } from './RouteCard'
import { Close, ReportBubble } from './Icons'

/** Top banner during navigation: the next turn and how far away it is. */
export function TurnBanner({ nav }: { nav: NavigationState }) {
  const angle = nav.nextManeuver ? turnAngle(nav.nextManeuver.type) : 0
  return (
    <div className="turn-banner glass">
      <div className="turn-icon">
        {nav.hasArrived || angle === null ? (
          <svg viewBox="0 0 24 24" width="36" height="36" fill="currentColor">
            <path d="M12 2a7 7 0 0 0-7 7c0 5.2 7 13 7 13s7-7.8 7-13a7 7 0 0 0-7-7Zm0 9.5A2.5 2.5 0 1 1 12 6.5a2.5 2.5 0 0 1 0 5Z" />
          </svg>
        ) : (
          <svg viewBox="0 0 24 24" width="36" height="36" fill="none" stroke="currentColor" strokeWidth="2.6" strokeLinecap="round" strokeLinejoin="round" style={{ transform: `rotate(${angle}deg)` }}>
            <path d="M12 20V5M6 11l6-6 6 6" />
          </svg>
        )}
      </div>
      <div style={{ minWidth: 0 }}>
        {nav.hasArrived ? (
          <div className="turn-distance">You've arrived</div>
        ) : (
          <>
            <div className="turn-distance">{formatDistance(nav.metersToManeuver)}</div>
            <div className="turn-text">{nav.nextManeuver?.instruction ?? 'Continue'}</div>
          </>
        )}
      </div>
    </div>
  )
}

/** Bottom bar during navigation: time and distance left, arrival time, report, mute, and end. */
export function NavigationBar({
  nav,
  muted,
  onToggleMute,
  onReport,
  onEnd,
}: {
  nav: NavigationState
  muted: boolean
  onToggleMute: () => void
  onReport: () => void
  onEnd: () => void
}) {
  const arrival = new Date(Date.now() + nav.remainingSeconds * 1000).toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' })
  return (
    <div className="nav-bar glass">
      <button className="circle report-circle" onClick={onReport} aria-label="Report">
        <ReportBubble />
      </button>
      <div className="nav-eta">
        <div className="mins">{Math.max(Math.round(nav.remainingSeconds / 60), 1)} min</div>
        <div className="sub">
          {formatDistance(nav.remainingMeters)} · {arrival}
        </div>
      </div>
      <button className="circle glass glass-interactive" onClick={onToggleMute} aria-label={muted ? 'Unmute' : 'Mute'}>
        <svg viewBox="0 0 24 24" className="icon" fill="currentColor">
          <path d="M4 9v6h4l5 4V5L8 9H4Z" />
          {muted ? (
            <path d="m16 9 5 6m0-6-5 6" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
          ) : (
            <path d="M16 8.5a5 5 0 0 1 0 7M18.5 6a8.5 8.5 0 0 1 0 12" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
          )}
        </svg>
      </button>
      <button className="circle glass glass-interactive" onClick={onEnd} aria-label="End">
        <Close />
      </button>
    </div>
  )
}
