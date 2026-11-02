\set ON_ERROR_STOP on
do $$begin if current_database() not like 'league21_replay_%' then raise exception 'Disposable DB only';end if;end$$;
\ir ../supabase/migrations/20261102101922_period_notices_profile_state.sql
begin;
set local role anon;
do $$begin begin perform public.league_period_notices();raise exception 'Guest notice leak';exception when insufficient_privilege then null;end;end$$;
reset role;
select set_config('request.jwt.claim.sub','20000000-0000-0000-0000-000000000001',true);
set local role authenticated;
do $$declare p jsonb;k text;begin
 p:=public.league_period_notices();k:=p#>>'{items,0,event_key}';
 if jsonb_array_length(p->'items')<>1 or p#>>'{items,0,phase}'<>'awaiting_close' then raise exception 'Wrong pending period';end if;
 perform public.league_period_notice_dismiss(k);perform public.league_period_notice_dismiss(k);
 if public.league_period_notices()->'items'<>'[]'::jsonb then raise exception 'Own dismissal not persistent';end if;
 begin perform public.league_period_notice_dismiss('period:month:1900-01:closed');raise exception 'Arbitrary notice key accepted';exception when invalid_parameter_value then null;end;
 begin perform * from league_archive_private.period_notice_dismissals;raise exception 'Private acknowledgements exposed';exception when insufficient_privilege then null;end;
end$$;
reset role;
select set_config('request.jwt.claim.sub','20000000-0000-0000-0000-000000000002',true);
set local role authenticated;
do $$declare p jsonb;r jsonb;k text;begin
 p:=public.league_period_notices();if jsonb_array_length(p->'items')<>1 then raise exception 'Other profile dismissal leaked';end if;
 k:=p#>>'{items,0,period_key}';p:=public.league_period_close_preview('month',k);
 r:=public.league_period_close_confirm('month',k,true,p->>'revision');if r->>'status'<>'closed' then raise exception 'Synthetic close failed';end if;
end$$;
reset role;
-- Two independent periods, both retained; only exact actor/event acknowledges.
update public.league_seasons_v21 set starts_on=current_date-10,ends_on=current_date-1,status='closed'
 where id='30000000-0000-0000-0000-000000000003';
select set_config('request.jwt.claim.sub','20000000-0000-0000-0000-000000000001',true);
set local role authenticated;
do $$declare p jsonb;k text;begin
 p:=public.league_period_notices();if jsonb_array_length(p->'items')<>2 then raise exception 'New official close suppressed by old dismissal';end if;
 select value->>'event_key' into k from jsonb_array_elements(p->'items') where value->>'kind'='month';
 perform public.league_period_notice_dismiss(k);
 if jsonb_array_length(public.league_period_notices()->'items')<>1 then raise exception 'Different period also dismissed';end if;
end$$;
reset role;
do $$begin
 if exists(select 1 from public.boxer_notifications where recipient_id='10000000-0000-0000-0000-000000000001' and read_at is null) then raise exception 'Exact own inbox event not acknowledged';end if;
 if exists(select 1 from public.boxer_notifications where recipient_id='10000000-0000-0000-0000-000000000002' and read_at is not null) then raise exception 'Another inbox changed';end if;
end$$;
select set_config('request.jwt.claim.sub','20000000-0000-0000-0000-000000000005',true);
set local role authenticated;
do $$begin begin perform public.league_period_notices();raise exception 'Inactive notice access';exception when insufficient_privilege then null;end;end$$;
reset role;
update public.league_feature_flags set is_enabled=false where feature_key='notifications';
select set_config('request.jwt.claim.sub','20000000-0000-0000-0000-000000000002',true);
set local role authenticated;
do $$begin if public.league_period_notices()->>'enabled'<>'false' then raise exception 'Flag bypass';end if;
 begin perform public.league_period_notice_dismiss('x');raise exception 'Disabled write allowed';exception when insufficient_privilege then null;end;
end$$;
rollback;
\echo Period notices: actual roles, account separation, pending-to-official resurfacing, two periods, exact inbox acknowledgement and feature flag passed.
