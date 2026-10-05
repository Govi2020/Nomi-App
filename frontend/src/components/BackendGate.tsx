import { useCallback, useEffect, useState, type ReactNode } from 'react'
import { isTauri } from '@tauri-apps/api/core'
import {
  initializeBackendRuntime,
  openBackendLogs,
  restartBackend,
  subscribeBackendEvents,
  type BackendInfo,
} from '../services/apiClient'

export function BackendGate({ children }: { children: ReactNode }) {
  const [info, setInfo] = useState<BackendInfo | null>(() => isTauri() ? null : { baseUrl: '', status: 'ready' })
  const [actionError, setActionError] = useState('')

  useEffect(() => {
    let active = true
    let unlisten: (() => void) | undefined
    void subscribeBackendEvents(next => { if (active) setInfo(next) })
      .then(stop => {
        if (active) unlisten = stop
        else stop()
      })
      .then(() => initializeBackendRuntime())
      .then(next => { if (active) setInfo(next) })
      .catch(error => {
        if (active) setInfo({ baseUrl: '', status: 'error', error: error instanceof Error ? error.message : String(error) })
      })
    return () => { active = false; unlisten?.() }
  }, [])

  const retry = useCallback(async () => {
    setActionError('')
    setInfo(current => ({ baseUrl: current?.baseUrl ?? '', status: 'starting' }))
    try {
      await restartBackend()
      const next = await initializeBackendRuntime()
      setInfo(next)
    } catch (error) {
      setInfo({ baseUrl: '', status: 'error', error: error instanceof Error ? error.message : String(error) })
    }
  }, [])

  if (!isTauri() || info?.status === 'ready') return children
  const failed = info?.status === 'error' || info?.status === 'crashed'

  return (
    <main className="backend-gate" aria-live="polite">
      <section className="backend-gate-card">
        <div className="backend-gate-mark" aria-hidden="true">N</div>
        <p className="backend-gate-eyebrow">NOMI DESKTOP</p>
        <h1>{failed ? 'Nomi could not start' : 'Starting Nomi…'}</h1>
        <p className="backend-gate-message">
          {failed ? info.error || 'The local service stopped before it became ready.' : 'Preparing your private local service.'}
        </p>
        {failed && <div className="backend-gate-actions">
          <button onClick={() => void retry()}>Retry</button>
          <button className="backend-gate-secondary" onClick={() => void openBackendLogs().catch(error => setActionError(String(error)))}>Open logs folder</button>
        </div>}
        {actionError && <p className="backend-gate-action-error">{actionError}</p>}
      </section>
    </main>
  )
}
