-- triggers/02_trip_leg_continuity.sql   (K)
-- A trip is a chain of legs. Rule: leg n must END where leg n+1 STARTS.
--   leg 1 can start anywhere; legs must be numbered 1, 2, 3 ... with no gaps.
-- Run after schema/*.sql.

\set ON_ERROR_STOP on

CREATE OR REPLACE FUNCTION trg_trip_leg_continuity()
RETURNS TRIGGER AS $$
DECLARE
  this_from INT;
  this_to   INT;
  prev_to   INT;
  next_from INT;
BEGIN
  SELECT from_node, to_node INTO this_from, this_to FROM edge WHERE edge_id = NEW.edge_id;

  -- Check against the previous leg
  IF NEW.leg_no > 1 THEN
    SELECT e.to_node INTO prev_to
    FROM trip_leg l JOIN edge e ON e.edge_id = l.edge_id
    WHERE l.trip_id = NEW.trip_id AND l.leg_no = NEW.leg_no - 1;

    IF prev_to IS NULL THEN
      RAISE EXCEPTION 'Trip % has no leg % - legs must be added in order without gaps',
        NEW.trip_id, NEW.leg_no - 1;
    END IF;
    IF prev_to <> this_from THEN
      RAISE EXCEPTION 'Trip % leg % starts at node % but leg % ended at node %',
        NEW.trip_id, NEW.leg_no, this_from, NEW.leg_no - 1, prev_to;
    END IF;
  END IF;

  -- Check against the next leg (matters when a leg is edited or inserted in the middle)
  SELECT e.from_node INTO next_from
  FROM trip_leg l JOIN edge e ON e.edge_id = l.edge_id
  WHERE l.trip_id = NEW.trip_id AND l.leg_no = NEW.leg_no + 1;

  IF next_from IS NOT NULL AND next_from <> this_to THEN
    RAISE EXCEPTION 'Trip % leg % ends at node % but leg % starts at node %',
      NEW.trip_id, NEW.leg_no, this_to, NEW.leg_no + 1, next_from;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trip_leg_continuity ON trip_leg;
CREATE TRIGGER trip_leg_continuity
BEFORE INSERT OR UPDATE ON trip_leg
FOR EACH ROW EXECUTE FUNCTION trg_trip_leg_continuity();
