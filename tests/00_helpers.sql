-- tests/00_helpers.sql   (K)
-- Tiny test toolkit used by the other test files (loaded with \i, inside a transaction).
--   expect_ok(area, test, sql)               the statement must succeed
--   expect_fail(area, test, sql, text)       the statement must FAIL with an error containing `text`
--   expect_eq(area, test, query, expected)   the query's single value must equal `expected`
-- Results go into the temp table test_results; every test file ends with ROLLBACK,
-- so nothing is ever saved to the real tables.

CREATE TEMP TABLE test_results (
  n      SERIAL,
  area   TEXT,
  test   TEXT,
  status TEXT,
  detail TEXT
);

CREATE FUNCTION pg_temp.expect_ok(p_area TEXT, p_test TEXT, p_sql TEXT) RETURNS VOID AS $$
BEGIN
  EXECUTE p_sql;
  INSERT INTO test_results(area, test, status) VALUES (p_area, p_test, 'PASS');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO test_results(area, test, status, detail)
  VALUES (p_area, p_test, 'FAIL', 'unexpected error: ' || SQLERRM);
END;
$$ LANGUAGE plpgsql;

CREATE FUNCTION pg_temp.expect_fail(p_area TEXT, p_test TEXT, p_sql TEXT, p_expect TEXT) RETURNS VOID AS $$
BEGIN
  BEGIN
    EXECUTE p_sql;
    RAISE EXCEPTION 'TEST_DID_NOT_FAIL';   -- undoes the statement's effect too
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM = 'TEST_DID_NOT_FAIL' THEN
      INSERT INTO test_results(area, test, status, detail)
      VALUES (p_area, p_test, 'FAIL', 'statement was accepted but should have been rejected');
    ELSIF position(lower(p_expect) IN lower(SQLERRM)) > 0 THEN
      INSERT INTO test_results(area, test, status) VALUES (p_area, p_test, 'PASS');
    ELSE
      INSERT INTO test_results(area, test, status, detail)
      VALUES (p_area, p_test, 'FAIL', 'rejected for a different reason: ' || SQLERRM);
    END IF;
  END;
END;
$$ LANGUAGE plpgsql;

CREATE FUNCTION pg_temp.expect_eq(p_area TEXT, p_test TEXT, p_query TEXT, p_expected TEXT) RETURNS VOID AS $$
DECLARE v TEXT;
BEGIN
  EXECUTE p_query INTO v;
  IF v IS NOT DISTINCT FROM p_expected THEN
    INSERT INTO test_results(area, test, status) VALUES (p_area, p_test, 'PASS');
  ELSE
    INSERT INTO test_results(area, test, status, detail)
    VALUES (p_area, p_test, 'FAIL', 'expected [' || p_expected || '] but got [' || COALESCE(v, 'NULL') || ']');
  END IF;
EXCEPTION WHEN OTHERS THEN
  INSERT INTO test_results(area, test, status, detail)
  VALUES (p_area, p_test, 'FAIL', 'query error: ' || SQLERRM);
END;
$$ LANGUAGE plpgsql;
