const ToggleTheme = ({ toggle, darkMode }) => (
  <button
    type="button"
    onClick={toggle}
    aria-label={darkMode ? 'Activar tema claro' : 'Activar tema oscuro'}
    className="inline-flex items-center justify-center rounded-2xl border border-slate-300 bg-white px-4 py-2 text-sm font-semibold shadow-sm transition hover:-translate-y-0.5 hover:bg-slate-100 dark:border-slate-700 dark:bg-slate-950 dark:hover:bg-slate-800"
  >
    {darkMode ? '☀️ Tema claro' : '🌙 Tema oscuro'}
  </button>
)

export default ToggleTheme
