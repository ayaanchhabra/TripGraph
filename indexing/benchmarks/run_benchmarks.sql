-- indexing/benchmarks/run_benchmarks.sql   (A)   PHASE 4
-- Runs all benchmark queries in four index states and builds the before/after table.
--   1_no_index   no indexes at all (baseline)
--   2_btree      B-tree indexes (composite, partial, name)
--   3_hash       same, but HASH index on name instead of B-tree
--   4_btree_gin  B-tree set + GIN full-text index
--
-- Needs: data/generate_bulk.sql already run (bench schema exists).
-- Run from the REPO ROOT (takes about a minute at 100k places):
--   psql -U postgres -d tripgraph -f indexing/benchmarks/run_benchmarks.sql
-- More timed runs per query:  -v runs=10
--
-- Outputs (indexing/benchmarks/results/):
--   <stage>_plans.txt   full EXPLAIN (ANALYZE, BUFFERS) text per stage (for screenshots)
--   summary.csv         the before/after timing table (send to AJ)
--   index_sizes.csv     size of each index
-- RE-RUNNABLE: the bench_log schema is rebuilt every time. generate_bulk.sql drops
-- the bench schema but not bench_log, so just run this again after regenerating data.

\set ON_ERROR_STOP on
\timing off

\if :{?runs}
\else
  \set runs 5
\endif

DO $$
BEGIN
  IF to_regclass('bench.place') IS NULL OR to_regclass('bench.review') IS NULL THEN
    RAISE EXCEPTION 'bench schema not found: run data/generate_bulk.sql first';
  END IF;
END $$;

-- 0. result tables ---------------------------------------------------------
DROP SCHEMA IF EXISTS bench_log CASCADE;
CREATE SCHEMA bench_log;

CREATE TABLE bench_log.query (qname text PRIMARY KEY, descr text, sql text NOT NULL);

CREATE TABLE bench_log.timing (
  stage       text,
  qname       text,
  run_no      int,
  exec_ms     numeric,
  plan_nodes  text,      -- scan types the planner used, e.g. "Bitmap Heap Scan, Bitmap Index Scan"
  index_names text       -- which index (if any) was used
);

CREATE TABLE bench_log.index_size (stage text, index_name text, size_kb bigint);

-- run every stored query p_runs times (plus 1 warm-up) and log Execution Time + plan shape
CREATE FUNCTION bench_log.run_stage(p_stage text, p_runs int) RETURNS void
LANGUAGE plpgsql AS $f$
DECLARE
  q    record;
  plan json;
  i    int;
BEGIN
  FOR q IN SELECT qname, sql FROM bench_log.query ORDER BY qname LOOP
    FOR i IN 0 .. p_runs LOOP
      EXECUTE 'EXPLAIN (ANALYZE, FORMAT JSON) ' || q.sql INTO plan;
      IF i > 0 THEN
        INSERT INTO bench_log.timing (stage, qname, run_no, exec_ms, plan_nodes, index_names)
        VALUES (
          p_stage, q.qname, i,
          (plan -> 0 ->> 'Execution Time')::numeric,
          (SELECT string_agg(DISTINCT t.m[1], ', ' ORDER BY t.m[1])
             FROM regexp_matches(plan::text, '"Node Type": *"([^"]*Scan)"', 'g') AS t(m)),
          (SELECT string_agg(DISTINCT t.m[1], ', ' ORDER BY t.m[1])
             FROM regexp_matches(plan::text, '"Index Name": *"([^"]+)"', 'g') AS t(m))
        );
      END IF;
    END LOOP;
  END LOOP;
END
$f$;

-- 1. probe values + the queries ----------------------------------------------
SELECT category_id AS cat_id FROM public.category WHERE name = 'Cafes' \gset
SELECT name AS probe_name FROM bench.place
WHERE place_id = (SELECT max(place_id) / 2 FROM bench.place) \gset

\i indexing/benchmarks/queries.sql

-- 2. the four stages -----------------------------------------------------------
\set stage '1_no_index'
\set mode  none
\i indexing/benchmarks/_run_stage.sql

\set stage '2_btree'
\set mode  btree
\i indexing/benchmarks/_run_stage.sql

\set stage '3_hash'
\set mode  hash
\i indexing/benchmarks/_run_stage.sql

\set stage '4_btree_gin'
\set mode  all
\i indexing/benchmarks/_run_stage.sql

-- 3. summary views -------------------------------------------------------------
-- median execution time per query and stage
CREATE VIEW bench_log.summary AS
WITH m AS (
  SELECT qname,
    round(percentile_cont(0.5) WITHIN GROUP (ORDER BY exec_ms) FILTER (WHERE stage = '1_no_index')::numeric, 3)   AS no_index_ms,
    round(percentile_cont(0.5) WITHIN GROUP (ORDER BY exec_ms) FILTER (WHERE stage = '2_btree')::numeric, 3)      AS btree_ms,
    round(percentile_cont(0.5) WITHIN GROUP (ORDER BY exec_ms) FILTER (WHERE stage = '3_hash')::numeric, 3)       AS hash_ms,
    round(percentile_cont(0.5) WITHIN GROUP (ORDER BY exec_ms) FILTER (WHERE stage = '4_btree_gin')::numeric, 3)  AS btree_gin_ms
  FROM bench_log.timing
  GROUP BY qname
)
SELECT qname, no_index_ms, btree_ms, hash_ms, btree_gin_ms,
       round(no_index_ms / NULLIF(least(btree_ms, hash_ms, btree_gin_ms), 0), 1) AS best_speedup_x
FROM m ORDER BY qname;

-- which scan the planner chose, per query and stage
CREATE VIEW bench_log.plans AS
SELECT DISTINCT ON (qname, stage) qname, stage, plan_nodes, index_names
FROM bench_log.timing
ORDER BY qname, stage, run_no;

\echo ''
\echo '=== Median execution time (ms) ==='
SELECT * FROM bench_log.summary;
\echo '=== Scan types chosen by the planner ==='
SELECT * FROM bench_log.plans;
\echo '=== Index sizes (kB) ==='
SELECT * FROM bench_log.index_size ORDER BY stage, index_name;

\copy (SELECT * FROM bench_log.summary) TO 'indexing/benchmarks/results/summary.csv' WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM bench_log.index_size ORDER BY stage, index_name) TO 'indexing/benchmarks/results/index_sizes.csv' WITH (FORMAT csv, HEADER true)

-- 4. leave the database in the baseline (no index) state
\i indexing/drop_indexes.sql
\echo 'Finished. Plans and CSVs are in indexing/benchmarks/results/'
