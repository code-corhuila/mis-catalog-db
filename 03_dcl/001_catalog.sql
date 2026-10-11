CREATE ROLE catalog_reader NOLOGIN;
CREATE ROLE catalog_writer NOLOGIN;
GRANT USAGE ON SCHEMA catalog TO catalog_reader, catalog_writer;
GRANT SELECT ON ALL TABLES IN SCHEMA catalog TO catalog_reader;
GRANT SELECT, INSERT ON catalog.medication, catalog.creation_request TO catalog_writer;
GRANT catalog_writer TO catalog_app;
