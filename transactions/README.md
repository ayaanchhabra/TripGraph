# Concurrency demo: the lost update 

**Idea:** two students review the same place at the same moment. The place's `review_count`
should go up by 2. With a bug it goes up by 1: one update is silently lost.

Files (run all commands from the repo root):

| File | What it does |
|---|---|
| `lost_update_demo.sql` | installs the BUGGY version of `recompute_place_rating` (no lock) |
| `lost_update_fix.sql` | installs the CORRECT version (locks the place row) |
| `concurrent_reviews.py` | many reviewers at once; reports CORRECT or LOST UPDATE |

Needs the schema, triggers and a loaded place (for example place 1 or 2). For the Python script: `pip install psycopg2-binary`.

---

## 1. Show the bug with two terminals (about 2 minutes)

**Terminal 0 (setup once):**
```sql
psql -U postgres -d tripgraph -f transactions/lost_update_demo.sql      -- buggy version on
psql -U postgres -d tripgraph
INSERT INTO app_user(user_id, name, email) VALUES (9001,'Demo One','d1@demo.test'),(9002,'Demo Two','d2@demo.test');
DELETE FROM review WHERE place_id = 2;
SELECT place_id, name, review_count FROM place WHERE place_id = 2;     -- review_count = 0
```

**Terminal 1 (student 1):**
```sql
BEGIN;
INSERT INTO review(user_id, place_id, rating) VALUES (9001, 2, 5);     -- do NOT commit yet
```

**Terminal 2 (student 2), straight after:**
```sql
BEGIN;
INSERT INTO review(user_id, place_id, rating) VALUES (9002, 2, 3);     -- appears to hang: waiting for terminal 1
```

**Terminal 1:** `COMMIT;`   **Terminal 2:** (it finishes now) `COMMIT;`

**Check (either terminal):**
```sql
SELECT count(*) AS real_reviews FROM review WHERE place_id = 2;        -- 2
SELECT review_count FROM place WHERE place_id = 2;                     -- 1  <-- LOST UPDATE
```

**Why:** both sessions counted the reviews they could see. Neither could see the other's uncommitted review,
so both computed a count without it. Session 2 waited for session 1's row lock, then wrote its stale number over it.

## 2. The same with many students at once
```bash
python3 transactions/concurrent_reviews.py --place-id 1 --reviews 20
```
Buggy version, 20 reviewers: "20 reviews exist but the place says 1."

## 3. Fix it

**Fix A: lock the row first (what our trigger does):**
```bash
psql -U postgres -d tripgraph -f transactions/lost_update_fix.sql
```
Repeat part 1 or 2: now `real_reviews` and `review_count` match. The second session waits for the lock,
and its next statement starts with a fresh snapshot that includes the first review.

Lock mode matters: `FOR NO KEY UPDATE`, not plain `FOR UPDATE`. Inserting a review already holds a light lock on
the place row (for the foreign-key check); asking for `FOR UPDATE` on top of it made concurrent reviewers
deadlock (we measured about 50 deadlocks in 45 seconds with 10 reviewers). `NO KEY UPDATE` does not conflict with that light lock.

**Fix B: stricter isolation level.** In both terminals use `BEGIN ISOLATION LEVEL SERIALIZABLE;`.
Instead of silently losing an update, PostgreSQL makes the second session fail with
`could not serialize access due to concurrent update`, and the application retries.
```bash
python3 transactions/concurrent_reviews.py --place-id 1 --reviews 20 --isolation serializable
```
Result: counts are correct even with the buggy version, but many transactions had to retry (about 200 for 20 reviewers).
Fix A avoids most of that waiting-and-retrying for a simple counter.

## Measured results (20 reviewers, same place)

| Trigger version | Isolation | Stored review_count | Correct? | Retries |
|---|---|---|---|---|
| buggy (no lock) | READ COMMITTED | 1 (should be 20) | NO: lost update | 0 |
| buggy (no lock) | SERIALIZABLE | 20 | yes | about 200 |
| fixed (lock) | READ COMMITTED | 20 | yes | 0 |
| fixed (lock) | SERIALIZABLE | 20 | yes | about 175 |

## Cleanup
```sql
DELETE FROM app_user WHERE user_id IN (9001, 9002);     -- also removes their reviews (trigger recounts)
```
and make sure the fixed version is installed (`lost_update_fix.sql`) before anyone uses the database normally.

---

# Schedule analysis (for the report and viva)

Notation: R1(X) = transaction 1 reads X, W1(X) = writes X, X = the place's review_count.

**1. The lost update is not serializable.**
Schedule: R1(X) R2(X) W1(X) W2(X) (both read the old value, both write).
Conflicts: R1(X) before W2(X) gives edge T1 -> T2. R2(X) before W1(X) gives edge T2 -> T1.
The precedence graph has a cycle (T1 -> T2 -> T1), so the schedule is **not conflict serializable**.
Neither serial order (T1 then T2, or T2 then T1) gives the same result, because in either serial order the
second transaction would see the first one's write.

**2. With the row lock it is serializable.**
T1: Lock-X(X) R1(X) W1(X) commit, unlock. T2 waits for Lock-X(X), then R2(X) W2(X) commit.
The effect is the serial schedule T1 then T2. This is **lock-based** (two-phase) concurrency control:
a transaction takes the lock, does its work, and releases at commit.

**3. Recoverable and cascadeless.**
- Not recoverable: W1(X) R2(X) commit2 abort1. T2 read T1's data and committed, but T1 then rolled back,
  so T2 committed on data that never existed.
- Recoverable but not cascadeless: W1(X) R2(X) abort1. T2 must also abort (a cascading rollback).
- Cascadeless: T2 reads X only after T1 commits.
PostgreSQL never lets a transaction read uncommitted data (no dirty reads), so every schedule it produces is cascadeless.

**4. Lock-based vs timestamp-based vs PostgreSQL.**
- Lock-based (2PL): transactions wait for locks, deadlocks are possible and must be detected (we saw this with plain `FOR UPDATE`).
- Timestamp-based: each transaction gets a timestamp and an operation that arrives "too late" is rejected and the
  transaction restarts. There are no waits and no deadlocks, but there are more restarts.
- PostgreSQL uses **MVCC**: readers see a snapshot and never block writers; writers lock only the rows they change.
  SERIALIZABLE adds checks (SSI) that abort a transaction when a non-serializable pattern appears, which is why
  Fix B throws serialization errors and needs retries.

---

# Concurrency demo: the deadlock

**Idea:** two transactions each hold a row lock the other one needs, so neither can ever continue.
PostgreSQL notices the circular wait and aborts one of them.

| File | What it does |
|---|---|
| `deadlock_demo.sh` | runs the whole demo automatically with two psql sessions |
| `deadlock_demo.sql` | the same demo as step-by-step instructions for two terminals |

Both use `UPDATE place SET name = name`, which takes the row lock but changes no data, and every session ends in ROLLBACK.

## Run it
```bash
bash transactions/deadlock_demo.sh tripgraph
```
Part 1 locks two places in opposite order (A: 1 then 2, B: 2 then 1). One session is aborted with
`ERROR: deadlock detected`. Part 2 locks them in the same order (lowest id first). Both sessions finish normally.

## Why it happens and how it is fixed
- Part 1 is a circular wait: A holds place 1 and wants place 2, B holds place 2 and wants place 1.
- PostgreSQL waits `deadlock_timeout` (1 second by default), finds the cycle in the waits-for graph and aborts one transaction.
- Fix: every transaction locks rows in the same global order. A circle of waits is then impossible.
- The same cause is behind the deadlocks we measured above with plain `FOR UPDATE` in the rating trigger: it asked for a stronger lock than the foreign-key check already held, so two reviewers waited on each other. `FOR NO KEY UPDATE` does not conflict with that lock.