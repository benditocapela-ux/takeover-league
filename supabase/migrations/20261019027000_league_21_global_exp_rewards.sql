-- Admin-configured, default-zero single-transaction challenge EXP; paid only after reviewed settlement.
alter table public.league_global_challenges_v21
 add column if not exists completion_exp integer not null default 0 check(completion_exp between 0 and 250);
alter table public.league_global_challenges_v21
 add column if not exists winner_exp integer not null default 0 check(winner_exp between 0 and 250);
create table if not exists public.league_global_exp_ledger_v21(
 challenge_id uuid not null references public.league_global_challenges_v21(id) on delete restrict,
 boxer_id uuid not null references public.profiles(id) on delete restrict,
 transaction_id uuid not null unique references public.point_transactions(id) on delete restrict,
 exp_amount integer not null check(exp_amount between 1 and 500),
 primary key(challenge_id,boxer_id)
);
alter table public.league_global_exp_ledger_v21 enable row level security;
revoke all on public.league_global_exp_ledger_v21 from public,anon,authenticated;
create or replace function league_v21_private.global_reward_set_core(p_challenge uuid,p_completion integer,p_winner integer)
returns jsonb language plpgsql security definer set search_path='' as $f$
declare actor public.profiles%rowtype; c public.league_global_challenges_v21%rowtype;
begin
 select * into actor from public.profiles p where p.auth_user_id=(select auth.uid()) and p.is_active and p.role='admin';
 if not found then raise exception 'Admin only' using errcode='42501';end if;
 if p_completion is null or p_winner is null or p_completion not between 0 and 250
 or p_winner not between 0 and 250 then raise exception 'Invalid EXP award' using errcode='22023';end if;
 select * into c from public.league_global_challenges_v21 where id=p_challenge for update;
 if not found or c.status<>'active' or c.ends_at<=now()
 then raise exception 'Only open active challenges may set rewards' using errcode='22023';end if;
 update public.league_global_challenges_v21 set completion_exp=p_completion,winner_exp=p_winner where id=c.id;
 return pg_catalog.jsonb_build_object('completion_exp',p_completion,'winner_exp',p_winner);
end$f$;
revoke all on function league_v21_private.global_reward_set_core(uuid,integer,integer) from public,anon,authenticated;
grant execute on function league_v21_private.global_reward_set_core(uuid,integer,integer) to authenticated;
create or replace function public.league_v21_admin_set_global_rewards(p_challenge uuid,p_completion integer,p_winner integer)
returns jsonb language sql volatile security invoker set search_path=''
as $f$ select league_v21_private.global_reward_set_core(p_challenge,p_completion,p_winner) $f$;
revoke all on function public.league_v21_admin_set_global_rewards(uuid,integer,integer) from public,anon,authenticated;
grant execute on function public.league_v21_admin_set_global_rewards(uuid,integer,integer) to authenticated;

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
