# Base de conocimiento técnica de NOXAS

NOXAS no debe “memorizar Internet” ni entrenarse nuevamente cada vez que cambia una documentación. Para Oracle, Microsoft, Linux y programación conviene usar **RAG**: buscar fragmentos relevantes en fuentes controladas, agregarlos temporalmente al contexto y responder con citas.

## RAG frente a fine-tuning

### RAG sirve para

- documentación que cambia;
- versiones distintas de productos;
- errores y mensajes concretos;
- respuestas con enlaces y referencias;
- contenido privado autorizado;
- corregir o retirar una fuente sin volver a entrenar un modelo.

### Fine-tuning serviría después para

- tono y formato de respuestas;
- estructura de análisis de tickets;
- clasificación de incidentes;
- estilo de resúmenes;
- selección de plantillas.

No debe usarse como sustituto de una documentación versionada. Un modelo afinado con una guía vieja seguirá estando orgullosamente equivocado hasta que alguien vuelva a entrenarlo.

## Flujo propuesto

```text
Fuente permitida
    ↓
Conector o sincronizador
    ↓
Normalización y limpieza
    ↓
Documento versionado
    ↓
Fragmentación por secciones
    ↓
Índice de palabras + embeddings
    ↓
Recuperación híbrida
    ↓
Reordenamiento por relevancia y confianza
    ↓
Prompt con fragmentos y citas
    ↓
Respuesta de NOXAS
```

## Capas

### 1. Registro de fuentes

Cada fuente se registra en `noxas_kb_source` con:

- editor;
- URL base;
- tipo de fuente;
- nivel de confianza;
- estrategia de actualización;
- estado habilitado/deshabilitado;
- nota de licencia o permisos.

Nada se ingiere solamente porque un crawler logró abrirlo. Capacidad técnica y permiso legal son conceptos distintos, descubrimiento desconcertante para cierta parte de Internet.

### 2. Documentos

`noxas_kb_document` guarda:

- título;
- enlace canónico;
- producto;
- versión;
- idioma;
- fecha publicada o modificada;
- hash del contenido;
- estado activo, obsoleto, eliminado o bloqueado.

El hash permite evitar reprocesar documentos idénticos.

### 3. Fragmentos

`noxas_kb_chunk` divide cada documento por encabezados y contexto semántico. Un fragmento debe:

- mantener la sección de origen;
- tener tamaño suficiente para conservar significado;
- evitar mezclar versiones o productos distintos;
- incluir un ancla o enlace directo cuando exista;
- poder citarse de manera independiente.

Punto inicial sugerido:

- 400 a 800 tokens por fragmento;
- solapamiento de 60 a 120 tokens;
- división prioritaria por encabezados, listas y bloques de código;
- código y explicación conservados juntos cuando dependan entre sí.

### 4. Búsqueda híbrida

NOXAS debería combinar:

1. **Palabras clave**, útiles para `ORA-01722`, nombres de paquetes, comandos y códigos HTTP.
2. **Búsqueda vectorial**, útil para preguntas conceptuales expresadas con palabras diferentes.
3. **Filtros**, por producto, versión, idioma y fuente.
4. **Reordenamiento**, favoreciendo fuente oficial, versión compatible y coincidencia exacta.

Oracle AI Vector Search permite almacenar vectores y realizar búsquedas de similitud. La extensión opcional está en `database/oracle/003_vector_extension_23ai.sql`.

## Fuentes iniciales

### Oracle

Prioridad:

1. Oracle Database SQL Language Reference.
2. PL/SQL Language Reference.
3. Database Error Messages.
4. AI Vector Search User's Guide.
5. Oracle Linux Documentation.
6. Documentación pública de Oracle E-Business Suite y Siebel cuando sea aplicable.
7. Documentación interna del usuario, sólo con permiso explícito.

Reglas:

- conservar versión exacta;
- no mezclar Oracle Database 12c, 19c, 23ai o 26ai sin marcarlo;
- no presentar ejemplos de una versión como válidos universalmente;
- no ingerir Oracle Support/MOS ni material restringido sin acceso y autorización;
- priorizar códigos de error y referencias oficiales antes que blogs.

Fuente base:

- `https://docs.oracle.com`

### Microsoft

Prioridad:

1. Microsoft Learn.
2. Windows documentation.
3. PowerShell documentation.
4. .NET y C# documentation.
5. Azure documentation cuando la consulta lo requiera.

Para catálogo y metadatos se debe usar la **Microsoft Learn Platform API**, que requiere autenticación con Microsoft Entra ID. El catálogo devuelve módulos, unidades, rutas de aprendizaje, credenciales y otros metadatos, pero no entrega toda la documentación técnica ni muestras de código. Los enlaces del catálogo deben conducir a la página oficial correspondiente.

Fuentes base:

- `https://learn.microsoft.com`
- `https://learn.microsoft.com/api/v1`

### Linux

Prioridad:

1. Linux Kernel Documentation.
2. Red Hat Enterprise Linux Documentation.
3. Ubuntu Server Documentation.
4. Manuales y documentación de cada herramienta o distribución.

Reglas:

- distinguir kernel, distribución y paquete;
- conservar versión de RHEL, Ubuntu LTS o kernel;
- evitar aplicar instrucciones de una distribución a otra sin aclararlo;
- priorizar documentación del fabricante para systemd, SELinux, networking y paquetes.

Fuentes base:

- `https://docs.kernel.org`
- `https://docs.redhat.com`
- `https://ubuntu.com/server/docs`

### Programación avanzada

Registro sugerido:

- Python: `https://docs.python.org`
- JavaScript web: `https://developer.mozilla.org`
- Node.js: `https://nodejs.org/docs`
- React: `https://react.dev`
- TypeScript: `https://www.typescriptlang.org/docs`
- Java: `https://docs.oracle.com/en/java`
- GitHub: `https://docs.github.com`
- Netlify: `https://docs.netlify.com`
- PostgreSQL, si se adopta: `https://www.postgresql.org/docs`

La lógica avanzada no debe depender solamente de documentación. También necesita una capa de razonamiento y validación:

- complejidad temporal y espacial;
- estructuras de datos;
- concurrencia;
- transacciones;
- idempotencia;
- diseño de APIs;
- pruebas;
- seguridad;
- patrones y antipatrones;
- análisis de logs y fallos.

Los ejemplos de código recuperados deben pasar por validaciones estáticas antes de mostrarse como solución segura.

## Estrategia de recuperación

Una consulta se clasifica primero:

```text
ORA / PL/SQL / EBS / Siebel → Oracle
PowerShell / Windows / .NET → Microsoft
systemd / dnf / apt / kernel → Linux
React / Node / algoritmo → Programación
```

Después se generan filtros:

```json
{
  "product": "Oracle Database",
  "version": "12.1",
  "language": "es",
  "sourceTrustMin": 8
}
```

Finalmente se recuperan entre 5 y 12 fragmentos, se eliminan duplicados y se entregan al modelo con:

- título;
- fuente;
- versión;
- enlace;
- fecha de recuperación;
- texto relevante.

## Citas en respuestas

Toda respuesta basada en la base técnica debe distinguir:

- **Fuente oficial:** afirmación respaldada por documentación.
- **Inferencia:** conclusión razonada por NOXAS a partir de la evidencia.
- **Dato faltante:** información necesaria para confirmar la causa.

Ejemplo:

```text
La documentación indica que ORA-01722 aparece al convertir texto no numérico.
En tu caso, es probable que una columna VARCHAR2 esté entrando en una conversión implícita.
Falta ver el valor exacto y la expresión de la línea afectada.
```

## Actualización

Frecuencia inicial:

| Fuente | Estrategia |
|---|---|
| Oracle Database | semanal o bajo demanda |
| Microsoft Learn Platform API | diaria |
| Linux Kernel | semanal |
| RHEL | semanal |
| Ubuntu Server | semanal |
| Documentos privados | manual |

Cada sincronización se registra en `noxas_kb_sync_run`. Un documento retirado no se borra inmediatamente: primero pasa a `REMOVED` o `BLOCKED` para conservar trazabilidad.

## Seguridad

- Los conectores privados viven en el backend.
- Las credenciales no se envían al navegador.
- Los documentos privados se asocian a usuarios o espacios autorizados.
- La recuperación filtra por permisos antes de buscar contenido.
- Los logs guardan hashes y métricas, no consultas completas sensibles.
- Las respuestas no ejecutan DML, comandos ni scripts automáticamente.

## Implementación por fases

### Fase A: laboratorio local

- Ejecutar `001_core_schema.sql`.
- Ejecutar `002_knowledge_schema.sql`.
- Cargar manualmente 20 a 50 documentos públicos y pequeños.
- Probar búsqueda por palabra clave.
- Medir calidad de fragmentación.

### Fase B: embeddings locales

- Confirmar soporte `VECTOR` en Oracle.
- Elegir un único modelo de embeddings.
- Ejecutar `003_vector_extension_23ai.sql` con la dimensión correcta.
- Generar embeddings desde un proceso local.
- Comparar búsqueda vectorial contra búsqueda exacta.

### Fase C: recuperación híbrida

- Clasificador de dominio y versión.
- Búsqueda keyword + vector.
- Reordenamiento por confianza.
- Respuestas con citas.
- Registro de métricas, no de secretos.

### Fase D: producción

- Base administrada en la nube.
- Sincronizadores programados.
- Control de permisos.
- Monitoreo de costo y frescura.
- Panel para habilitar o bloquear fuentes.
