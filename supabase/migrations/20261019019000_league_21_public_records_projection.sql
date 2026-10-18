-- Sanitized public boxer training records, refreshed only by an admin RPC.
-- This deliberately installs NO trigger on training approval and never exposes notes/weight.
create table if not exists public.league_public_records_v21(
 boxer_id uuid primary key references public.profiles(id) on delete cascade,
 boxer_name text not null,
 approved_sessions integer not null check(approved_sessions>=0),
 active_days integer not null check(active_days>=0),
 max_jogging_km numeric not null check(max_jogging_km>=0),
 max_technique_minutes integer not null check(max_technique_minutes>=0),
 refreshed_at timestamptz not null default now()
);
create index if not exists league_public_records_v21_name_idx on public.league_public_records_v21(boxer_name);
alter table public.league_public_records_v21 enable row level security;
revoke all on public.league_public_records_v21 from public,anon,authenticated;
grant select on public.league_public_records_v21 to anon,authenticated;
drop policy if exists "Public records are sanitized" on public.league_public_records_v21;
create policy "Public records are sanitized" on public.league_public_records_v21 for select to anon,authenticated using(true);
create or replace function league_v21_private.refresh_public_records_core(p_limit integer default 25,p_after uuid default null)
returns jsonb language plpgsql security definer set search_path='' as $f$
declare actor public.profiles%rowtype;v_processed integer;v_last uuid;
begin
 select * into actor from public.profiles p where p.auth_user_id=(select auth.uid()) and p.is_active and p.role='admin';
 if not found then raise exception 'Only active admin' using errcode='42501';end if;
 if p_limit is null or p_limit not between 1 and 25 then raise exception 'Limit must be 1-25' using errcode='22023';end if;
 with selected as (
  select p.id,p.display_name from public.profiles p
  where p.role='boxer' and p.is_active and (p_after is null or p.id>p_after)
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
 select count(*)::integer,max(boxer_id) into v_processed,v_last from stored;
 return pg_catalog.jsonb_build_object('processed',v_processed,'last_boxer_id',coalesce(v_last,p_after),
   'has_more',exists(select 1 from public.profiles p where p.role='boxer' and p.is_active and (coalesce(v_last,p_after) is null or p.id>coalesce(v_last,p_after))));
end$f$;
revoke all on function league_v21_private.refresh_public_records_core(integer,uuid) from public,anon,authenticated;
grant execute on function league_v21_private.refresh_public_records_core(integer,uuid) to authenticated;
create or replace function public.league_v21_refresh_public_records(p_limit integer default 25,p_after uuid default null)
returns jsonb language sql volatile security invoker set search_path=''
as $f$ select league_v21_private.refresh_public_records_core(p_limit,p_after) $f$;
revoke all on function public.league_v21_refresh_public_records(integer,uuid) from public,anon,authenticated;
grant execute on function public.league_v21_refresh_public_records(integer,uuid) to authenticated;
