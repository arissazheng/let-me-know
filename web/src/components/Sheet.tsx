import type { ReactNode } from 'react'
import { Close } from './Icons'

/** iOS-style bottom sheet with a grabber, title, and glass close/confirm buttons. */
export function Sheet({
  title,
  onClose,
  confirm,
  half,
  children,
}: {
  title?: string
  onClose: () => void
  confirm?: ReactNode
  half?: boolean
  children: ReactNode
}) {
  return (
    <>
      <div className="sheet-backdrop" onClick={onClose} />
      <div className={`sheet${half ? ' half' : ''}`} role="dialog" aria-label={title}>
        <div className="grabber" />
        <div className="sheet-header">
          <button className="circle glass glass-interactive" style={{ width: 44, height: 44 }} onClick={onClose} aria-label="Close">
            <Close className="icon" />
          </button>
          <h2>{title}</h2>
          <div style={{ justifySelf: 'end' }}>{confirm}</div>
        </div>
        <div className="sheet-body">{children}</div>
      </div>
    </>
  )
}

export function Toggle({ on, onChange, label }: { on: boolean; onChange: (v: boolean) => void; label: string }) {
  return <button className={`toggle${on ? ' on' : ''}`} role="switch" aria-checked={on} aria-label={label} onClick={() => onChange(!on)} />
}
