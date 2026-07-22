const STORE_KEY = 'xas-conversations-v1'
const LEGACY_HISTORY_KEY = 'xas-chat-history-v4'

export const STARTER_MESSAGE = {
  role: 'assistant',
  content: 'XAS listo. Pegá un error, log, consulta SQL o descripción de ticket y lo analizamos.',
}

function createId() {
  if (globalThis.crypto?.randomUUID) return globalThis.crypto.randomUUID()
  return `xas-${Date.now()}-${Math.random().toString(16).slice(2)}`
}

function normalizeMessages(messages) {
  if (!Array.isArray(messages)) return [{ ...STARTER_MESSAGE }]

  const validMessages = messages
    .filter((message) => message && ['user', 'assistant'].includes(message.role) && typeof message.content === 'string')
    .map(({ role, content }) => ({ role, content }))

  return validMessages.length ? validMessages : [{ ...STARTER_MESSAGE }]
}

export function deriveConversationTitle(text) {
  const normalized = String(text || '').replace(/\s+/g, ' ').trim()
  if (!normalized) return 'Nueva consulta'
  return normalized.length > 52 ? `${normalized.slice(0, 49).trim()}...` : normalized
}

export function createConversation({ title = 'Nueva consulta', messages, createdAt } = {}) {
  const timestamp = Date.now()
  return {
    id: createId(),
    title,
    messages: normalizeMessages(messages),
    createdAt: Number(createdAt) || timestamp,
    updatedAt: timestamp,
  }
}

function normalizeConversation(conversation) {
  if (!conversation || typeof conversation !== 'object') return null

  const messages = normalizeMessages(conversation.messages)
  const firstUserMessage = messages.find((message) => message.role === 'user')?.content
  const createdAt = Number(conversation.createdAt) || Date.now()

  return {
    id: typeof conversation.id === 'string' && conversation.id ? conversation.id : createId(),
    title:
      typeof conversation.title === 'string' && conversation.title.trim()
        ? conversation.title.trim()
        : deriveConversationTitle(firstUserMessage),
    messages,
    createdAt,
    updatedAt: Number(conversation.updatedAt) || createdAt,
  }
}

export function loadConversationState() {
  try {
    const stored = JSON.parse(localStorage.getItem(STORE_KEY))
    const conversations = Array.isArray(stored?.conversations)
      ? stored.conversations.map(normalizeConversation).filter(Boolean)
      : []

    if (conversations.length) {
      const activeExists = conversations.some((conversation) => conversation.id === stored.activeId)
      return {
        version: 1,
        activeId: activeExists ? stored.activeId : conversations[0].id,
        conversations,
      }
    }
  } catch {
    // Un almacenamiento dañado no debe impedir abrir XAS.
  }

  let legacyMessages
  try {
    legacyMessages = JSON.parse(localStorage.getItem(LEGACY_HISTORY_KEY))
  } catch {
    legacyMessages = null
  }

  const normalizedLegacy = normalizeMessages(legacyMessages)
  const firstUserMessage = normalizedLegacy.find((message) => message.role === 'user')?.content
  const conversation = createConversation({
    title: deriveConversationTitle(firstUserMessage),
    messages: normalizedLegacy,
  })

  return {
    version: 1,
    activeId: conversation.id,
    conversations: [conversation],
  }
}

export function saveConversationState(state) {
  try {
    localStorage.setItem(STORE_KEY, JSON.stringify(state))
  } catch {
    // El chat sigue funcionando aunque el navegador bloquee o complete el almacenamiento.
  }
}
