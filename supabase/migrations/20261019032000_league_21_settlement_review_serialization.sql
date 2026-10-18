-- Release hardening: serialize review writes with global challenges, arenas and season snapshots.
-- Locks only qualifying training submissions before pending check and reward scoring.
create or replace function league_v21_private.global_close_core(p_challenge uuid)
returns jsonb language plpgsql volatile security definer set search_path='' as $func$
declare actor public.profiles%rowtype; c public.league_global_challenges_v21%rowtype; tally integer; participant record; reward integer; txn uuid;
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
 PERFORM 1 FROM public.training_submissions s
  JOIN public.league_global_entries_v21 e ON e.boxer_id=s.boxer_id AND e.challenge_id=c.id
  WHERE s.created_at BETWEEN e.joined_at AND c.ends_at
    AND s.training_date BETWEEN (c.starts_at AT TIME ZONE 'Europe/Zurich')::date
                            AND (c.ends_at AT TIME ZONE 'Europe/Zurich')::date
  ORDER BY s.id FOR UPDATE OF s;
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
 for participant in select r.boxer_id,r.completed,r.rank_position from public.league_global_results_v21 r
   where r.challenge_id=c.id order by r.boxer_id loop
  reward:=case when participant.completed
    then c.completion_exp+case when participant.rank_position=1 then c.winner_exp else 0 end
    else 0 end;
  if reward>0 then
   if exists(select 1 from public.point_transactions t where t.boxer_id=participant.boxer_id
     and t.category='challenge_exp' and t.description='Global challenge reward: '||c.id::text)
   then raise exception 'Orphaned global payout must be reviewed' using errcode='23514';end if;
   insert into public.point_transactions(boxer_id,submission_id,points,exp,category,description,effective_date,created_by)
   values(participant.boxer_id,null,0,reward,'challenge_exp',
    'Global challenge reward: '||c.id::text,(c.ends_at at time zone 'Europe/Zurich')::date,actor.id)
   returning id into txn;
   insert into public.league_global_exp_ledger_v21(challenge_id,boxer_id,transaction_id,exp_amount)
   values(c.id,participant.boxer_id,txn,reward);
  end if;
 end loop;
 update public.league_global_challenges_v21 set status='closed' where id=c.id;
 return pg_catalog.jsonb_build_object('status','closed','participants',tally,'rewards_paid',c.completion_exp>0 or c.winner_exp>0);
end$func$;

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
 PERFORM 1 FROM public.training_submissions s
   JOIN public.league_arena_members_v21 m ON m.boxer_id=s.boxer_id
    AND m.arena_id=d.id AND m.status='accepted'
  WHERE s.created_at<=d.ends_at AND
    s.training_date BETWEEN (d.starts_at AT TIME ZONE 'Europe/Zurich')::date
                       AND (d.ends_at AT TIME ZONE 'Europe/Zurich')::date
  ORDER BY s.id FOR UPDATE OF s;
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
  insert into public.league_season_results_v21(season_id,boxer_id,boxer_name,rank_position,points,exp)
  select season.id,p.id,p.display_name,
         rank() over(order by greatest(coalesce(sum(t.points),0),0) desc,
                               greatest(coalesce(sum(t.exp),0),0) desc)::integer,
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
end$f$;;
