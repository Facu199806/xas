-- NOXAS - Permisos mínimos para el usuario NOXAS_APP
-- Ejecutar como NOXAS_DEV en FREEPDB1 después de 001 y 002.
-- NOXAS_APP no recibe privilegios DDL ni cuota para crear objetos.

SET SERVEROUTPUT ON
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

DECLARE
    v_container VARCHAR2(128) := SYS_CONTEXT('USERENV', 'CON_NAME');
    v_user      VARCHAR2(128) := SYS_CONTEXT('USERENV', 'SESSION_USER');
BEGIN
    IF v_container <> 'FREEPDB1' OR v_user <> 'NOXAS_DEV' THEN
        RAISE_APPLICATION_ERROR(-20051, '005_grant_app_privileges.sql requiere NOXAS_DEV conectado a FREEPDB1.');
    END IF;
END;
/

-- Registro, autenticación y preferencias.
GRANT SELECT, INSERT, UPDATE ON noxas_user TO NOXAS_APP_ROLE;
GRANT SELECT, INSERT, UPDATE, DELETE ON noxas_identity TO NOXAS_APP_ROLE;
GRANT SELECT, INSERT, UPDATE, DELETE ON noxas_credential TO NOXAS_APP_ROLE;
GRANT SELECT, INSERT, UPDATE ON noxas_user_preference TO NOXAS_APP_ROLE;

-- Conversaciones. El borrado lógico utiliza conversation_status = 'DELETED'.
GRANT SELECT, INSERT, UPDATE ON noxas_conversation TO NOXAS_APP_ROLE;
GRANT SELECT, INSERT, UPDATE ON noxas_message TO NOXAS_APP_ROLE;

-- Sesiones revocables y auditoría inmutable desde la aplicación.
GRANT SELECT, INSERT, UPDATE, DELETE ON noxas_session TO NOXAS_APP_ROLE;
GRANT SELECT, INSERT ON noxas_audit_event TO NOXAS_APP_ROLE;

-- La aplicación consulta la base de conocimiento, pero no administra fuentes ni documentos.
GRANT SELECT ON noxas_kb_source TO NOXAS_APP_ROLE;
GRANT SELECT ON noxas_kb_document TO NOXAS_APP_ROLE;
GRANT SELECT ON noxas_kb_chunk TO NOXAS_APP_ROLE;
GRANT SELECT, INSERT ON noxas_kb_retrieval_log TO NOXAS_APP_ROLE;

PROMPT Permisos concedidos a NOXAS_APP_ROLE.
PROMPT El backend deberá referenciar los objetos como NOXAS_DEV.NOXAS_*.

SELECT grantee, table_name, privilege
FROM user_tab_privs_made
WHERE grantee = 'NOXAS_APP_ROLE'
ORDER BY table_name, privilege;
