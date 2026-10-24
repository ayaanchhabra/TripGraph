-- data/load_all.sql   (A)
-- One command to load all hand-made data, in the right order.
--
-- Prerequisites: run these BEFORE this file, in this order:
--   1. schema/01_tables.sql
--   2. schema/02_constraints.sql
--   3. schema/03_seed_reference.sql
--   4. schema/04_favorites.sql
--   5. triggers/01_review_rating.sql
--   6. triggers/02_trip_leg_continuity.sql
--   7. queries/views/01_top_rated_places.sql
--   8. queries/views/02_open_now.sql
--   9. queries/trips/01_cheapest_route.sql
-- The triggers must be installed before any review data is loaded.
--
-- Run from the repo root:
--   psql -U postgres -d tripgraph -f data/load_all.sql

\set ON_ERROR_STOP on
\i data/map/load_map.sql
\i data/load_places.sql
