import { defineConfig, loadEnv } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '')
  const target = env.VITE_AI_PROXY_TARGET || 'http://localhost:11434'

  return {
    plugins: [react()],
    server: {
      proxy: {
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
      },
    },
  }
})
