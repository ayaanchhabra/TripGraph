-- queries/views/02_open_now.sql   (K)
-- is_open_at(place, time): is the place open at that moment?
-- open_now: all places open right now (Indian time).
--
-- Rules for opening_hours rows (day is ISO: 1 = Monday ... 7 = Sunday):
--   open_time <  close_time : open between the two times on that day
--   open_time >  close_time : closes AFTER MIDNIGHT (e.g. 18:00 -> 02:00). The row belongs
--                             to the day it opens; the after-midnight part counts as the next morning
--   open_time =  close_time : open 24 hours that day
--   no row for that day     : treated as closed
--
-- Examples:
--   SELECT * FROM open_now WHERE is_veg AND price_level <= 2;
--   SELECT is_open_at(1, TIMESTAMP '2026-10-23 21:00');   -- usable for arrival-time checks

\set ON_ERROR_STOP on

CREATE OR REPLACE FUNCTION is_open_at(p_place_id INT, p_ts TIMESTAMP)
RETURNS BOOLEAN
LANGUAGE sql STABLE AS $$
  SELECT EXISTS (
    SELECT 1
    FROM opening_hours h
    WHERE h.place_id = p_place_id
      AND (
            -- today's row
            ( h.day = EXTRACT(ISODOW FROM p_ts)::int
              AND ( h.open_time = h.close_time
                    OR (h.open_time < h.close_time AND p_ts::time >= h.open_time AND p_ts::time < h.close_time)
                    OR (h.open_time > h.close_time AND p_ts::time >= h.open_time) ) )
         OR
            -- yesterday's row that runs past midnight into today
            ( h.day = EXTRACT(ISODOW FROM p_ts - INTERVAL '1 day')::int
              AND h.open_time > h.close_time
              AND p_ts::time < h.close_time )
          )
  );
$$;

CREATE OR REPLACE VIEW open_now AS
SELECT p.place_id,
       p.name,
       c.name        AS category,
       c.group_name,
       f.cuisine,
       f.is_veg,
       p.price_level,
       p.student_discount,
       p.avg_rating,
       p.review_count,
       p.node_id
FROM place p
JOIN category c         ON c.category_id = p.category_id
LEFT JOIN food_outlet f ON f.place_id    = p.place_id
WHERE is_open_at(p.place_id, now() AT TIME ZONE 'Asia/Kolkata');
