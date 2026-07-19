import { useEffect, useMemo, useRef, useState } from 'react'

const HISTORY_KEY = 'xas-chat-history-v2'
const API_URL = import.meta.env.VITE_AI_API_URL || '/api/v1/chat/completions'
const MODEL = import.meta.env.VITE_AI_MODEL || 'gpt-4o-mini'

const starterMessage = {
  role: 'assistant',
  content: 'XAS listo. Pegá un error, log, consulta SQL o descripción de ticket y lo analizamos.',
}

function loadHistory() {
  try {
    const parsed = JSON.parse(localStorage.getItem(HISTORY_KEY))
    return Array.isArray(parsed) && parsed.length ? parsed : [starterMessage]
  } catch {
    return [starterMessage]
  }
}

export default function Chat() {
  const [messages, setMessages] = useState(loadHistory)
  const [input, setInput] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const bottomRef = useRef(null)

  const canSend = useMemo(() => input.trim().length > 0 && !loading, [input, loading])

  useEffect(() => {
    localStorage.setItem(HISTORY_KEY, JSON.stringify(messages))
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [messages, loading])

  async function handleSend(event) {
    event?.preventDefault()
    const text = input.trim()
    if (!text || loading) return

    const nextMessages = [...messages, { role: 'user', content: text }]
    setMessages(nextMessages)
    setInput('')
    setError('')
    setLoading(true)

    try {
      const response = await fetch(API_URL, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          model: MODEL,
          messages: nextMessages.map(({ role, content }) => ({ role, content })),
          stream: false,
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
        const apiMessage = data?.error?.message || data?.message || `Error HTTP ${response.status}`
        throw new Error(apiMessage)
      }

      const content = data?.choices?.[0]?.message?.content
      if (!content) throw new Error('La API respondió sin contenido en choices[0].message.content.')

      setMessages((current) => [...current, { role: 'assistant', content }])
    } catch (requestError) {
      setError(requestError instanceof Error ? requestError.message : 'No se pudo contactar con la IA.')
    } finally {
      setLoading(false)
    }
  }

  function clearHistory() {
    setMessages([starterMessage])
    setError('')
  }

  return (
    <section className="flex min-h-[70vh] flex-col overflow-hidden rounded-3xl border border-slate-200 bg-white shadow-sm dark:border-slate-800 dark:bg-slate-900">
      <div className="flex items-center justify-between border-b border-slate-200 px-5 py-4 dark:border-slate-800">
        <div>
          <h2 className="font-bold">Conversación</h2>
          <p className="text-xs text-slate-500 dark:text-slate-400">Modelo: {MODEL}</p>
        </div>
        <button
          type="button"
          onClick={clearHistory}
          className="rounded-xl border border-slate-300 px-3 py-2 text-xs font-semibold transition hover:bg-slate-100 dark:border-slate-700 dark:hover:bg-slate-800"
        >
          Limpiar historial
        </button>
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
              Analizando...
            </div>
          </div>
        )}

        {error && (
          <div className="rounded-2xl border border-red-200 bg-red-50 p-4 text-sm text-red-700 dark:border-red-900 dark:bg-red-950/40 dark:text-red-300">
            <strong>Error de conexión:</strong> {error}
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
            placeholder="Ejemplo: analizá este ORA-01722 y sugerí validaciones..."
            className="min-h-24 flex-1 resize-none rounded-2xl border border-slate-300 bg-white px-4 py-3 text-sm outline-none transition focus:border-cyan-500 focus:ring-4 focus:ring-cyan-500/10 dark:border-slate-700 dark:bg-slate-950"
          />
          <button
            type="submit"
            disabled={!canSend}
            className="rounded-2xl bg-cyan-600 px-6 py-3 font-bold text-white transition hover:bg-cyan-500 disabled:cursor-not-allowed disabled:opacity-40 sm:self-end"
          >
            {loading ? 'Enviando...' : 'Enviar'}
          </button>
        </div>
        <p className="mt-2 text-xs text-slate-500 dark:text-slate-400">Enter envía. Shift + Enter agrega una línea.</p>
      </form>
    </section>
  )
}
