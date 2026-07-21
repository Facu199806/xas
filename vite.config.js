import { defineConfig, loadEnv } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '')
  const target = env.VITE_AI_PROXY_TARGET || 'http://localhost:11434'

  const createProxy = () => ({
    '/api': {
      target,
      changeOrigin: true,
      rewrite: (path) => path.replace(/^\/api/, ''),
      configure: (proxy) => {
        proxy.on('error', (_error, _request, response) => {
          if (!response.headersSent) {
            response.writeHead(503, { 'Content-Type': 'application/json' })
          }
          response.end(JSON.stringify({
            error: {
              message: `No se pudo conectar con Ollama en ${target}`,
            },
          }))
        })
      },
    },
  })

  return {
    plugins: [react()],
    server: {
      proxy: createProxy(),
    },
    preview: {
      proxy: createProxy(),
    },
  }
})
