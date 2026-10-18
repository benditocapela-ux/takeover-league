-- Isolated TEST only; all fixture rows roll back.
begin;
select set_config('arena.admin',(select auth_user_id::text from public.profiles where role='admin' and is_active and auth_user_id is not null limit 1),true);
select set_config('arena.one',(select auth_user_id::text from public.profiles where role='boxer' and is_active and auth_user_id is not null order by id limit 1),true);
select set_config('arena.oneid',(select id::text from public.profiles where auth_user_id=current_setting('arena.one')::uuid),true);
select set_config('arena.twoid',(select id::text from public.profiles where role='boxer' and is_active and auth_user_id is not null order by id desc limit 1),true);
with x as (insert into public.profiles(display_name,role,is_active) values('ARENA LIVE THIRD FIXTURE','boxer',true) returning id)
select set_config('arena.three',id::text,true) from x;
select set_config('request.jwt.claim.sub',current_setting('arena.admin'),true);
set local role authenticated;
select set_config('arena.id',public.league_v21_arena_create('TEST Live Arena',7,array[current_setting('arena.oneid')::uuid,current_setting('arena.twoid')::uuid,current_setting('arena.three')::uuid])::text,true);
reset role;
update public.league_arena_members_v21 set status='accepted' where arena_id=current_setting('arena.id')::uuid;
set local role authenticated;
select public.league_v21_arena_start(current_setting('arena.id')::uuid);
reset role;
with x as (insert into public.training_submissions(boxer_id,training_type_id,training_date,status,created_at)
values(current_setting('arena.oneid')::uuid,(select id from public.training_types where is_active limit 1),current_date,'approved',now()) returning id)
select set_config('arena.sub',id::text,true) from x;
insert into public.point_transactions(boxer_id,submission_id,points,exp,category,description,effective_date)
values(current_setting('arena.oneid')::uuid,current_setting('arena.sub')::uuid,50,50,'training','TEST arena live points',current_date);
insert into public.training_submissions(boxer_id,training_type_id,training_date,status,created_at)
values(current_setting('arena.three')::uuid,(select id from public.training_types where is_active limit 1),current_date,'pending',now());
select set_config('request.jwt.claim.sub',current_setting('arena.one'),true);
set local role authenticated;
do $test$ declare r jsonb;begin
 select public.league_v21_arena_live_scores(current_setting('arena.id')::uuid) into r;
 if r->>'status'<>'active' or jsonb_array_length(r->'participants')<>3
 then raise exception 'Arena scores wrong shape: %',r;end if;
 if (select (x->>'score')::integer from jsonb_array_elements(r->'participants') x
   where x->>'boxer_id'=current_setting('arena.oneid'))<>50
 then raise exception 'Confirmed 50 points not reported: %',r;end if;
 if (select (x->>'pending')::integer from jsonb_array_elements(r->'participants') x
   where x->>'boxer_id'=current_setting('arena.three'))<>1
 then raise exception 'Pending training not reported: %',r;end if;
 perform set_config('request.jwt.claim.sub',gen_random_uuid()::text,true);
 begin
  perform public.league_v21_arena_live_scores(current_setting('arena.id')::uuid);
  raise exception 'Unrelated unauthenticated actor accessed arena';
 exception when insufficient_privilege then null;end;
end$test$;
reset role;
rollback;