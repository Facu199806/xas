# Publicar XAS en Netlify

Esta versión permite usar XAS sin dejar una PC encendida:

- La interfaz React se publica en Netlify.
- `/api/chat` se ejecuta como Netlify Function.
- La función llama a Netlify AI Gateway.
- El historial y el código de acceso se guardan sólo en el navegador del dispositivo.
- En `localhost`, XAS conserva el modo local con Ollama.

## 1. Crear el sitio

1. Iniciá sesión en Netlify.
2. Elegí **Add new project**.
3. Seleccioná **Import an existing project**.
4. Conectá GitHub.
5. Elegí el repositorio `Facu199806/xas`.
6. Netlify debería detectar:
   - Build command: `npm run build`
   - Publish directory: `dist`
   - Functions directory: `netlify/functions`
7. Hacé un deploy de producción.

El archivo `netlify.toml` ya contiene esa configuración.

## 2. Requisitos de AI Gateway

AI Gateway requiere:

- un plan de Netlify basado en créditos, incluido el plan Free actual;
- al menos un deploy de producción;
- las funciones de IA habilitadas para el equipo;
- créditos disponibles.

### Verificar el plan

Desde el panel del equipo:

1. Abrí **Usage & billing**.
2. Entrá en **Plan details** o **Billing details**.
3. Comprobá que el plan indique que está basado en créditos.

Las cuentas antiguas pueden conservar un plan Legacy. AI Gateway no está disponible en planes Legacy. El cambio a un plan basado en créditos es irreversible, por lo que conviene revisar las condiciones antes de confirmarlo.

### Verificar las funciones de IA

Como Team Owner:

1. Volvé al panel general del equipo.
2. Entrá en **Team settings**.
3. Abrí **AI enablement**.
4. Seleccioná **Configure** y habilitá las funciones de IA.

## 3. Credenciales automáticas

Netlify inyecta automáticamente variables para AI Gateway dentro de la Function.

XAS acepta primero:

- `OPENAI_API_KEY`
- `OPENAI_BASE_URL`

Y, como alternativa explícita:

- `NETLIFY_AI_GATEWAY_KEY`
- `NETLIFY_AI_GATEWAY_BASE_URL`

No copies estas variables desde otro sitio ni inventes valores manuales. Si existe sólo una variable `OPENAI_API_KEY` o `OPENAI_BASE_URL` configurada por vos, Netlify no completa automáticamente el par y la conexión puede quedar incompleta. En ese caso, eliminá las variables manuales y hacé un nuevo deploy.

Nunca guardes claves privadas en GitHub ni en variables cuyo nombre comience con `VITE_`, porque esas variables llegan al navegador.

## 4. Variables opcionales de XAS

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

Después de agregar o cambiar variables, ejecutá un nuevo deploy de producción.

## 5. Diagnóstico

Abrí:

```text
https://TU-SITIO.netlify.app/api/chat
```

Con AI Gateway disponible debe responder con:

```json
{
  "ok": true,
  "provider": "Netlify AI Gateway",
  "credentialSource": "openai"
}
```

También puede mostrar `credentialSource: "netlify"` cuando utiliza las variables universales del gateway.

Si devuelve `ok: false`, el objeto `diagnostics` sólo muestra si cada variable existe mediante valores `true` o `false`. No expone las claves.

Interpretación habitual:

- Todas en `false`: plan Legacy, AI Features deshabilitadas o deploy sin AI Gateway.
- Sólo una variable OpenAI en `true`: configuración manual incompleta en Environment variables.
- Variables Netlify en `true`: el fallback explícito debería permitir la conexión.

## 6. Validación de XAS

Abrí la URL de Netlify y comprobá:

1. El encabezado muestra `Modo nube`.
2. El indicador muestra `Nube conectada` sólo cuando el gateway está realmente disponible.
3. `Hola` recibe una respuesta breve.
4. Un error como `ORA-01722` activa razonamiento técnico.
5. El tema claro/oscuro cambia y persiste.
6. Al recargar, el historial continúa en el mismo dispositivo.

## 7. Instalar en Android

1. Abrí el sitio con Chrome.
2. Tocá el menú de tres puntos.
3. Elegí **Instalar aplicación** o **Agregar a la pantalla principal**.
4. Abrí XAS desde el nuevo ícono.

## 8. Instalar en iPhone o iPad

1. Abrí el sitio con Safari.
2. Tocá **Compartir**.
3. Elegí **Agregar a inicio**.
4. Confirmá el nombre XAS.

## 9. Funcionamiento local

Para seguir usando Ollama en la PC:

```bash
cp .env.example .env
npm install
npm run dev
```

El `.env.example` fija `VITE_AI_MODE=local`. En un dominio publicado, si esa variable no se define, XAS usa automáticamente el modo cloud.

## Seguridad y límites

- No publiques claves privadas ni `XAS_ACCESS_TOKEN` en GitHub.
- La función limita tamaño de mensajes, historial y frecuencia de solicitudes.
- El código de acceso es recomendable si la URL no debe ser usada por terceros.
- Revisá periódicamente el consumo de créditos en Netlify.
