-- indexing/create_indexes.sql   PHASE 4
-- Builds indexes on bench.place (the 100k+ generated table).
-- Run from the REPO ROOT:
--   psql -U postgres -d tripgraph -f indexing/create_indexes.sql                  (mode "all")
--   psql -U postgres -d tripgraph -v idx_mode=hash -f indexing/create_indexes.sql
--
-- idx_mode decides WHICH set is built (so run_benchmarks.sql can compare them):
--   btree : composite (category_id, price_level) + partial top-rated index + B-tree on name
--   hash  : same, but the name index is a HASH index instead of B-tree
--   gin   : only the full-text GIN index on name
--   all   : btree set + GIN   (the final recommended set; default)
--
-- Always run drop_indexes.sql first if you change mode, otherwise old indexes stay.

\set ON_ERROR_STOP on

\if :{?idx_mode}
\else
  \set idx_mode all
\endif

SELECT :'idx_mode' IN ('btree', 'hash', 'gin', 'all')   AS ok_mode,
       :'idx_mode' IN ('btree', 'hash', 'all')          AS do_common,
       :'idx_mode' IN ('btree', 'all')                  AS do_name_btree,
       :'idx_mode' = 'hash'                             AS do_name_hash,
       :'idx_mode' IN ('gin', 'all')                    AS do_gin \gset

\if :ok_mode
\else
  \echo 'idx_mode must be one of: btree, hash, gin, all'
  \quit
\endif

\echo 'Building indexes, mode =' :idx_mode

\if :do_common
  -- Q1: WHERE category_id = ? AND price_level <= ?
  -- Composite B-tree: equality column FIRST, range column SECOND.
  CREATE INDEX idx_place_category_price ON bench.place (category_id, price_level);

  -- Q3 and the top_rated_places idea: best-rated places inside one category.
  -- Composite (category, rating DESC) so the rows come out already sorted.
  -- PARTIAL (WHERE review_count >= 5): only places with enough reviews are indexed,
  -- so the index is small and unrated places (NULL / 0 rating) never get in the way.
  -- A query must repeat the same condition (review_count >= 5) to be allowed to use it.
  CREATE INDEX idx_place_toprated_partial ON bench.place (category_id, avg_rating DESC)
    WHERE review_count >= 5;
\endif

\if :do_name_btree
  -- Q2: WHERE name = ?   (B-tree works for = and also for <, >, BETWEEN, ORDER BY)
  CREATE INDEX idx_place_name_btree ON bench.place (name);
\endif

\if :do_name_hash
  -- Q2 again, but as a HASH index: only equality (=), no ranges, no ordering.
  CREATE INDEX idx_place_name_hash ON bench.place USING hash (name);
\endif

\if :do_gin
  -- Q4: full-text search on the name. GIN stores "word -> list of rows containing it".
  -- 'simple' = no stemming/stop-words (names like 'Sharma' should not be stemmed).
  -- The query must use the SAME expression: to_tsvector('simple', name)
  CREATE INDEX idx_place_name_fts_gin ON bench.place USING gin (to_tsvector('simple', name));
\endif

ANALYZE bench.place;
\echo 'Done.'
