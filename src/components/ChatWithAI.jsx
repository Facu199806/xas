import React, { useState } from 'react';

export default function ChatWithAI() {
  const [prompt, setPrompt] = useState('');
  const [response, setResponse] = useState('');
  const [loading, setLoading] = useState(false);

  const askAI = async () => {
    if (!prompt) return;
    setLoading(true);
    setResponse('');
    try {
      const res = await fetch('http://localhost:1337/v1/chat/completions', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ messages: [{ role: 'user', content: prompt }] }),
      });
      const data = await res.json();
      setResponse(data.choices?.[0]?.message?.content ?? 'Sin respuesta');
    } catch (e) {
      setResponse('Error al contactar con la IA');
    }
    setLoading(false);
  };

  return (
    <div className="chat-container">
      <textarea
        value={prompt}
        onChange={e => setPrompt(e.target.value)}
        placeholder="Escribe aquí..."
      />
      <button onClick={askAI} disabled={loading}>
        {loading ? 'Cargando...' : 'Enviar'}
      </button>
      <div className="chat-response">{response}</div>
    </div>
  );
}
