# Normalization chapter (Phase: design theory)

This folder shows why a badly designed table causes trouble and how splitting it into
smaller tables (up to BCNF) fixes it. Everything here is separate from the real TripGraph
tables: it only creates the table `tripgraph_messy` and the schema `norm_demo`.

## What each file is for
| File | Purpose |
|---|---|
| `messy_table.sql` | Builds the badly designed table `tripgraph_messy` and demonstrates 3 anomalies (update, insert, delete). |
| `functional_dependencies.md` | The list of functional dependencies, attribute closures, candidate keys and the minimal cover. |
| `decomposition_steps.md` | The steps from 1NF to BCNF, the lossless (chase) proof, dependency preservation and 8 viva questions. |
| `normalized_tables.sql` | Builds schema `norm_demo` with the final BCNF tables, mapped to the real TripGraph tables. |

## How to run (repo root, in this order)
```bash
psql -U postgres -d tripgraph -v ON_ERROR_STOP=1 -f normalization/messy_table.sql
psql -U postgres -d tripgraph -v ON_ERROR_STOP=1 -f normalization/normalized_tables.sql
```
`normalized_tables.sql` needs the table made by `messy_table.sql`, so never swap the order.
Both files can be re-run.

**Expected NOTICE:** `messy_table.sql` prints NOTICE lines ("INSERT ANOMALY: ...") about an insert that is refused
on purpose. That is part of the demo, not an error.

## 5-step viva walk-through
1. **Messy table:** run `messy_table.sql` and show `tripgraph_messy` (one wide table, repeated facts).
2. **Anomalies:** point at the three anomaly demos and read what each NOTICE says.
3. **FDs and closure:** open `functional_dependencies.md`; show the FD list, one closure, the keys.
4. **Decomposition:** open `decomposition_steps.md`; walk 1NF -> 2NF -> 3NF -> BCNF, then run
   `normalized_tables.sql` and show the `norm_demo` tables.
5. **Proof:** show the chase (lossless join) proof and the dependency-preservation check.

## Test checklist
- [ ] `messy_table.sql` finishes with no ERROR (the NOTICE about the refused insert is expected).
- [ ] `normalized_tables.sql` finishes with no ERROR, after `messy_table.sql`.
- [ ] Both files can be run a second time without errors.
- [ ] `\dt norm_demo.*` lists the final tables.
- [ ] The real tables are untouched; `bash tests/run_tests.sh tripgraph postgres` still shows failed = 0.
- [ ] You can explain each of the 8 viva questions at the end of `decomposition_steps.md`.
