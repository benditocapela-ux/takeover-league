-- STAGING ONLY. Transacted read-only postconditions and fixture writes are ROLLED BACK.
-- Tests public H2H inserts, revisions, cancellation and anonymous inability to write.
BEGIN;
SELECT set_config('v21h.one',(SELECT id::text FROM public.profiles WHERE role='boxer' AND is_active ORDER BY id LIMIT 1),true);
SELECT set_config('v21h.two',(SELECT id::text FROM public.profiles WHERE role='boxer' AND is_active ORDER BY id DESC LIMIT 1),true);
DO $fixture$ BEGIN
 IF current_setting('v21h.one')=current_setting('v21h.two') THEN
  RAISE EXCEPTION 'Requires two distinct boxer fixtures';
 END IF;
END $fixture$;
WITH inserted AS (
 INSERT INTO public.league_duels(challenger_id,opponent_id,status,duration_days,
   accepted_at,ends_at,settled_at,challenger_score,opponent_score,winner_id)
 VALUES(current_setting('v21h.one')::uuid,current_setting('v21h.two')::uuid,
  'settled',7,now()-interval '8 days',now()-interval '1 day',now(),20,10,
  current_setting('v21h.one')::uuid)
 RETURNING id
) SELECT set_config('v21h.duel',id::text,true) FROM inserted;
DO $assert$ BEGIN
 IF (SELECT challenger_score FROM public.league_public_duel_history_v21
     WHERE duel_id=current_setting('v21h.duel')::uuid)<>20 THEN
  RAISE EXCEPTION 'Settled INSERT did not project';
 END IF;
END $assert$;
UPDATE public.league_duels SET challenger_score=30 WHERE id=current_setting('v21h.duel')::uuid;
DO $assert$ BEGIN
 IF (SELECT challenger_score FROM public.league_public_duel_history_v21
     WHERE duel_id=current_setting('v21h.duel')::uuid)<>30 THEN
  RAISE EXCEPTION 'Corrected settled score did not project';
 END IF;
END $assert$;
UPDATE public.league_duels SET challenger_score=31 WHERE id=current_setting('v21h.duel')::uuid;
DO $assert$ BEGIN
 IF (SELECT challenger_score FROM public.league_public_duel_history_v21
     WHERE duel_id=current_setting('v21h.duel')::uuid)<>31
   OR (SELECT count(*) FROM public.league_public_duel_history_v21
       WHERE duel_id=current_setting('v21h.duel')::uuid)<>1 THEN
  RAISE EXCEPTION 'Repeated correction duplicated or lost H2H result';
 END IF;
END $assert$;
SET LOCAL ROLE anon;
DO $assert$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.league_public_duel_history_v21
   WHERE duel_id=current_setting('v21h.duel')::uuid) THEN
  RAISE EXCEPTION 'Anon cannot read public settled duel';
 END IF;
 BEGIN
  DELETE FROM public.league_public_duel_history_v21
  WHERE duel_id=current_setting('v21h.duel')::uuid;
  RAISE EXCEPTION 'Anon was able to delete a public duel result';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
END $assert$;
RESET ROLE;
UPDATE public.league_duels SET status='cancelled' WHERE id=current_setting('v21h.duel')::uuid;
DO $assert$ BEGIN
 IF EXISTS(SELECT 1 FROM public.league_public_duel_history_v21
    WHERE duel_id=current_setting('v21h.duel')::uuid) THEN
  RAISE EXCEPTION 'Cancelled duel still appears in public H2H';
 END IF;
END $assert$;
ROLLBACK;