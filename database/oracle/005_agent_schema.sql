-- NOXAS Agent v1 - Persistencia de ejecuciones, herramientas, memoria y aprobaciones
-- Ejecutar con F5 / Run Script conectado como NOXAS_DEV al servicio FREEPDB1.
-- Requiere que 001_core_schema.sql haya finalizado correctamente.

SET SERVEROUTPUT ON
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

DECLARE
    v_container VARCHAR2(128) := SYS_CONTEXT('USERENV', 'CON_NAME');
    v_user      VARCHAR2(128) := SYS_CONTEXT('USERENV', 'SESSION_USER');
BEGIN
    IF v_container <> 'FREEPDB1' THEN
        RAISE_APPLICATION_ERROR(-20051, '005_agent_schema.sql debe ejecutarse dentro de FREEPDB1.');
    END IF;

    IF v_user <> 'NOXAS_DEV' THEN
        RAISE_APPLICATION_ERROR(-20052, '005_agent_schema.sql debe ejecutarse conectado como NOXAS_DEV.');
    END IF;
END;
/

CREATE TABLE noxas_agent_run (
    agent_run_id          RAW(16) DEFAULT SYS_GUID() NOT NULL,
    user_id               RAW(16),
    conversation_id       RAW(16),
    objective_text        CLOB NOT NULL,
    run_status            VARCHAR2(30 CHAR) DEFAULT 'PENDING' NOT NULL,
    autonomy_level        VARCHAR2(20 CHAR) DEFAULT 'SUPERVISED' NOT NULL,
    model_name            VARCHAR2(120 CHAR),
    reasoning_effort      VARCHAR2(20 CHAR),
    maximum_steps         NUMBER(4) DEFAULT 5 NOT NULL,
    completed_steps       NUMBER(4) DEFAULT 0 NOT NULL,
    input_tokens          NUMBER(12),
    output_tokens         NUMBER(12),
    estimated_cost        NUMBER(18, 8),
    final_summary         CLOB,
    error_code            VARCHAR2(100 CHAR),
    error_message         VARCHAR2(2000 CHAR),
    metadata_json         CLOB,
    started_at            TIMESTAMP WITH TIME ZONE,
    finished_at           TIMESTAMP WITH TIME ZONE,
    created_at            TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
    updated_at            TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_noxas_agent_run PRIMARY KEY (agent_run_id),
    CONSTRAINT fk_noxas_agent_run_user FOREIGN KEY (user_id)
        REFERENCES noxas_user (user_id) ON DELETE SET NULL,
    CONSTRAINT fk_noxas_agent_run_conv FOREIGN KEY (conversation_id)
        REFERENCES noxas_conversation (conversation_id) ON DELETE SET NULL,
    CONSTRAINT ck_noxas_agent_run_status CHECK (
        run_status IN ('PENDING', 'RUNNING', 'WAITING_APPROVAL', 'COMPLETED', 'FAILED', 'CANCELLED')
    ),
    CONSTRAINT ck_noxas_agent_run_autonomy CHECK (
        autonomy_level IN ('ASSISTED', 'SUPERVISED', 'DELEGATED')
    ),
    CONSTRAINT ck_noxas_agent_run_effort CHECK (
        reasoning_effort IS NULL OR reasoning_effort IN ('NONE', 'MINIMAL', 'LOW', 'MEDIUM', 'HIGH')
    ),
    CONSTRAINT ck_noxas_agent_run_steps CHECK (
        maximum_steps BETWEEN 1 AND 50 AND completed_steps BETWEEN 0 AND maximum_steps
    ),
    CONSTRAINT ck_noxas_agent_run_tokens CHECK (
        (input_tokens IS NULL OR input_tokens >= 0)
        AND (output_tokens IS NULL OR output_tokens >= 0)
    ),
    CONSTRAINT ck_noxas_agent_run_cost CHECK (estimated_cost IS NULL OR estimated_cost >= 0),
    CONSTRAINT ck_noxas_agent_run_dates CHECK (
        finished_at IS NULL OR started_at IS NULL OR finished_at >= started_at
    ),
    CONSTRAINT ck_noxas_agent_run_json CHECK (metadata_json IS JSON)
);

CREATE TABLE noxas_agent_step (
    agent_step_id         RAW(16) DEFAULT SYS_GUID() NOT NULL,
    agent_run_id          RAW(16) NOT NULL,
    step_no               NUMBER(4) NOT NULL,
    step_type             VARCHAR2(30 CHAR) NOT NULL,
    step_status           VARCHAR2(20 CHAR) DEFAULT 'COMPLETED' NOT NULL,
    summary_text          CLOB,
    evidence_json         CLOB,
    started_at            TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
    finished_at           TIMESTAMP WITH TIME ZONE,
    CONSTRAINT pk_noxas_agent_step PRIMARY KEY (agent_step_id),
    CONSTRAINT fk_noxas_agent_step_run FOREIGN KEY (agent_run_id)
        REFERENCES noxas_agent_run (agent_run_id) ON DELETE CASCADE,
    CONSTRAINT uq_noxas_agent_step_no UNIQUE (agent_run_id, step_no),
    CONSTRAINT ck_noxas_agent_step_no CHECK (step_no > 0),
    CONSTRAINT ck_noxas_agent_step_type CHECK (
        step_type IN ('PLAN', 'TOOL_SELECTION', 'TOOL_RESULT', 'APPROVAL_REQUEST', 'FINAL_RESPONSE', 'ERROR')
    ),
    CONSTRAINT ck_noxas_agent_step_status CHECK (
        step_status IN ('PENDING', 'RUNNING', 'COMPLETED', 'FAILED', 'CANCELLED')
    ),
    CONSTRAINT ck_noxas_agent_step_dates CHECK (finished_at IS NULL OR finished_at >= started_at),
    CONSTRAINT ck_noxas_agent_step_json CHECK (evidence_json IS JSON)
);

CREATE TABLE noxas_tool_call (
    tool_call_id          RAW(16) DEFAULT SYS_GUID() NOT NULL,
    agent_run_id          RAW(16) NOT NULL,
    agent_step_id         RAW(16),
    provider_call_id      VARCHAR2(200 CHAR),
    tool_name             VARCHAR2(120 CHAR) NOT NULL,
    tool_category         VARCHAR2(30 CHAR) NOT NULL,
    call_status           VARCHAR2(30 CHAR) DEFAULT 'PENDING' NOT NULL,
    approval_required     CHAR(1 CHAR) DEFAULT 'N' NOT NULL,
    arguments_json        CLOB,
    result_json           CLOB,
    error_message         VARCHAR2(2000 CHAR),
    duration_ms           NUMBER(12),
    created_at            TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
    completed_at          TIMESTAMP WITH TIME ZONE,
    CONSTRAINT pk_noxas_tool_call PRIMARY KEY (tool_call_id),
    CONSTRAINT fk_noxas_tool_call_run FOREIGN KEY (agent_run_id)
        REFERENCES noxas_agent_run (agent_run_id) ON DELETE CASCADE,
    CONSTRAINT fk_noxas_tool_call_step FOREIGN KEY (agent_step_id)
        REFERENCES noxas_agent_step (agent_step_id) ON DELETE SET NULL,
    CONSTRAINT uq_noxas_tool_provider_call UNIQUE (agent_run_id, provider_call_id),
    CONSTRAINT ck_noxas_tool_category CHECK (
        tool_category IN ('READ', 'CALCULATE', 'ANALYZE', 'WRITE', 'EXTERNAL', 'SYSTEM')
    ),
    CONSTRAINT ck_noxas_tool_status CHECK (
        call_status IN ('PENDING', 'WAITING_APPROVAL', 'RUNNING', 'COMPLETED', 'FAILED', 'DENIED', 'CANCELLED')
    ),
    CONSTRAINT ck_noxas_tool_approval CHECK (approval_required IN ('Y', 'N')),
    CONSTRAINT ck_noxas_tool_duration CHECK (duration_ms IS NULL OR duration_ms >= 0),
    CONSTRAINT ck_noxas_tool_dates CHECK (completed_at IS NULL OR completed_at >= created_at),
    CONSTRAINT ck_noxas_tool_args_json CHECK (arguments_json IS JSON),
    CONSTRAINT ck_noxas_tool_result_json CHECK (result_json IS JSON)
);

CREATE TABLE noxas_approval_request (
    approval_request_id   RAW(16) DEFAULT SYS_GUID() NOT NULL,
    agent_run_id          RAW(16) NOT NULL,
    tool_call_id          RAW(16),
    requested_by_user_id  RAW(16),
    decided_by_user_id    RAW(16),
    action_type           VARCHAR2(40 CHAR) NOT NULL,
    risk_level            VARCHAR2(10 CHAR) NOT NULL,
    reversible_flag       CHAR(1 CHAR) DEFAULT 'N' NOT NULL,
    request_status        VARCHAR2(20 CHAR) DEFAULT 'PENDING' NOT NULL,
    description_text      CLOB NOT NULL,
    action_preview        CLOB,
    decision_comment      VARCHAR2(2000 CHAR),
    requested_at          TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
    decided_at            TIMESTAMP WITH TIME ZONE,
    expires_at            TIMESTAMP WITH TIME ZONE,
    CONSTRAINT pk_noxas_approval PRIMARY KEY (approval_request_id),
    CONSTRAINT fk_noxas_approval_run FOREIGN KEY (agent_run_id)
        REFERENCES noxas_agent_run (agent_run_id) ON DELETE CASCADE,
    CONSTRAINT fk_noxas_approval_tool FOREIGN KEY (tool_call_id)
        REFERENCES noxas_tool_call (tool_call_id) ON DELETE SET NULL,
    CONSTRAINT fk_noxas_approval_requested_user FOREIGN KEY (requested_by_user_id)
        REFERENCES noxas_user (user_id) ON DELETE SET NULL,
    CONSTRAINT fk_noxas_approval_decided_user FOREIGN KEY (decided_by_user_id)
        REFERENCES noxas_user (user_id) ON DELETE SET NULL,
    CONSTRAINT ck_noxas_approval_action CHECK (
        action_type IN ('CODE_CHANGE', 'DATABASE_WRITE', 'DEPLOY', 'EXTERNAL_MESSAGE', 'DELETE', 'INFRASTRUCTURE_CHANGE', 'OTHER')
    ),
    CONSTRAINT ck_noxas_approval_risk CHECK (risk_level IN ('LOW', 'MEDIUM', 'HIGH')),
    CONSTRAINT ck_noxas_approval_reversible CHECK (reversible_flag IN ('Y', 'N')),
    CONSTRAINT ck_noxas_approval_status CHECK (
        request_status IN ('PENDING', 'APPROVED', 'DENIED', 'EXPIRED', 'CANCELLED', 'EXECUTED')
    ),
    CONSTRAINT ck_noxas_approval_dates CHECK (
        (decided_at IS NULL OR decided_at >= requested_at)
        AND (expires_at IS NULL OR expires_at > requested_at)
    )
);

CREATE TABLE noxas_memory (
    memory_id             RAW(16) DEFAULT SYS_GUID() NOT NULL,
    user_id               RAW(16),
    source_run_id         RAW(16),
    memory_scope          VARCHAR2(20 CHAR) DEFAULT 'USER' NOT NULL,
    memory_type           VARCHAR2(30 CHAR) NOT NULL,
    memory_status         VARCHAR2(20 CHAR) DEFAULT 'ACTIVE' NOT NULL,
    title                 VARCHAR2(240 CHAR) NOT NULL,
    content_text          CLOB NOT NULL,
    confidence_score      NUMBER(5, 4),
    importance_score      NUMBER(5, 4),
    source_reference      VARCHAR2(1000 CHAR),
    metadata_json         CLOB,
    last_used_at          TIMESTAMP WITH TIME ZONE,
    expires_at            TIMESTAMP WITH TIME ZONE,
    created_at            TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
    updated_at            TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_noxas_memory PRIMARY KEY (memory_id),
    CONSTRAINT fk_noxas_memory_user FOREIGN KEY (user_id)
        REFERENCES noxas_user (user_id) ON DELETE CASCADE,
    CONSTRAINT fk_noxas_memory_run FOREIGN KEY (source_run_id)
        REFERENCES noxas_agent_run (agent_run_id) ON DELETE SET NULL,
    CONSTRAINT ck_noxas_memory_scope CHECK (memory_scope IN ('USER', 'PROJECT', 'CONVERSATION', 'SYSTEM')),
    CONSTRAINT ck_noxas_memory_type CHECK (
        memory_type IN ('FACT', 'PREFERENCE', 'PROJECT_DECISION', 'WORKFLOW', 'TECHNICAL_NOTE', 'SUMMARY')
    ),
    CONSTRAINT ck_noxas_memory_status CHECK (memory_status IN ('CANDIDATE', 'ACTIVE', 'ARCHIVED', 'REJECTED', 'DELETED')),
    CONSTRAINT ck_noxas_memory_confidence CHECK (
        confidence_score IS NULL OR confidence_score BETWEEN 0 AND 1
    ),
    CONSTRAINT ck_noxas_memory_importance CHECK (
        importance_score IS NULL OR importance_score BETWEEN 0 AND 1
    ),
    CONSTRAINT ck_noxas_memory_expiry CHECK (expires_at IS NULL OR expires_at > created_at),
    CONSTRAINT ck_noxas_memory_json CHECK (metadata_json IS JSON)
);

CREATE TABLE noxas_agent_task (
    agent_task_id         RAW(16) DEFAULT SYS_GUID() NOT NULL,
    user_id               RAW(16),
    parent_run_id         RAW(16),
    task_title            VARCHAR2(240 CHAR) NOT NULL,
    task_instruction      CLOB NOT NULL,
    task_status           VARCHAR2(20 CHAR) DEFAULT 'PENDING' NOT NULL,
    trigger_type          VARCHAR2(20 CHAR) DEFAULT 'MANUAL' NOT NULL,
    schedule_expression   VARCHAR2(500 CHAR),
    maximum_runs          NUMBER(10),
    completed_runs        NUMBER(10) DEFAULT 0 NOT NULL,
    next_run_at           TIMESTAMP WITH TIME ZONE,
    last_run_at           TIMESTAMP WITH TIME ZONE,
    created_at            TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
    updated_at            TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_noxas_agent_task PRIMARY KEY (agent_task_id),
    CONSTRAINT fk_noxas_agent_task_user FOREIGN KEY (user_id)
        REFERENCES noxas_user (user_id) ON DELETE CASCADE,
    CONSTRAINT fk_noxas_agent_task_run FOREIGN KEY (parent_run_id)
        REFERENCES noxas_agent_run (agent_run_id) ON DELETE SET NULL,
    CONSTRAINT ck_noxas_agent_task_status CHECK (
        task_status IN ('PENDING', 'ACTIVE', 'PAUSED', 'COMPLETED', 'FAILED', 'CANCELLED')
    ),
    CONSTRAINT ck_noxas_agent_task_trigger CHECK (
        trigger_type IN ('MANUAL', 'SCHEDULE', 'CONDITION')
    ),
    CONSTRAINT ck_noxas_agent_task_runs CHECK (
        completed_runs >= 0 AND (maximum_runs IS NULL OR maximum_runs > 0)
        AND (maximum_runs IS NULL OR completed_runs <= maximum_runs)
    )
);

CREATE INDEX ix_noxas_agent_run_user_date
    ON noxas_agent_run (user_id, created_at DESC);
CREATE INDEX ix_noxas_agent_run_status
    ON noxas_agent_run (run_status, created_at DESC);
CREATE INDEX ix_noxas_agent_step_run
    ON noxas_agent_step (agent_run_id, step_no);
CREATE INDEX ix_noxas_tool_call_run
    ON noxas_tool_call (agent_run_id, created_at);
CREATE INDEX ix_noxas_tool_call_status
    ON noxas_tool_call (call_status, approval_required, created_at);
CREATE INDEX ix_noxas_approval_pending
    ON noxas_approval_request (request_status, requested_at);
CREATE INDEX ix_noxas_memory_user_type
    ON noxas_memory (user_id, memory_status, memory_type, updated_at DESC);
CREATE INDEX ix_noxas_memory_project
    ON noxas_memory (memory_scope, memory_status, updated_at DESC);
CREATE INDEX ix_noxas_agent_task_due
    ON noxas_agent_task (task_status, next_run_at);

COMMENT ON TABLE noxas_agent_run IS 'Ejecución completa de un objetivo asignado a NOXAS Agent.';
COMMENT ON TABLE noxas_agent_step IS 'Traza resumida y auditable. No almacena cadenas privadas de razonamiento.';
COMMENT ON TABLE noxas_tool_call IS 'Invocaciones de herramientas con argumentos, resultados y estado.';
COMMENT ON TABLE noxas_approval_request IS 'Aprobaciones humanas obligatorias para acciones de escritura o externas.';
COMMENT ON TABLE noxas_memory IS 'Memorias verificables, revisables y con nivel de confianza.';
COMMENT ON TABLE noxas_agent_task IS 'Tareas manuales, programadas o condicionadas del agente.';

COMMIT;

PROMPT 005_agent_schema.sql finalizado correctamente.
