-- Prepared metric generation. New metrics stay disabled/unconfigured after migration.
-- No existing duel, reward, profile, feature flag or notification is backfilled.
BEGIN;
-- A client can supply created_at through the existing INSERT grant. New receipts are
-- therefore recorded independently by the server; historical rows are deliberately not backfilled.
ALTER TABLE public.training_submissions ADD COLUMN server_received_at timestamptz;
CREATE OR REPLACE FUNCTION league_v21_private.training_receipt_guard()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path=''
AS $fn$ BEGIN
 IF TG_OP='INSERT' THEN NEW.server_received_at:=clock_timestamp();
 ELSIF NEW.server_received_at IS DISTINCT FROM OLD.server_received_at THEN
  RAISE EXCEPTION 'Server receipt timestamp is immutable' USING errcode='23514';
 END IF;
 RETURN NEW;
END $fn$;
REVOKE ALL ON FUNCTION league_v21_private.training_receipt_guard() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER zz_league_training_receipt_guard BEFORE INSERT OR UPDATE OF server_received_at
 ON public.training_submissions FOR EACH ROW EXECUTE FUNCTION league_v21_private.training_receipt_guard();

ALTER TABLE public.league_duels
 ADD COLUMN scoring_metric text NOT NULL DEFAULT 'points' CHECK(scoring_metric IN ('points','jogging_km','training_count')),
 ADD COLUMN scoring_contract jsonb,
 ADD COLUMN scoring_training_type_id bigint REFERENCES public.training_types(id),
 ADD COLUMN scoring_starts_at timestamptz,
 ADD COLUMN challenger_value numeric,
 ADD COLUMN opponent_value numeric;
ALTER TABLE public.league_duels ADD CONSTRAINT duel_metric_contract_present
 CHECK(scoring_metric='points' OR (scoring_contract IS NOT NULL AND scoring_training_type_id IS NOT NULL));
ALTER TABLE public.league_duels ADD CONSTRAINT duel_metric_nonnegative_values
 CHECK((challenger_value IS NULL OR (challenger_value>=0 AND challenger_value::text NOT IN ('NaN','Infinity','-Infinity')))
  AND (opponent_value IS NULL OR (opponent_value>=0 AND opponent_value::text NOT IN ('NaN','Infinity','-Infinity'))));
ALTER TABLE public.league_duels ADD CONSTRAINT duel_metric_active_period
 CHECK(scoring_metric='points' OR status NOT IN ('active','awaiting_reviews','settled')
  OR (accepted_at IS NOT NULL AND scoring_starts_at IS NOT NULL AND ends_at IS NOT NULL));

CREATE TABLE league_v21_private.duel_metric_config(
 metric text PRIMARY KEY CHECK(metric IN ('jogging_km','training_count')),
 enabled boolean NOT NULL DEFAULT false,
 reward_rule text CHECK(reward_rule IN ('none','ranked_v21')),
 jogging_training_type_id bigint REFERENCES public.training_types(id),
 updated_at timestamptz NOT NULL DEFAULT now(),
 CHECK(metric='jogging_km' OR jogging_training_type_id IS NULL)
);
ALTER TABLE league_v21_private.duel_metric_config ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON league_v21_private.duel_metric_config FROM PUBLIC,anon,authenticated;
INSERT INTO league_v21_private.duel_metric_config(metric) VALUES('jogging_km'),('training_count');

-- Replace only the known legacy end-date check. Keep it unchanged for all points duels.
DO $constraint$ DECLARE c text; n integer; BEGIN
 SELECT count(*),min(conname) INTO n,c FROM pg_constraint
 WHERE conrelid='public.league_duels'::regclass AND contype='c'
  AND pg_get_constraintdef(oid) LIKE '%ends_at = (accepted_at +%';
 IF n<>1 THEN RAISE EXCEPTION 'Expected one legacy duel end-date constraint, found %',n; END IF;
 EXECUTE format('ALTER TABLE public.league_duels DROP CONSTRAINT %I',c);
END $constraint$;
ALTER TABLE public.league_duels ADD CONSTRAINT duel_end_date CHECK(
 ends_at IS NULL OR (accepted_at IS NOT NULL AND (
  (scoring_metric='points' AND ends_at=accepted_at+duration_days*interval '1 day') OR
  (scoring_metric<>'points' AND scoring_starts_at=
   (((accepted_at AT TIME ZONE 'Europe/Zurich')::date+1)::timestamp AT TIME ZONE 'Europe/Zurich')
   AND ends_at=((((scoring_starts_at AT TIME ZONE 'Europe/Zurich')::date+duration_days)::timestamp) AT TIME ZONE 'Europe/Zurich')))));

CREATE OR REPLACE FUNCTION league_v21_private.guard_duel_metric_contract()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $fn$ BEGIN
 IF TG_OP='UPDATE' AND OLD.scoring_contract IS NOT NULL THEN
  IF NEW.scoring_contract IS DISTINCT FROM OLD.scoring_contract
   OR NEW.scoring_metric IS DISTINCT FROM OLD.scoring_metric
   OR NEW.scoring_training_type_id IS DISTINCT FROM OLD.scoring_training_type_id
   OR NEW.challenger_id IS DISTINCT FROM OLD.challenger_id OR NEW.opponent_id IS DISTINCT FROM OLD.opponent_id
   OR NEW.duration_days IS DISTINCT FROM OLD.duration_days THEN
   RAISE EXCEPTION 'Invited duel contract is immutable' USING errcode='23514';
  END IF;
  IF OLD.accepted_at IS NOT NULL AND (NEW.accepted_at IS DISTINCT FROM OLD.accepted_at
   OR NEW.ends_at IS DISTINCT FROM OLD.ends_at OR NEW.scoring_starts_at IS DISTINCT FROM OLD.scoring_starts_at) THEN
   RAISE EXCEPTION 'Accepted duel period is immutable' USING errcode='23514';
  END IF;
 END IF;
 IF NEW.scoring_contract IS NOT NULL THEN
  IF NEW.scoring_contract->>'metric' IS DISTINCT FROM NEW.scoring_metric
   OR NEW.scoring_contract->>'visibility' NOT IN ('participants','club')
   OR NEW.scoring_contract->>'reward_rule' NOT IN ('none','ranked_v21')
   OR (NEW.scoring_metric='points' AND NEW.scoring_contract->>'reward_rule'<>'ranked_v21')
   OR NEW.scoring_contract->>'visibility' IS NULL OR NEW.scoring_contract->>'reward_rule' IS NULL THEN
   RAISE EXCEPTION 'Invalid duel contract' USING errcode='23514';
  END IF;
  IF NEW.status='active' AND (TG_OP='INSERT' OR OLD.accepted_at IS NULL) THEN
   IF (SELECT count(*) FROM public.profiles WHERE id IN(NEW.challenger_id,NEW.opponent_id)
    AND role='boxer' AND is_active AND archived_at IS NULL)<>2 THEN
    RAISE EXCEPTION 'Both contracted participants must be active and unarchived' USING errcode='42501';
   END IF;
  END IF;
  IF NEW.scoring_metric<>'points' AND NEW.status='active' AND
   (TG_OP='INSERT' OR OLD.accepted_at IS NULL) THEN
   IF NEW.accepted_at IS NULL THEN RAISE EXCEPTION 'Acceptance time required' USING errcode='23514'; END IF;
   NEW.scoring_starts_at:=(((NEW.accepted_at AT TIME ZONE 'Europe/Zurich')::date+1)::timestamp AT TIME ZONE 'Europe/Zurich');
   NEW.ends_at:=((((NEW.scoring_starts_at AT TIME ZONE 'Europe/Zurich')::date+NEW.duration_days)::timestamp) AT TIME ZONE 'Europe/Zurich');
  END IF;
 END IF;
 RETURN NEW;
END $fn$;
REVOKE ALL ON FUNCTION league_v21_private.guard_duel_metric_contract() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER league_v3_guard_contract BEFORE INSERT OR UPDATE ON public.league_duels
 FOR EACH ROW EXECUTE FUNCTION league_v21_private.guard_duel_metric_contract();

CREATE OR REPLACE FUNCTION league_v21_private.duel_metric_snapshot(p_duel public.league_duels,p_as_of timestamptz)
RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER SET search_path=''
AS $sql$
 WITH relevant AS MATERIALIZED (
  SELECT s.id,s.boxer_id,s.status,s.jogging_km,s.server_received_at FROM public.training_submissions s
  WHERE s.boxer_id IN (p_duel.challenger_id,p_duel.opponent_id)
   AND s.training_type_id=p_duel.scoring_training_type_id
   AND s.training_date>=(p_duel.scoring_starts_at AT TIME ZONE 'Europe/Zurich')::date
   AND s.training_date<(p_duel.ends_at AT TIME ZONE 'Europe/Zurich')::date
   AND s.training_date<=(p_as_of AT TIME ZONE 'Europe/Zurich')::date
   AND (s.server_received_at IS NULL OR (s.server_received_at>=p_duel.scoring_starts_at
    AND s.server_received_at<p_duel.ends_at AND s.server_received_at<=p_as_of))
 ), approved AS (
  SELECT s.id,s.boxer_id,s.jogging_km,count(t.id) ledger_count
  FROM relevant s LEFT JOIN public.point_transactions t ON t.submission_id=s.id
   AND t.boxer_id=s.boxer_id AND t.category IN ('training','legacy_import')
  WHERE s.status='approved' GROUP BY s.id,s.boxer_id,s.jogging_km
 ), totals AS (
  SELECT count(*) FILTER(WHERE ledger_count<>1)::integer invalid_ledger,
   (SELECT count(*) FROM relevant WHERE server_received_at IS NULL AND status IN ('approved','pending'))::integer missing_receipt,
   count(*) FILTER(WHERE p_duel.scoring_metric='jogging_km' AND
    (jogging_km IS NULL OR jogging_km<0 OR jogging_km::text IN ('NaN','Infinity','-Infinity')))::integer missing_distance,
   CASE WHEN p_duel.scoring_metric='training_count' THEN count(DISTINCT id) FILTER(WHERE boxer_id=p_duel.challenger_id)::numeric
        ELSE coalesce(sum(jogging_km) FILTER(WHERE boxer_id=p_duel.challenger_id),0) END p1,
   CASE WHEN p_duel.scoring_metric='training_count' THEN count(DISTINCT id) FILTER(WHERE boxer_id=p_duel.opponent_id)::numeric
        ELSE coalesce(sum(jogging_km) FILTER(WHERE boxer_id=p_duel.opponent_id),0) END p2 FROM approved
 ) SELECT pg_catalog.jsonb_build_object(
  'challenger_score',CASE WHEN invalid_ledger=0 AND missing_distance=0 AND missing_receipt=0 THEN p1 END,
  'opponent_score',CASE WHEN invalid_ledger=0 AND missing_distance=0 AND missing_receipt=0 THEN p2 END,
  'pending',(SELECT count(*) FROM relevant WHERE status='pending'),
  'approved',(SELECT count(*) FROM relevant WHERE status='approved'),
  'rejected',(SELECT count(*) FROM relevant WHERE status='rejected'),
  'invalid_ledger',invalid_ledger,'missing_distance',missing_distance,'missing_receipt',missing_receipt,
  'valid',invalid_ledger=0 AND missing_distance=0 AND missing_receipt=0) FROM totals
$sql$;
REVOKE ALL ON FUNCTION league_v21_private.duel_metric_snapshot(public.league_duels,timestamptz) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION league_v21_private.duel_v3_metric_revision(p_metric text)
RETURNS text LANGUAGE sql STABLE SECURITY INVOKER SET search_path=''
AS $sql$ SELECT CASE WHEN p_metric='points' THEN md5('points:ranked_v21:legacy_inclusive_zurich_dates:v3') ELSE (
 SELECT md5(jsonb_build_object('metric',c.metric,'enabled',c.enabled,'reward_rule',c.reward_rule,
  'type_id',c.jogging_training_type_id,'type_name',t.name,'type_active',t.is_active,
  'time_rule','next_zurich_midnight_full_days')::text)
 FROM league_v21_private.duel_metric_config c LEFT JOIN public.training_types t ON t.id=c.jogging_training_type_id
 WHERE c.metric=p_metric) END $sql$;
REVOKE ALL ON FUNCTION league_v21_private.duel_v3_metric_revision(text) FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION league_v21_private.duel_v3_type_revision(p_type_id bigint)
RETURNS text LANGUAGE sql STABLE SECURITY INVOKER SET search_path=''
AS $sql$ SELECT md5(jsonb_build_object('id',id,'name',name,'is_active',is_active)::text)
 FROM public.training_types WHERE id=p_type_id $sql$;
REVOKE ALL ON FUNCTION league_v21_private.duel_v3_type_revision(bigint) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION league_v21_private.duel_v3_options_core()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=''
AS $fn$ DECLARE metrics jsonb; types jsonb; BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.profiles WHERE auth_user_id=(SELECT auth.uid()) AND is_active
  AND archived_at IS NULL AND role IN ('boxer','coach','admin')) THEN RAISE EXCEPTION 'Authentication required' USING errcode='42501'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.league_feature_flags WHERE feature_key='duels' AND is_enabled)
 THEN RAISE EXCEPTION 'Duels are not enabled' USING errcode='42501'; END IF;
 SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('key',c.metric,
  'label',CASE WHEN c.metric='jogging_km' THEN 'Jogging-Kilometer' ELSE 'Trainings einer Trainingsart' END,
  'unit',CASE WHEN c.metric='jogging_km' THEN 'km' ELSE 'Trainings' END,
  'revision',league_v21_private.duel_v3_metric_revision(c.metric),
  'training_type_id',c.jogging_training_type_id,
  'training_type_name',(SELECT name FROM public.training_types WHERE id=c.jogging_training_type_id),
  'enabled',c.enabled AND c.reward_rule IS NOT NULL AND (c.metric<>'jogging_km' OR EXISTS(
   SELECT 1 FROM public.training_types t WHERE t.id=c.jogging_training_type_id AND t.is_active)),
  'disabled_reason',CASE WHEN c.reward_rule IS NULL THEN 'Belohnungsregel noch nicht freigegeben'
   WHEN c.metric='jogging_km' AND NOT EXISTS(SELECT 1 FROM public.training_types t WHERE t.id=c.jogging_training_type_id AND t.is_active)
    THEN 'Jogging-Trainingsart noch nicht konfiguriert' WHEN NOT c.enabled THEN 'Noch nicht freigegeben' END,
  'reward_rule',c.reward_rule,'reward_label',CASE c.reward_rule WHEN 'none' THEN 'Keine zusätzliche Belohnung'
   WHEN 'ranked_v21' THEN 'Bestehende rangabhängige EXP-Regel' ELSE 'Noch nicht eingerichtet' END) ORDER BY c.metric)
 INTO metrics FROM league_v21_private.duel_metric_config c;
 SELECT coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id',id,'name',name,
  'revision',league_v21_private.duel_v3_type_revision(id)) ORDER BY id),'[]')
 INTO types FROM public.training_types WHERE is_active;
 RETURN pg_catalog.jsonb_build_object('metrics',pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
  'key','points','label','Trainingspunkte','unit','Trainingspunkte','enabled',true,'disabled_reason',NULL,
  'revision',league_v21_private.duel_v3_metric_revision('points'),'training_type_id',NULL,'training_type_name',NULL,
  'reward_rule','ranked_v21','reward_label','Bestehende rangabhängige EXP-Regel'))||coalesce(metrics,'[]'),
  'training_types',types,'timezone','Europe/Zurich',
  'visibility_options',pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object('key','participants','label','Nur Teilnehmer und Trainer'),
   pg_catalog.jsonb_build_object('key','club','label','Angemeldete Vereinsboxer sehen den Gesamtstand')));
END $fn$;

CREATE OR REPLACE FUNCTION league_v21_private.duel_v3_invite_core(
 p_challenger uuid,p_opponent uuid,p_duration_days integer,p_metric text,
 p_training_type_id bigint DEFAULT NULL,p_visibility text DEFAULT 'participants',p_expected_rule jsonb DEFAULT NULL)
RETURNS uuid LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=''
AS $fn$ DECLARE cfg league_v21_private.duel_metric_config%ROWTYPE; type_id bigint; type_name text;
 reward text; label text; unit text; contract jsonb; duel uuid;
BEGIN
 PERFORM league_v21_private.duel_v3_options_core();
 IF p_metric IS NULL OR p_metric NOT IN ('points','jogging_km','training_count')
  OR p_visibility IS NULL OR p_visibility NOT IN ('participants','club') THEN
  RAISE EXCEPTION 'Valid metric and visibility required' USING errcode='22023'; END IF;
 IF p_metric='points' THEN
  IF p_training_type_id IS NOT NULL THEN RAISE EXCEPTION 'Points have no training-type filter' USING errcode='22023'; END IF;
  reward:='ranked_v21';label:='Trainingspunkte';unit:='Trainingspunkte';
 ELSE
  SELECT * INTO cfg FROM league_v21_private.duel_metric_config WHERE metric=p_metric FOR SHARE;
  IF NOT FOUND OR NOT cfg.enabled OR cfg.reward_rule IS NULL THEN
   RAISE EXCEPTION 'Metric invitation requires an explicitly configured reward rule and release' USING errcode='42501'; END IF;
  reward:=cfg.reward_rule;
  IF p_metric='jogging_km' THEN
   IF p_training_type_id IS NOT NULL THEN RAISE EXCEPTION 'Jogging type is configured by the server' USING errcode='22023'; END IF;
   type_id:=cfg.jogging_training_type_id;label:='Jogging-Kilometer';unit:='km';
  ELSE type_id:=p_training_type_id;label:='Trainings einer Trainingsart';unit:='Trainings'; END IF;
  SELECT name INTO type_name FROM public.training_types WHERE id=type_id AND is_active FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Active training-type ID required' USING errcode='22023'; END IF;
 END IF;
 IF p_expected_rule IS NULL OR jsonb_typeof(p_expected_rule)<>'object' THEN
  RAISE EXCEPTION 'Explicitly reviewed rule revision required' USING errcode='22023'; END IF;
 IF p_expected_rule->>'metric_revision' IS DISTINCT FROM league_v21_private.duel_v3_metric_revision(p_metric)
  OR p_expected_rule->>'training_type_revision' IS DISTINCT FROM
   (CASE WHEN p_metric='training_count' THEN league_v21_private.duel_v3_type_revision(type_id) END) THEN
  RAISE EXCEPTION 'Invitation rule changed: review the current options again' USING errcode='40001'; END IF;
 -- Existing RPC retains all actor, pair, expiry, duration and active-boxer guards/locks.
 duel:=public.duel_v2_invite(p_challenger,p_opponent,p_duration_days);
 IF (SELECT count(*) FROM public.profiles WHERE id IN(p_challenger,p_opponent)
  AND role='boxer' AND is_active AND archived_at IS NULL)<>2 THEN
  RAISE EXCEPTION 'Both participants must be active and unarchived' USING errcode='42501'; END IF;
 IF p_visibility='club' AND (SELECT count(*) FROM public.profiles
  WHERE id IN(p_challenger,p_opponent) AND is_active AND archived_at IS NULL AND is_listed)<>2 THEN
  RAISE EXCEPTION 'Club visibility requires both currently listed active boxers' USING errcode='42501'; END IF;
 contract:=pg_catalog.jsonb_build_object('version',3,'metric',p_metric,'label',label,'unit',unit,
  'training_type_id',type_id,'training_type_name',type_name,'visibility',p_visibility,
  'reward_rule',reward,'reward_label',CASE reward WHEN 'none' THEN 'Keine zusätzliche Belohnung' ELSE 'Bestehende rangabhängige EXP-Regel' END,
  'timezone','Europe/Zurich','time_rule',CASE WHEN p_metric='points' THEN 'legacy_inclusive_zurich_dates' ELSE 'next_zurich_midnight_full_days' END);
 UPDATE public.league_duels SET scoring_metric=p_metric,scoring_contract=contract,scoring_training_type_id=type_id WHERE id=duel;
 UPDATE public.boxer_notifications SET message=label||coalesce(' – '||type_name,'')||'. '||
  CASE WHEN p_metric='points' THEN p_duration_days||' Tage nach bestehender Zeitregel. '
   ELSE p_duration_days||' volle Tage ab dem Folgetag der Annahme (Europe/Zurich). ' END||
  (contract->>'reward_label')||'. '||CASE WHEN p_visibility='club' THEN 'Gesamtstand für angemeldete Vereinsboxer sichtbar.' ELSE 'Nur Teilnehmer und Trainer.' END
 WHERE event_key='duel:'||duel::text||':invited';
 RETURN duel;
END $fn$;

CREATE OR REPLACE FUNCTION league_v21_private.duel_v3_visible(p_duel_id uuid)
RETURNS public.league_duels LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=''
AS $fn$ DECLARE actor public.profiles%ROWTYPE; d public.league_duels%ROWTYPE; BEGIN
 SELECT * INTO actor FROM public.profiles WHERE auth_user_id=(SELECT auth.uid()) AND is_active
  AND archived_at IS NULL AND role IN ('boxer','coach','admin');
 IF NOT FOUND THEN RAISE EXCEPTION 'Authentication required' USING errcode='42501'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.league_feature_flags WHERE feature_key='duels' AND is_enabled)
 THEN RAISE EXCEPTION 'Duels are not enabled' USING errcode='42501'; END IF;
 SELECT * INTO d FROM public.league_duels WHERE id=p_duel_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'Duel not found' USING errcode='22023'; END IF;
 IF actor.role='boxer' AND actor.id NOT IN(d.challenger_id,d.opponent_id) THEN
  IF d.scoring_contract->>'visibility' IS DISTINCT FROM 'club'
   OR d.status NOT IN ('active','awaiting_reviews','settled')
   OR (SELECT count(*) FROM public.profiles WHERE id IN(d.challenger_id,d.opponent_id)
    AND is_active AND archived_at IS NULL AND is_listed)<>2 THEN
   RAISE EXCEPTION 'Not an authorized duel viewer' USING errcode='42501';
  END IF;
 END IF;
 RETURN d;
END $fn$;
REVOKE ALL ON FUNCTION league_v21_private.duel_v3_visible(uuid) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION league_v21_private.duel_v3_item(p_duel public.league_duels,p_as_of timestamptz)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path=''
AS $fn$ DECLARE s jsonb; r jsonb; ch text; op text; BEGIN
 SELECT display_name INTO ch FROM public.profiles WHERE id=p_duel.challenger_id;
 SELECT display_name INTO op FROM public.profiles WHERE id=p_duel.opponent_id;
 r:=coalesce(p_duel.scoring_contract,pg_catalog.jsonb_build_object('version',2,'metric','points',
  'label','Trainingspunkte','unit','Trainingspunkte','visibility','participants','timezone','Europe/Zurich',
  'time_rule','legacy_inclusive_zurich_dates','reward_rule',CASE WHEN p_duel.accepted_at IS NOT NULL
   AND NOT EXISTS(SELECT 1 FROM public.league_duel_rank_snapshots_v21 WHERE duel_id=p_duel.id) THEN 'legacy_v2' ELSE 'ranked_v21' END,
  'reward_label','Bestehende vereinbarte EXP-Regel'));
 IF p_duel.status='settled' THEN
  s:=pg_catalog.jsonb_build_object('challenger_score',CASE WHEN p_duel.scoring_metric='points' THEN p_duel.challenger_score::numeric ELSE p_duel.challenger_value END,
   'opponent_score',CASE WHEN p_duel.scoring_metric='points' THEN p_duel.opponent_score::numeric ELSE p_duel.opponent_value END,
   'pending',0,'valid',true,'provisional',false);
 ELSIF p_duel.status IN ('active','awaiting_reviews') THEN
  s:=CASE WHEN p_duel.scoring_metric='points' THEN league_v21_private.duel_points_snapshot(p_duel,p_as_of)
   ELSE league_v21_private.duel_metric_snapshot(p_duel,p_as_of) END;
  s:=pg_catalog.jsonb_build_object('challenger_score',s->'challenger_score','opponent_score',s->'opponent_score',
   'pending',s->'pending','valid',s->'valid','provisional',true);
 END IF;
 RETURN pg_catalog.jsonb_build_object('id',p_duel.id,'challenger_id',p_duel.challenger_id,'challenger_name',ch,
  'opponent_id',p_duel.opponent_id,'opponent_name',op,'status',p_duel.status,'duration_days',p_duel.duration_days,
  'invited_at',p_duel.invited_at,'expires_at',p_duel.expires_at,'accepted_at',p_duel.accepted_at,
  'starts_at',CASE WHEN p_duel.scoring_metric='points' THEN p_duel.accepted_at ELSE p_duel.scoring_starts_at END,
  'ends_at',p_duel.ends_at,'settled_at',p_duel.settled_at,'winner_id',p_duel.winner_id,'rule',r,'scores',s);
END $fn$;
REVOKE ALL ON FUNCTION league_v21_private.duel_v3_item(public.league_duels,timestamptz) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION league_v21_private.duel_v3_live_scores_core(p_duel_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=''
AS $fn$ DECLARE d public.league_duels%ROWTYPE; item jsonb; BEGIN
 d:=league_v21_private.duel_v3_visible(p_duel_id);
 IF d.status NOT IN ('active','awaiting_reviews','settled') THEN RAISE EXCEPTION 'No live score for this duel' USING errcode='22023'; END IF;
 item:=league_v21_private.duel_v3_item(d,statement_timestamp());
 IF NOT (item#>>'{scores,valid}')::boolean THEN RAISE EXCEPTION 'Metric data or scoring ledger requires review' USING errcode='23514'; END IF;
 RETURN (item->'scores')||pg_catalog.jsonb_build_object('status',d.status,'rule',item->'rule','starts_at',item->'starts_at','ends_at',d.ends_at);
END $fn$;

CREATE OR REPLACE FUNCTION league_v21_private.duel_v3_list_core(
 p_scope text DEFAULT 'mine',p_state text DEFAULT 'all',p_limit integer DEFAULT 20,
 p_before timestamptz DEFAULT NULL,p_before_id uuid DEFAULT NULL,p_search text DEFAULT NULL,p_duel_id uuid DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=''
AS $fn$ DECLARE actor public.profiles%ROWTYPE; d public.league_duels%ROWTYPE; items jsonb:='[]';
 n integer:=0; cursor jsonb; last_date timestamptz; last_id uuid; BEGIN
 SELECT * INTO actor FROM public.profiles WHERE auth_user_id=(SELECT auth.uid()) AND is_active
  AND archived_at IS NULL AND role IN ('boxer','coach','admin');
 IF NOT FOUND THEN RAISE EXCEPTION 'Authentication required' USING errcode='42501'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.league_feature_flags WHERE feature_key='duels' AND is_enabled)
 THEN RAISE EXCEPTION 'Duels are not enabled' USING errcode='42501'; END IF;
 IF p_scope IS NULL OR p_scope NOT IN ('mine','club','staff') OR p_state IS NULL
  OR p_state NOT IN ('all','pending','active','due','settled') OR p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 50
  OR ((p_before IS NULL)<>(p_before_id IS NULL)) OR length(coalesce(p_search,''))>100 THEN
  RAISE EXCEPTION 'Invalid duel list filter or cursor' USING errcode='22023'; END IF;
 IF p_scope='staff' AND actor.role NOT IN ('coach','admin') THEN RAISE EXCEPTION 'Staff scope required' USING errcode='42501'; END IF;
 FOR d IN SELECT x.* FROM public.league_duels x
  JOIN public.profiles ch ON ch.id=x.challenger_id JOIN public.profiles op ON op.id=x.opponent_id
  WHERE ((p_scope='mine' AND actor.id IN(x.challenger_id,x.opponent_id))
   OR (p_scope='staff' AND actor.role IN ('coach','admin'))
   OR (p_scope='club' AND x.scoring_contract->>'visibility'='club' AND x.status IN ('active','awaiting_reviews','settled')
    AND ch.is_active AND ch.archived_at IS NULL AND ch.is_listed AND op.is_active AND op.archived_at IS NULL AND op.is_listed))
   AND (p_state='all' OR (p_state='pending' AND x.status='pending')
    OR (p_state='active' AND x.status='active' AND x.ends_at>statement_timestamp())
    OR (p_state='due' AND x.status IN ('active','awaiting_reviews') AND x.ends_at<=statement_timestamp())
    OR (p_state='settled' AND x.status='settled'))
   AND (p_before IS NULL OR (x.invited_at,x.id)<(p_before,p_before_id))
   AND (p_duel_id IS NULL OR x.id=p_duel_id)
   AND (nullif(btrim(p_search),'') IS NULL OR position(lower(btrim(p_search)) IN lower(ch.display_name||' '||op.display_name))>0)
  ORDER BY x.invited_at DESC,x.id DESC LIMIT p_limit+1
 LOOP
  n:=n+1;
  IF n>p_limit THEN cursor:=pg_catalog.jsonb_build_object('before',last_date,'before_id',last_id); EXIT; END IF;
  items:=items||pg_catalog.jsonb_build_array(league_v21_private.duel_v3_item(d,statement_timestamp()));
  last_date:=d.invited_at;last_id:=d.id;
 END LOOP;
 RETURN pg_catalog.jsonb_build_object('items',items,'next_cursor',cursor);
END $fn$;

CREATE OR REPLACE FUNCTION league_v21_private.duel_metric_close_preview_core(p_duel_id uuid,p_as_of timestamptz)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=''
AS $fn$
DECLARE d public.league_duels%ROWTYPE; actor public.profiles%ROWTYPE; score jsonb;
 blockers jsonb:='[]'; rewards jsonb:='[]'; result jsonb; snapshots integer;
 cr integer; opr integer; p1 numeric; p2 numeric; boxer uuid; reward integer;
 ledger public.league_duel_exp_ledger%ROWTYPE; ledger_found boolean;
 payout_valid boolean; all_payouts_valid boolean:=true; winner uuid;
BEGIN
 SELECT * INTO actor FROM public.profiles WHERE auth_user_id=(SELECT auth.uid())
  AND is_active AND archived_at IS NULL AND role IN ('coach','admin');
 IF NOT FOUND THEN RAISE EXCEPTION 'Only active staff may preview closure' USING errcode='42501'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.league_feature_flags WHERE feature_key='duels' AND is_enabled)
 THEN RAISE EXCEPTION 'Duels are not enabled' USING errcode='42501'; END IF;
 SELECT * INTO d FROM public.league_duels WHERE id=p_duel_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'Duel not found' USING errcode='22023'; END IF;
 IF d.status NOT IN ('active','awaiting_reviews','settled') OR d.accepted_at IS NULL OR d.ends_at IS NULL
 THEN RAISE EXCEPTION 'Duel has no accepted scoring period' USING errcode='22023'; END IF;
 IF d.scoring_metric='points' THEN RETURN league_v21_private.duel_close_preview_core(p_duel_id,p_as_of); END IF;
 score:=league_v21_private.duel_metric_snapshot(d,p_as_of);
 p1:=(score->>'challenger_score')::numeric; p2:=(score->>'opponent_score')::numeric;
 IF d.ends_at>p_as_of THEN
  blockers:=blockers||pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object('code','in_progress','message','Der Duellzeitraum läuft noch.'));
 END IF;
 IF (score->>'pending')::integer>0 THEN
  blockers:=blockers||pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object('code','pending_reviews','message','Rechtzeitig eingereichte Trainings warten auf Prüfung.'));
 END IF;
 IF NOT (score->>'valid')::boolean THEN
  blockers:=blockers||pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object('code','metric_data_invalid','message','Die serverseitige Erfassungszeit, eine bestätigte Distanz oder eine passende Punktebuchung fehlt oder ist ungültig.'));
 END IF;
 SELECT count(*),max(rank_index) FILTER(WHERE boxer_id=d.challenger_id),
  max(rank_index) FILTER(WHERE boxer_id=d.opponent_id) INTO snapshots,cr,opr
 FROM public.league_duel_rank_snapshots_v21 WHERE duel_id=d.id;
 IF d.scoring_contract->>'reward_rule'='ranked_v21' AND (snapshots<>2 OR cr IS NULL OR opr IS NULL) THEN
  blockers:=blockers||pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object('code','rank_snapshot_invalid','message','Die gespeicherte Rangregel ist unvollständig.'));
 END IF;
 winner:=CASE WHEN p1>p2 THEN d.challenger_id WHEN p2>p1 THEN d.opponent_id END;
 FOREACH boxer IN ARRAY ARRAY[d.challenger_id,d.opponent_id] LOOP
  reward:=CASE WHEN d.scoring_contract->>'reward_rule'='none' THEN 0 END;
  IF d.scoring_contract->>'reward_rule'='ranked_v21' AND (score->>'valid')::boolean AND snapshots=2 AND cr IS NOT NULL AND opr IS NOT NULL THEN
   reward:=league_v21_private.duel_points_reward(p1=p2,boxer=winner,snapshots,
    CASE WHEN boxer=d.challenger_id THEN cr ELSE opr END,
    CASE WHEN boxer=d.challenger_id THEN opr ELSE cr END);
  END IF;
  SELECT * INTO ledger FROM public.league_duel_exp_ledger WHERE duel_id=d.id AND boxer_id=boxer;
  ledger_found:=FOUND;
  IF d.scoring_contract->>'reward_rule'='none' THEN
   payout_valid:=NOT ledger_found AND NOT EXISTS(SELECT 1 FROM public.point_transactions t
    WHERE t.boxer_id=boxer AND t.category='duel_exp' AND t.description='Duel reward: '||d.id::text);
  ELSIF NOT ledger_found OR ledger.transaction_id IS NULL THEN
   payout_valid:=d.status<>'settled' AND (NOT ledger_found OR ledger.awarded_exp=0)
    AND NOT EXISTS(SELECT 1 FROM public.point_transactions t WHERE t.boxer_id=boxer
      AND t.category='duel_exp' AND t.description='Duel reward: '||d.id::text);
  ELSE
   payout_valid:=EXISTS(SELECT 1 FROM public.point_transactions t
    WHERE t.id=ledger.transaction_id AND t.boxer_id=boxer AND t.category='duel_exp'
     AND t.points=0 AND t.exp=ledger.awarded_exp AND t.description='Duel reward: '||d.id::text
     AND t.effective_date=(d.ends_at AT TIME ZONE 'Europe/Zurich')::date);
  END IF;
  all_payouts_valid:=all_payouts_valid AND payout_valid;
  rewards:=rewards||pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
   'boxer_id',boxer,'planned_exp',reward,
   'booked_exp',CASE WHEN payout_valid THEN CASE WHEN ledger_found THEN ledger.awarded_exp ELSE 0 END END,
   'delta_exp',CASE WHEN payout_valid THEN reward-CASE WHEN ledger_found THEN ledger.awarded_exp ELSE 0 END END,
   'transaction_id',ledger.transaction_id));
 END LOOP;
 IF NOT all_payouts_valid THEN
  blockers:=blockers||pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object('code','reward_ledger_invalid','message','Die bestehende EXP-Buchung muss vor dem Abschluss geprüft werden.'));
 END IF;
 result:=pg_catalog.jsonb_build_object('duel_id',d.id,'status',d.status,
  'starts_at',d.scoring_starts_at,'ends_at',d.ends_at,
  'rule',d.scoring_contract||pg_catalog.jsonb_build_object(
   'start_day',(d.scoring_starts_at AT TIME ZONE 'Europe/Zurich')::date,
   'end_day',(d.ends_at AT TIME ZONE 'Europe/Zurich')::date-1,'end_exclusive',true),
  'scores',score-'invalid_ledger'-'missing_distance'-'missing_receipt'-'valid',
  'winner_id',winner,'tie',p1=p2,'provisional',true,
  'can_close',d.status IN ('active','awaiting_reviews') AND blockers='[]'::jsonb,
  'can_correct',d.status='settled' AND blockers='[]'::jsonb
    AND (p1 IS DISTINCT FROM d.challenger_value OR p2 IS DISTINCT FROM d.opponent_value
       OR EXISTS(SELECT 1 FROM pg_catalog.jsonb_array_elements(rewards) r WHERE (r->>'delta_exp')::integer<>0)),
  'blockers',blockers,'rewards',rewards,'review_path','coach.html');
 RETURN result||pg_catalog.jsonb_build_object('revision',pg_catalog.md5(result::text));
END $fn$;


CREATE OR REPLACE FUNCTION league_v21_private.duel_metric_reconcile_core(p_duel_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
 d public.league_duels%ROWTYPE;
 actor public.profiles%ROWTYPE;
 v_clock timestamptz := clock_timestamp();
 actor_found boolean;
 p1 numeric;
 p2 numeric;
 pending_count integer;
 score jsonb;
 target_exp integer;
 boxer uuid;
 old_exp integer;
 old_tx uuid;
 new_tx uuid;
 existing_status text;
 challenger_rank integer; opponent_rank integer; winner_rank integer; loser_rank integer; snapshots integer;
BEGIN
 SELECT * INTO actor FROM public.profiles
 WHERE auth_user_id=(SELECT auth.uid()) AND is_active=true AND archived_at IS NULL;
 actor_found:=FOUND;
 IF NOT EXISTS(SELECT 1 FROM public.league_feature_flags WHERE feature_key='duels' AND is_enabled=true) THEN
  RAISE EXCEPTION 'Duels are not enabled';
 END IF;
 IF NOT actor_found OR actor.role NOT IN ('admin','coach') THEN
  RAISE EXCEPTION 'Only a coach may reconcile duels';
 END IF;
 -- Lock boxer profiles before the duel row, matching invite/respond.
 SELECT * INTO d FROM public.league_duels WHERE id=p_duel_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'Duel not found'; END IF;
 PERFORM 1 FROM public.profiles
 WHERE id IN (d.challenger_id,d.opponent_id) ORDER BY id FOR UPDATE;
 SELECT * INTO d FROM public.league_duels WHERE id=p_duel_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Duel not found'; END IF;
 -- A lock wait may cross the duel end timestamp; decide using fresh time.
 v_clock:=clock_timestamp();
 IF d.scoring_metric='points' THEN RETURN league_v21_private.duel_reconcile_ranked_core(p_duel_id); END IF;
 IF d.status NOT IN ('active','awaiting_reviews','settled') THEN
  RAISE EXCEPTION 'Duel not active or completed';
 END IF;
 IF d.ends_at>v_clock THEN RETURN 'in_progress'; END IF;

 -- Lock the qualifying training submissions before counting and scoring.
 -- This serializes concurrent review/edit updates against settlement, so a
 -- submission cannot switch status between pending check and point summation.
 -- Existing review functions must be checked for consistent lock order.
 PERFORM 1 FROM public.training_submissions s
 WHERE s.boxer_id IN(d.challenger_id,d.opponent_id)
  AND s.training_date>=(d.scoring_starts_at AT TIME ZONE 'Europe/Zurich')::date
  AND s.training_date<(d.ends_at AT TIME ZONE 'Europe/Zurich')::date
  AND (s.server_received_at IS NULL OR (s.server_received_at>=d.scoring_starts_at AND s.server_received_at<d.ends_at))
 ORDER BY s.id FOR UPDATE;

 -- Shared scoring validation is evaluated after the existing submission locks.
 score:=league_v21_private.duel_metric_snapshot(d,d.ends_at);
 pending_count:=(score->>'pending')::integer;
 IF pending_count>0 THEN
  -- Never reopen an already-paid duel: preserve existing EXP until
  -- pending submissions are reviewed and a coach reconciles again.
  IF d.status='settled' THEN RETURN 'pending_correction'; END IF;
  IF d.status<>'awaiting_reviews' THEN
   UPDATE public.league_duels SET status='awaiting_reviews',updated_at=v_clock
   WHERE id=d.id;
   INSERT INTO public.league_duel_events(duel_id,event_type,payload)
   VALUES(d.id,'awaiting_reviews',pg_catalog.jsonb_build_object('pending',pending_count));
  END IF;
  RETURN 'awaiting_reviews';
 END IF;

 IF NOT (score->>'valid')::boolean THEN
  RAISE EXCEPTION 'Metric distance or scoring ledger requires review'
   USING errcode='23514';
 END IF;
 p1:=(score->>'challenger_score')::numeric;
 p2:=(score->>'opponent_score')::numeric;

 IF d.scoring_contract->>'reward_rule'='ranked_v21' THEN
 -- Snapshot at acceptance is mandatory for V2.1 ranked duels; older duels keep legacy rules.
 SELECT count(*) INTO snapshots FROM public.league_duel_rank_snapshots_v21 s WHERE s.duel_id=d.id;
 IF snapshots<>2 THEN RAISE EXCEPTION 'Incomplete duel rank snapshots' using errcode='23514';END IF;
 IF snapshots=2 THEN
  SELECT s.rank_index INTO challenger_rank FROM public.league_duel_rank_snapshots_v21 s
   WHERE s.duel_id=d.id AND s.boxer_id=d.challenger_id;
  SELECT s.rank_index INTO opponent_rank FROM public.league_duel_rank_snapshots_v21 s
   WHERE s.duel_id=d.id AND s.boxer_id=d.opponent_id;
  IF challenger_rank IS NULL OR opponent_rank IS NULL THEN
   RAISE EXCEPTION 'Duel rank snapshot participants mismatch' using errcode='23514';
  END IF;
  winner_rank:=CASE WHEN p1>p2 THEN challenger_rank ELSE opponent_rank END;
  loser_rank:=CASE WHEN p1>p2 THEN opponent_rank ELSE challenger_rank END;
 END IF;
 ELSE
  snapshots:=0;
  IF EXISTS(SELECT 1 FROM public.league_duel_exp_ledger WHERE duel_id=d.id)
   OR EXISTS(SELECT 1 FROM public.point_transactions WHERE category='duel_exp' AND description='Duel reward: '||d.id::text) THEN
   RAISE EXCEPTION 'No-reward duel unexpectedly has payout data' USING errcode='23514';
  END IF;
 END IF;
 existing_status:=d.status;
 UPDATE public.league_duels
 SET status='settled',settled_at=COALESCE(settled_at,v_clock),
     challenger_value=p1,opponent_value=p2,
     winner_id=CASE WHEN p1=p2 THEN NULL WHEN p1>p2 THEN d.challenger_id ELSE d.opponent_id END,
     updated_at=v_clock
 WHERE id=d.id;

 IF d.scoring_contract->>'reward_rule'='ranked_v21' THEN
 FOREACH boxer IN ARRAY ARRAY[d.challenger_id,d.opponent_id] LOOP
  target_exp:=league_v21_private.duel_points_reward(p1=p2,
   (p1>p2 AND boxer=d.challenger_id) OR (p2>p1 AND boxer=d.opponent_id),snapshots,
   CASE WHEN boxer=d.challenger_id THEN challenger_rank ELSE opponent_rank END,
   CASE WHEN boxer=d.challenger_id THEN opponent_rank ELSE challenger_rank END);

  INSERT INTO public.league_duel_exp_ledger(duel_id,boxer_id,awarded_exp)
  VALUES(d.id,boxer,0)
  ON CONFLICT(duel_id,boxer_id) DO NOTHING;

  SELECT awarded_exp,transaction_id INTO old_exp,old_tx
  FROM public.league_duel_exp_ledger
  WHERE duel_id=d.id AND boxer_id=boxer FOR UPDATE;

  IF old_tx IS NULL THEN
   -- A settled duel must already have a payout transaction for each boxer.
   -- Never silently reconstruct a missing payout during a correction.
   IF existing_status='settled' THEN
    RAISE EXCEPTION 'Settled duel payout transaction missing for duel % boxer %',d.id,boxer;
   END IF;
   -- A missing transaction reference is valid only for a new, unpaid ledger.
   -- Do not create another reward if the ledger already claims EXP was paid.
   IF old_exp IS DISTINCT FROM 0 THEN
    RAISE EXCEPTION 'Duel reward ledger claims EXP without transaction for duel % boxer %',d.id,boxer;
   END IF;
   -- Never create a second payout if a duel_exp transaction already exists
   -- but the ledger reference was lost (including on a first settlement).
   IF EXISTS (
    SELECT 1 FROM public.point_transactions t
    WHERE t.boxer_id=boxer AND t.category='duel_exp'
      AND t.description='Duel reward: '||d.id::text
   ) THEN
    RAISE EXCEPTION 'Orphaned duel payout transaction for duel % boxer %',d.id,boxer;
   END IF;
   INSERT INTO public.point_transactions
    (boxer_id,points,exp,category,description,effective_date,created_by)
   VALUES(boxer,0,target_exp,'duel_exp',
          'Duel reward: '||d.id::text,
          (d.ends_at AT TIME ZONE 'Europe/Zurich')::date,actor.id)
   RETURNING id INTO new_tx;
   UPDATE public.league_duel_exp_ledger
   SET transaction_id=new_tx,awarded_exp=target_exp,updated_at=v_clock
   WHERE duel_id=d.id AND boxer_id=boxer;
  ELSIF old_exp IS NULL THEN
   RAISE EXCEPTION 'Duel reward ledger has NULL EXP for duel % boxer %',d.id,boxer;
  ELSIF NOT EXISTS(
   SELECT 1 FROM public.point_transactions t
   WHERE t.id=old_tx AND t.boxer_id=boxer AND t.category='duel_exp'
     AND t.points=0 AND t.exp=old_exp
     AND t.description='Duel reward: '||d.id::text
     AND t.effective_date=(d.ends_at AT TIME ZONE 'Europe/Zurich')::date
  ) THEN
   RAISE EXCEPTION 'Duel reward ledger mismatch for duel % boxer %',d.id,boxer;
  ELSIF old_exp<>target_exp THEN
   -- A payout ledger must never update an unrelated or missing transaction.
   -- A broken reference is a release-blocking integrity error, not a silent success.
   UPDATE public.point_transactions SET exp=target_exp
   WHERE id=old_tx AND boxer_id=boxer AND category='duel_exp';
   IF NOT FOUND THEN
    RAISE EXCEPTION 'Duel reward transaction missing or mismatched for duel % boxer %',d.id,boxer;
   END IF;
   UPDATE public.league_duel_exp_ledger
   SET awarded_exp=target_exp,updated_at=v_clock
   WHERE duel_id=d.id AND boxer_id=boxer;
  END IF;
 END LOOP;
 END IF;

 IF existing_status<>'settled' OR p1<>d.challenger_value OR p2<>d.opponent_value THEN
  INSERT INTO public.league_duel_events(duel_id,event_type,payload)
  VALUES(d.id,CASE WHEN existing_status='settled' THEN 'corrected' ELSE 'settled' END,
   pg_catalog.jsonb_build_object('previous_scores',pg_catalog.jsonb_build_array(d.challenger_value,d.opponent_value),
                                'scores',pg_catalog.jsonb_build_array(p1,p2)));
 END IF;
 RETURN 'settled';
END $function$;


CREATE OR REPLACE FUNCTION league_v21_private.duel_metric_close_confirm_core(
 p_duel_id uuid,p_confirm boolean,p_expected_revision text)
RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=''
AS $fn$
DECLARE d public.league_duels%ROWTYPE; preview jsonb; after_preview jsonb;
 outcome text; bookings jsonb; changed boolean:=false;
BEGIN
 IF p_confirm IS DISTINCT FROM true OR p_expected_revision IS NULL OR length(p_expected_revision)<>32
 THEN RAISE EXCEPTION 'Explicit confirmation of a reviewed result is required' USING errcode='22023'; END IF;
 -- Authorize before looking up participant identities or taking their locks.
 preview:=league_v21_private.duel_metric_close_preview_core(p_duel_id,clock_timestamp());
 SELECT * INTO d FROM public.league_duels WHERE id=p_duel_id;
 IF d.scoring_metric='points' THEN RETURN league_v21_private.duel_close_confirm_core(p_duel_id,p_confirm,p_expected_revision); END IF;
 PERFORM 1 FROM public.profiles WHERE id IN (d.challenger_id,d.opponent_id) ORDER BY id FOR UPDATE;
 SELECT * INTO d FROM public.league_duels WHERE id=p_duel_id FOR UPDATE;
 PERFORM 1 FROM public.training_submissions s
 WHERE s.boxer_id IN(d.challenger_id,d.opponent_id)
  AND s.training_date>=(d.scoring_starts_at AT TIME ZONE 'Europe/Zurich')::date
  AND s.training_date<(d.ends_at AT TIME ZONE 'Europe/Zurich')::date
  AND (s.server_received_at IS NULL OR (s.server_received_at>=d.scoring_starts_at AND s.server_received_at<d.ends_at))
 ORDER BY s.id FOR UPDATE;
 preview:=league_v21_private.duel_metric_close_preview_core(p_duel_id,clock_timestamp());
 IF preview->>'revision' IS DISTINCT FROM p_expected_revision THEN
  outcome:='preview_changed';
 ELSIF (preview->>'can_close')::boolean OR (preview->>'can_correct')::boolean THEN
  outcome:=league_v21_private.duel_metric_reconcile_core(p_duel_id);
  changed:=outcome='settled';
 ELSIF d.status='settled' AND preview->'blockers'='[]'::jsonb THEN
  outcome:='settled';
 ELSIF EXISTS(SELECT 1 FROM pg_catalog.jsonb_array_elements(preview->'blockers') b WHERE b->>'code'='in_progress') THEN
  outcome:='in_progress';
 ELSIF EXISTS(SELECT 1 FROM pg_catalog.jsonb_array_elements(preview->'blockers') b WHERE b->>'code'='pending_reviews') THEN
  outcome:=CASE WHEN d.status='settled' THEN 'pending_correction' ELSE 'awaiting_reviews' END;
 ELSE
  outcome:='blocked';
 END IF;
 after_preview:=league_v21_private.duel_metric_close_preview_core(p_duel_id,clock_timestamp());
 SELECT coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
  'boxer_id',l.boxer_id,'awarded_exp',l.awarded_exp,'transaction_id',l.transaction_id)
  ORDER BY l.boxer_id),'[]'::jsonb) INTO bookings
 FROM public.league_duel_exp_ledger l WHERE l.duel_id=p_duel_id;
 RETURN pg_catalog.jsonb_build_object('outcome',outcome,'preview',after_preview,
  'bookings',bookings,'unchanged',NOT changed);
END $fn$;

-- Legacy points API never processes a metric duel.
CREATE OR REPLACE FUNCTION league_duel_private.duel_v2_live_scores_core(p_duel_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=''
AS $fn$
DECLARE actor public.profiles%ROWTYPE; d public.league_duels%ROWTYPE; score jsonb;
BEGIN
 SELECT * INTO actor FROM public.profiles
 WHERE auth_user_id=(SELECT auth.uid()) AND is_active AND archived_at IS NULL
  AND role IN ('boxer','coach','admin');
 IF NOT FOUND THEN RAISE EXCEPTION 'Authentication required' USING errcode='42501'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.league_feature_flags WHERE feature_key='duels' AND is_enabled)
 THEN RAISE EXCEPTION 'Duels are not enabled' USING errcode='42501'; END IF;
 SELECT * INTO d FROM public.league_duels WHERE id=p_duel_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'Duel not found' USING errcode='22023'; END IF;
 IF d.scoring_metric<>'points' THEN RAISE EXCEPTION 'Use metric duel API for this contract' USING errcode='22023'; END IF;
 IF actor.role='boxer' AND actor.id NOT IN (d.challenger_id,d.opponent_id)
 THEN RAISE EXCEPTION 'Not a duel participant' USING errcode='42501'; END IF;
 IF d.status NOT IN ('active','awaiting_reviews') OR d.accepted_at IS NULL OR d.ends_at IS NULL
 THEN RAISE EXCEPTION 'No live score for this duel' USING errcode='22023'; END IF;
 score:=league_v21_private.duel_points_snapshot(d,statement_timestamp());
 IF NOT (score->>'valid')::boolean THEN
  RAISE EXCEPTION 'Approved duel training has missing, duplicate or invalid scoring ledger'
   USING errcode='23514';
 END IF;
 RETURN pg_catalog.jsonb_build_object('challenger_score',score->'challenger_score',
  'opponent_score',score->'opponent_score','pending',score->'pending',
  'status',d.status,'provisional',true);
END $fn$;

-- Legacy points API never processes a metric duel.
CREATE OR REPLACE FUNCTION league_v21_private.duel_close_preview_core(p_duel_id uuid,p_as_of timestamptz)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=''
AS $fn$
DECLARE d public.league_duels%ROWTYPE; actor public.profiles%ROWTYPE; score jsonb;
 blockers jsonb:='[]'; rewards jsonb:='[]'; result jsonb; snapshots integer;
 cr integer; opr integer; p1 integer; p2 integer; boxer uuid; reward integer;
 ledger public.league_duel_exp_ledger%ROWTYPE; ledger_found boolean;
 payout_valid boolean; all_payouts_valid boolean:=true; winner uuid;
BEGIN
 SELECT * INTO actor FROM public.profiles WHERE auth_user_id=(SELECT auth.uid())
  AND is_active AND archived_at IS NULL AND role IN ('coach','admin');
 IF NOT FOUND THEN RAISE EXCEPTION 'Only active staff may preview closure' USING errcode='42501'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.league_feature_flags WHERE feature_key='duels' AND is_enabled)
 THEN RAISE EXCEPTION 'Duels are not enabled' USING errcode='42501'; END IF;
 SELECT * INTO d FROM public.league_duels WHERE id=p_duel_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'Duel not found' USING errcode='22023'; END IF;
 IF d.scoring_metric<>'points' THEN RAISE EXCEPTION 'Use metric duel API for this contract' USING errcode='22023'; END IF;
 IF d.status NOT IN ('active','awaiting_reviews','settled') OR d.accepted_at IS NULL OR d.ends_at IS NULL
 THEN RAISE EXCEPTION 'Duel has no accepted scoring period' USING errcode='22023'; END IF;
 score:=league_v21_private.duel_points_snapshot(d,p_as_of);
 p1:=(score->>'challenger_score')::integer; p2:=(score->>'opponent_score')::integer;
 IF d.ends_at>p_as_of THEN
  blockers:=blockers||pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object('code','in_progress','message','Der Duellzeitraum läuft noch.'));
 END IF;
 IF (score->>'pending')::integer>0 THEN
  blockers:=blockers||pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object('code','pending_reviews','message','Rechtzeitig eingereichte Trainings warten auf Prüfung.'));
 END IF;
 IF NOT (score->>'valid')::boolean THEN
  blockers:=blockers||pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object('code','scoring_ledger_invalid','message','Punktebuchungen fehlen, sind doppelt oder ergeben eine ungültige Wertung.'));
 END IF;
 SELECT count(*),max(rank_index) FILTER(WHERE boxer_id=d.challenger_id),
  max(rank_index) FILTER(WHERE boxer_id=d.opponent_id) INTO snapshots,cr,opr
 FROM public.league_duel_rank_snapshots_v21 WHERE duel_id=d.id;
 IF snapshots NOT IN (0,2) OR (snapshots=2 AND (cr IS NULL OR opr IS NULL))
  OR (d.scoring_contract IS NOT NULL AND snapshots<>2) THEN
  blockers:=blockers||pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object('code','rank_snapshot_invalid','message','Die gespeicherte Rangregel ist unvollständig.'));
 END IF;
 winner:=CASE WHEN p1>p2 THEN d.challenger_id WHEN p2>p1 THEN d.opponent_id END;
 FOREACH boxer IN ARRAY ARRAY[d.challenger_id,d.opponent_id] LOOP
  reward:=NULL;
  IF (score->>'valid')::boolean AND (d.scoring_contract IS NULL OR snapshots=2)
   AND (snapshots=0 OR (snapshots=2 AND cr IS NOT NULL AND opr IS NOT NULL)) THEN
   reward:=league_v21_private.duel_points_reward(p1=p2,boxer=winner,snapshots,
    CASE WHEN boxer=d.challenger_id THEN cr ELSE opr END,
    CASE WHEN boxer=d.challenger_id THEN opr ELSE cr END);
  END IF;
  SELECT * INTO ledger FROM public.league_duel_exp_ledger WHERE duel_id=d.id AND boxer_id=boxer;
  ledger_found:=FOUND;
  IF NOT ledger_found OR ledger.transaction_id IS NULL THEN
   payout_valid:=d.status<>'settled' AND (NOT ledger_found OR ledger.awarded_exp=0)
    AND NOT EXISTS(SELECT 1 FROM public.point_transactions t WHERE t.boxer_id=boxer
      AND t.category='duel_exp' AND t.description='Duel reward: '||d.id::text);
  ELSE
   payout_valid:=EXISTS(SELECT 1 FROM public.point_transactions t
    WHERE t.id=ledger.transaction_id AND t.boxer_id=boxer AND t.category='duel_exp'
     AND t.points=0 AND t.exp=ledger.awarded_exp AND t.description='Duel reward: '||d.id::text
     AND t.effective_date=(d.ends_at AT TIME ZONE 'Europe/Zurich')::date);
  END IF;
  all_payouts_valid:=all_payouts_valid AND payout_valid;
  rewards:=rewards||pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
   'boxer_id',boxer,'planned_exp',reward,
   'booked_exp',CASE WHEN payout_valid THEN CASE WHEN ledger_found THEN ledger.awarded_exp ELSE 0 END END,
   'delta_exp',CASE WHEN payout_valid THEN reward-CASE WHEN ledger_found THEN ledger.awarded_exp ELSE 0 END END,
   'transaction_id',ledger.transaction_id));
 END LOOP;
 IF NOT all_payouts_valid THEN
  blockers:=blockers||pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object('code','reward_ledger_invalid','message','Die bestehende EXP-Buchung muss vor dem Abschluss geprüft werden.'));
 END IF;
 result:=pg_catalog.jsonb_build_object('duel_id',d.id,'status',d.status,
  'starts_at',d.accepted_at,'ends_at',d.ends_at,
  'rule',coalesce(d.scoring_contract,'{}'::jsonb)||pg_catalog.jsonb_build_object('metric','points','unit','Trainingspunkte',
   'timezone','Europe/Zurich','time_rule','legacy_inclusive_zurich_dates',
   'start_day',(d.accepted_at AT TIME ZONE 'Europe/Zurich')::date,
   'end_day',(d.ends_at AT TIME ZONE 'Europe/Zurich')::date,
   'reward_rule',CASE WHEN d.scoring_contract IS NOT NULL THEN d.scoring_contract->>'reward_rule' WHEN snapshots=0 THEN 'legacy_v2' ELSE 'rank_snapshot_v21' END),
  'scores',score-'missing_ledger'-'duplicate_ledger'-'negative_score'-'valid',
  'winner_id',winner,'tie',p1=p2,'provisional',true,
  'can_close',d.status IN ('active','awaiting_reviews') AND blockers='[]'::jsonb,
  'can_correct',d.status='settled' AND blockers='[]'::jsonb
    AND (p1 IS DISTINCT FROM d.challenger_score OR p2 IS DISTINCT FROM d.opponent_score
       OR EXISTS(SELECT 1 FROM pg_catalog.jsonb_array_elements(rewards) r WHERE (r->>'delta_exp')::integer<>0)),
  'blockers',blockers,'rewards',rewards,'review_path','coach.html');
 RETURN result||pg_catalog.jsonb_build_object('revision',pg_catalog.md5(result::text));
END $fn$;

-- Legacy points API never processes a metric duel.
CREATE OR REPLACE FUNCTION league_v21_private.duel_reconcile_ranked_core(p_duel_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
 d public.league_duels%ROWTYPE;
 actor public.profiles%ROWTYPE;
 v_clock timestamptz := clock_timestamp();
 actor_found boolean;
 p1 integer;
 p2 integer;
 pending_count integer;
 score jsonb;
 target_exp integer;
 boxer uuid;
 old_exp integer;
 old_tx uuid;
 new_tx uuid;
 existing_status text;
 challenger_rank integer; opponent_rank integer; winner_rank integer; loser_rank integer; snapshots integer;
BEGIN
 SELECT * INTO actor FROM public.profiles
 WHERE auth_user_id=(SELECT auth.uid()) AND is_active=true AND archived_at IS NULL;
 actor_found:=FOUND;
 IF NOT EXISTS(SELECT 1 FROM public.league_feature_flags WHERE feature_key='duels' AND is_enabled=true) THEN
  RAISE EXCEPTION 'Duels are not enabled';
 END IF;
 IF NOT actor_found OR actor.role NOT IN ('admin','coach') THEN
  RAISE EXCEPTION 'Only a coach may reconcile duels';
 END IF;
 -- Lock boxer profiles before the duel row, matching invite/respond.
 SELECT * INTO d FROM public.league_duels WHERE id=p_duel_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'Duel not found'; END IF;
 IF d.scoring_metric<>'points' THEN RAISE EXCEPTION 'Use metric duel API for this contract' USING errcode='22023'; END IF;
 PERFORM 1 FROM public.profiles
 WHERE id IN (d.challenger_id,d.opponent_id) ORDER BY id FOR UPDATE;
 SELECT * INTO d FROM public.league_duels WHERE id=p_duel_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Duel not found'; END IF;
 -- A lock wait may cross the duel end timestamp; decide using fresh time.
 v_clock:=clock_timestamp();
 IF d.status NOT IN ('active','awaiting_reviews','settled') THEN
  RAISE EXCEPTION 'Duel not active or completed';
 END IF;
 IF d.ends_at>v_clock THEN RETURN 'in_progress'; END IF;

 -- Lock the qualifying training submissions before counting and scoring.
 -- This serializes concurrent review/edit updates against settlement, so a
 -- submission cannot switch status between pending check and point summation.
 -- Existing review functions must be checked for consistent lock order.
 PERFORM 1 FROM public.training_submissions s
 WHERE s.boxer_id IN (d.challenger_id,d.opponent_id)
   AND s.training_date >= (d.accepted_at AT TIME ZONE 'Europe/Zurich')::date
   AND s.training_date <= (d.ends_at AT TIME ZONE 'Europe/Zurich')::date
   AND coalesce(s.server_received_at,s.created_at)<=d.ends_at
 ORDER BY s.id FOR UPDATE;

 -- Shared scoring validation is evaluated after the existing submission locks.
 score:=league_v21_private.duel_points_snapshot(d,d.ends_at);
 pending_count:=(score->>'pending')::integer;
 IF pending_count>0 THEN
  -- Never reopen an already-paid duel: preserve existing EXP until
  -- pending submissions are reviewed and a coach reconciles again.
  IF d.status='settled' THEN RETURN 'pending_correction'; END IF;
  IF d.status<>'awaiting_reviews' THEN
   UPDATE public.league_duels SET status='awaiting_reviews',updated_at=v_clock
   WHERE id=d.id;
   INSERT INTO public.league_duel_events(duel_id,event_type,payload)
   VALUES(d.id,'awaiting_reviews',pg_catalog.jsonb_build_object('pending',pending_count));
  END IF;
  RETURN 'awaiting_reviews';
 END IF;

 IF NOT (score->>'valid')::boolean THEN
  RAISE EXCEPTION 'Approved duel training has missing, duplicate or invalid scoring ledger'
   USING errcode='23514';
 END IF;
 p1:=(score->>'challenger_score')::integer;
 p2:=(score->>'opponent_score')::integer;

 -- Snapshot at acceptance is mandatory for V2.1 ranked duels; older duels keep legacy rules.
 SELECT count(*) INTO snapshots FROM public.league_duel_rank_snapshots_v21 s WHERE s.duel_id=d.id;
 IF snapshots NOT IN (0,2) OR (d.scoring_contract IS NOT NULL AND snapshots<>2) THEN RAISE EXCEPTION 'Incomplete duel rank snapshots' using errcode='23514';END IF;
 IF snapshots=2 THEN
  SELECT s.rank_index INTO challenger_rank FROM public.league_duel_rank_snapshots_v21 s
   WHERE s.duel_id=d.id AND s.boxer_id=d.challenger_id;
  SELECT s.rank_index INTO opponent_rank FROM public.league_duel_rank_snapshots_v21 s
   WHERE s.duel_id=d.id AND s.boxer_id=d.opponent_id;
  IF challenger_rank IS NULL OR opponent_rank IS NULL THEN
   RAISE EXCEPTION 'Duel rank snapshot participants mismatch' using errcode='23514';
  END IF;
  winner_rank:=CASE WHEN p1>p2 THEN challenger_rank ELSE opponent_rank END;
  loser_rank:=CASE WHEN p1>p2 THEN opponent_rank ELSE challenger_rank END;
 END IF;
 existing_status:=d.status;
 UPDATE public.league_duels
 SET status='settled',settled_at=COALESCE(settled_at,v_clock),
     challenger_score=p1,opponent_score=p2,
     winner_id=CASE WHEN p1=p2 THEN NULL WHEN p1>p2 THEN d.challenger_id ELSE d.opponent_id END,
     updated_at=v_clock
 WHERE id=d.id;

 FOREACH boxer IN ARRAY ARRAY[d.challenger_id,d.opponent_id] LOOP
  target_exp:=league_v21_private.duel_points_reward(p1=p2,
   (p1>p2 AND boxer=d.challenger_id) OR (p2>p1 AND boxer=d.opponent_id),snapshots,
   CASE WHEN boxer=d.challenger_id THEN challenger_rank ELSE opponent_rank END,
   CASE WHEN boxer=d.challenger_id THEN opponent_rank ELSE challenger_rank END);

  INSERT INTO public.league_duel_exp_ledger(duel_id,boxer_id,awarded_exp)
  VALUES(d.id,boxer,0)
  ON CONFLICT(duel_id,boxer_id) DO NOTHING;

  SELECT awarded_exp,transaction_id INTO old_exp,old_tx
  FROM public.league_duel_exp_ledger
  WHERE duel_id=d.id AND boxer_id=boxer FOR UPDATE;

  IF old_tx IS NULL THEN
   -- A settled duel must already have a payout transaction for each boxer.
   -- Never silently reconstruct a missing payout during a correction.
   IF existing_status='settled' THEN
    RAISE EXCEPTION 'Settled duel payout transaction missing for duel % boxer %',d.id,boxer;
   END IF;
   -- A missing transaction reference is valid only for a new, unpaid ledger.
   -- Do not create another reward if the ledger already claims EXP was paid.
   IF old_exp IS DISTINCT FROM 0 THEN
    RAISE EXCEPTION 'Duel reward ledger claims EXP without transaction for duel % boxer %',d.id,boxer;
   END IF;
   -- Never create a second payout if a duel_exp transaction already exists
   -- but the ledger reference was lost (including on a first settlement).
   IF EXISTS (
    SELECT 1 FROM public.point_transactions t
    WHERE t.boxer_id=boxer AND t.category='duel_exp'
      AND t.description='Duel reward: '||d.id::text
   ) THEN
    RAISE EXCEPTION 'Orphaned duel payout transaction for duel % boxer %',d.id,boxer;
   END IF;
   INSERT INTO public.point_transactions
    (boxer_id,points,exp,category,description,effective_date,created_by)
   VALUES(boxer,0,target_exp,'duel_exp',
          'Duel reward: '||d.id::text,
          (d.ends_at AT TIME ZONE 'Europe/Zurich')::date,actor.id)
   RETURNING id INTO new_tx;
   UPDATE public.league_duel_exp_ledger
   SET transaction_id=new_tx,awarded_exp=target_exp,updated_at=v_clock
   WHERE duel_id=d.id AND boxer_id=boxer;
  ELSIF old_exp IS NULL THEN
   RAISE EXCEPTION 'Duel reward ledger has NULL EXP for duel % boxer %',d.id,boxer;
  ELSIF NOT EXISTS(
   SELECT 1 FROM public.point_transactions t
   WHERE t.id=old_tx AND t.boxer_id=boxer AND t.category='duel_exp'
     AND t.points=0 AND t.exp=old_exp
     AND t.description='Duel reward: '||d.id::text
     AND t.effective_date=(d.ends_at AT TIME ZONE 'Europe/Zurich')::date
  ) THEN
   RAISE EXCEPTION 'Duel reward ledger mismatch for duel % boxer %',d.id,boxer;
  ELSIF old_exp<>target_exp THEN
   -- A payout ledger must never update an unrelated or missing transaction.
   -- A broken reference is a release-blocking integrity error, not a silent success.
   UPDATE public.point_transactions SET exp=target_exp
   WHERE id=old_tx AND boxer_id=boxer AND category='duel_exp';
   IF NOT FOUND THEN
    RAISE EXCEPTION 'Duel reward transaction missing or mismatched for duel % boxer %',d.id,boxer;
   END IF;
   UPDATE public.league_duel_exp_ledger
   SET awarded_exp=target_exp,updated_at=v_clock
   WHERE duel_id=d.id AND boxer_id=boxer;
  END IF;
 END LOOP;

 IF existing_status<>'settled' OR p1<>d.challenger_score OR p2<>d.opponent_score THEN
  INSERT INTO public.league_duel_events(duel_id,event_type,payload)
  VALUES(d.id,CASE WHEN existing_status='settled' THEN 'corrected' ELSE 'settled' END,
   pg_catalog.jsonb_build_object('previous_scores',pg_catalog.jsonb_build_array(d.challenger_score,d.opponent_score),
                                'scores',pg_catalog.jsonb_build_array(p1,p2)));
 END IF;
 RETURN 'settled';
END $function$;

CREATE OR REPLACE FUNCTION public.duel_v2_list_mine()
 RETURNS TABLE(id uuid, challenger_id uuid, challenger_name text, opponent_id uuid, opponent_name text, status text, duration_days integer, invited_at timestamp with time zone, expires_at timestamp with time zone, accepted_at timestamp with time zone, ends_at timestamp with time zone, settled_at timestamp with time zone, challenger_score integer, opponent_score integer, winner_id uuid)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_profile uuid;
BEGIN
 SELECT p.id INTO v_profile FROM public.profiles p
 WHERE p.auth_user_id=(SELECT auth.uid()) AND p.is_active=true AND p.archived_at IS NULL
 AND p.role IN ('boxer','admin','coach');
 IF v_profile IS NULL THEN RAISE EXCEPTION 'Not authorized'; END IF;
 IF NOT EXISTS (
  SELECT 1 FROM public.league_feature_flags
  WHERE feature_key='duels' AND is_enabled=true
 ) THEN RAISE EXCEPTION 'Duels are not enabled'; END IF;
 RETURN QUERY
 SELECT d.id,d.challenger_id,c.display_name::text,
        d.opponent_id,o.display_name::text,d.status,d.duration_days,
        d.invited_at,d.expires_at,d.accepted_at,d.ends_at,d.settled_at,
        d.challenger_score,d.opponent_score,d.winner_id
 FROM public.league_duels d
 JOIN public.profiles c ON c.id=d.challenger_id
 JOIN public.profiles o ON o.id=d.opponent_id
 WHERE d.scoring_metric='points' AND (d.challenger_id=v_profile OR d.opponent_id=v_profile
    OR EXISTS(SELECT 1 FROM public.profiles p WHERE p.id=v_profile
              AND p.role IN ('admin','coach')))
 ORDER BY d.invited_at DESC LIMIT 100;
END $function$;

CREATE OR REPLACE FUNCTION public.duel_v2_reconcile_due(p_include_settled boolean DEFAULT false, p_after uuid DEFAULT NULL::uuid)
 RETURNS TABLE(duel_id uuid, outcome text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
 actor_role text;
 item record;
BEGIN
 SELECT p.role INTO actor_role FROM public.profiles p
 WHERE p.auth_user_id=(SELECT auth.uid()) AND p.is_active=true AND p.archived_at IS NULL;
 IF actor_role IS NULL OR actor_role NOT IN ('admin','coach') THEN
  RAISE EXCEPTION 'Only a coach may reconcile duels';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM public.league_feature_flags
               WHERE feature_key='duels' AND is_enabled=true) THEN
  RAISE EXCEPTION 'Duels are not enabled';
 END IF;
 FOR item IN
  SELECT d.id FROM public.league_duels d
  WHERE (d.status IN ('active','awaiting_reviews')
         OR (p_include_settled AND d.status='settled'))
    AND d.scoring_metric='points' AND d.ends_at<=clock_timestamp()
    AND (p_after IS NULL OR d.id>p_after)
  ORDER BY d.id LIMIT 100
 LOOP
  duel_id:=item.id;
  outcome:=public.duel_v2_reconcile(item.id);
  RETURN NEXT;
 END LOOP;
END $function$;
CREATE OR REPLACE FUNCTION league_v21_private.sync_public_duel_history()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
 -- Every V3 contract has explicit participant/club visibility, including points contracts.
 -- The old anonymous projection remains limited to legacy NULL-contract points.
 if new.scoring_metric<>'points' OR new.scoring_contract IS NOT NULL then return NEW; end if;
 if new.status='settled' and new.settled_at is not null then
  insert into public.league_public_duel_history_v21(
   duel_id,challenger_id,opponent_id,challenger_name,opponent_name,
   challenger_score,opponent_score,winner_id,settled_at)
  values(new.id,new.challenger_id,new.opponent_id,
   league_v21_private.public_display_name(new.challenger_id),
   league_v21_private.public_display_name(new.opponent_id),
   new.challenger_score,new.opponent_score,new.winner_id,new.settled_at)
  on conflict(duel_id) do update
  set challenger_name=excluded.challenger_name,opponent_name=excluded.opponent_name,
   challenger_score=excluded.challenger_score,opponent_score=excluded.opponent_score,
   winner_id=excluded.winner_id,settled_at=excluded.settled_at,updated_at=now();
 else
  delete from public.league_public_duel_history_v21 where duel_id=new.id;
 end if;
 return new;
end$function$;


-- Event identity retained; metric notices use the same stored numeric result and rule.
CREATE OR REPLACE FUNCTION league_v21_private.notify_duel_events()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $fn$
declare ch text; op text; score_ch text; score_op text; unit text;
begin
 if not league_v21_private.notifications_enabled() then return NEW; end if;
 if TG_OP='UPDATE' and NEW.status is not distinct from OLD.status then return NEW; end if;
 score_ch:=CASE WHEN NEW.scoring_metric='points' THEN NEW.challenger_score::text ELSE NEW.challenger_value::text END;
 score_op:=CASE WHEN NEW.scoring_metric='points' THEN NEW.opponent_score::text ELSE NEW.opponent_value::text END;
 unit:=CASE WHEN NEW.scoring_metric='points' THEN 'Trainingspunkte' ELSE NEW.scoring_contract->>'unit' END;
 select display_name into ch from public.profiles where id=NEW.challenger_id;
 select display_name into op from public.profiles where id=NEW.opponent_id;
 if TG_OP='INSERT' and NEW.status='pending' then
  insert into public.boxer_notifications(recipient_id,notification_type,title,message,target_path,event_key)
  values(NEW.opponent_id,'boxer_duel',pg_catalog.left('Duell-Einladung von '||coalesce(ch,'einem Boxer'),160),
   'Duell über '||NEW.duration_days||' Tage. Nimm die Einladung innerhalb von 48 Stunden an oder lehne sie ab.',
   '/duels.html?duel='||NEW.id::text,'duel:'||NEW.id::text||':invited')
  ON CONFLICT(recipient_id,event_key) WHERE event_key IS NOT NULL DO NOTHING;
 elsif TG_OP='UPDATE' and NEW.status='active' and OLD.status='pending' then
  insert into public.boxer_notifications(recipient_id,notification_type,title,message,target_path,event_key)
  values(NEW.challenger_id,'boxer_duel',pg_catalog.left(coalesce(op,'Dein Gegner')||' hat dein Duell angenommen',160),
   CASE WHEN NEW.scoring_metric='points' THEN 'Das Duell läuft jetzt '||NEW.duration_days||' Tage. Jedes bestätigte Training zählt.'
   ELSE (NEW.scoring_contract->>'label')||': Start '||to_char(NEW.scoring_starts_at AT TIME ZONE 'Europe/Zurich','DD.MM.YYYY')||
    ', '||NEW.duration_days||' volle Tage. '||(NEW.scoring_contract->>'reward_label')||'.' END,
   '/duels.html?duel='||NEW.id::text,'duel:'||NEW.id::text||':accepted')
  ON CONFLICT(recipient_id,event_key) WHERE event_key IS NOT NULL DO NOTHING;
 elsif TG_OP='UPDATE' and NEW.status='declined' and OLD.status='pending' then
  insert into public.boxer_notifications(recipient_id,notification_type,title,message,target_path,event_key)
  values(NEW.challenger_id,'boxer_duel',pg_catalog.left(coalesce(op,'Dein Gegner')||' hat dein Duell abgelehnt',160),
   'Du kannst jederzeit einen anderen Gegner herausfordern.',
   '/duels.html?duel='||NEW.id::text,'duel:'||NEW.id::text||':declined')
  ON CONFLICT(recipient_id,event_key) WHERE event_key IS NOT NULL DO NOTHING;
 elsif TG_OP='UPDATE' and NEW.status='settled' then
  insert into public.boxer_notifications(recipient_id,notification_type,title,message,target_path,event_key)
  select r.id,'boxer_duel',
   pg_catalog.left(case when NEW.winner_id is null then 'Duell gegen '||r.other||': Unentschieden'
        when NEW.winner_id=r.id then 'Duell gegen '||r.other||' gewonnen'
        else 'Duell gegen '||r.other||' verloren' end,160),
   'Endstand '||score_ch||' : '||score_op||' '||unit||'.'||
    case when NEW.winner_id is not null and NEW.winner_id<>r.id then ' Revanche? In den Duellen kannst du direkt erneut herausfordern.' else '' end,
   '/duels.html?duel='||NEW.id::text,'duel:'||NEW.id::text||':settled'
  from (values (NEW.challenger_id,coalesce(op,'Gegner')),(NEW.opponent_id,coalesce(ch,'Gegner'))) r(id,other)
  ON CONFLICT(recipient_id,event_key) WHERE event_key IS NOT NULL DO NOTHING;
 end if;
 return NEW;
end$fn$;


REVOKE ALL ON FUNCTION league_v21_private.duel_v3_options_core() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION league_v21_private.duel_v3_options_core() TO authenticated;
CREATE OR REPLACE FUNCTION public.duel_v3_options()
RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER SET search_path=''
AS $api$ SELECT league_v21_private.duel_v3_options_core() $api$;
REVOKE ALL ON FUNCTION public.duel_v3_options() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.duel_v3_options() TO authenticated;

REVOKE ALL ON FUNCTION league_v21_private.duel_v3_invite_core(uuid,uuid,integer,text,bigint,text,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION league_v21_private.duel_v3_invite_core(uuid,uuid,integer,text,bigint,text,jsonb) TO authenticated;
CREATE OR REPLACE FUNCTION public.duel_v3_invite(p_challenger uuid,p_opponent uuid,p_duration_days integer,p_metric text,p_training_type_id bigint DEFAULT NULL,p_visibility text DEFAULT 'participants',p_expected_rule jsonb DEFAULT NULL)
RETURNS uuid LANGUAGE sql VOLATILE SECURITY INVOKER SET search_path=''
AS $api$ SELECT league_v21_private.duel_v3_invite_core(p_challenger,p_opponent,p_duration_days,p_metric,p_training_type_id,p_visibility,p_expected_rule) $api$;
REVOKE ALL ON FUNCTION public.duel_v3_invite(uuid,uuid,integer,text,bigint,text,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.duel_v3_invite(uuid,uuid,integer,text,bigint,text,jsonb) TO authenticated;

REVOKE ALL ON FUNCTION league_v21_private.duel_v3_list_core(text,text,integer,timestamptz,uuid,text,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION league_v21_private.duel_v3_list_core(text,text,integer,timestamptz,uuid,text,uuid) TO authenticated;
CREATE OR REPLACE FUNCTION public.duel_v3_list(p_scope text DEFAULT 'mine',p_state text DEFAULT 'all',p_limit integer DEFAULT 20,p_before timestamptz DEFAULT NULL,p_before_id uuid DEFAULT NULL,p_search text DEFAULT NULL,p_duel_id uuid DEFAULT NULL)
RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER SET search_path=''
AS $api$ SELECT league_v21_private.duel_v3_list_core(p_scope,p_state,p_limit,p_before,p_before_id,p_search,p_duel_id) $api$;
REVOKE ALL ON FUNCTION public.duel_v3_list(text,text,integer,timestamptz,uuid,text,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.duel_v3_list(text,text,integer,timestamptz,uuid,text,uuid) TO authenticated;

REVOKE ALL ON FUNCTION league_v21_private.duel_v3_live_scores_core(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION league_v21_private.duel_v3_live_scores_core(uuid) TO authenticated;
CREATE OR REPLACE FUNCTION public.duel_v3_live_scores(p_duel_id uuid)
RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER SET search_path=''
AS $api$ SELECT league_v21_private.duel_v3_live_scores_core(p_duel_id) $api$;
REVOKE ALL ON FUNCTION public.duel_v3_live_scores(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.duel_v3_live_scores(uuid) TO authenticated;

REVOKE ALL ON FUNCTION league_v21_private.duel_metric_close_preview_core(uuid,timestamptz) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION league_v21_private.duel_metric_close_preview_core(uuid,timestamptz) TO authenticated;
CREATE OR REPLACE FUNCTION public.duel_v3_close_preview(p_duel_id uuid)
RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER SET search_path=''
AS $api$ SELECT league_v21_private.duel_metric_close_preview_core(p_duel_id,statement_timestamp()) $api$;
REVOKE ALL ON FUNCTION public.duel_v3_close_preview(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.duel_v3_close_preview(uuid) TO authenticated;

REVOKE ALL ON FUNCTION league_v21_private.duel_metric_close_confirm_core(uuid,boolean,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION league_v21_private.duel_metric_close_confirm_core(uuid,boolean,text) TO authenticated;
CREATE OR REPLACE FUNCTION public.duel_v3_close_confirm(p_duel_id uuid,p_confirm boolean,p_expected_revision text)
RETURNS jsonb LANGUAGE sql VOLATILE SECURITY INVOKER SET search_path=''
AS $api$ SELECT league_v21_private.duel_metric_close_confirm_core(p_duel_id,p_confirm,p_expected_revision) $api$;
REVOKE ALL ON FUNCTION public.duel_v3_close_confirm(uuid,boolean,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.duel_v3_close_confirm(uuid,boolean,text) TO authenticated;

REVOKE ALL ON FUNCTION league_v21_private.duel_metric_reconcile_core(uuid) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.duel_v2_list_mine(),public.duel_v2_reconcile_due(boolean,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.duel_v2_list_mine(),public.duel_v2_reconcile_due(boolean,uuid) TO authenticated;
-- Preserve historical point receipt semantics; trust server receipts for all new submissions.
CREATE OR REPLACE FUNCTION league_v21_private.duel_points_snapshot(
 p_duel public.league_duels, p_as_of timestamptz)
RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER SET search_path=''
AS $sql$
 WITH relevant AS MATERIALIZED (
  SELECT s.id,s.boxer_id,s.status
  FROM public.training_submissions s
  WHERE s.boxer_id IN (p_duel.challenger_id,p_duel.opponent_id)
   AND coalesce(s.server_received_at,s.created_at)<=least(p_as_of,p_duel.ends_at)
   AND s.training_date BETWEEN (p_duel.accepted_at AT TIME ZONE 'Europe/Zurich')::date
       AND least((p_duel.ends_at AT TIME ZONE 'Europe/Zurich')::date,
                 (p_as_of AT TIME ZONE 'Europe/Zurich')::date)
 ), scored AS (
  SELECT s.id,s.boxer_id,count(t.id) ledger_count,coalesce(sum(t.points),0) points
  FROM relevant s LEFT JOIN public.point_transactions t
   ON t.submission_id=s.id AND t.boxer_id=s.boxer_id
   AND t.category IN ('training','legacy_import')
  WHERE s.status='approved' GROUP BY s.id,s.boxer_id
 ), totals AS (
  SELECT count(*) FILTER (WHERE ledger_count=0)::integer missing_ledger,
   count(*) FILTER (WHERE ledger_count>1)::integer duplicate_ledger,
   coalesce(sum(points) FILTER (WHERE boxer_id=p_duel.challenger_id),0) p1,
   coalesce(sum(points) FILTER (WHERE boxer_id=p_duel.opponent_id),0) p2
  FROM scored
 )
 SELECT pg_catalog.jsonb_build_object(
  'challenger_score',CASE WHEN missing_ledger=0 AND duplicate_ledger=0 AND p1>=0 AND p2>=0 THEN p1::integer END,
  'opponent_score',CASE WHEN missing_ledger=0 AND duplicate_ledger=0 AND p1>=0 AND p2>=0 THEN p2::integer END,
  'pending',(SELECT count(*) FROM relevant WHERE status='pending'),
  'approved',(SELECT count(*) FROM relevant WHERE status='approved'),
  'rejected',(SELECT count(*) FROM relevant WHERE status='rejected'),
  'missing_ledger',missing_ledger,'duplicate_ledger',duplicate_ledger,
  'negative_score',p1<0 OR p2<0,
  'valid',missing_ledger=0 AND duplicate_ledger=0 AND p1>=0 AND p2>=0)
 FROM totals
$sql$;
CREATE OR REPLACE FUNCTION league_v21_private.duel_close_confirm_core(
 p_duel_id uuid,p_confirm boolean,p_expected_revision text)
RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=''
AS $fn$
DECLARE d public.league_duels%ROWTYPE; preview jsonb; after_preview jsonb;
 outcome text; bookings jsonb; changed boolean:=false;
BEGIN
 IF p_confirm IS DISTINCT FROM true OR p_expected_revision IS NULL OR length(p_expected_revision)<>32
 THEN RAISE EXCEPTION 'Explicit confirmation of a reviewed result is required' USING errcode='22023'; END IF;
 -- Authorize before looking up participant identities or taking their locks.
 preview:=league_v21_private.duel_close_preview_core(p_duel_id,clock_timestamp());
 SELECT * INTO d FROM public.league_duels WHERE id=p_duel_id;
 PERFORM 1 FROM public.profiles WHERE id IN (d.challenger_id,d.opponent_id) ORDER BY id FOR UPDATE;
 SELECT * INTO d FROM public.league_duels WHERE id=p_duel_id FOR UPDATE;
 PERFORM 1 FROM public.training_submissions s
 WHERE s.boxer_id IN (d.challenger_id,d.opponent_id)
  AND s.training_date BETWEEN (d.accepted_at AT TIME ZONE 'Europe/Zurich')::date
    AND (d.ends_at AT TIME ZONE 'Europe/Zurich')::date AND coalesce(s.server_received_at,s.created_at)<=d.ends_at
 ORDER BY s.id FOR UPDATE;
 preview:=league_v21_private.duel_close_preview_core(p_duel_id,clock_timestamp());
 IF preview->>'revision' IS DISTINCT FROM p_expected_revision THEN
  outcome:='preview_changed';
 ELSIF (preview->>'can_close')::boolean OR (preview->>'can_correct')::boolean THEN
  outcome:=league_v21_private.duel_reconcile_ranked_core(p_duel_id);
  changed:=outcome='settled';
 ELSIF d.status='settled' AND preview->'blockers'='[]'::jsonb THEN
  outcome:='settled';
 ELSIF EXISTS(SELECT 1 FROM pg_catalog.jsonb_array_elements(preview->'blockers') b WHERE b->>'code'='in_progress') THEN
  outcome:='in_progress';
 ELSIF EXISTS(SELECT 1 FROM pg_catalog.jsonb_array_elements(preview->'blockers') b WHERE b->>'code'='pending_reviews') THEN
  outcome:=CASE WHEN d.status='settled' THEN 'pending_correction' ELSE 'awaiting_reviews' END;
 ELSE
  outcome:='blocked';
 END IF;
 after_preview:=league_v21_private.duel_close_preview_core(p_duel_id,clock_timestamp());
 SELECT coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
  'boxer_id',l.boxer_id,'awarded_exp',l.awarded_exp,'transaction_id',l.transaction_id)
  ORDER BY l.boxer_id),'[]'::jsonb) INTO bookings
 FROM public.league_duel_exp_ledger l WHERE l.duel_id=p_duel_id;
 RETURN pg_catalog.jsonb_build_object('outcome',outcome,'preview',after_preview,
  'bookings',bookings,'unchanged',NOT changed);
END $fn$;
NOTIFY pgrst,'reload schema';
COMMIT;
