-- TEST only. Verified approve-without-ledger blocks multiplayer settlement, then repair settles once.
begin;
select set_config('a.admin',(select auth_user_id::text from public.profiles where role='admin' and is_active and auth_user_id is not null limit 1),true);
select set_config('a.one',(select id::text from public.profiles where role='boxer' and is_active order by id limit 1),true);
select set_config('a.two',(select id::text from public.profiles where role='boxer' and is_active order by id desc limit 1),true);
with x as (insert into public.profiles(display_name,role,is_active) values('ARENA MISSING LEDGER TEST','boxer',true) returning id)
select set_config('a.three',id::text,true) from x;
select set_config('request.jwt.claim.sub',current_setting('a.admin'),true);
set local role authenticated;
select set_config('a.id',public.league_v21_arena_create('TEST Missing Ledger Arena',7,
 array[current_setting('a.one')::uuid,current_setting('a.two')::uuid,current_setting('a.three')::uuid])::text,true);
reset role;
update public.league_arena_members_v21 set status='accepted' where arena_id=current_setting('a.id')::uuid;
-- Backdate a valid seven-day completed period with correct constraint-consistent timestamps.
update public.league_arena_duels_v21 set status='active',
 starts_at=now()-interval '8 days',ends_at=now()-interval '1 day'
where id=current_setting('a.id')::uuid;
with x as(
 insert into public.training_submissions(boxer_id,training_type_id,training_date,status,created_at)
 values(current_setting('a.one')::uuid,(select id from public.training_types where is_active order by id limit 1),
 current_date-4,'approved',now()-interval '4 days') returning id
) select set_config('a.sub',id::text,true) from x;
set local role authenticated;
do $missing$ begin
 begin
  perform public.league_v21_arena_finish(current_setting('a.id')::uuid);
  raise exception 'Arena settled with unbooked approved training';
 exception when check_violation then null;
 end;
end$missing$;
reset role;
do $unchanged$ begin
 if (select status from public.league_arena_duels_v21 where id=current_setting('a.id')::uuid)='settled'
 or exists(select 1 from public.league_arena_results_v21 where arena_id=current_setting('a.id')::uuid)
 then raise exception 'Arena partially settled with missing ledger';end if;
end$unchanged$;
insert into public.point_transactions(boxer_id,submission_id,points,exp,category,description,effective_date)
values(current_setting('a.one')::uuid,current_setting('a.sub')::uuid,50,50,'training','TEST corrected arena ledger',current_date-4);
set local role authenticated;
select public.league_v21_arena_finish(current_setting('a.id')::uuid);
select public.league_v21_arena_finish(current_setting('a.id')::uuid);
reset role;
do $settled$ begin
 if (select status from public.league_arena_duels_v21 where id=current_setting('a.id')::uuid)<>'settled'
 or (select count(*) from public.league_arena_results_v21 where arena_id=current_setting('a.id')::uuid)<>3
 or (select score from public.league_arena_results_v21 where arena_id=current_setting('a.id')::uuid
    and boxer_id=current_setting('a.one')::uuid)<>50
 or (select rank_position from public.league_arena_results_v21 where arena_id=current_setting('a.id')::uuid
    and boxer_id=current_setting('a.one')::uuid)<>1
 then raise exception 'Missing-ledger repair failed to settle correctly';end if;
end$settled$;
rollback;