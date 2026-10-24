# Viva Q&A for A's part (AJ: paste into docs/viva_qa.md)

**Q: What did you build?** The map (nodes/edges), the place loader, 100k generated rows, the index benchmarks, full-text search, relational algebra, and a recovery demo.
**Q: Why a separate `bench` schema?** The avg_rating trigger would fire per generated review and slow the load; bench tables are plain copies with no triggers/FKs/indexes, so we get a clean "no index" baseline and the demo data stays small.
**Q: Which index helped most and why?** Q2 (exact name) and Q3 (top-rated, partial composite): they return few rows, so the index avoids reading the table. Q1 returns thousands of rows, so the gain is smaller (bitmap scan).
**Q: When does the planner ignore an index?** Low selectivity (many rows match), tiny table, stale statistics, or the query does not match the index expression or partial predicate.
**Q: B-tree vs hash vs GIN?** B-tree: =, ranges, ordering. Hash: only =. GIN: "which rows contain this word": full-text, arrays, JSON.
**Q: Why does `LIKE '%tiffin%'` not use a B-tree?** A B-tree is sorted from the left; a leading wildcard has no sorted prefix. Use GIN full-text.
**Q: What does an index cost?** Disk (see index_sizes.csv) and slower INSERT/UPDATE/DELETE.
**Q: Is `place` still in BCNF with avg_rating stored?** Yes: place_id -> avg_rating and place_id is the key. The redundancy is across tables (it can be recomputed from review), so it is a deliberate denormalization kept correct by a trigger.
**Q: Relational algebra vs SQL?** RA is procedural and set-based; SQL is declarative and bag-based. Division has no SQL operator (double NOT EXISTS).
**Q: What is TRC?** Declarative: `{ t | condition }` with tuple variables and quantifiers; safe expressions give finite results.
**Q: How does PostgreSQL recover after a crash?** WAL redo from the last checkpoint; no commit record means the transaction is invisible.
