-- indexing/fulltext_search.sql   (A)
-- Ranked full-text search over place NAME and TAGS, in the public schema.
-- Run from the repo root, after schema + data are loaded:
--   psql -U postgres -d tripgraph -f indexing/fulltext_search.sql
-- Then:  SELECT * FROM search_places('veg cafe wifi');
--
-- Plain-language idea
--   to_tsvector  = turn text into a list of searchable words ("document")
--   tsquery      = the search words ("query")
--   @@           = "document matches query"
--   ts_rank      = a score: more/better matches => higher number
--   setweight    = make some words count more (name = 'A', tags = 'B')
--   'simple'     = no stemming, no stop words (place names like "Sharma" must stay as they are)
-- This file only ADDS a view, a function and an index. It does not change any table.
-- (If K prefers, the tag part can later become a stored tsvector column on place.)

\set ON_ERROR_STOP on

-- 1. Same GIN index as benchmark Q4, now on the real table.
--    The query below must use the SAME expression to_tsvector('simple', name) for it to be usable.
CREATE INDEX IF NOT EXISTS idx_place_name_fts_gin
  ON place USING gin (to_tsvector('simple', name));

-- 2. One searchable document per place: name (weight A) + all its tags (weight B).
CREATE OR REPLACE VIEW place_search AS
SELECT p.place_id,
       p.name,
       p.category_id,
       p.price_level,
       p.student_discount,
       p.avg_rating,
       p.review_count,
       COALESCE(string_agg(t.name, ' ' ORDER BY t.name), '') AS tags,
       setweight(to_tsvector('simple', p.name), 'A')
         || setweight(to_tsvector('simple', COALESCE(string_agg(t.name, ' '), '')), 'B') AS doc
FROM place p
LEFT JOIN place_tag pt ON pt.place_id = p.place_id
LEFT JOIN tag t        ON t.tag_id = pt.tag_id
GROUP BY p.place_id;

-- 3. Search function.
--    websearch_to_tsquery understands plain input like:  veg cafe   "late night"   chai -tea   cafe or dhaba
--    Ties are broken by stored rating, then by name, so results are stable.
CREATE OR REPLACE FUNCTION search_places(q text, max_rows int DEFAULT 20)
RETURNS TABLE (place_id int, name text, tags text, avg_rating numeric, rank real)
LANGUAGE sql STABLE AS $$
  SELECT s.place_id, s.name, s.tags, s.avg_rating,
         ts_rank(s.doc, websearch_to_tsquery('simple', q)) AS rank
  FROM place_search s
  WHERE s.doc @@ websearch_to_tsquery('simple', q)
  ORDER BY rank DESC, s.avg_rating DESC NULLS LAST, s.name
  LIMIT max_rows;
$$;

-- 4. Tag-only search (exact tag names): places that have ALL the given tags.
--    Example: SELECT * FROM places_with_tags(ARRAY['veg','wifi']);
CREATE OR REPLACE FUNCTION places_with_tags(tag_names text[])
RETURNS TABLE (place_id int, name text)
LANGUAGE sql STABLE AS $$
  SELECT p.place_id, p.name
  FROM place p
  JOIN place_tag pt ON pt.place_id = p.place_id
  JOIN tag t        ON t.tag_id = pt.tag_id
  WHERE t.name = ANY (SELECT lower(trim(x)) FROM unnest(tag_names) x)
  GROUP BY p.place_id, p.name
  HAVING count(DISTINCT t.name) = (SELECT count(DISTINCT lower(trim(x))) FROM unnest(tag_names) x)
  ORDER BY p.name;
$$;

ANALYZE place;
\echo 'Created: index idx_place_name_fts_gin, view place_search, functions search_places(), places_with_tags()'
