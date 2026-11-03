-- queries/relational_algebra/relational_algebra.sql
-- Six relational algebra queries with their SQL equivalents, plus one tuple relational
-- calculus (TRC) query. The algebra and explanations are in relational_algebra.md; this
-- file is the runnable SQL. Run from the repo root:
--   psql -U postgres -d tripgraph -f queries/relational_algebra/relational_algebra.sql
-- Table and column names are exactly those of the TABLES section (the project schema).

\echo '--- RA1: veg food outlets (select + join + project) ---'
SELECT DISTINCT p.name
FROM place p
JOIN food_outlet f ON f.place_id = p.place_id
WHERE f.is_veg = true;

\echo '--- RA2: names of places tagged "wifi" (three-table join) ---'
SELECT DISTINCT p.name
FROM place p
JOIN place_tag pt ON pt.place_id = p.place_id
JOIN tag t        ON t.tag_id = pt.tag_id
WHERE t.name = 'wifi';

\echo '--- RA3: places that have no review (set difference) ---'
SELECT place_id FROM place
EXCEPT
SELECT place_id FROM review;

\echo '--- RA4: places that are cheap (price_level = 1) OR have a student discount (union) ---'
SELECT place_id, name FROM place WHERE price_level = 1
UNION
SELECT place_id, name FROM place WHERE student_discount = true;

\echo '--- RA5: users who reviewed EVERY student-discount place (division) ---'
-- SQL has no division operator. Classic rewrite: "there is no discount place
-- that this user has NOT reviewed".
SELECT u.user_id, u.name
FROM app_user u
WHERE NOT EXISTS (
  SELECT 1 FROM place p
  WHERE p.student_discount = true
    AND NOT EXISTS (
      SELECT 1 FROM review r
      WHERE r.user_id = u.user_id AND r.place_id = p.place_id));

\echo '--- RA6: pairs of different places that share the same map node (rename + self join) ---'
SELECT p1.name AS place_1, p2.name AS place_2, p1.node_id
FROM place p1
JOIN place p2 ON p1.node_id = p2.node_id AND p1.place_id < p2.place_id;

\echo '--- TRC: places that have reviews and EVERY review is 4 or more (universal quantifier) ---'
SELECT p.name
FROM place p
WHERE EXISTS (SELECT 1 FROM review r WHERE r.place_id = p.place_id)
  AND NOT EXISTS (SELECT 1 FROM review r WHERE r.place_id = p.place_id AND r.rating < 4);
