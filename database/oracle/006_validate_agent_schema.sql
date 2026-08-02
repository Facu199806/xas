-- NOXAS Agent v1 - Validacion posterior a 005_agent_schema.sql
-- Ejecutar con F5 / Run Script conectado como NOXAS_DEV al servicio FREEPDB1.

SET SERVEROUTPUT ON
SET VERIFY OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

DECLARE
    v_container       VARCHAR2(128) := SYS_CONTEXT('USERENV', 'CON_NAME');
    v_user            VARCHAR2(128) := SYS_CONTEXT('USERENV', 'SESSION_USER');
    v_tables          NUMBER;
    v_constraints     NUMBER;
    v_indexes         NUMBER;
    v_invalid_objects NUMBER;
BEGIN
    IF v_container <> 'FREEPDB1' THEN
        RAISE_APPLICATION_ERROR(-20061, '006_validate_agent_schema.sql debe ejecutarse dentro de FREEPDB1.');
    END IF;

    IF v_user <> 'NOXAS_DEV' THEN
        RAISE_APPLICATION_ERROR(-20062, '006_validate_agent_schema.sql debe ejecutarse conectado como NOXAS_DEV.');
    END IF;

    SELECT COUNT(*)
      INTO v_tables
      FROM user_tables
     WHERE table_name IN (
        'NOXAS_AGENT_RUN',
        'NOXAS_AGENT_STEP',
        'NOXAS_TOOL_CALL',
        'NOXAS_APPROVAL_REQUEST',
        'NOXAS_MEMORY',
        'NOXAS_AGENT_TASK'
     );

    IF v_tables <> 6 THEN
        RAISE_APPLICATION_ERROR(-20063, 'Se esperaban 6 tablas del agente y se encontraron ' || v_tables || '.');
    END IF;

    SELECT COUNT(*)
      INTO v_constraints
      FROM user_constraints
     WHERE constraint_name IN (
        'PK_NOXAS_AGENT_RUN',
        'PK_NOXAS_AGENT_STEP',
        'PK_NOXAS_TOOL_CALL',
        'PK_NOXAS_APPROVAL',
        'PK_NOXAS_MEMORY',
        'PK_NOXAS_AGENT_TASK',
        'UQ_NOXAS_AGENT_STEP_NO'
     )
       AND status = 'ENABLED';

    IF v_constraints <> 7 THEN
        RAISE_APPLICATION_ERROR(-20064, 'No estan habilitadas todas las restricciones principales. Encontradas: ' || v_constraints || '.');
    END IF;

    SELECT COUNT(*)
      INTO v_indexes
      FROM user_indexes
     WHERE index_name IN (
        'IX_NOXAS_AGENT_RUN_USER_DATE',
        'IX_NOXAS_AGENT_RUN_STATUS',
        'IX_NOXAS_TOOL_CALL_RUN',
        'IX_NOXAS_TOOL_CALL_STATUS',
        'IX_NOXAS_APPROVAL_PENDING',
        'IX_NOXAS_MEMORY_USER_TYPE',
        'IX_NOXAS_MEMORY_PROJECT',
        'IX_NOXAS_AGENT_TASK_DUE'
     )
       AND status = 'VALID';

    IF v_indexes <> 8 THEN
        RAISE_APPLICATION_ERROR(-20065, 'Se esperaban 8 indices auxiliares validos y se encontraron ' || v_indexes || '.');
    END IF;

    SELECT COUNT(*)
      INTO v_invalid_objects
      FROM user_objects
     WHERE status <> 'VALID'
       AND object_name LIKE 'NOXAS%';

    IF v_invalid_objects <> 0 THEN
        RAISE_APPLICATION_ERROR(-20066, 'Hay objetos NOXAS invalidos: ' || v_invalid_objects || '.');
    END IF;

    DBMS_OUTPUT.PUT_LINE('Usuario actual       : ' || v_user);
    DBMS_OUTPUT.PUT_LINE('Contenedor actual    : ' || v_container);
    DBMS_OUTPUT.PUT_LINE('Tablas del agente    : ' || v_tables || '/6');
    DBMS_OUTPUT.PUT_LINE('Restricciones clave  : ' || v_constraints || '/7');
    DBMS_OUTPUT.PUT_LINE('Indices auxiliares   : ' || v_indexes || '/8');
    DBMS_OUTPUT.PUT_LINE('Objetos invalidos    : ' || v_invalid_objects);
    DBMS_OUTPUT.PUT_LINE('VALIDACION NOXAS AGENT: OK');
END;
/

PROMPT Listado de tablas del agente
SELECT table_name
FROM user_tables
WHERE table_name IN (
    'NOXAS_AGENT_RUN',
    'NOXAS_AGENT_STEP',
    'NOXAS_TOOL_CALL',
    'NOXAS_APPROVAL_REQUEST',
    'NOXAS_MEMORY',
    'NOXAS_AGENT_TASK'
)
ORDER BY table_name;

PROMPT Listado de indices auxiliares
SELECT index_name, table_name, uniqueness, status
FROM user_indexes
WHERE index_name LIKE 'IX_NOXAS_%'
  AND table_name IN (
    'NOXAS_AGENT_RUN',
    'NOXAS_AGENT_STEP',
    'NOXAS_TOOL_CALL',
    'NOXAS_APPROVAL_REQUEST',
    'NOXAS_MEMORY',
    'NOXAS_AGENT_TASK'
  )
ORDER BY table_name, index_name;

PROMPT 006_validate_agent_schema.sql finalizado correctamente.
