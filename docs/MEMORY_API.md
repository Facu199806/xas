# NOXAS Memory API v1

API privada de memoria persistente sobre Oracle Database y ORDS.

## Objetivo

Exponer únicamente operaciones controladas sobre `NOXAS_MEMORY` sin publicar la tabla mediante AutoREST y sin exponer Oracle SQL*Net (`1521`) a Internet.

La API usa:

- Oracle REST Data Services (ORDS);
- OAuth 2.0 `client_credentials` para autenticación máquina-a-máquina;
- un rol ORDS dedicado: `NOXAS_MEMORY_CLIENT`;
- un privilegio dedicado: `noxas.memory.api`;
- un paquete PL/SQL `NOXAS_MEMORY_API_PKG` como única capa de acceso a la tabla.

## Endpoints

Base local:

```text
http://localhost:8080/ords/noxas/memory/v1/
```

Endpoints protegidos:

```text
GET  health/
GET  memories/
GET  memories/:id
POST memories/
POST memories/:id/activate
POST memories/:id/archive
```

No existe `DELETE` físico en v1.

Las memorias nuevas se crean siempre como `CANDIDATE`. Deben pasar por `activate` antes de ser usadas como memoria activa.

## Instalación

Conectado como `NOXAS_DEV` a `FREEPDB1`:

```text
@/home/oracle/xas/database/oracle/007_memory_api_package.sql
@/home/oracle/xas/database/oracle/008_memory_ords_api.sql
@/home/oracle/xas/database/oracle/009_validate_memory_api.sql
```

Resultado esperado de la validación:

```text
Package válido         : 2/2
Módulo ORDS            : 1/1
Privilegio OAuth       : 1/1
Rol ORDS               : 1/1
Cliente OAuth          : 1/1
Rol asignado al cliente: 1/1
Health interno HTTP    : 200
VALIDACION NOXAS MEMORY API: OK
```

## Obtener las credenciales OAuth

Ejecutar localmente en SQLcl/SQL Developer:

```sql
SELECT name, client_id, client_secret
FROM user_ords_clients
WHERE name = 'NOXAS Backend Memory';
```

`CLIENT_SECRET` es un secreto real. No debe copiarse a Git, tickets, chats, capturas públicas ni archivos versionados.

## Token OAuth

El endpoint de token local es:

```text
http://localhost:8080/ords/noxas/oauth/token
```

Con `curl`:

```bash
curl -i \
  --user 'CLIENT_ID:CLIENT_SECRET' \
  --data 'grant_type=client_credentials' \
  http://localhost:8080/ords/noxas/oauth/token
```

El token recibido es temporal y se utiliza como Bearer token.

## Comprobar que la API está cerrada

Sin token:

```bash
curl -i http://localhost:8080/ords/noxas/memory/v1/health/
```

Resultado esperado: `401 Unauthorized`.

Con token:

```bash
curl -i \
  -H 'Authorization: Bearer ACCESS_TOKEN' \
  http://localhost:8080/ords/noxas/memory/v1/health/
```

Resultado esperado: HTTP `200` y JSON con `ok: true`.

## Crear una memoria candidata

Ejemplo con el usuario ficticio de `004_seed_demo_data.sql`:

```bash
curl -i \
  -X POST \
  -H 'Authorization: Bearer ACCESS_TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{
    "user_id":"11111111111111111111111111111111",
    "memory_scope":"USER",
    "memory_type":"TECHNICAL_NOTE",
    "title":"Prueba de memoria ORDS",
    "content_text":"Memoria ficticia creada para validar NOXAS Memory API.",
    "confidence_score":0.95,
    "importance_score":0.50,
    "source_reference":"manual-test"
  }' \
  http://localhost:8080/ords/noxas/memory/v1/memories/
```

La respuesta debe quedar en estado `CANDIDATE`.

## Activar

```bash
curl -i \
  -X POST \
  -H 'Authorization: Bearer ACCESS_TOKEN' \
  http://localhost:8080/ords/noxas/memory/v1/memories/MEMORY_ID/activate
```

## Listar memorias activas

`limit` es un query parameter reservado por ORDS, por lo que NOXAS usa `max_results` para controlar el máximo devuelto por la API.

```bash
curl -i \
  -H 'Authorization: Bearer ACCESS_TOKEN' \
  'http://localhost:8080/ords/noxas/memory/v1/memories/?status=ACTIVE&max_results=20'
```

## Archivar

```bash
curl -i \
  -X POST \
  -H 'Authorization: Bearer ACCESS_TOKEN' \
  http://localhost:8080/ords/noxas/memory/v1/memories/MEMORY_ID/archive
```

## Seguridad

1. El puerto Oracle `1521` permanece privado.
2. La tabla `NOXAS_MEMORY` no se publica con AutoREST.
3. El módulo completo queda asociado al privilegio `noxas.memory.api`.
4. Sólo el cliente OAuth con rol `NOXAS_MEMORY_CLIENT` puede acceder.
5. No se permite borrado físico desde HTTP.
6. Las nuevas memorias nacen como `CANDIDATE`.
7. Las escrituras generan eventos en `NOXAS_AUDIT_EVENT`.
8. No se habilita CORS para frontends externos; la API está pensada para comunicación backend a backend.
9. `CLIENT_SECRET` debe vivir únicamente en variables de entorno/secret stores.
10. Al publicar fuera de localhost se debe usar HTTPS obligatorio.

## Nota de versión ORDS

Esta VM está basada en la generación Oracle/ORDS 23.x y utiliza el paquete `OAUTH`, compatible con esa versión. En ORDS modernos, Oracle migró estas APIs administrativas hacia `ORDS_SECURITY`; esa migración se hará cuando se actualice la infraestructura, no durante la validación del appliance local.
