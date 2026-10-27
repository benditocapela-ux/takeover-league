-- Gamification step 1 (owner decisions 27.10.2026):
--  * New public snapshots only contain public boxers (active, listed, not archived).
--    Season results, hall of fame, records and badges skip non-public boxers; challenge
--    results and duel history keep the row (payout/scoring) but show "Privates Profil".
--    Existing rows are not changed.
--  * Hall of fame only for boxers with more than 0 season points.
--  * Editing live league challenges no longer depends on the legacy 'league_challenges' flag.
--  * Notifications: level-up, achievement, league-challenge result, season result; umlauts fixed.
--  * get_boxer_exp_level_rank returns the same level/rank as every page (quadratic v2 curve).
-- No profile, training, point, EXP or feature-flag row is changed or deleted.
-- Production use requires the normal migration path and a separate explicit FREIGEBEN.
BEGIN;

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION league_v21_private.public_display_name(p_profile uuid)
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $fn$
 SELECT COALESCE((
  SELECT p.display_name::text FROM public.profiles p
  WHERE p.id=p_profile AND p.role IN ('boxer','coach')
    AND p.is_active IS TRUE AND p.is_listed IS TRUE AND p.archived_at IS NULL
 ),'Privates Profil')
$fn$;

CREATE OR REPLACE FUNCTION league_v21_private.notifications_enabled()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $fn$
 SELECT EXISTS(SELECT 1 FROM public.league_feature_flags f
               WHERE f.feature_key='notifications' AND f.is_enabled IS TRUE)
$fn$;

-- Level names shared by index.html, guest.html, boxer.html and boxer-profile.js.
CREATE OR REPLACE FUNCTION league_v21_private.rank_for_level(p_level bigint)
RETURNS text
LANGUAGE sql
IMMUTABLE
SET search_path = ''
AS $fn$
 SELECT (ARRAY['F · Rookie','E · Prospect','D · Contender','C · Challenger',
               'B · Elite Fighter','A · Champion','S · Legend'])
        [LEAST(GREATEST(((COALESCE(p_level,1)-1)/10)::integer,0),6)+1]
$fn$;

REVOKE ALL ON FUNCTION league_v21_private.public_display_name(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION league_v21_private.notifications_enabled() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION league_v21_private.rank_for_level(bigint) FROM PUBLIC, anon, authenticated;

-- New notification type for level-ups (all existing types kept).
ALTER TABLE public.boxer_notifications DROP CONSTRAINT IF EXISTS boxer_notifications_notification_type_check;
ALTER TABLE public.boxer_notifications ADD CONSTRAINT boxer_notifications_notification_type_check
 CHECK (notification_type = ANY (ARRAY['training_approved','training_rejected','coach_feedback','coach_goal',
  'league_challenge','boxer_duel','achievement','season','general','level_up']::text[]));

-- ---------------------------------------------------------------------------
-- Seasons: only public boxers in the snapshot, hall of fame only with points > 0
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION league_v21_private.season_transition_core(p_season uuid, p_action text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
declare actor public.profiles%rowtype;season public.league_seasons_v21%rowtype;n integer;
begin
 select * into actor from public.profiles p where p.auth_user_id=(select auth.uid()) and p.is_active and p.role='admin';
 if not found then raise exception 'Only active admin' using errcode='42501';end if;
 select * into season from public.league_seasons_v21 s where s.id=p_season for update;
 if not found then raise exception 'Season not found' using errcode='22023';end if;
 if p_action='activate' then
  if season.status<>'draft' then raise exception 'Only draft seasons may be activated' using errcode='22023';end if;
  update public.league_seasons_v21 set status='active' where id=season.id;
  return pg_catalog.jsonb_build_object('status','active');
 elsif p_action='close' then
  if season.status='closed' then
   return pg_catalog.jsonb_build_object('status','closed','unchanged',true);
  end if;
  if season.status<>'active' or season.ends_on>=current_date then
   raise exception 'Only elapsed active seasons may close' using errcode='22023';end if;
  -- An unreviewed timely training might still change points and ranks.
  -- Block finalization until all season trainings are reviewed.
  PERFORM 1 FROM public.training_submissions t
   JOIN public.profiles p ON p.id=t.boxer_id AND p.role='boxer'
   WHERE t.training_date BETWEEN season.starts_on AND season.ends_on
   ORDER BY t.id FOR UPDATE OF t;
  if exists(select 1 from public.training_submissions t
    where t.status='pending' and t.training_date between season.starts_on and season.ends_on
    and exists(select 1 from public.profiles p where p.id=t.boxer_id and p.role='boxer'))
  then raise exception 'Pending season trainings require coach review' using errcode='23514';end if;
  if exists(select 1 from public.league_season_results_v21 r where r.season_id=season.id)
  then raise exception 'Unexpected existing season snapshot' using errcode='23505';end if;
  -- Public snapshot: only boxers that are public right now (same rule as the leaderboard).
  insert into public.league_season_results_v21(season_id,boxer_id,boxer_name,rank_position,points,exp)
  select season.id,p.id,p.display_name,
         rank() over(order by greatest(coalesce(sum(t.points),0),0) desc,
                               greatest(coalesce(sum(t.exp),0),0) desc)::integer,
         greatest(coalesce(sum(t.points),0),0)::integer,
         greatest(coalesce(sum(t.exp),0),0)::integer
  from public.profiles p
  left join public.point_transactions t on t.boxer_id=p.id
    and t.effective_date between season.starts_on and season.ends_on
  where p.role='boxer' and p.is_active is true and p.is_listed is true and p.archived_at is null
  group by p.id,p.display_name;
  get diagnostics n=row_count;
  -- Titles only for real season performance (no title for 0 points, even on a tie).
  insert into public.league_hall_of_fame_v21(boxer_id,boxer_name,season_id,title,description)
  select r.boxer_id,r.boxer_name,season.id,
   case r.rank_position when 1 then 'Saisonmeister' when 2 then 'Vizechampion' else 'Saisonpodium' end,
   season.title||' · Platz '||r.rank_position
  from public.league_season_results_v21 r
  where r.season_id=season.id and r.rank_position<=3 and r.points>0
  on conflict(boxer_id,season_id,title) do nothing;
  update public.league_seasons_v21 set status='closed' where id=season.id;
  if league_v21_private.notifications_enabled() then
   insert into public.boxer_notifications(recipient_id,notification_type,title,message,target_path)
   select r.boxer_id,'season',
    pg_catalog.left('Saison «'||season.title||'» beendet: Platz '||r.rank_position,160),
    case when r.rank_position=1 and r.points>0 then 'Gratulation, du bist Saisonmeister! '
         when r.rank_position<=3 and r.points>0 then 'Gratulation, du stehst auf dem Saisonpodium! '
         else '' end||r.points||' Punkte in dieser Saison.',
    '/league-history.html'
   from public.league_season_results_v21 r where r.season_id=season.id;
  end if;
  return pg_catalog.jsonb_build_object('status','closed','ranked_boxers',n);
 end if;
 raise exception 'Invalid season action' using errcode='22023';
end$function$;

-- ---------------------------------------------------------------------------
-- League challenges: results keep every participant (payout), names only when public
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION league_v21_private.global_close_core(p_challenge uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
declare actor public.profiles%rowtype; c public.league_global_challenges_v21%rowtype; tally integer; participant record; reward integer; txn uuid;
begin
 select * into actor from public.profiles p where p.auth_user_id=(select auth.uid()) and p.is_active and p.role='admin';
 if not found then raise exception 'Admin only' using errcode='42501';end if;
 select * into c from public.league_global_challenges_v21 x where x.id=p_challenge for update;
 if not found then raise exception 'Challenge not found' using errcode='22023';end if;
 if c.status='closed' then
  return pg_catalog.jsonb_build_object('status','closed','unchanged',true);
 end if;
 if c.status<>'active' or c.ends_at>now() then
  raise exception 'Only elapsed active challenge may close' using errcode='22023';end if;
 -- Hold settlement until all timely entries are reviewed.
 PERFORM 1 FROM public.training_submissions s
  JOIN public.league_global_entries_v21 e ON e.boxer_id=s.boxer_id AND e.challenge_id=c.id
  WHERE s.created_at BETWEEN e.joined_at AND c.ends_at
    AND s.training_date BETWEEN (c.starts_at AT TIME ZONE 'Europe/Zurich')::date
                            AND (c.ends_at AT TIME ZONE 'Europe/Zurich')::date
  ORDER BY s.id FOR UPDATE OF s;
  if exists(select 1 from public.training_submissions s
   join public.league_global_entries_v21 e on e.boxer_id=s.boxer_id and e.challenge_id=c.id
   where s.status='pending' and s.created_at between e.joined_at and c.ends_at
     and s.training_date between (c.starts_at at time zone 'Europe/Zurich')::date
                            and (c.ends_at at time zone 'Europe/Zurich')::date)
 then raise exception 'Pending trainings must be reviewed before settlement' using errcode='23514';end if;
 if exists(select 1 from public.league_global_results_v21 x where x.challenge_id=p_challenge)
 then raise exception 'Existing results require review' using errcode='23505';end if;
 with scores as (
  select e.boxer_id,league_v21_private.public_display_name(e.boxer_id) as boxer_name,
   case c.metric
    when 'training_sessions' then count(t.id)::numeric
    when 'jogging_km' then coalesce(sum(t.jogging_km),0)
    when 'technique_minutes' then coalesce(sum(t.technique_minutes),0)
    else 0 end as progress
  from public.league_global_entries_v21 e
  join public.profiles p on p.id=e.boxer_id
  left join public.training_submissions t on t.boxer_id=e.boxer_id
    and t.status='approved' and t.created_at>=e.joined_at
    and t.created_at<=c.ends_at
    and t.training_date between (c.starts_at at time zone 'Europe/Zurich')::date
                            and (c.ends_at at time zone 'Europe/Zurich')::date
  where e.challenge_id=c.id
  group by e.boxer_id
 ),ordered as (
  select boxer_id,boxer_name,progress,
   rank() over(order by progress desc)::integer as rank_position
  from scores
 )
 insert into public.league_global_results_v21(challenge_id,boxer_id,boxer_name,progress,rank_position,completed)
 select c.id,boxer_id,boxer_name,progress,rank_position,progress>=c.target_value from ordered;
 get diagnostics tally=row_count;
 for participant in select r.boxer_id,r.completed,r.rank_position,r.progress from public.league_global_results_v21 r
   where r.challenge_id=c.id order by r.boxer_id loop
  reward:=case when participant.completed
    then c.completion_exp+case when participant.rank_position=1 then c.winner_exp else 0 end
    else 0 end;
  if reward>0 then
   if exists(select 1 from public.point_transactions t where t.boxer_id=participant.boxer_id
     and t.category='challenge_exp' and t.description='Global challenge reward: '||c.id::text)
   then raise exception 'Orphaned global payout must be reviewed' using errcode='23514';end if;
   insert into public.point_transactions(boxer_id,submission_id,points,exp,category,description,effective_date,created_by)
   values(participant.boxer_id,null,0,reward,'challenge_exp',
    'Global challenge reward: '||c.id::text,(c.ends_at at time zone 'Europe/Zurich')::date,actor.id)
   returning id into txn;
   insert into public.league_global_exp_ledger_v21(challenge_id,boxer_id,transaction_id,exp_amount)
   values(c.id,participant.boxer_id,txn,reward);
  end if;
  if league_v21_private.notifications_enabled() then
   insert into public.boxer_notifications(recipient_id,notification_type,title,message,target_path)
   values(participant.boxer_id,'league_challenge',
    pg_catalog.left('Liga-Challenge «'||c.title||'» abgeschlossen: Platz '||participant.rank_position,160),
    case when participant.completed then 'Ziel erreicht' else 'Ziel nicht erreicht' end
     ||' · Fortschritt '||trim(to_char(participant.progress,'FM999999990.##'))
     ||case when reward>0 then ' · +'||reward||' EXP' else '' end,
    '/league-challenges.html');
  end if;
 end loop;
 update public.league_global_challenges_v21 set status='closed' where id=c.id;
 return pg_catalog.jsonb_build_object('status','closed','participants',tally,'rewards_paid',c.completion_exp>0 or c.winner_exp>0);
end$function$;

-- Editing live league challenges: same admin and fairness guards, without the legacy 2.0 flag.
CREATE OR REPLACE FUNCTION league_v21_private.global_edit_core(p_challenge uuid, p_title text, p_description text, p_metric text, p_target numeric, p_starts timestamp with time zone, p_ends timestamp with time zone, p_update_rules boolean)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
 actor public.profiles%ROWTYPE;
 c public.league_global_challenges_v21%ROWTYPE;
 change_rules boolean := COALESCE(p_update_rules,false);
BEGIN
 SELECT * INTO actor
 FROM public.profiles p
 WHERE p.auth_user_id=(SELECT auth.uid()) AND p.is_active IS TRUE AND p.role='admin';
 IF NOT FOUND THEN RAISE EXCEPTION 'Nur aktive Admins dürfen Liga-Challenges bearbeiten' USING ERRCODE='42501'; END IF;

 SELECT * INTO c FROM public.league_global_challenges_v21 x WHERE x.id=p_challenge FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Liga-Challenge nicht gefunden' USING ERRCODE='P0002'; END IF;
 IF c.status<>'active' THEN RAISE EXCEPTION 'Nur aktive Liga-Challenges können bearbeitet werden' USING ERRCODE='22023'; END IF;

 IF p_title IS NULL OR pg_catalog.length(pg_catalog.btrim(p_title)) NOT BETWEEN 3 AND 120
    OR pg_catalog.length(COALESCE(p_description,''))>1000
 THEN RAISE EXCEPTION 'Ungültiger Titel oder Beschreibung' USING ERRCODE='22023'; END IF;

 IF change_rules THEN
  IF c.starts_at<=pg_catalog.now() THEN
   RAISE EXCEPTION 'Messwert, Ziel und Zeitraum sind nach Beginn gesperrt' USING ERRCODE='22023';
  END IF;
  IF EXISTS(SELECT 1 FROM public.league_global_entries_v21 e WHERE e.challenge_id=c.id) THEN
   RAISE EXCEPTION 'Messwert, Ziel und Zeitraum sind gesperrt, sobald Boxer beigetreten sind' USING ERRCODE='22023';
  END IF;
  IF p_metric IS NULL OR p_metric NOT IN ('training_sessions','jogging_km','technique_minutes')
     OR p_target IS NULL OR p_target<=0 OR p_target>1000000
     OR p_starts IS NULL OR p_ends IS NULL
     OR p_starts<=pg_catalog.now() OR p_ends<=pg_catalog.now()
     OR p_ends<=p_starts OR p_ends>p_starts+interval '90 days'
  THEN RAISE EXCEPTION 'Ungültiger Messwert, Ziel oder Zeitraum (maximal 90 Tage)' USING ERRCODE='22023'; END IF;

  UPDATE public.league_global_challenges_v21
  SET title=pg_catalog.btrim(p_title),description=COALESCE(pg_catalog.btrim(p_description),''),
      metric=p_metric,target_value=p_target,starts_at=p_starts,ends_at=p_ends
  WHERE id=c.id;
 ELSE
  UPDATE public.league_global_challenges_v21
  SET title=pg_catalog.btrim(p_title),description=COALESCE(pg_catalog.btrim(p_description),'')
  WHERE id=c.id;
 END IF;

 RETURN pg_catalog.jsonb_build_object('id',c.id,'status',c.status,'rules_updated',change_rules);
END
$function$;

-- ---------------------------------------------------------------------------
-- Records: only public boxers are written
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION league_v21_private.refresh_public_records_core(p_limit integer DEFAULT 25, p_after uuid DEFAULT NULL::uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
declare actor public.profiles%rowtype;v_processed integer;v_last uuid;
begin
 select * into actor from public.profiles p where p.auth_user_id=(select auth.uid()) and p.is_active and p.role='admin';
 if not found then raise exception 'Only active admin' using errcode='42501';end if;
 if p_limit is null or p_limit not between 1 and 25 then raise exception 'Limit must be 1-25' using errcode='22023';end if;
 with selected as (
  select p.id,p.display_name from public.profiles p
  where p.role='boxer' and p.is_active and p.is_listed and p.archived_at is null
    and (p_after is null or p.id>p_after)
  order by p.id limit p_limit
 ),stats as (
  select p.id as boxer_id,p.display_name as boxer_name,
   count(s.id)::integer approved_sessions,
   count(distinct s.training_date)::integer active_days,
   coalesce(max(s.jogging_km),0)::numeric max_jogging_km,
   coalesce(max(s.technique_minutes),0)::integer max_technique_minutes
  from selected p left join public.training_submissions s on s.boxer_id=p.id and s.status='approved'
  group by p.id,p.display_name
 ),stored as (
  insert into public.league_public_records_v21(boxer_id,boxer_name,approved_sessions,active_days,max_jogging_km,max_technique_minutes,refreshed_at)
  select boxer_id,boxer_name,approved_sessions,active_days,max_jogging_km,max_technique_minutes,now() from stats
  on conflict(boxer_id) do update
   set boxer_name=excluded.boxer_name,approved_sessions=excluded.approved_sessions,
       active_days=excluded.active_days,max_jogging_km=excluded.max_jogging_km,
       max_technique_minutes=excluded.max_technique_minutes,refreshed_at=excluded.refreshed_at
  returning boxer_id
 )
 select count(*)::integer,(array_agg(boxer_id order by boxer_id desc))[1] into v_processed,v_last from stored;
 return pg_catalog.jsonb_build_object('processed',v_processed,'last_boxer_id',coalesce(v_last,p_after),
   'has_more',exists(select 1 from public.profiles p where p.role='boxer' and p.is_active and p.is_listed and p.archived_at is null
     and (coalesce(v_last,p_after) is null or p.id>coalesce(v_last,p_after))));
end$function$;

-- ---------------------------------------------------------------------------
-- Badges: only public boxers; earned badges appear once a boxer becomes public
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION league_v21_private.sync_public_badges_core()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
declare boxer uuid;
begin
 boxer:=case when TG_OP='DELETE' then OLD.boxer_id else NEW.boxer_id end;
 if TG_OP='DELETE' then
  delete from public.league_public_badges_v21
  where boxer_id=OLD.boxer_id and achievement_id=OLD.achievement_id;
 else
  insert into public.league_public_badges_v21(boxer_id,achievement_id,boxer_name,title,icon_key,earned_at)
  select NEW.boxer_id,NEW.achievement_id,p.display_name,d.title,d.icon_key,NEW.earned_at
  from public.profiles p join public.achievement_definitions d on d.id=NEW.achievement_id
  where p.id=NEW.boxer_id and p.is_active and p.is_listed and p.archived_at is null and p.role='boxer' and d.is_active
  on conflict(boxer_id,achievement_id)
  do update set boxer_name=excluded.boxer_name,title=excluded.title,icon_key=excluded.icon_key,earned_at=excluded.earned_at;
 end if;
 return case when TG_OP='DELETE' then OLD else NEW end;
end$function$;

CREATE OR REPLACE FUNCTION league_v21_private.publish_badges_when_public()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $fn$
begin
 if NEW.role='boxer' and NEW.is_active and NEW.is_listed and NEW.archived_at is null
    and not (OLD.role='boxer' and OLD.is_active and OLD.is_listed and OLD.archived_at is null) then
  insert into public.league_public_badges_v21(boxer_id,achievement_id,boxer_name,title,icon_key,earned_at)
  select a.boxer_id,a.achievement_id,NEW.display_name,d.title,d.icon_key,a.earned_at
  from public.boxer_achievements a join public.achievement_definitions d on d.id=a.achievement_id
  where a.boxer_id=NEW.id and d.is_active
  on conflict(boxer_id,achievement_id) do nothing;
 end if;
 return NEW;
end$fn$;
REVOKE ALL ON FUNCTION league_v21_private.publish_badges_when_public() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS league_v21_publish_badges_when_public ON public.profiles;
CREATE TRIGGER league_v21_publish_badges_when_public
 AFTER UPDATE OF is_active, is_listed, archived_at, role ON public.profiles
 FOR EACH ROW EXECUTE FUNCTION league_v21_private.publish_badges_when_public();

-- ---------------------------------------------------------------------------
-- Duel history: names only for public profiles
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION league_v21_private.sync_public_duel_history()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
begin
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

-- ---------------------------------------------------------------------------
-- Notifications
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public._notify_training_decision()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public', 'pg_temp'
AS $function$
BEGIN
 IF NEW.status NOT IN ('approved','rejected') OR NEW.status IS NOT DISTINCT FROM OLD.status THEN
  RETURN NEW;
 END IF;
 IF NOT EXISTS (SELECT 1 FROM public.league_feature_flags WHERE feature_key='notifications' AND is_enabled=true) THEN
  RETURN NEW;
 END IF;
 IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id=NEW.boxer_id AND role IN ('boxer','coach') AND is_active=true) THEN
  RETURN NEW;
 END IF;
 INSERT INTO public.boxer_notifications(recipient_id,notification_type,title,message,target_path)
 VALUES (
  NEW.boxer_id,
  CASE WHEN NEW.status='approved' THEN 'training_approved' ELSE 'training_rejected' END,
  CASE WHEN NEW.status='approved' THEN 'Training bestätigt' ELSE 'Training abgelehnt' END,
  CASE WHEN NEW.status='approved' THEN 'Dein Training vom '||to_char(NEW.training_date,'DD.MM.YYYY')||' wurde bestätigt.'
       ELSE 'Dein Training vom '||to_char(NEW.training_date,'DD.MM.YYYY')||' wurde abgelehnt.' END,
  '/boxer.html'
 );
 RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public._notify_coach_feedback()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public', 'pg_temp'
AS $function$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM public.league_feature_flags WHERE feature_key='notifications' AND is_enabled=true)
    OR NOT EXISTS (SELECT 1 FROM public.league_feature_flags WHERE feature_key='coach_feedback' AND is_enabled=true) THEN
  RETURN NEW;
 END IF;
 IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id=NEW.boxer_id AND role='boxer' AND is_active=true) THEN
  RETURN NEW;
 END IF;
 INSERT INTO public.boxer_notifications(recipient_id,notification_type,title,message,target_path)
 VALUES (NEW.boxer_id,'coach_feedback','Neues Coach-Feedback',
         'Du hast eine neue Rückmeldung von deinem Coach erhalten.','/boxer.html');
 RETURN NEW;
END;
$function$;

-- Level-up: one notification per reached level; a big jump announces the 5 highest levels.
CREATE OR REPLACE FUNCTION league_v21_private.notify_level_up()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $fn$
declare total bigint; before_total bigint; old_level bigint; new_level bigint; lvl bigint;
begin
 if TG_OP='UPDATE' and NEW.exp<=OLD.exp and NEW.boxer_id=OLD.boxer_id then return NEW; end if;
 if TG_OP='INSERT' and NEW.exp<=0 then return NEW; end if;
 if not league_v21_private.notifications_enabled() then return NEW; end if;
 if not exists(select 1 from public.profiles p where p.id=NEW.boxer_id and p.role in ('boxer','coach') and p.is_active) then
  return NEW;
 end if;
 select greatest(coalesce(sum(t.exp),0),0) into total from public.point_transactions t where t.boxer_id=NEW.boxer_id;
 before_total:=greatest(total-(NEW.exp-case when TG_OP='UPDATE' and NEW.boxer_id=OLD.boxer_id then OLD.exp else 0 end),0);
 old_level:=public.league_level_from_exp_v2(before_total);
 new_level:=public.league_level_from_exp_v2(total);
 if new_level is null or old_level is null or new_level<=old_level then return NEW; end if;
 for lvl in select g from pg_catalog.generate_series(greatest(old_level+1,new_level-4),new_level) g loop
  if not exists(select 1 from public.boxer_notifications n where n.recipient_id=NEW.boxer_id
     and n.notification_type='level_up' and n.title='Level '||lvl||' erreicht') then
   insert into public.boxer_notifications(recipient_id,notification_type,title,message,target_path)
   values(NEW.boxer_id,'level_up','Level '||lvl||' erreicht',
    case when (lvl-1)%10=0 then 'Neuer Rang: '||league_v21_private.rank_for_level(lvl)||'. Stark!'
         else 'Rang '||league_v21_private.rank_for_level(lvl)||' · Weiter so!' end,
    '/boxer.html');
  end if;
 end loop;
 return NEW;
end$fn$;
REVOKE ALL ON FUNCTION league_v21_private.notify_level_up() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS league_v21_notify_level_up ON public.point_transactions;
CREATE TRIGGER league_v21_notify_level_up
 AFTER INSERT OR UPDATE OF exp, boxer_id ON public.point_transactions
 FOR EACH ROW EXECUTE FUNCTION league_v21_private.notify_level_up();

-- Achievement unlocked (re-earning an achievement does not notify twice).
CREATE OR REPLACE FUNCTION league_v21_private.notify_achievement()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $fn$
declare v_title text; v_reward text;
begin
 if not league_v21_private.notifications_enabled() then return NEW; end if;
 if not exists(select 1 from public.profiles p where p.id=NEW.boxer_id and p.role in ('boxer','coach') and p.is_active) then
  return NEW;
 end if;
 select pg_catalog.left('Achievement freigeschaltet: '||d.title,160) into v_title
 from public.achievement_definitions d where d.id=NEW.achievement_id;
 if v_title is null then return NEW; end if;
 if exists(select 1 from public.boxer_notifications n where n.recipient_id=NEW.boxer_id
    and n.notification_type='achievement' and n.title=v_title) then return NEW; end if;
 v_reward:=NEW.metadata->>'reward_exp';
 insert into public.boxer_notifications(recipient_id,notification_type,title,message,target_path)
 values(NEW.boxer_id,'achievement',v_title,
  case when v_reward ~ '^[0-9]+$' then '+'||v_reward||' EXP. ' else '' end||'Sieh dir dein nächstes Ziel in Mein Studio an.',
  '/boxer.html');
 return NEW;
end$fn$;
REVOKE ALL ON FUNCTION league_v21_private.notify_achievement() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS league_v21_notify_achievement ON public.boxer_achievements;
CREATE TRIGGER league_v21_notify_achievement
 AFTER INSERT ON public.boxer_achievements
 FOR EACH ROW EXECUTE FUNCTION league_v21_private.notify_achievement();

-- ---------------------------------------------------------------------------
-- One level curve everywhere: same as league_level_from_exp_v2 and every page
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_boxer_exp_level_rank(p_boxer_id uuid)
RETURNS TABLE(boxer_id uuid, lifetime_exp bigint, lifetime_points bigint, level_number integer, level_start_exp bigint, next_level_exp bigint, exp_into_level bigint, exp_to_next_level bigint, rank_letter text)
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path = ''
AS $function$
WITH allowed AS (
 SELECT p.id FROM public.profiles p
 WHERE p.id=p_boxer_id AND p.role IN ('boxer','coach') AND p.is_active
  AND EXISTS (SELECT 1 FROM public.league_feature_flags f
              WHERE f.feature_key='performance_dashboard' AND f.is_enabled)
  AND EXISTS (SELECT 1 FROM public.profiles viewer
              WHERE viewer.auth_user_id=(SELECT auth.uid()) AND viewer.is_active
                AND (viewer.id=p.id OR viewer.role IN ('admin','coach')))
), totals AS (
 SELECT a.id, GREATEST(0::bigint,COALESCE(SUM(t.exp),0)::bigint) AS exp,
        GREATEST(0::bigint,COALESCE(SUM(t.points),0)::bigint) AS points
 FROM allowed a LEFT JOIN public.point_transactions t ON t.boxer_id=a.id
 GROUP BY a.id
), selected AS (
 SELECT t.id,t.exp,t.points,public.league_level_from_exp_v2(t.exp) AS lvl
 FROM totals t
)
SELECT s.id,s.exp,s.points,s.lvl::integer,
       public.league_level_start_exp_v2(s.lvl)::bigint,
       public.league_level_start_exp_v2(s.lvl+1)::bigint,
       (s.exp-public.league_level_start_exp_v2(s.lvl))::bigint,
       GREATEST(0::bigint,(public.league_level_start_exp_v2(s.lvl+1)-s.exp)::bigint),
       (ARRAY['F','E','D','C','B','A','S'])[LEAST(((s.lvl-1)/10)::integer,6)+1]
FROM selected s;
$function$;
REVOKE ALL ON FUNCTION public.get_boxer_exp_level_rank(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_boxer_exp_level_rank(uuid) TO authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
