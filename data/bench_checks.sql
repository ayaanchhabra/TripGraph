-- data/bench_checks.sql
-- Checks the generated bench data. Run from the repo root after generate_bulk.sql:
--   psql -U postgres -d tripgraph -f data/bench_checks.sql

\echo '1. Row counts (info)'
SELECT (SELECT count(*) FROM bench.place) AS places, (SELECT count(*) FROM bench.review) AS reviews,
       (SELECT count(*) FROM bench.app_user) AS users, (SELECT count(*) FROM bench.place_tag) AS place_tags;

\echo '2. Duplicate (user_id, place_id) reviews (expect 0 rows)'
SELECT user_id, place_id, count(*) FROM bench.review GROUP BY user_id, place_id HAVING count(*) > 1;

\echo '3. Ratings or price levels out of range (expect 0 rows)'
SELECT 'review' AS tbl, user_id::text AS id, rating::text AS bad FROM bench.review WHERE rating NOT BETWEEN 1 AND 5
UNION ALL
SELECT 'place', place_id::text, price_level::text FROM bench.place WHERE price_level NOT BETWEEN 1 AND 3;

\echo '4. Places with an invalid category or node (expect 0 rows)'
SELECT p.place_id FROM bench.place p
WHERE NOT EXISTS (SELECT 1 FROM public.category c WHERE c.category_id = p.category_id)
   OR NOT EXISTS (SELECT 1 FROM public.node n WHERE n.node_id = p.node_id);

\echo '5. Reviews pointing at missing users or places (expect 0 rows)'
SELECT r.user_id, r.place_id FROM bench.review r
WHERE NOT EXISTS (SELECT 1 FROM bench.app_user u WHERE u.user_id = r.user_id)
   OR NOT EXISTS (SELECT 1 FROM bench.place p WHERE p.place_id = r.place_id);

\echo '6. avg_rating / review_count that disagree with the reviews (expect 0 rows)'
SELECT p.place_id, p.avg_rating, p.review_count, x.avg_r, x.cnt
FROM bench.place p
JOIN (SELECT place_id, round(avg(rating)::numeric, 2) AS avg_r, count(*) AS cnt
      FROM bench.review GROUP BY place_id) x USING (place_id)
WHERE p.avg_rating::numeric <> x.avg_r OR p.review_count <> x.cnt;

\echo '7. Place tags pointing at missing places or tags (expect 0 rows)'
SELECT pt.place_id, pt.tag_id FROM bench.place_tag pt
WHERE NOT EXISTS (SELECT 1 FROM bench.place p WHERE p.place_id = pt.place_id)
   OR NOT EXISTS (SELECT 1 FROM bench.tag t WHERE t.tag_id = pt.tag_id);

\echo '8. Spread: price levels (info)'
SELECT price_level, count(*) FROM bench.place GROUP BY 1 ORDER BY 1;

\echo '9. Spread: ratings (info)'
SELECT rating, count(*) FROM bench.review GROUP BY 1 ORDER BY 1;

\echo '10. Spread: places per category (info; should be uneven)'
SELECT c.name, count(*) FROM bench.place p JOIN public.category c USING (category_id)
GROUP BY c.name ORDER BY 2 DESC;

\echo '11. Spread: reviews per place (info)'
SELECT percentile_disc(0.5) WITHIN GROUP (ORDER BY review_count) AS median,
       percentile_disc(0.9) WITHIN GROUP (ORDER BY review_count) AS p90,
       max(review_count) AS max FROM bench.place;
