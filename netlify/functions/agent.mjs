const API_NAME = 'NOXAS Agent API'
const API_VERSION = '1.1.0'
const DEFAULT_MODEL = process.env.XAS_AGENT_MODEL || process.env.XAS_CLOUD_MODEL || 'gpt-5.4-mini'
const DEFAULT_MAX_STEPS = 5
const HARD_MAX_STEPS = 8
const MAX_MESSAGES = 20
const MAX_TOTAL_CHARS = 40000
const MAX_OUTPUT_TOKENS = Number(process.env.XAS_AGENT_MAX_OUTPUT_TOKENS || 1400)
const ALLOWED_EFFORTS = new Set(['none', 'minimal', 'low', 'medium', 'high'])

const SYSTEM_PROMPT = `Tu nombre es NOXAS. Sos un agente supervisado orientado a resolver tareas mediante análisis, herramientas y verificación.

MÉTODO DE TRABAJO
1. Entendé el objetivo real antes de actuar.
2. Sé intelectualmente curioso: buscá datos faltantes, contradicciones, relaciones y causas posibles.
3. Separá hechos comprobados, hipótesis, inferencias y preguntas pendientes.
4. Generá más de una hipótesis cuando la evidencia sea insuficiente y tratá de refutarlas.
5. Usá herramientas solamente cuando aporten evidencia o reduzcan incertidumbre.
6. No declares una tarea completada sin una comprobación razonable.
7. Mostrá conclusiones, evidencias y próximos pasos. No reveles una cadena de pensamiento privada.

LÍMITES
- Sólo podés consultar información del proyecto, datos que el usuario proporcione o fuentes expresamente autorizadas.
- No busques, infieras ni acumules datos personales de terceros, ubicaciones privadas, rutinas o identidades.
- No ejecutes escrituras, publicaciones, borrados, despliegues, DML, cambios de infraestructura ni comunicaciones externas sin aprobación explícita.
- Para una acción de escritura, usá la herramienta propose_action y detenete en estado de aprobación.
- No inventes accesos, resultados, archivos, tablas, permisos ni ejecuciones.
- Priorizá seguridad, reversibilidad, trazabilidad y bajo consumo de recursos.

Respondé en español rioplatense claro y técnico, con pasos concretos.`

const PROJECT_KNOWLEDGE = [
  {
    id: 'architecture-current',
    title: 'Arquitectura actual',
    text: 'NOXAS usa React y Vite en el frontend, Netlify Functions en el backend. El chat usa Chat Completions y el agente usa Responses API.',
    tags: ['arquitectura', 'react', 'vite', 'netlify', 'chat', 'responses'],
  },
  {
    id: 'oracle-local',
    title: 'Oracle de desarrollo',
    text: 'El esquema NOXAS_DEV corre en Oracle Database 23c Free dentro de FREEPDB1. La VM local no está disponible para la aplicación pública cuando la computadora está apagada.',
    tags: ['oracle', 'freepdb1', 'noxas_dev', 'base', 'vm'],
  },
  {
    id: 'agent-policy',
    title: 'Política del agente',
    text: 'NOXAS Agent v1 puede leer, analizar, calcular y proponer. Las acciones de escritura requieren aprobación humana explícita.',
    tags: ['agente', 'seguridad', 'aprobación', 'herramientas'],
  },
  {
    id: 'production-safety',
    title: 'Seguridad de producción',
    text: 'Las consultas de diagnóstico deben ser de sólo lectura. UPDATE, DELETE, INSERT, MERGE, despliegues y cambios de repositorio requieren validación y aprobación.',
    tags: ['producción', 'sql', 'dml', 'deploy', 'seguridad'],
  },
]

const TOOL_DEFINITIONS = [
  {
    type: 'function',
    name: 'search_project_knowledge',
    description: 'Busca hechos conocidos y autorizados sobre el proyecto NOXAS.',
    strict: true,
    parameters: {
      type: 'object',
      additionalProperties: false,
      properties: {
        query: { type: 'string', description: 'Tema o términos a buscar.' },
      },
      required: ['query'],
    },
  },
  {
    type: 'function',
    name: 'calculate',
    description: 'Realiza una operación aritmética segura con números y operadores básicos.',
    strict: true,
    parameters: {
      type: 'object',
      additionalProperties: false,
      properties: {
        expression: { type: 'string', description: 'Expresión con números, paréntesis y + - * / %.' },
      },
      required: ['expression'],
    },
  },
  {
    type: 'function',
    name: 'inspect_runtime',
    description: 'Devuelve capacidades y límites activos del agente, sin exponer secretos.',
    strict: true,
    parameters: {
      type: 'object',
      additionalProperties: false,
      properties: {},
      required: [],
    },
  },
  {
    type: 'function',
    name: 'propose_action',
    description: 'Registra una acción de escritura o externa que necesita aprobación humana antes de ejecutarse.',
    strict: true,
    parameters: {
      type: 'object',
      additionalProperties: false,
      properties: {
        action_type: {
          type: 'string',
          enum: ['CODE_CHANGE', 'DATABASE_WRITE', 'DEPLOY', 'EXTERNAL_MESSAGE', 'DELETE', 'INFRASTRUCTURE_CHANGE', 'OTHER'],
        },
        description: { type: 'string' },
        risk: { type: 'string', enum: ['LOW', 'MEDIUM', 'HIGH'] },
        reversible: { type: 'boolean' },
        preview: { type: 'string', description: 'Resumen, comando o cambio previsto sin ejecutarlo.' },
      },
      required: ['action_type', 'description', 'risk', 'reversible', 'preview'],
    },
  },
]

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-store',
      'X-Content-Type-Options': 'nosniff',
      'X-NOXAS-Agent-Version': API_VERSION,
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

function resolveGateway() {
  const openAiBaseUrl = process.env.OPENAI_BASE_URL?.trim()
  const openAiApiKey = process.env.OPENAI_API_KEY?.trim()
  if (openAiBaseUrl && openAiApiKey) {
    return { baseUrl: openAiBaseUrl, apiKey: openAiApiKey, source: 'openai' }
  }

  const gatewayBaseUrl = process.env.NETLIFY_AI_GATEWAY_BASE_URL?.trim()
  const gatewayKey = process.env.NETLIFY_AI_GATEWAY_KEY?.trim()
  if (gatewayBaseUrl && gatewayKey) {
    return { baseUrl: gatewayBaseUrl, apiKey: gatewayKey, source: 'netlify' }
  }

  return null
}

function responsesUrl(baseUrl) {
  const normalized = baseUrl.replace(/\/+$/, '')
  return /\/v1$/i.test(normalized)
    ? `${normalized}/responses`
    : `${normalized}/v1/responses`
}

function tokenize(value) {
  return value
    .toLocaleLowerCase('es-AR')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .split(/[^a-z0-9_]+/)
    .filter(Boolean)
}

function searchProjectKnowledge({ query }) {
  const terms = tokenize(String(query || '')).slice(0, 12)
  if (!terms.length) return { matches: [] }

  const matches = PROJECT_KNOWLEDGE
    .map((item) => {
      const haystack = tokenize(`${item.title} ${item.text} ${item.tags.join(' ')}`)
      const score = terms.reduce((total, term) => total + haystack.filter((word) => word.includes(term)).length, 0)
      return { ...item, score }
    })
    .filter((item) => item.score > 0)
    .sort((a, b) => b.score - a.score)
    .slice(0, 4)
    .map(({ score, ...item }) => item)

  return { query, matches }
}

function calculate({ expression }) {
  const input = String(expression || '').trim()
  if (!input || input.length > 120) throw new Error('Expresión vacía o demasiado larga.')
  if (!/^[0-9+\-*/%().\s]+$/.test(input)) {
    throw new Error('La expresión contiene caracteres no permitidos.')
  }

  const result = Function(`"use strict"; return (${input})`)()
  if (typeof result !== 'number' || !Number.isFinite(result)) {
    throw new Error('El resultado no es un número finito.')
  }
  if (Math.abs(result) > 1e18) throw new Error('El resultado excede el límite permitido.')

  return { expression: input, result }
}

function inspectRuntime() {
  return {
    api: API_NAME,
    version: API_VERSION,
    providerApi: 'responses',
    model: DEFAULT_MODEL,
    mode: 'SUPERVISED',
    maximumSteps: HARD_MAX_STEPS,
    supportedReasoningEfforts: Array.from(ALLOWED_EFFORTS),
    writeActionsRequireApproval: true,
    persistentOracleMemoryConnected: false,
    tools: TOOL_DEFINITIONS.map((tool) => tool.name),
  }
}

function proposeAction(args) {
  return {
    status: 'APPROVAL_REQUIRED',
    proposal: {
      actionType: args.action_type,
      description: String(args.description || '').slice(0, 1200),
      risk: args.risk,
      reversible: Boolean(args.reversible),
      preview: String(args.preview || '').slice(0, 4000),
    },
    executed: false,
  }
}

const TOOL_HANDLERS = {
  search_project_knowledge: searchProjectKnowledge,
  calculate,
  inspect_runtime: inspectRuntime,
  propose_action: proposeAction,
}

function parseToolArguments(raw) {
  if (!raw) return {}
  try {
    return JSON.parse(raw)
  } catch {
    throw new Error('El modelo envió argumentos de herramienta inválidos.')
  }
}

function extractResponseText(output) {
  if (!Array.isArray(output)) return ''

  return output
    .filter((item) => item?.type === 'message')
    .flatMap((item) => Array.isArray(item.content) ? item.content : [])
    .filter((item) => item?.type === 'output_text' && typeof item.text === 'string')
    .map((item) => item.text.trim())
    .filter(Boolean)
    .join('\n')
    .trim()
}

function summarizeUsage(usage) {
  return usage.reduce((summary, item) => {
    summary.calls += 1
    summary.inputTokens += Number(item?.input_tokens || 0)
    summary.outputTokens += Number(item?.output_tokens || 0)
    summary.reasoningTokens += Number(item?.output_tokens_details?.reasoning_tokens || 0)
    summary.totalTokens += Number(item?.total_tokens || 0)
    return summary
  }, {
    calls: 0,
    inputTokens: 0,
    outputTokens: 0,
    reasoningTokens: 0,
    totalTokens: 0,
  })
}

async function callModel({ gateway, input, reasoningEffort, tools = TOOL_DEFINITIONS }) {
  const upstream = await fetch(responsesUrl(gateway.baseUrl), {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${gateway.apiKey}`,
      'Content-Type': 'application/json; charset=utf-8',
      Accept: 'application/json',
    },
    signal: AbortSignal.timeout(55000),
    body: JSON.stringify({
      model: DEFAULT_MODEL,
      instructions: SYSTEM_PROMPT,
      input,
      tools: tools?.length ? tools : undefined,
      tool_choice: tools?.length ? 'auto' : undefined,
      reasoning: { effort: reasoningEffort },
      max_output_tokens: Number.isFinite(MAX_OUTPUT_TOKENS) ? MAX_OUTPUT_TOKENS : 1400,
      store: false,
    }),
  })

  const text = await upstream.text()
  let data
  try {
    data = text ? JSON.parse(text) : {}
  } catch {
    throw new Error(`El proveedor respondió un formato inválido (${upstream.status}).`)
  }

  if (!upstream.ok) {
    throw new Error(data?.error?.message || `El proveedor devolvió HTTP ${upstream.status}.`)
  }

  if (!Array.isArray(data.output)) {
    throw new Error('El proveedor respondió sin una salida válida.')
  }

  if (data.status === 'failed') {
    throw new Error(data?.error?.message || 'El proveedor no pudo completar la respuesta.')
  }

  return {
    output: data.output,
    content: extractResponseText(data.output),
    usage: data.usage || null,
    model: data.model || DEFAULT_MODEL,
    responseId: data.id || null,
    status: data.status || null,
    incompleteDetails: data.incomplete_details || null,
  }
}

async function runAgent({ gateway, messages, reasoningEffort, maxSteps }) {
  const input = messages.map(({ role, content }) => ({ role, content }))
  const trace = []
  const usage = []
  let approvalRequired = null
  let modelName = DEFAULT_MODEL

  for (let step = 1; step <= maxSteps; step += 1) {
    const result = await callModel({ gateway, input, reasoningEffort })
    modelName = result.model
    if (result.usage) usage.push(result.usage)

    const toolCalls = result.output.filter((item) => item?.type === 'function_call')
    trace.push({
      step,
      type: toolCalls.length ? 'TOOL_SELECTION' : 'FINAL_RESPONSE',
      tools: toolCalls.map((call) => call.name).filter(Boolean),
      responseId: result.responseId,
      status: result.status,
    })

    if (!toolCalls.length) {
      if (!result.content) {
        const reason = result.incompleteDetails?.reason
        throw new Error(reason
          ? `El agente finalizó sin contenido (${reason}).`
          : 'El agente finalizó sin contenido.')
      }
      return {
        content: result.content,
        trace,
        usage,
        usageSummary: summarizeUsage(usage),
        modelName,
        approvalRequired,
      }
    }

    // Responses API requiere conservar los elementos de salida, incluidos los
    // elementos de razonamiento, antes de agregar los resultados de funciones.
    input.push(...result.output)

    for (const toolCall of toolCalls) {
      const toolName = toolCall.name
      const handler = TOOL_HANDLERS[toolName]
      let output

      try {
        if (!handler) throw new Error(`Herramienta no permitida: ${toolName}`)
        const args = parseToolArguments(toolCall.arguments)
        output = await handler(args)
        if (toolName === 'propose_action') approvalRequired = output.proposal
      } catch (error) {
        output = {
          error: error instanceof Error ? error.message : 'Falló la herramienta.',
        }
      }

      trace.push({ step, type: 'TOOL_RESULT', tool: toolName, ok: !output?.error })
      input.push({
        type: 'function_call_output',
        call_id: toolCall.call_id,
        output: JSON.stringify(output),
      })
    }
  }

  input.push({
    role: 'developer',
    content: 'Alcanzaste el límite de pasos. Entregá una conclusión breve con lo comprobado, lo pendiente y cualquier aprobación requerida. No uses herramientas.',
  })

  const finalResult = await callModel({
    gateway,
    input,
    reasoningEffort: 'none',
    tools: [],
  })
  if (finalResult.usage) usage.push(finalResult.usage)

  const content = finalResult.content
    || 'El agente alcanzó el límite de pasos sin producir una conclusión.'

  return {
    content,
    trace,
    usage,
    usageSummary: summarizeUsage(usage),
    modelName: finalResult.model,
    approvalRequired,
  }
}

export default async function handler(request) {
  const gateway = resolveGateway()

  if (request.method === 'GET') {
    return json({
      ok: Boolean(gateway),
      api: { name: API_NAME, version: API_VERSION, endpoint: '/api/agent' },
      assistant: 'NOXAS',
      mode: 'SUPERVISED',
      providerApi: 'responses',
      model: DEFAULT_MODEL,
      credentialSource: gateway?.source || null,
      oracleMemoryConnected: false,
      supportedReasoningEfforts: Array.from(ALLOWED_EFFORTS),
      tools: TOOL_DEFINITIONS.map((tool) => tool.name),
      message: gateway
        ? 'NOXAS Agent v1.1 está disponible con razonamiento y herramientas mediante Responses API.'
        : 'No hay credenciales configuradas para el proveedor de IA.',
    }, gateway ? 200 : 503)
  }

  if (request.method !== 'POST') {
    return json({ error: { message: 'Método no permitido.' } }, 405)
  }

  if (!isAuthorized(request)) {
    return json({ error: { message: 'Código de acceso incorrecto o ausente.' } }, 401)
  }

  if (!gateway) {
    return json({ error: { message: 'No hay credenciales configuradas para el proveedor de IA.' } }, 503)
  }

  try {
    const rawBody = await request.text()
    if (rawBody.length > 100000) {
      return json({ error: { message: 'Solicitud demasiado grande.' } }, 413)
    }

    const body = rawBody ? JSON.parse(rawBody) : {}
    const messages = sanitizeMessages(body.messages)
    if (!messages.some((item) => item.role === 'user')) {
      return json({ error: { message: 'Falta un mensaje del usuario.' } }, 400)
    }

    const requestedSteps = Number(body.max_steps || DEFAULT_MAX_STEPS)
    const maxSteps = Math.min(
      Math.max(Number.isFinite(requestedSteps) ? requestedSteps : DEFAULT_MAX_STEPS, 1),
      HARD_MAX_STEPS,
    )
    const reasoningEffort = ALLOWED_EFFORTS.has(body.reasoning_effort)
      ? body.reasoning_effort
      : 'medium'

    const result = await runAgent({ gateway, messages, reasoningEffort, maxSteps })

    return json({
      api: { name: API_NAME, version: API_VERSION, endpoint: '/api/agent' },
      assistant: 'NOXAS',
      mode: 'SUPERVISED',
      providerApi: 'responses',
      reasoningEffort,
      choices: [{ message: { role: 'assistant', content: result.content } }],
      model: result.modelName,
      approvalRequired: result.approvalRequired,
      trace: result.trace,
      usage: result.usage,
      usageSummary: result.usageSummary,
      credentialSource: gateway.source,
    })
  } catch (error) {
    const timedOut = error?.name === 'TimeoutError' || error?.name === 'AbortError'
    const invalidJson = error instanceof SyntaxError
    return json({
      error: {
        message: timedOut
          ? 'El agente superó el tiempo disponible. Reducí el objetivo o la cantidad de pasos.'
          : invalidJson
            ? 'El cuerpo JSON de la solicitud es inválido.'
            : error instanceof Error
              ? error.message
              : 'No se pudo ejecutar el agente.',
      },
    }, timedOut ? 504 : invalidJson ? 400 : 500)
  }
}

export const config = {
  path: '/api/agent',
  rateLimit: {
    windowLimit: 10,
    windowSize: 60,
    aggregateBy: ['ip', 'domain'],
  },
}
