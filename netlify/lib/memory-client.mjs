const DEFAULT_TIMEOUT_MS = 4000
const TOKEN_EXPIRY_SKEW_MS = 30000

let cachedAccessToken = null
let cachedAccessTokenExpiresAt = 0
let pendingAccessTokenPromise = null

function env(name) {
  return process.env[name]?.trim() || ''
}

function normalizeBaseUrl(value) {
  return value.replace(/\/+$/, '')
}

function resolveConfig() {
  const baseUrl = normalizeBaseUrl(env('NOXAS_MEMORY_BASE_URL'))
  const tokenUrl = env('NOXAS_MEMORY_TOKEN_URL')
  const clientId = env('NOXAS_MEMORY_CLIENT_ID')
  const clientSecret = env('NOXAS_MEMORY_CLIENT_SECRET')
  const configured = Boolean(baseUrl && tokenUrl && clientId && clientSecret)
  const requestedTimeout = Number(env('NOXAS_MEMORY_TIMEOUT_MS') || DEFAULT_TIMEOUT_MS)
  const timeoutMs = Number.isFinite(requestedTimeout)
    ? Math.min(Math.max(requestedTimeout, 500), 15000)
    : DEFAULT_TIMEOUT_MS

  return {
    configured,
    baseUrl,
    tokenUrl,
    clientId,
    clientSecret,
    timeoutMs,
  }
}

export function getMemoryConfigurationStatus() {
  const config = resolveConfig()
  return {
    configured: config.configured,
    timeoutMs: config.timeoutMs,
  }
}

function basicAuthorization(clientId, clientSecret) {
  return `Basic ${Buffer.from(`${clientId}:${clientSecret}`, 'utf8').toString('base64')}`
}

async function parseJsonResponse(response, fallbackMessage) {
  const text = await response.text()
  if (!text) return {}

  try {
    return JSON.parse(text)
  } catch {
    throw new Error(fallbackMessage)
  }
}

async function requestAccessToken({ forceRefresh = false } = {}) {
  const config = resolveConfig()
  if (!config.configured) {
    throw new Error('Memory API no está configurada en el backend.')
  }

  const now = Date.now()
  if (!forceRefresh && cachedAccessToken && cachedAccessTokenExpiresAt > now) {
    return cachedAccessToken
  }
  if (!forceRefresh && pendingAccessTokenPromise) {
    return pendingAccessTokenPromise
  }

  const tokenRequest = (async () => {
    const response = await fetch(config.tokenUrl, {
      method: 'POST',
      headers: {
        Authorization: basicAuthorization(config.clientId, config.clientSecret),
        'Content-Type': 'application/x-www-form-urlencoded; charset=utf-8',
        Accept: 'application/json',
      },
      signal: AbortSignal.timeout(config.timeoutMs),
      body: new URLSearchParams({ grant_type: 'client_credentials' }).toString(),
    })

    const data = await parseJsonResponse(response, 'OAuth devolvió una respuesta inválida.')
    if (!response.ok) {
      throw new Error(`OAuth de Memory API devolvió HTTP ${response.status}.`)
    }

    const accessToken = typeof data?.access_token === 'string' ? data.access_token.trim() : ''
    if (!accessToken) {
      throw new Error('OAuth no devolvió access_token.')
    }

    const expiresInSeconds = Number(data?.expires_in)
    const lifetimeMs = Number.isFinite(expiresInSeconds) && expiresInSeconds > 0
      ? expiresInSeconds * 1000
      : 300000

    cachedAccessToken = accessToken
    cachedAccessTokenExpiresAt = Date.now() + Math.max(lifetimeMs - TOKEN_EXPIRY_SKEW_MS, 1000)
    return cachedAccessToken
  })()

  pendingAccessTokenPromise = tokenRequest
  try {
    return await tokenRequest
  } finally {
    if (pendingAccessTokenPromise === tokenRequest) pendingAccessTokenPromise = null
  }
}

function buildMemoryUrl(path, query) {
  const config = resolveConfig()
  const suffix = String(path || '').replace(/^\/+/, '')
  const url = new URL(`${config.baseUrl}/${suffix}`)

  if (query) {
    for (const [key, value] of Object.entries(query)) {
      if (value !== undefined && value !== null && value !== '') {
        url.searchParams.set(key, String(value))
      }
    }
  }

  return url
}

async function requestMemory(path, { query, retryUnauthorized = true } = {}) {
  const config = resolveConfig()
  if (!config.configured) {
    throw new Error('Memory API no está configurada en el backend.')
  }

  const token = await requestAccessToken()
  const response = await fetch(buildMemoryUrl(path, query), {
    method: 'GET',
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: 'application/json',
    },
    signal: AbortSignal.timeout(config.timeoutMs),
  })

  if (response.status === 401 && retryUnauthorized) {
    cachedAccessToken = null
    cachedAccessTokenExpiresAt = 0
    await requestAccessToken({ forceRefresh: true })
    return requestMemory(path, { query, retryUnauthorized: false })
  }

  const data = await parseJsonResponse(response, `Memory API devolvió un formato inválido (HTTP ${response.status}).`)
  if (!response.ok) {
    const apiCode = typeof data?.error?.code === 'string' ? ` (${data.error.code})` : ''
    throw new Error(`Memory API devolvió HTTP ${response.status}${apiCode}.`)
  }

  return data
}

export async function memoryHealth() {
  return requestMemory('health/')
}

export async function listMemories({
  userId,
  scope,
  type,
  status = 'ACTIVE',
  maxResults = 20,
} = {}) {
  const boundedMaxResults = Math.min(Math.max(Number(maxResults) || 20, 1), 50)
  return requestMemory('memories/', {
    query: {
      user_id: userId,
      scope,
      type,
      status,
      max_results: boundedMaxResults,
    },
  })
}

export async function getMemory(memoryId) {
  const id = String(memoryId || '').trim()
  if (!/^[0-9A-Fa-f]{32}$/.test(id)) {
    throw new Error('memoryId debe contener 32 caracteres hexadecimales.')
  }

  return requestMemory(`memories/${id.toUpperCase()}`)
}

export async function loadActiveAgentMemories({ maxResultsPerScope = 10 } = {}) {
  const configuration = getMemoryConfigurationStatus()
  if (!configuration.configured) {
    return {
      configured: false,
      connected: false,
      items: [],
      warnings: ['Memory API no configurada.'],
    }
  }

  const scopes = ['PROJECT', 'SYSTEM']
  const results = await Promise.allSettled(
    scopes.map((scope) => listMemories({ scope, status: 'ACTIVE', maxResults: maxResultsPerScope })),
  )

  const items = []
  const warnings = []
  let successfulRequests = 0

  results.forEach((result, index) => {
    if (result.status === 'fulfilled') {
      successfulRequests += 1
      if (Array.isArray(result.value?.items)) {
        items.push(...result.value.items)
      }
      return
    }

    const message = result.reason instanceof Error ? result.reason.message : 'Error desconocido.'
    warnings.push(`${scopes[index]}: ${message}`)
  })

  return {
    configured: true,
    connected: successfulRequests > 0,
    items,
    warnings,
  }
}

export function resetMemoryClientCacheForTests() {
  cachedAccessToken = null
  cachedAccessTokenExpiresAt = 0
  pendingAccessTokenPromise = null
}
