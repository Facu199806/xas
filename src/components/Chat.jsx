import { useEffect, useMemo, useRef, useState } from 'react'
import ConversationSidebar from './ConversationSidebar'
import {
  STARTER_MESSAGE,
  createConversation,
  deriveConversationTitle,
  loadConversationState,
  saveConversationState,
} from '../lib/conversationStore'

const ACCESS_KEY = 'xas-cloud-access-token'
const LOCAL_HOSTS = new Set(['localhost', '127.0.0.1'])
const IS_LOCAL_HOST = LOCAL_HOSTS.has(window.location.hostname)
const AI_MODE = import.meta.env.VITE_AI_MODE || (IS_LOCAL_HOST ? 'local' : 'cloud')
const IS_CLOUD = AI_MODE === 'cloud'
const API_URL = IS_CLOUD
  ? (import.meta.env.VITE_CLOUD_API_URL || '/api/chat')
  : (import.meta.env.VITE_AI_API_URL || '/api/v1/chat/completions')
const MODELS_URL = import.meta.env.VITE_AI_MODELS_URL || '/api/v1/models'
const LOCAL_MODEL = import.meta.env.VITE_AI_MODEL || 'qwen3:4b'
const CLOUD_MODEL = import.meta.env.VITE_CLOUD_MODEL_LABEL || 'gpt-5.4-mini'
const MODEL = IS_CLOUD ? CLOUD_MODEL : LOCAL_MODEL
const DEFAULT_REASONING_EFFORT = import.meta.env.VITE_AI_REASONING_EFFORT || 'medium'
const TEMPERATURE = Number(import.meta.env.VITE_AI_TEMPERATURE ?? 0.2)
const MAX_TOKENS = Number(import.meta.env.VITE_AI_MAX_TOKENS ?? 1024)
const REQUEST_TIMEOUT_MS = Number(import.meta.env.VITE_AI_TIMEOUT_MS ?? 120000)
const MAX_CONTEXT_MESSAGES = 18

const SYSTEM_PROMPT = `Tu nombre es XAS. Sos un asistente especializado en soporte técnico, análisis de incidentes, Oracle EBS, Siebel, SQL, PL/SQL y Windows.

Antes de responder, separá hechos comprobables, hipótesis y datos faltantes. No inventes tablas, permisos, resultados, causas ni accesos. Cuando recibas un error o log, explicá qué indica, cuál es la causa más probable, cómo validarla y cuál es el siguiente paso seguro. Priorizá consultas de diagnóstico y evitá proponer UPDATE, DELETE o INSERT en producción salvo pedido explícito, aclarando siempre el riesgo. Respondé en español rioplatense claro, con pasos concretos y verificables. Mostrá conclusiones útiles, no una cadena de pensamiento privada.`

const SIMPLE_MESSAGE_PATTERN = /^(hola|buenas|buen día|buen dia|buenas tardes|buenas noches|qué tal|que tal|gracias|ok|dale|probando|test)[\s!¡?¿.,]*$/i
const TECHNICAL_MESSAGE_PATTERN = /(ora-\d+|sql|pl\/sql|siebel|oracle|ebs|error|log|stack|trace|query|consulta|select\b|join\b|package|procedure|función|funcion|ticket|incidente|windows|servidor|api|http|json|javascript|react|vite|analiz|diagn[oó]st)/i

const QUICK_PROMPTS = [
  'Analizá un ORA-01722 y sugerí validaciones seguras.',
  'Ayudame a redactar una derivación clara para un ticket.',
  'Revisá esta consulta SQL y marcá posibles problemas de rendimiento.',
]

function conversationMessages(messages) {
  return messages
    .filter((message) => message.content !== STARTER_MESSAGE.content)
    .slice(-MAX_CONTEXT_MESSAGES)
    .map(({ role, content }) => ({ role, content }))
}

function buildApiMessages(messages) {
  const conversation = conversationMessages(messages)
  return IS_CLOUD ? conversation : [{ role: 'system', content: SYSTEM_PROMPT }, ...conversation]
}

function chooseReasoningEffort(text) {
  const normalized = text.trim()
  if (SIMPLE_MESSAGE_PATTERN.test(normalized)) return 'none'
  if (TECHNICAL_MESSAGE_PATTERN.test(normalized)) return DEFAULT_REASONING_EFFORT
  if (normalized.length < 80) return 'low'
  return DEFAULT_REASONING_EFFORT
}

function reasoningLabel(effort) {
  if (effort === 'none') return 'respuesta rápida'
  if (effort === 'minimal') return 'razonamiento mínimo'
  if (effort === 'low') return 'razonamiento breve'
  if (effort === 'high') return 'razonamiento profundo'
  return 'razonamiento técnico'
}

function connectionClasses(status) {
  if (status === 'online') return 'border-emerald-200 bg-emerald-50 text-emerald-700 dark:border-emerald-900 dark:bg-emerald-950/40 dark:text-emerald-300'
  if (status === 'missing') return 'border-amber-200 bg-amber-50 text-amber-700 dark:border-amber-900 dark:bg-amber-950/40 dark:text-amber-300'
  if (status === 'offline') return 'border-red-200 bg-red-50 text-red-700 dark:border-red-900 dark:bg-red-950/40 dark:text-red-300'
  return 'border-slate-200 bg-slate-50 text-slate-600 dark:border-slate-700 dark:bg-slate-800 dark:text-slate-300'
}

export default function Chat() {
  const [conversationState, setConversationState] = useState(loadConversationState)
  const [input, setInput] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [activeEffort, setActiveEffort] = useState('none')
  const [elapsedSeconds, setElapsedSeconds] = useState(0)
  const [showSecurity, setShowSecurity] = useState(false)
  const [accessToken, setAccessToken] = useState(() => localStorage.getItem(ACCESS_KEY) || '')
  const [connection, setConnection] = useState({ status: 'checking', message: 'Comprobando conexión...' })
  const bottomRef = useRef(null)
  const abortControllerRef = useRef(null)

  const activeConversation = useMemo(
    () => conversationState.conversations.find((conversation) => conversation.id === conversationState.activeId)
      || conversationState.conversations[0],
    [conversationState],
  )
  const messages = activeConversation?.messages || [{ ...STARTER_MESSAGE }]
  const hasUserMessages = messages.some((message) => message.role === 'user')
  const canSend = useMemo(
    () => input.trim().length > 0 && !loading && connection.status === 'online',
    [input, loading, connection.status],
  )

  function updateConversation(conversationId, updater) {
    setConversationState((current) => ({
      ...current,
      conversations: current.conversations.map((conversation) => (
        conversation.id === conversationId ? updater(conversation) : conversation
      )),
    }))
  }

  function stopCurrentRequest(reason = 'navigation') {
    abortControllerRef.current?.abort(reason)
  }

  async function refreshConnection() {
    setConnection({ status: 'checking', message: 'Comprobando conexión...' })

    try {
      if (IS_CLOUD) {
        const response = await fetch(API_URL, { headers: { Accept: 'application/json' } })
        const rawText = await response.text()
        const data = rawText ? JSON.parse(rawText) : {}

        if (!response.ok || data?.ok !== true) {
          const message = data?.message || data?.error?.message || `Gateway no disponible (HTTP ${response.status}).`
          setConnection({ status: 'missing', message: 'Gateway sin configurar' })
          setError(message)
          return false
        }

        setError('')
        setConnection({ status: 'online', message: 'Nube conectada' })
        return true
      }

      const response = await fetch(MODELS_URL)
      const rawText = await response.text()
      const data = rawText ? JSON.parse(rawText) : {}
      if (!response.ok) throw new Error(`HTTP ${response.status}`)

      const availableModels = Array.isArray(data?.data) ? data.data.map((item) => item.id) : []
      const modelInstalled = availableModels.includes(LOCAL_MODEL)
      setConnection(
        modelInstalled
          ? { status: 'online', message: 'Ollama conectado' }
          : { status: 'missing', message: `Falta descargar ${LOCAL_MODEL}` },
      )
      return modelInstalled
    } catch (connectionError) {
      const message = connectionError instanceof Error ? connectionError.message : 'No se pudo comprobar la conexión.'
      setConnection({
        status: 'offline',
        message: IS_CLOUD ? 'Backend desconectado' : 'Ollama desconectado',
      })
      if (IS_CLOUD) setError(message)
      return false
    }
  }

  useEffect(() => {
    refreshConnection()
  }, [])

  useEffect(() => {
    saveConversationState(conversationState)
  }, [conversationState])

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [conversationState.activeId, activeConversation?.updatedAt, loading])

  useEffect(() => {
    localStorage.setItem(ACCESS_KEY, accessToken)
  }, [accessToken])

  useEffect(() => {
    if (!loading) {
      setElapsedSeconds(0)
      return undefined
    }

    const startedAt = Date.now()
    const timer = window.setInterval(() => {
      setElapsedSeconds(Math.floor((Date.now() - startedAt) / 1000))
    }, 1000)

    return () => window.clearInterval(timer)
  }, [loading])

  function createNewConversation() {
    stopCurrentRequest()
    const conversation = createConversation()
    setConversationState((current) => ({
      ...current,
      activeId: conversation.id,
      conversations: [conversation, ...current.conversations],
    }))
    setInput('')
    setError('')
  }

  function selectConversation(conversationId) {
    if (conversationId === conversationState.activeId) return
    stopCurrentRequest()
    setConversationState((current) => ({ ...current, activeId: conversationId }))
    setInput('')
    setError('')
  }

  function renameConversation(conversationId) {
    const conversation = conversationState.conversations.find((item) => item.id === conversationId)
    if (!conversation) return

    const nextTitle = window.prompt('Nombre de la conversación:', conversation.title)?.trim()
    if (!nextTitle) return

    updateConversation(conversationId, (current) => ({
      ...current,
      title: nextTitle.slice(0, 80),
      updatedAt: Date.now(),
    }))
  }

  function deleteConversation(conversationId) {
    const conversation = conversationState.conversations.find((item) => item.id === conversationId)
    if (!conversation || !window.confirm(`¿Eliminar “${conversation.title}”?`)) return

    stopCurrentRequest()
    setConversationState((current) => {
      const remaining = current.conversations.filter((item) => item.id !== conversationId)
      if (!remaining.length) {
        const replacement = createConversation()
        return { ...current, activeId: replacement.id, conversations: [replacement] }
      }

      return {
        ...current,
        activeId: current.activeId === conversationId ? remaining[0].id : current.activeId,
        conversations: remaining,
      }
    })
    setInput('')
    setError('')
  }

  function clearCurrentConversation() {
    if (!activeConversation || !hasUserMessages) return
    if (!window.confirm('¿Vaciar los mensajes de esta conversación?')) return

    stopCurrentRequest()
    updateConversation(activeConversation.id, (conversation) => ({
      ...conversation,
      title: 'Nueva consulta',
      messages: [{ ...STARTER_MESSAGE }],
      updatedAt: Date.now(),
    }))
    setInput('')
    setError('')
  }

  async function handleSend(event) {
    event?.preventDefault()
    const text = input.trim()
    if (!text || loading || !activeConversation || connection.status !== 'online') return

    const conversationId = activeConversation.id
    const effort = chooseReasoningEffort(text)
    const nextMessages = [...activeConversation.messages, { role: 'user', content: text }]
    const controller = new AbortController()
    const timeoutId = window.setTimeout(() => controller.abort('timeout'), REQUEST_TIMEOUT_MS)
    const firstUserMessage = !activeConversation.messages.some((message) => message.role === 'user')

    abortControllerRef.current = controller
    updateConversation(conversationId, (conversation) => ({
      ...conversation,
      title: firstUserMessage ? deriveConversationTitle(text) : conversation.title,
      messages: nextMessages,
      updatedAt: Date.now(),
    }))
    setInput('')
    setError('')
    setActiveEffort(effort)
    setLoading(true)

    try {
      const headers = { 'Content-Type': 'application/json' }
      if (IS_CLOUD && accessToken.trim()) headers.Authorization = `Bearer ${accessToken.trim()}`

      const body = {
        messages: buildApiMessages(nextMessages),
        reasoning_effort: effort,
      }

      if (!IS_CLOUD) {
        body.model = LOCAL_MODEL
        body.stream = false
        body.temperature = Number.isFinite(TEMPERATURE) ? TEMPERATURE : 0.2
        body.max_tokens = Number.isFinite(MAX_TOKENS) ? MAX_TOKENS : 1024
      }

      const response = await fetch(API_URL, {
        method: 'POST',
        headers,
        signal: controller.signal,
        body: JSON.stringify(body),
      })

      const rawText = await response.text()
      let data
      try {
        data = rawText ? JSON.parse(rawText) : {}
      } catch {
        throw new Error(`La API respondió algo que no es JSON (${response.status}).`)
      }

      if (!response.ok) {
        const apiMessage =
          (typeof data?.error === 'string' && data.error)
          || data?.error?.message
          || data?.message
          || `Error HTTP ${response.status}`
        throw new Error(apiMessage)
      }

      const content = data?.choices?.[0]?.message?.content?.trim()
      if (!content) throw new Error('La IA respondió sin contenido.')

      updateConversation(conversationId, (conversation) => ({
        ...conversation,
        messages: [...conversation.messages, { role: 'assistant', content }],
        updatedAt: Date.now(),
      }))
      setConnection({
        status: 'online',
        message: IS_CLOUD ? 'Nube conectada' : 'Ollama conectado',
      })
    } catch (requestError) {
      const requestMessage = requestError instanceof Error ? requestError.message : 'No se pudo contactar con la IA.'
      const aborted = controller.signal.aborted
      const timedOut = aborted && controller.signal.reason === 'timeout'
      const manuallyCancelled = aborted && controller.signal.reason === 'manual'
      const navigationCancelled = aborted && controller.signal.reason === 'navigation'
      const networkFailure = /failed to fetch|network|econnrefused|no se pudo conectar/i.test(requestMessage)
      const gatewayFailure = /AI Gateway|plan basado en créditos|AI Features|OPENAI_API_KEY|OPENAI_BASE_URL/i.test(requestMessage)

      if (timedOut) {
        setError(`La respuesta superó ${Math.round(REQUEST_TIMEOUT_MS / 1000)} segundos. Probá nuevamente con una consulta más corta.`)
      } else if (manuallyCancelled) {
        setError('Solicitud cancelada.')
      } else if (navigationCancelled) {
        setError('')
      } else if (networkFailure) {
        setError(IS_CLOUD ? 'No se pudo contactar con el backend de Netlify.' : `Ollama no está disponible. Ejecutá: ollama run ${LOCAL_MODEL}`)
        setConnection({ status: 'offline', message: IS_CLOUD ? 'Backend desconectado' : 'Ollama desconectado' })
      } else if (IS_CLOUD && gatewayFailure) {
        setError(requestMessage)
        setConnection({ status: 'missing', message: 'Gateway sin configurar' })
      } else {
        setError(requestMessage)
      }
    } finally {
      window.clearTimeout(timeoutId)
      if (abortControllerRef.current === controller) abortControllerRef.current = null
      setLoading(false)
    }
  }

  function cancelRequest() {
    abortControllerRef.current?.abort('manual')
  }

  return (
    <div className="grid min-h-0 flex-1 gap-4 lg:grid-cols-[300px_minmax(0,1fr)] lg:gap-6">
      <ConversationSidebar
        conversations={conversationState.conversations}
        activeId={conversationState.activeId}
        onSelect={selectConversation}
        onNew={createNewConversation}
        onRename={renameConversation}
        onDelete={deleteConversation}
      />

      <section className="flex min-h-[72vh] min-w-0 flex-col overflow-hidden rounded-3xl border border-slate-200 bg-white shadow-sm transition-colors duration-300 dark:border-slate-800 dark:bg-slate-900 lg:min-h-[calc(100vh-13rem)]">
        <div className="border-b border-slate-200 px-4 py-4 dark:border-slate-800 sm:px-5">
          <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
            <div className="min-w-0">
              <h2 className="truncate text-base font-bold sm:text-lg">{activeConversation?.title || 'Nueva consulta'}</h2>
              <p className="mt-1 text-xs text-slate-500 dark:text-slate-400">
                {IS_CLOUD ? 'Modo nube' : 'Modo local'} · {MODEL} · razonamiento adaptativo
              </p>
            </div>

            <div className="flex flex-wrap items-center gap-2">
              <button
                type="button"
                onClick={refreshConnection}
                className={`rounded-xl border px-3 py-2 text-xs font-semibold transition ${connectionClasses(connection.status)}`}
              >
                {connection.message}
              </button>
              {IS_CLOUD && (
                <button
                  type="button"
                  onClick={() => setShowSecurity((value) => !value)}
                  className="rounded-xl border border-slate-300 px-3 py-2 text-xs font-semibold transition hover:bg-slate-100 dark:border-slate-700 dark:hover:bg-slate-800"
                >
                  Seguridad
                </button>
              )}
              <button
                type="button"
                onClick={clearCurrentConversation}
                disabled={!hasUserMessages}
                className="rounded-xl border border-slate-300 px-3 py-2 text-xs font-semibold transition hover:bg-slate-100 disabled:cursor-not-allowed disabled:opacity-40 dark:border-slate-700 dark:hover:bg-slate-800"
              >
                Vaciar chat
              </button>
            </div>
          </div>

          {IS_CLOUD && showSecurity && (
            <div className="mt-4 rounded-2xl border border-slate-200 bg-slate-50 p-3 dark:border-slate-800 dark:bg-slate-950/60">
              <label className="block text-xs font-semibold text-slate-600 dark:text-slate-300">
                Código de acceso del sitio
                <input
                  type="password"
                  value={accessToken}
                  onChange={(event) => setAccessToken(event.target.value)}
                  placeholder="Sólo se usa si XAS_ACCESS_TOKEN está configurado"
                  autoComplete="current-password"
                  className="mt-2 w-full rounded-xl border border-slate-300 bg-white px-3 py-2 text-sm font-normal outline-none focus:border-cyan-500 dark:border-slate-700 dark:bg-slate-950"
                />
              </label>
              <p className="mt-2 text-xs text-slate-500 dark:text-slate-400">
                Se guarda únicamente en este navegador y nunca se agrega al repositorio.
              </p>
            </div>
          )}
        </div>

        <div className="flex-1 space-y-4 overflow-y-auto p-4 sm:p-5">
          {messages.map((message, index) => {
            const fromUser = message.role === 'user'
            return (
              <article key={`${message.role}-${index}`} className={`flex ${fromUser ? 'justify-end' : 'justify-start'}`}>
                <div
                  className={`max-w-[92%] whitespace-pre-wrap rounded-2xl px-4 py-3 text-sm leading-6 shadow-sm sm:max-w-[82%] ${
                    fromUser
                      ? 'rounded-br-md bg-cyan-600 text-white'
                      : 'rounded-bl-md bg-slate-100 text-slate-800 dark:bg-slate-800 dark:text-slate-100'
                  }`}
                >
                  {message.content}
                </div>
              </article>
            )
          })}

          {!hasUserMessages && !error && (
            <div className="grid gap-2 pt-2 sm:grid-cols-3">
              {QUICK_PROMPTS.map((prompt) => (
                <button
                  key={prompt}
                  type="button"
                  onClick={() => setInput(prompt)}
                  className="rounded-2xl border border-slate-200 bg-slate-50 p-3 text-left text-xs leading-5 text-slate-600 transition hover:border-cyan-400 hover:bg-cyan-50 hover:text-slate-900 dark:border-slate-800 dark:bg-slate-950/50 dark:text-slate-400 dark:hover:border-cyan-800 dark:hover:bg-cyan-950/30 dark:hover:text-slate-100"
                >
                  {prompt}
                </button>
              ))}
            </div>
          )}

          {loading && (
            <div className="flex justify-start">
              <div className="rounded-2xl rounded-bl-md bg-slate-100 px-4 py-3 text-sm text-slate-500 dark:bg-slate-800 dark:text-slate-400">
                {reasoningLabel(activeEffort)} · {elapsedSeconds}s
              </div>
            </div>
          )}

          {error && (
            <div className="rounded-2xl border border-red-200 bg-red-50 p-4 text-sm text-red-700 dark:border-red-900 dark:bg-red-950/40 dark:text-red-300">
              <strong>Aviso:</strong> {error}
            </div>
          )}
          <div ref={bottomRef} />
        </div>

        <form onSubmit={handleSend} className="border-t border-slate-200 p-4 dark:border-slate-800">
          <label htmlFor="message" className="sr-only">Mensaje</label>
          <div className="flex flex-col gap-3 sm:flex-row">
            <textarea
              id="message"
              value={input}
              onChange={(event) => setInput(event.target.value)}
              onKeyDown={(event) => {
                if (event.key === 'Enter' && !event.shiftKey) {
                  event.preventDefault()
                  handleSend()
                }
              }}
              rows={3}
              placeholder={connection.status === 'online' ? 'Escribí una consulta, pegá un error o compartí un log...' : 'Esperando una conexión disponible...'}
              className="min-h-24 flex-1 resize-none rounded-2xl border border-slate-300 bg-white px-4 py-3 text-base outline-none transition focus:border-cyan-500 focus:ring-4 focus:ring-cyan-500/10 dark:border-slate-700 dark:bg-slate-950 dark:text-slate-100 sm:text-sm"
            />
            <button
              type={loading ? 'button' : 'submit'}
              onClick={loading ? cancelRequest : undefined}
              disabled={!loading && !canSend}
              className="rounded-2xl bg-cyan-600 px-6 py-3 font-bold text-white transition hover:bg-cyan-500 disabled:cursor-not-allowed disabled:opacity-40 sm:self-end"
            >
              {loading ? 'Cancelar' : 'Enviar'}
            </button>
          </div>
          <p className="mt-2 text-xs text-slate-500 dark:text-slate-400">
            Enter envía. Shift + Enter agrega una línea. Cada conversación queda guardada sólo en este dispositivo.
          </p>
        </form>
      </section>
    </div>
  )
}
