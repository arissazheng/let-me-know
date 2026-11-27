function required(name: string): string {
  const value = import.meta.env[name] as string | undefined
  if (!value) throw new Error(`Missing ${name}. Copy web/.env.example to web/.env.local and fill it in.`)
  return value
}

export const config = {
  googleMapsApiKey: required('VITE_GOOGLE_MAPS_API_KEY'),
  googleMapId: required('VITE_GOOGLE_MAP_ID'),
  supabaseUrl: required('VITE_SUPABASE_URL'),
  supabaseAnonKey: required('VITE_SUPABASE_ANON_KEY'),
  valhallaUrl: required('VITE_VALHALLA_URL'),
}

export const BERKELEY = { lat: 37.869, lng: -122.2595 }

export const colors = {
  lightYellow: [255, 204, 0] as const,
  populationBlue: [10, 132, 255] as const,
  safeGreen: '#34c759',
}
