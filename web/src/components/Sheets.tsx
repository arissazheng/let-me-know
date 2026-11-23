import { useMapsLibrary } from '@vis.gl/react-google-maps'
import { useEffect, useRef, useState } from 'react'
import type { Report } from '../lib/data'
import type { LatLng } from '../lib/geo'
import { Bulb, Check, Clock, LocationArrow, People, Search, Warning } from './Icons'
import { Sheet, Toggle } from './Sheet'

function timeAgo(iso: string) {
  const minutes = Math.round((Date.now() - new Date(iso).getTime()) / 60000)
  const rtf = new Intl.RelativeTimeFormat('en', { numeric: 'auto' })
  if (minutes < 60) return rtf.format(-minutes, 'minute')
  return rtf.format(-Math.round(minutes / 60), 'hour')
}

/** F3: read a report — text, image or video, and when it was posted. */
export function ReportDetail({ report, onClose }: { report: Report; onClose: () => void }) {
  return (
    <Sheet onClose={onClose} half>
      <div className="report-detail">
        <div className="meta">
          <Clock className="icon" /> {timeAgo(report.created_at)}
          {report.is_demo && <span className="badge">Demo</span>}
        </div>
        <p>{report.description}</p>
        {report.media_url &&
          (report.media_type === 'video' ? (
            <video src={report.media_url} controls playsInline />
          ) : (
            <img src={report.media_url} alt="Attached to report" />
          ))}
      </div>
    </Sheet>
  )
}

/** F4: describe an incident at the pinned location, optionally with a photo or video. */
export function NewReportSheet({ onSubmit, onClose }: { onSubmit: (text: string, file: File | null) => Promise<void>; onClose: () => void }) {
  const [text, setText] = useState('')
  const [file, setFile] = useState<File | null>(null)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const input = useRef<HTMLInputElement>(null)

  async function submit() {
    setBusy(true)
    setError(null)
    try {
      await onSubmit(text.trim(), file)
      onClose()
    } catch (e) {
      setError(`Couldn't submit: ${(e as Error).message}`)
    } finally {
      setBusy(false)
    }
  }

  return (
    <Sheet
      title="Report"
      onClose={onClose}
      confirm={
        <button
          className="circle btn-prominent"
          style={{ width: 44, height: 44, padding: 0 }}
          disabled={!text.trim() || busy}
          onClick={submit}
          aria-label="Submit"
        >
          <Check className="icon" />
        </button>
      }
    >
      <textarea className="text-input" rows={5} placeholder="What happened?" value={text} onChange={(e) => setText(e.target.value)} />
      <div className="group-footer">Reported at the pin you placed. Visible to signed-in students for 24 hours.</div>
      <div className="group" style={{ marginTop: 16 }}>
        <button className="cell" onClick={() => input.current?.click()}>
          <span className="label" style={{ color: 'var(--tint)' }}>
            {file ? `${file.type.startsWith('video') ? 'Video' : 'Photo'} attached — replace` : 'Add Photo or Video'}
          </span>
        </button>
        {file && (
          <button className="cell destructive" onClick={() => setFile(null)}>
            Remove
          </button>
        )}
      </div>
      <input ref={input} type="file" accept="image/*,video/*" hidden onChange={(e) => setFile(e.target.files?.[0] ?? null)} />
      {error && <div className="group-footer destructive">{error}</div>}
    </Sheet>
  )
}

export type Destination = { name: string; location: LatLng }

/** F5: enter a destination. */
export function SearchSheet({ near, onPick, onClose }: { near: LatLng; onPick: (d: Destination) => void; onClose: () => void }) {
  const places = useMapsLibrary('places')
  const [query, setQuery] = useState('')
  const [suggestions, setSuggestions] = useState<google.maps.places.AutocompleteSuggestion[]>([])
  const [error, setError] = useState<string | null>(null)
  const token = useRef<google.maps.places.AutocompleteSessionToken | null>(null)

  useEffect(() => {
    if (!places) return
    token.current ??= new places.AutocompleteSessionToken()
    const text = query.trim()
    if (!text) {
      setSuggestions([])
      return
    }
    const timer = setTimeout(async () => {
      try {
        const { suggestions } = await places.AutocompleteSuggestion.fetchAutocompleteSuggestions({
          input: text,
          sessionToken: token.current!,
          locationBias: { center: near, radius: 3000 },
        })
        setError(null)
        setSuggestions(suggestions)
      } catch (e) {
        setError(`Search unavailable: ${(e as Error).message}`)
      }
    }, 250)
    return () => clearTimeout(timer)
  }, [places, query, near])

  async function pick(s: google.maps.places.AutocompleteSuggestion) {
    const prediction = s.placePrediction
    if (!prediction) return
    try {
      const place = prediction.toPlace()
      await place.fetchFields({ fields: ['displayName', 'location'] })
      if (!place.location) return
      token.current = null
      onPick({ name: place.displayName ?? prediction.mainText?.text ?? 'Destination', location: place.location.toJSON() })
      onClose()
    } catch (e) {
      setError(`Couldn't load that place: ${(e as Error).message}`)
    }
  }

  return (
    <Sheet title="Where to?" onClose={onClose}>
      <label className="search-field">
        <Search className="icon" />
        <input autoFocus placeholder="Search for a place" value={query} onChange={(e) => setQuery(e.target.value)} />
      </label>
      {error && <div className="group-footer destructive">{error}</div>}
      {suggestions.length > 0 && (
        <div className="group">
          {suggestions.map((s) =>
            s.placePrediction ? (
              <button key={s.placePrediction.placeId} className="suggestion" onClick={() => pick(s)}>
                {s.placePrediction.mainText?.text ?? s.placePrediction.text.text}
                <small>{s.placePrediction.secondaryText?.text}</small>
              </button>
            ) : null,
          )}
        </div>
      )}
    </Sheet>
  )
}

export type Prefs = {
  avoidIncidents: readonly [boolean, (v: boolean) => void]
  avoidPoorLighting: readonly [boolean, (v: boolean) => void]
  preferBusierStreets: readonly [boolean, (v: boolean) => void]
  shareLocation: readonly [boolean, (v: boolean) => void]
}

/** F7: route preferences, plus the opt-in for preference-based location tracking. */
export function SettingsSheet({ prefs, email, onSignOut, onClose }: { prefs: Prefs; email?: string; onSignOut: () => void; onClose: () => void }) {
  const row = (label: string, icon: React.ReactNode, [on, set]: readonly [boolean, (v: boolean) => void]) => (
    <div className="cell">
      {icon}
      <span className="label">{label}</span>
      <Toggle on={on} onChange={set} label={label} />
    </div>
  )
  return (
    <Sheet title="Settings" onClose={onClose}>
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

      <div className="group-title">About the Data</div>
      <div className="group">
        <div className="cell"><span className="label">Streetlights</span><span className="value">City of Berkeley</span></div>
        <div className="cell"><span className="label">Population</span><span className="value">Student pings + simulated</span></div>
        <div className="cell"><span className="label">Routes</span><span className="value">Valhalla / OpenStreetMap</span></div>
      </div>

      <div className="group" style={{ marginTop: 24 }}>
        {email && (
          <div className="cell"><span className="label">Signed in as</span><span className="value">{email}</span></div>
        )}
        <button className="cell destructive" onClick={onSignOut}>Sign Out</button>
      </div>
    </Sheet>
  )
}
