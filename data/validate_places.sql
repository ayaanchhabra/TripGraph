-- data/validate_places.sql   (A)
-- Sanity checks after load_places.sql. Run from the repo root:
--   psql -U postgres -d tripgraph -f data/validate_places.sql
-- "expect 0 rows" checks should be empty; "info" checks are for you to eyeball.

\echo '1. Row counts (info)'
SELECT (SELECT count(*) FROM place)         AS places,
       (SELECT count(*) FROM food_outlet)   AS food_outlets,
       (SELECT count(*) FROM tag)           AS tags,
       (SELECT count(*) FROM place_tag)     AS place_tags,
       (SELECT count(*) FROM opening_hours) AS hour_rows;

\echo '2. Places with no node (expect 0 rows)'
SELECT place_id, name FROM place WHERE node_id IS NULL;

\echo '3. Places attached to a node whose kind is not place (expect 0 rows, or a deliberate exception)'
SELECT p.place_id, p.name, n.name AS node_name, n.kind
FROM place p JOIN node n ON n.node_id = p.node_id
WHERE n.kind <> 'place';

\echo '4. Place-kind nodes that no place uses (expect 0 rows; orphaned map nodes)'
SELECT n.node_id, n.name FROM node n
WHERE n.kind = 'place'
  AND NOT EXISTS (SELECT 1 FROM place p WHERE p.node_id = n.node_id);

\echo '5. Places whose node is NOT reachable from NSUT Main Gate (expect 0 rows)'
WITH RECURSIVE reach(node_id) AS (
  SELECT node_id FROM node WHERE name = 'NSUT Main Gate'
  UNION
  SELECT e.to_node FROM reach r JOIN edge e ON e.from_node = r.node_id
)
SELECT p.place_id, p.name FROM place p
WHERE p.node_id NOT IN (SELECT node_id FROM reach);

\echo '6. Categories with no place (expect 0 rows for the sample load)'
SELECT c.category_id, c.name FROM category c
WHERE NOT EXISTS (SELECT 1 FROM place p WHERE p.category_id = c.category_id)
ORDER BY c.category_id;

\echo '7. Places with no opening hours (expect 0 rows)'
SELECT p.place_id, p.name FROM place p
WHERE NOT EXISTS (SELECT 1 FROM opening_hours h WHERE h.place_id = p.place_id);

\echo '8. Places with no tags (expect 0 rows)'
SELECT p.place_id, p.name FROM place p
WHERE NOT EXISTS (SELECT 1 FROM place_tag t WHERE t.place_id = p.place_id);

\echo '9. Food and drink places with no food_outlet row (expect 0 rows)'
SELECT p.place_id, p.name FROM place p
JOIN category c ON c.category_id = p.category_id
WHERE c.group_name = 'Food and drink'
  AND NOT EXISTS (SELECT 1 FROM food_outlet f WHERE f.place_id = p.place_id);

\echo '10. Non-food places that DO have a food_outlet row (expect 0 rows)'
SELECT p.place_id, p.name FROM place p
JOIN category c ON c.category_id = p.category_id
JOIN food_outlet f ON f.place_id = p.place_id
WHERE c.group_name <> 'Food and drink';

\echo '11. Duplicate name + address (expect 0 rows)'
SELECT name, address, count(*) FROM place GROUP BY name, address HAVING count(*) > 1;

\echo '12. Coordinates outside a rough Dwarka box (expect 0 rows)'
SELECT place_id, name, lat, lon FROM place
WHERE lat NOT BETWEEN 28.58 AND 28.64 OR lon NOT BETWEEN 77.00 AND 77.08;

\echo '13. Hours where close_time <= open_time, i.e. open past midnight (info)'
SELECT h.place_id, p.name, h.day, h.open_time, h.close_time
FROM opening_hours h JOIN place p USING (place_id)
WHERE h.close_time <= h.open_time
ORDER BY h.place_id, h.day;

\echo '14. Places per category (info)'
SELECT c.group_name, c.name, count(p.place_id) AS places
FROM category c LEFT JOIN place p ON p.category_id = c.category_id
GROUP BY c.group_name, c.name, c.category_id ORDER BY c.category_id;

\echo '15. Places per map node (info; shows which nodes are shared)'
SELECT n.node_id, n.name, count(p.place_id) AS places
FROM node n LEFT JOIN place p ON p.node_id = n.node_id
WHERE n.kind = 'place' GROUP BY n.node_id, n.name ORDER BY n.node_id;
