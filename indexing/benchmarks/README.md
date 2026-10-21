# Phase 4: indexing and benchmarks (A)

## 1. Concepts in plain language (read first, these are the viva questions)

**Seq Scan** = read every row of the table. Fine for small tables, slow for 100k+.
**Index** = a separate sorted/hashed structure that points to rows, so Postgres can jump to them.
It costs disk space and slows INSERT/UPDATE/DELETE (the index must be updated too).

| Index type | Good for | Not good for | Used here for |
|---|---|---|---|
| B-tree (default) | `=`, `<`, `>`, `BETWEEN`, `ORDER BY`, prefix `LIKE 'abc%'` | `LIKE '%abc'`, words inside text | Q1, Q2, Q3 |
| Hash | only `=` (very direct lookup) | ranges, sorting, multi-column | Q2 (compared with B-tree) |
| GIN | "which rows contain this word/element": full-text, arrays, JSON | plain range/equality on numbers | Q4 |

- **Composite index** `(category_id, price_level)`: equality column first, range column second.
  It also helps queries on `category_id` alone, but not on `price_level` alone.
- **Partial index** `... WHERE review_count >= 5`: indexes only some rows, so it is smaller.
  A query can use it only if its own WHERE repeats that condition.
- **Selectivity**: the fraction of rows a query returns. An index pays off when this is small.
  If a query returns a large share of the table, the planner correctly prefers a Seq Scan.
- **EXPLAIN ANALYZE** actually runs the query and shows the real plan and time.
  Look at: the scan type (`Seq Scan`, `Index Scan`, `Bitmap Heap Scan`), `Execution Time`,
  `Rows Removed by Filter` (work thrown away), and with BUFFERS the pages read.
- **Why might an index be ignored?** low selectivity; table too small; stale statistics (run ANALYZE);
  the query does not match the index expression/predicate; leading wildcard in LIKE.

## 2. The five queries

| Query | What it does | Index that should help |
|---|---|---|
| Q1_category_price | places in one category with price_level <= 2 | `idx_place_category_price` (composite B-tree) |
| Q2_name_lookup | one place by exact name | `idx_place_name_btree` or `idx_place_name_hash` |
| Q3_top_rated_stored | top 10 rated in a category (uses stored avg_rating) | `idx_place_toprated_partial` |
| Q4_fulltext_name | names containing "balaji" and "tiffin" | `idx_place_name_fts_gin` |
| Q5_top_rated_computed | same result as Q3 but AVG() from `review` | none on purpose: shows why avg_rating is denormalized |

## 3. How to run
```bash
# once the schema, seed, map and bench data exist
psql -U postgres -d tripgraph -f data/generate_bulk.sql
psql -U postgres -d tripgraph -f indexing/benchmarks/run_benchmarks.sql
# live demo for the viva
psql -U postgres -d tripgraph -f indexing/viva_demo.sql
```
Stages: `1_no_index`, `2_btree`, `3_hash`, `4_btree_gin`. Each query is run 1 warm-up + 5 timed times; the table shows the **median**.

## 4. Results table (fill from `results/summary.csv`, then send to AJ)

| Query | No index (ms) | B-tree (ms) | Hash (ms) | B-tree + GIN (ms) | Scan used after |
|---|---|---|---|---|---|
| Q1_category_price | | | | | |
| Q2_name_lookup | | | | | |
| Q3_top_rated_stored | | | | | |
| Q4_fulltext_name | | | | | |
| Q5_top_rated_computed | | | | | |

Expected pattern (check against YOUR numbers, do not copy this): Q1 and Q3 drop clearly with B-tree;
Q2 drops a lot with both B-tree and hash and the two are close; Q4 only drops in the GIN stage;
Q5 stays slow whatever we do. If a result surprises you, open `results/<stage>_plans.txt` and find out why. That is the viva answer.

## 5. Test checklist
- [ ] `bench_checks.sql` checks 2 to 7 return 0 rows before you benchmark.
- [ ] `run_benchmarks.sql` finishes with no error and `results/` has 4 `*_plans.txt` files + `summary.csv`.
- [ ] In `1_no_index_plans.txt` Q1, Q2, Q3, Q4 show `Seq Scan`.
- [ ] In `2_btree_plans.txt` Q1/Q2/Q3 show an index or bitmap scan with the right index name.
- [ ] In `4_btree_gin_plans.txt` Q4 uses `idx_place_name_fts_gin`.
- [ ] Re-running gives similar medians (small differences are normal).
- [ ] After the run, `\di bench.*` shows no leftover indexes.

## 6. How it connects
- **K**: his `top_rated_places` view and category queries are the real-world versions of Q1/Q3. Once you agree, K can add the same indexes to the `public` schema (e.g. `place(category_id, price_level)`, FK columns such as `review(place_id)`). Tell K the exact definitions from `create_indexes.sql`; do not edit his schema files yourself.
- **AJ**: needs `results/summary.csv`, the `*_plans.txt` screenshots and `avg_rating_denormalization.md` for the report.
- **S**: his search page can reuse the Q4 full-text query (Phase 5 builds the proper ranked search and tag search).
- **Viva demo step 3** = `indexing/viva_demo.sql`.

## 7. Questions to be ready for
1. Why did Q1 use a Bitmap scan instead of a plain Index Scan? (many matching rows; bitmap reads pages in order)
2. Why is hash not much faster than B-tree on Q2? (both are one lookup on 100k rows; the gap shows only at much larger sizes)
3. Why does `LIKE '%tiffin%'` not use a B-tree, and what do we use instead? (GIN full-text)
4. Why is the top-rated index partial? (small, skips unrated places, matches the query condition)
5. What does an index cost? (disk, slower writes; see `index_sizes.csv`)
6. Why is `avg_rating` stored and is `place` still in BCNF? (see `avg_rating_denormalization.md`)
