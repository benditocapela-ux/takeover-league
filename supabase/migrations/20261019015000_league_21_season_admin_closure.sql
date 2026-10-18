-- Seasons & Hall of Fame: admin-verified close, single immutable snapshot.
-- No point transactions are created; this only captures historical standings.
alter table public.league_season_results_v21 add column if not exists boxer_name text not null default 'Boxer';
alter table public.league_hall_of_fame_v21 add column if not exists boxer_name text not null default 'Boxer';
create or replace function league_v21_private.season_create_core(p_title text,p_start date,p_end date)
returns uuid language plpgsql security definer set search_path='' as $f$
declare actor public.profiles%rowtype;result uuid;
begin
 select * into actor from public.profiles p where p.auth_user_id=(select auth.uid()) and p.is_active and p.role='admin';
 if not found then raise exception 'Only active admin' using errcode='42501';end if;
 if p_title is null or length(trim(p_title)) not between 3 and 100
    or p_start is null or p_end is null or p_end<p_start or p_end>p_start+interval '366 days'
 then raise exception 'Invalid season window' using errcode='22023';end if;
 if exists(select 1 from public.league_seasons_v21 s where s.starts_on<=p_end and s.ends_on>=p_start)
 then raise exception 'Overlapping season exists' using errcode='23505';end if;
 insert into public.league_seasons_v21(title,starts_on,ends_on,status)
 values(trim(p_title),p_start,p_end,'draft') returning id into result;
 return result;
end$f$;
create or replace function league_v21_private.season_transition_core(p_season uuid,p_action text)
returns jsonb language plpgsql security definer set search_path='' as $f$
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
  if exists(select 1 from public.league_season_results_v21 r where r.season_id=season.id)
  then raise exception 'Unexpected existing season snapshot' using errcode='23505';end if;
  insert into public.league_season_results_v21(season_id,boxer_id,boxer_name,rank_position,points,exp)
  select season.id,p.id,p.display_name,
         row_number() over(order by greatest(coalesce(sum(t.points),0),0) desc,
                                    greatest(coalesce(sum(t.exp),0),0) desc,p.id)::integer,
         greatest(coalesce(sum(t.points),0),0)::integer,
         greatest(coalesce(sum(t.exp),0),0)::integer
  from public.profiles p
  left join public.point_transactions t on t.boxer_id=p.id
    and t.effective_date between season.starts_on and season.ends_on
  where p.role='boxer'
  group by p.id,p.display_name;
  get diagnostics n=row_count;
  insert into public.league_hall_of_fame_v21(boxer_id,boxer_name,season_id,title,description)
  select r.boxer_id,r.boxer_name,season.id,
   case r.rank_position when 1 then 'Saisonmeister' when 2 then 'Vizechampion' else 'Saisonpodium' end,
   season.title||' · Platz '||r.rank_position
  from public.league_season_results_v21 r
  where r.season_id=season.id and r.rank_position<=3
  on conflict(boxer_id,season_id,title) do nothing;
  update public.league_seasons_v21 set status='closed' where id=season.id;
  return pg_catalog.jsonb_build_object('status','closed','ranked_boxers',n);
 end if;
 raise exception 'Invalid season action' using errcode='22023';
end$f$;
revoke all on function league_v21_private.season_create_core(text,date,date) from public,anon,authenticated;
revoke all on function league_v21_private.season_transition_core(uuid,text) from public,anon,authenticated;
grant execute on function league_v21_private.season_create_core(text,date,date) to authenticated;
grant execute on function league_v21_private.season_transition_core(uuid,text) to authenticated;
create or replace function public.league_v21_admin_create_season(p_title text,p_start date,p_end date)
returns uuid language sql volatile security invoker set search_path=''
as $f$ select league_v21_private.season_create_core(p_title,p_start,p_end) $f$;
create or replace function public.league_v21_admin_season_action(p_season uuid,p_action text)
returns jsonb language sql volatile security invoker set search_path=''
as $f$ select league_v21_private.season_transition_core(p_season,p_action) $f$;
revoke all on function public.league_v21_admin_create_season(text,date,date) from public,anon,authenticated;
revoke all on function public.league_v21_admin_season_action(uuid,text) from public,anon,authenticated;
grant execute on function public.league_v21_admin_create_season(text,date,date) to authenticated;
grant execute on function public.league_v21_admin_season_action(uuid,text) to authenticated;
