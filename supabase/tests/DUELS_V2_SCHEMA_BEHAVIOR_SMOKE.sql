-- Disposable CI database only. Tests actual constraint behavior, not metadata.
BEGIN;
INSERT INTO public.profiles(id,role,is_active) VALUES
 ('00000000-0000-0000-0000-0000000000a1','boxer',true),
 ('00000000-0000-0000-0000-0000000000b2','boxer',true);

DO $duel_smoke$
DECLARE
 a uuid := '00000000-0000-0000-0000-0000000000a1';
 b uuid := '00000000-0000-0000-0000-0000000000b2';
BEGIN
 INSERT INTO public.league_duels(challenger_id,opponent_id,status,duration_days,accepted_at,ends_at)
 VALUES(a,b,'active',7,now(),now()+interval '7 days');
 BEGIN
  INSERT INTO public.league_duels(challenger_id,opponent_id,status,duration_days,accepted_at,ends_at)
  VALUES(b,a,'active',7,now(),now()+interval '7 days');
  RAISE EXCEPTION 'Duplicate reversed active pair was accepted';
 EXCEPTION WHEN unique_violation THEN NULL;
 END;

 INSERT INTO public.league_duels(challenger_id,opponent_id,status,duration_days)
 VALUES(a,b,'pending',7);
 BEGIN
  INSERT INTO public.league_duels(challenger_id,opponent_id,status,duration_days)
  VALUES(b,a,'pending',14);
  RAISE EXCEPTION 'Duplicate reversed pending pair was accepted';
 EXCEPTION WHEN unique_violation THEN NULL;
 END;

 BEGIN
  INSERT INTO public.league_duels(challenger_id,opponent_id,status,duration_days)
  VALUES(a,a,'pending',7);
  RAISE EXCEPTION 'Self-duel was accepted';
 EXCEPTION WHEN check_violation THEN NULL;
 END;

 IF pg_catalog.has_table_privilege('authenticated','public.league_duels','SELECT')
    OR pg_catalog.has_table_privilege('authenticated','public.league_duels','INSERT')
    OR pg_catalog.has_table_privilege('anon','public.league_duels','SELECT') THEN
  RAISE EXCEPTION 'Direct client access to duel tables must be revoked';
 END IF;
END $duel_smoke$;
ROLLBACK;
