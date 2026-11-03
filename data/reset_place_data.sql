-- data/reset_place_data.sql  DEV ONLY
-- Clears place data so load_places.sql can be re-run.
-- Run from the repo root. Does NOT touch node/edge or category.
-- Fails if reviews / favorites / trips still reference places; delete those first
-- (or ask S/K) rather than using CASCADE and silently wiping their sample data.

\set ON_ERROR_STOP on
BEGIN;
DELETE FROM place_tag;
DELETE FROM opening_hours;
DELETE FROM food_outlet;
DELETE FROM place;
DELETE FROM tag;
COMMIT;
