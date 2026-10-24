-- data/load_all.sql   (A)
-- One command to load all hand-made data, in the right order.
-- Prerequisite: K's schema/01_tables.sql, 02_constraints.sql, 03_seed_reference.sql already loaded.
-- Run from the repo root:
--   psql -U postgres -d tripgraph -f data/load_all.sql

\set ON_ERROR_STOP on
\i data/map/load_map.sql
\i data/load_places.sql
