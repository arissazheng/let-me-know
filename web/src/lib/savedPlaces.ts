import { useEffect, useState } from 'react'
import type { LatLng } from './geo'

/** A place the student starred or searched for, kept in this browser. */
export type SavedPlace = { name: string; location: LatLng }

const FAVORITES = 'savedPlaces.favorites'
const RECENTS = 'savedPlaces.recents'
const RECENT_LIMIT = 10
const listeners = new Set<() => void>()

function read(key: string): SavedPlace[] {
  try {
    return JSON.parse(localStorage.getItem(key) ?? '[]') as SavedPlace[]
  } catch {
    return []
  }
}

function write(key: string, places: SavedPlace[]) {
  try {
    localStorage.setItem(key, JSON.stringify(places))
  } catch {
    // Private windows can block storage; the lists just won't persist.
  }
  listeners.forEach((l) => l())
}

/** Favorite places and recent searches for the search sheet. */
export function useSavedPlaces() {
  const [favorites, setFavorites] = useState(() => read(FAVORITES))
  const [recents, setRecents] = useState(() => read(RECENTS))

  useEffect(() => {
    const refresh = () => {
      setFavorites(read(FAVORITES))
      setRecents(read(RECENTS))
    }
    listeners.add(refresh)
    return () => void listeners.delete(refresh)
  }, [])

  const isFavorite = (name: string) => favorites.some((p) => p.name === name)
  return {
    favorites,
    recents,
    isFavorite,
    toggleFavorite: (place: SavedPlace) =>
      write(FAVORITES, isFavorite(place.name) ? favorites.filter((p) => p.name !== place.name) : [...favorites, place]),
    /** Newest first, without duplicates. */
    addRecent: (place: SavedPlace) =>
      write(RECENTS, [place, ...recents.filter((p) => p.name !== place.name)].slice(0, RECENT_LIMIT)),
    removeRecent: (place: SavedPlace) => write(RECENTS, recents.filter((p) => p.name !== place.name)),
  }
}
