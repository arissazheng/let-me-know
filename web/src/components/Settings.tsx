import { useEffect, useState, type ReactNode } from 'react'
import type { Report } from '../lib/data'
import { useCampus, type CampusResource } from '../lib/campus'
import { supabase } from '../lib/supabase'
import { Bulb, LocationArrow, People, Warning } from './Icons'
import { Sheet, Toggle } from './Sheet'

type Pref = readonly [boolean, (v: boolean) => void]
export type Prefs = {
  avoidIncidents: Pref
  avoidPoorLighting: Pref
  preferBusierStreets: Pref
  shareLocation: Pref
  notifyNewReports: Pref
}

type Page = 'menu' | 'tracker' | 'resources' | 'about'
const TITLES: Record<Page, string> = { menu: 'Settings', tracker: 'Incident Tracker', resources: 'Safety Resources', about: 'About Us' }

/**
 * F7: the menu — the incident tracker, campus resources, notifications, route preferences, and the
 * opt-in for preference-based location tracking.
 */
export function SettingsSheet({
  prefs,
  email,
  onOpenReport,
  onSignOut,
  onClose,
}: {
  prefs: Prefs
  email?: string
  onOpenReport: (report: Report) => void
  onSignOut: () => void
  onClose: () => void
}) {
  const [page, setPage] = useState<Page>('menu')
  const row = (label: string, icon: ReactNode, [on, set]: Pref) => (
    <div className="cell">
      {icon}
      <span className="label">{label}</span>
      <Toggle on={on} onChange={set} label={label} />
    </div>
  )
  const link = (label: string, onClick: () => void) => (
    <button className="cell" onClick={onClick}>
      <span className="label">{label}</span>
      <span className="value">›</span>
    </button>
  )
  const [notify, setNotify] = prefs.notifyNewReports

  return (
    <Sheet title={TITLES[page]} onClose={onClose}>
      {page !== 'menu' && (
        <button className="back-button" onClick={() => setPage('menu')}>
          ‹ Settings
        </button>
      )}
      {page === 'tracker' && <IncidentTracker onOpenReport={onOpenReport} />}
      {page === 'resources' && <SafetyResources />}
      {page === 'about' && <About />}
      {page === 'menu' && (
        <>
          <div className="group">
            {link('Incident Tracker', () => setPage('tracker'))}
            {link('Safety Resources', () => setPage('resources'))}
            {link('About Us', () => setPage('about'))}
          </div>

          <div className="group-title">Notifications</div>
          <div className="group">
            {row('New incident reports', <Warning className="icon" />, [
              notify,
              async (on: boolean) => {
                if (on && 'Notification' in window && Notification.permission !== 'granted') {
                  if ((await Notification.requestPermission()) !== 'granted') return
                }
                setNotify(on)
              },
            ])}
          </div>
          <div className="group-footer">Get a notification whenever a student reports an incident around campus, while this page is open.</div>

          <div className="group-title">Safer Routes</div>
          <div className="group">
            {row('Avoid live incidents', <Warning className="icon" />, prefs.avoidIncidents)}
            {row('Avoid poorly lit streets', <Bulb className="icon" />, prefs.avoidPoorLighting)}
            {row('Prefer busier streets', <People className="icon" />, prefs.preferBusierStreets)}
          </div>

          <div className="group-title">Population Map</div>
          <div className="group">{row('Share my location anonymously', <LocationArrow className="icon" />, prefs.shareLocation)}</div>
          <div className="group-footer">
            While the app is open, sends your approximate location (rounded to about 10 m) as you move, about once a minute. It's only
            used to show how crowded areas are, never who is where.
          </div>

          <div className="group" style={{ marginTop: 24 }}>
            {email && (
              <div className="cell"><span className="label">Signed in as</span><span className="value">{email}</span></div>
            )}
            <button className="cell destructive" onClick={onSignOut}>Sign Out</button>
          </div>
          <div className="group-footer">Favorites, recent searches, and these settings are saved to your account.</div>
        </>
      )}
    </Sheet>
  )
}

/** Every report around campus as a table, or just the ones this student filed. */
function IncidentTracker({ onOpenReport }: { onOpenReport: (report: Report) => void }) {
  const [scope, setScope] = useState<'all' | 'mine'>('all')
  const [reports, setReports] = useState<Report[] | null>(null)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    setReports(null)
    supabase
      .from(scope === 'all' ? 'all_reports' : 'my_reports')
      .select()
      .order('created_at', { ascending: false })
      .limit(500)
      .then(({ data, error }) => {
        if (error) setError(`Couldn't load reports: ${error.message}`)
        else {
          setError(null)
          setReports(data as Report[])
        }
      })
  }, [scope])

  return (
    <>
      <div className="segmented">
        <button className={scope === 'all' ? 'on' : ''} onClick={() => setScope('all')}>All Reports</button>
        <button className={scope === 'mine' ? 'on' : ''} onClick={() => setScope('mine')}>My Reports</button>
      </div>
      {error && <div className="group-footer destructive">{error}</div>}
      {reports && reports.length === 0 && (
        <div className="group-footer">{scope === 'mine' ? "You haven't filed any reports." : 'No reports yet.'}</div>
      )}
      {reports && reports.length > 0 && (
        <table className="incident-table">
          <thead>
            <tr><th>Incident</th><th>Location</th><th>Filed</th></tr>
          </thead>
          <tbody>
            {reports.map((r) => (
              <tr key={r.id} onClick={() => onOpenReport(r)}>
                <td>
                  <strong>{r.title || 'Incident report'}</strong>
                  <small>{r.description}</small>
                </td>
                <td>{r.place_name ?? '—'}</td>
                <td>{new Date(r.created_at).toLocaleDateString([], { month: 'short', day: 'numeric' })}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </>
  )
}

/** The student's campus hotlines, escorts, and emergency services, each linked to its source. */
function SafetyResources() {
  const campus = useCampus()
  const settingUp = !campus || campus.status === 'pending' || campus.status === 'generating'
  const href = (item: CampusResource) => (item.phone ? `tel:${item.phone}` : (item.url ?? undefined))
  const row = (item: CampusResource) => (
    <div key={item.label} className="cell resource">
      <a className="label" href={href(item)} target={item.phone || item.url?.startsWith('sms:') ? undefined : '_blank'} rel="noreferrer">
        {item.label}
        <small>{item.detail}</small>
      </a>
      {item.source_url && (
        <a className="source-link" href={item.source_url} target="_blank" rel="noreferrer">
          Source
        </a>
      )}
    </div>
  )

  if (campus?.status === 'ready' && campus.resources.length > 0) {
    return (
      <>
        {campus.resources.map((section) => (
          <div key={section.title}>
            <div className="group-title">{section.title}</div>
            <div className="group">{section.items.map(row)}</div>
            {section.footer && <div className="group-footer">{section.footer}</div>}
          </div>
        ))}
        <div className="group-footer">
          Found on {campus.short_name ?? campus.domain}'s official pages when the campus was set up. Tap Source to check a number.
        </div>
      </>
    )
  }
  return (
    <>
      <div className="group-title">Emergency</div>
      <div className="group">{row({ label: 'Emergency', detail: '911', phone: '911', url: null, source_url: null })}</div>
      <div className="group-footer">
        {settingUp
          ? "Looking up your campus's safety resources. This takes about a minute the first time anyone from your school signs in."
          : "We couldn't find your campus's safety resources yet."}
      </div>
    </>
  )
}

function About() {
  return (
    <>
      <div className="group about">
        <h3>Let Me Know</h3>
        <p>
          Students share what they see around campus as it happens, so everyone can see live incidents on the map and walk home on
          safer routes that avoid them, stay on lit streets, and keep to busier areas.
        </p>
      </div>
      <div className="group-title">Why We Built This</div>
      <div className="group about">
        <p>
          Students regularly run into things like being followed, harassment, or aggressive behavior on their way around campus, and other students walking the same streets usually never hear about it. We built Let Me Know so students can warn each other the moment something happens and pick a safer way to get where they're going.
        </p>
      </div>
      <div className="group-title">Data</div>
      <div className="group">
        <div className="cell"><span className="label">Streetlights</span><span className="value">City of Berkeley</span></div>
        <div className="cell"><span className="label">Population</span><span className="value">Student pings + simulated</span></div>
        <div className="cell"><span className="label">Routes</span><span className="value">Valhalla / OpenStreetMap</span></div>
      </div>
    </>
  )
}
