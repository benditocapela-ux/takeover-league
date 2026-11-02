-- Read-only own-profile history and complete aggregates. No reward or receipt rules change.
BEGIN;
CREATE SCHEMA IF NOT EXISTS league_studio_private;
REVOKE ALL ON SCHEMA league_studio_private FROM PUBLIC,anon,authenticated;
GRANT USAGE ON SCHEMA league_studio_private TO authenticated;
CREATE INDEX IF NOT EXISTS training_submissions_own_history_cursor_idx
 ON public.training_submissions(boxer_id,created_at DESC,id DESC);
CREATE INDEX IF NOT EXISTS training_submissions_own_status_cursor_idx
 ON public.training_submissions(boxer_id,status,created_at DESC,id DESC);

CREATE OR REPLACE FUNCTION league_studio_private.studio_training_history_core(
 p_status text,p_before timestamptz,p_before_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=''
AS $fn$
DECLARE me uuid; result jsonb;
BEGIN
 SELECT id INTO me FROM public.profiles WHERE auth_user_id=(SELECT auth.uid())
  AND is_active AND archived_at IS NULL AND role IN ('boxer','coach','admin');
 IF me IS NULL THEN RAISE EXCEPTION 'Active own profile required' USING errcode='42501'; END IF;
 IF p_status IS NULL OR p_status NOT IN ('all','approved','pending','rejected')
  OR ((p_before IS NULL)<>(p_before_id IS NULL)) OR (p_before IS NOT NULL AND NOT isfinite(p_before))
 THEN RAISE EXCEPTION 'Invalid history filter or cursor' USING errcode='22023'; END IF;
 WITH candidates AS MATERIALIZED (
  SELECT s.id,s.training_type_id,t.name training_type_name,s.training_date,s.created_at,s.status,
   s.notes,s.jogging_km,s.technique_minutes,s.duration_minutes,s.club_tier,s.training_location,
   s.recorded_by IS NOT NULL recorded_by
  FROM public.training_submissions s JOIN public.training_types t ON t.id=s.training_type_id
  WHERE s.boxer_id=me AND (p_status='all' OR s.status=p_status)
   AND (p_before IS NULL OR (s.created_at,s.id)<(p_before,p_before_id))
  ORDER BY s.created_at DESC,s.id DESC LIMIT 21
 ), page AS MATERIALIZED (
  SELECT * FROM candidates ORDER BY created_at DESC,id DESC LIMIT 20
 ) SELECT jsonb_build_object('profile_id',me,'status',p_status,
  'items',coalesce((SELECT jsonb_agg(to_jsonb(p) ORDER BY p.created_at DESC,p.id DESC) FROM page p),'[]'::jsonb),
  'next_cursor',CASE WHEN (SELECT count(*) FROM candidates)>20 THEN
   (SELECT jsonb_build_object('before',created_at,'before_id',id) FROM page ORDER BY created_at,id LIMIT 1) END)
 INTO result;
 RETURN result;
END $fn$;

CREATE OR REPLACE FUNCTION league_studio_private.studio_training_summary_core()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=''
AS $fn$
DECLARE me uuid; today date:=(statement_timestamp() AT TIME ZONE 'Europe/Zurich')::date;
 week_start date:=date_trunc('week',today::timestamp)::date; result jsonb;
BEGIN
 SELECT id INTO me FROM public.profiles WHERE auth_user_id=(SELECT auth.uid())
  AND is_active AND archived_at IS NULL AND role IN ('boxer','coach','admin');
 IF me IS NULL THEN RAISE EXCEPTION 'Active own profile required' USING errcode='42501'; END IF;
 WITH base AS MATERIALIZED (
  SELECT s.training_date,s.status,s.training_type_id,t.name,
   CASE lower(btrim(t.name)) WHEN 'reguläres boxtraining' THEN 'boxing'
    WHEN 'sparring' THEN 'sparring' WHEN 'wettkampfsparring' THEN 'sparring'
    WHEN 'techniktraining' THEN 'technique' WHEN 'krafttraining' THEN 'strength'
    WHEN 'sprint-intervalle' THEN 'sprint' WHEN 'joggen' THEN 'jogging' ELSE 'other' END kind,
   CASE WHEN s.jogging_km::text IN ('NaN','Infinity','-Infinity') THEN 0 ELSE coalesce(s.jogging_km,0) END km,
   coalesce(s.technique_minutes,0) minutes
  FROM public.training_submissions s JOIN public.training_types t ON t.id=s.training_type_id WHERE s.boxer_id=me
 ), approved AS MATERIALIZED (SELECT * FROM base WHERE status='approved'),
 days AS MATERIALIZED (SELECT training_date day_key,count(*) n FROM approved GROUP BY training_date),
 weeks AS MATERIALIZED (SELECT date_trunc('week',training_date::timestamp)::date week,count(*) n FROM approved GROUP BY 1),
 anchors AS (SELECT CASE WHEN EXISTS(SELECT 1 FROM days WHERE day_key=today) THEN today ELSE today-1 END day_key,
  CASE WHEN EXISTS(SELECT 1 FROM weeks WHERE week=week_start AND n>=2) THEN week_start ELSE week_start-7 END week),
 day_sequence AS (SELECT d.day_key,row_number() OVER(ORDER BY d.day_key DESC)::integer seq FROM days d,anchors a WHERE d.day_key<=a.day_key),
 week_sequence AS (SELECT w.week,row_number() OVER(ORDER BY w.week DESC)::integer seq FROM weeks w,anchors a WHERE w.week<=a.week AND w.n>=2),
 per_type AS (SELECT training_type_id id,name,count(*) count,sum(km) km,sum(minutes) minutes FROM approved GROUP BY training_type_id,name),
 per_kind AS (SELECT kind,count(*) n FROM approved GROUP BY kind),
 current_week AS (SELECT * FROM base WHERE training_date>=week_start AND training_date<week_start+7)
 SELECT jsonb_build_object('profile_id',me,'today',today,'week_start',week_start,
  'totals',(SELECT jsonb_build_object('total',count(*),'approved',count(*) FILTER(WHERE status='approved'),
   'pending',count(*) FILTER(WHERE status='pending'),'rejected',count(*) FILTER(WHERE status='rejected')) FROM base),
  'types',coalesce((SELECT jsonb_agg(to_jsonb(p) ORDER BY p.count DESC,p.name,p.id) FROM per_type p),'[]'::jsonb),
  'stats',(SELECT jsonb_build_object('km',coalesce(sum(km) FILTER(WHERE name~*'jogg|lauf|running'),0),
   'sprints',count(*) FILTER(WHERE name~*'sprint'),'technique',coalesce(sum(minutes) FILTER(WHERE name~*'technik'),0)) FROM approved),
  'progress',(SELECT jsonb_build_object('training',count(*),'consistent',count(DISTINCT training_date),
   'road',coalesce(sum(km) FILTER(WHERE kind='jogging'),0),'flash',count(*) FILTER(WHERE kind='sprint'),
   'technician',coalesce(sum(minutes) FILTER(WHERE kind='technique'),0),'fighter',count(*) FILTER(WHERE kind='sparring'),
   'engine',count(*) FILTER(WHERE kind='strength'),'complete',(SELECT min(coalesce(p.n,0)) FROM
    (VALUES('boxing'),('sparring'),('technique'),('strength'),('sprint'),('jogging')) k(kind) LEFT JOIN per_kind p USING(kind))) FROM approved),
  'day_streak',(SELECT count(*) FROM day_sequence s,anchors a WHERE s.seq<=10000 AND s.day_key=a.day_key-(s.seq-1)),
  'last7',(SELECT count(*) FROM approved WHERE training_date BETWEEN today-6 AND today),
  'last30',(SELECT count(*) FROM approved WHERE training_date BETWEEN today-29 AND today),
  'days',coalesce((SELECT jsonb_agg(jsonb_build_object('date',day_key,'count',n) ORDER BY day_key) FROM days WHERE day_key BETWEEN today-41 AND today),'[]'::jsonb),
  'weekly',(SELECT jsonb_build_object('done',count(*) FILTER(WHERE status='approved'),'pending',count(*) FILTER(WHERE status='pending'),
   'boxing_done',count(*) FILTER(WHERE status='approved' AND kind IN ('boxing','technique','sparring')),
   'boxing_pending',count(*) FILTER(WHERE status='pending' AND kind IN ('boxing','technique','sparring')),
   'engine_done',count(*) FILTER(WHERE status='approved' AND kind IN ('jogging','sprint','strength')),
   'engine_pending',count(*) FILTER(WHERE status='pending' AND kind IN ('jogging','sprint','strength')),
   'streak',(SELECT count(*) FROM week_sequence s,anchors a WHERE s.seq<=520 AND s.week=a.week-7*(s.seq-1))) FROM current_week)
 ) INTO result;
 RETURN result;
END $fn$;

REVOKE ALL ON FUNCTION league_studio_private.studio_training_history_core(text,timestamptz,uuid),
 league_studio_private.studio_training_summary_core() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION league_studio_private.studio_training_history_core(text,timestamptz,uuid),
 league_studio_private.studio_training_summary_core() TO authenticated;
CREATE OR REPLACE FUNCTION public.get_my_studio_training_history(
 p_status text DEFAULT 'all',p_before timestamptz DEFAULT NULL,p_before_id uuid DEFAULT NULL)
RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER SET search_path=''
AS $fn$ SELECT league_studio_private.studio_training_history_core(p_status,p_before,p_before_id) $fn$;
CREATE OR REPLACE FUNCTION public.get_my_studio_training_summary()
RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER SET search_path=''
AS $fn$ SELECT league_studio_private.studio_training_summary_core() $fn$;
REVOKE ALL ON FUNCTION public.get_my_studio_training_history(text,timestamptz,uuid),
 public.get_my_studio_training_summary() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_studio_training_history(text,timestamptz,uuid),
 public.get_my_studio_training_summary() TO authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
