-- Disposable PostgreSQL CI only: verify review RPC inventory semantics.
-- No production function definitions are simulated or certified here.
BEGIN;
CREATE SCHEMA test_shadow;
CREATE FUNCTION test_shadow.review_training() RETURNS void LANGUAGE sql AS 'SELECT NULL::void';
DO $inventory$
DECLARE missing_count integer;
BEGIN
 WITH required(name) AS (
  VALUES ('review_training'),('admin_edit_training'),('admin_edit_training_details')
 )
 SELECT count(*) INTO missing_count
 FROM (
  SELECT r.name, count(p.oid) AS deployed_overloads
  FROM required r
  LEFT JOIN pg_catalog.pg_proc p
   ON p.proname=r.name AND p.pronamespace='public'::pg_catalog.regnamespace
  GROUP BY r.name
 ) results
 WHERE deployed_overloads=0;
 IF missing_count<>3 THEN
  RAISE EXCEPTION 'Non-public review_training must not satisfy public RPC inventory';
 END IF;
END $inventory$;
CREATE FUNCTION public.review_training() RETURNS void LANGUAGE sql AS 'SELECT NULL::void';
DO $inventory$
DECLARE missing_count integer;
DECLARE public_overloads integer;
BEGIN
 WITH required(name) AS (
  VALUES ('review_training'),('admin_edit_training'),('admin_edit_training_details')
 )
 SELECT count(*) FILTER(WHERE deployed_overloads=0),
        max(deployed_overloads) FILTER(WHERE name='review_training')
 INTO missing_count,public_overloads
 FROM (
  SELECT r.name, count(p.oid) AS deployed_overloads
  FROM required r
  LEFT JOIN pg_catalog.pg_proc p
   ON p.proname=r.name AND p.pronamespace='public'::pg_catalog.regnamespace
  GROUP BY r.name
 ) results;
 IF missing_count<>2 OR public_overloads<>1 THEN
  RAISE EXCEPTION 'Public review_training must be counted exactly once';
 END IF;
END $inventory$;
-- Ensure the inventory detects a second public overload rather than treating
-- its existence as a single reviewed function.
CREATE FUNCTION public.review_training(integer) RETURNS void LANGUAGE sql AS 'SELECT NULL::void';
DO $inventory$
DECLARE overloads integer;
BEGIN
 SELECT count(*) INTO overloads
 FROM pg_catalog.pg_proc p
 WHERE p.proname='review_training'
   AND p.pronamespace='public'::pg_catalog.regnamespace;
 IF overloads<>2 THEN
  RAISE EXCEPTION 'All public review_training overloads require inspection';
 END IF;
END $inventory$;
-- Exercise PUBLIC grant detection on a real PostgreSQL function.
-- PUBLIC is a pseudo-role in ACLs, not a named role for has_function_privilege.
DO $acl$
DECLARE allowed boolean;
BEGIN
 SELECT EXISTS (
  SELECT 1 FROM pg_catalog.aclexplode(
   COALESCE(p.proacl,pg_catalog.acldefault('f',p.proowner))
  ) acl WHERE acl.grantee=0 AND acl.privilege_type='EXECUTE'
 ) INTO allowed
 FROM pg_catalog.pg_proc p
 WHERE p.oid='public.review_training()'::pg_catalog.regprocedure;
 IF allowed IS DISTINCT FROM true THEN
  RAISE EXCEPTION 'Default PUBLIC EXECUTE grant not detected';
 END IF;
END $acl$;
REVOKE EXECUTE ON FUNCTION public.review_training() FROM PUBLIC;
DO $acl$
DECLARE allowed boolean;
BEGIN
 SELECT EXISTS (
  SELECT 1 FROM pg_catalog.aclexplode(
   COALESCE(p.proacl,pg_catalog.acldefault('f',p.proowner))
  ) acl WHERE acl.grantee=0 AND acl.privilege_type='EXECUTE'
 ) INTO allowed
 FROM pg_catalog.pg_proc p
 WHERE p.oid='public.review_training()'::pg_catalog.regprocedure;
 IF allowed IS DISTINCT FROM false THEN
  RAISE EXCEPTION 'Revoked PUBLIC EXECUTE still detected';
 END IF;
END $acl$;
ROLLBACK;
