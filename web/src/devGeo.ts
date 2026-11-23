// Development only: open the app with `?fakegeo` to drive the device location from the console
// (window.__setFakeLocation(lat, lng)) — for testing routing and turn-by-turn navigation on a laptop.
type Listener = PositionCallback

export function installFakeGeolocation(start = { lat: 37.8655, lng: -122.256 }) {
  let current = start
  const listeners = new Map<number, Listener>()
  let nextId = 1
  const position = (): GeolocationPosition =>
    ({
      coords: { latitude: current.lat, longitude: current.lng, accuracy: 5, altitude: null, altitudeAccuracy: null, heading: null, speed: null },
      timestamp: Date.now(),
    }) as GeolocationPosition

  Object.defineProperty(navigator, 'geolocation', {
    configurable: true,
    value: {
      getCurrentPosition: (ok: Listener) => setTimeout(() => ok(position())),
      watchPosition: (ok: Listener) => {
        const id = nextId++
        listeners.set(id, ok)
        setTimeout(() => ok(position()))
        return id
      },
      clearWatch: (id: number) => listeners.delete(id),
    },
  })
  ;(window as unknown as { __setFakeLocation: (lat: number, lng: number) => void }).__setFakeLocation = (lat, lng) => {
    current = { lat, lng }
    listeners.forEach((ok) => ok(position()))
  }
}
