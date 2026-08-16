-- NOXAS - Upgrade mínimo de privilegios para instalaciones existentes
-- Ejecutar como SYSDBA conectado a FREEPDB1.
-- Seguro de reejecutar: GRANT es idempotente para este caso.

SET SERVEROUTPUT ON
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

DECLARE
    v_container VARCHAR2(128) := SYS_CONTEXT('USERENV', 'CON_NAME');
    v_user      VARCHAR2(128) := SYS_CONTEXT('USERENV', 'SESSION_USER');
    v_count     PLS_INTEGER;
BEGIN
    IF v_container <> 'FREEPDB1' THEN
        RAISE_APPLICATION_ERROR(-20003, '000_upgrade_dev_privileges.sql debe ejecutarse en FREEPDB1.');
    END IF;

    IF v_user <> 'SYS' THEN
        RAISE_APPLICATION_ERROR(-20004, '000_upgrade_dev_privileges.sql debe ejecutarse como SYSDBA/SYS.');
    END IF;

    SELECT COUNT(*)
      INTO v_count
      FROM dba_users
     WHERE username = 'NOXAS_DEV';

    IF v_count <> 1 THEN
        RAISE_APPLICATION_ERROR(-20005, 'NOXAS_DEV no existe en FREEPDB1.');
    END IF;
END;
/

GRANT CREATE PROCEDURE TO NOXAS_DEV;

PROMPT Privilegios actuales relevantes para NOXAS_DEV
SELECT grantee, privilege
FROM dba_sys_privs
WHERE grantee = 'NOXAS_DEV'
  AND privilege IN ('CREATE SESSION', 'CREATE TABLE', 'CREATE PROCEDURE')
ORDER BY privilege;

PROMPT 000_upgrade_dev_privileges.sql finalizado correctamente.
