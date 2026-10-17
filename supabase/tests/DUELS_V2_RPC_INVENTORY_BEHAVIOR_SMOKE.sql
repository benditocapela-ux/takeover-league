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
ROLLBACK;
