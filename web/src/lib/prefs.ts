import { useEffect, useState } from 'react'

/** A boolean setting remembered in this browser (Settings toggles and map layers). */
export function usePref(key: string, initial: boolean) {
  const [value, setValue] = useState<boolean>(() => {
    try {
      const stored = localStorage.getItem(`lmk.${key}`)
      return stored === null ? initial : stored === 'true'
    } catch {
      return initial
    }
  })
  useEffect(() => {
    try {
      localStorage.setItem(`lmk.${key}`, String(value))
    } catch {
      // Private mode or blocked storage: keep the in-memory value.
    }
  }, [key, value])
  return [value, setValue] as const
}
