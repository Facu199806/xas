-- NOXAS Agent v1 - Prueba transaccional de memoria y ejecucion
-- Ejecutar con F5 / Run Script conectado como NOXAS_DEV al servicio FREEPDB1.
-- Requiere 001_core_schema.sql y 005_agent_schema.sql.
-- Usa datos ficticios y termina con ROLLBACK: no deja datos persistidos.

SET SERVEROUTPUT ON SIZE UNLIMITED
SET VERIFY OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

ALTER SESSION SET NLS_TIMESTAMP_TZ_FORMAT = 'YYYY-MM-DD HH24:MI:SS.FF TZH:TZM';

PROMPT ============================================================
PROMPT 1. PRECONDICIONES
PROMPT ============================================================

DECLARE
    v_container NUMBER;
    v_tables    NUMBER;
BEGIN
    SELECT COUNT(*)
      INTO v_container
      FROM dual
     WHERE SYS_CONTEXT('USERENV', 'CON_NAME') = 'FREEPDB1'
       AND SYS_CONTEXT('USERENV', 'SESSION_USER') = 'NOXAS_DEV';

    IF v_container <> 1 THEN
        RAISE_APPLICATION_ERROR(-20071,
            'Ejecutar como NOXAS_DEV dentro de FREEPDB1.');
    END IF;

    SELECT COUNT(*)
      INTO v_tables
      FROM user_tables
     WHERE table_name IN (
        'NOXAS_USER', 'NOXAS_CONVERSATION', 'NOXAS_AUDIT_EVENT',
        'NOXAS_MEMORY', 'NOXAS_AGENT_RUN', 'NOXAS_AGENT_STEP',
        'NOXAS_TOOL_CALL', 'NOXAS_APPROVAL_REQUEST'
     );

    IF v_tables <> 8 THEN
        RAISE_APPLICATION_ERROR(-20072,
            'Faltan tablas requeridas. Encontradas: ' || v_tables || '/8.');
    END IF;

    DBMS_OUTPUT.PUT_LINE('OK - usuario, contenedor y tablas requeridas.');
END;
/

SAVEPOINT noxas_runtime_test_start;

PROMPT ============================================================
PROMPT 2. INSERTS POSITIVOS CON DATOS FICTICIOS
PROMPT ============================================================

-- Identificadores reservados exclusivamente para esta prueba.
INSERT INTO noxas_user (
    user_id, email, display_name, user_status
) VALUES (
    HEXTORAW('00000000000000000000000000000701'),
    'facu.test.runtime@noxas.invalid',
    'Usuario ficticio NOXAS',
    'ACTIVE'
);

INSERT INTO noxas_conversation (
    conversation_id, user_id, title, model_name, metadata_json
) VALUES (
    HEXTORAW('00000000000000000000000000000702'),
    HEXTORAW('00000000000000000000000000000701'),
    'Prueba ficticia del runtime',
    'noxas-test-model',
    '{"environment":"TEST","contains_real_data":false}'
);

-- Memoria de entrada: ya existia antes del run. SOURCE_RUN_ID queda NULL
-- porque esa columna representa al run que CREO una memoria, no al que la leyo.
INSERT INTO noxas_memory (
    memory_id, user_id, memory_scope, memory_type, memory_status,
    title, content_text, confidence_score, importance_score,
    source_reference, metadata_json
) VALUES (
    HEXTORAW('00000000000000000000000000000707'),
    HEXTORAW('00000000000000000000000000000701'),
    'PROJECT', 'TECHNICAL_NOTE', 'ACTIVE',
    'Preferencia ficticia de entorno',
    'Usar siempre el entorno TEST para esta simulacion.',
    0.9500, 0.8000,
    'fixture://runtime/input-memory',
    '{"fixture":true,"contains_real_data":false}'
);

INSERT INTO noxas_agent_run (
    agent_run_id, user_id, conversation_id, objective_text,
    run_status, autonomy_level, model_name, reasoning_effort,
    maximum_steps, metadata_json, started_at
) VALUES (
    HEXTORAW('00000000000000000000000000000703'),
    HEXTORAW('00000000000000000000000000000701'),
    HEXTORAW('00000000000000000000000000000702'),
    'Leer una memoria ficticia y simular una escritura con aprobacion.',
    'RUNNING', 'SUPERVISED', 'noxas-test-model', 'LOW',
    5,
    '{"fixture":true,"input_memory_ids":["00000000000000000000000000000707"]}',
    SYSTIMESTAMP
);

INSERT INTO noxas_agent_step (
    agent_step_id, agent_run_id, step_no, step_type, step_status,
    summary_text, evidence_json, finished_at
) VALUES (
    HEXTORAW('00000000000000000000000000000704'),
    HEXTORAW('00000000000000000000000000000703'),
    1, 'PLAN', 'COMPLETED',
    'Se leyo la memoria ficticia y se preparo una accion controlada.',
    '{"memory_id":"00000000000000000000000000000707","read_ok":true}',
    SYSTIMESTAMP
);

INSERT INTO noxas_tool_call (
    tool_call_id, agent_run_id, agent_step_id, provider_call_id,
    tool_name, tool_category, call_status, approval_required,
    arguments_json
) VALUES (
    HEXTORAW('00000000000000000000000000000705'),
    HEXTORAW('00000000000000000000000000000703'),
    HEXTORAW('00000000000000000000000000000704'),
    'fixture-call-007-01',
    'memory.write.test', 'WRITE', 'WAITING_APPROVAL', 'Y',
    '{"operation":"create_test_summary","dry_run":true}'
);

INSERT INTO noxas_approval_request (
    approval_request_id, agent_run_id, tool_call_id,
    requested_by_user_id, action_type, risk_level,
    reversible_flag, request_status, description_text,
    action_preview, expires_at
) VALUES (
    HEXTORAW('00000000000000000000000000000706'),
    HEXTORAW('00000000000000000000000000000703'),
    HEXTORAW('00000000000000000000000000000705'),
    HEXTORAW('00000000000000000000000000000701'),
    'DATABASE_WRITE', 'LOW', 'Y', 'PENDING',
    'Autorizar la creacion de una memoria ficticia de resumen.',
    '{"table":"NOXAS_MEMORY","real_write":false}',
    SYSTIMESTAMP + INTERVAL '15' MINUTE
);

INSERT INTO noxas_audit_event (
    user_id, event_type, event_result, resource_type, resource_id, details_json
) VALUES (
    HEXTORAW('00000000000000000000000000000701'),
    'APPROVAL_REQUESTED', 'SUCCESS', 'NOXAS_APPROVAL_REQUEST',
    '00000000000000000000000000000706',
    '{"fixture":true,"risk_level":"LOW"}'
);

PROMPT ============================================================
PROMPT 3. SELECT Y VALIDACION DE LA CADENA
PROMPT ============================================================

COLUMN memory_title FORMAT A36
COLUMN objective FORMAT A50
COLUMN step_summary FORMAT A55
COLUMN tool_name FORMAT A24
COLUMN approval_status FORMAT A16

SELECT
    m.title AS memory_title,
    DBMS_LOB.SUBSTR(r.objective_text, 50, 1) AS objective,
    DBMS_LOB.SUBSTR(s.summary_text, 55, 1) AS step_summary,
    t.tool_name,
    a.request_status AS approval_status
FROM noxas_memory m
JOIN noxas_agent_run r
  ON r.agent_run_id = HEXTORAW('00000000000000000000000000000703')
JOIN noxas_agent_step s
  ON s.agent_run_id = r.agent_run_id
JOIN noxas_tool_call t
  ON t.agent_run_id = r.agent_run_id
 AND t.agent_step_id = s.agent_step_id
JOIN noxas_approval_request a
  ON a.agent_run_id = r.agent_run_id
 AND a.tool_call_id = t.tool_call_id
WHERE m.memory_id = HEXTORAW('00000000000000000000000000000707');

DECLARE
    v_count NUMBER;
BEGIN
    SELECT COUNT(*)
      INTO v_count
      FROM noxas_memory m
      JOIN noxas_agent_run r
        ON r.user_id = m.user_id
      JOIN noxas_agent_step s
        ON s.agent_run_id = r.agent_run_id
      JOIN noxas_tool_call t
        ON t.agent_run_id = r.agent_run_id
       AND t.agent_step_id = s.agent_step_id
      JOIN noxas_approval_request a
        ON a.agent_run_id = r.agent_run_id
       AND a.tool_call_id = t.tool_call_id
     WHERE m.memory_id = HEXTORAW('00000000000000000000000000000707')
       AND r.agent_run_id = HEXTORAW('00000000000000000000000000000703')
       AND s.agent_step_id = HEXTORAW('00000000000000000000000000000704')
       AND t.tool_call_id = HEXTORAW('00000000000000000000000000000705')
       AND a.approval_request_id = HEXTORAW('00000000000000000000000000000706');

    IF v_count <> 1 THEN
        RAISE_APPLICATION_ERROR(-20073, 'La cadena positiva no devolvio exactamente una fila.');
    END IF;
    DBMS_OUTPUT.PUT_LINE('OK - INSERT/SELECT y relaciones principales.');
END;
/

PROMPT ============================================================
PROMPT 4. UPDATES DE ESTADO Y AUDITORIA EXPLICITA
PROMPT ============================================================

UPDATE noxas_approval_request
   SET request_status     = 'APPROVED',
       decided_by_user_id = HEXTORAW('00000000000000000000000000000701'),
       decision_comment   = 'Aprobacion ficticia para prueba controlada.',
       decided_at         = SYSTIMESTAMP
 WHERE approval_request_id = HEXTORAW('00000000000000000000000000000706')
   AND request_status = 'PENDING';

UPDATE noxas_tool_call
   SET call_status  = 'COMPLETED',
       result_json  = '{"created":true,"fixture":true}',
       duration_ms  = 25,
       completed_at = SYSTIMESTAMP
 WHERE tool_call_id = HEXTORAW('00000000000000000000000000000705')
   AND call_status = 'WAITING_APPROVAL';

-- Memoria de salida: esta si fue creada por el run y valida SOURCE_RUN_ID.
INSERT INTO noxas_memory (
    memory_id, user_id, source_run_id, memory_scope, memory_type,
    memory_status, title, content_text, confidence_score,
    importance_score, source_reference, metadata_json
) VALUES (
    HEXTORAW('00000000000000000000000000000708'),
    HEXTORAW('00000000000000000000000000000701'),
    HEXTORAW('00000000000000000000000000000703'),
    'PROJECT', 'SUMMARY', 'CANDIDATE',
    'Resumen ficticio producido por el run',
    'La simulacion finalizo sin ejecutar acciones reales.',
    0.9000, 0.6000,
    'fixture://runtime/output-memory',
    '{"fixture":true,"produced_by_agent":true}'
);

UPDATE noxas_memory
   SET memory_status = 'ACTIVE',
       content_text  = 'La simulacion finalizo correctamente y fue auditada.',
       last_used_at  = SYSTIMESTAMP,
       updated_at    = SYSTIMESTAMP
 WHERE memory_id = HEXTORAW('00000000000000000000000000000708')
   AND memory_status = 'CANDIDATE';

UPDATE noxas_agent_run
   SET run_status      = 'COMPLETED',
       completed_steps = 1,
       input_tokens    = 120,
       output_tokens   = 45,
       estimated_cost  = 0,
       final_summary   = 'Prueba ficticia completada.',
       finished_at     = SYSTIMESTAMP,
       updated_at      = SYSTIMESTAMP
 WHERE agent_run_id = HEXTORAW('00000000000000000000000000000703')
   AND run_status = 'RUNNING';

INSERT ALL
    INTO noxas_audit_event (
        user_id, event_type, event_result, resource_type, resource_id, details_json
    ) VALUES (
        HEXTORAW('00000000000000000000000000000701'),
        'APPROVAL_DECIDED', 'SUCCESS', 'NOXAS_APPROVAL_REQUEST',
        '00000000000000000000000000000706', '{"decision":"APPROVED","fixture":true}'
    )
    INTO noxas_audit_event (
        user_id, event_type, event_result, resource_type, resource_id, details_json
    ) VALUES (
        HEXTORAW('00000000000000000000000000000701'),
        'TOOL_CALL_COMPLETED', 'SUCCESS', 'NOXAS_TOOL_CALL',
        '00000000000000000000000000000705', '{"fixture":true,"duration_ms":25}'
    )
    INTO noxas_audit_event (
        user_id, event_type, event_result, resource_type, resource_id, details_json
    ) VALUES (
        HEXTORAW('00000000000000000000000000000701'),
        'MEMORY_CREATED', 'SUCCESS', 'NOXAS_MEMORY',
        '00000000000000000000000000000708', '{"status":"ACTIVE","fixture":true}'
    )
    INTO noxas_audit_event (
        user_id, event_type, event_result, resource_type, resource_id, details_json
    ) VALUES (
        HEXTORAW('00000000000000000000000000000701'),
        'AGENT_RUN_COMPLETED', 'SUCCESS', 'NOXAS_AGENT_RUN',
        '00000000000000000000000000000703', '{"completed_steps":1,"fixture":true}'
    )
SELECT 1 FROM dual;

DECLARE
    v_bad_rows NUMBER;
    v_audit    NUMBER;
BEGIN
    SELECT COUNT(*)
      INTO v_bad_rows
      FROM noxas_agent_run
     WHERE agent_run_id = HEXTORAW('00000000000000000000000000000703')
       AND NOT (
           run_status = 'COMPLETED'
           AND completed_steps = 1
           AND finished_at >= started_at
           AND updated_at >= created_at
       );

    IF v_bad_rows <> 0 THEN
        RAISE_APPLICATION_ERROR(-20074, 'El UPDATE final del run no quedo consistente.');
    END IF;

    SELECT COUNT(*)
      INTO v_audit
      FROM noxas_audit_event
     WHERE user_id = HEXTORAW('00000000000000000000000000000701')
       AND JSON_VALUE(details_json, '$.fixture' RETURNING VARCHAR2(5)) = 'true';

    IF v_audit <> 5 THEN
        RAISE_APPLICATION_ERROR(-20075,
            'Se esperaban 5 eventos de auditoria y se encontraron ' || v_audit || '.');
    END IF;

    DBMS_OUTPUT.PUT_LINE('OK - UPDATE de estados y timestamps.');
    DBMS_OUTPUT.PUT_LINE('OK - auditoria explicita: ' || v_audit || '/5 eventos.');
END;
/

PROMPT Estado final antes del ROLLBACK
SELECT run_status, completed_steps, input_tokens, output_tokens,
       estimated_cost, started_at, finished_at
FROM noxas_agent_run
WHERE agent_run_id = HEXTORAW('00000000000000000000000000000703');

SELECT request_status, risk_level, reversible_flag, requested_at, decided_at
FROM noxas_approval_request
WHERE approval_request_id = HEXTORAW('00000000000000000000000000000706');

SELECT memory_type, memory_status, RAWTOHEX(source_run_id) AS source_run_id,
       created_at, updated_at, last_used_at
FROM noxas_memory
WHERE memory_id IN (
    HEXTORAW('00000000000000000000000000000707'),
    HEXTORAW('00000000000000000000000000000708')
)
ORDER BY memory_id;

SELECT event_type, event_result, resource_type, resource_id, created_at
FROM noxas_audit_event
WHERE user_id = HEXTORAW('00000000000000000000000000000701')
ORDER BY created_at;

PROMPT ============================================================
PROMPT 5. PRUEBAS NEGATIVAS: CONSTRAINTS DEBEN RECHAZAR LOS DATOS
PROMPT ============================================================

DECLARE
    PROCEDURE expect_rejection(
        p_name          IN VARCHAR2,
        p_sql           IN VARCHAR2,
        p_expected_code IN NUMBER
    ) IS
    BEGIN
        EXECUTE IMMEDIATE p_sql;
        RAISE_APPLICATION_ERROR(-20076,
            'FALLO - ' || p_name || ': Oracle acepto un dato invalido.');
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE = -20076 THEN
                RAISE;
            ELSIF SQLCODE = p_expected_code THEN
                DBMS_OUTPUT.PUT_LINE('OK - ' || p_name || ' rechazo ORA' || SQLCODE);
            ELSE
                RAISE_APPLICATION_ERROR(-20077,
                    'FALLO - ' || p_name || ': se esperaba ORA' ||
                    p_expected_code || ' y llego ORA' || SQLCODE || ' - ' || SQLERRM);
            END IF;
    END;
BEGIN
    expect_rejection(
        'CHECK de estado del run',
        q'[INSERT INTO noxas_agent_run (agent_run_id, objective_text, run_status)
           VALUES (HEXTORAW('00000000000000000000000000000720'), 'Invalido', 'UNKNOWN')]',
        -2290
    );

    expect_rejection(
        'CHECK de puntaje de memoria',
        q'[INSERT INTO noxas_memory
           (memory_id, memory_type, title, content_text, confidence_score)
           VALUES (HEXTORAW('00000000000000000000000000000721'),
                   'FACT', 'Invalido', 'Puntaje fuera de rango', 1.5)]',
        -2290
    );

    expect_rejection(
        'CHECK de JSON',
        q'[INSERT INTO noxas_memory
           (memory_id, memory_type, title, content_text, metadata_json)
           VALUES (HEXTORAW('00000000000000000000000000000722'),
                   'FACT', 'Invalido', 'JSON roto', '{json-roto}')]',
        -2290
    );

    expect_rejection(
        'FK step -> run',
        q'[INSERT INTO noxas_agent_step
           (agent_step_id, agent_run_id, step_no, step_type)
           VALUES (HEXTORAW('00000000000000000000000000000723'),
                   HEXTORAW('FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF'), 1, 'PLAN')]',
        -2291
    );

    expect_rejection(
        'UNIQUE run + step_no',
        q'[INSERT INTO noxas_agent_step
           (agent_step_id, agent_run_id, step_no, step_type)
           VALUES (HEXTORAW('00000000000000000000000000000724'),
                   HEXTORAW('00000000000000000000000000000703'), 1, 'PLAN')]',
        -1
    );

    expect_rejection(
        'CHECK fecha de aprobacion',
        q'[INSERT INTO noxas_approval_request
           (approval_request_id, agent_run_id, action_type, risk_level,
            description_text, requested_at, expires_at)
           VALUES (HEXTORAW('00000000000000000000000000000725'),
                   HEXTORAW('00000000000000000000000000000703'),
                   'DATABASE_WRITE', 'LOW', 'Fecha invalida',
                   SYSTIMESTAMP, SYSTIMESTAMP - INTERVAL '1' MINUTE)]',
        -2290
    );

    DBMS_OUTPUT.PUT_LINE('OK - todas las constraints negativas esperadas.');
END;
/

PROMPT ============================================================
PROMPT 6. PRUEBA DE AISLAMIENTO ENTRE RUNS (DIAGNOSTICO)
PROMPT ============================================================

SAVEPOINT noxas_cross_run_test;

INSERT INTO noxas_agent_run (
    agent_run_id, user_id, conversation_id, objective_text
) VALUES (
    HEXTORAW('00000000000000000000000000000730'),
    HEXTORAW('00000000000000000000000000000701'),
    HEXTORAW('00000000000000000000000000000702'),
    'Segundo run ficticio para probar aislamiento.'
);

INSERT INTO noxas_agent_step (
    agent_step_id, agent_run_id, step_no, step_type
) VALUES (
    HEXTORAW('00000000000000000000000000000731'),
    HEXTORAW('00000000000000000000000000000730'),
    1, 'PLAN'
);

-- El modelo actual permite asociar un tool_call del run A con un step del run B,
-- porque valida ambas FKs por separado pero no valida el par (run_id, step_id).
INSERT INTO noxas_tool_call (
    tool_call_id, agent_run_id, agent_step_id,
    tool_name, tool_category
) VALUES (
    HEXTORAW('00000000000000000000000000000732'),
    HEXTORAW('00000000000000000000000000000703'),
    HEXTORAW('00000000000000000000000000000731'),
    'cross-run-diagnostic', 'SYSTEM'
);

DECLARE
    v_cross_run NUMBER;
BEGIN
    SELECT COUNT(*)
      INTO v_cross_run
      FROM noxas_tool_call t
      JOIN noxas_agent_step s ON s.agent_step_id = t.agent_step_id
     WHERE t.tool_call_id = HEXTORAW('00000000000000000000000000000732')
       AND t.agent_run_id <> s.agent_run_id;

    IF v_cross_run = 1 THEN
        DBMS_OUTPUT.PUT_LINE(
            'ADVERTENCIA CONFIRMADA - el esquema permite TOOL_CALL y STEP de runs distintos.');
    ELSE
        RAISE_APPLICATION_ERROR(-20078,
            'Resultado inesperado en la prueba de aislamiento entre runs.');
    END IF;
END;
/

ROLLBACK TO noxas_cross_run_test;

PROMPT ============================================================
PROMPT 7. LIMPIEZA REVERSIBLE
PROMPT ============================================================

ROLLBACK TO noxas_runtime_test_start;

DECLARE
    v_remaining NUMBER;
BEGIN
    SELECT
          (SELECT COUNT(*) FROM noxas_user
            WHERE user_id = HEXTORAW('00000000000000000000000000000701'))
        + (SELECT COUNT(*) FROM noxas_agent_run
            WHERE agent_run_id IN (
                HEXTORAW('00000000000000000000000000000703'),
                HEXTORAW('00000000000000000000000000000730')
            ))
        + (SELECT COUNT(*) FROM noxas_memory
            WHERE memory_id IN (
                HEXTORAW('00000000000000000000000000000707'),
                HEXTORAW('00000000000000000000000000000708')
            ))
      INTO v_remaining
      FROM dual;

    IF v_remaining <> 0 THEN
        RAISE_APPLICATION_ERROR(-20079,
            'El ROLLBACK dejo ' || v_remaining || ' filas ficticias.');
    END IF;

    DBMS_OUTPUT.PUT_LINE('OK - ROLLBACK completo; no quedaron datos ficticios.');
    DBMS_OUTPUT.PUT_LINE('PRUEBA NOXAS RUNTIME: FINALIZADA.');
END;
/

PROMPT test_agent_runtime.sql finalizado correctamente.
