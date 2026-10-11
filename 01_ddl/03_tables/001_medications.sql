CREATE TABLE catalog.medication (
    id UUID PRIMARY KEY,
    code VARCHAR(40) NOT NULL CONSTRAINT uq_medication_code UNIQUE,
    name VARCHAR(160) NOT NULL,
    active_ingredient VARCHAR(160) NOT NULL,
    pharmaceutical_form VARCHAR(80) NOT NULL,
    concentration VARCHAR(80) NOT NULL,
    unit_of_measure VARCHAR(40) NOT NULL,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL,
    created_by UUID NOT NULL,
    CONSTRAINT ck_medication_code CHECK (code ~ '^[A-Z0-9-]{1,40}$'),
    CONSTRAINT ck_medication_text CHECK (
        length(btrim(name)) > 0 AND length(btrim(active_ingredient)) > 0
        AND length(btrim(pharmaceutical_form)) > 0
        AND length(btrim(concentration)) > 0 AND length(btrim(unit_of_measure)) > 0)
);
CREATE INDEX ix_medication_page ON catalog.medication (created_at DESC, id DESC);

CREATE TABLE catalog.creation_request (
    id UUID PRIMARY KEY,
    actor UUID NOT NULL,
    request_key VARCHAR(128) NOT NULL,
    request_hash VARCHAR(64) NOT NULL,
    response_json TEXT NOT NULL,
    medication_id UUID NOT NULL REFERENCES catalog.medication(id) ON DELETE RESTRICT,
    CONSTRAINT uq_creation_request UNIQUE (actor, request_key),
    CONSTRAINT ck_creation_key CHECK (request_key ~ '^[A-Za-z0-9._:-]{8,128}$'),
    CONSTRAINT ck_creation_hash CHECK (request_hash ~ '^[a-f0-9]{64}$')
);
