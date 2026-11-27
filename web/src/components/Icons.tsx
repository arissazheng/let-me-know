// SF Symbols–style line icons drawn as inline SVG.
type Props = { className?: string }
const base = {
  viewBox: '0 0 24 24',
  fill: 'none',
  stroke: 'currentColor',
  strokeWidth: 2,
  strokeLinecap: 'round' as const,
  strokeLinejoin: 'round' as const,
}

export const Search = ({ className = 'icon' }: Props) => (
  <svg {...base} className={className}><circle cx="10.5" cy="10.5" r="6.5" /><path d="m20 20-4.5-4.5" /></svg>
)
export const Filter = ({ className = 'icon' }: Props) => (
  <svg {...base} className={className}><path d="M4 7h16M7 12h10M10 17h4" /></svg>
)
export const Gear = ({ className = 'icon' }: Props) => (
  <svg {...base} className={className}>
    <circle cx="12" cy="12" r="3" />
    <path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1Z" />
  </svg>
)
export const Locate = ({ className = 'icon' }: Props) => (
  <svg viewBox="0 0 24 24" className={className} fill="currentColor"><path d="M21 3 3 10.5l7.5 2.5L13 21z" /></svg>
)
export const ReportBubble = ({ className = 'icon' }: Props) => (
  <svg viewBox="0 0 24 24" className={className} fill="currentColor">
    <path d="M5 3h14a3 3 0 0 1 3 3v9a3 3 0 0 1-3 3h-7l-5 4v-4H5a3 3 0 0 1-3-3V6a3 3 0 0 1 3-3Zm6 3v6h2V6h-2Zm0 8v2h2v-2h-2Z" />
  </svg>
)
export const Close = ({ className = 'icon' }: Props) => (
  <svg {...base} className={className}><path d="M6 6l12 12M18 6 6 18" /></svg>
)
export const Check = ({ className = 'icon' }: Props) => (
  <svg {...base} className={className}><path d="m5 12.5 4.5 4.5L19 7" /></svg>
)
export const Clock = ({ className = 'icon' }: Props) => (
  <svg {...base} className={className}><circle cx="12" cy="12" r="9" /><path d="M12 7v5l3 2" /></svg>
)
export const Star = ({ className = 'icon', filled = false }: Props & { filled?: boolean }) => (
  <svg {...base} className={className} fill={filled ? 'currentColor' : 'none'}>
    <path d="m12 3 2.8 5.7 6.2.9-4.5 4.4 1.1 6.2L12 17.3l-5.6 2.9 1.1-6.2L3 9.6l6.2-.9Z" />
  </svg>
)
export const Warning = ({ className = 'icon' }: Props) => (
  <svg {...base} className={className}><path d="M12 3 2 20h20L12 3Z" /><path d="M12 10v4M12 17v.5" /></svg>
)
export const Bulb = ({ className = 'icon' }: Props) => (
  <svg {...base} className={className}><path d="M9 18h6M10 21h4M12 3a6 6 0 0 0-3.5 10.9c.7.5 1 1.2 1 2.1h5c0-.9.3-1.6 1-2.1A6 6 0 0 0 12 3Z" /></svg>
)
export const People = ({ className = 'icon' }: Props) => (
  <svg {...base} className={className}>
    <circle cx="12" cy="8" r="3" /><circle cx="5" cy="9" r="2.2" /><circle cx="19" cy="9" r="2.2" />
    <path d="M6.5 19a5.5 5.5 0 0 1 11 0M1.5 18a3.5 3.5 0 0 1 4.5-3.3M22.5 18a3.5 3.5 0 0 0-4.5-3.3" />
  </svg>
)
export const LocationArrow = ({ className = 'icon' }: Props) => (
  <svg {...base} className={className}><path d="M21 3 3 10.5l7.5 2.5L13 21z" /></svg>
)
export const Walk = ({ className = 'icon' }: Props) => (
  <svg viewBox="0 0 24 24" className={className} fill="currentColor">
    <circle cx="14" cy="4" r="2" />
    <path d="M10.5 8.5 7 10v4h2v-2.7l1.4-.6L9 17l-3 4h2.5l2.3-3 1.7 2v4h2v-5l-2-2.5.6-3c1 1.3 2.4 2.1 4.1 2.2v-2c-1.3-.1-2.4-.9-3-2l-1-1.6c-.4-.6-1-1-1.8-1-.3 0-.6.1-1 .2Z" />
    <path d="M2 9h3M1 12h3M2 15h3" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" />
  </svg>
)
export const Envelope = ({ className = 'icon' }: Props) => (
  <svg viewBox="0 0 24 24" className={className} fill="currentColor">
    <path d="m12 2 9 6v12a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8l9-6Zm0 11.5L5.2 9 12 4.4 18.8 9 12 13.5Z" />
  </svg>
)
export const Pin = ({ className = '' }: Props) => (
  <svg viewBox="0 0 36 48" className={className} width="36" height="48">
    <path d="M18 0C8 0 0 7.8 0 17.5 0 30.6 18 48 18 48s18-17.4 18-30.5C36 7.8 28 0 18 0Z" fill="#ff3b30" />
    <circle cx="18" cy="17" r="6.5" fill="#8b0000" />
  </svg>
)
