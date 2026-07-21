const SYSTEM_PROMPT = `Tu nombre es XAS. Sos un asistente especializado en soporte técnico, análisis de incidentes, Oracle EBS, Siebel, SQL, PL/SQL y Windows.

Antes de responder, separá hechos comprobables, hipótesis y datos faltantes. No inventes tablas, permisos, resultados, causas ni accesos. Cuando recibas un error o log, explicá qué indica, cuál es la causa más probable, cómo validarla y cuál es el siguiente paso seguro. Priorizá consultas de diagnóstico y evitá proponer UPDATE, DELETE o INSERT en producción salvo pedido explícito, aclarando siempre el riesgo. Respondé en español rioplatense claro, con pasos concretos y verificables. Mostrá conclusiones útiles, no una cadena de pensamiento privada.`

const DEFAULT_MODEL = process.env.XAS_CLOUD_MODEL || 'gpt-5.4-mini'
const MAX_MESSAGES = 20
const MAX_TOTAL_CHARS = 40000
const MAX_OUTPUT_TOKENS = Number(process.env.XAS_MAX_OUTPUT_TOKENS || 1200)
const ALLOWED_EFFORTS = new Set(['none', 'minimal', 'low', 'medium', 'high'])

function json(data, status = 200) {
  return Response.json(data, {
    status,
    headers: {
      'Cache-Control': 'no-store',
      'X-Content-Type-Options': 'nosniff',
    },
  })
}

function isAuthorized(request) {
  const expected = process.env.XAS_ACCESS_TOKEN?.trim()
  if (!expected) return true
  return request.headers.get('authorization') === `Bearer ${expected}`
}

function sanitizeMessages(input) {
  if (!Array.isArray(input)) return []

  const messages = input
    .filter((item) => item && ['user', 'assistant'].includes(item.role) && typeof item.content === 'string')
    .slice(-MAX_MESSAGES)
    .map(({ role, content }) => ({ role, content: content.trim().slice(0, 12000) }))
    .filter((item) => item.content)

  const totalChars = messages.reduce((sum, item) => sum + item.content.length, 0)
  if (totalChars > MAX_TOTAL_CHARS) throw new Error('La conversación supera el tamaño permitido.')

  return messages
}

export default async function handler(request) {
  if (request.method === 'GET') {
    return json({ ok: true, provider: 'Netlify AI Gateway', model: DEFAULT_MODEL })
  }

  if (request.method !== 'POST') {
    return json({ error: { message: 'Método no permitido.' } }, 405)
  }

  if (!isAuthorized(request)) {
    return json({ error: { message: 'Código de acceso incorrecto o ausente.' } }, 401)
  }

  const baseUrl = process.env.OPENAI_BASE_URL
  const apiKey = process.env.OPENAI_API_KEY
  if (!baseUrl || !apiKey) {
    return json({
      error: {
        message: 'AI Gateway todavía no está activo. Hacé al menos un deploy de producción y verificá que las funciones de IA estén habilitadas en Netlify.',
      },
    }, 503)
  }

  try {
    const rawBody = await request.text()
    if (rawBody.length > 100000) return json({ error: { message: 'Solicitud demasiado grande.' } }, 413)

    const body = rawBody ? JSON.parse(rawBody) : {}
    const messages = sanitizeMessages(body.messages)
    if (!messages.some((item) => item.role === 'user')) {
      return json({ error: { message: 'Falta un mensaje del usuario.' } }, 400)
    }

    const reasoningEffort = ALLOWED_EFFORTS.has(body.reasoning_effort)
      ? body.reasoning_effort
      : 'low'

    const upstream = await fetch(`${baseUrl.replace(/\/$/, '')}/v1/chat/completions`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      signal: AbortSignal.timeout(55000),
      body: JSON.stringify({
        model: DEFAULT_MODEL,
        messages: [{ role: 'system', content: SYSTEM_PROMPT }, ...messages],
        reasoning_effort: reasoningEffort,
        max_completion_tokens: Number.isFinite(MAX_OUTPUT_TOKENS) ? MAX_OUTPUT_TOKENS : 1200,
        store: false,
      }),
    })

    const text = await upstream.text()
    let data
    try {
      data = text ? JSON.parse(text) : {}
    } catch {
      return json({ error: { message: `El proveedor respondió un formato inválido (${upstream.status}).` } }, 502)
    }

    if (!upstream.ok) {
      const message = data?.error?.message || `El proveedor devolvió HTTP ${upstream.status}.`
      return json({ error: { message } }, upstream.status)
    }

    const content = data?.choices?.[0]?.message?.content?.trim()
    if (!content) return json({ error: { message: 'El modelo respondió sin contenido.' } }, 502)

    return json({
      choices: [{ message: { role: 'assistant', content } }],
      model: data.model || DEFAULT_MODEL,
      usage: data.usage || null,
    })
  } catch (error) {
    const timedOut = error?.name === 'TimeoutError' || error?.name === 'AbortError'
    return json({
      error: {
        message: timedOut
          ? 'La IA en la nube tardó demasiado. Probá nuevamente con una consulta más corta.'
          : error instanceof Error
            ? error.message
            : 'No se pudo procesar la solicitud.',
      },
    }, timedOut ? 504 : 500)
  }
}

export const config = {
  path: '/api/chat',
  rateLimit: {
    windowLimit: 20,
    windowSize: 60,
    aggregateBy: ['ip', 'domain'],
  },
}
