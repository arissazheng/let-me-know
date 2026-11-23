import { Map, type MapCameraChangedEvent } from '@vis.gl/react-google-maps'
import { useEffect, useRef, useState } from 'react'
import { BERKELEY } from '../lib/config'
import { submitReport, useLocation, usePopulation, useReports, type Report } from '../lib/data'
import type { LatLng } from '../lib/geo'
import { useNavigator } from '../lib/navigation'
import { usePref } from '../lib/prefs'
import { passesNear, safeRoutes, type SafeRoute } from '../lib/routing'
import { supabase } from '../lib/supabase'
import { Check, Filter, Gear, Locate, Pin, ReportBubble, Search } from './Icons'
import { FocusOn, FollowUser, GlowLayers, ReportPins, RouteLines, UserDot } from './MapLayers'
import { NavigationBar, TurnBanner } from './Navigation'
import { RouteCard } from './RouteCard'
import { NewReportSheet, ReportDetail, SearchSheet, SettingsSheet, type Destination } from './Sheets'

/** The home screen: map, live reports, glows, search, safer routes, and reporting. */
export function MapScreen({ email }: { email?: string }) {
  const avoidIncidents = usePref('avoidIncidents', true)
  const avoidPoorLighting = usePref('avoidPoorLighting', true)
  const preferBusierStreets = usePref('preferBusierStreets', true)
  const shareLocation = usePref('shareLocation', false)
  const [showReports, setShowReports] = usePref('showReports', true)
  const [showLights, setShowLights] = usePref('showLightGlow', true)
  const [showPopulation, setShowPopulation] = usePref('showPopulationGlow', true)

  const { reports, latestLive, error: reportsError } = useReports()
  const { cells, crowdLevel } = usePopulation()
  const location = useLocation(shareLocation[0])

  const [center, setCenter] = useState<LatLng>(BERKELEY)
  const [focusToken, setFocusToken] = useState(0)
  const [menuOpen, setMenuOpen] = useState(false)
  const [selectedReport, setSelectedReport] = useState<Report | null>(null)
  const [placing, setPlacing] = useState(false)
  const [reportAt, setReportAt] = useState<LatLng | null>(null)
  const [searching, setSearching] = useState(false)
  const [settingsOpen, setSettingsOpen] = useState(false)

  const [destination, setDestination] = useState<Destination | null>(null)
  const [routes, setRoutes] = useState<SafeRoute[]>([])
  const [selectedRouteId, setSelectedRouteId] = useState<string | null>(null)
  const [routing, setRouting] = useState(false)
  const [routeError, setRouteError] = useState<string | null>(null)
  const [banner, setBanner] = useState<string | null>(null)
  const navigator = useNavigator()
  const nav = navigator.state

  const prefs = {
    avoidIncidents: avoidIncidents[0],
    avoidPoorLighting: avoidPoorLighting[0],
    preferBusierStreets: preferBusierStreets[0],
  }

  async function planRoute(to: Destination | null = destination) {
    if (!to) return
    if (!location) {
      setRouteError('Turn on location to plan a route.')
      return
    }
    setRouting(true)
    setRouteError(null)
    try {
      const planned = await safeRoutes(location, to.location, reports, crowdLevel, prefs)
      setRoutes(planned)
      setSelectedRouteId(planned[0]?.id ?? null)
      // Mid-walk re-plans (new report or off route) continue guidance on the new route.
      if (nav && planned[0]) navigator.replace(planned[0])
    } catch (e) {
      setRoutes([])
      setRouteError((e as Error).message)
    } finally {
      setRouting(false)
    }
  }

  // Routes self-correct when a new report lands near the route being shown (F8).
  const lastHandled = useRef<string | null>(null)
  useEffect(() => {
    if (!latestLive || latestLive.id === lastHandled.current) return
    lastHandled.current = latestLive.id
    const current = nav?.route ?? routes.find((r) => r.id === selectedRouteId)
    if (!destination || !current || !passesNear(current, latestLive, 75)) return
    planRoute().then(() => showBanner('New report near your route. Route updated.'))
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [latestLive])

  // Turn-by-turn progress on every location fix; re-plan if the student walks off the route.
  useEffect(() => {
    if (!nav || !location) return
    if (navigator.update(location)) planRoute().then(() => showBanner('Off route. Found a new safer route.'))
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [location])

  function showBanner(text: string) {
    setBanner(text)
    setTimeout(() => setBanner((current) => (current === text ? null : current)), 5000)
  }

  function startNavigation() {
    const route = routes.find((r) => r.id === selectedRouteId)
    if (route) navigator.start(route)
  }

  // Re-plan when route preferences change.
  useEffect(() => {
    if (destination) planRoute()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [prefs.avoidIncidents, prefs.avoidPoorLighting, prefs.preferBusierStreets])

  function endRoute() {
    navigator.stop()
    setDestination(null)
    setRoutes([])
    setSelectedRouteId(null)
    setRouteError(null)
  }

  const message = reportsError ?? routeError

  const reportButton = (
    <button className="btn-prominent red" style={{ display: 'flex', gap: 8, alignItems: 'center' }} onClick={() => setPlacing(true)}>
      <ReportBubble /> Report
    </button>
  )

  return (
    <div className="map-screen">
      <Map
        className="map"
        defaultCenter={BERKELEY}
        defaultZoom={15.5}
        disableDefaultUI
        clickableIcons={false}
        gestureHandling="greedy"
        onCameraChanged={(e: MapCameraChangedEvent) => setCenter(e.detail.center)}
      >
        <GlowLayers cells={cells} showLights={showLights} showPopulation={showPopulation} dimmed={!!nav} />
        {showReports && <ReportPins reports={reports} onSelect={setSelectedReport} />}
        <RouteLines
          routes={nav ? [nav.route] : routes}
          selectedId={nav?.route.id ?? selectedRouteId}
          destination={destination?.location ?? null}
          fit={!nav}
          onSelect={setSelectedRouteId}
        />
        <UserDot location={location} />
        <FocusOn target={location ?? BERKELEY} token={focusToken} />
        {nav && <FollowUser location={location} />}
      </Map>

      {placing && <Pin className="center-pin" />}

      <div className="overlay">
        {nav ? (
          <TurnBanner nav={nav} />
        ) : (
          <div className="top-bar">
            <button className="search-pill glass glass-interactive" onClick={() => setSearching(true)}>
              <Search />
              <span className={destination ? '' : 'placeholder'}>{destination?.name ?? 'Where to?'}</span>
            </button>
            <button className="circle glass glass-interactive" onClick={() => setMenuOpen((o) => !o)} aria-label="Map layers">
              <Filter />
            </button>
          </div>
        )}
        {banner && <div className="banner glass">{banner}</div>}
        {message && <div className="error-pill glass">{message}</div>}
        <div className="spacer" />

        {placing ? (
          <div className="place-panel glass">
            <div>Move the map to place the pin where it happened.</div>
            <div className="row">
              <button className="btn-glass glass glass-interactive" onClick={() => setPlacing(false)}>Cancel</button>
              <button className="btn-prominent red" onClick={() => setReportAt(center)}>Next</button>
            </div>
          </div>
        ) : nav ? (
          <NavigationBar
            nav={nav}
            muted={navigator.muted}
            onToggleMute={() => navigator.setMuted(!navigator.muted)}
            onReport={() => setPlacing(true)}
            onEnd={endRoute}
          />
        ) : destination ? (
          routing ? (
            <div className="place-panel glass">Finding a safer route…</div>
          ) : routes.length ? (
            // Reporting stays available mid-route; the student is most likely to see something while walking.
            <>
              <div style={{ alignSelf: 'flex-end' }}>{reportButton}</div>
              <RouteCard
                destinationName={destination.name}
                routes={routes}
                selectedId={selectedRouteId}
                onSelect={setSelectedRouteId}
                onStart={startNavigation}
                onClose={endRoute}
              />
            </>
          ) : (
            <button className="btn-glass glass" style={{ alignSelf: 'center' }} onClick={endRoute}>Close</button>
          )
        ) : (
          <>
            {(showLights || showPopulation) && (
              <div className="legend glass">
                {showLights && <span><i style={{ background: '#ffcc00', boxShadow: '0 0 6px #ffcc00' }} />Streetlights</span>}
                {showPopulation && <span><i style={{ background: '#0a84ff', boxShadow: '0 0 6px #0a84ff' }} />Students</span>}
              </div>
            )}
            <div className="bottom-bar">
              <button className="circle glass glass-interactive" onClick={() => setSettingsOpen(true)} aria-label="Settings">
                <Gear />
              </button>
              {reportButton}
              <button className="circle glass glass-interactive" onClick={() => setFocusToken((t) => t + 1)} aria-label="My location">
                <Locate />
              </button>
            </div>
          </>
        )}
      </div>

      {menuOpen && (
        <>
          <div style={{ position: 'fixed', inset: 0, zIndex: 4 }} onClick={() => setMenuOpen(false)} />
          <div className="menu glass">
            {[
              ['Reports', showReports, setShowReports],
              ['Streetlights', showLights, setShowLights],
              ['Students', showPopulation, setShowPopulation],
            ].map(([label, on, set]) => (
              <button key={label as string} onClick={() => (set as (v: boolean) => void)(!on)}>
                <span className="check">{on ? <Check className="icon" /> : null}</span>
                {label as string}
              </button>
            ))}
          </div>
        </>
      )}

      {selectedReport && <ReportDetail report={selectedReport} onClose={() => setSelectedReport(null)} />}
      {reportAt && (
        <NewReportSheet
          onClose={() => setReportAt(null)}
          onSubmit={async (text, file) => {
            await submitReport(text, reportAt, file)
            setPlacing(false)
          }}
        />
      )}
      {searching && (
        <SearchSheet
          near={location ?? center}
          onClose={() => setSearching(false)}
          onPick={(d) => {
            setDestination(d)
            planRoute(d)
          }}
        />
      )}
      {settingsOpen && (
        <SettingsSheet
          prefs={{ avoidIncidents, avoidPoorLighting, preferBusierStreets, shareLocation }}
          email={email}
          onSignOut={() => supabase.auth.signOut()}
          onClose={() => setSettingsOpen(false)}
        />
      )}
    </div>
  )
}
