-- NOXAS Memory API v1 - Validación de paquete, ORDS y OAuth
-- Ejecutar como NOXAS_DEV en FREEPDB1 después de 007 y 008.
-- No muestra CLIENT_SECRET.

SET SERVEROUTPUT ON
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

DECLARE
    v_container      VARCHAR2(128) := SYS_CONTEXT('USERENV', 'CON_NAME');
    v_user           VARCHAR2(128) := SYS_CONTEXT('USERENV', 'SESSION_USER');
    v_package_valid  PLS_INTEGER;
    v_module_count   PLS_INTEGER;
    v_priv_count     PLS_INTEGER;
    v_role_count     PLS_INTEGER;
    v_client_count   PLS_INTEGER;
    v_client_role    PLS_INTEGER;
    v_status         PLS_INTEGER;
    v_payload        CLOB;
BEGIN
    IF v_container <> 'FREEPDB1' OR v_user <> 'NOXAS_DEV' THEN
        RAISE_APPLICATION_ERROR(-20091, '009_validate_memory_api.sql requiere NOXAS_DEV conectado a FREEPDB1.');
    END IF;

    SELECT COUNT(*)
      INTO v_package_valid
      FROM user_objects
     WHERE object_name = 'NOXAS_MEMORY_API_PKG'
       AND object_type IN ('PACKAGE', 'PACKAGE BODY')
       AND status = 'VALID';

    SELECT COUNT(*)
      INTO v_module_count
      FROM user_ords_modules
     WHERE name = 'noxas.memory.api.v1';

    SELECT COUNT(*)
      INTO v_priv_count
      FROM user_ords_privileges
     WHERE name = 'noxas.memory.api';

    SELECT COUNT(*)
      INTO v_role_count
      FROM user_ords_roles
     WHERE name = 'NOXAS_MEMORY_CLIENT';

    SELECT COUNT(*)
      INTO v_client_count
      FROM user_ords_clients
     WHERE name = 'NOXAS Backend Memory';

    SELECT COUNT(*)
      INTO v_client_role
      FROM user_ords_client_roles
     WHERE client_name = 'NOXAS Backend Memory'
       AND role_name = 'NOXAS_MEMORY_CLIENT';

    noxas_memory_api_pkg.health(v_status, v_payload);

    DBMS_OUTPUT.PUT_LINE('Usuario actual         : ' || v_user);
    DBMS_OUTPUT.PUT_LINE('Contenedor actual      : ' || v_container);
    DBMS_OUTPUT.PUT_LINE('Package válido         : ' || v_package_valid || '/2');
    DBMS_OUTPUT.PUT_LINE('Módulo ORDS            : ' || v_module_count || '/1');
    DBMS_OUTPUT.PUT_LINE('Privilegio OAuth       : ' || v_priv_count || '/1');
    DBMS_OUTPUT.PUT_LINE('Rol ORDS               : ' || v_role_count || '/1');
    DBMS_OUTPUT.PUT_LINE('Cliente OAuth          : ' || v_client_count || '/1');
    DBMS_OUTPUT.PUT_LINE('Rol asignado al cliente: ' || v_client_role || '/1');
    DBMS_OUTPUT.PUT_LINE('Health interno HTTP    : ' || v_status);
    DBMS_OUTPUT.PUT_LINE('Health interno payload : ' || DBMS_LOB.SUBSTR(v_payload, 1000, 1));

    IF v_package_valid <> 2
       OR v_module_count <> 1
       OR v_priv_count <> 1
       OR v_role_count <> 1
       OR v_client_count <> 1
       OR v_client_role <> 1
       OR v_status <> 200 THEN
        RAISE_APPLICATION_ERROR(-20092, 'VALIDACION NOXAS MEMORY API: ERROR');
    END IF;

    DBMS_OUTPUT.PUT_LINE('VALIDACION NOXAS MEMORY API: OK');
END;
/

PROMPT Cliente OAuth creado (CLIENT_SECRET deliberadamente omitido):
SELECT name, client_id
  FROM user_ords_clients
 WHERE name = 'NOXAS Backend Memory';

PROMPT Módulo y privilegio:
SELECT name, uri_prefix, status
  FROM user_ords_modules
 WHERE name = 'noxas.memory.api.v1';

SELECT name, label
  FROM user_ords_privileges
 WHERE name = 'noxas.memory.api';

PROMPT 009_validate_memory_api.sql finalizado correctamente.
