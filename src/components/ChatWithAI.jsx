import { useState } from "react";

export default function ChatWithAI() {
  const [prompt, setPrompt] = useState("");
  const [response, setResponse] = useState("");
  const [loading, setLoading] = useState(false);

  const handleAskAI = async () => {
    setLoading(true);
    setResponse("");
    try {
      const res = await fetch("http://localhost:1337/v1/chat/completions", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ messages: [{ role: "user", content: prompt }] }),
      });
      const data = await res.json();
      setResponse(data.choices?.[0]?.message?.content || "Sin respuesta");
    } catch (error) {
      setResponse("Error al conectar con la IA");
    }
    setLoading(false);
  };

  return (
    <div>
      <h2>Habla con la IA</h2>
      <input
        type="text"
        value={prompt}
        onChange={e => setPrompt(e.target.value)}
        placeholder="Escribe tu pregunta..."
      />
      <button onClick={handleAskAI} disabled={loading}>
        Preguntar a la IA
      </button>
      <div>
        {loading ? "Cargando..." : response}
      </div>
    </div>
  );
}
