import { useEffect, useState } from 'react'

const Chat = () => {
  const [messages, setMessages] = useState(() => {
    return JSON.parse(localStorage.getItem('chatHistory')) || []
  })
  const [input, setInput] = useState('')
  const [loading, setLoading] = useState(false)

  const handleSend = () => {
    if (!input.trim()) return
    const userMsg = { from: 'user', text: input }
    setMessages((prev) => [...prev, userMsg])
    setInput('')
    setLoading(true)

    setTimeout(() => {
      const botMsg = {
        from: 'bot',
        text: `Echo: ${userMsg.text}`,
      }
      setMessages((prev) => [...prev, botMsg])
      setLoading(false)
    }, 1000)
  }

  useEffect(() => {
    localStorage.setItem('chatHistory', JSON.stringify(messages))
  }, [messages])

  return (
    <div className="border p-4 rounded mb-4">
      <div className="h-48 overflow-y-auto mb-2">
        {messages.map((msg, i) => (
          <div
            key={i}
            className={msg.from === 'user' ? 'text-right' : 'text-left'}
          >
            <span
              className={
                msg.from === 'user'
                  ? 'bg-blue-200 dark:bg-blue-700 p-1 rounded inline-block'
                  : 'bg-green-200 dark:bg-green-700 p-1 rounded inline-block'
              }
            >
              {msg.text}
            </span>
          </div>
        ))}
        {loading && <div className="italic text-gray-500">Escribiendo...</div>}
      </div>
      <div className="flex gap-2">
        <input
          className="flex-1 border rounded p-1 dark:bg-gray-800"
          value={input}
          onChange={(e) => setInput(e.target.value)}
        />
        <button
          className="bg-blue-500 text-white px-3 py-1 rounded"
          onClick={handleSend}
        >
          Enviar
        </button>
      </div>
    </div>
  )
}

export default Chat
