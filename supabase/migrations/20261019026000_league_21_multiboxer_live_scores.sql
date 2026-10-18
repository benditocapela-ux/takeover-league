-- Read-only, participant-limited live arena scoreboard. No direct table exposure.
create or replace function league_v21_private.arena_live_scores_core(p_arena uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $f$
declare actor public.profiles%rowtype; d public.league_arena_duels_v21%rowtype;rows jsonb;
begin
 select * into actor from public.profiles p where p.auth_user_id=(select auth.uid()) and p.is_active and p.role in ('boxer','admin');
 if not found then raise exception 'Active actor required' using errcode='42501';end if;
 select * into d from public.league_arena_duels_v21 where id=p_arena;
 if not found or d.status not in ('active','awaiting_reviews') then raise exception 'Arena not active' using errcode='22023';end if;
 if actor.role='boxer' and not exists(
  select 1 from public.league_arena_members_v21 m where m.arena_id=p_arena
   and m.boxer_id=actor.id and m.status='accepted')
 then raise exception 'Not an accepted arena participant' using errcode='42501';end if;
 if exists(
  select 1 from public.training_submissions s
  join public.league_arena_members_v21 m on m.boxer_id=s.boxer_id and m.arena_id=d.id and m.status='accepted'
  join public.point_transactions t on t.submission_id=s.id and t.boxer_id=s.boxer_id
   and t.category in ('training','legacy_import')
  where s.status='approved' and s.created_at<=d.ends_at
    and s.training_date between (d.starts_at at time zone 'Europe/Zurich')::date
                            and (d.ends_at at time zone 'Europe/Zurich')::date
  group by s.id having count(*)>1
 ) then raise exception 'Duplicate scoring ledger' using errcode='23514';end if;
 with scores as (
  select m.boxer_id,p.display_name,
    coalesce(sum(t.points) filter(where s.status='approved'),0)::integer as score,
    count(distinct s.id) filter(where s.status='pending')::integer as pending
  from public.league_arena_members_v21 m
  join public.profiles p on p.id=m.boxer_id
  left join public.training_submissions s on s.boxer_id=m.boxer_id
    and s.created_at<=least(d.ends_at,now())
    and s.training_date between (d.starts_at at time zone 'Europe/Zurich')::date
                            and least((d.ends_at at time zone 'Europe/Zurich')::date,current_date)
    and s.status in ('approved','pending')
  left join public.point_transactions t on t.submission_id=s.id
    and t.boxer_id=m.boxer_id and t.category in ('training','legacy_import')
  where m.arena_id=d.id and m.status='accepted'
  group by m.boxer_id,p.display_name
 ),ranked as (
  select boxer_id,display_name,score,pending,rank() over(order by score desc)::integer place from scores
 )
 select coalesce(pg_catalog.jsonb_agg(
  pg_catalog.jsonb_build_object('boxer_id',boxer_id,'name',display_name,'score',score,'pending',pending,'rank',place)
  order by place,display_name),'[]'::jsonb) into rows from ranked;
 return pg_catalog.jsonb_build_object('status',d.status,'provisional',true,'participants',rows);
end$f$;
revoke all on function league_v21_private.arena_live_scores_core(uuid) from public,anon,authenticated;
grant execute on function league_v21_private.arena_live_scores_core(uuid) to authenticated;
create or replace function public.league_v21_arena_live_scores(p_arena uuid)
returns jsonb language sql stable security invoker set search_path=''
as $f$ select league_v21_private.arena_live_scores_core(p_arena) $f$;
revoke all on function public.league_v21_arena_live_scores(uuid) from public,anon,authenticated;
grant execute on function public.league_v21_arena_live_scores(uuid) to authenticated;
