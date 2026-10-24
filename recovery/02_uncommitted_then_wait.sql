-- recovery/02_uncommitted_then_wait.sql   (A)   step 2
-- Run in a psql session and LEAVE IT OPEN. The transaction is never committed.
-- It prints this session's backend process id: that is the process you kill in step 3.
BEGIN;
INSERT INTO recovery_demo.payment(note) VALUES ('UNCOMMITTED, should vanish after crash');
SELECT pg_backend_pid() AS kill_this_pid;
SELECT * FROM recovery_demo.payment;   -- this session sees 2 rows (its own uncommitted change)
-- Do NOT type COMMIT. Go to another terminal.
