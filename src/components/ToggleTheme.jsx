const ToggleTheme = ({ toggle, darkMode }) => (
  <button
    onClick={toggle}
    className="bg-gray-300 dark:bg-gray-700 px-4 py-2 rounded mb-4"
  >
    {darkMode ? '🌞 Claro' : '🌙 Oscuro'}
  </button>
)

export default ToggleTheme
