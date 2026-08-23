# NOXAS Memory Read v1 - validación local

Esta integración conecta `/api/agent` con NOXAS Memory API para lectura de memorias `ACTIVE` en scopes `PROJECT` y `SYSTEM`.

## Variables backend

Configurar únicamente en el backend/secret store:

```text
NOXAS_MEMORY_BASE_URL=http://localhost:8080/ords/noxas/memory/v1/
NOXAS_MEMORY_TOKEN_URL=http://localhost:8080/ords/noxas/oauth/token
NOXAS_MEMORY_CLIENT_ID=<client-id>
NOXAS_MEMORY_CLIENT_SECRET=<client-secret>
```

Opcional:

```text
NOXAS_MEMORY_TIMEOUT_MS=4000
```

## Validación

1. Levantar Oracle/ORDS en la VM.
2. Confirmar que Memory API responde `401` sin token y `200` con OAuth válido.
3. Levantar el backend de NOXAS en el mismo entorno desde el que `localhost:8080` sea alcanzable.
4. Ejecutar `GET /api/agent`.
5. Verificar:

```json
{
  "oracleMemoryConnected": true,
  "oracleMemory": {
    "configured": true,
    "connected": true
  }
}
```

6. Crear o reutilizar una memoria ficticia `ACTIVE` con scope `PROJECT` o `SYSTEM`.
7. En modo Agente, pedir información que sólo exista en esa memoria y verificar que `search_project_knowledge` la recupere.
8. Apagar ORDS o quitar temporalmente la configuración de Memory API y confirmar que `/api/agent` sigue respondiendo mediante el conocimiento local de fallback.

## Alcance de v1

- Sólo lectura.
- Sólo scopes `PROJECT` y `SYSTEM`.
- Las listas se usan para ranking por preview.
- El contenido completo se solicita únicamente para memorias seleccionadas como match.
- Si Memory API no está disponible, el agente conserva `PROJECT_KNOWLEDGE` local.
- No se exponen `CLIENT_ID`, `CLIENT_SECRET`, access tokens ni URLs internas en la respuesta del agente.
