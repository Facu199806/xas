import { useMemo, useState } from 'react'

function formatUpdatedAt(timestamp) {
  const date = new Date(timestamp)
  if (Number.isNaN(date.getTime())) return ''

  return new Intl.DateTimeFormat('es-AR', {
    day: '2-digit',
    month: 'short',
    hour: '2-digit',
    minute: '2-digit',
  }).format(date)
}

export default function ConversationSidebar({
  conversations,
  activeId,
  onSelect,
  onNew,
  onRename,
  onDelete,
}) {
  const [query, setQuery] = useState('')

  const filteredConversations = useMemo(() => {
    const normalized = query.trim().toLowerCase()
    return [...conversations]
      .sort((a, b) => b.updatedAt - a.updatedAt)
      .filter((conversation) => !normalized || conversation.title.toLowerCase().includes(normalized))
  }, [conversations, query])

  return (
    <aside className="flex min-h-0 flex-col rounded-3xl border border-slate-200 bg-white/90 shadow-sm backdrop-blur dark:border-slate-800 dark:bg-slate-900/90 lg:sticky lg:top-6 lg:max-h-[calc(100vh-3rem)]">
      <div className="border-b border-slate-200 p-4 dark:border-slate-800">
        <button
          type="button"
          onClick={onNew}
          className="flex w-full items-center justify-center gap-2 rounded-2xl bg-cyan-600 px-4 py-3 text-sm font-bold text-white transition hover:bg-cyan-500 focus:outline-none focus:ring-4 focus:ring-cyan-500/20"
        >
          <span aria-hidden="true">＋</span>
          Nueva consulta
        </button>

        <label className="mt-3 block">
          <span className="sr-only">Buscar conversaciones</span>
          <input
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            placeholder="Buscar conversaciones..."
            className="w-full rounded-2xl border border-slate-300 bg-white px-4 py-2.5 text-sm outline-none transition focus:border-cyan-500 focus:ring-4 focus:ring-cyan-500/10 dark:border-slate-700 dark:bg-slate-950"
          />
        </label>
      </div>

      <div className="min-h-0 flex-1 space-y-2 overflow-y-auto p-3">
        {filteredConversations.map((conversation) => {
          const active = conversation.id === activeId
          const userMessages = conversation.messages.filter((message) => message.role === 'user').length

          return (
            <article
              key={conversation.id}
              className={`group rounded-2xl border p-2 transition ${
                active
                  ? 'border-cyan-400 bg-cyan-50 dark:border-cyan-700 dark:bg-cyan-950/30'
                  : 'border-transparent hover:border-slate-200 hover:bg-slate-50 dark:hover:border-slate-800 dark:hover:bg-slate-800/60'
              }`}
            >
              <button
                type="button"
                onClick={() => onSelect(conversation.id)}
                className="w-full rounded-xl px-2 py-2 text-left focus:outline-none focus:ring-2 focus:ring-cyan-500/30"
              >
                <span className="block truncate text-sm font-semibold">{conversation.title}</span>
                <span className="mt-1 flex items-center justify-between gap-2 text-[11px] text-slate-500 dark:text-slate-400">
                  <span>{userMessages ? `${userMessages} consulta${userMessages === 1 ? '' : 's'}` : 'Sin consultas'}</span>
                  <span>{formatUpdatedAt(conversation.updatedAt)}</span>
                </span>
              </button>

              <div className="flex justify-end gap-1 px-1 pb-1">
                <button
                  type="button"
                  onClick={() => onRename(conversation.id)}
                  className="rounded-lg px-2 py-1 text-[11px] font-semibold text-slate-500 transition hover:bg-white hover:text-slate-900 dark:hover:bg-slate-900 dark:hover:text-white"
                >
                  Renombrar
                </button>
                <button
                  type="button"
                  onClick={() => onDelete(conversation.id)}
                  className="rounded-lg px-2 py-1 text-[11px] font-semibold text-slate-500 transition hover:bg-red-50 hover:text-red-700 dark:hover:bg-red-950/40 dark:hover:text-red-300"
                >
                  Eliminar
                </button>
              </div>
            </article>
          )
        })}

        {!filteredConversations.length && (
          <div className="rounded-2xl border border-dashed border-slate-300 px-4 py-8 text-center text-sm text-slate-500 dark:border-slate-700">
            No encontré conversaciones con ese nombre.
          </div>
        )}
      </div>

      <div className="border-t border-slate-200 px-4 py-3 text-xs text-slate-500 dark:border-slate-800 dark:text-slate-400">
        Guardado local en este dispositivo.
      </div>
    </aside>
  )
}
