-- queries/views/freshers_guide_cheap_eats.sql
-- "Cheap eats for freshers": food places a new student can afford, best first.
-- A food place is listed when it has a food_outlet row and either
--   * price_level = 1 (the cheapest level), or
--   * price_level = 2 and it gives a student discount.
-- Ranked with window functions: cuisine_rank restarts inside each cuisine,
-- overall_rank runs over the whole list. Highest average rating first, then more reviews,
-- then name. RANK() gives tied places the same number.
--
--   SELECT * FROM freshers_guide_cheap_eats ORDER BY overall_rank LIMIT 10;
--   SELECT * FROM freshers_guide_cheap_eats WHERE is_veg ORDER BY cuisine, cuisine_rank;
--   SELECT * FROM freshers_guide_cheap_eats WHERE cuisine_rank = 1;   -- best of each cuisine
--
-- Run after the schema. Run security/02_grants.sql again afterwards if it does not list this view.

CREATE OR REPLACE VIEW freshers_guide_cheap_eats AS
SELECT p.place_id,
       p.name,
       c.name  AS category,
       COALESCE(f.cuisine, 'Other') AS cuisine,
       f.is_veg,
       p.price_level,
       p.student_discount,
       p.avg_rating,
       p.review_count,
       RANK() OVER (PARTITION BY COALESCE(f.cuisine, 'Other')
                    ORDER BY p.avg_rating DESC, p.review_count DESC) AS cuisine_rank,
       RANK() OVER (ORDER BY p.avg_rating DESC, p.review_count DESC) AS overall_rank
FROM place p
JOIN category c    ON c.category_id = p.category_id
JOIN food_outlet f ON f.place_id    = p.place_id
WHERE p.price_level = 1
   OR (p.price_level = 2 AND p.student_discount);

-- Let the student role read it (skipped if the security files have not been run yet).
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'tripgraph_student') THEN
        GRANT SELECT ON freshers_guide_cheap_eats TO tripgraph_student;
    END IF;
END $$;
