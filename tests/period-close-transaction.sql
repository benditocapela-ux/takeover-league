\set ON_ERROR_STOP on
-- All synthetic test mutations, including result snapshots, are rolled back.
begin;
select set_config('request.jwt.claim.sub','20000000-0000-0000-0000-000000000002',true);
insert into public.training_submissions(id,boxer_id,training_date,status,created_at) values
 ('40000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','2026-10-31','pending','2026-10-31T21:00:00Z');
do $$declare p jsonb;r jsonb;begin
 p:=public.league_period_close_preview('month','2026-10');r:=public.league_period_close_confirm('month','2026-10',true,p->>'revision');
 if r->>'status'<>'blocked' or p#>>'{trainings,pending}'<>'1' then raise exception 'Pending training did not block';end if;
 begin perform public.league_period_close_confirm('month','2026-10',false,p->>'revision');raise exception 'Implicit close accepted';exception when invalid_parameter_value then null;end;
end$$;
update public.training_submissions set status='approved';
do $$declare p jsonb;begin p:=public.league_period_close_preview('month','2026-10');if (p->>'can_close')::boolean or p#>>'{trainings,missing_ledger}'<>'1' then raise exception 'Missing ledger unblocked';end if;end$$;
insert into public.point_transactions(boxer_id,submission_id,points,exp,effective_date,category)
 select boxer_id,id,5,5,training_date,'training' from public.training_submissions;
insert into public.point_transactions(boxer_id,submission_id,points,exp,effective_date,category)
 select boxer_id,id,5,5,training_date,'training' from public.training_submissions;
do $$declare p jsonb;begin p:=public.league_period_close_preview('month','2026-10');if (p->>'can_close')::boolean or p#>>'{trainings,duplicate_ledger}'<>'1' then raise exception 'Duplicate ledger unblocked';end if;end$$;
delete from public.point_transactions where id=(select id from public.point_transactions where submission_id is not null order by id limit 1);
do $$declare p jsonb;r jsonb;n integer;before_points integer;begin
 p:=public.league_period_close_preview('month','2026-10');
 insert into public.point_transactions(boxer_id,points,exp,effective_date) values('10000000-0000-0000-0000-000000000001',1,1,'2026-10-15');
 r:=public.league_period_close_confirm('month','2026-10',true,p->>'revision');
 if r->>'status'<>'changed' or exists(select 1 from league_archive_private.period_closures) then raise exception 'Stale revision closed';end if;
 p:=r->'preview';select count(*) into before_points from public.point_transactions;
 r:=public.league_period_close_confirm('month','2026-10',true,p->>'revision');
 if r->>'status'<>'closed' or (r->>'notification_count')::int<>2 or (r->>'additional_payout')::boolean or r->'bookings'<>'[]'::jsonb then raise exception 'Month result closure invalid %',r;end if;
 if (select count(*) from public.point_transactions)<>before_points then raise exception 'Invented payout';end if;
 if (select count(*) from public.boxer_notifications where target_path='/league-history.html?month=2026-10')<>2 then raise exception 'Month notification deep link';end if;
 update public.boxer_notifications set read_at=now();
 r:=public.league_period_close_confirm('month','2026-10',true,p->>'revision');
 if (r->>'unchanged')::boolean is not true or (select count(*) from public.boxer_notifications)<>2 or exists(select from public.boxer_notifications where read_at is null) then raise exception 'Repeat duplicated or unread reset';end if;
 insert into public.point_transactions(boxer_id,points,exp,effective_date) values('10000000-0000-0000-0000-000000000001',900,900,'2026-10-15');
 r:=public.league_archive_period('month','2026-10',20,0);
 if r->>'source'<>'month_snapshot' or r->>'status'<>'official' or (r#>>'{rows,0,points}')::int<>40 then raise exception 'Official month not frozen';end if;
 if jsonb_array_length(r->'honors')<>0 then raise exception 'Invented month honor';end if;
 update public.profiles set is_listed=false where id='10000000-0000-0000-0000-000000000002';
 r:=public.league_archive_period('month','2026-10',20,0);
 if (r->>'total')::int<>1 or r#>>'{rows,0,rank}'<>'2' then raise exception 'Monthly current privacy or saved rank';end if;
 update public.profiles set is_listed=true where id='10000000-0000-0000-0000-000000000002';
 begin update league_archive_private.month_results set points=123;raise exception 'Snapshot mutable';exception when object_not_in_prerequisite_state then null;end;
 begin delete from league_archive_private.period_closures;raise exception 'Audit mutable';exception when object_not_in_prerequisite_state then null;end;
end$$;

-- Season rank contract excludes coaches and clamps scores as the original close did.
update public.league_seasons_v21 set starts_on='2026-07-01',ends_on='2026-07-31' where id='30000000-0000-0000-0000-000000000003';
insert into public.point_transactions(boxer_id,points,exp,effective_date) values
 ('10000000-0000-0000-0000-000000000001',40,30,'2026-07-10'),
 ('10000000-0000-0000-0000-000000000002',999,999,'2026-07-10'),
 ('10000000-0000-0000-0000-000000000006',-20,-10,'2026-07-11');
do $$declare p jsonb;r jsonb;begin
 p:=public.league_period_close_preview('season','30000000-0000-0000-0000-000000000003');
 if (p->>'ranked_count')::int<>2 or p#>>'{rows,1,points}'<>'0' or p#>>'{rows,1,exp}'<>'0' then raise exception 'Season eligibility/clamp differs';end if;
 r:=public.league_period_close_confirm('season','30000000-0000-0000-0000-000000000003',true,p->>'revision');
 if r->>'status'<>'closed' or (r->>'honor_count')::int<>1 or (select count(*) from public.boxer_notifications)<>4 then raise exception 'Two nearby different closes lost a notification or honor receipt';end if;
 if (select count(*) from public.league_hall_of_fame_v21 where season_id='30000000-0000-0000-0000-000000000003')<>1 then raise exception 'Season title contract changed';end if;
 if exists(select 1 from public.boxer_notifications where target_path='/league-history.html') then raise exception 'Unkeyed notification';end if;
 r:=public.league_archive_period('season','30000000-0000-0000-0000-000000000003',20,0);
 if r->>'source'<>'season_snapshot' or (r#>>'{rows,0,points}')::int<>40 then raise exception 'Official season mixed with month';end if;
end$$;
rollback;
begin;
-- Legacy explicit admin API keeps its response and next-draft contract.
delete from public.league_seasons_v21 where status='draft';
update public.league_seasons_v21 set starts_on=current_date-4,ends_on=current_date-1 where status='active';
select set_config('request.jwt.claim.sub','20000000-0000-0000-0000-000000000007',true);
do $$declare r jsonb;next_id uuid;begin
 r:=league_v21_private.season_transition_core('30000000-0000-0000-0000-000000000003','close');
 next_id:=(r#>>'{next_draft,id}')::uuid;
 if r->>'status'<>'closed' or r->>'ranked_boxers'<>'2' or next_id is null then raise exception 'Legacy admin close response changed %',r;end if;
 if not exists(select 1 from public.league_seasons_v21 where id=next_id and status='draft' and starts_on=current_date and ends_on=current_date+3)
 then raise exception 'Next draft length/date/status changed';end if;
 if (league_v21_private.season_transition_core('30000000-0000-0000-0000-000000000003','close')->>'unchanged')::boolean is not true then raise exception 'Legacy retry not unchanged';end if;
 perform set_config('request.jwt.claim.sub','20000000-0000-0000-0000-000000000002',true);
 begin perform league_v21_private.season_transition_core(next_id,'activate');raise exception 'Coach activated next draft';exception when insufficient_privilege then null;end;
 perform set_config('request.jwt.claim.sub','20000000-0000-0000-0000-000000000007',true);
 perform league_v21_private.season_transition_core(next_id,'activate');
 if (select count(*) from public.league_seasons_v21 where status='active')<>1 then raise exception 'Admin activation contract changed';end if;
end$$;
rollback;
\echo Result-only month+season close: pending, ledgers, stale revision, immutable snapshots, repeated confirm, exact events and privacy passed.
