-- queries/views/03_trending_this_month.sql
-- Purpose: Rank places using reviews from the last 30 days.
-- Run from the repository root:
--   psql -U postgres -d tripgraph -v ON_ERROR_STOP=1 -f queries/views/03_trending_this_month.sql
-- Re-runnable: CREATE OR REPLACE VIEW replaces the existing definition.

\set ON_ERROR_STOP on

CREATE OR REPLACE VIEW trending_this_month AS
WITH recent_reviews AS (
    SELECT
        r.place_id,
        COUNT(*)::integer AS recent_review_count,
        AVG(r.rating)::numeric AS recent_avg_rating
    FROM review AS r
    WHERE r.created_at >= CURRENT_TIMESTAMP - INTERVAL '30 days'
      AND r.created_at <= CURRENT_TIMESTAMP
    GROUP BY r.place_id
)
SELECT
    p.place_id,
    p.name,
    c.name AS category,
    rr.recent_review_count,
    rr.recent_avg_rating,
    RANK() OVER (
        ORDER BY
            rr.recent_review_count DESC,
            rr.recent_avg_rating DESC
    ) AS "rank"
FROM recent_reviews AS rr
JOIN place AS p
    ON p.place_id = rr.place_id
JOIN category AS c
    ON c.category_id = p.category_id;
