-- Test project ONLY; reproduces production baseline read APIs for registration fixture.
-- Never run on production. It lacks the sentinel public.league_test_boxers.
BEGIN;
DO $assert_test$ BEGIN
 IF to_regclass('public.league_test_boxers') IS NULL THEN
  RAISE EXCEPTION 'TEST ONLY: league_test_boxers sentinel missing';
 END IF;
END $assert_test$;
CREATE OR REPLACE FUNCTION public.get_monthly_awards(p_month date DEFAULT CURRENT_DATE)
 RETURNS TABLE(award_code text, award_name text, boxer_name text, award_value numeric, award_unit text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
with monthly_stats as (
  select
    p.id as boxer_id,
    p.display_name,
    count(distinct s.training_date)::numeric as training_days,
    coalesce(
      sum(s.jogging_km) filter (
        where lower(t.name) = 'joggen'
      ), 0
    )::numeric as jogging_km,
    count(*) filter (
      where lower(t.name) in (
        'sprint-intervalle',
        'sprintintervalle'
      )
    )::numeric as sprint_sessions,
    coalesce(
      sum(s.technique_minutes) filter (
        where lower(t.name) = 'techniktraining'
      ), 0
    )::numeric as technique_minutes
  from public.profiles p
  left join public.training_submissions s
    on s.boxer_id = p.id
    and s.status = 'approved'
    and s.training_date >= date_trunc('month', p_month)::date
    and s.training_date <
      (date_trunc('month', p_month) + interval '1 month')::date
  left join public.training_types t
    on t.id = s.training_type_id
  where p.role = 'boxer'
    and p.is_active = true
  group by p.id, p.display_name
),
award_scores as (
  select 'consistent'::text as code,
         'Mr. Consistent'::text as name,
         display_name,
         training_days as score,
         'Tage'::text as unit
  from monthly_stats

  union all
  select 'road_king', 'Road King',
         display_name, jogging_km, 'km'
  from monthly_stats

  union all
  select 'flash', 'The Flash',
         display_name, sprint_sessions, 'Einheiten'
  from monthly_stats

  union all
  select 'technician', 'The Technician',
         display_name, technique_minutes, 'Minuten'
  from monthly_stats
),
ranked as (
  select *,
    max(score) over (partition by code) as best_score
  from award_scores
)
select
  code,
  name,
  display_name,
  score,
  unit
from ranked
where score = best_score
  and score > 0
order by code, display_name;
$function$
;
CREATE OR REPLACE FUNCTION public.get_public_boxer_avatars()
 RETURNS TABLE(boxer_name text, avatar_key text, avatar_url text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select p.display_name::text, p.avatar_key::text, p.avatar_url::text
  from public.profiles p
  where p.role = 'boxer' and p.is_active = true;
$function$
;
CREATE OR REPLACE FUNCTION public.get_public_leaderboard()
 RETURNS TABLE(rank_position bigint, boxer_name text, monthly_points bigint, lifetime_exp bigint)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  with boxer_scores as (
    select
      p.id,
      p.display_name::text as boxer_name,

      coalesce(
        sum(t.points) filter (
          where t.effective_date >=
            date_trunc('month', current_date)::date
          and t.effective_date <
            (date_trunc('month', current_date)
              + interval '1 month')::date
        ),
        0
      )::bigint as monthly_points,

      coalesce(sum(t.exp), 0)::bigint as lifetime_exp

    from public.profiles p

    left join public.point_transactions t
      on t.boxer_id = p.id

    where p.role = 'boxer'
      and p.is_active = true

    group by p.id, p.display_name
  )

  select
    row_number() over (
      order by
        s.monthly_points desc,
        s.lifetime_exp desc,
        s.boxer_name asc,
        s.id asc
    ) as rank_position,

    s.boxer_name,
    s.monthly_points,
    s.lifetime_exp

  from boxer_scores s

  where s.monthly_points > 0

  order by rank_position;
$function$
;
CREATE OR REPLACE FUNCTION public.get_public_levels()
 RETURNS TABLE(boxer_name text, lifetime_exp bigint)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select
    p.display_name::text as boxer_name,
    coalesce(sum(t.exp), 0)::bigint as lifetime_exp
  from public.profiles p
  left join public.point_transactions t
    on t.boxer_id = p.id
  where p.role = 'boxer'
    and p.is_active = true
  group by p.id, p.display_name
  order by coalesce(sum(t.exp), 0) desc,
           p.display_name asc;
$function$
;
COMMIT;
