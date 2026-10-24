-- transactions/lost_update_fix.sql   (K)
-- Step 2 of the concurrency demo: put back the CORRECT version (locks the place row first).
-- Run from the repo root:
--   psql -U postgres -d tripgraph -f transactions/lost_update_fix.sql
--
-- The fix is the line  PERFORM 1 FROM place WHERE place_id = ... FOR NO KEY UPDATE;  in
-- triggers/01_review_rating.sql. The second session waits for the lock, and its NEXT
-- statement starts with a fresh snapshot that includes the first session's review.
-- (The other fix is SERIALIZABLE isolation: see transactions/README.md, part 3.)

\set ON_ERROR_STOP on
\i triggers/01_review_rating.sql
\echo 'FIXED (row lock) version of recompute_place_rating is now active.'
