-- data/sample_data/01_sample_users.sql
-- Purpose: 8 sample users (6 students and 2 admins) for demos and tests.
-- How to run (after data/load_all.sql, with the triggers installed):
--   psql -U postgres -d tripgraph -v ON_ERROR_STOP=1 -f data/sample_data/01_sample_users.sql
-- Re-runnable: a user whose email already exists is skipped.

INSERT INTO app_user (name, email, role, created_at) VALUES
  ('Aarav Sharma',   'aarav.sharma@example.com',   'student', now() - INTERVAL '90 days'),
  ('Diya Verma',     'diya.verma@example.com',     'student', now() - INTERVAL '88 days'),
  ('Rohan Gupta',    'rohan.gupta@example.com',    'student', now() - INTERVAL '85 days'),
  ('Ananya Singh',   'ananya.singh@example.com',   'student', now() - INTERVAL '80 days'),
  ('Kabir Malhotra', 'kabir.malhotra@example.com', 'student', now() - INTERVAL '75 days'),
  ('Meera Iyer',     'meera.iyer@example.com',     'student', now() - INTERVAL '70 days'),
  ('Vikram Rao',     'vikram.rao@example.com',     'admin',   now() - INTERVAL '95 days'),
  ('Sana Khan',      'sana.khan@example.com',      'admin',   now() - INTERVAL '95 days')
ON CONFLICT (email) DO NOTHING;
