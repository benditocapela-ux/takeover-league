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
 -- A boxer must not impersonate another challenger.
 BEGIN
  PERFORM public.duel_v2_invite(b,a,7);
  RAISE EXCEPTION 'Boxer impersonated another challenger';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Boxer impersonated another challenger' THEN RAISE; END IF;
  IF SQLERRM NOT LIKE 'Boxer may only challenge on own behalf%' THEN
   RAISE EXCEPTION 'Unexpected impersonation error: %',SQLERRM;
  END IF;
 END;
 duel:=public.duel_v2_invite(a,b,7);
 -- A challenger cannot accept their own invitation.
 BEGIN
  PERFORM public.duel_v2_respond(duel,true);
  RAISE EXCEPTION 'Challenger accepted own invitation';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Challenger accepted own invitation' THEN RAISE; END IF;
 END;
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
 -- An unauthenticated caller cannot respond, even with a known duel UUID.
 PERFORM set_config('test.auth_uid','',true);
 BEGIN
  PERFORM public.duel_v2_respond(duel,true);
  RAISE EXCEPTION 'Unauthenticated caller responded to invitation';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Unauthenticated caller responded to invitation' THEN RAISE; END IF;
 END;
 PERFORM set_config('test.auth_uid','10000000-0000-0000-0000-0000000000b2',true);
 result:=public.duel_v2_respond(duel,true);
 IF result<>'active' THEN RAISE EXCEPTION 'Expected active, got %',result; END IF;
 -- A completed period must not block a fresh invitation for the same pair.
 UPDATE public.league_duels SET accepted_at=now()-interval '8 days',
   ends_at=now()-interval '1 day' WHERE id=duel;
 PERFORM set_config('test.auth_uid','10000000-0000-0000-0000-0000000000a1',true);
 IF public.duel_v2_invite(a,b,7) IS NULL THEN
  RAISE EXCEPTION 'Rematch invitation missing';
 END IF;
 IF (SELECT status FROM public.league_duels WHERE id=duel)<>'awaiting_reviews' THEN
  RAISE EXCEPTION 'Completed duel not retained for settlement';
 END IF;
 -- A pending rematch may be declined without changing the old duel.
 PERFORM set_config('test.auth_uid','10000000-0000-0000-0000-0000000000b2',true);
 IF public.duel_v2_respond(
  (SELECT id FROM public.league_duels WHERE status='pending' AND challenger_id=a AND opponent_id=b LIMIT 1),
  false
 )<>'declined' THEN
  RAISE EXCEPTION 'Rematch decline failed';
 END IF;
 IF (SELECT status FROM public.league_duels WHERE id=duel)<>'awaiting_reviews' THEN
  RAISE EXCEPTION 'Declining rematch changed original duel';
 END IF;
 IF (SELECT count(*) FROM public.league_duel_events WHERE duel_id=duel)<>2 THEN
  RAISE EXCEPTION 'Expected invitation and acceptance events';
 END IF;
END $test$;
ROLLBACK;
