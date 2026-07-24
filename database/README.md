# Base de datos de NOXAS

Esta carpeta contiene el modelo de desarrollo para Oracle Database 23c/23ai Free dentro de VirtualBox.

## Orden de ejecución

```text
1. oracle/001_core_schema.sql
2. oracle/002_knowledge_schema.sql
3. oracle/003_vector_extension_23ai.sql   (opcional)
```

La extensión vectorial no debe ejecutarse hasta confirmar:

- que la instancia reconoce el tipo `VECTOR`;
- la dimensión del modelo de embeddings;
- memoria suficiente para el índice elegido.

## Usuario recomendado

Crear un esquema específico, por ejemplo `NOXAS_DEV`, en lugar de utilizar `SYS`, `SYSTEM`, `HR` o el propietario de otras prácticas.

La aplicación debería conectarse con una cuenta limitada distinta del propietario de las tablas. Esa cuenta recibirá únicamente los permisos necesarios para ejecutar el backend local.

## Datos

- No subir archivos `.dbf`, `.vdi`, exports con datos reales ni wallets al repositorio.
- No guardar contraseñas o tokens dentro de scripts SQL.
- Los datos de prueba deben ser ficticios.
- Las exportaciones se guardan fuera de Git o en almacenamiento cifrado.

## Verificación rápida

Después de ejecutar los scripts principales:

```sql
SELECT table_name
FROM user_tables
WHERE table_name LIKE 'NOXAS%'
ORDER BY table_name;
```

Relaciones de una conversación:

```sql
SELECT
    c.title,
    c.conversation_status,
    m.sequence_no,
    m.message_role,
    DBMS_LOB.SUBSTR(m.content_text, 200, 1) AS content_preview,
    m.created_at
FROM noxas_conversation c
JOIN noxas_message m
  ON m.conversation_id = c.conversation_id
WHERE c.conversation_id = :conversation_id
ORDER BY m.sequence_no;
```

## Migraciones

Los scripts numerados son migraciones iniciales. Una vez que exista información en la base, no se deben editar retroactivamente para cambiar producción. Los cambios nuevos se agregan como scripts posteriores:

```text
004_add_workspace.sql
005_add_message_feedback.sql
006_add_document_permissions.sql
```

Así la VM y la futura base cloud pueden reconstruirse de manera consistente, sin depender de recordar qué botón se tocó tres meses antes a las dos de la mañana.
