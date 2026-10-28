-- tests/test_freshers_guide.sql (rolls back everything it creates). Every row should say PASS.
BEGIN;
CREATE TEMP TABLE fg_results(check_name text, result text) ON COMMIT DROP;

DO $$
DECLARE
    v_cat int; v_node int;
    a int; b int; c int; d int; e int; f int;
    v_n int; v_r1 int; v_r2 int; v_r3 int;
BEGIN
    SELECT category_id, node_id INTO v_cat, v_node FROM place ORDER BY place_id LIMIT 1;

    -- a: price 1, rating 4.5      b: price 3 (too dear)       c: price 2 with discount, rating 4.0
    -- d: price 2 without discount e: price 1 but NOT a food outlet
    -- f: price 1, same cuisine as a, rating 3.0
    INSERT INTO place(name,category_id,lat,lon,price_level,node_id,avg_rating,review_count,student_discount)
        VALUES ('FG A',v_cat,28.6,77.0,1,v_node,4.5,10,false) RETURNING place_id INTO a;
    INSERT INTO place(name,category_id,lat,lon,price_level,node_id,avg_rating,review_count,student_discount)
        VALUES ('FG B',v_cat,28.6,77.0,3,v_node,5.0,10,true)  RETURNING place_id INTO b;
    INSERT INTO place(name,category_id,lat,lon,price_level,node_id,avg_rating,review_count,student_discount)
        VALUES ('FG C',v_cat,28.6,77.0,2,v_node,4.0,10,true)  RETURNING place_id INTO c;
    INSERT INTO place(name,category_id,lat,lon,price_level,node_id,avg_rating,review_count,student_discount)
        VALUES ('FG D',v_cat,28.6,77.0,2,v_node,4.9,10,false) RETURNING place_id INTO d;
    INSERT INTO place(name,category_id,lat,lon,price_level,node_id,avg_rating,review_count,student_discount)
        VALUES ('FG E',v_cat,28.6,77.0,1,v_node,4.9,10,false) RETURNING place_id INTO e;
    INSERT INTO place(name,category_id,lat,lon,price_level,node_id,avg_rating,review_count,student_discount)
        VALUES ('FG F',v_cat,28.6,77.0,1,v_node,3.0,10,false) RETURNING place_id INTO f;

    INSERT INTO food_outlet(place_id,cuisine,is_veg) VALUES
        (a,'FGcuisine',true),(b,'FGcuisine',true),(c,'FGcuisine',false),(d,'FGcuisine',false),(f,'FGcuisine',true);

    SELECT count(*) INTO v_n FROM freshers_guide_cheap_eats WHERE place_id = a;
    INSERT INTO fg_results VALUES ('price 1 food place is listed', CASE WHEN v_n=1 THEN 'PASS' ELSE 'FAIL' END);

    SELECT count(*) INTO v_n FROM freshers_guide_cheap_eats WHERE place_id = c;
    INSERT INTO fg_results VALUES ('price 2 with student discount is listed', CASE WHEN v_n=1 THEN 'PASS' ELSE 'FAIL' END);

    SELECT count(*) INTO v_n FROM freshers_guide_cheap_eats WHERE place_id = d;
    INSERT INTO fg_results VALUES ('price 2 without discount is not listed', CASE WHEN v_n=0 THEN 'PASS' ELSE 'FAIL' END);

    SELECT count(*) INTO v_n FROM freshers_guide_cheap_eats WHERE place_id = b;
    INSERT INTO fg_results VALUES ('price 3 is not listed even with discount', CASE WHEN v_n=0 THEN 'PASS' ELSE 'FAIL' END);

    SELECT count(*) INTO v_n FROM freshers_guide_cheap_eats WHERE place_id = e;
    INSERT INTO fg_results VALUES ('cheap place that is not a food outlet is not listed', CASE WHEN v_n=0 THEN 'PASS' ELSE 'FAIL' END);

    SELECT cuisine_rank INTO v_r1 FROM freshers_guide_cheap_eats WHERE place_id = a;
    SELECT cuisine_rank INTO v_r2 FROM freshers_guide_cheap_eats WHERE place_id = c;
    SELECT cuisine_rank INTO v_r3 FROM freshers_guide_cheap_eats WHERE place_id = f;
    INSERT INTO fg_results VALUES ('cuisine rank follows rating (4.5 -> 1, 4.0 -> 2, 3.0 -> 3)',
        CASE WHEN v_r1=1 AND v_r2=2 AND v_r3=3 THEN 'PASS' ELSE 'FAIL' END);

    SELECT count(*) INTO v_n FROM (SELECT cuisine, cuisine_rank FROM freshers_guide_cheap_eats
                                   GROUP BY cuisine, cuisine_rank HAVING count(*) > 1) t
        WHERE cuisine = 'FGcuisine';
    INSERT INTO fg_results VALUES ('ranks inside one cuisine are not repeated here', CASE WHEN v_n=0 THEN 'PASS' ELSE 'FAIL' END);

    -- every listed place satisfies the rule, and no place is listed twice
    SELECT count(*) INTO v_n FROM freshers_guide_cheap_eats WHERE NOT (price_level = 1 OR (price_level = 2 AND student_discount));
    INSERT INTO fg_results VALUES ('every listed place meets the price rule', CASE WHEN v_n=0 THEN 'PASS' ELSE 'FAIL' END);

    SELECT count(*) - count(DISTINCT place_id) INTO v_n FROM freshers_guide_cheap_eats;
    INSERT INTO fg_results VALUES ('no place is listed twice', CASE WHEN v_n=0 THEN 'PASS' ELSE 'FAIL' END);
END $$;

SELECT * FROM fg_results;
ROLLBACK;
