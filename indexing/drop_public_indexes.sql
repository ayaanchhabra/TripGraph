-- indexing/drop_public_indexes.sql
-- Purpose : Removes the five indexes created by indexing/public_indexes.sql.
--           Only idx_public_* indexes are touched; the full-text GIN index
--           (idx_place_name_fts_gin) and every primary key are left alone.
-- Run     : psql -U postgres -d tripgraph -v ON_ERROR_STOP=1 -f indexing/drop_public_indexes.sql
-- Re-run  : safe. DROP INDEX IF EXISTS does nothing when the index is already gone.
--
-- Agreed with the schema owner before merging; schema/ files are not edited.

DROP INDEX IF EXISTS public.idx_public_place_category_price;
DROP INDEX IF EXISTS public.idx_public_place_toprated_partial;
DROP INDEX IF EXISTS public.idx_public_edge_from_node;
DROP INDEX IF EXISTS public.idx_public_review_place;
DROP INDEX IF EXISTS public.idx_public_place_tag_tag;
