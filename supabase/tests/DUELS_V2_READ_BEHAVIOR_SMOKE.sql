-- Disposable PostgreSQL test only.
BEGIN;
INSERT INTO public.profiles(id,auth_user_id,display_name,role,is_active) VALUES
 ('00000000-0000-0000-0000-0000000000a1','10000000-0000-0000-0000-0000000000a1','Boxer A','boxer',true),
 ('00000000-0000-0000-0000-0000000000b2','10000000-0000-0000-0000-0000000000b2','Boxer B','boxer',true),
 ('00000000-0000-0000-0000-0000000000c3','10000000-0000-0000-0000-0000000000c3','Coach','coach',true),
 ('00000000-0000-0000-0000-0000000000d4','10000000-0000-0000-0000-0000000000d4','Boxer D','boxer',true);
INSERT INTO public.league_duels(challenger_id,opponent_id,duration_days)
VALUES('00000000-0000-0000-0000-0000000000a1','00000000-0000-0000-0000-0000000000b2',7);
UPDATE public.league_feature_flags SET is_enabled=true WHERE feature_key='duels';
DO $test$
DECLARE n integer;
BEGIN
 PERFORM set_config('test.auth_uid','10000000-0000-0000-0000-0000000000a1',true);
 SELECT count(*) INTO n FROM public.duel_v2_list_mine();
 IF n<>1 THEN RAISE EXCEPTION 'Participant read failed'; END IF;
 PERFORM set_config('test.auth_uid','10000000-0000-0000-0000-0000000000d4',true);
 SELECT count(*) INTO n FROM public.duel_v2_list_mine();
 IF n<>0 THEN RAISE EXCEPTION 'Unrelated boxer read failed'; END IF;
 PERFORM set_config('test.auth_uid','10000000-0000-0000-0000-0000000000c3',true);
 SELECT count(*) INTO n FROM public.duel_v2_list_mine();
 IF n<>1 THEN RAISE EXCEPTION 'Coach read failed'; END IF;
 SELECT count(*) INTO n FROM public.duel_v2_eligible_boxers();
 IF n<>3 THEN RAISE EXCEPTION 'Eligible list must include only three active boxers'; END IF;
 UPDATE public.profiles SET is_active=false
 WHERE id='00000000-0000-0000-0000-0000000000d4';
 SELECT count(*) INTO n FROM public.duel_v2_eligible_boxers();
 IF n<>2 THEN RAISE EXCEPTION 'Inactive boxer still eligible'; END IF;
 UPDATE public.league_feature_flags SET is_enabled=false WHERE feature_key='duels';
 BEGIN
  PERFORM public.duel_v2_list_mine();
  RAISE EXCEPTION 'Read RPC bypassed disabled flag';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Read RPC bypassed disabled flag' THEN RAISE; END IF;
 END;
 BEGIN
  PERFORM public.duel_v2_eligible_boxers();
  RAISE EXCEPTION 'Eligibility RPC bypassed disabled flag';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Eligibility RPC bypassed disabled flag' THEN RAISE; END IF;
 END;
END $test$;
ROLLBACK;
