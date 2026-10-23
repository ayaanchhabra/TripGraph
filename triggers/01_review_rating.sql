-- triggers/01_review_rating.sql   (K)
-- Keeps place.avg_rating and place.review_count in sync with the review table.
-- avg_rating is deliberately DENORMALIZED (stored on place) so "top rated" queries
-- do not have to average every review each time. The trigger is what keeps it correct.
-- Run after schema/*.sql.

\set ON_ERROR_STOP on

-- Helper: recompute one place from its reviews.
CREATE OR REPLACE FUNCTION recompute_place_rating(p_place_id INT)
RETURNS VOID AS $$
BEGIN
  -- Lock the place row first. If two people review the same place at the same
  -- time, the second one waits here until the first commits, and then counts
  -- again with a fresh view of the data. Without this lock both could compute
  -- the same stale count (a "lost update").
  PERFORM 1 FROM place WHERE place_id = p_place_id FOR UPDATE;

  UPDATE place
  SET review_count = (SELECT count(*)                      FROM review WHERE place_id = p_place_id),
      avg_rating   = (SELECT COALESCE(round(avg(rating), 2), 0) FROM review WHERE place_id = p_place_id)
  WHERE place_id = p_place_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION trg_review_rating()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP IN ('INSERT', 'UPDATE') THEN
    PERFORM recompute_place_rating(NEW.place_id);
  END IF;
  -- On DELETE, or when a review is moved to a different place, the OLD place changes too.
  IF TG_OP = 'DELETE' OR (TG_OP = 'UPDATE' AND OLD.place_id <> NEW.place_id) THEN
    PERFORM recompute_place_rating(OLD.place_id);
  END IF;
  RETURN NULL;  -- AFTER trigger: return value is ignored
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS review_rating ON review;
CREATE TRIGGER review_rating
AFTER INSERT OR UPDATE OR DELETE ON review
FOR EACH ROW EXECUTE FUNCTION trg_review_rating();
