-- Rücknahme von 20261031090000_training_v2_classification.sql.
-- Stellt training_insert_guard (Stand 20261029230000) und training_value (Stand 20261028230000) wörtlich wieder her, entfernt
-- die neuen RPCs, Hilfsfunktionen, den Ändern-Trigger, die Antragsspalten, die Ergänzungsliste und den Schalter training_v2.
-- Vorher deactivate_20261031090000_training_v2.sql ausführen, falls aktiviert (wird geprüft). Offene Anträge (Ort/Einheit) gehen dabei verloren;
-- die Trainings selbst bleiben offen und werden nach Trainingsart bestätigt. Bestätigte Trainings, club_tier, Punkte, EXP,
-- Coins und die Änderungshistorie bleiben unverändert (eingestufte Trainings behalten ihre gültige Wertung).
BEGIN;
DO $$ BEGIN
 IF EXISTS (SELECT 1 FROM public.league_feature_flags WHERE feature_key='training_v2' AND is_enabled) THEN
  RAISE EXCEPTION 'Zuerst deactivate_20261031090000_training_v2.sql ausführen';
 END IF;
 IF to_regclass('league_private.training_v2_schedule_backup') IS NOT NULL AND EXISTS (
   SELECT b.id,b.dow,b.training_type_id,b.tier,b.label,b.is_active FROM league_private.training_v2_schedule_backup b
   EXCEPT SELECT x.id,x.dow,x.training_type_id,x.tier,x.label,x.is_active FROM public.club_schedule x) THEN
  RAISE EXCEPTION 'Stundenplan weicht von der Sicherung ab: zuerst deactivate_20261031090000_training_v2.sql ausführen';
 END IF;
END $$;
DROP FUNCTION IF EXISTS public.staff_review_training(uuid,text,text,bigint,date,integer,text,boolean);
DROP FUNCTION IF EXISTS public.staff_correct_training(uuid,bigint,date,integer,text,text);
DROP FUNCTION IF EXISTS public.get_training_v2_config();
DROP FUNCTION IF EXISTS public.training_reward_preview(bigint,text);
DROP FUNCTION IF EXISTS public.staff_list_trainings(text,text,text,uuid,date,date,integer,integer,bigint);
DROP FUNCTION IF EXISTS public.staff_training_summary();
DROP FUNCTION IF EXISTS public.admin_training_tier_review(integer,integer);
DROP TRIGGER IF EXISTS league_training_request_update_guard ON public.training_submissions;
DROP FUNCTION IF EXISTS league_private.training_request_update_guard();
DROP FUNCTION IF EXISTS league_private.check_tier_choice(public.training_submissions,text,text,uuid);
DROP FUNCTION IF EXISTS league_private.training_card(public.training_submissions,uuid);
DROP FUNCTION IF EXISTS league_private.training_category(public.training_submissions);
DROP FUNCTION IF EXISTS league_private.requested_label(public.training_submissions);
DROP FUNCTION IF EXISTS league_private.training_conflicts(public.training_submissions);
DROP FUNCTION IF EXISTS league_private.suggested_tier(public.training_submissions);
DROP FUNCTION IF EXISTS league_private.training_closed_season(date);
DROP FUNCTION IF EXISTS league_private.pflicht_slot_on(date);

CREATE OR REPLACE FUNCTION league_private.training_value(p_sub uuid)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $fn$
 SELECT CASE WHEN s.status<>'approved' THEN 0 ELSE GREATEST(coalesce(ct.exp,0), t.points) END
 FROM public.training_submissions s JOIN public.training_types t ON t.id=s.training_type_id
 LEFT JOIN public.club_tiers ct ON ct.tier=s.club_tier
 WHERE s.id=p_sub
$fn$;
DROP FUNCTION IF EXISTS league_private.training_reward(bigint,text);

CREATE OR REPLACE FUNCTION league_private.training_insert_guard()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE uid uuid := auth.uid(); me public.profiles; tname text;
BEGIN
 IF uid IS NULL THEN RETURN NEW; END IF;
 SELECT * INTO me FROM public.profiles p WHERE p.auth_user_id=uid LIMIT 1;
 IF me.id IS NOT NULL AND me.role IN ('admin','coach') AND me.is_active THEN RETURN NEW; END IF;
 NEW.club_tier := NULL;
 NEW.recorded_by := NULL;
 SELECT t.name INTO tname FROM public.training_types t WHERE t.id=NEW.training_type_id AND t.club_only;
 IF tname IS NOT NULL AND league_private.flag_on('gym_training') AND league_private.flag_on('club_checkin_only') THEN
  RAISE EXCEPTION '«%» ist ein Vereinstraining und wird im Gym per Check-in erfasst. Selbst eintragen kannst du Heimtraining.', tname
   USING ERRCODE='42501';
 END IF;
 RETURN NEW;
END;
$fn$;

ALTER TABLE public.training_submissions DROP CONSTRAINT IF EXISTS training_submissions_v2_request_check;
ALTER TABLE public.training_submissions DROP COLUMN IF EXISTS requested_extra_key, DROP COLUMN IF EXISTS requested_slot_id,
 DROP COLUMN IF EXISTS requested_tier, DROP COLUMN IF EXISTS training_location, DROP COLUMN IF EXISTS tier_note;
DROP INDEX IF EXISTS public.training_submissions_v2_status_date_idx;
DROP INDEX IF EXISTS public.training_submissions_v2_boxer_date_idx;
DROP TABLE IF EXISTS public.club_extra_trainings;
DROP TABLE IF EXISTS league_private.training_v2_schedule_backup;
REVOKE ALL ON FUNCTION league_private.training_insert_guard(), league_private.training_value(uuid) FROM PUBLIC, anon, authenticated;
DELETE FROM public.league_feature_flags WHERE feature_key='training_v2';
NOTIFY pgrst, 'reload schema';
COMMIT;
