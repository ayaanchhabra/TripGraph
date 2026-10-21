# Crash recovery demo (A, OPTIONAL, viva step 7)

## Concepts in plain language
- **Atomicity**: a transaction either happens completely or not at all.
- **Durability**: once COMMIT returns, the data survives a crash.
- **WAL (write-ahead log)**: before PostgreSQL changes a data page, it writes a description of the change to a
  log file and flushes it to disk. After a crash it **replays** the log from the last checkpoint (**redo**), so
  committed changes are restored. A transaction with no COMMIT record is simply not visible afterwards.
- **Checkpoint**: a moment when all dirty pages are written to disk; recovery only has to replay the log after it.
- `kill -9` (SIGKILL) gives the process no chance to clean up. It is the closest we can get to a power cut.
- PostgreSQL uses **no-force / steal** buffer management with **redo** logging, and MVCC means uncommitted rows
  are just invisible, so there is no separate "undo" pass. (Textbook log-based recovery has redo + undo.)

## Two ways to run it
**Automatic (Linux / macOS / WSL):** `bash recovery/crash_demo.sh` from the repo root.
**Manual (good for the viva, you explain each step):**
1. Terminal 1: `psql -d tripgraph -f recovery/01_setup.sql` (one committed row).
2. Terminal 1: `psql -d tripgraph -f recovery/02_uncommitted_then_wait.sql`. It prints `kill_this_pid`. Leave the session open, do not COMMIT.
3. Terminal 2: `kill -9 <kill_this_pid>`  (on Windows: `taskkill /F /PID <pid>`).
   PostgreSQL notices a backend died abnormally, restarts all its processes and runs crash recovery by itself.
4. Terminal 2: `psql -d tripgraph -f recovery/03_verify.sql`. Expect ONE row (the committed one).
5. Show the server log lines: `database system was not properly shut down; automatic recovery in progress`,
   `redo starts at ...`, `redo done at ...`.
Cleanup: `DROP SCHEMA recovery_demo CASCADE;`

Tested on PostgreSQL 16: committed row survived, uncommitted row vanished, log showed redo.

## Stronger variant (optional)
Kill the **postmaster** instead (`kill -9` the PID in `postmaster.pid`, or `pg_ctl ... stop -m immediate`) and start
the server again with `pg_ctl start`; recovery runs at startup. Needs file access to the data directory, so it is
harder on a shared machine; the backend kill above is enough for the demo.

## Viva questions
1. Why is the committed row still there? (Its COMMIT record was flushed to the WAL before COMMIT returned.)
2. Why did the uncommitted row disappear? (No commit record; MVCC treats its xid as aborted.)
3. What does `fsync` / `synchronous_commit` control, and what happens if you turn them off? (Durability is lost on a crash.)
4. What is a checkpoint and why does it shorten recovery?
5. Difference between this and rollback? (Rollback is requested by the user; recovery is automatic after a crash.)
