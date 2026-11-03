# Why `place.avg_rating` and `place.review_count` are stored (denormalized)

(Short note for the report. The rating trigger keeps the values correct.)

## What is stored twice
Every rating already exists in `review(user_id, place_id, rating, ...)`.
`place.avg_rating` and `place.review_count` are just `AVG(rating)` and `COUNT(*)` of those rows.
So the same information is held in two places: a **derived attribute**.

## Is it a normal-form violation?
Strictly, no functional dependency *inside* `place` is broken: `place_id -> avg_rating` holds
and `place_id` is the key, so `place` is still in BCNF. The problem is **redundancy across tables**:
the value can be recomputed from `review`, so it can go out of sync if the trigger fails
or someone updates `review` without the trigger. That is why we call it a deliberate denormalization,
not a design mistake.

## Why we do it anyway
- Reads dominate: every list ("top-rated", category pages, search results) needs the rating.
  Reviews are written rarely by comparison.
- Without it, each list has to JOIN `review` and GROUP BY every time.
- Benchmark evidence: queries Q3 (stored value) vs Q5 (computed from reviews) in
  `indexing/benchmarks/results/summary.csv`. Same answer, Q3 can use the partial index
  `idx_place_toprated_partial` and reads a few pages; Q5 has to read and aggregate the reviews.
  Measured (median of 5 runs, 100k+ places, about 300k reviews): Q3 = 0.033 ms (B-tree stage,
  partial index), Q5 = 62.910 ms (its best stage, no index). Ratio = 62.910 / 0.033 = 1906, so
  about 1,900x. If Q5 is taken from the B-tree stage instead (124.931 ms), the ratio is
  124.931 / 0.033 = 3786, about 3,800x.

  Q5 did not get faster with indexes because its cost is reading and aggregating about 300k
  `review` rows (an AVG per place), and the indexes on `place` cannot reduce that work; the
  benchmark schema also has no index on `review(place_id)`. Only the stored `avg_rating`
  removes the aggregation.

## What we pay
- Extra work on every review insert/update/delete (the trigger recomputes the two columns).
- A consistency risk, handled by: (1) the rating trigger, (2) check 6 in `data/bench_checks.sql`
  (stored values vs recomputed values, expect 0 rows), (3) the lost-update demo
  (two sessions updating `review_count` at once; fixed with `SELECT ... FOR UPDATE`).

## One-sentence viva answer
"We stored avg_rating and review_count on `place` on purpose: lists are read far more often than
reviews are written, the benchmark shows the stored version is much faster, and a trigger plus a
consistency check keep the redundant copy correct."
