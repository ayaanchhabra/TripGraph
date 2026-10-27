-- triggers/03_audit_log.sql
-- Writes a row to audit_log whenever a place or an edge is added, changed or deleted.
-- Run AFTER schema/01-04 and triggers/01-02. Run security/02_grants.sql again afterwards
-- if you have already loaded the security files.
--
-- Why SECURITY DEFINER: students and admins have no right to write audit_log directly.
-- The trigger function runs with the owner's rights, so the log is written even when a
-- limited role makes the change, and nobody can write fake log rows by hand.
--
-- Why avg_rating / review_count changes are skipped: the review trigger updates place on
-- every review. Logging those would fill the log with machine noise. Only real edits
-- (name, price, hours-related fields, node, discount and so on) are recorded.

CREATE OR REPLACE FUNCTION trg_audit_change() RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_id text;
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_id := (to_jsonb(OLD) ->> CASE TG_TABLE_NAME WHEN 'place' THEN 'place_id' ELSE 'edge_id' END);
        INSERT INTO audit_log(action, table_name, record_id)
        VALUES ('DELETE', TG_TABLE_NAME, v_id);
        RETURN OLD;
    END IF;

    v_id := (to_jsonb(NEW) ->> CASE TG_TABLE_NAME WHEN 'place' THEN 'place_id' ELSE 'edge_id' END);

    IF TG_OP = 'UPDATE' THEN
        -- ignore updates that only touch the trigger-maintained rating columns
        IF (to_jsonb(NEW) - 'avg_rating' - 'review_count')
           = (to_jsonb(OLD) - 'avg_rating' - 'review_count') THEN
            RETURN NEW;
        END IF;
    END IF;

    INSERT INTO audit_log(action, table_name, record_id)
    VALUES (TG_OP, TG_TABLE_NAME, v_id);
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS audit_place ON place;
CREATE TRIGGER audit_place
    AFTER INSERT OR UPDATE OR DELETE ON place
    FOR EACH ROW EXECUTE FUNCTION trg_audit_change();

DROP TRIGGER IF EXISTS audit_edge ON edge;
CREATE TRIGGER audit_edge
    AFTER INSERT OR UPDATE OR DELETE ON edge
    FOR EACH ROW EXECUTE FUNCTION trg_audit_change();