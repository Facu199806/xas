-- NOXAS - Extensión opcional para Oracle AI Vector Search
-- Ejecutar únicamente si la instancia reconoce el tipo VECTOR.
-- La dimensión debe coincidir exactamente con el modelo de embeddings elegido.
-- Ejemplo habitual: 1536. Cambiar antes de ejecutar si corresponde.

DEFINE NOXAS_EMBEDDING_DIM = 1536

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
