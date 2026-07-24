-- NOXAS - Extensión opcional para Oracle AI Vector Search
-- NO EJECUTAR en el entorno validado actualmente:
--   Oracle Database Free 23.3.0.23.09
--   COMPATIBLE = 23.0.0
-- Oracle requiere COMPATIBLE 23.4.0 o superior para utilizar el tipo VECTOR.
-- Mantener NOXAS_VECTOR_CONFIRMED = NO hasta actualizar la instancia,
-- elegir el modelo de embeddings y confirmar su dimensión exacta.

SET SERVEROUTPUT ON
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

DEFINE NOXAS_VECTOR_CONFIRMED = NO
DEFINE NOXAS_EMBEDDING_DIM = 1536

DECLARE
    v_confirmation VARCHAR2(10) := UPPER(TRIM('&NOXAS_VECTOR_CONFIRMED'));
    v_container    VARCHAR2(128) := SYS_CONTEXT('USERENV', 'CON_NAME');
    v_user         VARCHAR2(128) := SYS_CONTEXT('USERENV', 'SESSION_USER');
BEGIN
    IF v_container <> 'FREEPDB1' OR v_user <> 'NOXAS_DEV' THEN
        RAISE_APPLICATION_ERROR(-20031, '003_vector_extension_23ai.sql requiere NOXAS_DEV conectado a FREEPDB1.');
    END IF;

    IF v_confirmation <> 'YES' THEN
        RAISE_APPLICATION_ERROR(
            -20032,
            'Extensión VECTOR bloqueada. Mantenga este archivo sin ejecutar mientras COMPATIBLE sea 23.0.0.'
        );
    END IF;
END;
/

CREATE TABLE noxas_kb_embedding (
    chunk_id             RAW(16) NOT NULL,
    embedding_model      VARCHAR2(160 CHAR) NOT NULL,
    embedding_dimensions NUMBER(10) NOT NULL,
    embedding            VECTOR(&NOXAS_EMBEDDING_DIM, FLOAT32) NOT NULL,
    created_at           TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
    updated_at           TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_noxas_kb_embedding PRIMARY KEY (chunk_id),
    CONSTRAINT fk_noxas_kb_embedding_chunk FOREIGN KEY (chunk_id)
        REFERENCES noxas_kb_chunk (chunk_id) ON DELETE CASCADE,
    CONSTRAINT ck_noxas_kb_embedding_dims CHECK (embedding_dimensions = &NOXAS_EMBEDDING_DIM)
);

-- El índice HNSW requiere memoria de vector disponible y vectores consistentes.
-- Descomentar después de cargar embeddings y validar la configuración de la instancia.
--
-- CREATE VECTOR INDEX ix_noxas_kb_embedding_hnsw
-- ON noxas_kb_embedding (embedding)
-- ORGANIZATION INMEMORY NEIGHBOR GRAPH
-- DISTANCE COSINE
-- WITH TARGET ACCURACY 90;

-- Ejemplo de búsqueda semántica. :query_embedding debe ser VECTOR con la misma dimensión.
--
-- SELECT
--     c.chunk_id,
--     d.title,
--     d.canonical_url,
--     c.section_path,
--     c.chunk_text,
--     VECTOR_DISTANCE(e.embedding, :query_embedding, COSINE) AS distance
-- FROM noxas_kb_embedding e
-- JOIN noxas_kb_chunk c ON c.chunk_id = e.chunk_id
-- JOIN noxas_kb_document d ON d.document_id = c.document_id
-- WHERE d.document_status = 'ACTIVE'
-- ORDER BY distance
-- FETCH FIRST 8 ROWS ONLY;
