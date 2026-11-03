-- recovery/03_verify.sql   step 4: after the server has restarted
-- Expected: only the committed row. The uncommitted row is gone (Atomicity).
SELECT * FROM recovery_demo.payment;
-- Proof that recovery ran: look at the server log for
--   "database system was not properly shut down; automatic recovery in progress"
--   "redo starts at ..."  /  "redo done at ..."
-- Cleanup when finished:  DROP SCHEMA recovery_demo CASCADE;
