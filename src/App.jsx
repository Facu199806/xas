import { useEffect, useState } from 'react'
import Chat from './components/Chat'
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
      <div className="mx-auto flex min-h-screen max-w-[1600px] flex-col gap-4 px-3 py-3 sm:gap-6 sm:px-5 sm:py-5 lg:px-8">
        <header className="flex items-center justify-between gap-4 rounded-3xl border border-slate-200 bg-white/90 px-4 py-3 shadow-sm backdrop-blur transition-colors duration-300 dark:border-slate-800 dark:bg-slate-900/90 sm:px-5 sm:py-4">
          <div className="flex min-w-0 items-center gap-3">
            <img
              src="/xas-icon.svg"
              alt="Logo de NOXAS"
              className="h-11 w-11 shrink-0 rounded-2xl shadow-lg shadow-cyan-500/10 ring-1 ring-slate-200 dark:ring-slate-700 sm:h-14 sm:w-14"
            />
            <div className="min-w-0">
              <div className="flex items-center gap-2">
                <h1 className="truncate text-xl font-black tracking-tight sm:text-2xl">NOXAS</h1>
                <span className="hidden rounded-full border border-cyan-200 bg-cyan-50 px-2 py-0.5 text-[10px] font-bold uppercase tracking-wider text-cyan-700 dark:border-cyan-900 dark:bg-cyan-950/40 dark:text-cyan-300 sm:inline-flex">
                  beta
                </span>
              </div>
              <p className="truncate text-xs text-slate-500 dark:text-slate-400 sm:text-sm">
                Asistente técnico para soporte, Oracle, Siebel y análisis de incidentes.
              </p>
            </div>
          </div>

          <ToggleTheme darkMode={darkMode} toggle={() => setDarkMode((value) => !value)} />
        </header>

        <Chat />
      </div>
    </main>
  )
}
