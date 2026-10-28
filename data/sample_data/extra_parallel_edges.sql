-- data/sample_data/extra_parallel_edges.sql
-- Adds faster-but-paid alternatives next to two existing walking edges, so that
-- the cheapest_edges view has real choices to show in the demo.
--   nodes 1 -> 2: walk (Rs 0, 8 min)  +  e-rickshaw (Rs 20, 3 min)  +  auto (Rs 40, 3 min)
--   nodes 1 -> 8: walk (Rs 0, 5 min)  +  e-rickshaw (Rs 10, 2 min)
-- Safe to run more than once: a row is only added if that node pair and mode do not exist yet,
-- and only if the walking edge it sits next to exists.

INSERT INTO edge (from_node, to_node, mode, distance_m, time_min, fare)
SELECT v.from_node, v.to_node, v.mode, v.distance_m, v.time_min, v.fare
FROM (VALUES
        (1, 2, 'erickshaw', 650, 3, 20.00),
        (1, 2, 'auto',      700, 3, 40.00),
        (1, 8, 'erickshaw', 450, 2, 10.00)
     ) AS v(from_node, to_node, mode, distance_m, time_min, fare)
WHERE EXISTS (SELECT 1 FROM edge w
              WHERE w.from_node = v.from_node AND w.to_node = v.to_node AND w.mode = 'walk')
  AND NOT EXISTS (SELECT 1 FROM edge x
                  WHERE x.from_node = v.from_node AND x.to_node = v.to_node AND x.mode = v.mode);
