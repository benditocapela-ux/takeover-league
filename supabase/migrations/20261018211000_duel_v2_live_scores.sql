-- Takeover League 2.0 - authenticated, participant-limited live duel score.
-- Security hardening: SECURITY DEFINER logic lives ONLY in an unexposed schema.
-- public API is a SECURITY INVOKER wrapper. Owner and participant checks remain in core.
create schema if not exists league_duel_private;
revoke all on schema league_duel_private from public, anon, authenticated;
grant usage on schema league_duel_private to authenticated;

-- Previously blocked in production; this hardened version is TEST-ONLY until an authorized security review clears it.
create or replace function league_duel_private.duel_v2_live_scores_core(p_duel_id uuid)
returns jsonb language plpgsql stable security definer set search_path = ''
as $function$
declare
 actor public.profiles%rowtype;
 duel public.league_duels%rowtype;
 p1 integer; p2 integer; awaiting integer;
 start_day date; end_day date;
begin
 select * into actor from public.profiles p
 where p.auth_user_id=(select auth.uid()) and p.is_active is true
 and p.role in ('boxer','admin','coach');
 if not found then raise exception 'Authentication required' using errcode='42501'; end if;
 if not exists(select 1 from public.league_feature_flags where feature_key='duels' and is_enabled=true)
 then raise exception 'Duels are not enabled' using errcode='42501'; end if;
 select * into duel from public.league_duels d where d.id=p_duel_id;
 if not found then raise exception 'Duel not found' using errcode='22023'; end if;
 if actor.role='boxer' and actor.id not in (duel.challenger_id,duel.opponent_id)
 then raise exception 'Not a duel participant' using errcode='42501'; end if;
 if duel.status not in ('active','awaiting_reviews') or duel.accepted_at is null or duel.ends_at is null
 then raise exception 'No live score for this duel' using errcode='22023'; end if;
 start_day=(duel.accepted_at at time zone 'Europe/Zurich')::date;
 end_day=least((duel.ends_at at time zone 'Europe/Zurich')::date, (now() at time zone 'Europe/Zurich')::date);

 if exists(
  select 1 from public.training_submissions s join public.point_transactions t
   on t.submission_id=s.id and t.boxer_id=s.boxer_id
  where s.boxer_id in (duel.challenger_id,duel.opponent_id)
   and s.status='approved' and s.created_at<=least(now(),duel.ends_at)
   and s.training_date between start_day and end_day
   and t.category in ('training','legacy_import')
  group by s.id having count(*)>1
 ) then
   raise exception 'Duplicate scoring transactions require review' using errcode='22023';
 end if;

 select coalesce(sum(t.points) filter(where s.boxer_id=duel.challenger_id),0)::integer,
        coalesce(sum(t.points) filter(where s.boxer_id=duel.opponent_id),0)::integer
 into p1,p2
 from public.training_submissions s join public.point_transactions t
  on t.submission_id=s.id and t.boxer_id=s.boxer_id
 where s.boxer_id in (duel.challenger_id,duel.opponent_id)
  and s.status='approved' and s.created_at<=least(now(),duel.ends_at)
  and s.training_date between start_day and end_day
  and t.category in ('training','legacy_import');
 if p1<0 or p2<0 then raise exception 'Negative duel scores' using errcode='22023'; end if;
 select count(*) into awaiting from public.training_submissions s
 where s.boxer_id in (duel.challenger_id,duel.opponent_id)
  and s.status='pending' and s.created_at<=least(now(),duel.ends_at)
  and s.training_date between start_day and end_day;
 return pg_catalog.jsonb_build_object(
  'challenger_score',p1,'opponent_score',p2,'pending',awaiting,
  'status',duel.status,'provisional',true);
end;
$function$;
revoke all on function league_duel_private.duel_v2_live_scores_core(uuid) from public,anon,authenticated;
grant execute on function league_duel_private.duel_v2_live_scores_core(uuid) to authenticated;

-- Public wrapper runs as caller and returns only the validated, compact aggregate.
create or replace function public.duel_v2_live_scores(p_duel_id uuid)
returns jsonb language sql stable security invoker set search_path = ''
as $api$
  select league_duel_private.duel_v2_live_scores_core(p_duel_id);
$api$;
revoke all on function public.duel_v2_live_scores(uuid) from public,anon,authenticated;
grant execute on function public.duel_v2_live_scores(uuid) to authenticated;

