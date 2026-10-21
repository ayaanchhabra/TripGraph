-- indexing/benchmarks/_run_stage.sql   (A)   helper, called by run_benchmarks.sql
-- Expects psql variables:  :stage (label)  :mode (none | btree | hash | all)  :runs
-- 1) set the index state  2) time every query :runs times  3) save the readable plans to a file

\echo '--- stage' :stage '(indexes:' :mode ') ---'

\i indexing/drop_indexes.sql

SELECT :'mode' <> 'none' AS has_idx \gset
\if :has_idx
  \set idx_mode :mode
  \i indexing/create_indexes.sql
\endif
ANALYZE bench.place;

-- timings (run 0 of each query is a warm-up and is not stored)
SELECT bench_log.run_stage(:'stage', :runs);

-- how big are the indexes (cost side of the trade-off)
INSERT INTO bench_log.index_size (stage, index_name, size_kb)
SELECT :'stage', c.relname, pg_relation_size(c.oid) / 1024
FROM pg_index i JOIN pg_class c ON c.oid = i.indexrelid
WHERE i.indrelid = 'bench.place'::regclass;

-- readable EXPLAIN (ANALYZE, BUFFERS) output for screenshots / the report
\set plan_file 'indexing/benchmarks/results/' :stage '_plans.txt'
\o :plan_file
\pset tuples_only on
SELECT stmt FROM (
  SELECT qname, 0 AS ord, format('SELECT %L', '=== ' || qname || '   [' || :'stage' || '] ===') AS stmt
  FROM bench_log.query
  UNION ALL
  SELECT qname, 1, 'EXPLAIN (ANALYZE, BUFFERS) ' || sql FROM bench_log.query
) s ORDER BY qname, ord \gexec
\pset tuples_only off
\o
