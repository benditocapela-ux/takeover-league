-- Result-only month/season closure. No bonuses, backfill, flags or production close.
-- Requires 20261102090410 archive readers and 20261102093606 event identity.
begin;
create table league_archive_private.period_closures(
 kind text not null check(kind in ('month','season')), period_key text not null,
 closed_at timestamptz not null default clock_timestamp(), closed_by uuid not null references public.profiles(id),
 revision text not null, ranked_count integer not null, notification_count integer not null,
 reward_status text not null default 'not_configured' check(reward_status='not_configured'),
 primary key(kind,period_key));
create table league_archive_private.month_results(
 id uuid primary key default gen_random_uuid(),month_key text not null,
 boxer_id uuid not null references public.profiles(id),boxer_name text not null,
 rank_position bigint not null check(rank_position>0),points bigint not null,exp bigint not null,
 captured_at timestamptz not null default clock_timestamp(),unique(month_key,boxer_id));
revoke all on league_archive_private.period_closures,league_archive_private.month_results from public,anon,authenticated;
create function league_archive_private.prevent_snapshot_change() returns trigger
language plpgsql set search_path='' as $$begin raise exception 'Official period snapshots are immutable' using errcode='55000';end$$;
revoke all on function league_archive_private.prevent_snapshot_change() from public,anon,authenticated;
create trigger period_closures_immutable before update or delete on league_archive_private.period_closures
 for each row execute function league_archive_private.prevent_snapshot_change();
create trigger month_results_immutable before update or delete on league_archive_private.month_results
 for each row execute function league_archive_private.prevent_snapshot_change();

create function league_archive_private.close_preview_core(p_kind text,p_key text)
returns jsonb language plpgsql stable security definer set search_path='' as $fn$
declare actor public.profiles%rowtype; season public.league_seasons_v21%rowtype;
 today date:=(statement_timestamp() at time zone 'Europe/Zurich')::date;first_day date;end_day date;
 payload jsonb;results jsonb;training_state jsonb;ledger_state text;blockers jsonb:='[]';
 official boolean;title text;pending integer;approved integer;rejected integer;missing integer;duplicates integer;invalid integer;
begin
 select * into actor from public.profiles p where p.auth_user_id=(select auth.uid())
  and p.is_active and p.archived_at is null and p.role in ('coach','admin');
 if not found then raise exception 'Active coach or admin required' using errcode='42501';end if;
 if p_kind is null or p_kind not in ('month','season') or p_key is null then raise exception 'Exact period required' using errcode='22023';end if;
 if p_kind='month' then
  if p_key !~ '^[0-9]{4}-(0[1-9]|1[0-2])$' then raise exception 'Invalid month key' using errcode='22023';end if;
  first_day:=(p_key||'-01')::date;end_day:=(first_day+interval '1 month')::date;title:=p_key;
  if first_day<date '2000-01-01' or first_day>date_trunc('month',today)::date then raise exception 'Month outside available range' using errcode='22023';end if;
  official:=exists(select 1 from league_archive_private.period_closures where kind=p_kind and period_key=p_key);
 else
  begin select * into season from public.league_seasons_v21 where id=p_key::uuid;
  exception when invalid_text_representation then raise exception 'Invalid season key' using errcode='22023';end;
  if season.id is null or season.status not in ('active','closed') then raise exception 'Only active or closed seasons' using errcode='22023';end if;
  first_day:=season.starts_on;end_day:=season.ends_on+1;title:=season.title;official:=season.status='closed';
 end if;
 select coalesce(jsonb_agg(to_jsonb(r) order by r.rank_position,r.id),'[]'::jsonb) into results
 from league_archive_private.period_rows(p_kind,season.id,first_day,end_day,official) r;
 with relevant as materialized(
  select t.id,t.boxer_id,t.status,t.training_date,t.created_at from public.training_submissions t
  join public.profiles p on p.id=t.boxer_id
  where t.training_date>=first_day and t.training_date<end_day
   and (p.role='boxer' or (p_kind='month' and p.role='coach'))
 ), scored as(
  select r.id,count(t.id) n from relevant r left join public.point_transactions t
   on t.submission_id=r.id and t.boxer_id=r.boxer_id and t.category in ('training','legacy_import')
    and t.effective_date=r.training_date
  where r.status='approved' group by r.id
 )
 select (select count(*) from relevant where status='pending'),(select count(*) from relevant where status='approved'),
  (select count(*) from relevant where status='rejected'),(select count(*) from scored where n=0),(select count(*) from scored where n>1),
  (select coalesce(jsonb_agg(to_jsonb(r) order by r.id),'[]'::jsonb) from relevant r)
 into pending,approved,rejected,missing,duplicates,training_state;
 select count(*) into invalid from public.point_transactions t join public.training_submissions s on s.id=t.submission_id
 where t.effective_date>=first_day and t.effective_date<end_day and t.category in ('training','legacy_import')
  and (s.status<>'approved' or s.boxer_id<>t.boxer_id or s.training_date<>t.effective_date);
 select md5(coalesce(jsonb_agg(to_jsonb(t) order by t.id)::text,'[]')) into ledger_state
 from public.point_transactions t where t.effective_date>=first_day and t.effective_date<end_day;
 if not official then
  if end_day>today then blockers:=blockers||jsonb_build_array(jsonb_build_object('code','in_progress','message','Der Zeitraum läuft noch.'));end if;
  if pending>0 then blockers:=blockers||jsonb_build_array(jsonb_build_object('code','pending_reviews','message','Offene Trainings müssen zuerst geprüft werden.'));end if;
  if missing>0 or duplicates>0 or invalid>0 then blockers:=blockers||jsonb_build_array(jsonb_build_object('code','ledger_invalid','message','Fehlende, doppelte oder widersprüchliche Trainingsbuchungen müssen geprüft werden.'));end if;
 end if;
 payload:=jsonb_build_object('version',1,'kind',p_kind,'key',p_key,'title',title,'starts_on',first_day,'ends_on',end_day-1,
  'timezone','Europe/Zurich','status',case when official then 'closed' when end_day>today then 'running' else 'awaiting_close' end,
  'can_close',not official and blockers='[]'::jsonb,'blockers',blockers,
  'trainings',jsonb_build_object('pending',pending,'approved',approved,'rejected',rejected,'missing_ledger',missing,'duplicate_ledger',duplicates,'invalid_ledger',invalid),
  'ranked_count',jsonb_array_length(results),'rows',coalesce((select jsonb_agg(r) from (select value r from jsonb_array_elements(results) limit 20) q),'[]'::jsonb),
  'reward',jsonb_build_object('status','not_configured','additional_payout',false,'planned_bookings','[]'::jsonb),
  'honors',case when p_kind='season' then 'existing_positive_top3_season_titles' else 'not_configured' end,
  'result_path','league-history.html?'||p_kind||'='||p_key,'review_path','coach.html',
  'notifications_enabled',league_v21_private.notifications_enabled());
 return payload||jsonb_build_object('revision',md5(payload::text||results::text||training_state::text||ledger_state), '_snapshot_rows',results);
end$fn$;
revoke all on function league_archive_private.close_preview_core(text,text) from public,anon,authenticated;
create function public.league_period_close_preview(p_kind text,p_key text)
returns jsonb language sql stable security definer set search_path='' as $$
 select league_archive_private.close_preview_core(p_kind,p_key)-'_snapshot_rows'
$$;
revoke all on function public.league_period_close_preview(text,text) from public,anon,authenticated;
grant execute on function public.league_period_close_preview(text,text) to authenticated;

create function public.league_period_close_confirm(p_kind text,p_key text,p_confirm boolean,p_revision text)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare actor public.profiles%rowtype;preview jsonb;season public.league_seasons_v21%rowtype;existing league_archive_private.period_closures%rowtype;
 first_day date;end_day date;n integer;notices integer:=0;next_start date;next_end date;next_title text;next_id uuid;suffix integer:=1;
begin
 select * into actor from public.profiles p where p.auth_user_id=(select auth.uid())
  and p.is_active and p.archived_at is null and p.role in ('coach','admin');
 if not found then raise exception 'Active coach or admin required' using errcode='42501';end if;
 if p_confirm is distinct from true or p_revision is null or p_revision !~ '^[0-9a-f]{32}$' then raise exception 'Explicit confirmation and preview revision required' using errcode='22023';end if;
 -- One lock namespace for a precise period. Two staff/tabs cannot both finalize it.
 perform pg_advisory_xact_lock(hashtextextended('league-period:'||coalesce(p_kind,'')||':'||coalesce(p_key,''),0));
 select * into existing from league_archive_private.period_closures where kind=p_kind and period_key=p_key;
 if found then return jsonb_build_object('status','closed','unchanged',true,'kind',p_kind,'key',p_key,'ranked_count',existing.ranked_count,
  'closed_at',existing.closed_at,'notification_count',existing.notification_count,'additional_payout',false,'bookings','[]'::jsonb,'result_path','league-history.html?'||p_kind||'='||p_key);end if;
 preview:=league_archive_private.close_preview_core(p_kind,p_key);
 if preview->>'status'='closed' then return jsonb_build_object('status','closed','unchanged',true,'kind',p_kind,'key',p_key,'additional_payout',false,'bookings','[]'::jsonb,'result_path',preview->>'result_path');end if;
 first_day:=(preview->>'starts_on')::date;end_day:=(preview->>'ends_on')::date+1;
 if p_kind='season' then select * into season from public.league_seasons_v21 where id=p_key::uuid for update;end if;
 -- Approval functions lock their training row before booking. Wait, then recompute;
 -- new data after this consistent snapshot cannot rewrite an official result.
 perform 1 from public.training_submissions t join public.profiles p on p.id=t.boxer_id
 where t.training_date>=first_day and t.training_date<end_day and (p.role='boxer' or (p_kind='month' and p.role='coach'))
 order by t.id for update of t;
 preview:=league_archive_private.close_preview_core(p_kind,p_key);
 if preview->>'revision' is distinct from p_revision then return jsonb_build_object('status','changed','preview',preview-'_snapshot_rows');end if;
 if not (preview->>'can_close')::boolean then return jsonb_build_object('status','blocked','preview',preview-'_snapshot_rows');end if;
 n:=(preview->>'ranked_count')::integer;
 if p_kind='month' then
  insert into league_archive_private.month_results(month_key,boxer_id,boxer_name,rank_position,points,exp)
  select p_key,r.boxer_id,r.boxer_name,r.rank_position,r.points,r.exp
  from jsonb_to_recordset(preview->'_snapshot_rows') r(boxer_id uuid,boxer_name text,rank_position bigint,points bigint,exp bigint);
 else
  if exists(select 1 from public.league_season_results_v21 where season_id=season.id) then raise exception 'Unexpected existing season snapshot' using errcode='23505';end if;
  insert into public.league_season_results_v21(season_id,boxer_id,boxer_name,rank_position,points,exp)
  select season.id,r.boxer_id,r.boxer_name,r.rank_position::integer,r.points::integer,r.exp::integer
  from jsonb_to_recordset(preview->'_snapshot_rows') r(boxer_id uuid,boxer_name text,rank_position bigint,points bigint,exp bigint);
  insert into public.league_hall_of_fame_v21(boxer_id,boxer_name,season_id,title,description)
  select r.boxer_id,r.boxer_name,season.id,case r.rank_position when 1 then 'Saisonmeister' when 2 then 'Vizechampion' else 'Saisonpodium' end,
   season.title||' · Platz '||r.rank_position from public.league_season_results_v21 r
   where r.season_id=season.id and r.rank_position<=3 and r.points>0 on conflict(boxer_id,season_id,title) do nothing;
  update public.league_seasons_v21 set status='closed' where id=season.id;
  -- Preserve existing next-draft behavior; activation remains admin-only.
  perform pg_advisory_xact_lock(94712031);
  next_start:=season.ends_on+1;next_end:=next_start+(season.ends_on-season.starts_on);
  if not exists(select 1 from public.league_seasons_v21 s where s.id<>season.id and s.ends_on>=next_start) then
   next_title:=(case when extract(month from next_end) in (12,1,2) then 'Winter' when extract(month from next_end) in (3,4,5) then 'Frühling'
    when extract(month from next_end) in (6,7,8) then 'Sommer' else 'Herbst' end)||' '||extract(year from next_end)::integer;
   while exists(select 1 from public.league_seasons_v21 s where s.title=next_title||case when suffix>1 then ' ('||suffix||')' else '' end) loop suffix:=suffix+1;end loop;
   if suffix>1 then next_title:=next_title||' ('||suffix||')';end if;
   insert into public.league_seasons_v21(title,starts_on,ends_on,status) values(next_title,next_start,next_end,'draft') returning id into next_id;
  end if;
 end if;
 if league_v21_private.notifications_enabled() then
  insert into public.boxer_notifications(recipient_id,notification_type,title,message,target_path,event_key)
  select r.boxer_id,'season',left(case when p_kind='month' then 'Monat ' else 'Saison ' end||(preview->>'title')||' abgeschlossen',160),
   'Ergebnis gespeichert: Platz '||r.rank_position||' · '||r.points||' Punkte. Keine zusätzliche Abschlussprämie.',
   '/'||(preview->>'result_path'),'period:'||p_kind||':'||p_key||':closed'
  from jsonb_to_recordset(preview->'_snapshot_rows') r(boxer_id uuid,rank_position bigint,points bigint)
  on conflict(recipient_id,event_key) where event_key is not null do nothing;
  get diagnostics notices=row_count;
 end if;
 insert into league_archive_private.period_closures(kind,period_key,closed_by,revision,ranked_count,notification_count)
 values(p_kind,p_key,actor.id,p_revision,n,notices);
 return jsonb_build_object('status','closed','kind',p_kind,'key',p_key,'ranked_count',n,'notification_count',notices,
  'additional_payout',false,'bookings','[]'::jsonb,'honors',preview->'honors',
  'honor_count',case when p_kind='season' then (select count(*) from public.league_hall_of_fame_v21 where season_id=season.id) else 0 end,
  'next_draft_id',next_id,'result_path',preview->>'result_path');
end$fn$;
revoke all on function public.league_period_close_confirm(text,text,boolean,text) from public,anon,authenticated;
grant execute on function public.league_period_close_confirm(text,text,boolean,text) to authenticated;

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
 where p_official and p_kind='season' and r.season_id=p_season and p.is_active and p.is_listed and p.archived_at is null and p.role in ('boxer','coach')
 union all
 select r.id,r.boxer_id,r.boxer_name,r.rank_position,r.points,r.exp,r.captured_at
 from league_archive_private.month_results r
 where p_official and p_kind='month' and r.month_key=to_char(p_start,'YYYY-MM')
  and league_archive_private.profile_visible(r.boxer_id)
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
   official:=exists(select 1 from league_archive_private.period_closures where kind='month' and period_key=p_key);
  state:=case when official then 'official' when first_day=month_start then 'live' else 'reconstructed' end;
  title:=p_key;source:=case when official then 'month_snapshot' else 'current_ledger_reconstruction' end;
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
 if official and p_kind='season' then
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


-- Existing admin transition stays admin-only. Its explicit close action uses the
-- same contract; activation/configuration are not granted to coaches.
create or replace function league_v21_private.season_transition_core(p_season uuid,p_action text)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare actor public.profiles%rowtype;s public.league_seasons_v21%rowtype;p jsonb;r jsonb;next_draft jsonb;
begin
 select * into actor from public.profiles where auth_user_id=(select auth.uid()) and is_active
  and archived_at is null and role='admin';
 if not found then raise exception 'Only active admin' using errcode='42501';end if;
 if p_action='close' then
  p:=public.league_period_close_preview('season',p_season::text);
  r:=public.league_period_close_confirm('season',p_season::text,true,p->>'revision');
  select jsonb_build_object('id',id,'title',title,'starts_on',starts_on,'ends_on',ends_on) into next_draft
   from public.league_seasons_v21 where id=(r->>'next_draft_id')::uuid;
  return r||jsonb_build_object('ranked_boxers',r->'ranked_count','next_draft',next_draft);
 elsif p_action='activate' then
  select * into s from public.league_seasons_v21 where id=p_season for update;
  if not found or s.status<>'draft' then raise exception 'Only draft seasons may be activated' using errcode='22023';end if;
  perform pg_advisory_xact_lock(94712031);
  if exists(select 1 from public.league_seasons_v21 where status='active' and id<>s.id) then raise exception 'Another season is already active' using errcode='23505';end if;
  update public.league_seasons_v21 set status='active' where id=s.id;
  return jsonb_build_object('status','active');
 end if;
 raise exception 'Invalid season action' using errcode='22023';
end$fn$;
notify pgrst,'reload schema';
commit;
