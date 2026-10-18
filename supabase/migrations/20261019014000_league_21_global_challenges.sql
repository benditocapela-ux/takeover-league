-- Global league challenges 2.1 – independent of private coach assignments.
-- RLS restricts membership, and NO rewards are paid by joining.
create table if not exists public.league_global_challenges_v21 (
 id uuid primary key default gen_random_uuid(),
 title text not null check(length(trim(title)) between 3 and 120),
 description text not null default '',
 metric text not null check(metric in ('training_sessions','jogging_km','technique_minutes')),
 target_value numeric not null check(target_value>0 and target_value<=1000000),
 starts_at timestamptz not null,
 ends_at timestamptz not null,
 status text not null default 'draft' check(status in ('draft','active','closed')),
 created_by uuid not null references public.profiles(id),
 created_at timestamptz not null default now(),
 check(ends_at>starts_at)
);
create table if not exists public.league_global_entries_v21 (
 id uuid primary key default gen_random_uuid(),
 challenge_id uuid not null references public.league_global_challenges_v21(id) on delete restrict,
 boxer_id uuid not null references public.profiles(id) on delete cascade,
 joined_at timestamptz not null default now(),
 unique(challenge_id,boxer_id)
);
alter table public.league_global_challenges_v21 enable row level security;
alter table public.league_global_entries_v21 enable row level security;
revoke all on public.league_global_challenges_v21,public.league_global_entries_v21 from public,anon,authenticated;
grant select on public.league_global_challenges_v21 to anon,authenticated;
grant select on public.league_global_entries_v21 to authenticated;
drop policy if exists "Only active global challenges are public" on public.league_global_challenges_v21;
create policy "Only active global challenges are public" on public.league_global_challenges_v21 for select to anon,authenticated using(status in ('active','closed'));
drop policy if exists "Only own global challenge entries" on public.league_global_entries_v21;
create policy "Only own global challenge entries" on public.league_global_entries_v21 for select to authenticated using(
 exists(select 1 from public.profiles p where p.id=boxer_id and p.auth_user_id=(select auth.uid()) and p.is_active)
 or exists(select 1 from public.profiles p where p.auth_user_id=(select auth.uid()) and p.is_active and p.role='admin')
);
create or replace function league_v21_private.global_join_core(p_challenge uuid)
returns jsonb language plpgsql security definer set search_path='' as $f$
declare actor public.profiles%rowtype;c public.league_global_challenges_v21%rowtype;entry uuid;
begin
 select * into actor from public.profiles p where p.auth_user_id=(select auth.uid()) and p.is_active and p.role='boxer';
 if not found then raise exception 'Active boxer required' using errcode='42501';end if;
 select * into c from public.league_global_challenges_v21 where id=p_challenge for share;
 if not found or c.status<>'active' or now() not between c.starts_at and c.ends_at
 then raise exception 'Global challenge is not open' using errcode='22023';end if;
 insert into public.league_global_entries_v21(challenge_id,boxer_id)
 values(c.id,actor.id)
 on conflict(challenge_id,boxer_id) do update set boxer_id=excluded.boxer_id
 returning id into entry;
 return pg_catalog.jsonb_build_object('entry_id',entry,'joined',true);
end$f$;
revoke all on function league_v21_private.global_join_core(uuid) from public,anon,authenticated;
grant execute on function league_v21_private.global_join_core(uuid) to authenticated;
create or replace function public.league_v21_join_global_challenge(p_challenge uuid)
returns jsonb language sql volatile security invoker set search_path=''
as $f$ select league_v21_private.global_join_core(p_challenge) $f$;
revoke all on function public.league_v21_join_global_challenge(uuid) from public,anon,authenticated;
grant execute on function public.league_v21_join_global_challenge(uuid) to authenticated;
-- Administrative challenge creation is intentionally not opened to clients yet;
-- use a separately reviewed/authorized admin function in the next stage.
