# A: status, how to run, handoff notes

## How to run my part (from the repo root, after K's schema is loaded)
```
psql -d tripgraph -f data/load_all.sql                  # map + places (needs data/csv/*.csv from AJ)
psql -d tripgraph -f data/validate_places.sql
psql -d tripgraph -f data/generate_bulk.sql             # bench schema, 100k places
psql -d tripgraph -f data/bench_checks.sql
psql -d tripgraph -f indexing/benchmarks/run_benchmarks.sql
psql -d tripgraph -f indexing/viva_demo.sql             # viva step 3
psql -d tripgraph -f indexing/fulltext_search.sql       # search view + functions (public schema)
psql -d tripgraph -f queries/relational_algebra/relational_algebra.sql
bash recovery/crash_demo.sh                             # optional, viva step 7
```

## Done
- Mini map (15 nodes, 32 edges) + loader + validator
- Place loader (from AJ's CSVs) + validator, bulk generator, bench checks
- Indexes, 4-stage benchmark, viva demo, avg_rating denormalization note
- Full-text search on name + tags (`search_places`, `places_with_tags`)
- Relational algebra x6 + TRC x1 with SQL (`relational_algebra.md/.sql`)
- Crash recovery demo (`recovery/`)
All scripts were run end to end on PostgreSQL 16 against a stand-in schema (`_scratch_test/`).

## Still to do (needs other people or your own machine)
1. Re-run everything against K's REAL schema; fix any column/type differences.
2. Run `run_benchmarks.sql` on your laptop and put YOUR numbers into `indexing/benchmarks/README.md` section 4 and into
   `avg_rating_denormalization.md` (Q3 vs Q5). The files in `results_rehearsal/` are only a rehearsal.
3. Send AJ: `results/summary.csv`, `results/*_plans.txt` screenshots, `index_sizes.csv`, `avg_rating_denormalization.md`,
   `relational_algebra.md`, `recovery/README.md`.
4. Adjust map names/distances/fares to the real Dwarka area.
5. Delete `_scratch_test/` once K's schema is merged.

## Messages to send
**To K**
- Please add these to the public schema: `place(category_id, price_level)`, `place(category_id, avg_rating DESC) WHERE review_count >= 5`,
  and indexes on FK columns such as `review(place_id)`, `place_tag(tag_id)`, `edge(from_node)`. Definitions are in `indexing/create_indexes.sql`.
- Confirm `opening_hours.day`: 1 = Monday ... 7 = Sunday?
- My loader needs these exact names/types: `category.name` seed text must equal the `category_name` values in AJ's CSV
  (my stand-in used the names from the project description; your seed text must match them exactly, e.g. "Study spots" vs "Study spots (libraries, quiet cafes)").
- `place.avg_rating` / `review_count` need defaults (NULL/0) so the loader can omit them; `node.name` must be UNIQUE (the loader joins on it).
- `search_places()` ranks ties by `avg_rating`; fine if the trigger keeps it filled.
**To AJ**
- Names in `places.csv` (`category_name`, `node_name`) must match exactly; the map has 8 place nodes (Cafe X, Dhaba Y, Stationery and Photocopy Shop,
  Chaat Corner, Grocery Store, Medical Store, City Park, Mall). Several places may share a node.
- Every place needs 7 opening_hours rows and at least one tag; see `data/CSV_CONTRACT.md`.
**To S**
- The search page can call `SELECT * FROM search_places('veg cafe');` and `SELECT * FROM places_with_tags(ARRAY['veg','wifi']);`.
