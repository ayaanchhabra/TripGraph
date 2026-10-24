#!/usr/bin/env bash
# tests/run_tests.sh   (K)
# Runs every test file and saves the output in tests/results/ (for the report).
# Run from the repo root:   bash tests/run_tests.sh            (database "tripgraph", user "postgres")
#                           bash tests/run_tests.sh mydb myuser
DB="${1:-tripgraph}"
USER_NAME="${2:-postgres}"
mkdir -p tests/results
for f in tests/test_constraints.sql tests/test_triggers.sql tests/test_queries.sql; do
  name="$(basename "$f" .sql)"
  echo "=== $name ==="
  psql -U "$USER_NAME" -d "$DB" -f "$f" 2>&1 | tee "tests/results/$name.txt"
done
