-- NOXAS - Datos ficticios para validar relaciones y constraints
-- Ejecutar como NOXAS_DEV en FREEPDB1 después de 001 y 002.
-- Puede volver a ejecutarse: elimina únicamente los registros DEMO definidos aquí.

SET SERVEROUTPUT ON
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

DECLARE
    v_container VARCHAR2(128) := SYS_CONTEXT('USERENV', 'CON_NAME');
    v_user      VARCHAR2(128) := SYS_CONTEXT('USERENV', 'SESSION_USER');
    v_source_id RAW(16);
BEGIN
    IF v_container <> 'FREEPDB1' OR v_user <> 'NOXAS_DEV' THEN
        RAISE_APPLICATION_ERROR(-20041, '004_seed_demo_data.sql requiere NOXAS_DEV conectado a FREEPDB1.');
    END IF;

    SELECT source_id
      INTO v_source_id
      FROM noxas_kb_source
     WHERE source_code = 'ORACLE_DOCS';

    DELETE FROM noxas_kb_retrieval_log
     WHERE query_hash = 'DEMO_QUERY_HASH_ORA01722_000000000000000000000000000000000000000000000000000000000000';

    DELETE FROM noxas_kb_document
     WHERE source_id = v_source_id
       AND external_key = 'demo-oracle-ora-01722';

    DELETE FROM noxas_user
     WHERE email = 'facu.demo@noxas.local';

    INSERT INTO noxas_user (
        user_id,
        email,
        display_name,
        user_status,
        email_verified_at,
        last_login_at
    ) VALUES (
        HEXTORAW('11111111111111111111111111111111'),
        'facu.demo@noxas.local',
        'Facu Demo',
        'ACTIVE',
        SYSTIMESTAMP,
        SYSTIMESTAMP
    );

    INSERT INTO noxas_identity (
        identity_id,
        user_id,
        provider_code,
        provider_subject,
        provider_email,
        last_used_at
    ) VALUES (
        HEXTORAW('12121212121212121212121212121212'),
        HEXTORAW('11111111111111111111111111111111'),
        'GITHUB',
        'demo-github-subject-001',
        'facu.demo@noxas.local',
        SYSTIMESTAMP
    );

    INSERT INTO noxas_user_preference (
        user_id,
        theme_code,
        locale_code,
        default_model,
        reasoning_level,
        save_history_flag,
        memory_enabled_flag,
        preferences_json
    ) VALUES (
        HEXTORAW('11111111111111111111111111111111'),
        'DARK',
        'es-AR',
        'gpt-5.4-mini',
        'ADAPTIVE',
        'Y',
        'N',
        '{"demo":true,"source":"004_seed_demo_data.sql"}'
    );

    INSERT INTO noxas_conversation (
        conversation_id,
        user_id,
        title,
        conversation_status,
        pinned_flag,
        model_name,
        system_profile,
        metadata_json,
        last_message_at
    ) VALUES (
        HEXTORAW('22222222222222222222222222222222'),
        HEXTORAW('11111111111111111111111111111111'),
        'Diagnóstico ORA-01722 de prueba',
        'ACTIVE',
        'N',
        'gpt-5.4-mini',
        'TECH_SUPPORT',
        '{"demo":true,"environment":"FREEPDB1"}',
        SYSTIMESTAMP
    );

    INSERT INTO noxas_message (
        message_id,
        conversation_id,
        sequence_no,
        client_message_id,
        message_role,
        message_status,
        content_text,
        provider_name,
        model_name,
        reasoning_effort,
        input_tokens,
        output_tokens,
        latency_ms,
        metadata_json
    ) VALUES (
        HEXTORAW('23232323232323232323232323232323'),
        HEXTORAW('22222222222222222222222222222222'),
        1,
        'demo-user-message-001',
        'USER',
        'COMPLETED',
        'Tengo un ORA-01722 en un proceso ficticio. ¿Qué validaciones seguras debería realizar?',
        'NETLIFY_AI_GATEWAY',
        'gpt-5.4-mini',
        'MEDIUM',
        24,
        NULL,
        NULL,
        '{"demo":true}'
    );

    INSERT INTO noxas_message (
        message_id,
        conversation_id,
        sequence_no,
        client_message_id,
        message_role,
        message_status,
        content_text,
        provider_name,
        model_name,
        reasoning_effort,
        input_tokens,
        output_tokens,
        latency_ms,
        metadata_json
    ) VALUES (
        HEXTORAW('24242424242424242424242424242424'),
        HEXTORAW('22222222222222222222222222222222'),
        2,
        'demo-assistant-message-001',
        'ASSISTANT',
        'COMPLETED',
        'El ORA-01722 indica una conversión inválida a NUMBER. Primero conviene aislar la columna y revisar valores no numéricos con consultas SELECT antes de modificar datos.',
        'NETLIFY_AI_GATEWAY',
        'gpt-5.4-mini',
        'MEDIUM',
        24,
        42,
        850,
        '{"demo":true}'
    );

    INSERT INTO noxas_kb_document (
        document_id,
        source_id,
        external_key,
        title,
        canonical_url,
        product_name,
        product_version,
        language_code,
        document_status,
        content_hash,
        metadata_json
    ) VALUES (
        HEXTORAW('33333333333333333333333333333333'),
        v_source_id,
        'demo-oracle-ora-01722',
        'Documento ficticio de diagnóstico ORA-01722',
        'https://docs.oracle.com/error-help/db/ora-01722/',
        'Oracle Database',
        '23c Free',
        'es-AR',
        'ACTIVE',
        'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
        '{"demo":true,"copyright":"No contiene una copia de la documentación"}'
    );

    INSERT INTO noxas_kb_chunk (
        chunk_id,
        document_id,
        chunk_no,
        section_path,
        source_anchor,
        chunk_text,
        token_count,
        content_hash,
        embedding_status,
        metadata_json
    ) VALUES (
        HEXTORAW('34343434343434343434343434343434'),
        HEXTORAW('33333333333333333333333333333333'),
        0,
        'Errores de conversión > ORA-01722',
        'demo-summary',
        'Resumen ficticio: el error aparece cuando Oracle intenta convertir a número un valor cuyo formato no es numérico. La validación debe comenzar con consultas de diagnóstico y revisión de conversiones implícitas.',
        36,
        'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
        'SKIPPED',
        '{"demo":true,"embeddingReason":"VECTOR no disponible con COMPATIBLE 23.0"}'
    );

    INSERT INTO noxas_kb_retrieval_log (
        retrieval_id,
        user_id,
        conversation_id,
        query_hash,
        retrieval_mode,
        result_count,
        top_score,
        source_codes_json,
        latency_ms
    ) VALUES (
        HEXTORAW('35353535353535353535353535353535'),
        HEXTORAW('11111111111111111111111111111111'),
        HEXTORAW('22222222222222222222222222222222'),
        'DEMO_QUERY_HASH_ORA01722_000000000000000000000000000000000000000000000000000000000000',
        'KEYWORD',
        1,
        0.98,
        '["ORACLE_DOCS"]',
        18
    );

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Datos DEMO creados correctamente.');
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20042, 'No existe ORACLE_DOCS. Ejecute primero 002_knowledge_schema.sql.');
END;
/
