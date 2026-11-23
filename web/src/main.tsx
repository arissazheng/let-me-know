import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { App } from './App'
import './styles.css'

if (import.meta.env.DEV && new URLSearchParams(window.location.search).has('fakegeo')) {
  const { installFakeGeolocation } = await import('./devGeo')
  installFakeGeolocation()
}

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>,
)
