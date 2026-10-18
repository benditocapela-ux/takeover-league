-- Fair ties and pending training review gate. Existing TEST-only initial migration stays additive.
-- Multiple boxers with identical progress share a place; no arbitrary UUID tie-break.
alter table public.league_global_results_v21
 drop constraint if exists league_global_results_v21_challenge_id_rank_position_key;
create or replace function league_v21_private.global_close_core(p_challenge uuid)
returns jsonb language plpgsql volatile security definer set search_path='' as $func$
declare actor public.profiles%rowtype; c public.league_global_challenges_v21%rowtype; tally integer;
begin
 select * into actor from public.profiles p where p.auth_user_id=(select auth.uid()) and p.is_active and p.role='admin';
 if not found then raise exception 'Admin only' using errcode='42501';end if;
 select * into c from public.league_global_challenges_v21 x where x.id=p_challenge for update;
 if not found then raise exception 'Challenge not found' using errcode='22023';end if;
 if c.status='closed' then
  return pg_catalog.jsonb_build_object('status','closed','unchanged',true);
 end if;
 if c.status<>'active' or c.ends_at>now() then
  raise exception 'Only elapsed active challenge may close' using errcode='22023';end if;
 -- Hold settlement until all timely entries are reviewed.
 if exists(select 1 from public.training_submissions s
   join public.league_global_entries_v21 e on e.boxer_id=s.boxer_id and e.challenge_id=c.id
   where s.status='pending' and s.created_at between e.joined_at and c.ends_at
     and s.training_date between (c.starts_at at time zone 'Europe/Zurich')::date
                            and (c.ends_at at time zone 'Europe/Zurich')::date)
 then raise exception 'Pending trainings must be reviewed before settlement' using errcode='23514';end if;
 if exists(select 1 from public.league_global_results_v21 x where x.challenge_id=p_challenge)
 then raise exception 'Existing results require review' using errcode='23505';end if;
 with scores as (
  select e.boxer_id,p.display_name as boxer_name,
   case c.metric
    when 'training_sessions' then count(t.id)::numeric
    when 'jogging_km' then coalesce(sum(t.jogging_km),0)
    when 'technique_minutes' then coalesce(sum(t.technique_minutes),0)
    else 0 end as progress
  from public.league_global_entries_v21 e
  join public.profiles p on p.id=e.boxer_id
  left join public.training_submissions t on t.boxer_id=e.boxer_id
    and t.status='approved' and t.created_at>=e.joined_at
    and t.created_at<=c.ends_at
    and t.training_date between (c.starts_at at time zone 'Europe/Zurich')::date
                            and (c.ends_at at time zone 'Europe/Zurich')::date
  where e.challenge_id=c.id
  group by e.boxer_id,p.display_name
 ),ordered as (
  select boxer_id,boxer_name,progress,
   rank() over(order by progress desc)::integer as rank_position
  from scores
 )
 insert into public.league_global_results_v21(challenge_id,boxer_id,boxer_name,progress,rank_position,completed)
 select c.id,boxer_id,boxer_name,progress,rank_position,progress>=c.target_value from ordered;
 get diagnostics tally=row_count;
 update public.league_global_challenges_v21 set status='closed' where id=c.id;
 return pg_catalog.jsonb_build_object('status','closed','participants',tally,'rewards_paid',false);
end$func$;
