-- Rollback für 20261028230000_club_schedule_tiers.sql (Etappe 6a).
-- WICHTIG: Falls die Aktivierung bereits ausgeführt wurde, ZUERST
--   supabase/production-prep/deactivate_20261028230000_club_schedule_tiers.sql ausführen (stellt Punkte und Punktwerte wieder her).
-- Danach stellt dieses Skript die Funktionen der Etappen 2 bis 5 wieder her, entfernt die neuen Funktionen und den Einreich-Schutz
-- und schaltet die Pflicht-Quest aus. Tabellen, Spalten und Daten (Stundenplan, Stufen, Einstufungen) bleiben erhalten.
BEGIN;
DROP TRIGGER IF EXISTS league_training_insert_guard ON public.training_submissions;
DROP FUNCTION IF EXISTS public.staff_open_club_session(integer);
DROP FUNCTION IF EXISTS public.staff_update_gym_session(bigint,bigint,text);
DROP FUNCTION IF EXISTS public.staff_set_training_tier(uuid,text);
DROP FUNCTION IF EXISTS public.staff_training_tiers(uuid[]);
DROP FUNCTION IF EXISTS public.get_club_schedule();
DROP FUNCTION IF EXISTS public.admin_save_club_slot(integer,integer,bigint,text,text,integer,boolean);
UPDATE public.quest_definitions SET is_active=false WHERE key='pflicht';

-- Vorherige Versionen (Etappen 2 bis 5 und Produktion)
CREATE OR REPLACE FUNCTION public.staff_open_gym_session(p_training_type_id bigint, p_duration_minutes integer, p_note text, p_group_key text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.require_staff(); t public.training_types; g public.training_groups; new_id bigint; note text;
BEGIN
 SELECT * INTO t FROM public.training_types x WHERE x.id=p_training_type_id AND x.is_active;
 IF NOT FOUND THEN RAISE EXCEPTION 'Bitte eine gültige Trainingsart wählen' USING ERRCODE='22023'; END IF;
 IF t.name='Joggen' THEN RAISE EXCEPTION 'Joggen bitte einzeln mit Distanz eintragen, nicht über den Gym-Check-in' USING ERRCODE='22023'; END IF;
 IF p_duration_minutes IS NULL OR p_duration_minutes NOT BETWEEN 1 AND 1440 THEN RAISE EXCEPTION 'Bitte die Dauer in Minuten angeben' USING ERRCODE='22023'; END IF;
 note := pg_catalog.btrim(coalesce(p_note,''));
 IF pg_catalog.char_length(note)<3 OR pg_catalog.char_length(note)>500 THEN RAISE EXCEPTION 'Bitte eine Bemerkung für alle angeben (mindestens 3 Zeichen)' USING ERRCODE='22023'; END IF;
 IF p_group_key IS NOT NULL AND p_group_key<>'' THEN
  SELECT * INTO g FROM public.training_groups x WHERE x.key=p_group_key;
  IF NOT FOUND THEN RAISE EXCEPTION 'Unbekannte Trainingsgruppe' USING ERRCODE='22023'; END IF;
 END IF;
 INSERT INTO public.gym_sessions(session_date,training_type_id,duration_minutes,note,group_id,opened_by)
 VALUES (league_private.zurich_today(),t.id,p_duration_minutes,note,g.id,me.id) RETURNING id INTO new_id;
 RETURN pg_catalog.jsonb_build_object('id',new_id,'session_date',league_private.zurich_today());
END;
$fn$;

CREATE OR REPLACE FUNCTION public.staff_list_gym_sessions(p_days integer DEFAULT 14)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.require_staff();
BEGIN
 RETURN coalesce((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id',s.id,'session_date',s.session_date,'status',s.status,
   'training_type',t.name,'training_type_id',s.training_type_id,'duration_minutes',s.duration_minutes,'note',s.note,
   'group',(SELECT g.key FROM public.training_groups g WHERE g.id=s.group_id),
   'opened_by',(SELECT p.display_name FROM public.profiles p WHERE p.id=s.opened_by),
   'present',(SELECT count(*) FROM public.gym_attendance a WHERE a.session_id=s.id),
   'confirmed',(SELECT count(*) FROM public.gym_attendance a WHERE a.session_id=s.id AND a.submission_id IS NOT NULL))
   ORDER BY s.session_date DESC, s.id DESC)
  FROM public.gym_sessions s JOIN public.training_types t ON t.id=s.training_type_id
  WHERE s.session_date >= league_private.zurich_today() - LEAST(GREATEST(coalesce(p_days,14),1),120)),'[]'::jsonb);
END;
$fn$;

CREATE OR REPLACE FUNCTION public.staff_get_gym_session(p_session_id bigint)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.require_staff(); s public.gym_sessions;
BEGIN
 SELECT * INTO s FROM public.gym_sessions x WHERE x.id=p_session_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'Einheit nicht gefunden' USING ERRCODE='22023'; END IF;
 RETURN pg_catalog.jsonb_build_object('id',s.id,'session_date',s.session_date,'status',s.status,'duration_minutes',s.duration_minutes,'note',s.note,
  'training_type',(SELECT t.name FROM public.training_types t WHERE t.id=s.training_type_id),
  'group',(SELECT g.key FROM public.training_groups g WHERE g.id=s.group_id),
  'people',coalesce((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id',p.id,'display_name',p.display_name,'is_self',p.id=me.id,
     'group',(SELECT g.key FROM public.training_group_members m JOIN public.training_groups g ON g.id=m.group_id WHERE m.profile_id=p.id),
     'present',a.profile_id IS NOT NULL,'source',a.source,'confirmed',a.submission_id IS NOT NULL,'skipped_reason',a.skipped_reason)
     ORDER BY pg_catalog.lower(p.display_name))
    FROM public.profiles p LEFT JOIN public.gym_attendance a ON a.session_id=s.id AND a.profile_id=p.id
    WHERE (p.is_active AND p.archived_at IS NULL AND p.role IN ('boxer','coach')) OR a.profile_id IS NOT NULL),'[]'::jsonb));
END;
$fn$;

CREATE OR REPLACE FUNCTION public.staff_confirm_gym_session(p_session_id bigint)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.require_staff(); s public.gym_sessions; a record; r jsonb;
 n integer := 0; pts integer := 0; skipped jsonb := '[]'::jsonb; reason text;
BEGIN
 SELECT * INTO s FROM public.gym_sessions x WHERE x.id=p_session_id FOR UPDATE;
 IF NOT FOUND OR s.status<>'open' THEN RAISE EXCEPTION 'Diese Einheit ist schon abgeschlossen' USING ERRCODE='55000'; END IF;
 IF NOT EXISTS (SELECT 1 FROM public.gym_attendance x WHERE x.session_id=s.id) THEN RAISE EXCEPTION 'Noch niemand als anwesend markiert' USING ERRCODE='22023'; END IF;
 FOR a IN SELECT x.profile_id, p.display_name, p.role, p.is_active, p.archived_at FROM public.gym_attendance x JOIN public.profiles p ON p.id=x.profile_id
          WHERE x.session_id=s.id AND x.submission_id IS NULL ORDER BY pg_catalog.lower(p.display_name) LOOP
  reason := NULL;
  IF a.profile_id=me.id THEN reason := 'eigenes Training – bitte normal einreichen';
  ELSIF a.role NOT IN ('boxer','coach') OR NOT a.is_active OR a.archived_at IS NOT NULL THEN reason := 'Profil nicht aktiv';
  ELSIF EXISTS (SELECT 1 FROM public.training_submissions t WHERE t.boxer_id=a.profile_id AND t.training_date=s.session_date
                AND t.training_type_id=s.training_type_id AND t.status IN ('pending','approved')) THEN reason := 'hat dieses Training schon eingereicht';
  END IF;
  IF reason IS NOT NULL THEN
   UPDATE public.gym_attendance x SET skipped_reason=reason WHERE x.session_id=s.id AND x.profile_id=a.profile_id;
   skipped := skipped || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object('name',a.display_name,'reason',reason));
   CONTINUE;
  END IF;
  r := public.staff_record_training(a.profile_id, s.training_type_id, s.session_date, s.duration_minutes, s.note, NULL,
        pg_catalog.md5('gym:'||s.id::text||':'||a.profile_id::text)::uuid);
  UPDATE public.gym_attendance x SET submission_id=(r->>'submission_id')::uuid, skipped_reason=NULL WHERE x.session_id=s.id AND x.profile_id=a.profile_id;
  n := n+1; pts := pts+coalesce((r->>'points_awarded')::integer,0);
 END LOOP;
 UPDATE public.gym_sessions x SET status='confirmed', confirmed_at=now(), confirmed_by=me.id WHERE x.id=s.id;
 RETURN pg_catalog.jsonb_build_object('confirmed',n,'points_awarded',pts,'skipped',skipped);
END;
$fn$;

CREATE OR REPLACE FUNCTION public.my_gym_sessions_today()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer();
BEGIN
 IF me.id IS NULL THEN RAISE EXCEPTION 'Bitte anmelden' USING ERRCODE='42501'; END IF;
 IF NOT league_private.flag_on('gym_training') AND me.role NOT IN ('admin','coach') THEN RETURN '[]'::jsonb; END IF;
 RETURN coalesce((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id',s.id,'training_type',t.name,'duration_minutes',s.duration_minutes,
   'note',s.note,'group',(SELECT g.name FROM public.training_groups g WHERE g.id=s.group_id),
   'checked_in',EXISTS (SELECT 1 FROM public.gym_attendance a WHERE a.session_id=s.id AND a.profile_id=me.id)) ORDER BY s.id)
  FROM public.gym_sessions s JOIN public.training_types t ON t.id=s.training_type_id
  WHERE s.status='open' AND s.session_date=league_private.zurich_today()),'[]'::jsonb);
END;
$fn$;

CREATE OR REPLACE FUNCTION public.get_my_presence()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); today date := league_private.zurich_today(); from_d date;
BEGIN
 IF me.id IS NULL THEN RAISE EXCEPTION 'Bitte anmelden' USING ERRCODE='42501'; END IF;
 IF NOT league_private.flag_on('gym_training') AND me.role<>'admin' THEN RETURN pg_catalog.jsonb_build_object('enabled',false); END IF;
 from_d := league_private.week_monday(today) - 21;
 RETURN pg_catalog.jsonb_build_object('enabled',true,'today',today,
  'group',league_private.group_json(league_private.group_of(me.id)),
  'days',(SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('date',d::date,
     'trainings',(SELECT count(*) FROM public.training_submissions s WHERE s.boxer_id=me.id AND s.status='approved' AND s.training_date=d::date),
     'pending',(SELECT count(*) FROM public.training_submissions s WHERE s.boxer_id=me.id AND s.status='pending' AND s.training_date=d::date),
     'gym',EXISTS (SELECT 1 FROM public.gym_attendance a JOIN public.gym_sessions g ON g.id=a.session_id
                   WHERE a.profile_id=me.id AND g.session_date=d::date AND g.status<>'cancelled')) ORDER BY d)
     FROM pg_catalog.generate_series(from_d::timestamp, (from_d+27)::timestamp, interval '1 day') d),
  'weeks',league_private.presence_weeks(me.id,4),
  'streak_weeks',league_private.presence_streak(me.id));
END;
$fn$;

CREATE OR REPLACE FUNCTION public.staff_presence_overview()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.require_staff();
BEGIN
 RETURN coalesce((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id',p.id,'display_name',p.display_name,
   'group',league_private.group_json(league_private.group_of(p.id)),
   'weeks',league_private.presence_weeks(p.id,4),'streak_weeks',league_private.presence_streak(p.id),
   'last_training',(SELECT max(s.training_date) FROM public.training_submissions s WHERE s.boxer_id=p.id AND s.status='approved'))
   ORDER BY pg_catalog.lower(p.display_name))
  FROM public.profiles p WHERE p.is_active AND p.archived_at IS NULL AND p.role IN ('boxer','coach')),'[]'::jsonb);
END;
$fn$;

CREATE OR REPLACE FUNCTION public.staff_get_training_plan(p_group_key text, p_week_start date)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.require_staff(); g public.training_groups; pl public.training_plans;
BEGIN
 SELECT * INTO g FROM public.training_groups x WHERE x.key=p_group_key;
 IF NOT FOUND THEN RAISE EXCEPTION 'Unbekannte Trainingsgruppe' USING ERRCODE='22023'; END IF;
 SELECT * INTO pl FROM public.training_plans x WHERE x.group_id=g.id AND x.week_start=league_private.week_monday(p_week_start);
 RETURN pg_catalog.jsonb_build_object('group',league_private.group_json(g),'week_start',league_private.week_monday(p_week_start),
  'plan',CASE WHEN pl.id IS NULL THEN NULL ELSE pg_catalog.jsonb_build_object('focus',pl.focus,'items',pl.items,'published_at',pl.published_at,
   'updated_at',pl.updated_at,'updated_by',(SELECT p.display_name FROM public.profiles p WHERE p.id=pl.updated_by)) END);
END;
$fn$;

CREATE OR REPLACE FUNCTION public.get_my_week_plan(p_week_start date DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); g public.training_groups; pl public.training_plans; ws date; today date := league_private.zurich_today();
BEGIN
 IF me.id IS NULL THEN RAISE EXCEPTION 'Bitte anmelden' USING ERRCODE='42501'; END IF;
 IF NOT league_private.flag_on('gym_training') AND me.role<>'admin' THEN RETURN pg_catalog.jsonb_build_object('enabled',false); END IF;
 ws := league_private.week_monday(coalesce(p_week_start,today));
 g := league_private.group_of(me.id);
 IF g.id IS NOT NULL THEN
  SELECT * INTO pl FROM public.training_plans x WHERE x.group_id=g.id AND x.week_start=ws AND x.published_at IS NOT NULL;
 END IF;
 RETURN pg_catalog.jsonb_build_object('enabled',true,'today',today,'week_start',ws,'group',league_private.group_json(g),
  'trainings',league_private.approved_count(me.id,ws,ws+6),
  'plan',CASE WHEN pl.id IS NULL THEN NULL ELSE pg_catalog.jsonb_build_object('focus',pl.focus,'published_at',pl.published_at,
   'updated_by',(SELECT p.display_name FROM public.profiles p WHERE p.id=pl.updated_by),
   'items',coalesce((SELECT pg_catalog.jsonb_agg(it || pg_catalog.jsonb_build_object(
      'date',ws+(it->>'day')::integer,
      'training_type',(SELECT t.name FROM public.training_types t WHERE t.id=(it->>'type_id')::bigint),
      'status',CASE
        WHEN EXISTS (SELECT 1 FROM public.training_submissions s WHERE s.boxer_id=me.id AND s.status='approved'
                     AND s.training_type_id=(it->>'type_id')::bigint AND s.training_date=ws+(it->>'day')::integer) THEN 'done'
        WHEN EXISTS (SELECT 1 FROM public.training_submissions s WHERE s.boxer_id=me.id AND s.status='pending'
                     AND s.training_type_id=(it->>'type_id')::bigint AND s.training_date=ws+(it->>'day')::integer) THEN 'pending'
        WHEN ws+(it->>'day')::integer < today THEN 'missed'
        WHEN ws+(it->>'day')::integer = today THEN 'today'
        ELSE 'open' END) ORDER BY (it->>'day')::integer, ord)
     FROM pg_catalog.jsonb_array_elements(pl.items) WITH ORDINALITY e(it,ord)),'[]'::jsonb)) END);
END;
$fn$;

CREATE OR REPLACE FUNCTION league_private.plan_pct(p_profile uuid, p_week date)
RETURNS integer LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE g public.training_groups := league_private.group_of(p_profile); pl public.training_plans; total integer; done integer;
BEGIN
 IF g.id IS NULL THEN RETURN NULL; END IF;
 SELECT * INTO pl FROM public.training_plans x WHERE x.group_id=g.id AND x.week_start=league_private.week_monday(p_week) AND x.published_at IS NOT NULL;
 IF pl.id IS NULL THEN RETURN NULL; END IF;
 total := pg_catalog.jsonb_array_length(pl.items);
 IF total=0 THEN RETURN NULL; END IF;
 SELECT count(*) INTO done FROM pg_catalog.jsonb_array_elements(pl.items) it
 WHERE EXISTS (SELECT 1 FROM public.training_submissions s WHERE s.boxer_id=p_profile AND s.status='approved'
   AND s.training_type_id=(it->>'type_id')::bigint AND s.training_date=pl.week_start+(it->>'day')::integer);
 RETURN floor(done*100.0/total)::integer;
END;
$fn$;

CREATE OR REPLACE FUNCTION league_private.quest_progress(p_profile uuid, p_metric text, p_from date, p_to date)
RETURNS numeric LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE v numeric;
BEGIN
 IF p_metric='duels' THEN
  SELECT count(*) INTO v FROM public.league_duels d
  WHERE p_profile IN (d.challenger_id, d.opponent_id) AND d.status IN ('active','awaiting_reviews','settled')
    AND d.accepted_at IS NOT NULL AND (d.accepted_at AT TIME ZONE 'Europe/Zurich')::date BETWEEN p_from AND p_to;
  RETURN v;
 ELSIF p_metric='plan_pct' THEN
  RETURN league_private.plan_pct(p_profile, p_from);
 END IF;
 SELECT CASE p_metric
   WHEN 'sessions' THEN count(*)
   WHEN 'box_sessions' THEN count(*) FILTER (WHERE t.category IN ('Boxen','Wettkampf'))
   WHEN 'technique_minutes' THEN coalesce(sum(coalesce(s.technique_minutes,s.duration_minutes,0)) FILTER (WHERE t.name='Techniktraining'),0)
   WHEN 'recovery_sessions' THEN count(*) FILTER (WHERE t.name='Mobilität / Regeneration')
   WHEN 'recovery_minutes' THEN coalesce(sum(coalesce(s.duration_minutes,0)) FILTER (WHERE t.name='Mobilität / Regeneration'),0)
   WHEN 'home_minutes' THEN coalesce(sum(coalesce(s.duration_minutes,0)) FILTER (WHERE t.name IN ('Schattenboxen / Heimtraining','Seilspringen / Konditionszirkel')),0)
   WHEN 'jogging_km' THEN coalesce(sum(coalesce(s.jogging_km,0)) FILTER (WHERE t.name='Joggen'),0)
   ELSE 0 END
 INTO v
 FROM public.training_submissions s JOIN public.training_types t ON t.id=s.training_type_id
 WHERE s.boxer_id=p_profile AND s.status='approved' AND s.training_date BETWEEN p_from AND p_to;
 RETURN coalesce(v,0);
END;
$fn$;

CREATE OR REPLACE FUNCTION league_private.quest_state(p_profile uuid, d public.quest_definitions, p_from date, p_to date)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE tgt integer := league_private.quest_target(d, p_profile); prog numeric; avail boolean := true; c public.quest_claims;
BEGIN
 prog := league_private.quest_progress(p_profile, d.metric, p_from, p_to);
 IF d.metric='plan_pct' AND prog IS NULL THEN avail := false; prog := 0; END IF;
 IF d.metric='duels' AND NOT league_private.flag_on('duels') THEN avail := false; END IF;
 SELECT * INTO c FROM public.quest_claims x WHERE x.profile_id=p_profile AND x.quest_key=d.key AND x.period_start=p_from;
 RETURN pg_catalog.jsonb_build_object('key',d.key,'kind',d.kind,'metric',d.metric,'title',league_private.quest_title(d,tgt),
  'description',d.description,'target',tgt,'progress',prog,'exp',coalesce(c.exp,d.exp),'coins',coalesce(c.coins,d.coins),
  'available',avail OR c.id IS NOT NULL,'done',c.id IS NOT NULL OR (avail AND prog>=tgt),'claimed',c.id IS NOT NULL,'claimed_at',c.claimed_at,
  'period_start',p_from);
END;
$fn$;

CREATE OR REPLACE FUNCTION league_private.kg_sync(p uuid)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE st public.kg_settings;
BEGIN
 IF p IS NULL THEN RETURN; END IF;
 SELECT * INTO st FROM public.kg_settings WHERE id=1;
 PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('kg_wallet:'||p::text));
 IF st.start_coins>0 THEN
  INSERT INTO public.kg_ledger(profile_id,amount,reason,ref,note) VALUES (p,st.start_coins,'start','start','Startguthaben')
  ON CONFLICT (profile_id,reason,ref) DO NOTHING;
 END IF;
 IF st.coins_per_training>0 THEN
  INSERT INTO public.kg_ledger(profile_id,amount,reason,ref,note)
  SELECT s.boxer_id, st.coins_per_training, 'training', s.id::text, 'Bestätigtes Training vom '||pg_catalog.to_char(s.training_date,'DD.MM.YYYY')
  FROM public.training_submissions s WHERE s.boxer_id=p AND s.status='approved'
  ON CONFLICT (profile_id,reason,ref) DO NOTHING;
 END IF;
 -- Training nicht mehr bestätigt (oder wieder bestätigt): Differenz als Korrektur buchen.
 INSERT INTO public.kg_ledger(profile_id,amount,reason,ref,note)
 SELECT p, x.want-x.have, 'training_fix', x.base||':'||(x.fixes+1)::text,
        CASE WHEN x.want>x.have THEN 'Training wieder bestätigt' ELSE 'Training nicht mehr bestätigt' END
 FROM (SELECT g.base, g.have, g.fixes,
         CASE WHEN EXISTS (SELECT 1 FROM public.training_submissions s WHERE s.id::text=g.base AND s.boxer_id=p AND s.status='approved')
              THEN g.credit ELSE 0 END AS want
       FROM (SELECT b.base, sum(b.amount)::integer AS have, count(*) FILTER (WHERE b.reason='training_fix')::integer AS fixes,
               coalesce(max(b.amount) FILTER (WHERE b.reason='training'),0)::integer AS credit
             FROM (SELECT pg_catalog.split_part(l.ref,':',1) AS base, l.amount, l.reason
                   FROM public.kg_ledger l WHERE l.profile_id=p AND l.reason IN ('training','training_fix')) b
             GROUP BY b.base) g) x
 WHERE x.want<>x.have
 ON CONFLICT (profile_id,reason,ref) DO NOTHING;
 -- Abgeholte Quest-Coins (Etappe 3)
 WITH c AS (
  UPDATE public.quest_claims q SET coins_credited_at=now()
  WHERE q.profile_id=p AND q.coins_credited_at IS NULL AND q.coins>0
  RETURNING q.id, q.coins, q.quest_key, q.period_start)
 INSERT INTO public.kg_ledger(profile_id,amount,reason,ref,note)
 SELECT p, c.coins, 'quest', c.id::text, 'Quest '||c.quest_key||' ('||pg_catalog.to_char(c.period_start,'DD.MM.')||')' FROM c
 ON CONFLICT (profile_id,reason,ref) DO NOTHING;
END;
$fn$;

CREATE OR REPLACE FUNCTION league_private.kg_pass_points(p uuid, p_month date)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE s public.kg_pass_settings; m0 date := league_private.kg_month(p_month); m1 date; tr integer; qw integer; qd integer; qc integer; dp integer; dw integer;
 pt integer; pq integer; pd integer; total integer;
BEGIN
 m1 := (m0 + interval '1 month')::date;
 SELECT * INTO s FROM public.kg_pass_settings WHERE id=1;
 SELECT count(*) INTO tr FROM public.training_submissions t
  WHERE t.boxer_id=p AND t.status='approved' AND t.training_date>=m0 AND t.training_date<m1;
 SELECT count(*) FILTER (WHERE d.kind='weekly'), count(*) FILTER (WHERE d.kind='daily'), count(*) FILTER (WHERE d.kind='chest')
 INTO qw, qd, qc
 FROM public.quest_claims c JOIN public.quest_definitions d ON d.key=c.quest_key
 WHERE c.profile_id=p AND (c.claimed_at AT TIME ZONE 'Europe/Zurich')::date>=m0 AND (c.claimed_at AT TIME ZONE 'Europe/Zurich')::date<m1;
 SELECT count(*) INTO dp FROM public.league_duels d
  WHERE p IN (d.challenger_id,d.opponent_id) AND d.status IN ('active','awaiting_reviews','settled') AND d.accepted_at IS NOT NULL
    AND (d.accepted_at AT TIME ZONE 'Europe/Zurich')::date>=m0 AND (d.accepted_at AT TIME ZONE 'Europe/Zurich')::date<m1;
 SELECT count(*) INTO dw FROM public.league_duels d
  WHERE d.status='settled' AND d.winner_id=p AND d.settled_at IS NOT NULL
    AND (d.settled_at AT TIME ZONE 'Europe/Zurich')::date>=m0 AND (d.settled_at AT TIME ZONE 'Europe/Zurich')::date<m1;
 pt := tr*s.kp_training; pq := qw*s.kp_quest_weekly + qd*s.kp_quest_daily + qc*s.kp_quest_chest; pd := dp*s.kp_duel_played + dw*s.kp_duel_won;
 total := pt+pq+pd;
 RETURN pg_catalog.jsonb_build_object('month',m0,'trainings',tr,'quests_weekly',qw,'quests_daily',qd,'quests_chest',qc,'duels_played',dp,'duels_won',dw,
  'points_trainings',pt,'points_quests',pq,'points_duels',pd,'total',total,'per_tier',s.kp_per_tier,'tier',LEAST(30,total/s.kp_per_tier));
END;
$fn$;

CREATE OR REPLACE FUNCTION public.admin_edit_training(p_submission_id uuid, p_boxer_id uuid, p_training_type_id bigint, p_training_date date, p_notes text, p_status text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $function$
DECLARE
 v_admin public.profiles%rowtype;
 v_old public.training_submissions%rowtype;
 v_new public.training_submissions%rowtype;
 v_old_tx jsonb;
 v_new_tx jsonb;
 v_points integer;
 v_tx_id uuid;
BEGIN
 SELECT * INTO v_admin FROM public.profiles
 WHERE auth_user_id=(SELECT auth.uid()) AND role IN ('admin','coach') AND is_active=true;
 IF NOT FOUND THEN RAISE EXCEPTION 'Nur aktive Trainer dürfen Trainings bearbeiten'; END IF;
 IF p_status NOT IN ('pending','approved','rejected') OR p_status IS NULL THEN
  RAISE EXCEPTION 'Ungültiger Status';
 END IF;
 IF p_boxer_id IS NULL OR p_training_type_id IS NULL OR p_training_date IS NULL THEN
  RAISE EXCEPTION 'Boxer, Trainingsart und Datum sind erforderlich';
 END IF;
 PERFORM 1 FROM public.profiles WHERE id=p_boxer_id AND role IN ('boxer','coach');
 IF NOT FOUND THEN RAISE EXCEPTION 'Boxer nicht gefunden'; END IF;
 SELECT points INTO v_points FROM public.training_types
 WHERE id=p_training_type_id AND is_active=true;
 IF NOT FOUND OR v_points IS NULL OR v_points<0 THEN
  RAISE EXCEPTION 'Trainingsart ungültig oder inaktiv';
 END IF;

 SELECT * INTO v_old FROM public.training_submissions
 WHERE id=p_submission_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Training nicht gefunden'; END IF;

 SELECT id INTO v_tx_id FROM public.point_transactions
 WHERE submission_id=p_submission_id ORDER BY created_at LIMIT 1 FOR UPDATE;
 SELECT to_jsonb(t) INTO v_old_tx FROM public.point_transactions t WHERE id=v_tx_id;
 IF (SELECT count(*) FROM public.point_transactions WHERE submission_id=p_submission_id)>1 THEN
  RAISE EXCEPTION 'Mehrere Punktebuchungen vorhanden: manuelle Prüfung erforderlich';
 END IF;

 UPDATE public.training_submissions SET
 boxer_id=p_boxer_id, training_type_id=p_training_type_id,
 training_date=p_training_date, notes=p_notes,
 status=p_status,
 reviewed_by=CASE WHEN p_status='pending' THEN null ELSE v_admin.id END,
 reviewed_at=CASE WHEN p_status='pending' THEN null ELSE now() END
 WHERE id=p_submission_id RETURNING * INTO v_new;

 IF v_tx_id IS NOT NULL THEN
  UPDATE public.point_transactions SET
   boxer_id=p_boxer_id,
   points=CASE WHEN p_status='approved' THEN v_points ELSE 0 END,
   exp=CASE WHEN p_status='approved' THEN v_points ELSE 0 END,
   effective_date=p_training_date,
   created_by=v_admin.id,
   description=CASE WHEN p_status='approved' THEN 'Training (admin-korrigiert)' ELSE 'Training (widerrufen)' END
  WHERE id=v_tx_id;
 ELSIF p_status='approved' THEN
  INSERT INTO public.point_transactions
  (boxer_id,submission_id,points,exp,category,description,effective_date,created_by)
  VALUES (p_boxer_id,p_submission_id,v_points,v_points,'training',
          'Training (admin-korrigiert)',p_training_date,v_admin.id)
  RETURNING id INTO v_tx_id;
 END IF;
 SELECT to_jsonb(t) INTO v_new_tx FROM public.point_transactions t WHERE id=v_tx_id;
 INSERT INTO public.training_audit
 (submission_id,changed_by,old_submission,new_submission,old_transaction,new_transaction)
 VALUES (p_submission_id,v_admin.id,to_jsonb(v_old),to_jsonb(v_new),v_old_tx,v_new_tx);

 -- Recalculate both sides of a transfer, and the affected dates/streaks.
 IF v_admin.role='coach' THEN
  PERFORM league_private.coach_training_bonus_refresh(v_old.boxer_id);
 ELSE
  PERFORM public.recalculate_boxer_bonuses(v_old.boxer_id);
 END IF;
 IF v_old.boxer_id IS DISTINCT FROM p_boxer_id THEN
  IF v_admin.role='coach' THEN
   PERFORM league_private.coach_training_bonus_refresh(p_boxer_id);
  ELSE
   PERFORM public.recalculate_boxer_bonuses(p_boxer_id);
  END IF;
 END IF;

 RETURN jsonb_build_object('status',p_status,
  'points',CASE WHEN p_status='approved' THEN v_points ELSE 0 END);
END;
$function$;

DROP FUNCTION IF EXISTS league_private.activate_club_tiers(uuid);
DROP FUNCTION IF EXISTS league_private.deactivate_club_tiers(uuid);
DROP FUNCTION IF EXISTS league_private.training_insert_guard();
DROP FUNCTION IF EXISTS league_private.apply_training_value(uuid,uuid,text,jsonb);
DROP FUNCTION IF EXISTS league_private.kg_training_coins(uuid,integer);
DROP FUNCTION IF EXISTS league_private.pflicht_info(uuid);
DROP FUNCTION IF EXISTS league_private.pflicht_days(uuid,date,date);
DROP FUNCTION IF EXISTS league_private.plan_item_done(uuid,date,bigint,boolean);
DROP FUNCTION IF EXISTS league_private.auto_plan_items();
DROP FUNCTION IF EXISTS league_private.slot_json(public.club_schedule);
DROP FUNCTION IF EXISTS league_private.club_slot_for(date,bigint);
DROP FUNCTION IF EXISTS league_private.training_value(uuid);
DROP FUNCTION IF EXISTS league_private.tier_label(text);
NOTIFY pgrst, 'reload schema';
COMMIT;
