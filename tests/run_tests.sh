#!/usr/bin/env bash
# tests/run_tests.sh
# Runs every test file and saves the output in tests/results/ (for the report).
# Run from the repo root:   bash tests/run_tests.sh            (database "tripgraph", user "postgres")
#                           bash tests/run_tests.sh mydb myuser
# The last lines say whether any test failed. The exit code is 1 if one did.
DB="${1:-tripgraph}"
USER_NAME="${2:-postgres}"
mkdir -p tests/results

TESTS=(
  tests/test_constraints.sql
  tests/test_triggers.sql
  tests/test_queries.sql
  tests/test_audit.sql
  tests/test_similar_places.sql
  tests/test_cheapest_edges.sql
  tests/test_freshers_guide.sql
)

RESULT_FILES=()
for f in "${TESTS[@]}"; do
  name="$(basename "$f" .sql)"
  echo "=== $name ==="
  psql -U "$USER_NAME" -d "$DB" -f "$f" 2>&1 | tee "tests/results/$name.txt"
  RESULT_FILES+=("tests/results/$name.txt")
done

# A test failed if a result row ends in FAIL, or if psql reported an error while running a test file.
FAILED=$(cat "${RESULT_FILES[@]}" | grep -cE '\| *FAIL *$|^psql:.*ERROR:')
echo
echo "=============================="
if [ "$FAILED" -eq 0 ]; then
  echo "ALL TESTS PASSED (failed = 0)"
else
  echo "TESTS FAILED: $FAILED failing line(s). Look for FAIL or ERROR in tests/results/"
  exit 1
fi