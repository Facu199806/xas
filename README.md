# XAS

XAS es una interfaz local construida con React, Vite y Tailwind CSS para conversar con un modelo ejecutado mediante Ollama. Está orientada al análisis de tickets, errores, logs, SQL y consultas técnicas.

## Funcionalidades

- Chat conectado a Ollama mediante la API compatible con OpenAI.
- Prompt de sistema enfocado en soporte técnico, Oracle EBS, Siebel, SQL, PL/SQL y Windows.
- Nivel de razonamiento configurable.
- Estado visible de conexión y detección del modelo instalado.
- Historial persistido en `localStorage`.
- Tema claro y oscuro persistente.
- Manejo visible de errores HTTP, modelo ausente y backend apagado.
- Buscador de referencias rápidas para tickets.
- Proxy de desarrollo para evitar problemas de CORS con servicios locales.

## Requisitos

- Node.js 18 o superior.
- npm.
- Ollama para Windows, macOS o Linux.
- El modelo `qwen3:4b` o el que se configure en `.env`.

## Instalación

```bash
git clone https://github.com/Facu199806/xas.git
cd xas
npm install
cp .env.example .env
```

En Windows PowerShell:

```powershell
Copy-Item .env.example .env
```

## Instalar el modelo local

```bash
ollama pull qwen3:4b
ollama run qwen3:4b
```

Ollama expone su API local en `http://localhost:11434`.

## Ejecutar XAS

En una terminal dejá Ollama activo. En otra:

```bash
npm run dev
```

Abrí la dirección mostrada por Vite, normalmente `http://localhost:5173`.

## Configuración

Variables disponibles en `.env`:

```env
VITE_AI_PROXY_TARGET=http://localhost:11434
VITE_AI_API_URL=/api/v1/chat/completions
VITE_AI_MODELS_URL=/api/v1/models
VITE_AI_MODEL=qwen3:4b
VITE_AI_REASONING_EFFORT=medium
VITE_AI_TEMPERATURE=0.2
```

- `VITE_AI_PROXY_TARGET`: host local de Ollama.
- `VITE_AI_API_URL`: endpoint de chat compatible con OpenAI.
- `VITE_AI_MODELS_URL`: endpoint usado para comprobar la conexión y los modelos instalados.
- `VITE_AI_MODEL`: modelo enviado en cada solicitud.
- `VITE_AI_REASONING_EFFORT`: nivel de razonamiento solicitado.
- `VITE_AI_TEMPERATURE`: variación de las respuestas.

Si el `.env` anterior apuntaba a `localhost:1337`, actualizalo y reiniciá Vite.

## Scripts

```bash
npm run dev
npm run build
npm run preview
```

## Estructura principal

```text
src/
├── components/
│   ├── Chat.jsx
│   ├── TicketFilter.jsx
│   └── ToggleTheme.jsx
├── App.jsx
├── index.css
└── main.jsx
```

## Seguridad

XAS funciona completamente en el equipo cuando se usa Ollama. No guardes claves privadas en variables `VITE_*`, porque Vite las incorpora al código del navegador. Para proveedores externos con secretos, usá un backend intermedio.

## Próximas mejoras

- Conversaciones múltiples.
- Prompts configurables desde la interfaz.
- Importación de logs y archivos.
- Respuestas en streaming.
- Pruebas automatizadas.
