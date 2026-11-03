-- tests/test_trending.sql
-- Purpose: Test the trending_this_month view.
-- Run from the repository root:
--   psql -U postgres -d tripgraph -v ON_ERROR_STOP=1 -f tests/test_trending.sql
-- Everything is rolled back at the end.

\set ON_ERROR_STOP on

BEGIN;

\i tests/00_helpers.sql
\i tests/01_fixtures.sql

\o /dev/null

-- Create three additional test places.
INSERT INTO place
    (place_id, name, category_id, address, lat, lon, price_level, node_id)
SELECT
    900003, 'TEST Trending Tie', category_id,
    'test', 28.61, 77.03, 2, node_id
FROM place
WHERE place_id = 900001;

INSERT INTO place
    (place_id, name, category_id, address, lat, lon, price_level, node_id)
SELECT
    900004, 'TEST Trending Lower Rating', category_id,
    'test', 28.61, 77.03, 2, node_id
FROM place
WHERE place_id = 900001;

INSERT INTO place
    (place_id, name, category_id, address, lat, lon, price_level, node_id)
SELECT
    900005, 'TEST Trending No Recent Reviews', category_id,
    'test', 28.61, 77.03, 2, node_id
FROM place
WHERE place_id = 900001;

-- Recent reviews:
-- Place 900001: 2 reviews, average 4.00.
-- Place 900003: 2 reviews, average 4.00.
-- Place 900004: 2 reviews, average 3.50.
-- Place 900002: 1 review, average 5.00.
-- Place 900005: only an old review and a future review.

INSERT INTO review (user_id, place_id, rating, created_at)
VALUES
    (900001, 900001, 5, CURRENT_TIMESTAMP - INTERVAL '1 day'),
    (900002, 900001, 3, CURRENT_TIMESTAMP - INTERVAL '2 days'),

    (900001, 900003, 4, CURRENT_TIMESTAMP - INTERVAL '1 day'),
    (900003, 900003, 4, CURRENT_TIMESTAMP - INTERVAL '2 days'),

    (900002, 900004, 3, CURRENT_TIMESTAMP - INTERVAL '1 day'),
    (900003, 900004, 4, CURRENT_TIMESTAMP - INTERVAL '2 days'),

    (900001, 900002, 5, CURRENT_TIMESTAMP - INTERVAL '1 day'),

    (900001, 900005, 2, CURRENT_TIMESTAMP - INTERVAL '31 days'),
    (900002, 900005, 5, CURRENT_TIMESTAMP + INTERVAL '1 day');

-- Test 1: Only four places with recent reviews appear.
SELECT pg_temp.expect_eq(
    'trending_this_month',
    'only four test places with recent reviews are listed',
    $q$
        SELECT count(*)::text
        FROM trending_this_month
        WHERE place_id BETWEEN 900001 AND 900005
    $q$,
    '4'
);

-- Test 2: Recent review counts.
SELECT pg_temp.expect_eq(
    'trending_this_month',
    'recent review counts are correct',
    $q$
        SELECT string_agg(
            place_id::text || ':' || recent_review_count::text,
            ',' ORDER BY place_id
        )
        FROM trending_this_month
        WHERE place_id BETWEEN 900001 AND 900005
    $q$,
    '900001:2,900002:1,900003:2,900004:2'
);

-- Test 3: Recent average ratings.
SELECT pg_temp.expect_eq(
    'trending_this_month',
    'recent average ratings are correct',
    $q$
        SELECT string_agg(
            place_id::text || ':' ||
            recent_avg_rating::numeric(10,2)::text,
            ',' ORDER BY place_id
        )
        FROM trending_this_month
        WHERE place_id BETWEEN 900001 AND 900005
    $q$,
    '900001:4.00,900002:5.00,900003:4.00,900004:3.50'
);

-- Test 4: Equal counts and averages receive equal ranks.
SELECT pg_temp.expect_eq(
    'trending_this_month',
    'equal review counts and averages receive the same rank',
    $q$
        SELECT (
            (SELECT "rank" FROM trending_this_month WHERE place_id = 900001)
            =
            (SELECT "rank" FROM trending_this_month WHERE place_id = 900003)
        )::text
    $q$,
    'true'
);

-- Test 5: RANK counts every preceding row, including ties.
-- This verifies rank gaps without assuming test places start at rank 1.
SELECT pg_temp.expect_eq(
    'trending_this_month',
    'RANK counts all preceding rows and preserves tie gaps',
    $q$
        SELECT (
            (SELECT "rank"
             FROM trending_this_month
             WHERE place_id = 900004)
            =
            1 + (
                SELECT count(*)
                FROM trending_this_month AS t
                WHERE t.recent_review_count > 2
                   OR (
                       t.recent_review_count = 2
                       AND t.recent_avg_rating > 3.50
                   )
            )
        )::text
    $q$,
    'true'
);
-- Test 6: Review count has priority over average rating.
SELECT pg_temp.expect_eq(
    'trending_this_month',
    'review count takes priority over average rating',
    $q$
        SELECT (
            (SELECT "rank" FROM trending_this_month WHERE place_id = 900004)
            <
            (SELECT "rank" FROM trending_this_month WHERE place_id = 900002)
        )::text
    $q$,
    'true'
);

-- Test 7: Old and future reviews do not make a place trending.
SELECT pg_temp.expect_eq(
    'trending_this_month',
    'places without reviews in the last 30 days are excluded',
    $q$
        SELECT (
            NOT EXISTS (
                SELECT 1
                FROM trending_this_month
                WHERE place_id = 900005
            )
        )::text
    $q$,
    'true'
);

\o

SELECT n AS "#", area, test, status
FROM test_results
ORDER BY n;

SELECT
    count(*) FILTER (WHERE status = 'PASS') AS passed,
    count(*) FILTER (WHERE status = 'FAIL') AS failed
FROM test_results;

SELECT n AS "#", test, detail AS "what went wrong"
FROM test_results
WHERE status = 'FAIL'
ORDER BY n;

ROLLBACK;
