-- security/01_roles.sql
-- Purpose: creates the roles used for access control (Unit I, DCL).
--   tripgraph_student        group role (NOLOGIN): what a normal student may do
--   tripgraph_admin          group role (NOLOGIN): a student plus moderation rights.
--                            It is made a MEMBER of tripgraph_student, so it inherits everything a
--                            student can do (role inheritance); security/02_grants.sql adds only the extras.
--   tripgraph_demo_student   login role for demos, member of tripgraph_student
--   tripgraph_demo_admin     login role for demos, member of tripgraph_admin
-- How to run (as the database owner or a superuser):
--   psql -U postgres -d tripgraph -v ON_ERROR_STOP=1 -f security/01_roles.sql
-- Re-runnable: a role that already exists is skipped (roles belong to the whole server, not one database).
-- The demo passwords below are for a local classroom demo only. Never reuse them anywhere real.

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'tripgraph_student') THEN
    CREATE ROLE tripgraph_student NOLOGIN;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'tripgraph_admin') THEN
    CREATE ROLE tripgraph_admin NOLOGIN;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'tripgraph_demo_student') THEN
    CREATE ROLE tripgraph_demo_student LOGIN PASSWORD 'demo_student_pw';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'tripgraph_demo_admin') THEN
    CREATE ROLE tripgraph_demo_admin LOGIN PASSWORD 'demo_admin_pw';
  END IF;
END $$;

-- Membership = inheritance. A member automatically gets the rights of the group role.
GRANT tripgraph_student TO tripgraph_admin;        -- admin can do everything a student can
GRANT tripgraph_student TO tripgraph_demo_student;
GRANT tripgraph_admin   TO tripgraph_demo_admin;

\echo 'Roles ready: tripgraph_student, tripgraph_admin, tripgraph_demo_student, tripgraph_demo_admin'
