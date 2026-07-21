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
      <div className="mx-auto flex min-h-screen max-w-7xl flex-col gap-4 px-3 py-3 sm:gap-6 sm:px-4 sm:py-6 lg:px-8">
        <header className="flex flex-col gap-4 rounded-3xl border border-slate-200 bg-white/90 p-4 shadow-sm backdrop-blur transition-colors duration-300 dark:border-slate-800 dark:bg-slate-900/90 sm:p-5 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <p className="text-xs font-semibold uppercase tracking-[0.25em] text-cyan-600 dark:text-cyan-400">XAS workspace</p>
            <h1 className="mt-1 text-2xl font-black tracking-tight sm:text-3xl">Asistente para soporte</h1>
            <p className="mt-2 max-w-2xl text-sm text-slate-600 dark:text-slate-400">
              Análisis de tickets, errores, logs y consultas técnicas desde la web, el celular o tu entorno local.
            </p>
          </div>
          <ToggleTheme darkMode={darkMode} toggle={() => setDarkMode((value) => !value)} />
        </header>

        <section className="grid flex-1 gap-4 sm:gap-6 lg:grid-cols-[minmax(0,1fr)_320px]">
          <Chat />
          <TicketFilter />
        </section>
      </div>
    </main>
  )
}
