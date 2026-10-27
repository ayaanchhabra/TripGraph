-- tests/test_audit.sql  (run after triggers/03_audit_log.sql; rolls back everything it creates)
-- Expected: every row in the result says PASS.
BEGIN;
CREATE TEMP TABLE audit_results(check_name text, result text) ON COMMIT DROP;

DO $$
DECLARE
    v_place int; v_edge int; v_before int; v_n int;
BEGIN
    -- 1. editing a place is logged
    SELECT place_id INTO v_place FROM place ORDER BY place_id LIMIT 1;
    SELECT count(*) INTO v_before FROM audit_log WHERE table_name='place' AND record_id=v_place::text AND action='UPDATE';
    UPDATE place SET price_level = CASE WHEN price_level = 3 THEN 2 ELSE price_level + 1 END WHERE place_id = v_place;
    SELECT count(*) INTO v_n FROM audit_log WHERE table_name='place' AND record_id=v_place::text AND action='UPDATE';
    INSERT INTO audit_results VALUES ('place edit is logged', CASE WHEN v_n = v_before + 1 THEN 'PASS' ELSE 'FAIL' END);

    -- 2. a rating-only change is NOT logged
    v_before := v_n;
    UPDATE place SET avg_rating = 4.9, review_count = review_count + 1 WHERE place_id = v_place;
    SELECT count(*) INTO v_n FROM audit_log WHERE table_name='place' AND record_id=v_place::text AND action='UPDATE';
    INSERT INTO audit_results VALUES ('rating-only update is not logged', CASE WHEN v_n = v_before THEN 'PASS' ELSE 'FAIL' END);

    -- 3. editing a fare is logged
    SELECT edge_id INTO v_edge FROM edge ORDER BY edge_id LIMIT 1;
    SELECT count(*) INTO v_before FROM audit_log WHERE table_name='edge' AND record_id=v_edge::text;
    UPDATE edge SET fare = fare + 5 WHERE edge_id = v_edge;
    SELECT count(*) INTO v_n FROM audit_log WHERE table_name='edge' AND record_id=v_edge::text;
    INSERT INTO audit_results VALUES ('edge fare change is logged', CASE WHEN v_n = v_before + 1 THEN 'PASS' ELSE 'FAIL' END);

    -- 4. deleting a place is logged
    INSERT INTO place(name, category_id, lat, lon, price_level, node_id)
    SELECT 'Audit Test Place', category_id, lat, lon, 1, node_id FROM place ORDER BY place_id LIMIT 1
    RETURNING place_id INTO v_place;
    DELETE FROM place WHERE place_id = v_place;
    SELECT count(*) INTO v_n FROM audit_log WHERE table_name='place' AND record_id=v_place::text AND action IN ('INSERT','DELETE');
    INSERT INTO audit_results VALUES ('place insert and delete are logged', CASE WHEN v_n = 2 THEN 'PASS' ELSE 'FAIL' END);
END $$;

SELECT * FROM audit_results;
ROLLBACK;