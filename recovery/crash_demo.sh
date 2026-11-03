#!/usr/bin/env bash
# recovery/crash_demo.sh   OPTIONAL: automated version of the crash demo (Linux / macOS / WSL)
# Usage (from the repo root):  bash recovery/crash_demo.sh
# Uses the usual psql environment variables (PGHOST, PGPORT, PGUSER, PGDATABASE). Defaults: database tripgraph.
# What it does: commits one row, opens a transaction with a second row that is never committed,
# kills that session's backend with SIGKILL (kill -9), waits for PostgreSQL to recover from the WAL
# by itself, then shows which rows survived.
set -euo pipefail
export PGDATABASE="${PGDATABASE:-tripgraph}"
PSQL="psql -X -v ON_ERROR_STOP=1 -q"

echo "== 1. setup: one committed row =="
$PSQL -f recovery/01_setup.sql

echo "== 2. open a transaction, insert a row, do NOT commit, keep the session alive =="
# A named pipe keeps psql's input open, so the transaction stays open until we kill it.
FIFO=$(mktemp -u /tmp/recovery_fifo.XXXXXX); mkfifo "$FIFO"
$PSQL -t -A < "$FIFO" > /dev/null 2>&1 &
SESSION_PID=$!
exec 9> "$FIFO"
cat recovery/02_uncommitted_then_wait.sql >&9
sleep 2
BACKEND_PID=$($PSQL -t -A -c "SELECT pid FROM pg_stat_activity WHERE state = 'idle in transaction' AND datname = current_database() ORDER BY xact_start LIMIT 1")
echo "backend pid of the open transaction: $BACKEND_PID"

echo "== 3. kill -9 that backend (simulated crash) =="
kill -9 "$BACKEND_PID"
exec 9>&-; rm -f "$FIFO"; wait "$SESSION_PID" 2>/dev/null || true

echo "== 4. wait for automatic crash recovery (WAL replay) =="
for i in $(seq 1 30); do
  if $PSQL -c "SELECT 1" >/dev/null 2>&1; then break; fi
  sleep 1
done

echo "== 5. verify: expect ONLY the committed row =="
$PSQL -f recovery/03_verify.sql
echo "Now check the server log for 'automatic recovery in progress' and 'redo done'."
