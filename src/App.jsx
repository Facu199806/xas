import { useEffect, useState } from 'react'
import Chat from './components/Chat'
import TicketFilter from './components/TicketFilter'
import ToggleTheme from './components/ToggleTheme'

const THEME_KEY = 'xas-theme'

export default function App() {
  const [darkMode, setDarkMode] = useState(() => {
    const savedTheme = localStorage.getItem(THEME_KEY)
    if (savedTheme) return savedTheme === 'dark'
    return window.matchMedia?.('(prefers-color-scheme: dark)').matches ?? false
  })

  useEffect(() => {
    document.documentElement.classList.toggle('dark', darkMode)
    document.documentElement.style.colorScheme = darkMode ? 'dark' : 'light'
    localStorage.setItem(THEME_KEY, darkMode ? 'dark' : 'light')
  }, [darkMode])

  return (
    <main className="min-h-screen bg-slate-100 text-slate-950 transition-colors duration-300 dark:bg-slate-950 dark:text-slate-100">
      <div className="mx-auto flex min-h-screen max-w-7xl flex-col gap-6 px-4 py-6 lg:px-8">
        <header className="flex flex-col gap-4 rounded-3xl border border-slate-200 bg-white/90 p-5 shadow-sm backdrop-blur transition-colors duration-300 dark:border-slate-800 dark:bg-slate-900/90 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <p className="text-xs font-semibold uppercase tracking-[0.25em] text-cyan-600 dark:text-cyan-400">XAS workspace</p>
            <h1 className="mt-1 text-3xl font-black tracking-tight">Asistente local para soporte</h1>
            <p className="mt-2 max-w-2xl text-sm text-slate-600 dark:text-slate-400">
              Chat con IA, historial local y referencias rápidas para analizar incidentes sin convertir cada ticket en una expedición arqueológica.
            </p>
          </div>
          <ToggleTheme darkMode={darkMode} toggle={() => setDarkMode((value) => !value)} />
        </header>

        <section className="grid flex-1 gap-6 lg:grid-cols-[minmax(0,1fr)_320px]">
          <Chat />
          <TicketFilter />
        </section>
      </div>
    </main>
  )
}
