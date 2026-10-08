import { useCallback, useEffect, useState } from 'react'
import { apiClient, openOllamaDownload } from '../services/apiClient'

type AiStatus = {
  ollama_reachable: boolean
  chat_model: string
  chat_model_installed: boolean
  embedding_model: string
  embedding_model_installed: boolean
  ready: boolean
}
type PullProgress = { status?: string; completed?: number; total?: number; error?: string }

export function AiReadinessCard() {
  const [status, setStatus] = useState<AiStatus | null>(null)
  const [checking, setChecking] = useState(true)
  const [pulling, setPulling] = useState(false)
  const [progress, setProgress] = useState('')
  const [error, setError] = useState('')

  const refresh = useCallback(async () => {
    setChecking(true)
    setError('')
    try { setStatus(await apiClient.get<AiStatus>('/api/ai/status')) }
    catch (reason) { setError(reason instanceof Error ? reason.message : 'Could not check the local AI service.') }
    finally { setChecking(false) }
  }, [])

  useEffect(() => { void refresh() }, [refresh])

  const pull = async (model: 'chat' | 'embedding', name: string) => {
    const response = await apiClient.request('/api/ai/models/pull', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ model }),
    })
    if (!response.body) throw new Error('The model download did not provide progress.')
    const reader = response.body.getReader()
    const decoder = new TextDecoder()
    let buffer = ''
    while (true) {
      const { value, done } = await reader.read()
      buffer += decoder.decode(value ?? new Uint8Array(), { stream: !done })
      const lines = buffer.split('\n')
      buffer = lines.pop() ?? ''
      for (const line of lines) {
        if (!line.trim()) continue
        const item = JSON.parse(line) as PullProgress
        if (item.error) throw new Error(item.error)
        if (item.status) {
          const percent = item.total && item.completed !== undefined ? ` (${Math.floor(item.completed * 100 / item.total)}%)` : ''
          setProgress(`${name}: ${item.status}${percent}`)
        }
      }
      if (done) break
    }
  }

  const installModels = async () => {
    if (!status || !status.ollama_reachable || pulling) return
    setPulling(true)
    setError('')
    try {
      if (!status.chat_model_installed) await pull('chat', status.chat_model)
      if (!status.embedding_model_installed) await pull('embedding', status.embedding_model)
      await refresh()
      setProgress('')
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'Model download failed.')
    } finally {
      setPulling(false)
    }
  }

  if (!checking && !error && status?.ready) return <section className="ai-setup-card ai-setup-ready" aria-live="polite">
    <div className="ai-setup-copy"><span className="ai-setup-kicker">LOCAL AI READY</span><p>{status.chat_model} and {status.embedding_model} are available on this device.</p></div>
    <div className="ai-setup-actions"><button type="button" className="ai-setup-secondary" onClick={() => void refresh()}>Check again</button></div>
  </section>
  if (checking && !status) return <section className="ai-setup-card" aria-live="polite"><span className="ai-setup-kicker">LOCAL AI</span><p>Checking Ollama availability…</p></section>

  const ollamaMissing = !status?.ollama_reachable
  const missingModels = Boolean(status?.ollama_reachable && (!status.chat_model_installed || !status.embedding_model_installed))
  return <section className="ai-setup-card" aria-live="polite">
    <div className="ai-setup-copy">
      <span className="ai-setup-kicker">LOCAL AI</span>
      <h2>{ollamaMissing ? 'AI features need Ollama' : missingModels ? 'Download the models for AI features' : 'Could not check AI readiness'}</h2>
      <p>{ollamaMissing
        ? 'AI features are unavailable right now, but your journal still works. Install Ollama, then check again.'
        : missingModels
          ? `Nomi uses ${status?.chat_model} for chat and ${status?.embedding_model} for search. Downloads stay on your device.`
          : error || 'The local AI service could not be checked.'}</p>
      {progress && <p className="ai-setup-progress" role="status">{progress}</p>}
      {error && !ollamaMissing && <p className="ai-setup-error" role="alert">{error}</p>}
    </div>
    <div className="ai-setup-actions">
      {ollamaMissing && <button type="button" className="ai-setup-secondary" onClick={() => void openOllamaDownload().catch(reason => setError(String(reason)))}>Install Ollama</button>}
      {missingModels && <button type="button" disabled={pulling} onClick={() => void installModels()}>{pulling ? 'Downloading…' : 'Download required models'}</button>}
      <button type="button" className="ai-setup-secondary" disabled={checking || pulling} onClick={() => void refresh()}>{checking ? 'Checking…' : 'Check again'}</button>
    </div>
  </section>
}
