-- indexing/viva_demo.sql   (A)
-- Short live demo for the viva (step 3 of the demo plan): same query, with and without an index.
-- Needs bench data (data/generate_bulk.sql). Run from the REPO ROOT:
--   psql -U postgres -d tripgraph -f indexing/viva_demo.sql
-- Read the "Seq Scan" vs "Index/Bitmap Scan" line and the "Execution Time" line of each plan.

\set ON_ERROR_STOP on
SELECT category_id AS cat_id FROM public.category WHERE name = 'Cafes' \gset

\echo '=== 1. WITHOUT any index ==='
\i indexing/drop_indexes.sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT place_id, name, price_level FROM bench.place
WHERE category_id = :cat_id AND price_level <= 2;

\echo '=== 2. WITH the composite B-tree index ==='
\set idx_mode btree
\i indexing/create_indexes.sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT place_id, name, price_level FROM bench.place
WHERE category_id = :cat_id AND price_level <= 2;

\echo '=== 3. Top-rated in one category, using the partial index ==='
EXPLAIN (ANALYZE, BUFFERS)
SELECT place_id, name, avg_rating, review_count FROM bench.place
WHERE category_id = :cat_id AND review_count >= 5
ORDER BY avg_rating DESC LIMIT 10;

\echo '=== 4. Same query after dropping the indexes again ==='
\i indexing/drop_indexes.sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT place_id, name, avg_rating, review_count FROM bench.place
WHERE category_id = :cat_id AND review_count >= 5
ORDER BY avg_rating DESC LIMIT 10;
