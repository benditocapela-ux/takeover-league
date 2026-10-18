-- V2.1 authoritative, reproducible global challenge settlement.
-- No EXP/point rewards: the award policy is not yet approved.
create table if not exists public.league_global_results_v21(
 challenge_id uuid not null references public.league_global_challenges_v21(id) on delete restrict,
 boxer_id uuid not null references public.profiles(id) on delete restrict,
 boxer_name text not null,
 progress numeric not null check(progress>=0),
 rank_position integer not null check(rank_position>0),
 completed boolean not null,
 closed_at timestamptz not null default now(),
 primary key(challenge_id,boxer_id),
 unique(challenge_id,rank_position)
);
alter table public.league_global_results_v21 enable row level security;
revoke all on public.league_global_results_v21 from public,anon,authenticated;
grant select on public.league_global_results_v21 to anon,authenticated;
drop policy if exists "Only finalized global results are public" on public.league_global_results_v21;
create policy "Only finalized global results are public" on public.league_global_results_v21 for select to anon,authenticated using(
 exists(select 1 from public.league_global_challenges_v21 c where c.id=challenge_id and c.status='closed')
);
create or replace function league_v21_private.global_close_core(p_challenge uuid)
returns jsonb language plpgsql volatile security definer set search_path='' as $func$
declare actor public.profiles%rowtype; c public.league_global_challenges_v21%rowtype; tally integer;
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
 if exists(select 1 from public.league_global_results_v21 x where x.challenge_id=p_challenge)
 then raise exception 'Existing results require review' using errcode='23505';end if;
 with scores as (
  select e.boxer_id,p.display_name as boxer_name,
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
  group by e.boxer_id,p.display_name
 ),ordered as (
  select boxer_id,boxer_name,progress,
   row_number() over(order by progress desc,boxer_id)::integer as rank_position
  from scores
 )
 insert into public.league_global_results_v21(challenge_id,boxer_id,boxer_name,progress,rank_position,completed)
 select c.id,boxer_id,boxer_name,progress,rank_position,progress>=c.target_value from ordered;
 get diagnostics tally=row_count;
 update public.league_global_challenges_v21 set status='closed' where id=c.id;
 return pg_catalog.jsonb_build_object('status','closed','participants',tally,'rewards_paid',false);
end$func$;
revoke all on function league_v21_private.global_close_core(uuid) from public,anon,authenticated;
grant execute on function league_v21_private.global_close_core(uuid) to authenticated;
create or replace function public.league_v21_admin_close_global_challenge(p_challenge uuid)
returns jsonb language sql volatile security invoker set search_path=''
as $func$ select league_v21_private.global_close_core(p_challenge) $func$;
revoke all on function public.league_v21_admin_close_global_challenge(uuid) from public,anon,authenticated;
grant execute on function public.league_v21_admin_close_global_challenge(uuid) to authenticated;
