-- NOXAS - Base de conocimiento y trazabilidad de fuentes
-- Diseñada para RAG: recuperar documentación relevante y citarla.
-- La ingestión debe respetar términos de uso, licencias y permisos de cada fuente.

CREATE TABLE noxas_kb_source (
    source_id            RAW(16) DEFAULT SYS_GUID() NOT NULL,
    source_code          VARCHAR2(80 CHAR) NOT NULL,
    source_name          VARCHAR2(240 CHAR) NOT NULL,
    publisher_name       VARCHAR2(160 CHAR) NOT NULL,
    base_url             VARCHAR2(1000 CHAR),
    source_kind          VARCHAR2(30 CHAR) NOT NULL,
    trust_level          NUMBER(2) DEFAULT 5 NOT NULL,
    sync_strategy        VARCHAR2(30 CHAR) DEFAULT 'MANUAL' NOT NULL,
    enabled_flag         CHAR(1 CHAR) DEFAULT 'Y' NOT NULL,
    license_note         VARCHAR2(1000 CHAR),
    last_sync_at         TIMESTAMP WITH TIME ZONE,
    created_at           TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
    updated_at           TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_noxas_kb_source PRIMARY KEY (source_id),
    CONSTRAINT uq_noxas_kb_source_code UNIQUE (source_code),
    CONSTRAINT ck_noxas_kb_source_kind CHECK (source_kind IN ('DOCUMENTATION', 'CATALOG_API', 'REPOSITORY', 'MANUAL', 'PRIVATE_DOCS')),
    CONSTRAINT ck_noxas_kb_source_trust CHECK (trust_level BETWEEN 1 AND 10),
    CONSTRAINT ck_noxas_kb_source_sync CHECK (sync_strategy IN ('MANUAL', 'DAILY', 'WEEKLY', 'ON_DEMAND', 'WEBHOOK')),
    CONSTRAINT ck_noxas_kb_source_enabled CHECK (enabled_flag IN ('Y', 'N'))
);

CREATE TABLE noxas_kb_document (
    document_id          RAW(16) DEFAULT SYS_GUID() NOT NULL,
    source_id            RAW(16) NOT NULL,
    external_key         VARCHAR2(500 CHAR),
    title                VARCHAR2(1000 CHAR) NOT NULL,
    canonical_url        VARCHAR2(2000 CHAR),
    product_name         VARCHAR2(240 CHAR),
    product_version      VARCHAR2(120 CHAR),
    language_code        VARCHAR2(20 CHAR) DEFAULT 'en-US' NOT NULL,
    document_status      VARCHAR2(20 CHAR) DEFAULT 'ACTIVE' NOT NULL,
    published_at         TIMESTAMP WITH TIME ZONE,
    source_modified_at   TIMESTAMP WITH TIME ZONE,
    retrieved_at         TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
    content_hash         VARCHAR2(128 CHAR) NOT NULL,
    metadata_json        CLOB,
    created_at           TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
    updated_at           TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_noxas_kb_document PRIMARY KEY (document_id),
    CONSTRAINT fk_noxas_kb_document_source FOREIGN KEY (source_id)
        REFERENCES noxas_kb_source (source_id) ON DELETE CASCADE,
    CONSTRAINT uq_noxas_kb_document_key UNIQUE (source_id, external_key),
    CONSTRAINT ck_noxas_kb_document_status CHECK (document_status IN ('ACTIVE', 'STALE', 'REMOVED', 'BLOCKED')),
    CONSTRAINT ck_noxas_kb_document_json CHECK (metadata_json IS JSON)
);

CREATE TABLE noxas_kb_chunk (
    chunk_id             RAW(16) DEFAULT SYS_GUID() NOT NULL,
    document_id          RAW(16) NOT NULL,
    chunk_no             NUMBER(10) NOT NULL,
    section_path         VARCHAR2(1000 CHAR),
    source_anchor        VARCHAR2(500 CHAR),
    chunk_text           CLOB NOT NULL,
    token_count          NUMBER(10),
    content_hash         VARCHAR2(128 CHAR) NOT NULL,
    embedding_status     VARCHAR2(20 CHAR) DEFAULT 'PENDING' NOT NULL,
    embedding_model      VARCHAR2(160 CHAR),
    embedding_dimensions NUMBER(10),
    metadata_json        CLOB,
    created_at           TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
    updated_at           TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_noxas_kb_chunk PRIMARY KEY (chunk_id),
    CONSTRAINT fk_noxas_kb_chunk_document FOREIGN KEY (document_id)
        REFERENCES noxas_kb_document (document_id) ON DELETE CASCADE,
    CONSTRAINT uq_noxas_kb_chunk_no UNIQUE (document_id, chunk_no),
    CONSTRAINT ck_noxas_kb_chunk_no CHECK (chunk_no >= 0),
    CONSTRAINT ck_noxas_kb_chunk_tokens CHECK (token_count IS NULL OR token_count >= 0),
    CONSTRAINT ck_noxas_kb_chunk_dims CHECK (embedding_dimensions IS NULL OR embedding_dimensions > 0),
    CONSTRAINT ck_noxas_kb_chunk_status CHECK (embedding_status IN ('PENDING', 'READY', 'ERROR', 'SKIPPED')),
    CONSTRAINT ck_noxas_kb_chunk_json CHECK (metadata_json IS JSON)
);

CREATE TABLE noxas_kb_sync_run (
    sync_run_id          RAW(16) DEFAULT SYS_GUID() NOT NULL,
    source_id            RAW(16) NOT NULL,
    run_status           VARCHAR2(20 CHAR) DEFAULT 'RUNNING' NOT NULL,
    started_at           TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
    finished_at          TIMESTAMP WITH TIME ZONE,
    documents_seen       NUMBER(12) DEFAULT 0 NOT NULL,
    documents_created    NUMBER(12) DEFAULT 0 NOT NULL,
    documents_updated    NUMBER(12) DEFAULT 0 NOT NULL,
    documents_failed     NUMBER(12) DEFAULT 0 NOT NULL,
    error_summary        CLOB,
    metadata_json        CLOB,
    CONSTRAINT pk_noxas_kb_sync_run PRIMARY KEY (sync_run_id),
    CONSTRAINT fk_noxas_kb_sync_source FOREIGN KEY (source_id)
        REFERENCES noxas_kb_source (source_id) ON DELETE CASCADE,
    CONSTRAINT ck_noxas_kb_sync_status CHECK (run_status IN ('RUNNING', 'COMPLETED', 'PARTIAL', 'FAILED', 'CANCELLED')),
    CONSTRAINT ck_noxas_kb_sync_counts CHECK (
        documents_seen >= 0 AND documents_created >= 0 AND documents_updated >= 0 AND documents_failed >= 0
    ),
    CONSTRAINT ck_noxas_kb_sync_json CHECK (metadata_json IS JSON)
);

CREATE TABLE noxas_kb_retrieval_log (
    retrieval_id         RAW(16) DEFAULT SYS_GUID() NOT NULL,
    user_id              RAW(16),
    conversation_id      RAW(16),
    query_hash           VARCHAR2(128 CHAR) NOT NULL,
    retrieval_mode       VARCHAR2(20 CHAR) NOT NULL,
    result_count         NUMBER(5) DEFAULT 0 NOT NULL,
    top_score            NUMBER,
    source_codes_json    CLOB,
    latency_ms           NUMBER(12),
    created_at           TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_noxas_kb_retrieval PRIMARY KEY (retrieval_id),
    CONSTRAINT fk_noxas_kb_retrieval_user FOREIGN KEY (user_id)
        REFERENCES noxas_user (user_id) ON DELETE SET NULL,
    CONSTRAINT fk_noxas_kb_retrieval_conv FOREIGN KEY (conversation_id)
        REFERENCES noxas_conversation (conversation_id) ON DELETE SET NULL,
    CONSTRAINT ck_noxas_kb_retrieval_mode CHECK (retrieval_mode IN ('KEYWORD', 'VECTOR', 'HYBRID')),
    CONSTRAINT ck_noxas_kb_retrieval_count CHECK (result_count >= 0),
    CONSTRAINT ck_noxas_kb_retrieval_latency CHECK (latency_ms IS NULL OR latency_ms >= 0),
    CONSTRAINT ck_noxas_kb_retrieval_json CHECK (source_codes_json IS JSON)
);

CREATE INDEX ix_noxas_kb_document_source ON noxas_kb_document (source_id, document_status, updated_at DESC);
CREATE INDEX ix_noxas_kb_document_product ON noxas_kb_document (product_name, product_version);
CREATE INDEX ix_noxas_kb_chunk_document ON noxas_kb_chunk (document_id, chunk_no);
CREATE INDEX ix_noxas_kb_chunk_embed ON noxas_kb_chunk (embedding_status, updated_at);
CREATE INDEX ix_noxas_kb_sync_source ON noxas_kb_sync_run (source_id, started_at DESC);
CREATE INDEX ix_noxas_kb_retrieval_date ON noxas_kb_retrieval_log (created_at DESC);

COMMENT ON TABLE noxas_kb_source IS 'Registro permitido de fuentes oficiales, privadas o manuales.';
COMMENT ON TABLE noxas_kb_document IS 'Metadatos versionados de cada documento recuperado.';
COMMENT ON TABLE noxas_kb_chunk IS 'Fragmentos citables usados por recuperación semántica o por palabras clave.';
COMMENT ON TABLE noxas_kb_sync_run IS 'Auditoría de cada sincronización de una fuente.';
COMMENT ON TABLE noxas_kb_retrieval_log IS 'Métricas de recuperación sin almacenar la consulta original del usuario.';

-- Fuentes iniciales. No implica permiso automático para copiar todo su contenido.
INSERT INTO noxas_kb_source (
    source_code, source_name, publisher_name, base_url, source_kind, trust_level, sync_strategy, license_note
) VALUES (
    'ORACLE_DOCS', 'Oracle Documentation', 'Oracle', 'https://docs.oracle.com', 'DOCUMENTATION', 10, 'ON_DEMAND',
    'Priorizar documentación pública oficial. Oracle Support/MOS requiere acceso y permisos separados.'
);

INSERT INTO noxas_kb_source (
    source_code, source_name, publisher_name, base_url, source_kind, trust_level, sync_strategy, license_note
) VALUES (
    'MS_LEARN', 'Microsoft Learn', 'Microsoft', 'https://learn.microsoft.com', 'CATALOG_API', 10, 'DAILY',
    'Usar la API oficial de Microsoft Learn para catálogo y enlaces; respetar Microsoft API Terms of Use.'
);

INSERT INTO noxas_kb_source (
    source_code, source_name, publisher_name, base_url, source_kind, trust_level, sync_strategy, license_note
) VALUES (
    'LINUX_KERNEL', 'Linux Kernel Documentation', 'Linux Kernel Community', 'https://docs.kernel.org', 'DOCUMENTATION', 10, 'WEEKLY',
    'Documentación oficial del kernel; conservar versión y enlace canónico.'
);

INSERT INTO noxas_kb_source (
    source_code, source_name, publisher_name, base_url, source_kind, trust_level, sync_strategy, license_note
) VALUES (
    'RHEL_DOCS', 'Red Hat Enterprise Linux Documentation', 'Red Hat', 'https://docs.redhat.com', 'DOCUMENTATION', 9, 'WEEKLY',
    'Conservar producto y versión; algunas áreas pueden requerir autenticación o suscripción.'
);

INSERT INTO noxas_kb_source (
    source_code, source_name, publisher_name, base_url, source_kind, trust_level, sync_strategy, license_note
) VALUES (
    'UBUNTU_SERVER', 'Ubuntu Server Documentation', 'Canonical', 'https://ubuntu.com/server/docs', 'DOCUMENTATION', 9, 'WEEKLY',
    'Conservar versión LTS y fecha de actualización.'
);

COMMIT;
