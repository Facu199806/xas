# XAS

XAS es un asistente web construido con React, Vite y Tailwind CSS para analizar tickets, errores, logs, SQL y consultas técnicas.

Puede funcionar de dos formas:

- **Modo local:** Ollama y `qwen3:4b` en la PC.
- **Modo cloud:** Netlify Functions y Netlify AI Gateway, accesible desde cualquier navegador o celular sin dejar una computadora encendida.

## Funcionalidades

- Chat con razonamiento adaptativo según la consulta.
- Prompt especializado en soporte técnico, Oracle EBS, Siebel, SQL, PL/SQL y Windows.
- Historial persistido en `localStorage` de cada dispositivo.
- Tema claro y oscuro persistente.
- Estado visible del backend.
- Cancelación y timeout de solicitudes lentas.
- Buscador de referencias rápidas para tickets.
- Diseño adaptable a PC, Android, iPhone y tablet.
- Manifiesto y service worker para instalar XAS como aplicación web.
- Código de acceso opcional para proteger el backend cloud.
- Límite de solicitudes y validación del tamaño de los mensajes.

## Arquitectura

```text
Modo local
Navegador → Vite → Ollama → qwen3:4b

Modo publicado
Celular / navegador → Netlify → /api/chat → Netlify AI Gateway → modelo cloud
```

El navegador detecta automáticamente el entorno:

- `localhost` usa Ollama, salvo que `VITE_AI_MODE` indique otra cosa.
- Un dominio publicado usa `/api/chat` y el backend cloud.

## Uso local con Ollama

```bash
git clone https://github.com/Facu199806/xas.git
cd xas
npm install
cp .env.example .env
ollama pull qwen3:4b
npm run dev
```

En Windows PowerShell:

```powershell
Copy-Item .env.example .env
```

Abrí la dirección que muestre Vite, normalmente `http://localhost:5173`.

## Publicar en Netlify

El repositorio incluye:

- `netlify.toml`
- `netlify/functions/chat.mjs`
- configuración PWA en `public/`
- ruta cloud `/api/chat`

La guía completa está en:

```text
docs/NETLIFY.md
```

Resumen:

1. Importá este repositorio desde GitHub en Netlify.
2. Ejecutá el primer deploy de producción.
3. Verificá que AI Gateway esté habilitado.
4. Opcionalmente configurá:

```text
XAS_CLOUD_MODEL=gpt-5.4-mini
XAS_MAX_OUTPUT_TOKENS=1200
XAS_ACCESS_TOKEN=un-codigo-largo-y-privado
```

Netlify inyecta las credenciales de AI Gateway en la función. No se guardan claves privadas en el frontend.

## Instalar en el celular

### Android

Abrí el sitio con Chrome y elegí **Instalar aplicación** o **Agregar a la pantalla principal**.

### iPhone o iPad

Abrí el sitio con Safari, tocá **Compartir** y elegí **Agregar a inicio**.

## Variables locales

```env
VITE_AI_MODE=local
VITE_AI_PROXY_TARGET=http://localhost:11434
VITE_AI_API_URL=/api/v1/chat/completions
VITE_AI_MODELS_URL=/api/v1/models
VITE_AI_MODEL=qwen3:4b
VITE_CLOUD_API_URL=/api/chat
VITE_CLOUD_MODEL_LABEL=gpt-5.4-mini
VITE_AI_REASONING_EFFORT=medium
VITE_AI_TEMPERATURE=0.2
VITE_AI_MAX_TOKENS=1024
VITE_AI_TIMEOUT_MS=120000
```

## Scripts

```bash
npm run dev
npm run build
npm run preview
```

## Estructura principal

```text
netlify/
└── functions/
    └── chat.mjs
public/
├── manifest.webmanifest
├── sw.js
└── xas-icon.svg
src/
├── components/
│   ├── Chat.jsx
│   ├── TicketFilter.jsx
│   └── ToggleTheme.jsx
├── App.jsx
├── index.css
└── main.jsx
netlify.toml
```

## Seguridad

- No guardes claves privadas en variables `VITE_*`.
- Usá `XAS_ACCESS_TOKEN` en Netlify si la URL debe ser personal.
- Revisá el consumo de créditos y los logs de la función.
- El historial se guarda en el dispositivo, no en el repositorio.
- La función limita historial, tamaño y frecuencia de solicitudes.

## Próximas mejoras

- Conversaciones múltiples.
- Importación de logs y archivos.
- Respuestas en streaming.
- Autenticación con cuenta personal.
- Pruebas automatizadas.
