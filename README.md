# XAS

XAS es una interfaz local construida con React, Vite y Tailwind CSS para conversar con una API de IA compatible con el formato de OpenAI. Está orientada al análisis de tickets, errores, logs y consultas técnicas.

## Funcionalidades

- Chat conectado a una API configurable.
- Historial persistido en `localStorage`.
- Tema claro y oscuro persistente.
- Manejo visible de errores HTTP y respuestas inválidas.
- Buscador de referencias rápidas para tickets.
- Proxy de desarrollo para evitar problemas de CORS con servicios locales.

## Requisitos

- Node.js 18 o superior.
- npm.
- Un servidor compatible con `POST /v1/chat/completions` ejecutándose localmente o disponible por red.

## Instalación

```bash
git clone https://github.com/Facu199806/xas.git
cd xas
npm install
cp .env.example .env
npm run dev
```

En Windows PowerShell podés crear el archivo de entorno con:

```powershell
Copy-Item .env.example .env
```

## Configuración

Variables disponibles en `.env`:

```env
VITE_AI_PROXY_TARGET=http://localhost:1337
VITE_AI_API_URL=/api/v1/chat/completions
VITE_AI_MODEL=gpt-4o-mini
```

- `VITE_AI_PROXY_TARGET`: servidor local o remoto al que Vite enviará las solicitudes `/api` durante el desarrollo.
- `VITE_AI_API_URL`: endpoint que consume el frontend.
- `VITE_AI_MODEL`: nombre de modelo enviado en el cuerpo de la solicitud.

El endpoint debe responder con una estructura similar a:

```json
{
  "choices": [
    {
      "message": {
        "content": "Respuesta del asistente"
      }
    }
  ]
}
```

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

## Próximas mejoras sugeridas

- Backend propio para proteger claves y normalizar proveedores.
- Conversaciones múltiples.
- Prompts de sistema configurables.
- Importación de logs y archivos.
- Respuestas en streaming.
- Pruebas automatizadas.

## Seguridad

No guardes claves privadas en variables `VITE_*`: Vite las incorpora al código del navegador. Para proveedores que exigen una clave secreta, usá un backend intermedio.
