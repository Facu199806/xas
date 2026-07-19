# Puesta en marcha rápida

## 1. Frontend

1. Instalá Node.js 18 o superior.
2. Ejecutá `npm install`.
3. Copiá `.env.example` como `.env`.
4. Para desarrollo, ejecutá `npm run dev`.
5. Abrí la URL que muestre Vite, normalmente `http://localhost:5173`.

Para probar la compilación de producción:

```bash
npm run build
npm run preview
```

La vista previa suele quedar en `http://localhost:4173`. Tanto `dev` como `preview` redirigen las solicitudes `/api` al motor configurado en `VITE_AI_PROXY_TARGET`.

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
VITE_AI_MAX_TOKENS=1024
VITE_AI_TIMEOUT_MS=120000
```

- `VITE_AI_REASONING_EFFORT` se usa en consultas técnicas. Los saludos desactivan el razonamiento y las preguntas cortas usan nivel bajo.
- `VITE_AI_MAX_TOKENS` limita la generación para que el modelo no consuma recursos indefinidamente.
- `VITE_AI_TIMEOUT_MS` cancela una solicitud que exceda el tiempo indicado.

Si ya existía un `.env` anterior apuntando al puerto `1337`, reemplazalo por estos valores y reiniciá `npm run dev` o `npm run preview`.

## 4. Diagnóstico directo

Comprobá que Ollama vea el modelo:

```bash
curl http://localhost:11434/v1/models
```

Probá una respuesta sin razonamiento prolongado:

```bash
curl http://localhost:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"qwen3:4b","messages":[{"role":"user","content":"Hola"}],"reasoning_effort":"none","max_tokens":128,"stream":false}'
```

Si este comando también demora, el problema está en la carga o ejecución local del modelo, no en React. La primera generación puede tardar más porque Ollama debe cargar el modelo en memoria.

## Validación mínima

- El tema claro/oscuro debe cambiar al pulsar el botón y persistir al recargar.
- El encabezado del chat debe mostrar `Ollama conectado`.
- Si falta el modelo, debe indicar `Falta descargar qwen3:4b`.
- Un saludo debe usar `respuesta rápida`.
- Un error, log o consulta SQL debe activar razonamiento técnico.
- Durante una solicitud debe mostrarse el tiempo transcurrido y el botón `Cancelar`.
- Una solicitud demasiado larga debe cortarse sin dejar bloqueada la interfaz.
- El historial debe persistir al recargar.
- Una API apagada debe mostrar un error explicativo.
- Una respuesta válida debe aparecer como mensaje del asistente.
- `npm run build` debe finalizar sin errores antes de publicar.
- `npm run preview` debe conservar la conexión con Ollama.
