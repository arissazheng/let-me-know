import { useEffect, useState, type ReactNode } from 'react'
import type { Report } from '../lib/data'
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
 * F7: the menu — reporting, trip planning, the incident tracker, campus resources, notifications,
 * route preferences, and the opt-in for preference-based location tracking.
 */
export function SettingsSheet({
  prefs,
  email,
  onReportIncident,
  onPlanTrip,
  onOpenReport,
  onSignOut,
  onClose,
}: {
  prefs: Prefs
  email?: string
  onReportIncident: () => void
  onPlanTrip: () => void
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
            {link('Report Incident', () => {
              onClose()
              onReportIncident()
            })}
            {link('Trip Planner', () => {
              onClose()
              onPlanTrip()
            })}
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

const RESOURCES: { title: string; items: { label: string; detail: string; href: string }[]; footer?: string }[] = [
  {
    title: 'Emergency',
    items: [
      { label: 'Emergency', detail: '911', href: 'tel:911' },
      { label: 'UCPD Emergency from a Cell Phone', detail: '(510) 642-3333', href: 'tel:5106423333' },
    ],
    footer: 'Blue light phones on campus also connect straight to UCPD dispatch.',
  },
  {
    title: 'UCPD Resources',
    items: [
      { label: 'UCPD Non-Emergency (24 hours)', detail: '(510) 642-6760', href: 'tel:5106426760' },
      { label: 'SafeWalk Escort', detail: 'Dusk – 3 AM, last call 2:30 AM · (510) 642-WALK', href: 'tel:5106429255' },
      { label: 'Night Safety Shuttle', detail: '7:30 PM – 3 AM · book in the Downtowner app', href: 'https://nightsafety.berkeley.edu/' },
      { label: 'Night Safety Services', detail: 'nightsafety.berkeley.edu', href: 'https://nightsafety.berkeley.edu/' },
      { label: 'Make a Report to UCPD', detail: 'ucpd.berkeley.edu', href: 'https://ucpd.berkeley.edu/make-report' },
      { label: 'Resource Guide', detail: 'Campus safety support', href: 'https://supportal.berkeley.edu/topics/safety' },
    ],
  },
  { title: 'Anonymous Tips', items: [{ label: 'CalTIP (text)', detail: '(510) 664-8477 · non-emergency crime', href: 'sms:5106648477' }] },
  { title: 'City of Berkeley', items: [{ label: 'Berkeley Police Non-Emergency', detail: '(510) 981-5900', href: 'tel:5109815900' }] },
]

/** UC Berkeley hotlines, escorts, and emergency services. */
function SafetyResources() {
  return (
    <>
      {RESOURCES.map((section) => (
        <div key={section.title}>
          <div className="group-title">{section.title}</div>
          <div className="group">
            {section.items.map((item) => (
              <a key={item.label} className="cell resource" href={item.href} target={item.href.startsWith('http') ? '_blank' : undefined} rel="noreferrer">
                <span className="label">
                  {item.label}
                  <small>{item.detail}</small>
                </span>
              </a>
            ))}
          </div>
          {section.footer && <div className="group-footer">{section.footer}</div>}
        </div>
      ))}
    </>
  )
}

const TEAM = ['Arissa Zheng', 'Arushi Desai', 'Kevin Padilla', 'Adonis Som', 'Runn Kiriruangchai', 'Sarah Elnahas']

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
      <div className="group-title">Team 14 · UGBA 190D</div>
      <div className="group">
        {TEAM.map((name) => (
          <div key={name} className="cell"><span className="label">{name}</span></div>
        ))}
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
