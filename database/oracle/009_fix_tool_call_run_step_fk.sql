-- NOXAS Agent v1 - Parche de integridad TOOL_CALL -> STEP/RUN
-- 009: impide que un NOXAS_TOOL_CALL apunte a un AGENT_STEP de otro AGENT_RUN.
-- Ejecutar con F5 / Run Script conectado como NOXAS_DEV al servicio FREEPDB1.
-- Requiere 005_agent_schema.sql aplicado previamente.

SET SERVEROUTPUT ON
SET VERIFY OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

PROMPT ============================================================
PROMPT 009 - REFUERZO DE INTEGRIDAD TOOL_CALL / RUN / STEP
PROMPT ============================================================

DECLARE
    v_container VARCHAR2(128) := SYS_CONTEXT('USERENV', 'CON_NAME');
    v_user      VARCHAR2(128) := SYS_CONTEXT('USERENV', 'SESSION_USER');
    v_count     NUMBER;
BEGIN
    IF v_container <> 'FREEPDB1' THEN
        RAISE_APPLICATION_ERROR(-20091, '009 debe ejecutarse dentro de FREEPDB1.');
    END IF;

    IF v_user <> 'NOXAS_DEV' THEN
        RAISE_APPLICATION_ERROR(-20092, '009 debe ejecutarse conectado como NOXAS_DEV.');
    END IF;

    SELECT COUNT(*)
      INTO v_count
      FROM user_tables
     WHERE table_name IN ('NOXAS_AGENT_RUN', 'NOXAS_AGENT_STEP', 'NOXAS_TOOL_CALL');

    IF v_count <> 3 THEN
        RAISE_APPLICATION_ERROR(-20093, 'Faltan tablas requeridas del runtime. Ejecutar 005 primero.');
    END IF;

    DBMS_OUTPUT.PUT_LINE('OK - usuario, contenedor y tablas requeridas.');
END;
/

PROMPT
PROMPT 1. DIAGNOSTICO DE DATOS EXISTENTES
PROMPT ============================================================

DECLARE
    v_mismatches NUMBER;
BEGIN
    SELECT COUNT(*)
      INTO v_mismatches
      FROM noxas_tool_call tc
     WHERE tc.agent_step_id IS NOT NULL
       AND NOT EXISTS (
            SELECT 1
              FROM noxas_agent_step st
             WHERE st.agent_run_id  = tc.agent_run_id
               AND st.agent_step_id = tc.agent_step_id
       );

    IF v_mismatches > 0 THEN
        RAISE_APPLICATION_ERROR(
            -20094,
            'Existen ' || v_mismatches ||
            ' TOOL_CALL con STEP perteneciente a otro RUN. Corregir datos antes de aplicar 009.'
        );
    END IF;

    DBMS_OUTPUT.PUT_LINE('OK - no existen relaciones TOOL_CALL/RUN/STEP incompatibles.');
END;
/

PROMPT
PROMPT 2. APLICACION DEL PARCHE
PROMPT ============================================================

DECLARE
    v_count NUMBER;
BEGIN
    -- Oracle exige que las columnas padre de una FK compuesta coincidan con
    -- una PK o UNIQUE. AGENT_STEP_ID ya es PK, pero el par RUN/STEP no lo era.
    SELECT COUNT(*)
      INTO v_count
      FROM user_constraints
     WHERE table_name = 'NOXAS_AGENT_STEP'
       AND constraint_name = 'UQ_NOXAS_AGENT_STEP_RUN_ID';

    IF v_count = 0 THEN
        EXECUTE IMMEDIATE '
            ALTER TABLE noxas_agent_step
            ADD CONSTRAINT uq_noxas_agent_step_run_id
            UNIQUE (agent_run_id, agent_step_id)';
        DBMS_OUTPUT.PUT_LINE('OK - creada UQ_NOXAS_AGENT_STEP_RUN_ID.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('OK - UQ_NOXAS_AGENT_STEP_RUN_ID ya existe.');
    END IF;

    -- Primero se crea la FK nueva. La FK vieja se elimina solo despues de que
    -- la relacion compuesta haya quedado protegida.
    SELECT COUNT(*)
      INTO v_count
      FROM user_constraints
     WHERE table_name = 'NOXAS_TOOL_CALL'
       AND constraint_name = 'FK_NOXAS_TOOL_CALL_STEP_RUN';

    IF v_count = 0 THEN
        EXECUTE IMMEDIATE '
            ALTER TABLE noxas_tool_call
            ADD CONSTRAINT fk_noxas_tool_call_step_run
            FOREIGN KEY (agent_run_id, agent_step_id)
            REFERENCES noxas_agent_step (agent_run_id, agent_step_id)';
        DBMS_OUTPUT.PUT_LINE('OK - creada FK compuesta FK_NOXAS_TOOL_CALL_STEP_RUN.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('OK - FK_NOXAS_TOOL_CALL_STEP_RUN ya existe.');
    END IF;

    SELECT COUNT(*)
      INTO v_count
      FROM user_constraints
     WHERE table_name = 'NOXAS_TOOL_CALL'
       AND constraint_name = 'FK_NOXAS_TOOL_CALL_STEP';

    IF v_count > 0 THEN
        EXECUTE IMMEDIATE '
            ALTER TABLE noxas_tool_call
            DROP CONSTRAINT fk_noxas_tool_call_step';
        DBMS_OUTPUT.PUT_LINE('OK - eliminada FK simple FK_NOXAS_TOOL_CALL_STEP.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('OK - FK simple anterior ya no existe.');
    END IF;

    -- Indice del lado hijo para la FK compuesta y operaciones por run/step.
    SELECT COUNT(*)
      INTO v_count
      FROM user_indexes
     WHERE index_name = 'IX_NOXAS_TOOL_CALL_RUN_STEP';

    IF v_count = 0 THEN
        EXECUTE IMMEDIATE '
            CREATE INDEX ix_noxas_tool_call_run_step
            ON noxas_tool_call (agent_run_id, agent_step_id)';
        DBMS_OUTPUT.PUT_LINE('OK - creado IX_NOXAS_TOOL_CALL_RUN_STEP.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('OK - IX_NOXAS_TOOL_CALL_RUN_STEP ya existe.');
    END IF;
END;
/

PROMPT
PROMPT 3. VALIDACION ESTRUCTURAL
PROMPT ============================================================

DECLARE
    v_uq NUMBER;
    v_fk NUMBER;
BEGIN
    SELECT COUNT(*)
      INTO v_uq
      FROM user_constraints
     WHERE table_name = 'NOXAS_AGENT_STEP'
       AND constraint_name = 'UQ_NOXAS_AGENT_STEP_RUN_ID'
       AND constraint_type = 'U'
       AND status = 'ENABLED';

    SELECT COUNT(*)
      INTO v_fk
      FROM user_constraints
     WHERE table_name = 'NOXAS_TOOL_CALL'
       AND constraint_name = 'FK_NOXAS_TOOL_CALL_STEP_RUN'
       AND constraint_type = 'R'
       AND status = 'ENABLED';

    IF v_uq <> 1 OR v_fk <> 1 THEN
        RAISE_APPLICATION_ERROR(-20095, 'Las constraints nuevas no quedaron habilitadas correctamente.');
    END IF;

    DBMS_OUTPUT.PUT_LINE('OK - UQ y FK compuesta habilitadas.');
END;
/

PROMPT
PROMPT 4. PRUEBA NEGATIVA DE AISLAMIENTO ENTRE RUNS
PROMPT ============================================================

SAVEPOINT noxas_009_isolation_test;

DECLARE
    v_run_a  RAW(16) := SYS_GUID();
    v_run_b  RAW(16) := SYS_GUID();
    v_step_a RAW(16) := SYS_GUID();
BEGIN
    INSERT INTO noxas_agent_run (
        agent_run_id, objective_text, run_status, autonomy_level,
        maximum_steps, completed_steps
    ) VALUES (
        v_run_a, '009 test - run A', 'RUNNING', 'SUPERVISED', 2, 0
    );

    INSERT INTO noxas_agent_run (
        agent_run_id, objective_text, run_status, autonomy_level,
        maximum_steps, completed_steps
    ) VALUES (
        v_run_b, '009 test - run B', 'RUNNING', 'SUPERVISED', 2, 0
    );

    INSERT INTO noxas_agent_step (
        agent_step_id, agent_run_id, step_no, step_type,
        step_status, summary_text
    ) VALUES (
        v_step_a, v_run_a, 1, 'TOOL_SELECTION',
        'COMPLETED', '009 test - step perteneciente al run A'
    );

    BEGIN
        INSERT INTO noxas_tool_call (
            agent_run_id, agent_step_id, tool_name, tool_category,
            call_status, approval_required, arguments_json
        ) VALUES (
            v_run_b, v_step_a, 'runtime.isolation.test', 'READ',
            'PENDING', 'N', '{"test":"cross-run"}'
        );

        RAISE_APPLICATION_ERROR(
            -20096,
            'FALLO - la FK compuesta permitio TOOL_CALL y STEP de runs distintos.'
        );
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE = -2291 THEN
                DBMS_OUTPUT.PUT_LINE('OK - aislamiento entre runs rechazado con ORA-02291.');
            ELSE
                RAISE;
            END IF;
    END;
END;
/

ROLLBACK TO noxas_009_isolation_test;

PROMPT
PROMPT 5. VERIFICACION DE LIMPIEZA
PROMPT ============================================================

DECLARE
    v_count NUMBER;
BEGIN
    SELECT COUNT(*)
      INTO v_count
      FROM noxas_agent_run
     WHERE objective_text IN ('009 test - run A', '009 test - run B');

    IF v_count <> 0 THEN
        RAISE_APPLICATION_ERROR(-20097, 'La prueba 009 dejo datos ficticios sin limpiar.');
    END IF;

    DBMS_OUTPUT.PUT_LINE('OK - prueba reversible; no quedaron datos ficticios.');
    DBMS_OUTPUT.PUT_LINE('009 - integridad TOOL_CALL/RUN/STEP reforzada correctamente.');
END;
/

PROMPT
PROMPT 009_fix_tool_call_run_step_fk.sql finalizado correctamente.
