-- Emergency rollback of PUBLIC COACH LISTING, not of privacy.
-- Requires the previous registration migration's profiles.is_listed column.
-- Never restore unfiltered functions: that would publish unlisted Boxer profiles.
BEGIN;
CREATE OR REPLACE FUNCTION public.get_award_leaderboard(p_award text, p_period text DEFAULT 'month'::text)
 RETURNS TABLE(boxer_name text, award_value numeric, rank_position bigint)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
with valid as (
  select
    p.id as boxer_id,
    p.display_name,
    s.training_date,
    s.jogging_km,
    s.technique_minutes,
    lower(t.name) as training_name
  from public.training_submissions s
  join public.profiles p
    on p.id = s.boxer_id
  join public.training_types t
    on t.id = s.training_type_id
  where s.status = 'approved'
    and p.role = 'boxer'
    and p.is_active AND p.is_listed = true
    and (
      p_period = 'all'
      or (
        p_period = 'month'
        and s.training_date >=
          date_trunc(
            'month',
            timezone('Europe/Zurich', now())
          )::date
        and s.training_date <
          (
            date_trunc(
              'month',
              timezone('Europe/Zurich', now())
            ) + interval '1 month'
          )::date
      )
    )
),
values_by_boxer as (
  select
    p.id as boxer_id,
    p.display_name,
    case
      when p_award = 'consistent'
        then count(distinct v.training_date)::numeric

      when p_award = 'road_king'
        then coalesce(
          sum(
            case
              when v.training_name ~ 'jogg|lauf|running'
              then v.jogging_km
              else 0
            end
          ), 0
        )::numeric

      when p_award = 'flash'
        then count(*) filter (
          where v.training_name ~ 'sprint'
        )::numeric

      when p_award = 'technician'
        then coalesce(
          sum(
            case
              when v.training_name ~ 'technik'
              then v.technique_minutes
              else 0
            end
          ), 0
        )::numeric

      else 0::numeric
    end as score
  from public.profiles p
  left join valid v
    on v.boxer_id = p.id
  where p.role = 'boxer'
    and p.is_active AND p.is_listed = true
  group by p.id, p.display_name
)
select
  display_name::text,
  score,
  dense_rank() over (order by score desc)::bigint
from values_by_boxer
where p_award in (
  'consistent',
  'road_king',
  'flash',
  'technician'
)
and p_period in ('month', 'all')
order by score desc, display_name asc;
$function$
;

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
    and p.is_active = true AND p.is_listed = true
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
  where p.role = 'boxer' and p.is_active = true AND p.is_listed = true;
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
      and p.is_active = true AND p.is_listed = true

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
    and p.is_active = true AND p.is_listed = true
  group by p.id, p.display_name
  order by coalesce(sum(t.exp), 0) desc,
           p.display_name asc;
$function$
;
COMMIT;
