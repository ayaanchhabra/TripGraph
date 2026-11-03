-- queries/views/01_top_rated_places.sql
-- Ranks places inside each category by average rating (ties broken by more reviews).
-- Only places with at least one review appear. Uses a window function (RANK).
--
-- Examples:
--   SELECT * FROM top_rated_places WHERE rank_in_category <= 3;
--   SELECT * FROM top_rated_places WHERE category = 'Stationery and photocopy/printing' AND student_discount;

\set ON_ERROR_STOP on

CREATE OR REPLACE VIEW top_rated_places AS
SELECT p.place_id,
       p.name,
       c.name        AS category,
       c.group_name,
       f.is_veg,                     -- NULL for places that are not Food and drink
       p.price_level,
       p.student_discount,
       p.avg_rating,
       p.review_count,
       RANK() OVER (PARTITION BY p.category_id
                    ORDER BY p.avg_rating DESC, p.review_count DESC) AS rank_in_category
FROM place p
JOIN category c        ON c.category_id = p.category_id
LEFT JOIN food_outlet f ON f.place_id   = p.place_id
WHERE p.review_count > 0;
