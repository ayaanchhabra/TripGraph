-- tests/01_fixtures.sql   (K)
-- A tiny private map and some test rows (ids start at 900001 so they never clash with real data).
-- Everything is rolled back at the end of each test file.
--
--   TEST Gate (900001) --walk 2 min--> TEST Stand (900002) --e-rickshaw 8 min, Rs 10--> TEST Cafe Node (900003)
--   TEST Gate (900001) --walk 20 min, Rs 0------------------------------------------> TEST Cafe Node (900003)
--   plus two return edges (so the map has cycles), and TEST Island (900004) that nothing connects to.

INSERT INTO node (node_id, name, kind) VALUES
  (900001, 'TEST Gate',      'gate'),
  (900002, 'TEST Stand',     'erickshaw_stand'),
  (900003, 'TEST Cafe Node', 'place'),
  (900004, 'TEST Island',    'place');

INSERT INTO edge (edge_id, from_node, to_node, mode, distance_m, time_min, fare) VALUES
  (900001, 900001, 900002, 'walk',      150,   2,  0),
  (900002, 900002, 900003, 'erickshaw', 1200,  8, 10),
  (900003, 900001, 900003, 'walk',      1200, 20,  0),
  (900004, 900003, 900001, 'walk',      1200, 20,  0),
  (900005, 900002, 900001, 'walk',      150,   2,  0);

-- two places in the same category
INSERT INTO place (place_id, name, category_id, address, lat, lon, price_level, student_discount, node_id)
SELECT 900001, 'TEST Cafe',      min(category_id), 'test', 28.61, 77.03, 2, true,  900003 FROM category;
INSERT INTO place (place_id, name, category_id, address, lat, lon, price_level, student_discount, node_id)
SELECT 900002, 'TEST Night Cafe', min(category_id), 'test', 28.61, 77.03, 1, false, 900004 FROM category;

-- TEST Cafe: 09:00-22:00 every day.  TEST Night Cafe: 18:00-02:00 (after midnight) every day.
INSERT INTO opening_hours (place_id, day, open_time, close_time)
SELECT 900001, d, '09:00', '22:00' FROM generate_series(1, 7) d;
INSERT INTO opening_hours (place_id, day, open_time, close_time)
SELECT 900002, d, '18:00', '02:00' FROM generate_series(1, 7) d;

INSERT INTO tag (tag_id, name) VALUES (900001, 'test-tag');
INSERT INTO place_tag (place_id, tag_id) VALUES (900001, 900001);

INSERT INTO app_user (user_id, name, email) VALUES
  (900001, 'Test One',   't1@tripgraph.test'),
  (900002, 'Test Two',   't2@tripgraph.test'),
  (900003, 'Test Three', 't3@tripgraph.test');

INSERT INTO trip (trip_id, user_id) VALUES (900001, 900001);
