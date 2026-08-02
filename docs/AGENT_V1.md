# NOXAS Agent v1

NOXAS Agent v1 introduce un ciclo supervisado de análisis, selección de herramientas, observación de resultados y conclusión.

## Estado de esta rama

- El chat actual permanece sin cambios en `/api/chat`.
- El nuevo agente está disponible en `/api/agent`.
- El agente no ejecuta escrituras reales.
- Las acciones de código, base de datos, despliegue, eliminación, infraestructura o comunicación externa se convierten en propuestas que requieren aprobación.
- La memoria Oracle todavía no está conectada al endpoint. El archivo `database/oracle/005_agent_schema.sql` prepara las tablas necesarias.

## Conducta del agente

El prompt del agente exige:

1. entender el objetivo antes de actuar;
2. buscar datos faltantes y contradicciones;
3. separar hechos, hipótesis e inferencias;
4. tratar de refutar hipótesis débiles;
5. usar herramientas sólo cuando reduzcan incertidumbre;
6. verificar antes de declarar una tarea completada;
7. evitar inferir o acumular información personal de terceros;
8. pedir aprobación para cualquier acción de escritura o externa.

La curiosidad se aplica al problema técnico y a las fuentes autorizadas. No habilita vigilancia, recolección de datos personales ni acceso implícito a recursos.

## Herramientas iniciales

| Herramienta | Función | Escritura |
|---|---|---|
| `search_project_knowledge` | Busca hechos básicos autorizados del proyecto | No |
| `calculate` | Resuelve aritmética básica | No |
| `inspect_runtime` | Informa capacidades y límites activos | No |
| `propose_action` | Genera una solicitud de aprobación | No ejecuta |

## Límites

- Máximo predeterminado: 5 pasos.
- Máximo absoluto: 8 pasos.
- Máximo de 10 solicitudes por minuto por IP y dominio.
- Cada paso puede producir una nueva llamada al modelo y, por lo tanto, consumir inferencia.
- `XAS_AGENT_MAX_OUTPUT_TOKENS` permite reducir el máximo de salida.
- `XAS_AGENT_MODEL` permite seleccionar un modelo diferente al chat normal.

## Probar el diagnóstico

```bash
curl https://TU-SITIO.netlify.app/api/agent
```

Respuesta esperada:

```json
{
  "ok": true,
  "assistant": "NOXAS",
  "mode": "SUPERVISED",
  "oracleMemoryConnected": false
}
```

## Probar una tarea

```bash
curl -X POST https://TU-SITIO.netlify.app/api/agent \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer TU_TOKEN" \
  -d '{
    "messages": [
      {
        "role": "user",
        "content": "Revisá qué capacidades tenés y explicá qué te falta para guardar memoria en Oracle."
      }
    ],
    "reasoning_effort": "medium",
    "max_steps": 4
  }'
```

La cabecera `Authorization` sólo es necesaria cuando `XAS_ACCESS_TOKEN` está configurado.

## Instalar el esquema Oracle

Conectado como `NOXAS_DEV` a `FREEPDB1`:

```text
@database/oracle/005_agent_schema.sql
```

El script crea:

- `NOXAS_AGENT_RUN`
- `NOXAS_AGENT_STEP`
- `NOXAS_TOOL_CALL`
- `NOXAS_APPROVAL_REQUEST`
- `NOXAS_MEMORY`
- `NOXAS_AGENT_TASK`

Las trazas guardan resúmenes operativos y evidencias, no cadenas privadas de razonamiento.

## Siguiente integración

1. probar `/api/agent` en un Deploy Preview;
2. comprobar compatibilidad del proveedor con `tool_calls`;
3. conectar la interfaz mediante un selector Chat/Agente;
4. conectar persistencia Oracle mediante un backend privado o una API REST segura;
5. agregar herramientas reales de GitHub, documentación y diagnóstico SQL;
6. implementar aprobación y reanudación de ejecuciones.

No se debe exponer directamente el puerto Oracle 1521 de una VM doméstica a internet.
