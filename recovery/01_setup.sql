-- recovery/01_setup.sql   OPTIONAL crash-recovery demo, step 1
-- Creates a tiny separate table so the demo never touches real data.
\set ON_ERROR_STOP on
DROP SCHEMA IF EXISTS recovery_demo CASCADE;
CREATE SCHEMA recovery_demo;
CREATE TABLE recovery_demo.payment (id serial PRIMARY KEY, note text, created_at timestamptz DEFAULT now());
-- A COMMITTED row: must survive the crash (Durability).
INSERT INTO recovery_demo.payment(note) VALUES ('committed before crash');
SELECT * FROM recovery_demo.payment;
