-- Takeover 2.1 private multiplayer arena: 3-8 real accepted boxers, one final ledger-free result.
-- No award transactions; avoids bypassing unsettled EXP policy.
create table if not exists public.league_arena_duels_v21(
 id uuid primary key default gen_random_uuid(),
 title text not null check(length(trim(title)) between 3 and 120),
 created_by uuid not null references public.profiles(id),
 duration_days integer not null check(duration_days in (7,14)),
 status text not null default 'invited' check(status in ('invited','active','awaiting_reviews','settled','cancelled')),
 starts_at timestamptz,ends_at timestamptz,settled_at timestamptz,
 created_at timestamptz not null default now(),
 check(ends_at is null or (starts_at is not null and ends_at=starts_at+duration_days*interval '1 day'))
);
create table if not exists public.league_arena_members_v21(
 arena_id uuid not null references public.league_arena_duels_v21(id) on delete restrict,
 boxer_id uuid not null references public.profiles(id) on delete restrict,
 status text not null default 'invited' check(status in ('invited','accepted','declined')),
 responded_at timestamptz,
 primary key(arena_id,boxer_id)
);
create table if not exists public.league_arena_results_v21(
 arena_id uuid not null references public.league_arena_duels_v21(id) on delete restrict,
 boxer_id uuid not null references public.profiles(id) on delete restrict,
 boxer_name text not null,
 score integer not null check(score>=0),
 rank_position integer not null check(rank_position>0),
 closed_at timestamptz not null default now(),
 primary key(arena_id,boxer_id)
);
create index if not exists league_arena_members_v21_boxer_idx on public.league_arena_members_v21(boxer_id,arena_id);
do $guard$ declare name text;begin
 foreach name in array array['league_arena_duels_v21','league_arena_members_v21','league_arena_results_v21'] loop
  execute format('alter table public.%I enable row level security',name);
  execute format('revoke all on public.%I from public,anon,authenticated',name);
 end loop;
end$guard$;
create or replace function league_v21_private.arena_actor()
returns public.profiles language sql stable security definer set search_path=''
as $f$ select p from public.profiles p where p.auth_user_id=(select auth.uid()) and p.is_active limit 1 $f$;
revoke all on function league_v21_private.arena_actor() from public,anon,authenticated;
grant execute on function league_v21_private.arena_actor() to authenticated;

create or replace function league_v21_private.arena_create_core(p_title text,p_duration integer,p_boxers uuid[])
returns uuid language plpgsql volatile security definer set search_path='' as $f$
declare actor public.profiles%rowtype;result uuid;num integer;
begin
 select * into actor from public.profiles p where p.auth_user_id=(select auth.uid()) and p.is_active and p.role='admin';
 if not found then raise exception 'Only active admin may invite a multiplayer arena' using errcode='42501';end if;
 if p_title is null or length(trim(p_title)) not between 3 and 120
  or p_duration not in (7,14) or p_boxers is null or pg_catalog.array_length(p_boxers,1) not between 3 and 8
 then raise exception 'Arena requires 3-8 boxers' using errcode='22023';end if;
 select count(distinct id) into num from pg_catalog.unnest(p_boxers) id;
 if num<>pg_catalog.array_length(p_boxers,1) then raise exception 'Duplicate boxer invitation' using errcode='22023';end if;
 if (select count(*) from public.profiles p where p.id=any(p_boxers) and p.role='boxer' and p.is_active)<>num
 then raise exception 'All invitees must be active boxers' using errcode='22023';end if;
 insert into public.league_arena_duels_v21(title,duration_days,created_by)
 values(trim(p_title),p_duration,actor.id) returning id into result;
 insert into public.league_arena_members_v21(arena_id,boxer_id)
 select result,id from pg_catalog.unnest(p_boxers) id;
 return result;
end$f$;
revoke all on function league_v21_private.arena_create_core(text,integer,uuid[]) from public,anon,authenticated;
grant execute on function league_v21_private.arena_create_core(text,integer,uuid[]) to authenticated;

create or replace function league_v21_private.arena_respond_core(p_arena uuid,p_accept boolean)
returns text language plpgsql volatile security definer set search_path='' as $f$
declare actor public.profiles%rowtype;d public.league_arena_duels_v21%rowtype;
begin
 select * into actor from public.profiles p where p.auth_user_id=(select auth.uid()) and p.is_active and p.role='boxer';
 if not found then raise exception 'Active boxer only' using errcode='42501';end if;
 select * into d from public.league_arena_duels_v21 where id=p_arena for update;
 if not found or d.status<>'invited' then raise exception 'Arena invitation closed' using errcode='22023';end if;
 update public.league_arena_members_v21 set
 status=case when p_accept then 'accepted' else 'declined' end,responded_at=now()
 where arena_id=p_arena and boxer_id=actor.id and status='invited';
 if not found then raise exception 'No open invitation for this boxer' using errcode='42501';end if;
 return case when p_accept then 'accepted' else 'declined' end;
end$f$;
revoke all on function league_v21_private.arena_respond_core(uuid,boolean) from public,anon,authenticated;
grant execute on function league_v21_private.arena_respond_core(uuid,boolean) to authenticated;

create or replace function league_v21_private.arena_start_core(p_arena uuid)
returns jsonb language plpgsql volatile security definer set search_path='' as $f$
declare actor public.profiles%rowtype;d public.league_arena_duels_v21%rowtype;num integer;clock timestamptz;
begin
 select * into actor from public.profiles p where p.auth_user_id=(select auth.uid()) and p.is_active and p.role='admin';
 if not found then raise exception 'Active admin only' using errcode='42501';end if;
 select * into d from public.league_arena_duels_v21 where id=p_arena for update;
 if not found or d.status<>'invited' then raise exception 'Arena cannot start' using errcode='22023';end if;
 select count(*) into num from public.league_arena_members_v21 where arena_id=p_arena and status='accepted';
 if num<3 then raise exception 'At least three accepted boxers required' using errcode='22023';end if;
 clock:=clock_timestamp();
 update public.league_arena_duels_v21 set status='active',starts_at=clock,ends_at=clock+d.duration_days*interval '1 day'
 where id=p_arena;
 return pg_catalog.jsonb_build_object('status','active','participants',num);
end$f$;
revoke all on function league_v21_private.arena_start_core(uuid) from public,anon,authenticated;
grant execute on function league_v21_private.arena_start_core(uuid) to authenticated;

-- Secure participant-level data lookup; no table grants.
create or replace function league_v21_private.arena_list_core()
returns jsonb language plpgsql stable security definer set search_path='' as $f$
declare actor public.profiles%rowtype;data jsonb;
begin
 select * into actor from public.profiles p where p.auth_user_id=(select auth.uid()) and p.is_active and p.role in ('boxer','admin');
 if not found then raise exception 'Active boxer or admin required' using errcode='42501';end if;
 select coalesce(pg_catalog.jsonb_agg(item),'[]'::jsonb) into data
 from (
  select pg_catalog.jsonb_build_object(
   'id',d.id,'title',d.title,'status',d.status,'duration_days',d.duration_days,
   'starts_at',d.starts_at,'ends_at',d.ends_at,
   'participants',coalesce((select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
     'boxer_id',m.boxer_id,'name',p.display_name,'status',m.status) order by p.display_name)
     from public.league_arena_members_v21 m join public.profiles p on p.id=m.boxer_id where m.arena_id=d.id),'[]'::jsonb),
   'results',coalesce((select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
     'name',r.boxer_name,'score',r.score,'rank',r.rank_position) order by r.rank_position,r.boxer_name)
     from public.league_arena_results_v21 r where r.arena_id=d.id),'[]'::jsonb)
  ) item
  from public.league_arena_duels_v21 d
  where actor.role='admin' or exists(select 1 from public.league_arena_members_v21 m
   where m.arena_id=d.id and m.boxer_id=actor.id)
  order by d.created_at desc limit 100
 ) sub;
 return data;
end$f$;
revoke all on function league_v21_private.arena_list_core() from public,anon,authenticated;
grant execute on function league_v21_private.arena_list_core() to authenticated;

create or replace function league_v21_private.arena_finish_core(p_arena uuid)
returns jsonb language plpgsql volatile security definer set search_path='' as $f$
declare actor public.profiles%rowtype;d public.league_arena_duels_v21%rowtype;num integer;pending_count integer;
begin
 select * into actor from public.profiles p where p.auth_user_id=(select auth.uid()) and p.is_active and p.role='admin';
 if not found then raise exception 'Only admin may finalize arena' using errcode='42501';end if;
 select * into d from public.league_arena_duels_v21 where id=p_arena for update;
 if not found then raise exception 'Arena not found' using errcode='22023';end if;
 if d.status='settled' then return pg_catalog.jsonb_build_object('status','settled','unchanged',true);end if;
 if d.status not in ('active','awaiting_reviews') or d.ends_at>now() then
 raise exception 'Arena not due' using errcode='22023';end if;
 select count(*) into pending_count
 from public.training_submissions s join public.league_arena_members_v21 m
  on m.boxer_id=s.boxer_id and m.arena_id=d.id and m.status='accepted'
 where s.status='pending' and s.created_at<=d.ends_at
   and s.training_date between (d.starts_at at time zone 'Europe/Zurich')::date
                           and (d.ends_at at time zone 'Europe/Zurich')::date;
 if pending_count>0 then
  update public.league_arena_duels_v21 set status='awaiting_reviews' where id=d.id;
  return pg_catalog.jsonb_build_object('status','awaiting_reviews','pending',pending_count);
 end if;
 if exists(select 1 from public.league_arena_results_v21 where arena_id=d.id)
 then raise exception 'Existing result ledger requires review' using errcode='23505';end if;
 -- Fail closed on duplicated approved submission ledger rows.
 if exists(
 select 1 from public.training_submissions s
 join public.league_arena_members_v21 m on m.boxer_id=s.boxer_id and m.arena_id=d.id and m.status='accepted'
 join public.point_transactions t on t.submission_id=s.id and t.boxer_id=s.boxer_id and t.category in ('training','legacy_import')
 where s.status='approved' and s.created_at<=d.ends_at
 and s.training_date between (d.starts_at at time zone 'Europe/Zurich')::date and (d.ends_at at time zone 'Europe/Zurich')::date
 group by s.id having count(*)>1
 ) then raise exception 'Duplicate training score ledger' using errcode='23514';end if;
 with scores as (
 select m.boxer_id,p.display_name boxer_name,coalesce(sum(t.points),0)::integer score
 from public.league_arena_members_v21 m join public.profiles p on p.id=m.boxer_id
 left join public.training_submissions s on s.boxer_id=m.boxer_id
  and s.status='approved' and s.created_at<=d.ends_at
  and s.training_date between (d.starts_at at time zone 'Europe/Zurich')::date and (d.ends_at at time zone 'Europe/Zurich')::date
 left join public.point_transactions t on t.submission_id=s.id and t.boxer_id=m.boxer_id and t.category in ('training','legacy_import')
 where m.arena_id=d.id and m.status='accepted'
 group by m.boxer_id,p.display_name
 ),ranked as (
 select boxer_id,boxer_name,score,rank() over(order by score desc)::integer rank_position
 from scores
 )
 insert into public.league_arena_results_v21(arena_id,boxer_id,boxer_name,score,rank_position)
 select d.id,boxer_id,boxer_name,score,rank_position from ranked;
 get diagnostics num=row_count;
 update public.league_arena_duels_v21 set status='settled',settled_at=now() where id=d.id;
 return pg_catalog.jsonb_build_object('status','settled','participants',num,'rewards_paid',false);
end$f$;
revoke all on function league_v21_private.arena_finish_core(uuid) from public,anon,authenticated;
grant execute on function league_v21_private.arena_finish_core(uuid) to authenticated;

create or replace function public.league_v21_arena_create(p_title text,p_duration integer,p_boxers uuid[])
returns uuid language sql volatile security invoker set search_path=''
as $f$ select league_v21_private.arena_create_core(p_title,p_duration,p_boxers) $f$;
create or replace function public.league_v21_arena_respond(p_arena uuid,p_accept boolean)
returns text language sql volatile security invoker set search_path=''
as $f$ select league_v21_private.arena_respond_core(p_arena,p_accept) $f$;
create or replace function public.league_v21_arena_start(p_arena uuid)
returns jsonb language sql volatile security invoker set search_path=''
as $f$ select league_v21_private.arena_start_core(p_arena) $f$;
create or replace function public.league_v21_arena_list_mine()
returns jsonb language sql stable security invoker set search_path=''
as $f$ select league_v21_private.arena_list_core() $f$;
create or replace function public.league_v21_arena_finish(p_arena uuid)
returns jsonb language sql volatile security invoker set search_path=''
as $f$ select league_v21_private.arena_finish_core(p_arena) $f$;
revoke all on function public.league_v21_arena_create(text,integer,uuid[]) from public,anon,authenticated;
revoke all on function public.league_v21_arena_respond(uuid,boolean) from public,anon,authenticated;
revoke all on function public.league_v21_arena_start(uuid) from public,anon,authenticated;
revoke all on function public.league_v21_arena_list_mine() from public,anon,authenticated;
revoke all on function public.league_v21_arena_finish(uuid) from public,anon,authenticated;
grant execute on function public.league_v21_arena_create(text,integer,uuid[]),
 public.league_v21_arena_respond(uuid,boolean),public.league_v21_arena_start(uuid),
 public.league_v21_arena_list_mine(),public.league_v21_arena_finish(uuid) to authenticated;
