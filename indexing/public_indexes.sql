-- indexing/public_indexes.sql
-- Purpose : Indexes for the REAL tables in schema public (place, edge, review, place_tag).
--           indexing/create_indexes.sql only builds indexes on the benchmark copy (bench.place);
--           this file gives the real tables the same kind of help, using the same ideas.
-- Run     : psql -U postgres -d tripgraph -v ON_ERROR_STOP=1 -f indexing/public_indexes.sql
-- Undo    : psql -U postgres -d tripgraph -v ON_ERROR_STOP=1 -f indexing/drop_public_indexes.sql
-- Re-run  : safe. Every index uses CREATE INDEX IF NOT EXISTS.
-- Needs   : the schema files (schema/01_tables.sql and the rest of the run order) loaded first.
--
-- Agreed with the schema owner before merging; schema/ files are not edited.
--
-- All names start with idx_public_ so they never clash with the bench indexes.
-- The full-text GIN index on place.name (idx_place_name_fts_gin) is NOT created here:
-- indexing/fulltext_search.sql already creates it.

-- ---------------------------------------------------------------------------
-- 1. The five indexes
-- ---------------------------------------------------------------------------

-- Category pages: "places in one category with price_level <= 2".
-- Equality column first (category_id), range column second (price_level).
CREATE INDEX IF NOT EXISTS idx_public_place_category_price
    ON public.place (category_id, price_level);

-- Top-rated lists: best rated places inside one category.
-- Partial: only places with at least 5 reviews are indexed, so it is small.
-- A query can use it only if its own WHERE repeats review_count >= 5.
CREATE INDEX IF NOT EXISTS idx_public_place_toprated_partial
    ON public.place (category_id, avg_rating DESC)
    WHERE review_count >= 5;

-- Routing: cheapest_route joins edge e ON e.from_node = <current node>.
-- A foreign key does not create an index by itself in PostgreSQL, so we add it.
CREATE INDEX IF NOT EXISTS idx_public_edge_from_node
    ON public.edge (from_node);

-- Reviews of one place. The primary key is (user_id, place_id), which is only useful when
-- user_id is known, so place_id alone is not indexed without this.
CREATE INDEX IF NOT EXISTS idx_public_review_place
    ON public.review (place_id);

-- Places that carry one tag. The primary key is (place_id, tag_id), so searching by
-- tag_id alone needs its own index.
CREATE INDEX IF NOT EXISTS idx_public_place_tag_tag
    ON public.place_tag (tag_id);

-- ---------------------------------------------------------------------------
-- 2. Refresh the planner statistics
-- ---------------------------------------------------------------------------
ANALYZE public.place;
ANALYZE public.edge;
ANALYZE public.review;
ANALYZE public.place_tag;
ANALYZE public.node;

-- ---------------------------------------------------------------------------
-- 3. Verification: expect exactly 5 rows
-- ---------------------------------------------------------------------------
SELECT tablename, indexname, indexdef
FROM   pg_indexes
WHERE  schemaname = 'public'
  AND  indexname LIKE 'idx_public_%'
ORDER  BY tablename, indexname;

-- ---------------------------------------------------------------------------
-- 4. EXPLAIN examples
-- ---------------------------------------------------------------------------
-- Honest note: the demo data has only about a dozen places, edges and reviews. For tables
-- that tiny, reading everything is cheaper than walking an index, so PostgreSQL will usually
-- choose a Seq Scan. That is the planner being correct, not the index being broken.
-- To SEE the index being used, we run SET enable_seqscan = off; before the EXPLAIN.
-- It does not forbid Seq Scans, it only makes them look very expensive, so the planner
-- picks the index path instead. RESET enable_seqscan; puts it back afterwards.
-- On the 100k+ row benchmark data the index is chosen without this switch.
-- (Change the literal values below if your demo data has other ids.)

-- Example 1: category + price_level filter on place -> idx_public_place_category_price
EXPLAIN (ANALYZE, COSTS OFF)
SELECT place_id, name, price_level
FROM   public.place
WHERE  category_id = 1
  AND  price_level <= 2;

SET enable_seqscan = off;
EXPLAIN (ANALYZE, COSTS OFF)
SELECT place_id, name, price_level
FROM   public.place
WHERE  category_id = 1
  AND  price_level <= 2;
RESET enable_seqscan;

-- Example 2: the edge join used inside cheapest_route (edges that leave one node)
--            -> idx_public_edge_from_node
EXPLAIN (ANALYZE, COSTS OFF)
SELECT e.edge_id, e.to_node, e.mode, e.fare
FROM   public.node n
JOIN   public.edge e ON e.from_node = n.node_id
WHERE  n.name = 'NSUT Main Gate';

SET enable_seqscan = off;
EXPLAIN (ANALYZE, COSTS OFF)
SELECT e.edge_id, e.to_node, e.mode, e.fare
FROM   public.node n
JOIN   public.edge e ON e.from_node = n.node_id
WHERE  n.name = 'NSUT Main Gate';
RESET enable_seqscan;

-- Example 3: all review rows for one place -> idx_public_review_place
EXPLAIN (ANALYZE, COSTS OFF)
SELECT user_id, rating, created_at
FROM   public.review
WHERE  place_id = 2;

SET enable_seqscan = off;
EXPLAIN (ANALYZE, COSTS OFF)
SELECT user_id, rating, created_at
FROM   public.review
WHERE  place_id = 2;
RESET enable_seqscan;
