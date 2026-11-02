-- Explicit authorized rollback only, before any official close through the new API.
-- Once snapshots exist, this deliberately refuses destructive rollback: keep data,
-- roll back the frontend if needed, and prepare a reviewed forward repair instead.
begin;
do $$begin
 if exists(select 1 from league_archive_private.period_closures) or exists(select 1 from league_archive_private.month_results)
 then raise exception 'Official period records exist: destructive rollback forbidden' using errcode='55000';end if;
end$$;
CREATE OR REPLACE FUNCTION league_v21_private.season_transition_core(p_season uuid, p_action text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
declare actor public.profiles%rowtype;season public.league_seasons_v21%rowtype;n integer;
 next_start date;next_end date;next_title text;next_id uuid;suffix integer:=1;
begin
 select * into actor from public.profiles p where p.auth_user_id=(select auth.uid()) and p.is_active and p.role='admin';
 if not found then raise exception 'Only active admin' using errcode='42501';end if;
 select * into season from public.league_seasons_v21 s where s.id=p_season for update;
 if not found then raise exception 'Season not found' using errcode='22023';end if;
 if p_action='activate' then
  if season.status<>'draft' then raise exception 'Only draft seasons may be activated' using errcode='22023';end if;
  -- Nie zwei aktive Saisons gleichzeitig (vorher nur im Frontend verhindert).
  perform pg_catalog.pg_advisory_xact_lock(94712031);
  if exists(select 1 from public.league_seasons_v21 s where s.status='active' and s.id<>season.id) then
   raise exception 'Another season is already active' using errcode='23505';end if;
  update public.league_seasons_v21 set status='active' where id=season.id;
  return pg_catalog.jsonb_build_object('status','active');
 elsif p_action='close' then
  if season.status='closed' then
   return pg_catalog.jsonb_build_object('status','closed','unchanged',true);
  end if;
  if season.status<>'active' or season.ends_on>=current_date then
   raise exception 'Only elapsed active seasons may close' using errcode='22023';end if;
  -- An unreviewed timely training might still change points and ranks.
  -- Block finalization until all season trainings are reviewed.
  PERFORM 1 FROM public.training_submissions t
   JOIN public.profiles p ON p.id=t.boxer_id AND p.role='boxer'
   WHERE t.training_date BETWEEN season.starts_on AND season.ends_on
   ORDER BY t.id FOR UPDATE OF t;
  if exists(select 1 from public.training_submissions t
    where t.status='pending' and t.training_date between season.starts_on and season.ends_on
    and exists(select 1 from public.profiles p where p.id=t.boxer_id and p.role='boxer'))
  then raise exception 'Pending season trainings require coach review' using errcode='23514';end if;
  if exists(select 1 from public.league_season_results_v21 r where r.season_id=season.id)
  then raise exception 'Unexpected existing season snapshot' using errcode='23505';end if;
  -- Public snapshot: only boxers that are public right now (same rule as the leaderboard).
  insert into public.league_season_results_v21(season_id,boxer_id,boxer_name,rank_position,points,exp)
  select season.id,p.id,p.display_name,
         rank() over(order by greatest(coalesce(sum(t.points),0),0) desc,
                               greatest(coalesce(sum(t.exp),0),0) desc)::integer,
         greatest(coalesce(sum(t.points),0),0)::integer,
         greatest(coalesce(sum(t.exp),0),0)::integer
  from public.profiles p
  left join public.point_transactions t on t.boxer_id=p.id
    and t.effective_date between season.starts_on and season.ends_on
  where p.role='boxer' and p.is_active is true and p.is_listed is true and p.archived_at is null
  group by p.id,p.display_name;
  get diagnostics n=row_count;
  -- Titles only for real season performance (no title for 0 points, even on a tie).
  insert into public.league_hall_of_fame_v21(boxer_id,boxer_name,season_id,title,description)
  select r.boxer_id,r.boxer_name,season.id,
   case r.rank_position when 1 then 'Saisonmeister' when 2 then 'Vizechampion' else 'Saisonpodium' end,
   season.title||' · Platz '||r.rank_position
  from public.league_season_results_v21 r
  where r.season_id=season.id and r.rank_position<=3 and r.points>0
  on conflict(boxer_id,season_id,title) do nothing;
  update public.league_seasons_v21 set status='closed' where id=season.id;
  if league_v21_private.notifications_enabled() then
   insert into public.boxer_notifications(recipient_id,notification_type,title,message,target_path)
   select r.boxer_id,'season',
    pg_catalog.left('Saison «'||season.title||'» beendet: Platz '||r.rank_position,160),
    case when r.rank_position=1 and r.points>0 then 'Gratulation, du bist Saisonmeister! '
         when r.rank_position<=3 and r.points>0 then 'Gratulation, du stehst auf dem Saisonpodium! '
         else '' end||r.points||' Punkte in dieser Saison.',
    '/league-history.html'
   from public.league_season_results_v21 r where r.season_id=season.id;
  end if;
  -- Folgesaison automatisch als Entwurf vorbereiten (gleiche Länge, direkt anschliessend),
  -- sofern noch keine spätere Saison angelegt ist. Aktivieren bleibt ein bewusster Admin-Schritt.
  next_start:=season.ends_on+1;
  next_end:=next_start+(season.ends_on-season.starts_on);
  if not exists(select 1 from public.league_seasons_v21 s where s.id<>season.id and s.ends_on>=next_start) then
   next_title:=(case when extract(month from next_end) in (12,1,2) then 'Winter'
                     when extract(month from next_end) in (3,4,5) then 'Frühling'
                     when extract(month from next_end) in (6,7,8) then 'Sommer' else 'Herbst' end)
               ||' '||extract(year from next_end)::integer;
   while exists(select 1 from public.league_seasons_v21 s where s.title=next_title||case when suffix>1 then ' ('||suffix||')' else '' end) loop
    suffix:=suffix+1;
   end loop;
   if suffix>1 then next_title:=next_title||' ('||suffix||')';end if;
   insert into public.league_seasons_v21(title,starts_on,ends_on,status)
   values(next_title,next_start,next_end,'draft') returning id into next_id;
  end if;
  return pg_catalog.jsonb_build_object('status','closed','ranked_boxers',n,
   'next_draft',case when next_id is null then null else pg_catalog.jsonb_build_object('id',next_id,'title',next_title,'starts_on',next_start,'ends_on',next_end) end);
 end if;
 raise exception 'Invalid season action' using errcode='22023';
end$function$;


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


drop function public.league_period_close_confirm(text,text,boolean,text);
drop function public.league_period_close_preview(text,text);
drop function league_archive_private.close_preview_core(text,text);
drop table league_archive_private.month_results;
drop table league_archive_private.period_closures;
drop function league_archive_private.prevent_snapshot_change();
notify pgrst,'reload schema';
commit;