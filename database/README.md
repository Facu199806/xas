# Base de datos de NOXAS

Esta carpeta contiene el modelo de desarrollo validado para Oracle Database Free dentro de VirtualBox.

## Entorno confirmado

```text
Oracle Database 23 Free Release 23.0.0.0.0
Version 23.3.0.23.09
COMPATIBLE = 23.0.0
CDB = FREE
PDB = FREEPDB1
Puerto = 1521
```

El servicio `FREE` conecta a `CDB$ROOT`. El servicio `FREEPDB1` conecta a la PDB donde deben vivir los usuarios y las tablas de NOXAS.

No se deben ejecutar las migraciones de la aplicación dentro de `CDB$ROOT` ni con el esquema `SYS`.

## Conexiones recomendadas en SQL Developer

### Administración inicial

```text
Name: SYS_FREEPDB1
Usuario: sys
Rol: SYSDBA
Host: localhost
Puerto: 1521
Nombre del servicio: FREEPDB1
```

### Propietario del esquema

Se crea con `000_create_users.sql`:

```text
Name: NOXAS_DEV
Usuario: NOXAS_DEV
Rol: Default
Host: localhost
Puerto: 1521
Nombre del servicio: FREEPDB1
```

### Usuario futuro del backend

```text
Name: NOXAS_APP
Usuario: NOXAS_APP
Rol: Default
Host: localhost
Puerto: 1521
Nombre del servicio: FREEPDB1
```

`NOXAS_APP` no crea tablas ni recibe cuota de almacenamiento. El backend deberá consultar objetos con el prefijo `NOXAS_DEV.`, por ejemplo `NOXAS_DEV.NOXAS_CONVERSATION`.

## Orden de ejecución

Ejecutar cada archivo mediante **Run Script / F5**, no como una sola sentencia aislada.

```text
1. oracle/000_create_users.sql             como SYSDBA en FREEPDB1
2. oracle/001_core_schema.sql              como NOXAS_DEV en FREEPDB1
3. oracle/002_knowledge_schema.sql         como NOXAS_DEV en FREEPDB1
4. oracle/004_seed_demo_data.sql           como NOXAS_DEV en FREEPDB1
5. oracle/005_grant_app_privileges.sql     como NOXAS_DEV en FREEPDB1
6. oracle/006_validate_installation.sql    como NOXAS_DEV en FREEPDB1
```

El archivo `003_vector_extension_23ai.sql` queda fuera del orden normal.

## AI Vector Search

La instancia confirmada tiene `COMPATIBLE = 23.0.0`. Oracle requiere `COMPATIBLE = 23.4.0` o superior para utilizar el tipo `VECTOR`.

Por lo tanto:

- no ejecutar `003_vector_extension_23ai.sql`;
- no modificar `COMPATIBLE` en esta instalación 23.3;
- actualizar primero Oracle Database Free a una versión compatible;
- después elegir el modelo de embeddings y su dimensión;
- recién entonces habilitar el archivo vectorial.

El script está bloqueado con `NOXAS_VECTOR_CONFIRMED = NO` para evitar una ejecución accidental.

## Usuarios y permisos

### `NOXAS_DEV`

Propietario de las tablas. Recibe solamente:

- `CREATE SESSION`;
- `CREATE TABLE`;
- cuota de 2 GB sobre `USERS`.

### `NOXAS_APP`

Usuario futuro del backend. Recibe:

- `CREATE SESSION`;
- el rol `NOXAS_APP_ROLE`;
- permisos DML sobre usuarios, identidades, credenciales, preferencias, conversaciones, mensajes y sesiones;
- inserción de auditoría;
- lectura de fuentes, documentos y fragmentos de conocimiento;
- inserción del registro de recuperación.

No recibe privilegios DDL, acceso a `SYS`, roles administrativos ni permisos para administrar las fuentes documentales.

## Datos ficticios

`004_seed_demo_data.sql` crea únicamente información de laboratorio:

- un usuario ficticio;
- una identidad ficticia de GitHub;
- preferencias;
- una conversación sobre un ORA-01722;
- dos mensajes;
- un documento y un fragmento de conocimiento ficticios;
- un registro de recuperación por palabras clave.

El script puede repetirse porque elimina y vuelve a crear únicamente esos registros DEMO.

## Validación

`006_validate_installation.sql` comprueba:

- que el usuario sea `NOXAS_DEV`;
- que el contenedor sea `FREEPDB1`;
- que existan las 13 tablas iniciales;
- que todas las constraints estén habilitadas y validadas;
- que existan las cinco fuentes oficiales iniciales;
- que las relaciones de los datos ficticios sean correctas;
- que los permisos de `NOXAS_APP_ROLE` hayan sido concedidos.

La salida correcta debe terminar con:

```text
RESULTADO                   : VALIDACIÓN CORRECTA
006_validate_installation.sql finalizado correctamente.
```

## Seguridad

- No subir archivos `.dbf`, `.vdi`, exports con datos reales ni wallets al repositorio.
- No guardar contraseñas o tokens dentro de scripts SQL.
- Las contraseñas de `000_create_users.sql` se solicitan de forma interactiva.
- No exponer directamente el listener Oracle a Internet.
- La futura conexión remota debe pasar por un backend autenticado y cifrado.

## Migraciones futuras

Una vez que exista información persistente, los scripts ejecutados no se editan retroactivamente para cambiar producción. Los cambios nuevos se agregan como migraciones posteriores.

Así la VM y una futura base administrada pueden reconstruirse de forma consistente, sin depender de recordar qué botón se tocó tres meses antes a las dos de la mañana.
