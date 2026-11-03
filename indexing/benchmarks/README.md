# Phase 4: indexing and benchmarks

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

## 4. Results table

Median of 5 timed runs, in ms (from `results/summary.csv`). `place` has 100k+ generated rows;
`review` has about 300k rows (149,824 rows per worker, 2 workers).

| Query | No index (ms) | B-tree (ms) | Hash (ms) | B-tree + GIN (ms) | Scan used after |
|---|---|---|---|---|---|
| Q1_category_price | 11.172 | 5.791 | 7.594 | 5.924 | Bitmap Index Scan on `idx_place_category_price` |
| Q2_name_lookup | 9.169 | 0.039 | 0.021 | 0.034 | Index Scan using `idx_place_name_btree` (B-tree stage) or `idx_place_name_hash` (hash stage) |
| Q3_top_rated_stored | 17.729 | 0.033 | 0.036 | 0.036 | Index Scan using `idx_place_toprated_partial` |
| Q4_fulltext_name | 129.721 | 189.905 | 193.154 | 1.407 | Bitmap Index Scan on `idx_place_name_fts_gin` (GIN stage only; Seq Scan in the other stages) |
| Q5_top_rated_computed | 62.910 | 124.931 | 99.571 | 102.488 | Parallel Seq Scan on `review` (and Parallel Seq Scan or Bitmap scan on `place`); no index helps |

### How to read this
Each row is one query timed in four stages; a smaller number is faster, and the last column
names the scan the planner used once the indexes existed. Q2 and Q3 gain the most
(about 437x and 537x) because they fetch very few rows, Q1 gains only about 1.9x because it returns
5,634 rows, and Q4 gains about 92x but only in the GIN stage (129.7 -> 1.4 ms).

Q4 got slower in the B-tree and hash stages (129.7 -> 189.9 / 193.2 ms). This is not an effect of
the index: neither a B-tree nor a hash index can serve a word-inside-text search, so the plan is
still a Seq Scan and the difference is run-to-run noise (cache state, parallel workers).
Q5 also got slower (62.9 -> 124.9 / 99.6 / 102.5 ms) for the same reason: its cost is reading and
aggregating the `review` rows, which no index on `place` can reduce. Its `best_speedup_x` of 0.6
means "no index improved it". That is the point of Q5: only the stored `avg_rating` (Q3) avoids the work.

## 5. Test checklist
- [ ] `bench_checks.sql` checks 2 to 7 return 0 rows before you benchmark.
- [ ] `run_benchmarks.sql` finishes with no error and `results/` has 4 `*_plans.txt` files + `summary.csv`.
- [ ] In `1_no_index_plans.txt` Q1, Q2, Q3, Q4 show `Seq Scan`.
- [ ] In `2_btree_plans.txt` Q1/Q2/Q3 show an index or bitmap scan with the right index name.
- [ ] In `4_btree_gin_plans.txt` Q4 uses `idx_place_name_fts_gin`.
- [ ] Re-running gives similar medians (small differences are normal).
- [ ] After the run, `\di bench.*` shows no leftover indexes.

## 6. How it connects
- **Top-rated view**: the `top_rated_places` view and category queries are the real-world versions of Q1/Q3. After the index list is agreed, the database team can add the same indexes to the `public` schema (e.g. `place(category_id, price_level)`, FK columns such as `review(place_id)`). Use the exact definitions from `create_indexes.sql` and keep schema changes in the schema-maintenance change.
- **Report material**: `results/summary.csv`, the `*_plans.txt` screenshots and `avg_rating_denormalization.md` are useful evidence.
- **Search page**: the Q4 full-text query can be reused (Phase 5 builds the proper ranked search and tag search).
- **Viva demo step 3** = `indexing/viva_demo.sql`.

## 7. Questions to be ready for
1. Why did Q1 use a Bitmap scan instead of a plain Index Scan? (many matching rows; bitmap reads pages in order)
2. Why is hash not much faster than B-tree on Q2? (both are one lookup on 100k rows; the gap shows only at much larger sizes)
3. Why does `LIKE '%tiffin%'` not use a B-tree, and what do we use instead? (GIN full-text)
4. Why is the top-rated index partial? (small, skips unrated places, matches the query condition)
5. What does an index cost? (disk, slower writes; see `index_sizes.csv`)
6. Why is `avg_rating` stored and is `place` still in BCNF? (see `avg_rating_denormalization.md`)
