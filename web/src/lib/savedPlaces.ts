import { updateAccount, useAccount, type SavedPlace } from './account'

export type { SavedPlace }

const RECENT_LIMIT = 10

/** Favorite places and recent searches for the search sheet, kept with the student's account. */
export function useSavedPlaces() {
  const { favorites, recents } = useAccount()
  const isFavorite = (name: string) => favorites.some((p) => p.name === name)
  return {
    favorites,
    recents,
    isFavorite,
    toggleFavorite: (place: SavedPlace) =>
      updateAccount({ favorites: isFavorite(place.name) ? favorites.filter((p) => p.name !== place.name) : [...favorites, place] }),
    /** Newest first, without duplicates. */
    addRecent: (place: SavedPlace) =>
      updateAccount({ recents: [place, ...recents.filter((p) => p.name !== place.name)].slice(0, RECENT_LIMIT) }),
    removeRecent: (place: SavedPlace) => updateAccount({ recents: recents.filter((p) => p.name !== place.name) }),
  }
}
