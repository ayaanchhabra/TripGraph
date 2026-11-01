#!/usr/bin/env bash
# scripts/setup_db.sh
# Builds the whole TripGraph database from scratch, in the right order, then runs every test.
# Run from anywhere:   bash scripts/setup_db.sh                    (database "tripgraph", your own user)
#                      bash scripts/setup_db.sh mydb myuser
#                      bash scripts/setup_db.sh tripgraph postgres --reset     (drop and rebuild)
# Needs PostgreSQL 15 or later and a user who may create databases and roles (a superuser is simplest).
# It stops at the first file that fails and says which one.
# It refuses to touch an existing database unless you add --reset, so it cannot wipe your work by accident.

DB="tripgraph"
USER_NAME="$(whoami)"
RESET=0
POS=0
for arg in "$@"; do
  case "$arg" in
    --reset) RESET=1 ;;
    *) POS=$((POS+1)); [ "$POS" -eq 1 ] && DB="$arg"; [ "$POS" -eq 2 ] && USER_NAME="$arg" ;;
  esac
done

cd "$(dirname "$0")/.." || exit 1          # the repo root: the data loaders use paths relative to it

PSQL_ADMIN="psql -X -q -U $USER_NAME -d postgres"
if $PSQL_ADMIN -tAc "SELECT 1 FROM pg_database WHERE datname = '$DB'" | grep -q 1; then
  if [ "$RESET" -eq 1 ]; then
    echo "Dropping database $DB ..."
    $PSQL_ADMIN -c "DROP DATABASE $DB" || exit 1
  else
    echo "Database $DB already exists. Use --reset to drop it and rebuild, or pick another name."
    exit 1
  fi
fi
echo "Creating database $DB ..."
$PSQL_ADMIN -c "CREATE DATABASE $DB" || exit 1

FILES=(
  security/01_roles.sql
  schema/01_tables.sql
  schema/02_constraints.sql
  schema/03_seed_reference.sql
  schema/04_favorites.sql
  triggers/01_review_rating.sql
  triggers/02_trip_leg_continuity.sql
  triggers/03_audit_log.sql
  queries/views/01_top_rated_places.sql
  queries/views/02_open_now.sql
  queries/trips/01_cheapest_route.sql
  queries/views/cheapest_edges.sql
  queries/views/freshers_guide_cheap_eats.sql
  queries/procedures/01_similar_places.sql
  data/load_all.sql
  data/sample_data/load_sample.sql
  data/sample_data/extra_parallel_edges.sql
  data/sample_data/extra_places.sql
  indexing/fulltext_search.sql
  indexing/public_indexes.sql
)
# Optional files: loaded only if they exist (they are added by later tasks).
for opt in queries/views/03_trending_this_month.sql; do
  [ -f "$opt" ] && FILES+=("$opt")
done
FILES+=(security/02_grants.sql)             # always last: it grants rights on everything created above

for f in "${FILES[@]}"; do
  echo "loading $f"
  if ! psql -X -q -U "$USER_NAME" -d "$DB" -v ON_ERROR_STOP=1 -f "$f" > /tmp/tripgraph_setup.log 2>&1; then
    echo "FAILED: $f"
    grep -E "ERROR|FATAL" /tmp/tripgraph_setup.log | head -5
    exit 1
  fi
done

echo
echo "Database $DB is ready. Running all tests ..."
bash tests/run_tests.sh "$DB" "$USER_NAME" > /tmp/tripgraph_tests.log 2>&1
tail -3 /tmp/tripgraph_tests.log
grep -q "ALL TESTS PASSED" /tmp/tripgraph_tests.log
