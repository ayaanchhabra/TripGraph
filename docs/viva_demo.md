# TripGraph viva demo runbook

This runbook follows one rehearsable order and uses the SQL files and shell scripts already in the repository. Run commands from the repository root. The examples use the local PostgreSQL account `postgres`; replace it with the database account used on the demo machine when needed.

## Before the viva

1. Start PostgreSQL and open PowerShell in the project folder.
2. Put PostgreSQL's `bin` folder on the PowerShell path so `psql` is available:

   ```powershell
   $env:Path = "C:\Program Files\PostgreSQL\16\bin;$env:Path"
   ```

3. If repeated password prompts are inconvenient, set `PGPASSWORD` for this PowerShell session only. The password is not saved in the repository. Clear it after the rehearsal with `Remove-Item Env:PGPASSWORD`.
4. Make sure the main TripGraph database exists and its test suite passes. If `tripgraph` already exists, do **not** run the setup script again; just run the tests:

   ```powershell
   & "C:\Program Files\Git\bin\bash.exe" tests/run_tests.sh tripgraph postgres
   ```

   Only if the database does not exist yet, create it with:

   ```powershell
   & "C:\Program Files\Git\bin\bash.exe" scripts/setup_db.sh tripgraph postgres
   ```

   The setup script refuses to overwrite an existing database. Do not add `--reset` to the main viva database merely to rehearse.

5. Have two PowerShell windows ready for the concurrency demonstration. Keep the project folder as the working directory in both.

**Output note:** query rows and `EXPLAIN ANALYZE` timings depend on the data and the machine. Do not memorise timings copied from another computer. During the local rehearsal, record the actual scan node and `Execution Time` printed by `indexing/viva_demo.sql`; this runbook does not invent a transcript for a database session it has not run.

---

## 1. ER model and normalization to BCNF

**Command / action**

Open the ER diagram:

```powershell
Start-Process .\docs\er_diagram\tripgraph_er.png
```

Run the denormalized example and then build the normalized demonstration schema:

```powershell
psql -U postgres -d tripgraph -v ON_ERROR_STOP=1 -f normalization/messy_table.sql
psql -U postgres -d tripgraph -v ON_ERROR_STOP=1 -f normalization/normalized_tables.sql
```

**Say**

"The ER diagram shows the entities and their relationships. The messy table deliberately combines place, category, node, tags, opening hours, reviews and transport edges. Repeating tag values and copied facts create update, insert and delete anomalies. We first make values atomic, then remove partial and transitive dependencies, and finish with BCNF tables in a separate `norm_demo` schema so the demonstration does not collide with the real application schema."

**The examiner should see**

The ER diagram; the 12-row `tripgraph_messy` example; the three anomaly demonstrations; and the normalized tables created under `norm_demo`. The anomaly demonstrations use transactions or controlled exception handling so they do not leave the messy example damaged.

## 2. Cheapest route

The sample place with ID 3 is the study cafe. Ask for a route from the default `NSUT Main Gate`, starting at 12:00 on the current date:

```powershell
psql -U postgres -d tripgraph -c "SELECT * FROM cheapest_route(3, (CURRENT_DATE + TIME '12:00'));"
```

**Say**

"`cheapest_route` uses a recursive CTE. It extends a path one edge at a time, tracks total fare and time, avoids revisiting nodes, and stops when the fare or leg limit is reached. It then checks whether the destination is open at the arrival time and returns the chosen path as ordered legs."

**The examiner should see**

A result table with one row per route leg and the from/to stop, transport mode, distance, time, fare and running totals. If no route is returned, check the place ID, map connectivity and opening hours before the viva; do not change the function during the demo.

## 3. Same query without and with indexes

The benchmark query uses the separate `bench` schema, not the 12 real sample places. Generate that benchmark data once before the live comparison:

```powershell
psql -U postgres -d tripgraph -v ON_ERROR_STOP=1 -f data/generate_bulk.sql
```

Then run the existing demonstration:

```powershell
psql -U postgres -d tripgraph -v ON_ERROR_STOP=1 -f indexing/viva_demo.sql
```

**Say**

"The first plan runs without the benchmark indexes. The next plan runs after the composite B-tree index is created. The script also compares the top-rated query with and without the partial index. `EXPLAIN ANALYZE` executes the query, so it reports the actual plan, row counts, buffers and execution time. The planner can still choose a sequential scan when it estimates that reading many rows is cheaper."

**The examiner should see**

The `EXPLAIN ANALYZE, BUFFERS` plans printed by the script. Point out the scan node and index name in each plan, then compare the actual `Execution Time` lines from this machine. The script drops its benchmark indexes again at the end. Timings vary; record the values from the rehearsal machine rather than putting fixed numbers in the presentation.

## 4. Invalid review and trip-leg inserts

Run the existing negative-demo script after the sample data has been loaded:

```powershell
psql -U postgres -d tripgraph -f data/sample_data/demo_invalid_inserts.sql
```

**Say**

"These statements are intentionally invalid. The primary key prevents a user from reviewing the same place twice, the rating CHECK constraint rejects a value outside 1 to 5, and the trip-leg trigger rejects a leg that does not start where the previous leg ended. Each example is wrapped in a transaction and rolled back."

**The examiner should see**

Three PostgreSQL error messages: duplicate-key violation, CHECK-constraint violation, and the trip-leg continuity trigger rejection. The script continues after those expected errors and finishes with a trip-count check. These errors are the point of this negative test; they are not a reason to stop the demo.

## 5. Lost update, corrected trigger, and deadlock

Use a **separate disposable database** for this section because the lost-update example deletes reviews for place 2. It must not be run against the database containing the team's main demo data.

Create the disposable database once:

```powershell
& "C:\Program Files\Git\bin\bash.exe" scripts/setup_db.sh tripgraph_viva postgres
```

If `tripgraph_viva` already exists and you intend to rebuild this disposable database, use `scripts/setup_db.sh tripgraph_viva postgres --reset` only for `tripgraph_viva`, never for the main `tripgraph` database.

Install the deliberately buggy version of the rating helper:

```powershell
psql -U postgres -d tripgraph_viva -v ON_ERROR_STOP=1 -f transactions/lost_update_demo.sql
```

In a third terminal (setup terminal), connect and prepare the two demo users and the target place:

```powershell
psql -U postgres -d tripgraph_viva
```

At the `psql` prompt:

```sql
INSERT INTO app_user (user_id, name, email)
VALUES (9001, 'Demo One', 'd1@demo.test'),
       (9002, 'Demo Two', 'd2@demo.test');
DELETE FROM review WHERE place_id = 2;
SELECT place_id, name, review_count FROM place WHERE place_id = 2;
```

Open two more `psql` terminals connected to `tripgraph_viva`.

**Terminal A** (do not commit yet):

```sql
BEGIN;
INSERT INTO review (user_id, place_id, rating) VALUES (9001, 2, 5);
```

**Terminal B**, immediately after Terminal A's insert:

```sql
BEGIN;
INSERT INTO review (user_id, place_id, rating) VALUES (9002, 2, 3);
```

Terminal B waits. Commit Terminal A first:

```sql
COMMIT;
```

The insert in Terminal B then completes; commit Terminal B:

```sql
COMMIT;
```

Check in either terminal:

```sql
SELECT count(*) AS real_reviews FROM review WHERE place_id = 2;
SELECT review_count FROM place WHERE place_id = 2;
```

**Say**

"Both transactions counted reviews from snapshots that did not include the other's uncommitted row. The second update overwrote the correct count with a stale count. Two reviews exist, but the stored count is one: a lost update."

Now install the fix:

```powershell
psql -U postgres -d tripgraph_viva -v ON_ERROR_STOP=1 -f transactions/lost_update_fix.sql
```

Repeat the preparation and two-terminal sequence: first delete the two demo reviews from place 2, run the two inserts concurrently, and commit A then B. Check the same two queries. With the row-locking trigger restored, the stored `review_count` should match the two committed review rows.

Run the repository's deadlock demonstration on the same disposable database:

```powershell
& "C:\Program Files\Git\bin\bash.exe" transactions/deadlock_demo.sh tripgraph_viva postgres
```

**Say**

"In part one, the sessions lock the same two places in opposite order, creating a circular wait. PostgreSQL detects the deadlock and aborts one transaction. In part two, both sessions lock rows in the same order, so one waits for the other but there is no cycle. The script rolls back its updates, so it does not change the place names."

**The examiner should see**

For the lost update, two real review rows but a stale count in the buggy version, followed by matching counts after the fix. For the deadlock, one session aborted in the opposite-order case and both sessions finish in the consistent-order case.

Clean up the disposable demo users after the demonstrations:

```sql
DELETE FROM app_user WHERE user_id IN (9001, 9002);
```

Keep the fixed trigger installed. The disposable database can be dropped later if it is no longer needed.

## 6. Optional recovery demonstration: backend termination and transaction outcome

The supplied recovery scripts create a committed row and an uncommitted row, then allow the uncommitted session's backend to be terminated. This safely demonstrates that the committed row remains and the open transaction is rolled back. It does **not** stop the PostgreSQL server process, so do not describe this script as a full PostgreSQL server crash/restart or claim that it proves startup-time WAL redo.

Prepare the demo table:

```powershell
psql -U postgres -d tripgraph_viva -v ON_ERROR_STOP=1 -f recovery/01_setup.sql
```

In an interactive `psql` session, run the second file and leave the session open:

```powershell
psql -U postgres -d tripgraph_viva
```

At the prompt:

```sql
\i recovery/02_uncommitted_then_wait.sql
```

Record the printed `kill_this_pid`. In another PowerShell window, terminate that backend:

```powershell
taskkill /F /PID <kill_this_pid>
```

Verify from another connection:

```powershell
psql -U postgres -d tripgraph_viva -f recovery/03_verify.sql
```

**The examiner should see** the committed row and not the uncommitted row. Explain that a full instance-crash/WAL-redo demonstration would need a controlled PostgreSQL server shutdown/crash and inspection of the server startup log; the current backend-kill script is not that demonstration.

## 7. Roles: student blocked, admin allowed

Run the role tests as the database owner or superuser:

```powershell
psql -U postgres -d tripgraph -v ON_ERROR_STOP=1 -f security/03_test_roles.sql
```

**Say**

"The student role can read the permitted tables and views and perform the limited writes it was granted. It cannot insert or modify places directly or read the audit log. The admin inherits the student rights and receives additional management rights. These tests use `SET LOCAL ROLE` and roll back their test data."

**The examiner should see**

The role test table with PASS statuses for expected allowed and denied operations, followed by passed/failed/skipped counts. Point out a denied student place write and audit-log read, and an allowed admin place write and audit-log read.

---

## Bonus demonstrations

Run these after the ordered seven steps if time permits. They use existing project files and objects.

**Audit trigger**

Reinstall the trigger definition, then show a temporary place update and its audit row inside a transaction:

```powershell
psql -U postgres -d tripgraph -v ON_ERROR_STOP=1 -f triggers/03_audit_log.sql
psql -U postgres -d tripgraph -c "BEGIN; UPDATE place SET name = name || ' [audit demo]' WHERE place_id = 3; SELECT log_id, action, table_name, record_id, logged_at FROM audit_log ORDER BY log_id DESC LIMIT 3; ROLLBACK;"
```

The trigger writes the audit row in the same transaction; the final rollback removes both the temporary name change and its audit row.

**Similar places**

```powershell
psql -U postgres -d tripgraph -c "SELECT * FROM similar_places(1, 5);"
```

Point out that results stay in the same category, are within one price level, exclude the target place, and sort by price difference then rating and review count.

**Favorites and visited history**

```powershell
psql -U postgres -d tripgraph -v ON_ERROR_STOP=1 -f user_features/favorites.sql
```

The file saves a favorite, marks it visited, lists favorites and visited places, shows popular places and open favorites, then removes the favorite it added. The default sample user and place are documented at the top of the SQL file.

**Full-text and tag search**

```powershell
psql -U postgres -d tripgraph -c "SELECT * FROM search_places('veg cafe', 10);"
psql -U postgres -d tripgraph -c "SELECT * FROM places_with_tags(ARRAY['veg','wifi']);"
```

Explain that the first function ranks matches over place names and tags; the second returns places having all requested exact tags.

**Trending places**

```powershell
psql -U postgres -d tripgraph -c "SELECT * FROM trending_this_month ORDER BY rank, name;"
```

Explain that the view counts reviews from the last 30 days and ranks by recent count, then recent average rating.

## If something goes wrong

- If the database does not exist, run the normal setup command once: `scripts/setup_db.sh tripgraph postgres`.
- If the main database is damaged and you intentionally want to rebuild it, first create a fresh `pg_dump` backup. Only then use `scripts/setup_db.sh tripgraph postgres --reset`. This drops and recreates the database.
- For the lost-update section, rebuild only the disposable `tripgraph_viva` database. Do not use the buggy trigger demo on the main `tripgraph` database.
- If a demo returns no route, check that the sample data, map, and opening hours were loaded and that the chosen destination is open at the demonstration time.
- If the index plan differs, record the actual plan. Planner choices and execution times depend on statistics, cache state, PostgreSQL version and machine resources; do not edit the query just to force a desired-looking plan.
- After a demonstration that temporarily changed functions, make sure `transactions/lost_update_fix.sql` has been run on the disposable database.

## Local rehearsal record

Fill this section from the actual console output on the viva machine. Do not copy timing values from another machine.

| Item | Actual result recorded during rehearsal |
|---|---|
| `cheapest_route(3, ...)` | ______________________________ |
| Index demo, without index: scan node / Execution Time | ______________________________ |
| Index demo, with index: scan node / Execution Time | ______________________________ |
| Invalid review and trip-leg inserts | ______________________________ |
| Lost update before fix: real count / stored count | ______________________________ |
| Lost update after fix: real count / stored count | ______________________________ |
| Deadlock demo: opposite order / same order | ______________________________ |
| Role tests: passed / failed / skipped | ______________________________ |
