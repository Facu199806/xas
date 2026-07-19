# Puesta en marcha rápida

## 1. Frontend

1. Instalá Node.js 18 o superior.
2. Ejecutá `npm install`.
3. Copiá `.env.example` como `.env`.
4. Ejecutá `npm run dev`.
5. Abrí la URL que muestre Vite, normalmente `http://localhost:5173`.

## 2. Motor local con Ollama

1. Instalá Ollama para Windows.
2. Abrí una segunda terminal.
3. Descargá el modelo recomendado:

```bash
ollama pull qwen3:4b
```

4. Iniciá una conversación para comprobar el modelo:

```bash
ollama run qwen3:4b
```

Ollama queda disponible en `http://localhost:11434`. XAS usa el endpoint compatible con OpenAI `/v1/chat/completions` mediante el proxy de Vite.

## 3. Variables de entorno

```env
VITE_AI_PROXY_TARGET=http://localhost:11434
VITE_AI_API_URL=/api/v1/chat/completions
VITE_AI_MODELS_URL=/api/v1/models
VITE_AI_MODEL=qwen3:4b
VITE_AI_REASONING_EFFORT=medium
VITE_AI_TEMPERATURE=0.2
```

Si ya existía un `.env` anterior apuntando al puerto `1337`, reemplazalo por estos valores y reiniciá `npm run dev`.

## Validación mínima

- El tema claro/oscuro debe cambiar al pulsar el botón y persistir al recargar.
- El encabezado del chat debe mostrar `Ollama conectado`.
- Si falta el modelo, debe indicar `Falta descargar qwen3:4b`.
- El historial debe persistir al recargar.
- Una API apagada debe mostrar un error explicativo.
- Una respuesta válida debe aparecer como mensaje del asistente.
- `npm run build` debe finalizar sin errores antes de publicar.
