-- NOXAS - Validación integral del esquema inicial
-- Ejecutar como NOXAS_DEV en FREEPDB1 después de 001, 002, 004 y 005.

SET SERVEROUTPUT ON
SET LINESIZE 220
SET PAGESIZE 200
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

DECLARE
    v_container            VARCHAR2(128) := SYS_CONTEXT('USERENV', 'CON_NAME');
    v_user                 VARCHAR2(128) := SYS_CONTEXT('USERENV', 'SESSION_USER');
    v_expected_tables      NUMBER := 13;
    v_table_count          NUMBER;
    v_bad_constraints      NUMBER;
    v_demo_users           NUMBER;
    v_demo_conversations   NUMBER;
    v_demo_messages        NUMBER;
    v_demo_documents       NUMBER;
    v_demo_chunks          NUMBER;
    v_initial_sources      NUMBER;
BEGIN
    IF v_container <> 'FREEPDB1' OR v_user <> 'NOXAS_DEV' THEN
        RAISE_APPLICATION_ERROR(-20061, '006_validate_installation.sql requiere NOXAS_DEV conectado a FREEPDB1.');
    END IF;

    SELECT COUNT(*)
      INTO v_table_count
      FROM user_tables
     WHERE table_name IN (
        'NOXAS_USER',
        'NOXAS_IDENTITY',
        'NOXAS_CREDENTIAL',
        'NOXAS_USER_PREFERENCE',
        'NOXAS_CONVERSATION',
        'NOXAS_MESSAGE',
        'NOXAS_SESSION',
        'NOXAS_AUDIT_EVENT',
        'NOXAS_KB_SOURCE',
        'NOXAS_KB_DOCUMENT',
        'NOXAS_KB_CHUNK',
        'NOXAS_KB_SYNC_RUN',
        'NOXAS_KB_RETRIEVAL_LOG'
     );

    SELECT COUNT(*)
      INTO v_bad_constraints
      FROM user_constraints
     WHERE table_name LIKE 'NOXAS%'
       AND (status <> 'ENABLED' OR validated <> 'VALIDATED');

    SELECT COUNT(*) INTO v_demo_users
    FROM noxas_user
    WHERE email = 'facu.demo@noxas.local';

    SELECT COUNT(*) INTO v_demo_conversations
    FROM noxas_conversation
    WHERE conversation_id = HEXTORAW('22222222222222222222222222222222');

    SELECT COUNT(*) INTO v_demo_messages
    FROM noxas_message
    WHERE conversation_id = HEXTORAW('22222222222222222222222222222222');

    SELECT COUNT(*) INTO v_demo_documents
    FROM noxas_kb_document
    WHERE external_key = 'demo-oracle-ora-01722';

    SELECT COUNT(*) INTO v_demo_chunks
    FROM noxas_kb_chunk
    WHERE document_id = HEXTORAW('33333333333333333333333333333333');

    SELECT COUNT(*) INTO v_initial_sources
    FROM noxas_kb_source
    WHERE source_code IN ('ORACLE_DOCS', 'MS_LEARN', 'LINUX_KERNEL', 'RHEL_DOCS', 'UBUNTU_SERVER');

    DBMS_OUTPUT.PUT_LINE('============================================================');
    DBMS_OUTPUT.PUT_LINE('NOXAS - Resumen de validación');
    DBMS_OUTPUT.PUT_LINE('============================================================');
    DBMS_OUTPUT.PUT_LINE('Usuario / contenedor       : ' || v_user || ' / ' || v_container);
    DBMS_OUTPUT.PUT_LINE('Tablas principales         : ' || v_table_count || ' de ' || v_expected_tables);
    DBMS_OUTPUT.PUT_LINE('Constraints no válidas     : ' || v_bad_constraints);
    DBMS_OUTPUT.PUT_LINE('Fuentes oficiales iniciales: ' || v_initial_sources || ' de 5');
    DBMS_OUTPUT.PUT_LINE('Usuario DEMO               : ' || v_demo_users);
    DBMS_OUTPUT.PUT_LINE('Conversación DEMO          : ' || v_demo_conversations);
    DBMS_OUTPUT.PUT_LINE('Mensajes DEMO              : ' || v_demo_messages || ' de 2');
    DBMS_OUTPUT.PUT_LINE('Documento DEMO             : ' || v_demo_documents);
    DBMS_OUTPUT.PUT_LINE('Fragmento DEMO             : ' || v_demo_chunks);

    IF v_table_count <> v_expected_tables THEN
        RAISE_APPLICATION_ERROR(-20062, 'Cantidad inesperada de tablas NOXAS.');
    END IF;

    IF v_bad_constraints <> 0 THEN
        RAISE_APPLICATION_ERROR(-20063, 'Existen constraints deshabilitadas o no validadas.');
    END IF;

    IF v_initial_sources <> 5 THEN
        RAISE_APPLICATION_ERROR(-20064, 'No se cargaron las cinco fuentes oficiales iniciales.');
    END IF;

    IF v_demo_users <> 1 OR v_demo_conversations <> 1 OR v_demo_messages <> 2
       OR v_demo_documents <> 1 OR v_demo_chunks <> 1 THEN
        RAISE_APPLICATION_ERROR(-20065, 'Los datos ficticios no quedaron completos.');
    END IF;

    DBMS_OUTPUT.PUT_LINE('RESULTADO                   : VALIDACIÓN CORRECTA');
END;
/

PROMPT ============================================================
PROMPT Tablas creadas
PROMPT ============================================================

SELECT table_name, num_rows, last_analyzed
FROM user_tables
WHERE table_name LIKE 'NOXAS%'
ORDER BY table_name;

PROMPT ============================================================
PROMPT Constraints
PROMPT ============================================================

SELECT table_name, constraint_name, constraint_type, status, validated
FROM user_constraints
WHERE table_name LIKE 'NOXAS%'
ORDER BY table_name, constraint_type, constraint_name;

PROMPT ============================================================
PROMPT Conversación ficticia y mensajes
PROMPT ============================================================

SELECT
    c.title,
    c.conversation_status,
    m.sequence_no,
    m.message_role,
    DBMS_LOB.SUBSTR(m.content_text, 180, 1) AS content_preview,
    m.created_at
FROM noxas_conversation c
JOIN noxas_message m
  ON m.conversation_id = c.conversation_id
WHERE c.conversation_id = HEXTORAW('22222222222222222222222222222222')
ORDER BY m.sequence_no;

PROMPT ============================================================
PROMPT Fuente, documento y fragmento ficticio
PROMPT ============================================================

SELECT
    s.source_code,
    d.title,
    d.product_version,
    c.chunk_no,
    c.embedding_status,
    DBMS_LOB.SUBSTR(c.chunk_text, 180, 1) AS chunk_preview
FROM noxas_kb_source s
JOIN noxas_kb_document d
  ON d.source_id = s.source_id
JOIN noxas_kb_chunk c
  ON c.document_id = d.document_id
WHERE d.external_key = 'demo-oracle-ora-01722';

PROMPT ============================================================
PROMPT Permisos concedidos al rol de aplicación
PROMPT ============================================================

SELECT grantee, table_name, privilege
FROM user_tab_privs_made
WHERE grantee = 'NOXAS_APP_ROLE'
ORDER BY table_name, privilege;

PROMPT 006_validate_installation.sql finalizado correctamente.
