-- NOXAS Memory API v1 - API PL/SQL segura sobre NOXAS_MEMORY
-- Ejecutar con F5 / Run Script conectado como NOXAS_DEV al servicio FREEPDB1.
-- Requiere 001_core_schema.sql y 005_agent_schema.sql.

SET SERVEROUTPUT ON
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

DECLARE
    v_container VARCHAR2(128) := SYS_CONTEXT('USERENV', 'CON_NAME');
    v_user      VARCHAR2(128) := SYS_CONTEXT('USERENV', 'SESSION_USER');
    v_count     PLS_INTEGER;
BEGIN
    IF v_container <> 'FREEPDB1' THEN
        RAISE_APPLICATION_ERROR(-20081, '007_memory_api_package.sql debe ejecutarse dentro de FREEPDB1.');
    END IF;

    IF v_user <> 'NOXAS_DEV' THEN
        RAISE_APPLICATION_ERROR(-20082, '007_memory_api_package.sql debe ejecutarse conectado como NOXAS_DEV.');
    END IF;

    SELECT COUNT(*)
      INTO v_count
      FROM user_tables
     WHERE table_name = 'NOXAS_MEMORY';

    IF v_count <> 1 THEN
        RAISE_APPLICATION_ERROR(-20083, 'Falta la tabla NOXAS_MEMORY. Ejecutar primero 005_agent_schema.sql.');
    END IF;
END;
/

CREATE OR REPLACE PACKAGE noxas_memory_api_pkg AUTHID DEFINER AS
    PROCEDURE health(
        p_http_status OUT PLS_INTEGER,
        p_payload     OUT CLOB
    );

    PROCEDURE list_memories(
        p_user_id_hex IN  VARCHAR2 DEFAULT NULL,
        p_scope       IN  VARCHAR2 DEFAULT NULL,
        p_type        IN  VARCHAR2 DEFAULT NULL,
        p_status      IN  VARCHAR2 DEFAULT 'ACTIVE',
        p_limit       IN  VARCHAR2 DEFAULT '20',
        p_http_status OUT PLS_INTEGER,
        p_payload     OUT CLOB
    );

    PROCEDURE get_memory(
        p_memory_id_hex IN  VARCHAR2,
        p_http_status   OUT PLS_INTEGER,
        p_payload       OUT CLOB
    );

    PROCEDURE create_memory(
        p_body        IN  CLOB,
        p_http_status OUT PLS_INTEGER,
        p_payload     OUT CLOB
    );

    PROCEDURE set_memory_status(
        p_memory_id_hex IN  VARCHAR2,
        p_new_status    IN  VARCHAR2,
        p_http_status   OUT PLS_INTEGER,
        p_payload       OUT CLOB
    );
END noxas_memory_api_pkg;
/

SHOW ERRORS PACKAGE noxas_memory_api_pkg

CREATE OR REPLACE PACKAGE BODY noxas_memory_api_pkg AS
    c_api_name    CONSTANT VARCHAR2(80) := 'NOXAS Memory API';
    c_api_version CONSTANT VARCHAR2(20) := '1.0.0';

    FUNCTION error_json(p_code VARCHAR2, p_message VARCHAR2) RETURN CLOB IS
    BEGIN
        RETURN JSON_OBJECT(
            'error' VALUE JSON_OBJECT(
                'code' VALUE p_code,
                'message' VALUE p_message
            )
            RETURNING CLOB
        );
    END;

    FUNCTION is_hex32(p_value VARCHAR2) RETURN BOOLEAN IS
    BEGIN
        RETURN p_value IS NOT NULL
           AND REGEXP_LIKE(TRIM(p_value), '^[0-9A-Fa-f]{32}$');
    END;

    FUNCTION raw_id(p_value VARCHAR2, p_field VARCHAR2) RETURN RAW IS
    BEGIN
        IF NOT is_hex32(p_value) THEN
            RAISE_APPLICATION_ERROR(-20084, p_field || ' debe contener 32 caracteres hexadecimales.');
        END IF;
        RETURN HEXTORAW(UPPER(TRIM(p_value)));
    END;

    FUNCTION memory_json(p_memory_id RAW) RETURN CLOB IS
        l_payload CLOB;
    BEGIN
        SELECT JSON_OBJECT(
                   'memoryId' VALUE RAWTOHEX(memory_id),
                   'userId' VALUE CASE WHEN user_id IS NULL THEN NULL ELSE RAWTOHEX(user_id) END,
                   'sourceRunId' VALUE CASE WHEN source_run_id IS NULL THEN NULL ELSE RAWTOHEX(source_run_id) END,
                   'scope' VALUE memory_scope,
                   'type' VALUE memory_type,
                   'status' VALUE memory_status,
                   'title' VALUE title,
                   'contentText' VALUE content_text,
                   'confidenceScore' VALUE confidence_score,
                   'importanceScore' VALUE importance_score,
                   'sourceReference' VALUE source_reference,
                   'metadataJson' VALUE metadata_json,
                   'lastUsedAt' VALUE CASE WHEN last_used_at IS NULL THEN NULL ELSE TO_CHAR(last_used_at, 'YYYY-MM-DD"T"HH24:MI:SS.FFTZH:TZM') END,
                   'expiresAt' VALUE CASE WHEN expires_at IS NULL THEN NULL ELSE TO_CHAR(expires_at, 'YYYY-MM-DD"T"HH24:MI:SS.FFTZH:TZM') END,
                   'createdAt' VALUE TO_CHAR(created_at, 'YYYY-MM-DD"T"HH24:MI:SS.FFTZH:TZM'),
                   'updatedAt' VALUE TO_CHAR(updated_at, 'YYYY-MM-DD"T"HH24:MI:SS.FFTZH:TZM')
                   RETURNING CLOB
               )
          INTO l_payload
          FROM noxas_memory
         WHERE memory_id = p_memory_id;

        RETURN l_payload;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN NULL;
    END;

    PROCEDURE write_audit(
        p_user_id     IN RAW,
        p_event_type  IN VARCHAR2,
        p_resource_id IN VARCHAR2,
        p_details     IN VARCHAR2
    ) IS
    BEGIN
        INSERT INTO noxas_audit_event (
            user_id,
            event_type,
            event_result,
            resource_type,
            resource_id,
            details_json
        ) VALUES (
            p_user_id,
            p_event_type,
            'SUCCESS',
            'NOXAS_MEMORY',
            p_resource_id,
            JSON_OBJECT('detail' VALUE p_details RETURNING CLOB)
        );
    END;

    PROCEDURE health(
        p_http_status OUT PLS_INTEGER,
        p_payload     OUT CLOB
    ) IS
        l_count NUMBER;
    BEGIN
        SELECT COUNT(*) INTO l_count FROM noxas_memory WHERE memory_status <> 'DELETED';

        p_http_status := 200;
        p_payload := JSON_OBJECT(
            'ok' VALUE 'true' FORMAT JSON,
            'api' VALUE c_api_name,
            'version' VALUE c_api_version,
            'schema' VALUE SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'),
            'container' VALUE SYS_CONTEXT('USERENV', 'CON_NAME'),
            'memoryCount' VALUE l_count
            RETURNING CLOB
        );
    EXCEPTION
        WHEN OTHERS THEN
            p_http_status := 500;
            p_payload := error_json('MEMORY_API_HEALTH_FAILED', 'No se pudo consultar el estado de la API.');
    END;

    PROCEDURE list_memories(
        p_user_id_hex IN  VARCHAR2 DEFAULT NULL,
        p_scope       IN  VARCHAR2 DEFAULT NULL,
        p_type        IN  VARCHAR2 DEFAULT NULL,
        p_status      IN  VARCHAR2 DEFAULT 'ACTIVE',
        p_limit       IN  VARCHAR2 DEFAULT '20',
        p_http_status OUT PLS_INTEGER,
        p_payload     OUT CLOB
    ) IS
        l_user_id       RAW(16);
        l_scope         VARCHAR2(20);
        l_type          VARCHAR2(30);
        l_status        VARCHAR2(20);
        l_limit         PLS_INTEGER := 20;
        l_items         CLOB;
        l_matched_count PLS_INTEGER := 0;
        l_returned      PLS_INTEGER := 0;
    BEGIN
        IF p_user_id_hex IS NOT NULL THEN
            l_user_id := raw_id(p_user_id_hex, 'user_id');
        END IF;

        l_scope := CASE WHEN p_scope IS NULL THEN NULL ELSE UPPER(TRIM(p_scope)) END;
        l_type := CASE WHEN p_type IS NULL THEN NULL ELSE UPPER(TRIM(p_type)) END;
        l_status := CASE WHEN p_status IS NULL THEN NULL ELSE UPPER(TRIM(p_status)) END;

        IF l_scope IS NOT NULL AND l_scope NOT IN ('USER', 'PROJECT', 'CONVERSATION', 'SYSTEM') THEN
            p_http_status := 400;
            p_payload := error_json('INVALID_SCOPE', 'scope no es válido.');
            RETURN;
        END IF;

        IF l_type IS NOT NULL AND l_type NOT IN ('FACT', 'PREFERENCE', 'PROJECT_DECISION', 'WORKFLOW', 'TECHNICAL_NOTE', 'SUMMARY') THEN
            p_http_status := 400;
            p_payload := error_json('INVALID_TYPE', 'type no es válido.');
            RETURN;
        END IF;

        IF l_status IS NOT NULL AND l_status NOT IN ('CANDIDATE', 'ACTIVE', 'ARCHIVED', 'REJECTED') THEN
            p_http_status := 400;
            p_payload := error_json('INVALID_STATUS', 'status no es válido para lectura.');
            RETURN;
        END IF;

        BEGIN
            l_limit := TO_NUMBER(NVL(TRIM(p_limit), '20'));
        EXCEPTION
            WHEN VALUE_ERROR THEN
                l_limit := 20;
        END;
        l_limit := LEAST(GREATEST(l_limit, 1), 50);

        SELECT COUNT(*)
          INTO l_matched_count
          FROM noxas_memory
         WHERE memory_status <> 'DELETED'
           AND (l_user_id IS NULL OR user_id = l_user_id)
           AND (l_scope IS NULL OR memory_scope = l_scope)
           AND (l_type IS NULL OR memory_type = l_type)
           AND (l_status IS NULL OR memory_status = l_status);

        SELECT JSON_ARRAYAGG(
                   JSON_OBJECT(
                       'memoryId' VALUE RAWTOHEX(memory_id),
                       'userId' VALUE CASE WHEN user_id IS NULL THEN NULL ELSE RAWTOHEX(user_id) END,
                       'scope' VALUE memory_scope,
                       'type' VALUE memory_type,
                       'status' VALUE memory_status,
                       'title' VALUE title,
                       'contentPreview' VALUE DBMS_LOB.SUBSTR(content_text, 500, 1),
                       'confidenceScore' VALUE confidence_score,
                       'importanceScore' VALUE importance_score,
                       'updatedAt' VALUE TO_CHAR(updated_at, 'YYYY-MM-DD"T"HH24:MI:SS.FFTZH:TZM')
                       RETURNING VARCHAR2(4000)
                   )
                   RETURNING CLOB
               ),
               COUNT(*)
          INTO l_items, l_returned
          FROM (
              SELECT *
                FROM (
                    SELECT m.*
                      FROM noxas_memory m
                     WHERE m.memory_status <> 'DELETED'
                       AND (l_user_id IS NULL OR m.user_id = l_user_id)
                       AND (l_scope IS NULL OR m.memory_scope = l_scope)
                       AND (l_type IS NULL OR m.memory_type = l_type)
                       AND (l_status IS NULL OR m.memory_status = l_status)
                     ORDER BY m.updated_at DESC
                )
               WHERE ROWNUM <= l_limit
          );

        IF l_items IS NULL THEN
            l_items := TO_CLOB('[]');
        END IF;

        p_http_status := 200;
        p_payload := TO_CLOB('{"items":') || l_items
                  || ',"returnedCount":' || TO_CHAR(l_returned)
                  || ',"matchedCount":' || TO_CHAR(l_matched_count)
                  || ',"limit":' || TO_CHAR(l_limit) || '}';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE = -20084 THEN
                p_http_status := 400;
                p_payload := error_json('INVALID_ID', SQLERRM);
            ELSE
                p_http_status := 500;
                p_payload := error_json('MEMORY_LIST_FAILED', 'No se pudieron listar las memorias.');
            END IF;
    END;

    PROCEDURE get_memory(
        p_memory_id_hex IN  VARCHAR2,
        p_http_status   OUT PLS_INTEGER,
        p_payload       OUT CLOB
    ) IS
        l_memory_id RAW(16);
    BEGIN
        l_memory_id := raw_id(p_memory_id_hex, 'memory_id');
        p_payload := memory_json(l_memory_id);

        IF p_payload IS NULL THEN
            p_http_status := 404;
            p_payload := error_json('MEMORY_NOT_FOUND', 'La memoria no existe.');
            RETURN;
        END IF;

        p_http_status := 200;
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE = -20084 THEN
                p_http_status := 400;
                p_payload := error_json('INVALID_ID', SQLERRM);
            ELSE
                p_http_status := 500;
                p_payload := error_json('MEMORY_GET_FAILED', 'No se pudo leer la memoria.');
            END IF;
    END;

    PROCEDURE create_memory(
        p_body        IN  CLOB,
        p_http_status OUT PLS_INTEGER,
        p_payload     OUT CLOB
    ) IS
        l_json              JSON_OBJECT_T;
        l_memory_id         RAW(16) := SYS_GUID();
        l_user_id           RAW(16);
        l_source_run_id     RAW(16);
        l_scope             VARCHAR2(20) := 'USER';
        l_type              VARCHAR2(30);
        l_title             VARCHAR2(240);
        l_content           VARCHAR2(12000);
        l_source_reference  VARCHAR2(1000);
        l_confidence        NUMBER;
        l_importance        NUMBER;
        l_count             PLS_INTEGER;
    BEGIN
        IF p_body IS NULL OR DBMS_LOB.GETLENGTH(p_body) = 0 OR DBMS_LOB.GETLENGTH(p_body) > 16000 THEN
            p_http_status := 400;
            p_payload := error_json('INVALID_BODY', 'El cuerpo JSON es obligatorio y debe tener hasta 16000 caracteres.');
            RETURN;
        END IF;

        BEGIN
            l_json := JSON_OBJECT_T.parse(p_body);
        EXCEPTION
            WHEN OTHERS THEN
                p_http_status := 400;
                p_payload := error_json('INVALID_JSON', 'El cuerpo no contiene JSON válido.');
                RETURN;
        END;

        IF NOT l_json.has('memory_type') OR NOT l_json.has('title') OR NOT l_json.has('content_text') THEN
            p_http_status := 400;
            p_payload := error_json('MISSING_FIELDS', 'memory_type, title y content_text son obligatorios.');
            RETURN;
        END IF;

        l_type := UPPER(TRIM(l_json.get_string('memory_type')));
        l_title := TRIM(l_json.get_string('title'));
        l_content := l_json.get_string('content_text');

        IF l_json.has('memory_scope') THEN
            l_scope := UPPER(TRIM(l_json.get_string('memory_scope')));
        END IF;

        IF l_json.has('user_id') AND l_json.get_string('user_id') IS NOT NULL THEN
            l_user_id := raw_id(l_json.get_string('user_id'), 'user_id');
        END IF;

        IF l_json.has('source_run_id') AND l_json.get_string('source_run_id') IS NOT NULL THEN
            l_source_run_id := raw_id(l_json.get_string('source_run_id'), 'source_run_id');
        END IF;

        IF l_json.has('source_reference') THEN
            l_source_reference := SUBSTR(l_json.get_string('source_reference'), 1, 1000);
        END IF;

        IF l_json.has('confidence_score') THEN
            l_confidence := l_json.get_number('confidence_score');
        END IF;

        IF l_json.has('importance_score') THEN
            l_importance := l_json.get_number('importance_score');
        END IF;

        IF l_scope NOT IN ('USER', 'PROJECT', 'CONVERSATION', 'SYSTEM') THEN
            p_http_status := 400;
            p_payload := error_json('INVALID_SCOPE', 'memory_scope no es válido.');
            RETURN;
        END IF;

        IF l_type NOT IN ('FACT', 'PREFERENCE', 'PROJECT_DECISION', 'WORKFLOW', 'TECHNICAL_NOTE', 'SUMMARY') THEN
            p_http_status := 400;
            p_payload := error_json('INVALID_TYPE', 'memory_type no es válido.');
            RETURN;
        END IF;

        IF l_title IS NULL OR LENGTH(l_title) > 240 THEN
            p_http_status := 400;
            p_payload := error_json('INVALID_TITLE', 'title debe tener entre 1 y 240 caracteres.');
            RETURN;
        END IF;

        IF l_content IS NULL OR LENGTH(l_content) > 12000 THEN
            p_http_status := 400;
            p_payload := error_json('INVALID_CONTENT', 'content_text debe tener entre 1 y 12000 caracteres.');
            RETURN;
        END IF;

        IF l_confidence IS NOT NULL AND (l_confidence < 0 OR l_confidence > 1) THEN
            p_http_status := 400;
            p_payload := error_json('INVALID_CONFIDENCE', 'confidence_score debe estar entre 0 y 1.');
            RETURN;
        END IF;

        IF l_importance IS NOT NULL AND (l_importance < 0 OR l_importance > 1) THEN
            p_http_status := 400;
            p_payload := error_json('INVALID_IMPORTANCE', 'importance_score debe estar entre 0 y 1.');
            RETURN;
        END IF;

        IF l_scope = 'USER' AND l_user_id IS NULL THEN
            p_http_status := 400;
            p_payload := error_json('USER_REQUIRED', 'user_id es obligatorio para memorias con scope USER.');
            RETURN;
        END IF;

        IF l_user_id IS NOT NULL THEN
            SELECT COUNT(*) INTO l_count
              FROM noxas_user
             WHERE user_id = l_user_id
               AND user_status = 'ACTIVE';
            IF l_count <> 1 THEN
                p_http_status := 400;
                p_payload := error_json('USER_NOT_FOUND', 'user_id no corresponde a un usuario activo.');
                RETURN;
            END IF;
        END IF;

        IF l_source_run_id IS NOT NULL THEN
            SELECT COUNT(*) INTO l_count
              FROM noxas_agent_run
             WHERE agent_run_id = l_source_run_id;
            IF l_count <> 1 THEN
                p_http_status := 400;
                p_payload := error_json('RUN_NOT_FOUND', 'source_run_id no existe.');
                RETURN;
            END IF;
        END IF;

        INSERT INTO noxas_memory (
            memory_id,
            user_id,
            source_run_id,
            memory_scope,
            memory_type,
            memory_status,
            title,
            content_text,
            confidence_score,
            importance_score,
            source_reference
        ) VALUES (
            l_memory_id,
            l_user_id,
            l_source_run_id,
            l_scope,
            l_type,
            'CANDIDATE',
            l_title,
            TO_CLOB(l_content),
            l_confidence,
            l_importance,
            l_source_reference
        );

        write_audit(
            p_user_id     => l_user_id,
            p_event_type  => 'MEMORY_CREATED',
            p_resource_id => RAWTOHEX(l_memory_id),
            p_details     => 'Memoria creada en estado CANDIDATE mediante NOXAS Memory API.'
        );

        COMMIT;
        p_http_status := 201;
        p_payload := memory_json(l_memory_id);
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            IF SQLCODE = -20084 THEN
                p_http_status := 400;
                p_payload := error_json('INVALID_ID', SQLERRM);
            ELSE
                p_http_status := 500;
                p_payload := error_json('MEMORY_CREATE_FAILED', 'No se pudo crear la memoria.');
            END IF;
    END;

    PROCEDURE set_memory_status(
        p_memory_id_hex IN  VARCHAR2,
        p_new_status    IN  VARCHAR2,
        p_http_status   OUT PLS_INTEGER,
        p_payload       OUT CLOB
    ) IS
        l_memory_id RAW(16);
        l_status    VARCHAR2(20) := UPPER(TRIM(p_new_status));
        l_user_id   RAW(16);
    BEGIN
        IF l_status NOT IN ('ACTIVE', 'ARCHIVED') THEN
            p_http_status := 400;
            p_payload := error_json('INVALID_STATUS', 'La API sólo permite activar o archivar memorias.');
            RETURN;
        END IF;

        l_memory_id := raw_id(p_memory_id_hex, 'memory_id');

        BEGIN
            SELECT user_id
              INTO l_user_id
              FROM noxas_memory
             WHERE memory_id = l_memory_id
               AND memory_status <> 'DELETED'
             FOR UPDATE;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                p_http_status := 404;
                p_payload := error_json('MEMORY_NOT_FOUND', 'La memoria no existe.');
                RETURN;
        END;

        UPDATE noxas_memory
           SET memory_status = l_status,
               updated_at = SYSTIMESTAMP
         WHERE memory_id = l_memory_id;

        write_audit(
            p_user_id     => l_user_id,
            p_event_type  => 'MEMORY_STATUS_CHANGED',
            p_resource_id => RAWTOHEX(l_memory_id),
            p_details     => 'Estado actualizado a ' || l_status || ' mediante NOXAS Memory API.'
        );

        COMMIT;
        p_http_status := 200;
        p_payload := memory_json(l_memory_id);
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            IF SQLCODE = -20084 THEN
                p_http_status := 400;
                p_payload := error_json('INVALID_ID', SQLERRM);
            ELSE
                p_http_status := 500;
                p_payload := error_json('MEMORY_STATUS_FAILED', 'No se pudo actualizar el estado de la memoria.');
            END IF;
    END;
END noxas_memory_api_pkg;
/

SHOW ERRORS PACKAGE BODY noxas_memory_api_pkg

DECLARE
    v_invalid PLS_INTEGER;
BEGIN
    SELECT COUNT(*)
      INTO v_invalid
      FROM user_objects
     WHERE object_name = 'NOXAS_MEMORY_API_PKG'
       AND status <> 'VALID';

    IF v_invalid > 0 THEN
        RAISE_APPLICATION_ERROR(-20085, 'NOXAS_MEMORY_API_PKG quedó INVALID. Revisar SHOW ERRORS.');
    END IF;
END;
/

COMMIT;
PROMPT 007_memory_api_package.sql finalizado correctamente.
