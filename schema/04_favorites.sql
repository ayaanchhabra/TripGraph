-- schema/04_favorites.sql   (K)
-- Adds the favorite table: a many-to-many relationship between app_user and place.
-- A student can save many places, and a place can be saved by many students.
-- Run after 01, 02 and 03 (it needs app_user and place to exist). Safe to run more than once.
--   psql -d tripgraph -f schema/04_favorites.sql

\set ON_ERROR_STOP on

DROP TABLE IF EXISTS favorite;

CREATE TABLE favorite (
  user_id  INT         NOT NULL,
  place_id INT         NOT NULL,
  visited  BOOLEAN     NOT NULL DEFAULT false,      -- saved only, or already been there
  saved_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, place_id),                  -- a place can be saved once per student
  CONSTRAINT fk_fav_user  FOREIGN KEY (user_id)  REFERENCES app_user(user_id) ON DELETE CASCADE,
  CONSTRAINT fk_fav_place FOREIGN KEY (place_id) REFERENCES place(place_id)   ON DELETE CASCADE
);
