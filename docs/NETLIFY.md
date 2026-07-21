# Publicar XAS en Netlify

Esta versión permite usar XAS sin dejar una PC encendida:

- La interfaz React se publica en Netlify.
- `/api/chat` se ejecuta como Netlify Function.
- La función llama a Netlify AI Gateway.
- El historial y el código de acceso se guardan sólo en el navegador del dispositivo.
- En `localhost`, XAS conserva el modo local con Ollama.

## 1. Fusionar la rama

Fusioná la pull request de `deploy-netlify-mobile` hacia `main`.

En la PC, actualizá después con:

```bash
git switch main
git pull --ff-only origin main
```

## 2. Crear el sitio

1. Iniciá sesión en Netlify.
2. Elegí **Add new project**.
3. Seleccioná **Import an existing project**.
4. Conectá GitHub.
5. Elegí el repositorio `Facu199806/xas`.
6. Netlify debería detectar:
   - Build command: `npm run build`
   - Publish directory: `dist`
   - Functions directory: `netlify/functions`
7. Hacé el primer deploy de producción.

El archivo `netlify.toml` ya contiene esa configuración.

## 3. Activar AI Gateway

AI Gateway requiere un plan de créditos actual, incluido Free, y al menos un deploy de producción.

En la configuración del equipo o proyecto verificá que las funciones de IA estén habilitadas. La función usa automáticamente:

- `OPENAI_API_KEY`
- `OPENAI_BASE_URL`

Netlify las inyecta para AI Gateway. No deben guardarse claves dentro del repositorio ni en variables `VITE_*`.

## 4. Variables opcionales

En **Project configuration > Environment variables** podés agregar:

```text
XAS_CLOUD_MODEL=gpt-5.4-mini
XAS_MAX_OUTPUT_TOKENS=1200
XAS_ACCESS_TOKEN=un-codigo-largo-y-privado
```

- `XAS_CLOUD_MODEL`: modelo usado por la función.
- `XAS_MAX_OUTPUT_TOKENS`: límite de salida por respuesta.
- `XAS_ACCESS_TOKEN`: protección opcional del chat.

Si definís `XAS_ACCESS_TOKEN`, ingresá el mismo valor en el campo **Código de acceso** dentro de XAS. El código se guarda localmente en ese navegador.

Después de agregar o cambiar variables, ejecutá un nuevo deploy.

## 5. Validación

Abrí la URL de Netlify y comprobá:

1. El encabezado del chat muestra `Modo nube`.
2. El indicador muestra `Nube conectada`.
3. `Hola` recibe una respuesta breve.
4. Un error como `ORA-01722` activa razonamiento técnico.
5. El tema claro/oscuro cambia y persiste.
6. Al recargar, el historial continúa en el mismo dispositivo.

También podés comprobar el backend abriendo:

```text
https://TU-SITIO.netlify.app/api/chat
```

Debe devolver un JSON con `ok: true`.

## 6. Instalar en Android

1. Abrí el sitio con Chrome.
2. Tocá el menú de tres puntos.
3. Elegí **Instalar aplicación** o **Agregar a la pantalla principal**.
4. Abrí XAS desde el nuevo ícono.

## 7. Instalar en iPhone o iPad

1. Abrí el sitio con Safari.
2. Tocá **Compartir**.
3. Elegí **Agregar a inicio**.
4. Confirmá el nombre XAS.

## 8. Funcionamiento local

Para seguir usando Ollama en la PC:

```bash
cp .env.example .env
npm install
npm run dev
```

El `.env.example` fija `VITE_AI_MODE=local`. En un dominio publicado, si esa variable no se define, XAS usa automáticamente el modo cloud.

## Seguridad y límites

- No publiques `OPENAI_API_KEY`, `XAS_ACCESS_TOKEN` ni otras claves en GitHub.
- La función limita tamaño de mensajes, historial y frecuencia de solicitudes.
- El código de acceso es recomendable si la URL no debe ser usada por terceros.
- Revisá periódicamente el consumo de créditos en Netlify.
