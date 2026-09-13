-- NOXAS Conversation API v1 - Publicación segura mediante ORDS
-- Ejecutar con F5 / Run Script conectado como NOXAS_DEV a FREEPDB1.
-- Requiere 011_conversation_api_package.sql y ORDS instalado/configurado.
--
-- Seguridad:
--   * NO se habilita AutoREST para NOXAS_CONVERSATION ni NOXAS_MESSAGE.
--   * Todo el módulo queda detrás del privilegio OAuth noxas.conversation.api.
--   * El cliente usa client_credentials y el rol NOXAS_CONVERSATION_CLIENT.
--   * El CLIENT_SECRET queda únicamente en ORDS; no debe versionarse.

SET SERVEROUTPUT ON
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

DECLARE
    v_container VARCHAR2(128) := SYS_CONTEXT('USERENV', 'CON_NAME');
    v_user      VARCHAR2(128) := SYS_CONTEXT('USERENV', 'SESSION_USER');
    v_count     PLS_INTEGER;
BEGIN
    IF v_container <> 'FREEPDB1' THEN
        RAISE_APPLICATION_ERROR(
            -20121,
            '012_conversation_ords_api.sql debe ejecutarse dentro de FREEPDB1.'
        );
    END IF;

    IF v_user <> 'NOXAS_DEV' THEN
        RAISE_APPLICATION_ERROR(
            -20122,
            '012_conversation_ords_api.sql debe ejecutarse conectado como NOXAS_DEV.'
        );
    END IF;

    SELECT COUNT(*)
      INTO v_count
      FROM user_objects
     WHERE object_name = 'NOXAS_CONVERSATION_API_PKG'
       AND object_type = 'PACKAGE'
       AND status = 'VALID';

    IF v_count <> 1 THEN
        RAISE_APPLICATION_ERROR(
            -20123,
            'Falta NOXAS_CONVERSATION_API_PKG válido. Ejecutar primero 011_conversation_api_package.sql.'
        );
    END IF;
END;
/

BEGIN
    ORDS.ENABLE_SCHEMA(
        p_enabled             => TRUE,
        p_schema              => 'NOXAS_DEV',
        p_url_mapping_type    => 'BASE_PATH',
        p_url_mapping_pattern => 'noxas',
        p_auto_rest_auth      => TRUE
    );

    ORDS.DEFINE_MODULE(
        p_module_name    => 'noxas.conversation.api.v1',
        p_base_path      => '/conversation/v1/',
        p_items_per_page => 20,
        p_status         => 'PUBLISHED',
        p_comments       => 'API privada de conversaciones persistentes para NOXAS.'
    );
END;
/

-- health/
BEGIN
    ORDS.DEFINE_TEMPLATE(
        p_module_name => 'noxas.conversation.api.v1',
        p_pattern     => 'health/'
    );

    ORDS.DEFINE_HANDLER(
        p_module_name => 'noxas.conversation.api.v1',
        p_pattern     => 'health/',
        p_method      => 'GET',
        p_source_type => ORDS.source_type_plsql,
        p_source      => q'~
DECLARE
    l_status  PLS_INTEGER;
    l_payload CLOB;
    l_offset  PLS_INTEGER := 1;
BEGIN
    noxas_conversation_api_pkg.health(
        p_http_status => l_status,
        p_payload     => l_payload
    );

    :status_code := l_status;

    OWA_UTIL.mime_header(
        'application/json; charset=utf-8',
        FALSE
    );
    OWA_UTIL.http_header_close;

    WHILE l_offset <= DBMS_LOB.GETLENGTH(l_payload) LOOP
        HTP.PRN(
            DBMS_LOB.SUBSTR(
                l_payload,
                30000,
                l_offset
            )
        );

        l_offset := l_offset + 30000;
    END LOOP;
END;
~'
    );
END;
/

-- conversations/
BEGIN
    ORDS.DEFINE_TEMPLATE(
        p_module_name => 'noxas.conversation.api.v1',
        p_pattern     => 'conversations/'
    );

    ORDS.DEFINE_HANDLER(
        p_module_name => 'noxas.conversation.api.v1',
        p_pattern     => 'conversations/',
        p_method      => 'GET',
        p_source_type => ORDS.source_type_plsql,
        p_source      => q'~
DECLARE
    l_status  PLS_INTEGER;
    l_payload CLOB;
    l_offset  PLS_INTEGER := 1;
BEGIN
    noxas_conversation_api_pkg.list_conversations(
        p_user_id_hex => :user_id,
        p_status      => :status,
        p_limit       => :max_results,
        p_http_status => l_status,
        p_payload     => l_payload
    );

    :status_code := l_status;

    OWA_UTIL.mime_header(
        'application/json; charset=utf-8',
        FALSE
    );
    OWA_UTIL.http_header_close;

    WHILE l_offset <= DBMS_LOB.GETLENGTH(l_payload) LOOP
        HTP.PRN(
            DBMS_LOB.SUBSTR(
                l_payload,
                30000,
                l_offset
            )
        );

        l_offset := l_offset + 30000;
    END LOOP;
END;
~'
    );
END;
/

-- Sin CORS para clientes web externos.
-- Esta API está pensada para backend -> ORDS.
BEGIN
    ORDS.SET_MODULE_ORIGINS_ALLOWED(
        p_module_name     => 'noxas.conversation.api.v1',
        p_origins_allowed => ''
    );
END;
/

-- Rol y privilegio que protegen el módulo completo.
DECLARE
    l_roles    OWA.vc_arr;
    l_patterns OWA.vc_arr;
    l_modules  OWA.vc_arr;
    l_count    PLS_INTEGER;
BEGIN
    SELECT COUNT(*)
      INTO l_count
      FROM user_ords_roles
     WHERE name = 'NOXAS_CONVERSATION_CLIENT';

    IF l_count = 0 THEN
        ORDS.CREATE_ROLE(
            'NOXAS_CONVERSATION_CLIENT'
        );
    END IF;

    l_roles(1)   := 'NOXAS_CONVERSATION_CLIENT';
    l_modules(1) := 'noxas.conversation.api.v1';

    ORDS.DEFINE_PRIVILEGE(
        p_privilege_name => 'noxas.conversation.api',
        p_roles          => l_roles,
        p_patterns       => l_patterns,
        p_modules        => l_modules,
        p_label          => 'NOXAS Conversation API',
        p_description    => 'Acceso backend autenticado a conversaciones persistentes de NOXAS.'
    );
END;
/

-- Cliente OAuth máquina-a-máquina.
-- Sólo se crea si todavía no existe.
DECLARE
    l_count PLS_INTEGER;
BEGIN
    SELECT COUNT(*)
      INTO l_count
      FROM user_ords_clients
     WHERE name = 'NOXAS Backend Conversation';

    IF l_count = 0 THEN
        OAUTH.CREATE_CLIENT(
            p_name            => 'NOXAS Backend Conversation',
            p_grant_type      => 'client_credentials',
            p_owner           => 'NOXAS',
            p_description     => 'Cliente backend para acceso controlado a conversaciones.',
            p_support_email   => 'support@noxas.local',
            p_privilege_names => 'noxas.conversation.api'
        );
    END IF;

    SELECT COUNT(*)
      INTO l_count
      FROM user_ords_client_roles
     WHERE client_name = 'NOXAS Backend Conversation'
       AND role_name = 'NOXAS_CONVERSATION_CLIENT';

    IF l_count = 0 THEN
        OAUTH.GRANT_CLIENT_ROLE(
            p_client_name => 'NOXAS Backend Conversation',
            p_role_name   => 'NOXAS_CONVERSATION_CLIENT'
        );
    END IF;

    COMMIT;
END;
/

PROMPT ============================================================
PROMPT NOXAS Conversation API publicada y protegida con OAuth2.
PROMPT Base local: http://localhost:8080/ords/noxas/conversation/v1/
PROMPT Token URL : http://localhost:8080/ords/noxas/oauth/token
PROMPT IMPORTANTE: no versionar CLIENT_SECRET ni access tokens.
PROMPT ============================================================
PROMPT 012_conversation_ords_api.sql finalizado correctamente.