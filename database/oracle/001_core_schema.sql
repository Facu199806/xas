-- NOXAS - Modelo principal para Oracle Database 23c/23ai Free
-- Ejecutar con un usuario propietario del esquema de desarrollo.
-- No contiene datos reales ni contraseñas en texto plano.

ALTER SESSION SET NLS_TIMESTAMP_TZ_FORMAT = 'YYYY-MM-DD HH24:MI:SS.FF TZH:TZM';

CREATE TABLE noxas_user (
    user_id              RAW(16) DEFAULT SYS_GUID() NOT NULL,
    email                VARCHAR2(320 CHAR) NOT NULL,
    display_name         VARCHAR2(160 CHAR),
    user_status          VARCHAR2(20 CHAR) DEFAULT 'ACTIVE' NOT NULL,
    email_verified_at    TIMESTAMP WITH TIME ZONE,
    last_login_at        TIMESTAMP WITH TIME ZONE,
    created_at           TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
    updated_at           TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
    version_no           NUMBER(10) DEFAULT 1 NOT NULL,
    CONSTRAINT pk_noxas_user PRIMARY KEY (user_id),
    CONSTRAINT uq_noxas_user_email UNIQUE (email),
    CONSTRAINT ck_noxas_user_status CHECK (user_status IN ('PENDING', 'ACTIVE', 'SUSPENDED', 'DELETED')),
    CONSTRAINT ck_noxas_user_version CHECK (version_no > 0)
);

CREATE TABLE noxas_identity (
    identity_id          RAW(16) DEFAULT SYS_GUID() NOT NULL,
    user_id              RAW(16) NOT NULL,
    provider_code        VARCHAR2(30 CHAR) NOT NULL,
    provider_subject     VARCHAR2(255 CHAR) NOT NULL,
    provider_email       VARCHAR2(320 CHAR),
    created_at           TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
    last_used_at         TIMESTAMP WITH TIME ZONE,
    CONSTRAINT pk_noxas_identity PRIMARY KEY (identity_id),
    CONSTRAINT fk_noxas_identity_user FOREIGN KEY (user_id)
        REFERENCES noxas_user (user_id) ON DELETE CASCADE,
    CONSTRAINT uq_noxas_identity_provider UNIQUE (provider_code, provider_subject),
    CONSTRAINT ck_noxas_identity_provider CHECK (provider_code IN ('LOCAL', 'GOOGLE', 'MICROSOFT', 'GITHUB', 'MAGIC_LINK'))
);

CREATE TABLE noxas_credential (
    user_id              RAW(16) NOT NULL,
    password_hash        VARCHAR2(255 CHAR) NOT NULL,
    hash_algorithm       VARCHAR2(30 CHAR) DEFAULT 'ARGON2ID' NOT NULL,
    password_changed_at  TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
    failed_attempts      NUMBER(5) DEFAULT 0 NOT NULL,
    locked_until         TIMESTAMP WITH TIME ZONE,
    created_at           TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
    updated_at           TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_noxas_credential PRIMARY KEY (user_id),
    CONSTRAINT fk_noxas_credential_user FOREIGN KEY (user_id)
        REFERENCES noxas_user (user_id) ON DELETE CASCADE,
    CONSTRAINT ck_noxas_credential_hash CHECK (hash_algorithm IN ('ARGON2ID', 'BCRYPT', 'SCRYPT')),
    CONSTRAINT ck_noxas_credential_attempts CHECK (failed_attempts >= 0)
);

CREATE TABLE noxas_user_preference (
    user_id              RAW(16) NOT NULL,
    theme_code           VARCHAR2(10 CHAR) DEFAULT 'SYSTEM' NOT NULL,
    locale_code          VARCHAR2(20 CHAR) DEFAULT 'es-AR' NOT NULL,
    default_model        VARCHAR2(120 CHAR),
    reasoning_level      VARCHAR2(20 CHAR) DEFAULT 'ADAPTIVE' NOT NULL,
    save_history_flag    CHAR(1 CHAR) DEFAULT 'Y' NOT NULL,
    memory_enabled_flag  CHAR(1 CHAR) DEFAULT 'N' NOT NULL,
    preferences_json     CLOB,
    updated_at           TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_noxas_user_pref PRIMARY KEY (user_id),
    CONSTRAINT fk_noxas_user_pref_user FOREIGN KEY (user_id)
        REFERENCES noxas_user (user_id) ON DELETE CASCADE,
    CONSTRAINT ck_noxas_pref_theme CHECK (theme_code IN ('SYSTEM', 'LIGHT', 'DARK')),
    CONSTRAINT ck_noxas_pref_reason CHECK (reasoning_level IN ('ADAPTIVE', 'NONE', 'LOW', 'MEDIUM', 'HIGH')),
    CONSTRAINT ck_noxas_pref_history CHECK (save_history_flag IN ('Y', 'N')),
    CONSTRAINT ck_noxas_pref_memory CHECK (memory_enabled_flag IN ('Y', 'N')),
    CONSTRAINT ck_noxas_pref_json CHECK (preferences_json IS JSON)
);

CREATE TABLE noxas_conversation (
    conversation_id      RAW(16) DEFAULT SYS_GUID() NOT NULL,
    user_id              RAW(16) NOT NULL,
    title                VARCHAR2(240 CHAR) DEFAULT 'Nueva consulta' NOT NULL,
    conversation_status  VARCHAR2(20 CHAR) DEFAULT 'ACTIVE' NOT NULL,
    pinned_flag          CHAR(1 CHAR) DEFAULT 'N' NOT NULL,
    model_name           VARCHAR2(120 CHAR),
    system_profile       VARCHAR2(80 CHAR) DEFAULT 'TECH_SUPPORT' NOT NULL,
    conversation_summary CLOB,
    metadata_json        CLOB,
    created_at           TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
    updated_at           TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
    last_message_at      TIMESTAMP WITH TIME ZONE,
    version_no           NUMBER(10) DEFAULT 1 NOT NULL,
    CONSTRAINT pk_noxas_conversation PRIMARY KEY (conversation_id),
    CONSTRAINT fk_noxas_conversation_user FOREIGN KEY (user_id)
        REFERENCES noxas_user (user_id) ON DELETE CASCADE,
    CONSTRAINT ck_noxas_conversation_status CHECK (conversation_status IN ('ACTIVE', 'ARCHIVED', 'DELETED')),
    CONSTRAINT ck_noxas_conversation_pin CHECK (pinned_flag IN ('Y', 'N')),
    CONSTRAINT ck_noxas_conversation_json CHECK (metadata_json IS JSON),
    CONSTRAINT ck_noxas_conversation_version CHECK (version_no > 0)
);

CREATE TABLE noxas_message (
    message_id           RAW(16) DEFAULT SYS_GUID() NOT NULL,
    conversation_id      RAW(16) NOT NULL,
    sequence_no          NUMBER(10) NOT NULL,
    client_message_id    VARCHAR2(120 CHAR),
    message_role         VARCHAR2(20 CHAR) NOT NULL,
    message_status       VARCHAR2(20 CHAR) DEFAULT 'COMPLETED' NOT NULL,
    content_text         CLOB NOT NULL,
    provider_name        VARCHAR2(80 CHAR),
    model_name           VARCHAR2(120 CHAR),
    reasoning_effort     VARCHAR2(20 CHAR),
    input_tokens         NUMBER(12),
    output_tokens        NUMBER(12),
    latency_ms           NUMBER(12),
    error_code           VARCHAR2(80 CHAR),
    metadata_json        CLOB,
    created_at           TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_noxas_message PRIMARY KEY (message_id),
    CONSTRAINT fk_noxas_message_conversation FOREIGN KEY (conversation_id)
        REFERENCES noxas_conversation (conversation_id) ON DELETE CASCADE,
    CONSTRAINT uq_noxas_message_sequence UNIQUE (conversation_id, sequence_no),
    CONSTRAINT uq_noxas_message_client UNIQUE (conversation_id, client_message_id),
    CONSTRAINT ck_noxas_message_sequence CHECK (sequence_no > 0),
    CONSTRAINT ck_noxas_message_role CHECK (message_role IN ('SYSTEM', 'USER', 'ASSISTANT', 'TOOL')),
    CONSTRAINT ck_noxas_message_status CHECK (message_status IN ('PENDING', 'COMPLETED', 'ERROR', 'CANCELLED')),
    CONSTRAINT ck_noxas_message_effort CHECK (reasoning_effort IS NULL OR reasoning_effort IN ('NONE', 'MINIMAL', 'LOW', 'MEDIUM', 'HIGH')),
    CONSTRAINT ck_noxas_message_input_tokens CHECK (input_tokens IS NULL OR input_tokens >= 0),
    CONSTRAINT ck_noxas_message_output_tokens CHECK (output_tokens IS NULL OR output_tokens >= 0),
    CONSTRAINT ck_noxas_message_latency CHECK (latency_ms IS NULL OR latency_ms >= 0),
    CONSTRAINT ck_noxas_message_json CHECK (metadata_json IS JSON)
);

CREATE TABLE noxas_session (
    session_id           RAW(16) DEFAULT SYS_GUID() NOT NULL,
    user_id              RAW(16) NOT NULL,
    refresh_token_hash   VARCHAR2(255 CHAR) NOT NULL,
    user_agent           VARCHAR2(500 CHAR),
    ip_hash              VARCHAR2(128 CHAR),
    created_at           TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
    last_seen_at         TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
    expires_at           TIMESTAMP WITH TIME ZONE NOT NULL,
    revoked_at           TIMESTAMP WITH TIME ZONE,
    CONSTRAINT pk_noxas_session PRIMARY KEY (session_id),
    CONSTRAINT fk_noxas_session_user FOREIGN KEY (user_id)
        REFERENCES noxas_user (user_id) ON DELETE CASCADE,
    CONSTRAINT ck_noxas_session_expiry CHECK (expires_at > created_at)
);

CREATE TABLE noxas_audit_event (
    audit_event_id       RAW(16) DEFAULT SYS_GUID() NOT NULL,
    user_id              RAW(16),
    session_id           RAW(16),
    event_type           VARCHAR2(80 CHAR) NOT NULL,
    event_result         VARCHAR2(20 CHAR) DEFAULT 'SUCCESS' NOT NULL,
    resource_type        VARCHAR2(60 CHAR),
    resource_id          VARCHAR2(160 CHAR),
    ip_hash              VARCHAR2(128 CHAR),
    details_json         CLOB,
    created_at           TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_noxas_audit_event PRIMARY KEY (audit_event_id),
    CONSTRAINT fk_noxas_audit_user FOREIGN KEY (user_id)
        REFERENCES noxas_user (user_id) ON DELETE SET NULL,
    CONSTRAINT fk_noxas_audit_session FOREIGN KEY (session_id)
        REFERENCES noxas_session (session_id) ON DELETE SET NULL,
    CONSTRAINT ck_noxas_audit_result CHECK (event_result IN ('SUCCESS', 'FAILURE', 'DENIED')),
    CONSTRAINT ck_noxas_audit_json CHECK (details_json IS JSON)
);

CREATE INDEX ix_noxas_identity_user ON noxas_identity (user_id);
CREATE INDEX ix_noxas_conversation_user_date ON noxas_conversation (user_id, updated_at DESC);
CREATE INDEX ix_noxas_conversation_status ON noxas_conversation (user_id, conversation_status, updated_at DESC);
CREATE INDEX ix_noxas_message_conversation ON noxas_message (conversation_id, sequence_no);
CREATE INDEX ix_noxas_session_user_expiry ON noxas_session (user_id, expires_at);
CREATE INDEX ix_noxas_audit_user_date ON noxas_audit_event (user_id, created_at DESC);
CREATE INDEX ix_noxas_audit_type_date ON noxas_audit_event (event_type, created_at DESC);

COMMENT ON TABLE noxas_user IS 'Cuenta lógica de NOXAS. No almacena contraseñas en texto plano.';
COMMENT ON TABLE noxas_identity IS 'Identidades externas o locales vinculadas a una cuenta.';
COMMENT ON TABLE noxas_credential IS 'Hash de contraseña sólo para autenticación local.';
COMMENT ON TABLE noxas_conversation IS 'Cabecera de una conversación perteneciente a un usuario.';
COMMENT ON TABLE noxas_message IS 'Mensajes ordenados de una conversación, con métricas opcionales del modelo.';
COMMENT ON TABLE noxas_session IS 'Sesiones revocables. Sólo almacena el hash del token de renovación.';
COMMENT ON TABLE noxas_audit_event IS 'Eventos de seguridad y auditoría sin guardar secretos.';
