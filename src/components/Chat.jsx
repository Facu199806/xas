import { useEffect, useMemo, useRef, useState } from 'react'

const HISTORY_KEY = 'xas-chat-history-v3'
const API_URL = import.meta.env.VITE_AI_API_URL || '/api/v1/chat/completions'
const MODELS_URL = import.meta.env.VITE_AI_MODELS_URL || '/api/v1/models'
const MODEL = import.meta.env.VITE_AI_MODEL || 'qwen3:4b'
const DEFAULT_REASONING_EFFORT = import.meta.env.VITE_AI_REASONING_EFFORT || 'medium'
const TEMPERATURE = Number(import.meta.env.VITE_AI_TEMPERATURE ?? 0.2)
const MAX_TOKENS = Number(import.meta.env.VITE_AI_MAX_TOKENS ?? 1024)
const REQUEST_TIMEOUT_MS = Number(import.meta.env.VITE_AI_TIMEOUT_MS ?? 120000)
const MAX_CONTEXT_MESSAGES = 18

const SYSTEM_PROMPT = `Tu nombre es XAS. Sos un asistente local especializado en soporte técnico, análisis de incidentes, Oracle EBS, Siebel, SQL, PL/SQL y Windows.

Antes de responder, separá hechos comprobables, hipótesis y datos faltantes. No inventes tablas, permisos, resultados, causas ni accesos. Cuando recibas un error o log, explicá qué indica, cuál es la causa más probable, cómo validarla y cuál es el siguiente paso seguro. Priorizá consultas de diagnóstico y evitá proponer UPDATE, DELETE o INSERT en producción salvo pedido explícito, aclarando siempre el riesgo. Respondé en español rioplatense claro, con pasos concretos y verificables. Razoná internamente y mostrale al usuario conclusiones útiles, no una cadena de pensamiento privada.`

const starterMessage = {
  role: 'assistant',
  content: 'XAS listo. Pegá un error, log, consulta SQL o descripción de ticket y lo analizamos.',
}

const SIMPLE_MESSAGE_PATTERN = /^(hola|buenas|buen día|buen dia|buenas tardes|buenas noches|qué tal|que tal|gracias|ok|dale|probando|test)[\s!¡?¿.,]*$/i
const TECHNICAL_MESSAGE_PATTERN = /(ora-\d+|sql|pl\/sql|siebel|oracle|ebs|error|log|stack|trace|query|consulta|select\b|join\b|package|procedure|función|funcion|ticket|incidente|windows|servidor|api|http|json|javascript|react|vite|analiz|diagn[oó]st)/i

function loadHistory() {
  try {
    const parsed = JSON.parse(localStorage.getItem(HISTORY_KEY))
    return Array.isArray(parsed) && parsed.length ? parsed : [starterMessage]
  } catch {
    return [starterMessage]
  }
}

function buildApiMessages(messages) {
  const conversation = messages
    .filter((message) => message.content !== starterMessage.content)
    .slice(-MAX_CONTEXT_MESSAGES)
    .map(({ role, content }) => ({ role, content }))

  return [{ role: 'system', content: SYSTEM_PROMPT }, ...conversation]
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
  const [messages, setMessages] = useState(loadHistory)
  const [input, setInput] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [activeEffort, setActiveEffort] = useState('none')
  const [elapsedSeconds, setElapsedSeconds] = useState(0)
  const [connection, setConnection] = useState({ status: 'checking', message: 'Comprobando Ollama...' })
  const bottomRef = useRef(null)
  const abortControllerRef = useRef(null)

  const canSend = useMemo(() => input.trim().length > 0 && !loading, [input, loading])

  async function refreshConnection() {
    setConnection({ status: 'checking', message: 'Comprobando Ollama...' })

    try {
      const response = await fetch(MODELS_URL)
      const rawText = await response.text()
      const data = rawText ? JSON.parse(rawText) : {}

      if (!response.ok) throw new Error(`HTTP ${response.status}`)

      const availableModels = Array.isArray(data?.data) ? data.data.map((item) => item.id) : []
      const modelInstalled = availableModels.includes(MODEL)

      setConnection(
        modelInstalled
          ? { status: 'online', message: 'Ollama conectado' }
          : { status: 'missing', message: `Falta descargar ${MODEL}` },
      )

      return modelInstalled
    } catch {
      setConnection({ status: 'offline', message: 'Ollama desconectado' })
      return false
    }
  }

  useEffect(() => {
    refreshConnection()
  }, [])

  useEffect(() => {
    localStorage.setItem(HISTORY_KEY, JSON.stringify(messages))
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [messages, loading])

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

  async function handleSend(event) {
    event?.preventDefault()
    const text = input.trim()
    if (!text || loading) return

    const effort = chooseReasoningEffort(text)
    const nextMessages = [...messages, { role: 'user', content: text }]
    const controller = new AbortController()
    const timeoutId = window.setTimeout(() => controller.abort('timeout'), REQUEST_TIMEOUT_MS)

    abortControllerRef.current = controller
    setMessages(nextMessages)
    setInput('')
    setError('')
    setActiveEffort(effort)
    setLoading(true)

    try {
      const response = await fetch(API_URL, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        signal: controller.signal,
        body: JSON.stringify({
          model: MODEL,
          messages: buildApiMessages(nextMessages),
          stream: false,
          temperature: Number.isFinite(TEMPERATURE) ? TEMPERATURE : 0.2,
          max_tokens: Number.isFinite(MAX_TOKENS) ? MAX_TOKENS : 1024,
          reasoning_effort: effort,
        }),
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
          (typeof data?.error === 'string' && data.error) ||
          data?.error?.message ||
          data?.message ||
          `Error HTTP ${response.status}`

        if (response.status === 404 && /model|not found|no encontrado/i.test(apiMessage)) {
          throw new Error(`El modelo ${MODEL} no está instalado. Ejecutá: ollama pull ${MODEL}`)
        }

        throw new Error(apiMessage)
      }

      const content = data?.choices?.[0]?.message?.content?.trim()
      if (!content) {
        throw new Error('Ollama terminó el razonamiento pero no generó una respuesta final. Probá de nuevo o usá un nivel de razonamiento menor.')
      }

      setMessages((current) => [...current, { role: 'assistant', content }])
      setConnection({ status: 'online', message: 'Ollama conectado' })
    } catch (requestError) {
      const requestMessage = requestError instanceof Error
        ? requestError.message
        : typeof requestError === 'string'
          ? requestError
          : 'No se pudo contactar con la IA.'
      const aborted = controller.signal.aborted
      const timedOut = aborted && controller.signal.reason === 'timeout'
      const manuallyCancelled = aborted && controller.signal.reason === 'manual'
      const networkFailure = /failed to fetch|network|econnrefused|no se pudo conectar con ollama/i.test(requestMessage)

      if (timedOut) {
        setError(`La respuesta superó ${Math.round(REQUEST_TIMEOUT_MS / 1000)} segundos. Ollama sigue conectado, pero el modelo tardó demasiado. Probá una consulta más corta o bajá el razonamiento.`)
      } else if (manuallyCancelled) {
        setError('Solicitud cancelada. Ollama sigue disponible.')
      } else if (networkFailure) {
        setError(`Ollama no está disponible. Iniciá Ollama y ejecutá: ollama run ${MODEL}`)
        setConnection({ status: 'offline', message: 'Ollama desconectado' })
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

  function clearHistory() {
    abortControllerRef.current?.abort('manual')
    setMessages([starterMessage])
    setError('')
  }

  return (
    <section className="flex min-h-[70vh] flex-col overflow-hidden rounded-3xl border border-slate-200 bg-white shadow-sm transition-colors duration-300 dark:border-slate-800 dark:bg-slate-900">
      <div className="flex flex-col gap-3 border-b border-slate-200 px-5 py-4 transition-colors dark:border-slate-800 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h2 className="font-bold">Conversación</h2>
          <p className="text-xs text-slate-500 dark:text-slate-400">Modelo local: {MODEL} · razonamiento adaptativo</p>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          <button
            type="button"
            onClick={refreshConnection}
            className={`rounded-xl border px-3 py-2 text-xs font-semibold transition ${connectionClasses(connection.status)}`}
          >
            {connection.message}
          </button>
          <button
            type="button"
            onClick={clearHistory}
            className="rounded-xl border border-slate-300 px-3 py-2 text-xs font-semibold transition hover:bg-slate-100 dark:border-slate-700 dark:hover:bg-slate-800"
          >
            Limpiar historial
          </button>
        </div>
      </div>

      <div className="flex-1 space-y-4 overflow-y-auto p-5">
        {messages.map((message, index) => {
          const fromUser = message.role === 'user'
          return (
            <article key={`${message.role}-${index}`} className={`flex ${fromUser ? 'justify-end' : 'justify-start'}`}>
              <div
                className={`max-w-[88%] whitespace-pre-wrap rounded-2xl px-4 py-3 text-sm leading-6 shadow-sm ${
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

      <form onSubmit={handleSend} className="border-t border-slate-200 p-4 transition-colors dark:border-slate-800">
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
            placeholder="Ejemplo: analizá este ORA-01722 y sugerí validaciones..."
            className="min-h-24 flex-1 resize-none rounded-2xl border border-slate-300 bg-white px-4 py-3 text-sm outline-none transition focus:border-cyan-500 focus:ring-4 focus:ring-cyan-500/10 dark:border-slate-700 dark:bg-slate-950 dark:text-slate-100"
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
        <p className="mt-2 text-xs text-slate-500 dark:text-slate-400">Enter envía. Shift + Enter agrega una línea. Los saludos usan respuesta rápida; los casos técnicos activan razonamiento.</p>
      </form>
    </section>
  )
}
