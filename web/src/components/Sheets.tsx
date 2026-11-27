import { useMapsLibrary } from '@vis.gl/react-google-maps'
import { useEffect, useRef, useState } from 'react'
import type { LatLng } from '../lib/geo'
import { useSavedPlaces, type SavedPlace } from '../lib/savedPlaces'
import { Clock, Close, Search, Star } from './Icons'
import { Sheet } from './Sheet'

export type Destination = { name: string; location: LatLng }

/** F5: enter a destination, with starred places and recent searches. Also used to type where an incident happened. */
export function SearchSheet({
  title = 'Where to?',
  near,
  onPick,
  onClose,
}: {
  title?: string
  near: LatLng
  onPick: (d: Destination) => void
  onClose: () => void
}) {
  const places = useMapsLibrary('places')
  const [query, setQuery] = useState('')
  const [suggestions, setSuggestions] = useState<google.maps.places.AutocompleteSuggestion[]>([])
  const [error, setError] = useState<string | null>(null)
  const token = useRef<google.maps.places.AutocompleteSessionToken | null>(null)
  const saved = useSavedPlaces()

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

  async function fetchPlace(s: google.maps.places.AutocompleteSuggestion): Promise<SavedPlace | null> {
    const prediction = s.placePrediction
    if (!prediction) return null
    try {
      const place = prediction.toPlace()
      await place.fetchFields({ fields: ['displayName', 'location'] })
      if (!place.location) return null
      token.current = null
      return { name: place.displayName ?? prediction.mainText?.text ?? 'Destination', ...place.location.toJSON() }
    } catch (e) {
      setError(`Couldn't load that place: ${(e as Error).message}`)
      return null
    }
  }

  function choose(place: SavedPlace) {
    saved.addRecent(place)
    onPick({ name: place.name, location: { lat: place.lat, lng: place.lng } })
    onClose()
  }

  const star = (name: string, onToggle: () => void) => {
    const on = saved.isFavorite(name)
    return (
      <button className={`star-button${on ? ' on' : ''}`} onClick={onToggle} aria-label={on ? 'Remove from Favorites' : 'Add to Favorites'}>
        <Star filled={on} />
      </button>
    )
  }

  return (
    <Sheet title={title} onClose={onClose}>
      <label className="search-field">
        <Search className="icon" />
        <input autoFocus placeholder="Search for a place" value={query} onChange={(e) => setQuery(e.target.value)} />
      </label>
      {error && <div className="group-footer destructive">{error}</div>}
      {query.trim() ? (
        suggestions.length > 0 && (
          <div className="group">
            {suggestions.map((s) => {
              const p = s.placePrediction
              if (!p) return null
              const name = p.mainText?.text ?? p.text.text
              return (
                <div key={p.placeId} className="place-row">
                  <button className="suggestion" onClick={async () => { const place = await fetchPlace(s); if (place) choose(place) }}>
                    {name}
                    <small>{p.secondaryText?.text}</small>
                  </button>
                  {star(name, async () => { const place = await fetchPlace(s); if (place) saved.toggleFavorite(place) })}
                </div>
              )
            })}
          </div>
        )
      ) : (
        <>
          {saved.favorites.length > 0 && (
            <>
              <div className="group-title">Favorites</div>
              <div className="favorite-chips">
                {saved.favorites.map((place) => (
                  <button key={place.name} className="btn-glass glass glass-interactive favorite-chip" onClick={() => choose(place)}>
                    <Star className="icon-sm" filled /> {place.name}
                  </button>
                ))}
              </div>
            </>
          )}
          {saved.recents.length > 0 && (
            <>
              <div className="group-title">Recent</div>
              <div className="group">
                {saved.recents.map((place) => (
                  <div key={place.name} className="place-row">
                    <button className="suggestion recent" onClick={() => choose(place)}>
                      <Clock className="icon-sm" /> {place.name}
                    </button>
                    {star(place.name, () => saved.toggleFavorite(place))}
                    <button className="star-button" onClick={() => saved.removeRecent(place)} aria-label="Remove from Recent">
                      <Close className="icon-sm" />
                    </button>
                  </div>
                ))}
              </div>
            </>
          )}
        </>
      )}
    </Sheet>
  )
}
