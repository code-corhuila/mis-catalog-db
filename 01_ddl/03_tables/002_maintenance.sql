ALTER TABLE catalog.medication
    ADD COLUMN version BIGINT NOT NULL DEFAULT 0 CHECK (version >= 0),
    ADD COLUMN updated_at TIMESTAMPTZ,
    ADD COLUMN updated_by UUID,
    ADD CONSTRAINT ck_medication_update_audit CHECK (
        (version = 0 AND updated_at IS NULL AND updated_by IS NULL)
        OR (version > 0 AND updated_at IS NOT NULL AND updated_by IS NOT NULL));
GRANT UPDATE (code, name, active_ingredient, pharmaceutical_form, concentration,
    active, version, updated_at, updated_by) ON catalog.medication TO catalog_writer;
