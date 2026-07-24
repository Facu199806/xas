-- NOXAS - Creación inicial de usuarios y rol de aplicación
-- Ejecutar con F5 / Run Script como SYSDBA conectado al servicio FREEPDB1.
-- No ejecutar conectado al servicio FREE, porque ese servicio apunta a CDB$ROOT.

SET SERVEROUTPUT ON
SET VERIFY OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

PROMPT ============================================================
PROMPT NOXAS - Verificación del contenedor
PROMPT ============================================================

DECLARE
    v_container  VARCHAR2(128);
    v_compatible VARCHAR2(128);
BEGIN
    v_container := SYS_CONTEXT('USERENV', 'CON_NAME');

    SELECT value
      INTO v_compatible
      FROM v$parameter
     WHERE name = 'compatible';

    DBMS_OUTPUT.PUT_LINE('Contenedor actual : ' || v_container);
    DBMS_OUTPUT.PUT_LINE('COMPATIBLE        : ' || v_compatible);

    IF v_container = 'CDB$ROOT' THEN
        RAISE_APPLICATION_ERROR(
            -20001,
            'Conexión incorrecta: use el servicio FREEPDB1 o ejecute ALTER SESSION SET CONTAINER = FREEPDB1.'
        );
    END IF;

    IF v_container <> 'FREEPDB1' THEN
        RAISE_APPLICATION_ERROR(
            -20002,
            'Este laboratorio fue preparado para FREEPDB1. Contenedor actual: ' || v_container
        );
    END IF;
END;
/

PROMPT Las contraseñas se solicitan de forma interactiva y no quedan guardadas en Git.
ACCEPT NOXAS_DEV_PASSWORD CHAR PROMPT 'Contraseña para NOXAS_DEV: ' HIDE
ACCEPT NOXAS_APP_PASSWORD CHAR PROMPT 'Contraseña para NOXAS_APP: ' HIDE

PROMPT ============================================================
PROMPT Creando esquema propietario, usuario de aplicación y rol
PROMPT ============================================================

CREATE USER NOXAS_DEV
    IDENTIFIED BY "&NOXAS_DEV_PASSWORD"
    DEFAULT TABLESPACE USERS
    TEMPORARY TABLESPACE TEMP
    QUOTA 2G ON USERS
    ACCOUNT UNLOCK
    CONTAINER = CURRENT;

GRANT CREATE SESSION, CREATE TABLE TO NOXAS_DEV;

CREATE ROLE NOXAS_APP_ROLE;

CREATE USER NOXAS_APP
    IDENTIFIED BY "&NOXAS_APP_PASSWORD"
    DEFAULT TABLESPACE USERS
    TEMPORARY TABLESPACE TEMP
    QUOTA 0 ON USERS
    ACCOUNT UNLOCK
    CONTAINER = CURRENT;

GRANT CREATE SESSION TO NOXAS_APP;
GRANT NOXAS_APP_ROLE TO NOXAS_APP;
ALTER USER NOXAS_APP DEFAULT ROLE NOXAS_APP_ROLE;

UNDEFINE NOXAS_DEV_PASSWORD
UNDEFINE NOXAS_APP_PASSWORD

PROMPT ============================================================
PROMPT Usuarios creados correctamente en FREEPDB1
PROMPT ============================================================

SELECT username, account_status, default_tablespace, temporary_tablespace
FROM dba_users
WHERE username IN ('NOXAS_DEV', 'NOXAS_APP')
ORDER BY username;

SELECT grantee, granted_role, default_role
FROM dba_role_privs
WHERE grantee = 'NOXAS_APP';
