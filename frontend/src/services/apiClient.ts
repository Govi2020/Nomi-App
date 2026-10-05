import { invoke, isTauri } from '@tauri-apps/api/core'
import { listen, type UnlistenFn } from '@tauri-apps/api/event'

export type BackendStatus = 'starting' | 'ready' | 'error' | 'crashed' | 'stopped'
export interface BackendInfo {
  baseUrl: string
  status: BackendStatus
  error?: string
  logPath?: string
}

type BackendEvent = { message?: string; error?: string; logPath?: string }
type BackendState = { baseUrl: string; token?: string }

const browserBaseUrl = import.meta.env.VITE_API_BASE_URL ?? ''
const state: BackendState = { baseUrl: browserBaseUrl }

export const resolveApiUrl = (path: string) => `${state.baseUrl}${path}`

export async function getBackendInfo(): Promise<BackendInfo> {
  if (!isTauri()) return { baseUrl: browserBaseUrl, status: 'ready' }
  return invoke<BackendInfo>('get_backend_info')
}

export async function initializeBackendRuntime(): Promise<BackendInfo> {
  if (!isTauri()) {
    state.baseUrl = browserBaseUrl
    return { baseUrl: browserBaseUrl, status: 'ready' }
  }
  const info = await getBackendInfo()
  if (info.status === 'ready') state.baseUrl = info.baseUrl
  return info
}

export async function subscribeBackendEvents(onChange: (info: BackendInfo) => void): Promise<UnlistenFn> {
  if (!isTauri()) return () => undefined
  const unlisteners = await Promise.all([
    listen<BackendEvent>('backend://starting', () => onChange({ baseUrl: state.baseUrl, status: 'starting' })),
    listen<BackendEvent>('backend://ready', event => {
      void getBackendInfo().then(info => {
        state.baseUrl = info.baseUrl
        onChange({ ...info, status: 'ready' })
      }).catch(error => onChange({ baseUrl: state.baseUrl, status: 'error', error: errorMessage(error) }))
    }),
    listen<BackendEvent>('backend://error', event => onChange({
      baseUrl: state.baseUrl,
      status: 'error',
      error: event.payload.error ?? event.payload.message ?? 'The backend could not start.',
      logPath: event.payload.logPath,
    })),
    listen<BackendEvent>('backend://crashed', event => onChange({
      baseUrl: state.baseUrl,
      status: 'crashed',
      error: event.payload.error ?? event.payload.message ?? 'The backend stopped unexpectedly.',
      logPath: event.payload.logPath,
    })),
  ])
  return () => unlisteners.forEach(unlisten => unlisten())
}

export async function restartBackend(): Promise<void> {
  if (isTauri()) await invoke('restart_backend')
}

export async function openBackendLogs(): Promise<void> {
  if (isTauri()) await invoke('open_logs_folder')
}

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error)
}

async function checked(response: Response): Promise<Response> {
  if (response.ok) return response
  let message = `Request failed (${response.status})`
  try {
    const error = await response.json() as { detail?: string }
    if (error.detail) message = error.detail
  } catch {
    // Preserve the HTTP status when the backend does not return JSON.
  }
  throw new Error(message)
}

export const apiClient = {
  async request(path: string, init?: RequestInit): Promise<Response> {
    const headers = new Headers(init?.headers)
    if (state.token) headers.set('Authorization', `Bearer ${state.token}`)
    return checked(await fetch(resolveApiUrl(path), { ...init, headers }))
  },
  async get<T>(path: string, signal?: AbortSignal): Promise<T> {
    return (await apiClient.request(path, { signal })).json() as Promise<T>
  },
  async post<T>(path: string, body: unknown): Promise<T> {
    return (await apiClient.request(path, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) })).json() as Promise<T>
  },
  async upload<T>(path: string, file: File): Promise<T> {
    const body = new FormData()
    body.append('file', file)
    return (await apiClient.request(path, { method: 'POST', body })).json() as Promise<T>
  },
  async put<T>(path: string, body: unknown): Promise<T> {
    return (await apiClient.request(path, { method: 'PUT', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) })).json() as Promise<T>
  },
  async delete<T>(path: string): Promise<T> {
    return (await apiClient.request(path, { method: 'DELETE' })).json() as Promise<T>
  },
}
