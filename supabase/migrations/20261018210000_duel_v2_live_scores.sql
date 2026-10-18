-- Takeover League 2.0: current approved duel training scores, without awards.
-- This exposes only participants' aggregate scores to participants and coaches.
-- Stage on TEST; do not apply to production before backup/release authorization.
create or replace function public.duel_v2_live_scores(p_duel_id uuid)
returns jsonb language plpgsql stable security definer set search_path = ''
as $fn$
declare v_actor public.profiles%rowtype;
        d public.league_duels%rowtype;
        v_at timestamptz:=pg_catalog.clock_timestamp();
        v_cutoff date;
        v_challenger integer:=0;
        v_opponent integer:=0;
        v_pending integer:=0;
begin
 if (select auth.uid()) is null then
   raise exception 'Authentication required' using errcode='28000';end if;
 select * into v_actor from public.profiles
 where auth_user_id=(select auth.uid()) and is_active=true and role in ('boxer','coach','admin');
 if v_actor.id is null then raise exception 'Active profile required' using errcode='42501';end if;
 if not exists(select 1 from public.league_feature_flags where feature_key='duels' and is_enabled=true)
 then raise exception 'Duels not available' using errcode='42501';end if;
 select * into d from public.league_duels where id=p_duel_id;
 if d.id is null then raise exception 'Duel not found' using errcode='22023';end if;
 if v_actor.role not in ('coach','admin')
    and v_actor.id not in (d.challenger_id,d.opponent_id)
 then raise exception 'Private duel' using errcode='42501';end if;
 if d.status not in ('active','awaiting_reviews','settled') or d.accepted_at is null or d.ends_at is null
 then raise exception 'No active duel progress' using errcode='22023';end if;
 if d.status='settled' then
  return pg_catalog.jsonb_build_object('duel_id',d.id,'challenger_score',d.challenger_score,
     'opponent_score',d.opponent_score,'pending',0,'as_of',v_at,'final',true);
 end if;
 v_cutoff:=(least(v_at,d.ends_at) at time zone 'Europe/Zurich')::date;
 if exists(
    select 1 from public.training_submissions s
    join public.point_transactions t on t.submission_id=s.id and t.boxer_id=s.boxer_id
    where s.boxer_id in (d.challenger_id,d.opponent_id)
      and s.status='approved' and s.created_at<=least(v_at,d.ends_at)
      and s.training_date between (d.accepted_at at time zone 'Europe/Zurich')::date and v_cutoff
      and t.category in ('training','legacy_import')
    group by s.id having count(*)>1
 ) then raise exception 'Duplicate scoring requires review' using errcode='22023';end if;
 select coalesce(sum(t.points) filter(where s.boxer_id=d.challenger_id),0)::integer,
        coalesce(sum(t.points) filter(where s.boxer_id=d.opponent_id),0)::integer
 into v_challenger,v_opponent
 from public.training_submissions s
 join public.point_transactions t on t.submission_id=s.id and t.boxer_id=s.boxer_id
 where s.boxer_id in (d.challenger_id,d.opponent_id) and s.status='approved'
   and s.created_at<=least(v_at,d.ends_at)
   and s.training_date between (d.accepted_at at time zone 'Europe/Zurich')::date and v_cutoff
   and t.category in ('training','legacy_import');
 select count(*) into v_pending from public.training_submissions s
 where s.boxer_id in (d.challenger_id,d.opponent_id) and s.status='pending'
   and s.created_at<=least(v_at,d.ends_at)
   and s.training_date between (d.accepted_at at time zone 'Europe/Zurich')::date and v_cutoff;
 return pg_catalog.jsonb_build_object('duel_id',d.id,'challenger_score',v_challenger,
    'opponent_score',v_opponent,'pending',v_pending,'as_of',v_at,'final',false);
end
$fn$;
revoke all on function public.duel_v2_live_scores(uuid) from public,anon;
grant execute on function public.duel_v2_live_scores(uuid) to authenticated;
