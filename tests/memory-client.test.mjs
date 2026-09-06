import test from 'node:test'
import assert from 'node:assert/strict'

import {
  getMemoryConfigurationStatus,
  loadActiveAgentMemories,
  memoryHealth,
  resetMemoryClientCacheForTests,
} from '../netlify/lib/memory-client.mjs'

const MEMORY_ENV_KEYS = [
  'NOXAS_MEMORY_BASE_URL',
  'NOXAS_MEMORY_TOKEN_URL',
  'NOXAS_MEMORY_CLIENT_ID',
  'NOXAS_MEMORY_CLIENT_SECRET',
  'NOXAS_MEMORY_TIMEOUT_MS',
]

function clearMemoryEnv() {
  for (const key of MEMORY_ENV_KEYS) delete process.env[key]
}

function configureMemoryEnv() {
  process.env.NOXAS_MEMORY_BASE_URL = 'http://localhost:8080/ords/noxas/memory/v1/'
  process.env.NOXAS_MEMORY_TOKEN_URL = 'http://localhost:8080/ords/noxas/oauth/token'
  process.env.NOXAS_MEMORY_CLIENT_ID = 'test-client'
  process.env.NOXAS_MEMORY_CLIENT_SECRET = 'test-secret'
}

function jsonResponse(status, body) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })
}

test.beforeEach(() => {
  clearMemoryEnv()
  resetMemoryClientCacheForTests()
})

test.afterEach(() => {
  clearMemoryEnv()
  resetMemoryClientCacheForTests()
})

test('reporta Memory API sin configurar sin intentar requests', async () => {
  let fetchCalls = 0
  globalThis.fetch = async () => {
    fetchCalls += 1
    throw new Error('fetch no debería ejecutarse')
  }

  assert.deepEqual(getMemoryConfigurationStatus(), {
    configured: false,
    timeoutMs: 4000,
  })

  const result = await loadActiveAgentMemories()
  assert.equal(result.configured, false)
  assert.equal(result.connected, false)
  assert.deepEqual(result.items, [])
  assert.equal(fetchCalls, 0)
})

test('reutiliza un único token OAuth para PROJECT y SYSTEM', async () => {
  configureMemoryEnv()
  let tokenCalls = 0
  const memoryScopes = []

  globalThis.fetch = async (input, options = {}) => {
    const url = new URL(String(input))
    if (url.pathname.endsWith('/oauth/token')) {
      tokenCalls += 1
      assert.match(options.headers.Authorization, /^Basic /)
      return jsonResponse(200, { access_token: 'token-1', expires_in: 300 })
    }

    assert.equal(options.headers.Authorization, 'Bearer token-1')
    memoryScopes.push(url.searchParams.get('scope'))
    return jsonResponse(200, {
      items: [{ memoryId: `${memoryScopes.length}`.padStart(32, '0'), scope: url.searchParams.get('scope') }],
    })
  }

  const result = await loadActiveAgentMemories({ maxResultsPerScope: 5 })
  assert.equal(result.configured, true)
  assert.equal(result.connected, true)
  assert.equal(result.items.length, 2)
  assert.equal(tokenCalls, 1)
  assert.deepEqual(memoryScopes.sort(), ['PROJECT', 'SYSTEM'])
})

test('renueva el token una vez si Memory API responde 401', async () => {
  configureMemoryEnv()
  let tokenCalls = 0
  let healthCalls = 0

  globalThis.fetch = async (input, options = {}) => {
    const url = new URL(String(input))
    if (url.pathname.endsWith('/oauth/token')) {
      tokenCalls += 1
      return jsonResponse(200, { access_token: `token-${tokenCalls}`, expires_in: 300 })
    }

    healthCalls += 1
    if (healthCalls === 1) {
      assert.equal(options.headers.Authorization, 'Bearer token-1')
      return jsonResponse(401, { error: { code: 'UNAUTHORIZED' } })
    }

    assert.equal(options.headers.Authorization, 'Bearer token-2')
    return jsonResponse(200, { ok: true })
  }

  const result = await memoryHealth()
  assert.equal(result.ok, true)
  assert.equal(tokenCalls, 2)
  assert.equal(healthCalls, 2)
})

test('degrada por scope sin tirar abajo toda la carga de memoria', async () => {
  configureMemoryEnv()

  globalThis.fetch = async (input) => {
    const url = new URL(String(input))
    if (url.pathname.endsWith('/oauth/token')) {
      return jsonResponse(200, { access_token: 'token-ok', expires_in: 300 })
    }

    const scope = url.searchParams.get('scope')
    if (scope === 'PROJECT') {
      return jsonResponse(200, { items: [{ memoryId: 'A'.repeat(32), scope: 'PROJECT' }] })
    }

    return jsonResponse(503, { error: { code: 'TEMPORARY_FAILURE' } })
  }

  const result = await loadActiveAgentMemories()
  assert.equal(result.connected, true)
  assert.equal(result.items.length, 1)
  assert.equal(result.warnings.length, 1)
  assert.match(result.warnings[0], /^SYSTEM:/)
})
