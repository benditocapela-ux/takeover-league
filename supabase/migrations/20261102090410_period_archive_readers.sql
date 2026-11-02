-- Read-only period archive. No closure, reward, notification, flag or data rewrite.
-- Requires the installed V2.1 snapshot tables and profile listing/archive columns.
begin;
create schema if not exists league_archive_private;
revoke all on schema league_archive_private from public;
grant usage on schema league_archive_private to anon,authenticated;

-- Intentionally answers only whether a profile is publicly listable. This helper
-- also protects the existing table readers without deleting historical snapshots.
create or replace function league_archive_private.profile_visible(p_boxer uuid)
returns boolean language sql stable security definer set search_path='' as $fn$
 select exists(select 1 from public.profiles p where p.id=p_boxer
  and p.is_active and p.is_listed and p.archived_at is null and p.role in ('boxer','coach'))
$fn$;
revoke all on function league_archive_private.profile_visible(uuid) from public,anon,authenticated;
grant execute on function league_archive_private.profile_visible(uuid) to anon,authenticated;

drop policy if exists "Archive results respect current visibility" on public.league_season_results_v21;
create policy "Archive results respect current visibility" on public.league_season_results_v21
 as restrictive for select to anon,authenticated using(league_archive_private.profile_visible(boxer_id));
drop policy if exists "Archive honors respect current visibility" on public.league_hall_of_fame_v21;
create policy "Archive honors respect current visibility" on public.league_hall_of_fame_v21
 as restrictive for select to anon,authenticated using(league_archive_private.profile_visible(boxer_id));

-- Internal row source has no API grants. Final season ranks stay exactly as saved,
-- even if a currently hidden profile leaves a gap in the public ranking.
create or replace function league_archive_private.period_rows(p_kind text,p_season uuid,p_start date,p_end date,p_official boolean)
returns table(id uuid,boxer_id uuid,boxer_name text,rank_position bigint,points bigint,exp bigint,captured_at timestamptz)
language sql stable set search_path='' as $fn$
 with scores as (
  select p.id,p.display_name,
   coalesce(sum(t.points) filter(where t.effective_date>=p_start and t.effective_date<p_end),0)::bigint points,
   coalesce(sum(t.exp) filter(where t.effective_date>=p_start and t.effective_date<p_end),0)::bigint exp,
   coalesce(sum(t.exp),0)::bigint lifetime_exp
  from public.profiles p left join public.point_transactions t on t.boxer_id=p.id
  where not p_official and p.is_active and p.is_listed and p.archived_at is null
   and (p.role='boxer' or (p_kind='month' and p.role='coach'))
  group by p.id,p.display_name
 ), ranked as (
  select s.*,case when p_kind='month' then
   row_number() over(order by s.points desc,s.lifetime_exp desc,s.display_name,s.id)
   else rank() over(order by greatest(s.points,0) desc,greatest(s.exp,0) desc) end rank_position
  from scores s where p_kind<>'month' or s.points>0
 )
 select r.id,r.boxer_id,r.boxer_name,r.rank_position::bigint,r.points::bigint,r.exp::bigint,r.captured_at
 from public.league_season_results_v21 r join public.profiles p on p.id=r.boxer_id
 where p_official and r.season_id=p_season and p.is_active and p.is_listed and p.archived_at is null and p.role in ('boxer','coach')
 union all
 select r.id,r.id,r.display_name,r.rank_position,
  case when p_kind='season' then greatest(r.points,0) else r.points end,
  case when p_kind='season' then greatest(r.exp,0) else r.exp end,null::timestamptz from ranked r
$fn$;
revoke all on function league_archive_private.period_rows(text,uuid,date,date,boolean) from public,anon,authenticated;

create or replace function league_archive_private.period_core(p_kind text,p_key text,p_limit integer,p_offset integer)
returns jsonb language plpgsql stable security definer set search_path='' as $fn$
declare today date:=(pg_catalog.now() at time zone 'Europe/Zurich')::date;
 month_start date; first_day date; end_day date; cutoff date; season public.league_seasons_v21%rowtype;
 official boolean:=false; state text; title text; source text; page_size integer; page_offset integer;
 viewer uuid; items jsonb; podium jsonb; honors jsonb:='[]'::jsonb; mine jsonb; total integer; next_offset integer;
begin
 if p_kind not in ('month','season') or p_kind is null or p_key is null then
  raise exception 'Select month or season and an exact period key' using errcode='22023';end if;
 if p_limit is null or p_limit<1 or p_limit>50 or p_offset is null or p_offset<0 or p_offset>100000 then
  raise exception 'Invalid bounded archive page' using errcode='22023';end if;
 page_size:=p_limit;page_offset:=p_offset;
 if p_kind='month' then
  if p_key !~ '^[0-9]{4}-(0[1-9]|1[0-2])$' then raise exception 'Invalid YYYY-MM month key' using errcode='22023';end if;
  first_day:=(p_key||'-01')::date;month_start:=pg_catalog.date_trunc('month',today)::date;
  if first_day<date '2000-01-01' or first_day>month_start then raise exception 'Month outside available archive range' using errcode='22023';end if;
  end_day:=(first_day+interval '1 month')::date;
  state:=case when first_day=month_start then 'live' else 'reconstructed' end;
  title:=p_key;source:='current_ledger_reconstruction';
 else
  begin select * into season from public.league_seasons_v21 s where s.id=p_key::uuid and s.status in ('active','closed');
  exception when invalid_text_representation then raise exception 'Invalid season key' using errcode='22023';end;
  if season.id is null then raise exception 'Season not published or not found' using errcode='22023';end if;
  first_day:=season.starts_on;end_day:=season.ends_on+1;title:=season.title;official:=season.status='closed';
  state:=case when official then 'official' when season.ends_on<today then 'awaiting_close' else 'live' end;
  source:=case when official then 'season_snapshot' else 'current_ledger_reconstruction' end;
 end if;
 cutoff:=case when official then end_day else least(end_day,today+1) end;
 select p.id into viewer from public.profiles p where p.auth_user_id=(select auth.uid())
  and p.is_active and p.archived_at is null and p.role in ('boxer','coach');
 with rows as materialized(select * from league_archive_private.period_rows(p_kind,season.id,first_day,cutoff,official)),
 page as (select * from rows order by rank_position,id offset page_offset limit page_size),
 top as (select * from rows where rank_position<=3 and points>0 order by rank_position,id)
 select (select count(*)::integer from rows),
  coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'name',r.boxer_name,'rank',r.rank_position,'points',r.points,'exp',r.exp,'captured_at',r.captured_at) order by r.rank_position,r.id) from page r),'[]'::jsonb),
  coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'name',r.boxer_name,'rank',r.rank_position,'points',r.points) order by r.rank_position,r.id) from top r),'[]'::jsonb),
  (select jsonb_build_object('name',r.boxer_name,'rank',r.rank_position,'points',r.points,'exp',r.exp) from rows r where r.boxer_id=viewer)
 into total,items,podium,mine;
 next_offset:=case when page_offset+page_size<total then page_offset+page_size else null end;
 if official then
  select coalesce(jsonb_agg(jsonb_build_object('id',h.id,'name',h.boxer_name,'title',h.title,'description',h.description,'awarded_at',h.awarded_at) order by h.awarded_at,h.id),'[]'::jsonb)
  into honors from public.league_hall_of_fame_v21 h where h.season_id=season.id and league_archive_private.profile_visible(h.boxer_id);
 end if;
 return jsonb_build_object('version',1,'kind',p_kind,'key',p_key,'title',title,'starts_on',first_day,'ends_on',end_day-1,
  'timezone','Europe/Zurich','status',state,'source',source,'official',official,'rows',items,'top',podium,'honors',honors,
  'total',total,'next_offset',next_offset,'my_result',mine,'calculated_at',pg_catalog.now(),
  'reward',jsonb_build_object('status','not_configured','additional_payout',false),
  'ranking_rule',case when p_kind='month' then 'points_then_lifetime_exp_name_id_existing_monthly_rule' else 'saved_rank_or_points_then_period_exp' end);
end$fn$;
revoke all on function league_archive_private.period_core(text,text,integer,integer) from public,anon,authenticated;
grant execute on function league_archive_private.period_core(text,text,integer,integer) to anon,authenticated;

create or replace function public.league_archive_period(p_kind text,p_key text,p_limit integer default 20,p_offset integer default 0)
returns jsonb language sql stable security invoker set search_path='' as $fn$
 select league_archive_private.period_core(p_kind,p_key,p_limit,p_offset)
$fn$;
revoke all on function public.league_archive_period(text,text,integer,integer) from public,anon,authenticated;
grant execute on function public.league_archive_period(text,text,integer,integer) to anon,authenticated;
comment on function public.league_archive_period(text,text,integer,integer) is
 'Read-only period archive. Closed season snapshots; months reconstructed from current dated ledger. No payout or official monthly close.';
commit;
