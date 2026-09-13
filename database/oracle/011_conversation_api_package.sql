-- NOXAS Conversation API v1
-- API PL/SQL segura sobre NOXAS_CONVERSATION y NOXAS_MESSAGE.
-- Ejecutar con F5 / Run Script conectado como NOXAS_DEV a FREEPDB1.

SET SERVEROUTPUT ON
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

DECLARE
    v_container VARCHAR2(128) := SYS_CONTEXT('USERENV', 'CON_NAME');
    v_user      VARCHAR2(128) := SYS_CONTEXT('USERENV', 'SESSION_USER');
    v_count     PLS_INTEGER;
BEGIN
    IF v_container <> 'FREEPDB1' THEN
        RAISE_APPLICATION_ERROR(
            -20111,
            '011_conversation_api_package.sql debe ejecutarse dentro de FREEPDB1.'
        );
    END IF;

    IF v_user <> 'NOXAS_DEV' THEN
        RAISE_APPLICATION_ERROR(
            -20112,
            '011_conversation_api_package.sql debe ejecutarse conectado como NOXAS_DEV.'
        );
    END IF;

    SELECT COUNT(*)
      INTO v_count
      FROM user_tables
     WHERE table_name IN (
         'NOXAS_CONVERSATION',
         'NOXAS_MESSAGE'
     );

    IF v_count <> 2 THEN
        RAISE_APPLICATION_ERROR(
            -20113,
            'Faltan NOXAS_CONVERSATION o NOXAS_MESSAGE. Ejecutar primero 001_core_schema.sql.'
        );
    END IF;
END;
/

CREATE OR REPLACE PACKAGE noxas_conversation_api_pkg AUTHID DEFINER AS

    PROCEDURE health(
        p_http_status OUT PLS_INTEGER,
        p_payload     OUT CLOB
    );

    PROCEDURE list_conversations(
        p_user_id_hex IN  VARCHAR2 DEFAULT NULL,
        p_status      IN  VARCHAR2 DEFAULT 'ACTIVE',
        p_limit       IN  VARCHAR2 DEFAULT '20',
        p_http_status OUT PLS_INTEGER,
        p_payload     OUT CLOB
    );

END noxas_conversation_api_pkg;
/

SHOW ERRORS PACKAGE noxas_conversation_api_pkg

CREATE OR REPLACE PACKAGE BODY noxas_conversation_api_pkg AS

    c_api_name    CONSTANT VARCHAR2(80) := 'NOXAS Conversation API';
    c_api_version CONSTANT VARCHAR2(20) := '1.0.0';

    FUNCTION error_json(
        p_code    VARCHAR2,
        p_message VARCHAR2
    ) RETURN CLOB IS
        l_payload CLOB;
    BEGIN
        SELECT JSON_OBJECT(
                   'error' VALUE JSON_OBJECT(
                       'code' VALUE p_code,
                       'message' VALUE p_message
                   )
                   RETURNING CLOB
               )
          INTO l_payload
          FROM dual;

        RETURN l_payload;
    END;


    FUNCTION is_hex32(
        p_value VARCHAR2
    ) RETURN BOOLEAN IS
    BEGIN
        RETURN p_value IS NOT NULL
           AND REGEXP_LIKE(
               TRIM(p_value),
               '^[0-9A-Fa-f]{32}$'
           );
    END;


    PROCEDURE health(
        p_http_status OUT PLS_INTEGER,
        p_payload     OUT CLOB
    ) IS
        l_conversation_count NUMBER;
        l_message_count      NUMBER;
    BEGIN
        SELECT COUNT(*)
          INTO l_conversation_count
          FROM noxas_conversation
         WHERE conversation_status <> 'DELETED';

        SELECT COUNT(*)
          INTO l_message_count
          FROM noxas_message m
         WHERE EXISTS (
             SELECT 1
               FROM noxas_conversation c
              WHERE c.conversation_id = m.conversation_id
                AND c.conversation_status <> 'DELETED'
         );

        p_http_status := 200;

        SELECT JSON_OBJECT(
                   'ok' VALUE 'true' FORMAT JSON,
                   'api' VALUE c_api_name,
                   'version' VALUE c_api_version,
                   'schema' VALUE SYS_CONTEXT(
                       'USERENV',
                       'CURRENT_SCHEMA'
                   ),
                   'container' VALUE SYS_CONTEXT(
                       'USERENV',
                       'CON_NAME'
                   ),
                   'conversationCount' VALUE l_conversation_count,
                   'messageCount' VALUE l_message_count
                   RETURNING CLOB
               )
          INTO p_payload
          FROM dual;

    EXCEPTION
        WHEN OTHERS THEN
            p_http_status := 500;
            p_payload := error_json(
                'CONVERSATION_API_HEALTH_FAILED',
                'No se pudo consultar el estado de Conversation API.'
            );
    END health;


    PROCEDURE list_conversations(
        p_user_id_hex IN  VARCHAR2 DEFAULT NULL,
        p_status      IN  VARCHAR2 DEFAULT 'ACTIVE',
        p_limit       IN  VARCHAR2 DEFAULT '20',
        p_http_status OUT PLS_INTEGER,
        p_payload     OUT CLOB
    ) IS
        l_user_id       RAW(16);
        l_status        VARCHAR2(20);
        l_limit         PLS_INTEGER := 20;
        l_items         CLOB;
        l_matched_count PLS_INTEGER := 0;
        l_returned      PLS_INTEGER := 0;
    BEGIN
        ------------------------------------------------------------
        -- USER_ID
        ------------------------------------------------------------
        IF p_user_id_hex IS NOT NULL THEN
            IF NOT is_hex32(p_user_id_hex) THEN
                p_http_status := 400;
                p_payload := error_json(
                    'INVALID_USER_ID',
                    'user_id debe contener 32 caracteres hexadecimales.'
                );
                RETURN;
            END IF;

            l_user_id := HEXTORAW(
                UPPER(TRIM(p_user_id_hex))
            );
        END IF;


        ------------------------------------------------------------
        -- STATUS
        ------------------------------------------------------------
        l_status :=
            CASE
                WHEN p_status IS NULL THEN 'ACTIVE'
                ELSE UPPER(TRIM(p_status))
            END;

        IF l_status NOT IN (
            'ACTIVE',
            'ARCHIVED',
            'DELETED'
        ) THEN
            p_http_status := 400;
            p_payload := error_json(
                'INVALID_STATUS',
                'status debe ser ACTIVE, ARCHIVED o DELETED.'
            );
            RETURN;
        END IF;


        ------------------------------------------------------------
        -- LIMIT
        ------------------------------------------------------------
        IF p_limit IS NOT NULL THEN
            IF NOT REGEXP_LIKE(
                TRIM(p_limit),
                '^[0-9]+$'
            ) THEN
                p_http_status := 400;
                p_payload := error_json(
                    'INVALID_LIMIT',
                    'max_results debe ser un número entero.'
                );
                RETURN;
            END IF;

            l_limit := TO_NUMBER(TRIM(p_limit));
        END IF;

        IF l_limit < 1 OR l_limit > 100 THEN
            p_http_status := 400;
            p_payload := error_json(
                'INVALID_LIMIT',
                'max_results debe estar entre 1 y 100.'
            );
            RETURN;
        END IF;


        ------------------------------------------------------------
        -- TOTAL MATCHED
        ------------------------------------------------------------
        SELECT COUNT(*)
          INTO l_matched_count
          FROM noxas_conversation c
         WHERE c.conversation_status = l_status
           AND (
               l_user_id IS NULL
               OR c.user_id = l_user_id
           );


        ------------------------------------------------------------
        -- ITEMS
        ------------------------------------------------------------
        SELECT JSON_ARRAYAGG(
                   item_json FORMAT JSON
                   RETURNING CLOB
               )
          INTO l_items
          FROM (
              SELECT JSON_OBJECT(
                         'id' VALUE RAWTOHEX(c.conversation_id),
                         'userId' VALUE RAWTOHEX(c.user_id),
                         'title' VALUE c.title,
                         'status' VALUE c.conversation_status,
                         'pinned' VALUE
                             CASE
                                 WHEN c.pinned_flag = 'Y'
                                 THEN 'true'
                                 ELSE 'false'
                             END FORMAT JSON,
                         'modelName' VALUE c.model_name,
                         'systemProfile' VALUE c.system_profile,

                         'createdAt' VALUE TO_CHAR(
                             c.created_at,
                             'YYYY-MM-DD"T"HH24:MI:SS.FFTZH:TZM'
                         ),

                         'updatedAt' VALUE TO_CHAR(
                             c.updated_at,
                             'YYYY-MM-DD"T"HH24:MI:SS.FFTZH:TZM'
                         ),

                         'lastMessageAt' VALUE
                             CASE
                                 WHEN c.last_message_at IS NULL
                                 THEN NULL
                                 ELSE TO_CHAR(
                                     c.last_message_at,
                                     'YYYY-MM-DD"T"HH24:MI:SS.FFTZH:TZM'
                                 )
                             END,

                         'version' VALUE c.version_no,

                         'messageCount' VALUE (
                             SELECT COUNT(*)
                               FROM noxas_message m
                              WHERE m.conversation_id =
                                    c.conversation_id
                         ),

                         'userMessageCount' VALUE (
                             SELECT COUNT(*)
                               FROM noxas_message m
                              WHERE m.conversation_id =
                                    c.conversation_id
                                AND m.message_role = 'USER'
                         )

                         RETURNING CLOB
                     ) AS item_json
                FROM noxas_conversation c
               WHERE c.conversation_status = l_status
                 AND (
                     l_user_id IS NULL
                     OR c.user_id = l_user_id
                 )
               ORDER BY
                     c.pinned_flag DESC,
                     NVL(
                         c.last_message_at,
                         c.updated_at
                     ) DESC
               FETCH FIRST l_limit ROWS ONLY
          );

        IF l_items IS NULL THEN
            l_items := TO_CLOB('[]');
        END IF;


        SELECT COUNT(*)
          INTO l_returned
          FROM (
              SELECT 1
                FROM noxas_conversation c
               WHERE c.conversation_status = l_status
                 AND (
                     l_user_id IS NULL
                     OR c.user_id = l_user_id
                 )
               ORDER BY
                     c.pinned_flag DESC,
                     NVL(
                         c.last_message_at,
                         c.updated_at
                     ) DESC
               FETCH FIRST l_limit ROWS ONLY
          );


        ------------------------------------------------------------
        -- RESPONSE
        ------------------------------------------------------------
        p_http_status := 200;

        SELECT JSON_OBJECT(
                   'items' VALUE l_items FORMAT JSON,
                   'matchedCount' VALUE l_matched_count,
                   'returnedCount' VALUE l_returned
                   RETURNING CLOB
               )
          INTO p_payload
          FROM dual;

    EXCEPTION
        WHEN OTHERS THEN
            p_http_status := 500;
            p_payload := error_json(
                'CONVERSATION_LIST_FAILED',
                'No se pudieron listar las conversaciones.'
            );
    END list_conversations;

END noxas_conversation_api_pkg;
/

SHOW ERRORS PACKAGE BODY noxas_conversation_api_pkg

PROMPT ==========================================
PROMPT NOXAS Conversation API package instalado.
PROMPT ==========================================