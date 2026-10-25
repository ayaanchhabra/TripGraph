-- data/sample_data/03_sample_favorites.sql
-- Purpose: 16 sample favorites. visited = true means the student has already been there.
-- How to run (after 01_sample_users.sql):
--   psql -U postgres -d tripgraph -v ON_ERROR_STOP=1 -f data/sample_data/03_sample_favorites.sql
-- Re-runnable: a favorite that already exists (same user and place) is skipped.
-- Needs the 12 places from data/csv/places.csv. If a place or user is missing, the check below
-- stops with a message that names it.

DROP TABLE IF EXISTS pg_temp.stg_favorite;
CREATE TEMP TABLE stg_favorite AS
SELECT * FROM (VALUES
  ('aarav.sharma@example.com',   'Sample Chaat Stall',  true,  30),
  ('aarav.sharma@example.com',   'Sample Study Cafe',   true,  25),
  ('aarav.sharma@example.com',   'Sample Movie Hall',   false,  9),
  ('diya.verma@example.com',     'Sample Study Cafe',   true,  40),
  ('diya.verma@example.com',     'Sample Park',         true,  15),
  ('diya.verma@example.com',     'Sample Book Corner',  false,  6),
  ('rohan.gupta@example.com',    'Sample Dhaba',        true,  35),
  ('rohan.gupta@example.com',    'Sample Xerox and Printing', true, 20),
  ('rohan.gupta@example.com',    'Sample Gym',          false, 12),
  ('ananya.singh@example.com',   'Sample Chai Point',   true,  18),
  ('ananya.singh@example.com',   'Sample Study Cafe',   false,  5),
  ('kabir.malhotra@example.com', 'Sample Chai Point',   true,  27),
  ('kabir.malhotra@example.com', 'Sample Gaming Zone',  false,  3),
  ('meera.iyer@example.com',     'Sample Chaat Stall',  false, 14),
  ('sana.khan@example.com',      'Sample Study Cafe',   true,  22),
  ('vikram.rao@example.com',     'Sample Medical Store', false, 8)
) AS v(email, place_name, visited, days_ago);

DO $$
DECLARE
  bad_places TEXT;
  bad_users  TEXT;
BEGIN
  SELECT string_agg(DISTINCT s.place_name, ', ') INTO bad_places
  FROM stg_favorite s LEFT JOIN place p ON p.name = s.place_name
  WHERE p.place_id IS NULL;
  IF bad_places IS NOT NULL THEN
    RAISE EXCEPTION 'Sample favorites: these places are not in the place table: %. Load the places first: reload the database in the documented order, ending with data/load_all.sql.', bad_places;
  END IF;

  SELECT string_agg(DISTINCT s.email, ', ') INTO bad_users
  FROM stg_favorite s LEFT JOIN app_user u ON u.email = s.email
  WHERE u.user_id IS NULL;
  IF bad_users IS NOT NULL THEN
    RAISE EXCEPTION 'Sample favorites: these users are missing: %. Run data/sample_data/01_sample_users.sql first.', bad_users;
  END IF;
END $$;

INSERT INTO favorite (user_id, place_id, visited, saved_at)
SELECT u.user_id,
       p.place_id,
       s.visited,
       now() - s.days_ago * INTERVAL '1 day'
FROM stg_favorite s
JOIN app_user u ON u.email = s.email
JOIN place p    ON p.name  = s.place_name
ON CONFLICT (user_id, place_id) DO NOTHING;