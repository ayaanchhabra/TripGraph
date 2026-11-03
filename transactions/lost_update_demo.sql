-- transactions/lost_update_demo.sql
-- Step 1 of the concurrency demo: put in the BUGGY version of the rating helper.
-- It is the same as triggers/01_review_rating.sql but WITHOUT the row lock.
-- Run from the repo root:
--   psql -U postgres -d tripgraph -f transactions/lost_update_demo.sql
--
-- Then follow transactions/README.md to show the bug with two terminals,
-- or run:  python3 transactions/concurrent_reviews.py --place-id 1 --reviews 20

\set ON_ERROR_STOP on

CREATE OR REPLACE FUNCTION recompute_place_rating(p_place_id INT)
RETURNS VOID AS $$
BEGIN
  -- NAIVE: no lock. Each session counts the reviews IT can see, then writes that number.
  -- Two sessions reviewing the same place at the same time both count without seeing
  -- the other's (uncommitted) review, so the second write overwrites the first.
  UPDATE place
  SET review_count = (SELECT count(*)                           FROM review WHERE place_id = p_place_id),
      avg_rating   = (SELECT COALESCE(round(avg(rating), 2), 0) FROM review WHERE place_id = p_place_id)
  WHERE place_id = p_place_id;
END;
$$ LANGUAGE plpgsql;

\echo 'BUGGY (no lock) version of recompute_place_rating is now active.'
