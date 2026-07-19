import { useMemo, useState } from 'react'

const allTickets = [
  { title: 'Problema con login', area: 'Accesos' },
  { title: 'No funciona el botón de enviar', area: 'Frontend' },
  { title: 'Error 404 al cargar página', area: 'Portal' },
  { title: 'Cambiar contraseña', area: 'Accesos' },
  { title: 'Consulta sobre facturación', area: 'EBS' },
  { title: 'ORA-01722: número no válido', area: 'Oracle' },
]

export default function TicketFilter() {
  const [query, setQuery] = useState('')
  const filtered = useMemo(() => {
    const normalized = query.trim().toLowerCase()
    if (!normalized) return allTickets
    return allTickets.filter(({ title, area }) => `${title} ${area}`.toLowerCase().includes(normalized))
  }, [query])

  return (
    <aside className="h-fit rounded-3xl border border-slate-200 bg-white p-5 shadow-sm dark:border-slate-800 dark:bg-slate-900">
      <h2 className="font-bold">Referencias rápidas</h2>
      <p className="mt-1 text-xs text-slate-500 dark:text-slate-400">Casos de ejemplo para orientar el análisis.</p>
      <input
        className="mt-4 w-full rounded-xl border border-slate-300 bg-white px-3 py-2 text-sm outline-none focus:border-cyan-500 dark:border-slate-700 dark:bg-slate-950"
        placeholder="Buscar ticket o área..."
        value={query}
        onChange={(event) => setQuery(event.target.value)}
      />
      <div className="mt-4 space-y-2">
        {filtered.map((ticket) => (
          <article key={`${ticket.area}-${ticket.title}`} className="rounded-2xl border border-slate-200 p-3 dark:border-slate-800">
            <p className="text-sm font-semibold">{ticket.title}</p>
            <p className="mt-1 text-xs text-cyan-600 dark:text-cyan-400">{ticket.area}</p>
          </article>
        ))}
        {!filtered.length && <p className="py-4 text-center text-sm text-slate-500">Sin coincidencias.</p>}
      </div>
    </aside>
  )
}
