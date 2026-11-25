import { useEffect, useRef, useState, type ReactNode } from 'react'
import { reportMedia, type MediaItem, type Report } from '../lib/data'
import { Clock, Close, ReportBubble } from './Icons'

/** UCPD's emergency line from a cell phone (ucpd.berkeley.edu). */
export const UCPD_PHONE = '5106423333'

type FabAction = 'report' | 'ucpd' | '911'

/**
 * Large + button in the map's bottom corner. Press and hold to reveal Report, UCPD, and 911,
 * then slide onto one and let go to choose it. A quick tap opens the same options to tap.
 */
export function ActionFab({ onAction }: { onAction: (action: FabAction) => void }) {
  const [open, setOpen] = useState(false)
  const [hovered, setHovered] = useState<FabAction | null>(null)
  const holdTimer = useRef<number | undefined>(undefined)
  const held = useRef(false)
  const refs = { report: useRef<HTMLButtonElement>(null), ucpd: useRef<HTMLButtonElement>(null), '911': useRef<HTMLButtonElement>(null) }

  const actionAt = (x: number, y: number): FabAction | null => {
    for (const action of ['report', 'ucpd', '911'] as const) {
      const r = refs[action].current?.getBoundingClientRect()
      if (r && x >= r.left - 8 && x <= r.right + 8 && y >= r.top - 8 && y <= r.bottom + 8) return action
    }
    return null
  }

  const choose = (action: FabAction) => {
    setOpen(false)
    setHovered(null)
    onAction(action)
  }

  return (
    <div className="fab-area">
      {open && <div className="fab-dismiss" onClick={() => setOpen(false)} />}
      <div className={`fab-options${open ? ' open' : ''}`}>
        <FabOption ref={refs['911']} action="911" label="911" hovered={hovered} onChoose={choose}>
          <svg viewBox="0 0 24 24" className="icon" fill="currentColor"><path d="M6.6 10.8a15.1 15.1 0 0 0 6.6 6.6l2.2-2.2a1 1 0 0 1 1-.25 11.4 11.4 0 0 0 3.6.57 1 1 0 0 1 1 1V20a1 1 0 0 1-1 1A17 17 0 0 1 3 4a1 1 0 0 1 1-1h3.5a1 1 0 0 1 1 1c0 1.25.2 2.45.57 3.6a1 1 0 0 1-.25 1Z" /></svg>
        </FabOption>
        <FabOption ref={refs.ucpd} action="ucpd" label="UCPD" hovered={hovered} onChoose={choose}>
          <svg viewBox="0 0 24 24" className="icon" fill="currentColor"><path d="M12 2 4 5v6c0 5 3.4 9.6 8 11 4.6-1.4 8-6 8-11V5l-8-3Zm0 5.5a2.5 2.5 0 1 1 0 5 2.5 2.5 0 0 1 0-5Zm0 12.2a8.3 8.3 0 0 1-4.6-4.1c.6-1.4 2.6-2.1 4.6-2.1s4 .7 4.6 2.1a8.3 8.3 0 0 1-4.6 4.1Z" /></svg>
        </FabOption>
        <FabOption ref={refs.report} action="report" label="Report" hovered={hovered} onChoose={choose}>
          <ReportBubble />
        </FabOption>
      </div>
      <button
        className={`fab glass${open ? ' open' : ''}`}
        aria-label="Report or call for help"
        aria-expanded={open}
        onPointerDown={(e) => {
          e.currentTarget.setPointerCapture(e.pointerId)
          held.current = false
          holdTimer.current = window.setTimeout(() => {
            held.current = true
            setOpen(true)
            navigator.vibrate?.(10)
          }, 250)
        }}
        onPointerMove={(e) => {
          if (held.current) setHovered(actionAt(e.clientX, e.clientY))
        }}
        onPointerUp={(e) => {
          window.clearTimeout(holdTimer.current)
          if (held.current) {
            const action = actionAt(e.clientX, e.clientY)
            if (action) choose(action)
            else setHovered(null)
          } else {
            setOpen((o) => !o)
          }
        }}
        onPointerCancel={() => {
          window.clearTimeout(holdTimer.current)
          setHovered(null)
        }}
        onContextMenu={(e) => e.preventDefault()}
      >
        <svg viewBox="0 0 24 24" width="30" height="30" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round">
          <path d="M12 5v14M5 12h14" />
        </svg>
      </button>
    </div>
  )
}

function FabOption({
  ref,
  action,
  label,
  hovered,
  onChoose,
  children,
}: {
  ref: React.RefObject<HTMLButtonElement | null>
  action: FabAction
  label: string
  hovered: FabAction | null
  onChoose: (a: FabAction) => void
  children: ReactNode
}) {
  return (
    // CSS class names can't start with a digit, so 911 is styled as "call911".
    <button
      ref={ref}
      className={`fab-option ${action === '911' ? 'call911' : action}${hovered === action ? ' hovered' : ''}`}
      onClick={() => onChoose(action)}
    >
      <span className="fab-option-icon glass">{children}</span>
      <span className="fab-option-label">{label}</span>
    </button>
  )
}

/** Liquid glass card over a faded map; tapping anywhere outside the card closes it. */
export function GlassModal({ onClose, children }: { onClose: () => void; children: ReactNode }) {
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && onClose()
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [onClose])
  return (
    <div className="glass-modal-backdrop" onClick={onClose}>
      <div className="glass-modal glass" role="dialog" onClick={(e) => e.stopPropagation()}>
        <button className="glass-modal-close circle glass glass-interactive" onClick={onClose} aria-label="Close">
          <Close />
        </button>
        {children}
      </div>
    </div>
  )
}

/** F4: optional title, a description, and any number of photos/videos. */
export function ReportForm({
  onSubmit,
  onClose,
}: {
  onSubmit: (report: { title: string; description: string; files: File[] }) => Promise<void>
  onClose: () => void
}) {
  const [title, setTitle] = useState('')
  const [description, setDescription] = useState('')
  const [files, setFiles] = useState<File[]>([])
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const input = useRef<HTMLInputElement>(null)
  const previews = useObjectUrls(files)

  async function submit() {
    setBusy(true)
    setError(null)
    try {
      await onSubmit({ title: title.trim(), description: description.trim(), files })
      onClose()
    } catch (e) {
      setError(`Couldn't submit: ${(e as Error).message}`)
    } finally {
      setBusy(false)
    }
  }

  return (
    <GlassModal onClose={onClose}>
      <input className="report-title-input" placeholder="Title" value={title} maxLength={120} onChange={(e) => setTitle(e.target.value)} />
      <label className="field-label">
        Description <span className="required" aria-label="required">*</span>
      </label>
      <textarea className="text-input glass-field" rows={5} placeholder="What happened?" value={description} onChange={(e) => setDescription(e.target.value)} />
      {files.length > 0 && (
        <div className="upload-grid">
          {files.map((file, i) => (
            <div key={previews[i]} className="upload-tile">
              {file.type.startsWith('video') ? <video src={previews[i]} muted playsInline /> : <img src={previews[i]} alt="" />}
              <button className="upload-remove" aria-label="Remove" onClick={() => setFiles((f) => f.filter((_, j) => j !== i))}>
                <Close className="icon" />
              </button>
            </div>
          ))}
        </div>
      )}
      <button className="upload-box" onClick={() => input.current?.click()}>
        <svg viewBox="0 0 24 24" width="26" height="26" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <path d="M12 15V3M7 8l5-5 5 5M5 13v6a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-6" />
        </svg>
        <strong>{files.length ? 'Add more' : 'Upload'}</strong>
        <small>.JPG, .PNG, .MOV</small>
      </button>
      <input
        ref={input}
        type="file"
        accept="image/jpeg,image/png,image/heic,video/quicktime,video/mp4"
        multiple
        hidden
        onChange={(e) => {
          const picked = [...(e.target.files ?? [])]
          setFiles((f) => [...f, ...picked])
          e.target.value = ''
        }}
      />
      {error && <div className="group-footer destructive">{error}</div>}
      <div className="modal-actions">
        <button className="btn-prominent" disabled={!description.trim() || busy} onClick={submit}>
          {busy ? 'Submitting…' : 'Confirm'}
        </button>
      </div>
    </GlassModal>
  )
}

/** F3: a report's title, place, description, and a media library (large view + thumbnails). */
export function ReportView({ report, onClose }: { report: Report; onClose: () => void }) {
  const media = reportMedia(report)
  const [index, setIndex] = useState(0)
  const current: MediaItem | undefined = media[index]
  return (
    <GlassModal onClose={onClose}>
      <h2 className="report-title">{report.title || 'Incident report'}</h2>
      <div className="report-meta">
        {report.place_name && (
          <span>
            <svg viewBox="0 0 24 24" width="14" height="14" fill="currentColor"><path d="M12 2a7 7 0 0 0-7 7c0 5.2 7 13 7 13s7-7.8 7-13a7 7 0 0 0-7-7Zm0 9.5A2.5 2.5 0 1 1 12 6.5a2.5 2.5 0 0 1 0 5Z" /></svg>
            {report.place_name}
          </span>
        )}
        <span>
          <Clock className="icon-sm" /> {timeAgo(report.created_at)}
        </span>
        {report.is_demo && <span className="badge">Demo</span>}
      </div>
      <p className="report-description glass-field">{report.description}</p>
      {current && (
        <div className="media-library">
          <div className="media-main">
            {current.type === 'video' ? (
              <video key={current.url} src={current.url} controls playsInline />
            ) : (
              <img src={current.url} alt={`Attachment ${index + 1}`} />
            )}
          </div>
          {media.length > 1 && (
            <div className="media-thumbs">
              {media.map((item, i) => (
                <button key={item.url} className={`media-thumb${i === index ? ' selected' : ''}`} onClick={() => setIndex(i)} aria-label={`Show attachment ${i + 1}`}>
                  {item.type === 'video' ? <video src={item.url} muted playsInline preload="metadata" /> : <img src={item.url} alt="" />}
                </button>
              ))}
            </div>
          )}
        </div>
      )}
    </GlassModal>
  )
}

function timeAgo(iso: string) {
  const minutes = Math.round((Date.now() - new Date(iso).getTime()) / 60000)
  const rtf = new Intl.RelativeTimeFormat('en', { numeric: 'auto' })
  if (minutes < 60) return rtf.format(-minutes, 'minute')
  return rtf.format(-Math.round(minutes / 60), 'hour')
}

/** Local preview URLs for picked files, revoked when they change. */
function useObjectUrls(files: File[]) {
  const [urls, setUrls] = useState<string[]>([])
  useEffect(() => {
    const next = files.map((f) => URL.createObjectURL(f))
    setUrls(next)
    return () => next.forEach((u) => URL.revokeObjectURL(u))
  }, [files])
  return urls
}
