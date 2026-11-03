-- indexing/benchmarks/queries.sql
-- Defines the benchmark queries ONCE, as rows in bench_log.query.
-- Included by run_benchmarks.sql (needs bench_log.query to exist and the psql variables
-- :cat_id and :probe_name to be set). Not meant to be run on its own.
--
-- Q1  filter by category + price        (composite B-tree)
-- Q2  lookup by exact name              (B-tree vs hash)
-- Q3  top-rated in one category         (partial composite B-tree; stored avg_rating)
-- Q4  full-text search on the name      (GIN)
-- Q5  top-rated computed from reviews   (NOT indexed: shows why avg_rating is denormalized)

INSERT INTO bench_log.query (qname, descr, sql) VALUES
('Q1_category_price',
 'Places in one category with price_level <= 2',
 format($q$
   SELECT place_id, name, price_level, avg_rating
   FROM bench.place
   WHERE category_id = %s AND price_level <= 2
 $q$, :cat_id)),

('Q2_name_lookup',
 'Exact name lookup (1 row)',
 format($q$
   SELECT place_id, name, category_id, price_level
   FROM bench.place
   WHERE name = %L
 $q$, :'probe_name')),

('Q3_top_rated_stored',
 'Top 10 rated places in one category, using stored avg_rating',
 format($q$
   SELECT place_id, name, avg_rating, review_count
   FROM bench.place
   WHERE category_id = %s AND review_count >= 5
   ORDER BY avg_rating DESC
   LIMIT 10
 $q$, :cat_id)),

('Q4_fulltext_name',
 'Full-text search: names containing both words "balaji" and "tiffin"',
 $q$
   SELECT place_id, name
   FROM bench.place
   WHERE to_tsvector('simple', name) @@ to_tsquery('simple', 'balaji & tiffin')
 $q$),

('Q5_top_rated_computed',
 'Same answer as Q3 but AVG() computed from bench.review every time (no denormalization)',
 format($q$
   SELECT p.place_id, p.name, round(avg(r.rating), 2) AS avg_rating, count(*) AS review_count
   FROM bench.place p
   JOIN bench.review r ON r.place_id = p.place_id
   WHERE p.category_id = %s
   GROUP BY p.place_id, p.name
   HAVING count(*) >= 5
   ORDER BY avg(r.rating) DESC
   LIMIT 10
 $q$, :cat_id));
