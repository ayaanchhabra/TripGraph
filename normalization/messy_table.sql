-- normalization/messy_table.sql
-- Purpose : Build ONE badly designed (denormalized) table, tripgraph_messy, from the
--           example TripGraph data, and show the three classic anomalies on it
--           (update, insert, delete). This is the starting point of the
--           normalization chapter: functional_dependencies.md and
--           decomposition_steps.md explain how to fix it, and normalized_tables.sql
--           builds the fixed design.
-- Needs   : nothing. It does not read or change any real TripGraph table.
-- Run     : psql -U postgres -d tripgraph -v ON_ERROR_STOP=1 -f normalization/messy_table.sql
-- Re-run  : safe. The table is dropped and rebuilt, and every anomaly demo runs inside a
--           transaction that is rolled back, so the 12 rows are never damaged.
--
-- Where the data comes from: places, categories, tags, opening hours and map nodes/edges
-- are the example values (places 2, 3, 4, 5, 6, 11, 12). The four students and their
-- ratings are made up for this demo (example.com emails), because no review data is
-- needed to explain normalization.

DROP TABLE IF EXISTS tripgraph_messy CASCADE;

-- One row = one place, together with ONE opening-hours day, ONE review and ONE
-- transport edge (an edge that leaves the place's own map node). A careless export
-- glued all of that into a single table. Problems you can see:
--   * tags is a comma list: a repeating group (not even 1NF).
--   * place, category, node and student facts are copied into every row.
--   * the primary key has to be (place_id, day, user_id, edge_id) just to keep rows apart.
CREATE TABLE tripgraph_messy (
  -- place facts
  place_id         INT           NOT NULL,
  place_name       TEXT          NOT NULL,
  category_id      INT           NOT NULL,
  category_name    TEXT          NOT NULL,
  group_name       TEXT          NOT NULL,   -- depends on the category, not on the place
  address          TEXT,
  price_level      SMALLINT      NOT NULL,
  student_discount BOOLEAN       NOT NULL,
  node_id          INT           NOT NULL,   -- the map node the place is reached from
  node_name        TEXT          NOT NULL,
  node_kind        TEXT          NOT NULL,
  cuisine          TEXT,                     -- only food places have a value
  is_veg           BOOLEAN,                  -- only food places have a value
  tags             TEXT          NOT NULL,   -- REPEATING GROUP: 'veg, wifi, coffee'
  -- opening hours (one day per row)
  day              SMALLINT      NOT NULL,   -- ISO: 1 = Monday ... 7 = Sunday
  open_time        TIME          NOT NULL,
  close_time       TIME          NOT NULL,   -- smaller than open_time means after midnight
  -- review (one student per row)
  user_id          INT           NOT NULL,
  user_name        TEXT          NOT NULL,
  user_email       TEXT          NOT NULL,
  rating           SMALLINT      NOT NULL,
  -- transport option (one edge leaving the place's node per row)
  edge_id          INT           NOT NULL,
  mode             TEXT          NOT NULL,
  distance_m       INT           NOT NULL,
  time_min         INT           NOT NULL,
  fare             NUMERIC(6,2)  NOT NULL,
  to_node_id       INT           NOT NULL,   -- where the edge leads
  to_node_name     TEXT          NOT NULL,
  to_node_kind     TEXT          NOT NULL,
  PRIMARY KEY (place_id, day, user_id, edge_id),
  UNIQUE (place_id, day, user_email, edge_id)   -- second candidate key: email also identifies a student
);

INSERT INTO tripgraph_messy VALUES
  (3, 'Sample Study Cafe', 3, 'Cafes', 'Food and drink', 'Sector 3 market, Dwarka', 2, true, 8, 'Cafe X', 'place', 'Cafe', true, 'veg, wifi, coffee, late-night', 1, '10:00', '01:00', 1, 'Riya Verma', 'riya.v@example.com', 5, 19, 'walk', 400, 5, 0.00, 1, 'NSUT Main Gate', 'gate'),
  (3, 'Sample Study Cafe', 3, 'Cafes', 'Food and drink', 'Sector 3 market, Dwarka', 2, true, 8, 'Cafe X', 'place', 'Cafe', true, 'veg, wifi, coffee, late-night', 6, '10:00', '01:00', 2, 'Aman Gupta', 'aman.g@example.com', 4, 19, 'walk', 400, 5, 0.00, 1, 'NSUT Main Gate', 'gate'),
  (3, 'Sample Study Cafe', 3, 'Cafes', 'Food and drink', 'Sector 3 market, Dwarka', 2, true, 8, 'Cafe X', 'place', 'Cafe', true, 'veg, wifi, coffee, late-night', 7, '10:00', '01:00', 3, 'Neha Singh', 'neha.s@example.com', 5, 19, 'walk', 400, 5, 0.00, 1, 'NSUT Main Gate', 'gate'),
  (2, 'Sample Chaat Stall', 2, 'Street food and chaat', 'Food and drink', 'Outside NSUT main gate', 1, true, 11, 'Chaat Corner', 'place', 'Chaat', true, 'veg, chaat, cheap', 1, '16:00', '22:00', 1, 'Riya Verma', 'riya.v@example.com', 4, 21, 'walk', 500, 7, 0.00, 1, 'NSUT Main Gate', 'gate'),
  (2, 'Sample Chaat Stall', 2, 'Street food and chaat', 'Food and drink', 'Outside NSUT main gate', 1, true, 11, 'Chaat Corner', 'place', 'Chaat', true, 'veg, chaat, cheap', 4, '16:00', '22:00', 4, 'Karan Mehta', 'karan.m@example.com', 3, 21, 'walk', 500, 7, 0.00, 1, 'NSUT Main Gate', 'gate'),
  (4, 'Sample Chai Point', 5, 'Juice, shakes and chai points', 'Food and drink', 'Market chowk, Dwarka', 1, false, 6, 'Market Chowk E-Rickshaw Stand', 'erickshaw_stand', 'Chai', true, 'chai, veg, cheap', 2, '07:00', '21:00', 2, 'Aman Gupta', 'aman.g@example.com', 5, 22, 'erickshaw', 1200, 8, 10.00, 3, 'Main Gate E-Rickshaw Stand', 'erickshaw_stand'),
  (4, 'Sample Chai Point', 5, 'Juice, shakes and chai points', 'Food and drink', 'Market chowk, Dwarka', 1, false, 6, 'Market Chowk E-Rickshaw Stand', 'erickshaw_stand', 'Chai', true, 'chai, veg, cheap', 2, '07:00', '21:00', 2, 'Aman Gupta', 'aman.g@example.com', 5, 23, 'walk', 1200, 16, 0.00, 1, 'NSUT Main Gate', 'gate'),
  (5, 'Sample Xerox and Printing', 7, 'Stationery and photocopy/printing', 'Study and work', 'Opposite NSUT gate', 1, true, 10, 'Stationery and Photocopy Shop', 'place', NULL, NULL, 'printing, photocopy, cheap', 3, '09:00', '20:00', 3, 'Neha Singh', 'neha.s@example.com', 4, 20, 'walk', 250, 4, 0.00, 1, 'NSUT Main Gate', 'gate'),
  (6, 'Sample Book Corner', 8, 'Books and second-hand books', 'Study and work', 'Sector 3 market, Dwarka', 1, true, 10, 'Stationery and Photocopy Shop', 'place', NULL, NULL, 'second-hand, cheap', 3, '10:00', '20:00', 1, 'Riya Verma', 'riya.v@example.com', 5, 20, 'walk', 250, 4, 0.00, 1, 'NSUT Main Gate', 'gate'),
  (11, 'Sample Gaming Zone', 20, 'Gaming zones and cyber cafes', 'Hangouts', 'Mall, Dwarka', 2, true, 15, 'Mall', 'place', NULL, NULL, 'hangout', 1, '11:00', '23:00', 4, 'Karan Mehta', 'karan.m@example.com', 4, 31, 'walk', 400, 5, 0.00, 7, 'Metro Station B', 'metro'),
  (12, 'Sample Movie Hall', 21, 'Malls and movie halls', 'Hangouts', 'Mall, Dwarka', 3, false, 15, 'Mall', 'place', NULL, NULL, 'movies, hangout, late-night', 7, '10:00', '01:00', 4, 'Karan Mehta', 'karan.m@example.com', 5, 31, 'walk', 400, 5, 0.00, 7, 'Metro Station B', 'metro'),
  (12, 'Sample Movie Hall', 21, 'Malls and movie halls', 'Hangouts', 'Mall, Dwarka', 3, false, 15, 'Mall', 'place', NULL, NULL, 'movies, hangout, late-night', 5, '10:00', '01:00', 1, 'Riya Verma', 'riya.v@example.com', 3, 31, 'walk', 400, 5, 0.00, 7, 'Metro Station B', 'metro');

\echo
\echo === The messy table: 12 rows, place facts repeated again and again ===
SELECT place_id, place_name, category_name, node_name, day, user_id, rating, edge_id, mode
FROM tripgraph_messy
ORDER BY place_id, day, user_id, edge_id;

-- ---------------------------------------------------------------------------
-- ANOMALY 1: UPDATE anomaly
-- Place 3 appears in 3 rows. Its address is stored 3 times. If the update touches
-- only some of the rows (a typical mistake), the table now disagrees with itself.
-- ---------------------------------------------------------------------------
\echo
\echo === UPDATE anomaly: change the address of place 3 in only one of its rows ===
BEGIN;

UPDATE tripgraph_messy
SET address = 'Sector 3 market, Dwarka (next to the gate)'
WHERE place_id = 3 AND day = 1;

-- Expect TWO different addresses for the same place (2 rows and 1 row).
SELECT place_id, address, count(*) AS rows_with_this_address
FROM tripgraph_messy
WHERE place_id = 3
GROUP BY place_id, address
ORDER BY address;

ROLLBACK;   -- undo, so the demo can be repeated

-- ---------------------------------------------------------------------------
-- ANOMALY 2: INSERT anomaly
-- A new place (or a new category) cannot be stored until it already has an
-- opening-hours day, a review AND a transport edge, because those columns are part of
-- the primary key and cannot be NULL. Facts about a place should not need a review.
-- ---------------------------------------------------------------------------
\echo
\echo === INSERT anomaly: add a new place that has no review yet ===
DO $$
BEGIN
  INSERT INTO tripgraph_messy
    (place_id, place_name, category_id, category_name, group_name, address,
     price_level, student_discount, node_id, node_name, node_kind, tags)
  VALUES
    (13, 'Sample Laundry', 12, 'Laundry and ironing', 'Essentials', 'Sector 3, Dwarka',
     1, false, 12, 'Grocery Store', 'place', 'laundry');
  RAISE NOTICE 'The insert worked (this should not happen).';
EXCEPTION WHEN not_null_violation THEN
  RAISE NOTICE 'INSERT ANOMALY: the new place was refused because day, user_id, edge_id ... cannot be NULL.';
  RAISE NOTICE 'The category "Laundry and ironing" cannot be stored either, until some review exists.';
END $$;

SELECT count(*) AS rows_for_place_13 FROM tripgraph_messy WHERE place_id = 13;   -- 0

-- ---------------------------------------------------------------------------
-- ANOMALY 3: DELETE anomaly
-- Place 6 appears in exactly ONE row (one review). If that student deletes the review,
-- the row goes, and with it the place, its price, its address AND the category
-- "Books and second-hand books" (no other place has that category).
-- ---------------------------------------------------------------------------
\echo
\echo === DELETE anomaly: remove the only review of place 6 ===
BEGIN;

DELETE FROM tripgraph_messy WHERE place_id = 6 AND user_id = 1;

SELECT count(*) AS rows_for_place_6      FROM tripgraph_messy WHERE place_id = 6;      -- 0: the place is gone
SELECT count(*) AS rows_for_category_8   FROM tripgraph_messy WHERE category_id = 8;   -- 0: the category is gone

ROLLBACK;   -- undo

\echo
\echo Done. The table still has its 12 rows:
SELECT count(*) AS rows_in_tripgraph_messy FROM tripgraph_messy;   -- 12
