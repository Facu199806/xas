-- NOXAS Memory API v1 - Publicación segura mediante Oracle REST Data Services (ORDS)
-- Ejecutar con F5 / Run Script conectado como NOXAS_DEV al servicio FREEPDB1.
-- Requiere 007_memory_api_package.sql y ORDS instalado/configurado.
--
-- Seguridad:
--   * NO se habilita AutoREST para NOXAS_MEMORY.
--   * Todo el módulo queda detrás del privilegio OAuth noxas.memory.api.
--   * El cliente usa client_credentials y el rol NOXAS_MEMORY_CLIENT.
--   * El CLIENT_SECRET queda únicamente en ORDS; no debe versionarse.

SET SERVEROUTPUT ON
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

DECLARE
    v_container VARCHAR2(128) := SYS_CONTEXT('USERENV', 'CON_NAME');
    v_user      VARCHAR2(128) := SYS_CONTEXT('USERENV', 'SESSION_USER');
    v_count     PLS_INTEGER;
BEGIN
    IF v_container <> 'FREEPDB1' THEN
        RAISE_APPLICATION_ERROR(-20086, '008_memory_ords_api.sql debe ejecutarse dentro de FREEPDB1.');
    END IF;

    IF v_user <> 'NOXAS_DEV' THEN
        RAISE_APPLICATION_ERROR(-20087, '008_memory_ords_api.sql debe ejecutarse conectado como NOXAS_DEV.');
    END IF;

    SELECT COUNT(*)
      INTO v_count
      FROM user_objects
     WHERE object_name = 'NOXAS_MEMORY_API_PKG'
       AND object_type = 'PACKAGE'
       AND status = 'VALID';

    IF v_count <> 1 THEN
        RAISE_APPLICATION_ERROR(-20088, 'Falta NOXAS_MEMORY_API_PKG válido. Ejecutar primero 007_memory_api_package.sql.');
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
        p_module_name    => 'noxas.memory.api.v1',
        p_base_path      => '/memory/v1/',
        p_items_per_page => 20,
        p_status         => 'PUBLISHED',
        p_comments       => 'API privada de memoria para NOXAS Agent.'
    );
END;
/

-- health/
BEGIN
    ORDS.DEFINE_TEMPLATE(
        p_module_name => 'noxas.memory.api.v1',
        p_pattern     => 'health/'
    );

    ORDS.DEFINE_HANDLER(
        p_module_name => 'noxas.memory.api.v1',
        p_pattern     => 'health/',
        p_method      => 'GET',
        p_source_type => ORDS.source_type_plsql,
        p_source      => q'~
DECLARE
    l_status  PLS_INTEGER;
    l_payload CLOB;
    l_offset  PLS_INTEGER := 1;
BEGIN
    noxas_memory_api_pkg.health(l_status, l_payload);
    :status_code := l_status;
    OWA_UTIL.mime_header('application/json; charset=utf-8', FALSE);
    OWA_UTIL.http_header_close;
    WHILE l_offset <= DBMS_LOB.GETLENGTH(l_payload) LOOP
        HTP.PRN(DBMS_LOB.SUBSTR(l_payload, 30000, l_offset));
        l_offset := l_offset + 30000;
    END LOOP;
END;
~'
    );
END;
/

-- memories/ : GET list, POST create
BEGIN
    ORDS.DEFINE_TEMPLATE(
        p_module_name => 'noxas.memory.api.v1',
        p_pattern     => 'memories/'
    );

    ORDS.DEFINE_HANDLER(
        p_module_name   => 'noxas.memory.api.v1',
        p_pattern       => 'memories/',
        p_method        => 'GET',
        p_source_type   => ORDS.source_type_plsql,
        p_source        => q'~
DECLARE
    l_status  PLS_INTEGER;
    l_payload CLOB;
    l_offset  PLS_INTEGER := 1;
BEGIN
    noxas_memory_api_pkg.list_memories(
        p_user_id_hex => :user_id,
        p_scope       => :scope,
        p_type        => :type,
        p_status      => :status,
        p_limit       => :max_results,
        p_http_status => l_status,
        p_payload     => l_payload
    );
    :status_code := l_status;
    OWA_UTIL.mime_header('application/json; charset=utf-8', FALSE);
    OWA_UTIL.http_header_close;
    WHILE l_offset <= DBMS_LOB.GETLENGTH(l_payload) LOOP
        HTP.PRN(DBMS_LOB.SUBSTR(l_payload, 30000, l_offset));
        l_offset := l_offset + 30000;
    END LOOP;
END;
~'
    );

    ORDS.DEFINE_HANDLER(
        p_module_name   => 'noxas.memory.api.v1',
        p_pattern       => 'memories/',
        p_method        => 'POST',
        p_mimes_allowed => 'application/json',
        p_source_type   => ORDS.source_type_plsql,
        p_source        => q'~
DECLARE
    l_body    CLOB := :body_text;
    l_status  PLS_INTEGER;
    l_payload CLOB;
    l_offset  PLS_INTEGER := 1;
BEGIN
    noxas_memory_api_pkg.create_memory(
        p_body        => l_body,
        p_http_status => l_status,
        p_payload     => l_payload
    );
    :status_code := l_status;
    OWA_UTIL.mime_header('application/json; charset=utf-8', FALSE);
    OWA_UTIL.http_header_close;
    WHILE l_offset <= DBMS_LOB.GETLENGTH(l_payload) LOOP
        HTP.PRN(DBMS_LOB.SUBSTR(l_payload, 30000, l_offset));
        l_offset := l_offset + 30000;
    END LOOP;
END;
~'
    );
END;
/

-- memories/:id
BEGIN
    ORDS.DEFINE_TEMPLATE(
        p_module_name => 'noxas.memory.api.v1',
        p_pattern     => 'memories/:id'
    );

    ORDS.DEFINE_HANDLER(
        p_module_name => 'noxas.memory.api.v1',
        p_pattern     => 'memories/:id',
        p_method      => 'GET',
        p_source_type => ORDS.source_type_plsql,
        p_source      => q'~
DECLARE
    l_status  PLS_INTEGER;
    l_payload CLOB;
    l_offset  PLS_INTEGER := 1;
BEGIN
    noxas_memory_api_pkg.get_memory(
        p_memory_id_hex => :id,
        p_http_status   => l_status,
        p_payload       => l_payload
    );
    :status_code := l_status;
    OWA_UTIL.mime_header('application/json; charset=utf-8', FALSE);
    OWA_UTIL.http_header_close;
    WHILE l_offset <= DBMS_LOB.GETLENGTH(l_payload) LOOP
        HTP.PRN(DBMS_LOB.SUBSTR(l_payload, 30000, l_offset));
        l_offset := l_offset + 30000;
    END LOOP;
END;
~'
    );
END;
/

-- memories/:id/activate
BEGIN
    ORDS.DEFINE_TEMPLATE(
        p_module_name => 'noxas.memory.api.v1',
        p_pattern     => 'memories/:id/activate'
    );

    ORDS.DEFINE_HANDLER(
        p_module_name => 'noxas.memory.api.v1',
        p_pattern     => 'memories/:id/activate',
        p_method      => 'POST',
        p_source_type => ORDS.source_type_plsql,
        p_source      => q'~
DECLARE
    l_status  PLS_INTEGER;
    l_payload CLOB;
    l_offset  PLS_INTEGER := 1;
BEGIN
    noxas_memory_api_pkg.set_memory_status(
        p_memory_id_hex => :id,
        p_new_status    => 'ACTIVE',
        p_http_status   => l_status,
        p_payload       => l_payload
    );
    :status_code := l_status;
    OWA_UTIL.mime_header('application/json; charset=utf-8', FALSE);
    OWA_UTIL.http_header_close;
    WHILE l_offset <= DBMS_LOB.GETLENGTH(l_payload) LOOP
        HTP.PRN(DBMS_LOB.SUBSTR(l_payload, 30000, l_offset));
        l_offset := l_offset + 30000;
    END LOOP;
END;
~'
    );
END;
/

-- memories/:id/archive
BEGIN
    ORDS.DEFINE_TEMPLATE(
        p_module_name => 'noxas.memory.api.v1',
        p_pattern     => 'memories/:id/archive'
    );

    ORDS.DEFINE_HANDLER(
        p_module_name => 'noxas.memory.api.v1',
        p_pattern     => 'memories/:id/archive',
        p_method      => 'POST',
        p_source_type => ORDS.source_type_plsql,
        p_source      => q'~
DECLARE
    l_status  PLS_INTEGER;
    l_payload CLOB;
    l_offset  PLS_INTEGER := 1;
BEGIN
    noxas_memory_api_pkg.set_memory_status(
        p_memory_id_hex => :id,
        p_new_status    => 'ARCHIVED',
        p_http_status   => l_status,
        p_payload       => l_payload
    );
    :status_code := l_status;
    OWA_UTIL.mime_header('application/json; charset=utf-8', FALSE);
    OWA_UTIL.http_header_close;
    WHILE l_offset <= DBMS_LOB.GETLENGTH(l_payload) LOOP
        HTP.PRN(DBMS_LOB.SUBSTR(l_payload, 30000, l_offset));
        l_offset := l_offset + 30000;
    END LOOP;
END;
~'
    );
END;
/

-- Sin CORS para clientes web externos: esta API está pensada para backend -> ORDS.
BEGIN
    ORDS.SET_MODULE_ORIGINS_ALLOWED(
        p_module_name     => 'noxas.memory.api.v1',
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
     WHERE name = 'NOXAS_MEMORY_CLIENT';

    IF l_count = 0 THEN
        ORDS.CREATE_ROLE('NOXAS_MEMORY_CLIENT');
    END IF;

    l_roles(1) := 'NOXAS_MEMORY_CLIENT';
    l_modules(1) := 'noxas.memory.api.v1';

    ORDS.DEFINE_PRIVILEGE(
        p_privilege_name => 'noxas.memory.api',
        p_roles          => l_roles,
        p_patterns       => l_patterns,
        p_modules        => l_modules,
        p_label          => 'NOXAS Memory API',
        p_description    => 'Acceso backend autenticado a la memoria persistente de NOXAS.'
    );
END;
/

-- Cliente OAuth máquina-a-máquina. Sólo se crea si todavía no existe.
DECLARE
    l_count PLS_INTEGER;
BEGIN
    SELECT COUNT(*)
      INTO l_count
      FROM user_ords_clients
     WHERE name = 'NOXAS Backend Memory';

    IF l_count = 0 THEN
        OAUTH.CREATE_CLIENT(
            p_name            => 'NOXAS Backend Memory',
            p_grant_type      => 'client_credentials',
            p_owner           => 'NOXAS',
            p_description     => 'Cliente backend para lectura y escritura controlada de memoria.',
            p_support_email   => 'support@noxas.local',
            p_privilege_names => 'noxas.memory.api'
        );
    END IF;

    SELECT COUNT(*)
      INTO l_count
      FROM user_ords_client_roles
     WHERE client_name = 'NOXAS Backend Memory'
       AND role_name = 'NOXAS_MEMORY_CLIENT';

    IF l_count = 0 THEN
        OAUTH.GRANT_CLIENT_ROLE(
            p_client_name => 'NOXAS Backend Memory',
            p_role_name   => 'NOXAS_MEMORY_CLIENT'
        );
    END IF;

    COMMIT;
END;
/

PROMPT ============================================================
PROMPT NOXAS Memory API publicada y protegida con OAuth2.
PROMPT Base local: http://localhost:8080/ords/noxas/memory/v1/
PROMPT Token URL : http://localhost:8080/ords/noxas/oauth/token
PROMPT IMPORTANTE: no pegues CLIENT_SECRET en Git, Jira ni chats.
PROMPT ============================================================
PROMPT 008_memory_ords_api.sql finalizado correctamente.
