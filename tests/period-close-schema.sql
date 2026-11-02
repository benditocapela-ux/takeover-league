\set ON_ERROR_STOP on
-- Fresh synthetic local database only; authentic PG roles/transactions, no cloud data.
\ir period-archive-schema.sql
create schema league_v21_private;
create table public.league_feature_flags(feature_key text primary key,is_enabled boolean not null);
insert into public.league_feature_flags values('notifications',true);
create function league_v21_private.notifications_enabled() returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.league_feature_flags where feature_key='notifications' and is_enabled)
$$;
revoke all on function league_v21_private.notifications_enabled() from public,anon,authenticated;
create table public.training_submissions(id uuid primary key default gen_random_uuid(),boxer_id uuid references public.profiles(id),training_date date not null,
 status text not null,created_at timestamptz not null default now());
alter table public.training_submissions enable row level security;
alter table public.point_transactions add column submission_id uuid references public.training_submissions(id);
alter table public.point_transactions add column category text not null default 'adjustment';
alter table public.league_seasons_v21 alter column id set default gen_random_uuid();
create unique index season_one_active on public.league_seasons_v21(status) where status='active';
alter table public.league_hall_of_fame_v21 add unique(boxer_id,season_id,title);
create table public.boxer_notifications(id uuid primary key default gen_random_uuid(),recipient_id uuid references public.profiles(id),notification_type text not null,
 title text not null,message text not null,target_path text,created_at timestamptz default now(),read_at timestamptz,event_key text);
create unique index boxer_notifications_recipient_event_key_uidx on public.boxer_notifications(recipient_id,event_key) where event_key is not null;
alter table public.boxer_notifications enable row level security;
\ir ../supabase/migrations/20261028110000_season_single_active_next_draft.sql
\ir ../supabase/migrations/20261102095858_period_close_preview_snapshot.sql
insert into public.profiles values
 ('10000000-0000-0000-0000-000000000007','20000000-0000-0000-0000-000000000007','Admin','admin',true,false,null),
 ('10000000-0000-0000-0000-000000000008','20000000-0000-0000-0000-000000000008','Coach archiviert','coach',true,false,now());

begin read only;
set local role anon;
do $$begin
 begin perform public.league_period_close_preview('month','2026-10');raise exception 'Guest preview accepted';exception when insufficient_privilege then null;end;
 begin perform public.league_period_close_confirm('month','2026-10',true,repeat('0',32));raise exception 'Guest close accepted';exception when insufficient_privilege then null;end;
end$$;
reset role;
select set_config('request.jwt.claim.sub','20000000-0000-0000-0000-000000000001',true);
set local role authenticated;
do $$begin begin perform public.league_period_close_preview('month','2026-10');raise exception 'Boxer preview accepted';exception when insufficient_privilege then null;end;end$$;
reset role;
select set_config('request.jwt.claim.sub','20000000-0000-0000-0000-000000000008',true);
set local role authenticated;
do $$begin begin perform public.league_period_close_preview('month','2026-10');raise exception 'Archived coach accepted';exception when insufficient_privilege then null;end;end$$;
reset role;
select set_config('request.jwt.claim.sub','20000000-0000-0000-0000-000000000002',true);
set local role authenticated;
do $$declare p jsonb;begin
 p:=public.league_period_close_preview('month','2026-10');
 if (p->>'can_close')::boolean is not true or p?'_snapshot_rows' or (p->>'ranked_count')::int<>2 or p#>>'{reward,status}'<>'not_configured' then raise exception 'Read-only month preview invalid';end if;
 if (public.league_period_close_preview('season','30000000-0000-0000-0000-000000000003')->>'can_close')::boolean then raise exception 'Running season closable';end if;
 begin perform * from league_archive_private.period_closures;raise exception 'Private closure table exposed';exception when insufficient_privilege then null;end;
 begin perform league_v21_private.season_transition_core('30000000-0000-0000-0000-000000000003','activate');raise exception 'Coach activation allowed';exception when insufficient_privilege then null;end;
end$$;
rollback;

\ir period-close-transaction.sql
\echo Period close schema/role/READ ONLY/transaction tests passed.
