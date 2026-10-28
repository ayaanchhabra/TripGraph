-- data/sample_data/extra_places.sql
-- Adds four more food places that share a category with an existing sample place, so that
-- similar_places() and the freshers_guide_cheap_eats view have something to compare.
--   Sample Dhaba 2         (Restaurants and dhabas)  price 1, student discount
--   Sample Study Cafe 2    (Cafes)                   price 2, student discount
--   Sample Chaat Stall 2   (Street food and chaat)   price 1
--   Sample Chai Point 2    (Juice, shakes and chai)  price 2, student discount
-- Each copies the location, map node and cuisine of the place it sits next to. Two reviews per
-- new place come from the first two existing users; the rating trigger fills avg_rating and review_count.
-- Safe to run more than once: a place is added only if its name does not exist yet,
-- and a review only if that user has not reviewed that place.

INSERT INTO place (name, category_id, address, lat, lon, price_level, student_discount, node_id)
SELECT v.new_name, s.category_id, s.address, s.lat + 0.0004, s.lon + 0.0004,
       v.price_level, v.discount, s.node_id
FROM (VALUES
        ('Sample Dhaba 2',       'Sample Dhaba',       1::smallint, true),
        ('Sample Study Cafe 2',  'Sample Study Cafe',  2::smallint, true),
        ('Sample Chaat Stall 2', 'Sample Chaat Stall', 1::smallint, false),
        ('Sample Chai Point 2',  'Sample Chai Point',  2::smallint, true)
     ) AS v(new_name, sibling, price_level, discount)
JOIN place s ON s.name = v.sibling
WHERE NOT EXISTS (SELECT 1 FROM place x WHERE x.name = v.new_name);

INSERT INTO food_outlet (place_id, cuisine, is_veg)
SELECT n.place_id, f.cuisine, f.is_veg
FROM (VALUES ('Sample Dhaba 2','Sample Dhaba'), ('Sample Study Cafe 2','Sample Study Cafe'),
             ('Sample Chaat Stall 2','Sample Chaat Stall'), ('Sample Chai Point 2','Sample Chai Point')
     ) AS v(new_name, sibling)
JOIN place n ON n.name = v.new_name
JOIN place s ON s.name = v.sibling
JOIN food_outlet f ON f.place_id = s.place_id
ON CONFLICT (place_id) DO NOTHING;

INSERT INTO review (user_id, place_id, rating)
SELECT u.user_id, p.place_id, CASE u.rn WHEN 1 THEN 5 ELSE 4 END
FROM (SELECT user_id, ROW_NUMBER() OVER (ORDER BY user_id) AS rn FROM app_user) u
CROSS JOIN place p
WHERE u.rn <= 2
  AND p.name IN ('Sample Dhaba 2','Sample Study Cafe 2','Sample Chaat Stall 2','Sample Chai Point 2')
ON CONFLICT DO NOTHING;
