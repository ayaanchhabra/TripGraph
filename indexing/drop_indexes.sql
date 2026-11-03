-- indexing/drop_indexes.sql
-- Removes every index that create_indexes.sql can build, so you are back to the
-- "no index" baseline. Safe to run any time (IF EXISTS).
-- Run from the REPO ROOT:
--   psql -U postgres -d tripgraph -f indexing/drop_indexes.sql

\set ON_ERROR_STOP on
SET client_min_messages = warning;   -- hide "index does not exist, skipping" notices

DROP INDEX IF EXISTS bench.idx_place_category_price;
DROP INDEX IF EXISTS bench.idx_place_name_btree;
DROP INDEX IF EXISTS bench.idx_place_name_hash;
DROP INDEX IF EXISTS bench.idx_place_toprated_partial;
DROP INDEX IF EXISTS bench.idx_place_name_fts_gin;

RESET client_min_messages;
