-- Synthetic, disposable CI database ONLY. Exercises real PL/pgSQL RPC bodies.
BEGIN;
INSERT INTO public.profiles(id,auth_user_id,role,is_active) VALUES
 ('00000000-0000-0000-0000-0000000000a1','10000000-0000-0000-0000-0000000000a1','boxer',true),
 ('00000000-0000-0000-0000-0000000000b2','10000000-0000-0000-0000-0000000000b2','boxer',true),
 ('00000000-0000-0000-0000-0000000000c3','10000000-0000-0000-0000-0000000000c3','coach',true);
UPDATE public.league_feature_flags SET is_enabled=true WHERE feature_key='duels';

DO $test$
DECLARE
 a uuid := '00000000-0000-0000-0000-0000000000a1';
 b uuid := '00000000-0000-0000-0000-0000000000b2';
 duel uuid;
 result text;
BEGIN
 PERFORM set_config('test.auth_uid','10000000-0000-0000-0000-0000000000a1',true);
 BEGIN
  PERFORM public.duel_v2_invite(a,b,NULL);
  RAISE EXCEPTION 'NULL duration was accepted';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='NULL duration was accepted' THEN RAISE; END IF;
 END;
 duel:=public.duel_v2_invite(a,b,7);
 BEGIN
  PERFORM public.duel_v2_invite(b,a,7);
  RAISE EXCEPTION 'Duplicate invitation was accepted';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Duplicate invitation was accepted' THEN RAISE; END IF;
 END;
 PERFORM set_config('test.auth_uid','10000000-0000-0000-0000-0000000000b2',true);
 BEGIN
  PERFORM public.duel_v2_respond(duel,NULL);
  RAISE EXCEPTION 'NULL acceptance was accepted';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='NULL acceptance was accepted' THEN RAISE; END IF;
 END;
 result:=public.duel_v2_respond(duel,true);
 IF result<>'active' THEN RAISE EXCEPTION 'Expected active, got %',result; END IF;
 IF (SELECT count(*) FROM public.league_duel_events WHERE duel_id=duel)<>2 THEN
  RAISE EXCEPTION 'Expected invitation and acceptance events';
 END IF;
END $test$;
ROLLBACK;
