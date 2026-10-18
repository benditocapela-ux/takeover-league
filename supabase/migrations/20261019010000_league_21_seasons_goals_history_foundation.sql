-- Takeover League 2.1 foundation. ADDITIVE AND STAGING ONLY.
-- No automatic point/EXP awards. Rewards must be server-authorized and idempotent.
create table if not exists public.league_seasons_v21 (
 id uuid primary key default gen_random_uuid(),
 title text not null check (length(trim(title)) between 3 and 100),
 starts_on date not null,
 ends_on date not null,
 status text not null default 'draft' check (status in ('draft','active','closed')),
 created_at timestamptz not null default now(),
 check (ends_on >= starts_on),
 unique(starts_on, ends_on)
);
create table if not exists public.league_boxer_goals_v21 (
 id uuid primary key default gen_random_uuid(),
 boxer_id uuid not null references public.profiles(id) on delete cascade,
 title text not null check(length(trim(title)) between 3 and 120),
 metric text not null check(metric in ('training_sessions','jogging_km','technique_minutes','custom')),
 target_value numeric not null check(target_value>0 and target_value<=1000000),
 manual_progress numeric not null default 0 check(manual_progress>=0 and manual_progress<=1000000),
 starts_on date not null default current_date,
 ends_on date not null,
 status text not null default 'active' check(status in ('active','completed','archived')),
 created_by uuid not null references public.profiles(id),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 check(ends_on>=starts_on)
);
create index if not exists league_boxer_goals_v21_owner_idx on public.league_boxer_goals_v21(boxer_id,status,ends_on);
create table if not exists public.league_goal_progress_v21 (
 id uuid primary key default gen_random_uuid(),
 goal_id uuid not null references public.league_boxer_goals_v21(id) on delete cascade,
 progress_delta numeric not null check(progress_delta>0 and progress_delta<=1000000),
 recorded_by uuid not null references public.profiles(id),
 note text check(note is null or length(note)<=500),
 created_at timestamptz not null default now()
);
create index if not exists league_goal_progress_v21_goal_idx on public.league_goal_progress_v21(goal_id,created_at);
create table if not exists public.league_season_results_v21 (
 id uuid primary key default gen_random_uuid(),
 season_id uuid not null references public.league_seasons_v21(id) on delete restrict,
 boxer_id uuid not null references public.profiles(id) on delete restrict,
 rank_position integer not null check(rank_position>0),
 points integer not null check(points>=0),
 exp integer not null check(exp>=0),
 captured_at timestamptz not null default now(),
 unique(season_id,boxer_id), unique(season_id,rank_position)
);
create table if not exists public.league_hall_of_fame_v21 (
 id uuid primary key default gen_random_uuid(),
 boxer_id uuid not null references public.profiles(id) on delete restrict,
 season_id uuid references public.league_seasons_v21(id) on delete restrict,
 title text not null check(length(trim(title)) between 3 and 120),
 description text,
 awarded_at timestamptz not null default now(),
 unique(boxer_id,season_id,title)
);
-- New features remain private/locked until reviewed, authorized server APIs exist.
do $guard$ declare t text;begin
 foreach t in array array['league_seasons_v21','league_boxer_goals_v21','league_goal_progress_v21',
   'league_season_results_v21','league_hall_of_fame_v21'] loop
  execute format('alter table public.%I enable row level security',t);
  execute format('revoke all on public.%I from public,anon,authenticated',t);
 end loop;
end$guard$;
-- Only season metadata and finalized historical rankings are public.
grant select on public.league_seasons_v21,public.league_season_results_v21,public.league_hall_of_fame_v21 to anon,authenticated;
drop policy if exists "Season metadata visible only after activation" on public.league_seasons_v21;
create policy "Season metadata visible only after activation" on public.league_seasons_v21 for select to anon,authenticated using(status in ('active','closed'));
drop policy if exists "Closed season results public" on public.league_season_results_v21;
create policy "Closed season results public" on public.league_season_results_v21 for select to anon,authenticated using(exists(select 1 from public.league_seasons_v21 s where s.id=season_id and s.status='closed'));
drop policy if exists "Hall of fame public for closed seasons" on public.league_hall_of_fame_v21;
create policy "Hall of fame public for closed seasons" on public.league_hall_of_fame_v21 for select to anon,authenticated using(season_id is not null and exists(select 1 from public.league_seasons_v21 s where s.id=season_id and s.status='closed'));
-- Authenticated boxer can read ONLY own goals, never unrestricted other boxer goals.
grant select on public.league_boxer_goals_v21,public.league_goal_progress_v21 to authenticated;
drop policy if exists "Owner or admin reads goals" on public.league_boxer_goals_v21;
create policy "Owner or admin reads goals" on public.league_boxer_goals_v21 for select to authenticated using (
 exists(select 1 from public.profiles p where p.id=boxer_id and p.auth_user_id=(select auth.uid()) and p.is_active)
 or exists(select 1 from public.profiles admin where admin.auth_user_id=(select auth.uid()) and admin.is_active and admin.role='admin')
);
drop policy if exists "Owner or admin reads manual progress" on public.league_goal_progress_v21;
create policy "Owner or admin reads manual progress" on public.league_goal_progress_v21 for select to authenticated using(
 exists(select 1 from public.league_boxer_goals_v21 g where g.id=goal_id)
);
-- No client-side INSERT/UPDATE/DELETE grants: mutations need a future audited RPC.
