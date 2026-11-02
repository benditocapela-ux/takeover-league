-- Bounded period notices and per-profile/per-phase acknowledgements.
-- No background closure, notifications, rewards, flags or historical backfill.
begin;
create table league_archive_private.period_notice_dismissals(
 profile_id uuid not null references public.profiles(id),event_key text not null,
 dismissed_at timestamptz not null default now(),primary key(profile_id,event_key));
revoke all on league_archive_private.period_notice_dismissals from public,anon,authenticated;
create function league_archive_private.notice_candidates()
returns table(kind text,period_key text,phase text,title text,ends_on date,event_key text,result_path text)
language sql stable security definer set search_path='' as $fn$
 with clock as(select (now() at time zone 'Europe/Zurich')::date today),
 month as(select to_char(date_trunc('month',today)-interval '1 month','YYYY-MM') key,(date_trunc('month',today)::date-1) ends from clock),
 candidates as(
  select 'month'::text kind,m.key,case when c.period_key is not null then 'closed' else 'awaiting_close' end phase,m.key title,m.ends
  from month m left join league_archive_private.period_closures c on c.kind='month' and c.period_key=m.key
  union all
  select 'season',s.id::text,case when s.status='closed' then 'closed' else 'awaiting_close' end,s.title,s.ends_on
  from (select s.* from public.league_seasons_v21 s,clock c where s.status in ('active','closed') and s.ends_on<c.today
   and (s.status='active' or s.ends_on>=c.today-31) order by s.ends_on desc,s.id limit 3) s
 ) select c.kind,c.key,c.phase,c.title,c.ends,'period:'||c.kind||':'||c.key||':'||c.phase,
  'league-history.html?'||c.kind||'='||c.key from candidates c order by c.ends desc,c.kind,c.key
$fn$;
revoke all on function league_archive_private.notice_candidates() from public,anon,authenticated;
create function public.league_period_notices()
returns jsonb language plpgsql stable security definer set search_path='' as $fn$
declare actor uuid;items jsonb;
begin
 select id into actor from public.profiles where auth_user_id=(select auth.uid()) and is_active and archived_at is null and role in ('boxer','coach','admin');
 if actor is null then raise exception 'Active profile required' using errcode='42501';end if;
 if not league_v21_private.notifications_enabled() then return jsonb_build_object('version',1,'enabled',false,'items','[]'::jsonb);end if;
 select coalesce(jsonb_agg(to_jsonb(n) order by n.ends_on desc,n.kind,n.period_key),'[]'::jsonb) into items
 from league_archive_private.notice_candidates() n
 where not exists(select 1 from league_archive_private.period_notice_dismissals d where d.profile_id=actor and d.event_key=n.event_key);
 return jsonb_build_object('version',1,'enabled',true,'items',items);
end$fn$;
revoke all on function public.league_period_notices() from public,anon,authenticated;
grant execute on function public.league_period_notices() to authenticated;
create function public.league_period_notice_dismiss(p_event_key text)
returns boolean language plpgsql security definer set search_path='' as $fn$
declare actor uuid;
begin
 select id into actor from public.profiles where auth_user_id=(select auth.uid()) and is_active and archived_at is null and role in ('boxer','coach','admin');
 if actor is null then raise exception 'Active profile required' using errcode='42501';end if;
 if not league_v21_private.notifications_enabled() then raise exception 'Notifications disabled' using errcode='42501';end if;
 if not exists(select 1 from league_archive_private.notice_candidates() where event_key=p_event_key) then raise exception 'Unknown current period notice' using errcode='22023';end if;
 insert into league_archive_private.period_notice_dismissals(profile_id,event_key) values(actor,p_event_key) on conflict do nothing;
 -- Same recipient/event as the existing inbox; preserve a previously read time.
 update public.boxer_notifications set read_at=coalesce(read_at,now()) where recipient_id=actor and event_key=p_event_key;
 return true;
end$fn$;
revoke all on function public.league_period_notice_dismiss(text) from public,anon,authenticated;
grant execute on function public.league_period_notice_dismiss(text) to authenticated;
notify pgrst,'reload schema';
commit;
