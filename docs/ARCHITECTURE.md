# Arquitectura actual

El navegador consume un endpoint configurable mediante `VITE_AI_API_URL`. Durante el desarrollo, las solicitudes bajo `/api` son redirigidas por Vite hacia `VITE_AI_PROXY_TARGET`.

```text
React UI -> /api/v1/chat/completions -> Vite proxy -> servidor de IA
```

Esta separación evita dejar una URL rígida dentro de los componentes y reduce problemas de CORS en desarrollo.

## Límite actual

La aplicación sigue siendo exclusivamente frontend. No debe contener claves secretas. Cuando se incorpore un proveedor autenticado, conviene agregar un backend propio que gestione credenciales, límites, normalización de respuestas y almacenamiento persistente.
