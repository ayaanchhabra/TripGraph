# REHEARSAL results (not for the report)
Produced on a stand-in schema (`_scratch_test/stub_schema.sql`) on a cloud machine, only to prove the
scripts run end to end. Absolute times will differ on your laptop and on the actual project schema.
Re-run `run_benchmarks.sql` yourself; it writes the real files into `../results/`. Use YOUR numbers in the report.
Pattern seen (matches the expected pattern in ../README.md): Q1 ~5x faster with B-tree; Q2 and Q3 hundreds of times faster;
Q4 only fast in the GIN stage (~110 ms -> ~1 ms); Q5 stays ~45-60 ms whatever the indexes (that is the denormalization argument).
