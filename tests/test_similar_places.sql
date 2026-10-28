-- tests/test_similar_places.sql  (rolls back everything it creates). Every row should say PASS.
BEGIN;
CREATE TEMP TABLE sp_results(check_name text, result text) ON COMMIT DROP;

DO $$
DECLARE
    v_cat int; v_node int; v_a int; v_b int; v_c int; v_d int; v_e int; v_first int; v_n int; v_bad int;
BEGIN
    SELECT category_id, node_id INTO v_cat, v_node FROM place ORDER BY place_id LIMIT 1;

    -- A: target (price 2). B: price 2, rating 4. C: price 3, rating 5. D: price 1 with discount.
    -- E: another category, must never appear.
    INSERT INTO place(name, category_id, lat, lon, price_level, node_id, avg_rating, review_count)
        VALUES ('SP Target', v_cat, 28.6, 77.0, 2, v_node, 0, 0) RETURNING place_id INTO v_a;
    INSERT INTO place(name, category_id, lat, lon, price_level, node_id, avg_rating, review_count)
        VALUES ('SP Same price', v_cat, 28.6, 77.0, 2, v_node, 4.0, 3) RETURNING place_id INTO v_b;
    INSERT INTO place(name, category_id, lat, lon, price_level, node_id, avg_rating, review_count)
        VALUES ('SP Higher price', v_cat, 28.6, 77.0, 3, v_node, 5.0, 3) RETURNING place_id INTO v_c;
    INSERT INTO place(name, category_id, lat, lon, price_level, node_id, avg_rating, review_count, student_discount)
        VALUES ('SP Cheaper discount', v_cat, 28.6, 77.0, 1, v_node, 3.0, 3, true) RETURNING place_id INTO v_d;
    INSERT INTO place(name, category_id, lat, lon, price_level, node_id)
        SELECT 'SP Other category', category_id, 28.6, 77.0, 2, v_node
        FROM category WHERE category_id <> v_cat ORDER BY category_id LIMIT 1 RETURNING place_id INTO v_e;

    SELECT place_id INTO v_first FROM similar_places(v_a) LIMIT 1;
    INSERT INTO sp_results VALUES ('same price ranks first', CASE WHEN v_first = v_b THEN 'PASS' ELSE 'FAIL' END);

    SELECT count(*) INTO v_n FROM similar_places(v_a, 10) WHERE place_id = v_a;
    INSERT INTO sp_results VALUES ('the place itself is never returned', CASE WHEN v_n = 0 THEN 'PASS' ELSE 'FAIL' END);

    SELECT count(*) INTO v_n FROM similar_places(v_a, 10) WHERE place_id = v_e;
    INSERT INTO sp_results VALUES ('other categories are never returned', CASE WHEN v_n = 0 THEN 'PASS' ELSE 'FAIL' END);

    SELECT count(*) INTO v_n FROM similar_places(v_a, 10) WHERE place_id IN (v_b, v_c, v_d);
    INSERT INTO sp_results VALUES ('prices within one level are returned', CASE WHEN v_n = 3 THEN 'PASS' ELSE 'FAIL' END);

    SELECT count(*) INTO v_n FROM similar_places(v_a, 10, true);
    SELECT count(*) INTO v_bad FROM similar_places(v_a, 10, true) WHERE NOT student_discount;
    INSERT INTO sp_results VALUES ('discount filter keeps only discount places', CASE WHEN v_n >= 1 AND v_bad = 0 THEN 'PASS' ELSE 'FAIL' END);

    SELECT count(*) INTO v_n FROM similar_places(v_a, 1);
    INSERT INTO sp_results VALUES ('limit 1 returns one row', CASE WHEN v_n = 1 THEN 'PASS' ELSE 'FAIL' END);

    SELECT count(*) INTO v_n FROM similar_places(-1);
    INSERT INTO sp_results VALUES ('unknown place id returns no rows', CASE WHEN v_n = 0 THEN 'PASS' ELSE 'FAIL' END);
END $$;

SELECT * FROM sp_results;
ROLLBACK;
