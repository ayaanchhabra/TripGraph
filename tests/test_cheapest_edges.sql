-- tests/test_cheapest_edges.sql (read-only). Every row should say PASS.
SELECT 'one row per node pair' AS check_name,
       CASE WHEN (SELECT count(*) FROM cheapest_edges)
               = (SELECT count(*) FROM (SELECT DISTINCT from_node, to_node FROM edge) d)
            THEN 'PASS' ELSE 'FAIL' END AS result
UNION ALL
SELECT 'no pair appears twice',
       CASE WHEN NOT EXISTS (SELECT 1 FROM cheapest_edges GROUP BY from_node, to_node HAVING count(*) > 1)
            THEN 'PASS' ELSE 'FAIL' END
UNION ALL
SELECT 'every kept edge has the lowest fare for its pair',
       CASE WHEN NOT EXISTS (
            SELECT 1 FROM cheapest_edges c
            WHERE EXISTS (SELECT 1 FROM edge e
                          WHERE e.from_node = c.from_node AND e.to_node = c.to_node AND e.fare < c.fare))
            THEN 'PASS' ELSE 'FAIL' END
UNION ALL
SELECT 'on a fare tie the shorter time is kept',
       CASE WHEN NOT EXISTS (
            SELECT 1 FROM cheapest_edges c
            WHERE EXISTS (SELECT 1 FROM edge e
                          WHERE e.from_node = c.from_node AND e.to_node = c.to_node
                            AND e.fare = c.fare AND e.time_min < c.time_min))
            THEN 'PASS' ELSE 'FAIL' END
UNION ALL
SELECT 'alternatives = other edges between the same pair',
       CASE WHEN NOT EXISTS (
            SELECT 1 FROM cheapest_edges c
            WHERE c.alternatives <> (SELECT count(*) - 1 FROM edge e
                                     WHERE e.from_node = c.from_node AND e.to_node = c.to_node))
            THEN 'PASS' ELSE 'FAIL' END;