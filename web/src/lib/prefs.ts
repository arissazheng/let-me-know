import { updateAccount, useAccount } from './account'

/** A boolean setting (Settings toggles and map layers), kept with the student's account. */
export function usePref(key: string, initial: boolean) {
  const { preferences } = useAccount()
  const value = preferences[key] ?? initial
  const setValue = (next: boolean) => updateAccount({ preferences: { ...preferences, [key]: next } })
  return [value, setValue] as const
}
