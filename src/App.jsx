import React, { useState, useEffect } from 'react'
import Chat from './components/Chat'
import ToggleTheme from './components/ToggleTheme'
import TicketFilter from './components/TicketFilter'

const App = () => {
  const [darkMode, setDarkMode] = useState(false)

  useEffect(() => {
    document.documentElement.classList.toggle('dark', darkMode)
  }, [darkMode])

  return (
    <div className="min-h-screen bg-white dark:bg-gray-900 text-black dark:text-white p-4">
      <ToggleTheme toggle={() => setDarkMode(!darkMode)} darkMode={darkMode} />
      <h1 className="text-2xl font-bold mb-4">💬 Chat + Tickets</h1>
      <Chat />
      <TicketFilter />
    </div>
  )
}

export default App
