import test from 'node:test'
import assert from 'node:assert/strict'

import handler from '../netlify/functions/agent.mjs'
import { resetMemoryClientCacheForTests } from '../netlify/lib/memory-client.mjs'

const ORIGINAL_FETCH = globalThis.fetch
const ENV_KEYS = [
  'OPENAI_BASE_URL',
  'OPENAI_API_KEY',
  'NETLIFY_AI_GATEWAY_BASE_URL',
  'NETLIFY_AI_GATEWAY_KEY',
  'XAS_ACCESS_TOKEN',
  'NOXAS_MEMORY_BASE_URL',
  'NOXAS_MEMORY_TOKEN_URL',
  'NOXAS_MEMORY_CLIENT_ID',
  'NOXAS_MEMORY_CLIENT_SECRET',
  'NOXAS_MEMORY_TIMEOUT_MS',
]

function clearEnv() {
  for (const key of ENV_KEYS) delete process.env[key]
}

function configureGateway() {
  process.env.OPENAI_BASE_URL = 'https://provider.test/v1'
  process.env.OPENAI_API_KEY = 'provider-key'
}

function configureMemory() {
  process.env.NOXAS_MEMORY_BASE_URL = 'https://memory.test/ords/noxas/memory/v1/'
  process.env.NOXAS_MEMORY_TOKEN_URL = 'https://memory.test/ords/noxas/oauth/token'
  process.env.NOXAS_MEMORY_CLIENT_ID = 'memory-client'
  process.env.NOXAS_MEMORY_CLIENT_SECRET = 'memory-secret'
}

function jsonResponse(status, body) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })
}

function providerToolCall(query) {
  return {
    id: 'resp-tool',
    status: 'completed',
    model: 'test-model',
    output: [{
      type: 'function_call',
      name: 'search_project_knowledge',
      call_id: 'call-memory',
      arguments: JSON.stringify({ query }),
    }],
    usage: { input_tokens: 10, output_tokens: 5, total_tokens: 15 },
  }
}

function providerFinal(text = 'Respuesta final') {
  return {
    id: 'resp-final',
    status: 'completed',
    model: 'test-model',
    output: [{
      type: 'message',
      content: [{ type: 'output_text', text }],
    }],
    usage: { input_tokens: 20, output_tokens: 8, total_tokens: 28 },
  }
}

function postRequest(content) {
  return new Request('https://noxas.test/api/agent', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      messages: [{ role: 'user', content }],
      reasoning_effort: 'low',
      max_steps: 3,
    }),
  })
}

test.beforeEach(() => {
  clearEnv()
  resetMemoryClientCacheForTests()
  configureGateway()
})

test.afterEach(() => {
  globalThis.fetch = ORIGINAL_FETCH
  clearEnv()
  resetMemoryClientCacheForTests()
})

test('GET /api/agent informa health real de Memory API sin exponer secretos', async () => {
  configureMemory()

  globalThis.fetch = async (input) => {
    const url = new URL(String(input))
    if (url.pathname.endsWith('/oauth/token')) {
      return jsonResponse(200, { access_token: 'memory-token', expires_in: 300 })
    }
    if (url.pathname.endsWith('/health/')) {
      return jsonResponse(200, { ok: true, memoryCount: 7 })
    }
    throw new Error(`Request inesperado: ${url}`)
  }

  const response = await handler(new Request('https://noxas.test/api/agent'))
  const body = await response.json()

  assert.equal(response.status, 200)
  assert.equal(body.oracleMemoryConnected, true)
  assert.equal(body.oracleMemory.configured, true)
  assert.equal(body.oracleMemory.connected, true)
  assert.equal(body.oracleMemory.memoryCount, 7)
  assert.equal(JSON.stringify(body).includes('memory-secret'), false)
  assert.equal(JSON.stringify(body).includes('memory-client'), false)
})

test('search_project_knowledge usa memoria ACTIVE PROJECT/SYSTEM y lee el contenido completo', async () => {
  configureMemory()
  const memoryId = 'A'.repeat(32)
  let providerCalls = 0
  let observedToolOutput = null

  globalThis.fetch = async (input, options = {}) => {
    const url = new URL(String(input))

    if (url.pathname.endsWith('/oauth/token')) {
      return jsonResponse(200, { access_token: 'memory-token', expires_in: 300 })
    }

    if (url.pathname.endsWith('/memories/')) {
      const scope = url.searchParams.get('scope')
      return jsonResponse(200, {
        items: scope === 'PROJECT'
          ? [{
              memoryId,
              scope: 'PROJECT',
              type: 'TECHNICAL_NOTE',
              status: 'ACTIVE',
              title: 'Proyecto Epsilon',
              contentPreview: 'Epsilon usa una estrategia de retención específica.',
            }]
          : [],
      })
    }

    if (url.pathname.endsWith(`/memories/${memoryId}`)) {
      return jsonResponse(200, {
        memoryId,
        scope: 'PROJECT',
        type: 'TECHNICAL_NOTE',
        status: 'ACTIVE',
        title: 'Proyecto Epsilon',
        contentText: 'Epsilon conserva memoria persistente mediante ORDS y Oracle con OAuth2.',
        confidenceScore: 0.95,
        importanceScore: 0.8,
      })
    }

    if (url.pathname.endsWith('/responses')) {
      providerCalls += 1
      const requestBody = JSON.parse(options.body)
      if (providerCalls === 1) {
        return jsonResponse(200, providerToolCall('epsilon retencion'))
      }

      const toolResult = requestBody.input.find((item) => item?.type === 'function_call_output')
      assert.ok(toolResult)
      observedToolOutput = JSON.parse(toolResult.output)
      return jsonResponse(200, providerFinal('Memoria Oracle consultada.'))
    }

    throw new Error(`Request inesperado: ${url}`)
  }

  const response = await handler(postRequest('Revisá la memoria de Epsilon.'))
  const body = await response.json()

  assert.equal(response.status, 200)
  assert.equal(body.oracleMemoryConnected, true)
  assert.equal(body.oracleMemory.loadedItems, 1)
  assert.equal(providerCalls, 2)
  assert.ok(observedToolOutput.matches.some((item) => (
    item.source === 'oracle-memory'
    && item.text.includes('ORDS y Oracle con OAuth2')
    && item.degraded === false
  )))
})

test('si Memory API falla el agente conserva PROJECT_KNOWLEDGE local como fallback', async () => {
  configureMemory()
  let providerCalls = 0
  let observedToolOutput = null

  globalThis.fetch = async (input, options = {}) => {
    const url = new URL(String(input))

    if (url.pathname.endsWith('/oauth/token')) {
      return jsonResponse(200, { access_token: 'memory-token', expires_in: 300 })
    }

    if (url.pathname.endsWith('/memories/')) {
      return jsonResponse(503, { error: { code: 'TEMPORARY_FAILURE' } })
    }

    if (url.pathname.endsWith('/responses')) {
      providerCalls += 1
      const requestBody = JSON.parse(options.body)
      if (providerCalls === 1) {
        return jsonResponse(200, providerToolCall('arquitectura react vite'))
      }

      const toolResult = requestBody.input.find((item) => item?.type === 'function_call_output')
      assert.ok(toolResult)
      observedToolOutput = JSON.parse(toolResult.output)
      return jsonResponse(200, providerFinal('Fallback local correcto.'))
    }

    throw new Error(`Request inesperado: ${url}`)
  }

  const response = await handler(postRequest('Inspeccioná la arquitectura actual.'))
  const body = await response.json()

  assert.equal(response.status, 200)
  assert.equal(body.oracleMemoryConnected, false)
  assert.equal(body.oracleMemory.warningCount, 2)
  assert.equal(providerCalls, 2)
  assert.ok(observedToolOutput.matches.some((item) => item.source === 'local'))
  assert.equal(observedToolOutput.memory.connected, false)
})
// Verifica que propose_action detenga el agente sin una segunda llamada al modelo.
test('propose_action detiene el agente inmediatamente en WAITING_APPROVAL', async () => {
  let providerCalls = 0

  globalThis.fetch = async (input) => {
    const url = new URL(String(input))

    if (url.pathname.endsWith('/responses')) {
      providerCalls += 1

      if (providerCalls > 1) {
        throw new Error('El agente no debe volver a llamar al modelo después de propose_action.')
      }

      return jsonResponse(200, {
        id: 'resp-approval',
        status: 'completed',
        model: 'test-model',
        output: [{
          type: 'function_call',
          name: 'propose_action',
          call_id: 'call-approval',
          arguments: JSON.stringify({
            action_type: 'CODE_CHANGE',
            description: 'Modificar configuración del agente.',
            risk: 'MEDIUM',
            reversible: true,
            preview: 'Aplicar cambio controlado en agent.mjs.',
          }),
        }],
        usage: {
          input_tokens: 12,
          output_tokens: 6,
          total_tokens: 18,
        },
      })
    }

    throw new Error(`Request inesperado: ${url}`)
  }

  const response = await handler(
    postRequest('Aplicá un cambio en el agente.'),
  )
  const body = await response.json()

  assert.equal(response.status, 200)
  assert.equal(body.status, 'WAITING_APPROVAL')
  assert.equal(providerCalls, 1)

  assert.deepEqual(body.approvalRequired, {
    actionType: 'CODE_CHANGE',
    description: 'Modificar configuración del agente.',
    risk: 'MEDIUM',
    reversible: true,
    preview: 'Aplicar cambio controlado en agent.mjs.',
  })

  assert.equal(
    body.choices[0].message.content,
    'La acción propuesta requiere aprobación humana antes de continuar.',
  )

  assert.ok(
    body.trace.some((item) => (
      item.type === 'TOOL_RESULT'
      && item.tool === 'propose_action'
      && item.ok === true
    )),
  )

  assert.ok(
    body.trace.some((item) => (
      item.type === 'WAITING_APPROVAL'
      && item.tool === 'propose_action'
    )),
  )
})
