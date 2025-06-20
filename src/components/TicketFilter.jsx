import { useState } from 'react'

const allTickets = [
  'Problema con login',
  'No funciona el botón de enviar',
  'Error 404 al cargar página',
  'Cambiar contraseña',
  'Consulta sobre facturación',
]

const TicketFilter = () => {
  const [query, setQuery] = useState('')

  const filtered = allTickets.filter((t) =>
    t.toLowerCase().includes(query.toLowerCase())
  )

  return (
    <div className="border p-4 rounded">
      <h2 className="text-lg font-semibold mb-2">🔍 Buscar ticket</h2>
      <input
        className="w-full border p-1 rounded mb-2 dark:bg-gray-800"
        placeholder="Buscar..."
        value={query}
        onChange={(e) => setQuery(e.target.value)}
      />
      <ul className="list-disc list-inside">
        {filtered.map((ticket, i) => (
          <li key={i}>{ticket}</li>
        ))}
      </ul>
    </div>
  )
}

export default TicketFilter
