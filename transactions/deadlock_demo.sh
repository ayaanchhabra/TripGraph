#!/bin/bash
# transactions/deadlock_demo.sh -- runs the deadlock demo automatically with two psql sessions.
# Usage:  bash transactions/deadlock_demo.sh tripgraph [db_user]
# Changes nothing: UPDATE place SET name = name keeps the value, and every session ends
# in ROLLBACK (or is aborted by PostgreSQL).

DB=${1:-tripgraph}
USR=${2:-$(whoami)}
P="psql -X -q -d $DB -U $USR -v ON_ERROR_STOP=1"

read P1 P2 <<< "$($P -At -F' ' -c 'SELECT min(place_id), max(place_id) FROM (SELECT place_id FROM place ORDER BY place_id LIMIT 2) t')"
if [ -z "$P1" ] || [ "$P1" = "$P2" ]; then echo "Need at least two places in the place table."; exit 1; fi
echo "Using place $P1 and place $P2"

run_pair () {   # $1 = first place for A, $2 = second for A, $3 = first for B, $4 = second for B
    ( $P -c "BEGIN" -c "UPDATE place SET name = name WHERE place_id = $1" -c "SELECT pg_sleep(2)" \
         -c "UPDATE place SET name = name WHERE place_id = $2" -c "ROLLBACK" > /tmp/dl_A.txt 2>&1
      echo "$?" > /tmp/dl_A.rc ) &
    ( $P -c "BEGIN" -c "UPDATE place SET name = name WHERE place_id = $3" -c "SELECT pg_sleep(2)" \
         -c "UPDATE place SET name = name WHERE place_id = $4" -c "ROLLBACK" > /tmp/dl_B.txt 2>&1
      echo "$?" > /tmp/dl_B.rc ) &
    wait
    for s in A B; do
        if grep -q "deadlock detected" /tmp/dl_$s.txt; then echo "  Session $s: ABORTED by PostgreSQL (deadlock detected)"
        elif [ "$(cat /tmp/dl_$s.rc)" = "0" ]; then echo "  Session $s: finished normally"
        else echo "  Session $s: failed:"; sed 's/^/    /' /tmp/dl_$s.txt; fi
    done
}

echo; echo "PART 1: opposite lock order  (A: $P1 then $P2, B: $P2 then $P1)"
run_pair $P1 $P2 $P2 $P1
echo; echo "PART 2: same lock order      (A: $P1 then $P2, B: $P1 then $P2)"
run_pair $P1 $P2 $P1 $P2
echo; echo "Expected: Part 1 shows one session aborted by a deadlock, Part 2 shows both finishing normally."
