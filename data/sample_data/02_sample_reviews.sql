-- data/sample_data/02_sample_reviews.sql
-- Purpose: 45 sample reviews over the 12 places, with ratings from 1 to 5.
--   * dates are spread over the last 60 days
--   * 18 reviews are dated inside the CURRENT month (kind 'recent'), the rest are older (kind 'older')
--   * 5 places have 5 or more reviews (Dhaba, Chaat Stall, Study Cafe, Chai Point, Xerox)
-- IMPORTANT: the review trigger must be ENABLED. It fills place.avg_rating and place.review_count.
-- How to run (after 01_sample_users.sql):
--   psql -U postgres -d tripgraph -v ON_ERROR_STOP=1 -f data/sample_data/02_sample_reviews.sql
-- Re-runnable: a review that already exists (same user and place) is skipped.
-- Needs the 12 places from data/csv/places.csv. If a place or user is missing, the check below
-- stops with a message that names it.
--
-- How the date column works:
--   'recent' + 0.35 -> 35 percent of the way from the start of this month to now (always inside this month)
--   'older'  + 41   -> 41 days ago

DROP TABLE IF EXISTS pg_temp.stg_review;
CREATE TEMP TABLE stg_review AS
SELECT * FROM (VALUES
  -- Sample Dhaba (6)
  ('aarav.sharma@example.com',   'Sample Dhaba', 4, 'Good thali, filling and cheap',          'older',  41),
  ('diya.verma@example.com',     'Sample Dhaba', 3, 'Tasty but slow service at lunch',        'older',  28),
  ('rohan.gupta@example.com',    'Sample Dhaba', 5, 'Best butter chicken near campus',        'recent', 0.35),
  ('ananya.singh@example.com',   'Sample Dhaba', 4, 'Value for money',                        'older',  14),
  ('kabir.malhotra@example.com', 'Sample Dhaba', 1, 'Found a hair in the food',               'older',  52),
  ('meera.iyer@example.com',     'Sample Dhaba', 4, 'Decent food and open late',              'recent', 0.80),
  -- Sample Chaat Stall (7)
  ('aarav.sharma@example.com',   'Sample Chaat Stall', 5, 'Golgappe are great',               'recent', 0.20),
  ('diya.verma@example.com',     'Sample Chaat Stall', 5, 'Cheap and fresh',                  'older',  33),
  ('rohan.gupta@example.com',    'Sample Chaat Stall', 4, 'Gets crowded after 5 pm',          'recent', 0.55),
  ('ananya.singh@example.com',   'Sample Chaat Stall', 5, 'Student discount is a nice touch', 'older',  20),
  ('kabir.malhotra@example.com', 'Sample Chaat Stall', 4, 'Good aloo tikki',                  'recent', 0.90),
  ('meera.iyer@example.com',     'Sample Chaat Stall', 3, 'Hygiene could be better',          'older',  47),
  ('vikram.rao@example.com',     'Sample Chaat Stall', 5, 'Must try the dahi bhalla',         'recent', 0.65),
  -- Sample Study Cafe (7)
  ('aarav.sharma@example.com',   'Sample Study Cafe', 4, 'Quiet and the wifi works',          'recent', 0.10),
  ('diya.verma@example.com',     'Sample Study Cafe', 5, 'Great for group study',             'recent', 0.45),
  ('rohan.gupta@example.com',    'Sample Study Cafe', 3, 'A bit pricey for coffee',           'older',  18),
  ('ananya.singh@example.com',   'Sample Study Cafe', 4, 'Good cold coffee',                  'recent', 0.70),
  ('sana.khan@example.com',      'Sample Study Cafe', 5, 'Open past midnight, saved my exams','recent', 0.95),
  ('vikram.rao@example.com',     'Sample Study Cafe', 4, 'Comfortable seats',                 'older',  26),
  ('meera.iyer@example.com',     'Sample Study Cafe', 2, 'Too crowded before exams',          'older',  55),
  -- Sample Chai Point (6)
  ('kabir.malhotra@example.com', 'Sample Chai Point', 5, 'Best kulhad chai around',            'recent', 0.25),
  ('rohan.gupta@example.com',    'Sample Chai Point', 4, 'Quick service',                     'older',  22),
  ('sana.khan@example.com',      'Sample Chai Point', 4, 'Good maska bun',                    'older',  38),
  ('aarav.sharma@example.com',   'Sample Chai Point', 3, 'Average tea but a nice spot',       'older',  45),
  ('diya.verma@example.com',     'Sample Chai Point', 5, 'Perfect evening break',             'recent', 0.60),
  ('ananya.singh@example.com',   'Sample Chai Point', 4, 'Reasonable prices',                 'older',  11),
  -- Sample Xerox and Printing (6)
  ('aarav.sharma@example.com',   'Sample Xerox and Printing', 5, 'Re 1 per page and fast',    'recent', 0.15),
  ('rohan.gupta@example.com',    'Sample Xerox and Printing', 4, 'Handles bulk orders well',  'older',  30),
  ('meera.iyer@example.com',     'Sample Xerox and Printing', 5, 'Student discount on printouts', 'recent', 0.50),
  ('kabir.malhotra@example.com', 'Sample Xerox and Printing', 3, 'Long queue during submissions', 'older', 15),
  ('sana.khan@example.com',      'Sample Xerox and Printing', 4, 'Colour print quality is good', 'older', 42),
  ('vikram.rao@example.com',     'Sample Xerox and Printing', 1, 'Machine broke and ruined my print', 'older', 58),
  -- Sample Book Corner (3)
  ('diya.verma@example.com',     'Sample Book Corner', 5, 'Found an old edition cheap',       'older',  36),
  ('ananya.singh@example.com',   'Sample Book Corner', 4, 'Good second-hand shelf',           'recent', 0.40),
  ('rohan.gupta@example.com',    'Sample Book Corner', 4, 'Helpful owner',                    'older',  24),
  -- Sample Daily Needs Store (2)
  ('kabir.malhotra@example.com', 'Sample Daily Needs Store', 4, 'Everything in one place',     'older',  17),
  ('meera.iyer@example.com',     'Sample Daily Needs Store', 3, 'Snacks slightly above MRP',   'older',  50),
  -- Sample Medical Store (2)
  ('vikram.rao@example.com',     'Sample Medical Store', 5, 'Open late and helpful',          'recent', 0.30),
  ('sana.khan@example.com',      'Sample Medical Store', 4, 'Always has stock',               'older',  29),
  -- Sample Gym (2)
  ('aarav.sharma@example.com',   'Sample Gym', 3, 'Crowded in the evenings',                  'older',  21),
  ('rohan.gupta@example.com',    'Sample Gym', 4, 'Good equipment for the price',             'older',  44),
  -- Sample Park (1)
  ('diya.verma@example.com',     'Sample Park', 5, 'Peaceful for an evening walk',            'older',  12),
  -- Sample Gaming Zone (1)
  ('kabir.malhotra@example.com', 'Sample Gaming Zone', 4, 'Fun with friends, good PCs',       'recent', 0.85),
  -- Sample Movie Hall (2)
  ('ananya.singh@example.com',   'Sample Movie Hall', 3, 'Tickets are expensive',             'older',  34),
  ('sana.khan@example.com',      'Sample Movie Hall', 4, 'Good sound and comfy seats',        'recent', 0.75)
) AS v(email, place_name, rating, review_text, kind, amount);

-- Stop with a readable message if a place or user is missing
DO $$
DECLARE
  bad_places TEXT;
  bad_users  TEXT;
BEGIN
  SELECT string_agg(DISTINCT s.place_name, ', ') INTO bad_places
  FROM stg_review s LEFT JOIN place p ON p.name = s.place_name
  WHERE p.place_id IS NULL;
  IF bad_places IS NOT NULL THEN
    RAISE EXCEPTION 'Sample reviews: these places are not in the place table: %. Load the places first: reload the database in the documented order, ending with data/load_all.sql.', bad_places;
  END IF;

  SELECT string_agg(DISTINCT s.email, ', ') INTO bad_users
  FROM stg_review s LEFT JOIN app_user u ON u.email = s.email
  WHERE u.user_id IS NULL;
  IF bad_users IS NOT NULL THEN
    RAISE EXCEPTION 'Sample reviews: these users are missing: %. Run data/sample_data/01_sample_users.sql first.', bad_users;
  END IF;
END $$;

INSERT INTO review (user_id, place_id, rating, review_text, created_at)
SELECT u.user_id,
       p.place_id,
       s.rating,
       s.review_text,
       CASE WHEN s.kind = 'recent'
            THEN date_trunc('month', now()) + (now() - date_trunc('month', now())) * s.amount::float8
            ELSE now() - s.amount::float8 * INTERVAL '1 day'
       END
FROM stg_review s
JOIN app_user u ON u.email = s.email
JOIN place p    ON p.name  = s.place_name
ON CONFLICT (user_id, place_id) DO NOTHING;