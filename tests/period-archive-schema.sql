\set ON_ERROR_STOP on
-- Fresh disposable PG16/17 database, synthetic records only; never production.
do $$begin if current_database() not like 'league21_replay_%' then raise exception 'Disposable database required';end if;
 if not exists(select from pg_roles where rolname='anon') then create role anon nologin;end if;
 if not exists(select from pg_roles where rolname='authenticated') then create role authenticated nologin;end if;
end$$;
create schema auth;
create function auth.uid() returns uuid language sql stable set search_path='' as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
grant usage on schema auth to anon,authenticated;
create table public.profiles(id uuid primary key,auth_user_id uuid unique,display_name text,role text,is_active boolean,is_listed boolean,archived_at timestamptz);
create table public.point_transactions(id uuid primary key default gen_random_uuid(),boxer_id uuid not null references public.profiles(id),points integer,exp integer,effective_date date);
create table public.league_seasons_v21(id uuid primary key,title text,starts_on date,ends_on date,status text);
create table public.league_season_results_v21(id uuid primary key default gen_random_uuid(),season_id uuid references public.league_seasons_v21(id),boxer_id uuid references public.profiles(id),boxer_name text,rank_position integer,points integer,exp integer,captured_at timestamptz default now());
create table public.league_hall_of_fame_v21(id uuid primary key default gen_random_uuid(),season_id uuid references public.league_seasons_v21(id),boxer_id uuid references public.profiles(id),boxer_name text,title text,description text,awarded_at timestamptz default now());
alter table public.profiles enable row level security;
alter table public.point_transactions enable row level security;
alter table public.league_seasons_v21 enable row level security;
alter table public.league_season_results_v21 enable row level security;
alter table public.league_hall_of_fame_v21 enable row level security;
grant select on public.league_seasons_v21,public.league_season_results_v21,public.league_hall_of_fame_v21 to anon,authenticated;
create policy seasons_public on public.league_seasons_v21 for select to anon,authenticated using(status in ('active','closed'));
create policy results_public on public.league_season_results_v21 for select to anon,authenticated using(exists(select from public.league_seasons_v21 s where s.id=season_id and s.status='closed'));
create policy honors_public on public.league_hall_of_fame_v21 for select to anon,authenticated using(exists(select from public.league_seasons_v21 s where s.id=season_id and s.status='closed'));
\ir ../supabase/migrations/20261102090410_period_archive_readers.sql

insert into public.profiles values
 ('10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','Alpha aktuell','boxer',true,true,null),
 ('10000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000002','Beta','coach',true,true,null),
 ('10000000-0000-0000-0000-000000000003','20000000-0000-0000-0000-000000000003','Privat','boxer',true,false,null),
 ('10000000-0000-0000-0000-000000000004','20000000-0000-0000-0000-000000000004','Archiviert','boxer',true,true,now()),
 ('10000000-0000-0000-0000-000000000005','20000000-0000-0000-0000-000000000005','Inaktiv','boxer',false,true,null),
 ('10000000-0000-0000-0000-000000000006','20000000-0000-0000-0000-000000000006','Nullpunkte','boxer',true,true,null);
insert into public.league_seasons_v21 values
 ('30000000-0000-0000-0000-000000000001','September offiziell','2026-09-01','2026-09-30','closed'),
 ('30000000-0000-0000-0000-000000000002','August offiziell','2026-08-01','2026-08-31','closed'),
 ('30000000-0000-0000-0000-000000000003','Laufende Saison',current_date-1,current_date+1,'active'),
 ('30000000-0000-0000-0000-000000000004','Privater Entwurf',current_date+10,current_date+20,'draft');
insert into public.league_season_results_v21(season_id,boxer_id,boxer_name,rank_position,points,exp) values
 ('30000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','Alpha im September',2,100,70),
 ('30000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000002','Beta',2,100,70),
 ('30000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000003','Privat',1,200,80),
 ('30000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000004','Archiviert',3,50,30),
 ('30000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000005','Inaktiv',3,50,30),
 ('30000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000006','Nullpunkte',4,0,0),
 ('30000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000001','Alpha im August',1,555,55);
insert into public.league_hall_of_fame_v21(season_id,boxer_id,boxer_name,title,description)
 select season_id,boxer_id,boxer_name,'Saisonpodium','Gespeicherte Ehrung' from public.league_season_results_v21 where rank_position<=3;
insert into public.point_transactions(boxer_id,points,exp,effective_date) values
 ('10000000-0000-0000-0000-000000000001',10,10,'2026-10-01'),
 ('10000000-0000-0000-0000-000000000001',20,20,'2026-10-31'),
 ('10000000-0000-0000-0000-000000000001',999,999,'2026-09-30'),
 ('10000000-0000-0000-0000-000000000001',888,888,'2026-11-01'),
 ('10000000-0000-0000-0000-000000000002',40,40,'2026-10-15'),
 ('10000000-0000-0000-0000-000000000003',5000,5000,'2026-10-15');

-- A real READ ONLY transaction proves the endpoint and policies do not write.
begin read only;
set local role anon;
do $$declare p jsonb;q jsonb;begin
 p:=public.league_archive_period('season','30000000-0000-0000-0000-000000000001',20,0);
 if p->>'status'<>'official' or (p->>'total')::int<>3 or jsonb_array_length(p->'top')<>2 then raise exception 'Wrong official snapshot/visibility/ties';end if;
 if exists(select from jsonb_array_elements(p->'rows') r where (r->>'points')::int=555 or r->>'name' like '%August%') then raise exception 'Season mix';end if;
 if not exists(select from jsonb_array_elements(p->'rows') r where r->>'name'='Alpha im September' and (r->>'rank')::int=2 and (r->>'points')::int=100) then raise exception 'Snapshot changed or rank gap renumbered';end if;
 if jsonb_array_length(p->'honors')<>2 then raise exception 'Hidden honors leaked';end if;
 if (select count(*) from public.league_season_results_v21)<>4 then raise exception 'Existing direct table visibility unsafe';end if;
 if (select count(*) from public.league_hall_of_fame_v21)<>3 then raise exception 'Direct honors visibility unsafe';end if;
 if p->'my_result'<>'null'::jsonb then raise exception 'Anonymous own result';end if;
 p:=public.league_archive_period('month','2026-10',1,0);q:=public.league_archive_period('month','2026-10',1,1);
 if p->>'status'<>'reconstructed' or (p->>'official')::boolean or (p->>'total')::int<>2 or (p->>'next_offset')::int<>1 then raise exception 'Month provenance or page';end if;
 if p#>>'{rows,0,name}'<>'Beta' or (p#>>'{rows,0,points}')::int<>40 or (q#>>'{rows,0,points}')::int<>30 or q->'next_offset'<>'null'::jsonb then raise exception 'Month boundaries or pagination';end if;
 if jsonb_array_length(p->'honors')<>0 or (p#>>'{reward,additional_payout}')::boolean then raise exception 'Invented monthly award/payout';end if;
 begin perform public.league_archive_period('season','30000000-0000-0000-0000-000000000004',20,0);raise exception 'Draft leaked';exception when invalid_parameter_value then null;end;
 begin perform public.league_archive_period('month','2026-13',20,0);raise exception 'Invalid month accepted';exception when invalid_parameter_value then null;end;
 begin perform public.league_archive_period('month','2026-10',51,0);raise exception 'Unbounded page';exception when invalid_parameter_value then null;end;
 begin perform league_archive_private.period_rows('month',null,'2026-10-01','2026-11-01',false);raise exception 'Internal helper exposed';exception when insufficient_privilege then null;end;
end$$;
reset role;
select set_config('request.jwt.claim.sub','20000000-0000-0000-0000-000000000001',true);
set local role authenticated;
do $$declare p jsonb;begin
 p:=public.league_archive_period('month','2026-10',1,0);
 if p#>>'{my_result,name}'<>'Alpha aktuell' or (p#>>'{my_result,points}')::int<>30 then raise exception 'Own result missing beyond first page';end if;
end$$;
reset role;
select set_config('request.jwt.claim.sub','20000000-0000-0000-0000-000000000005',true);
set local role authenticated;
do $$begin if public.league_archive_period('month','2026-10',20,0)->'my_result'<>'null'::jsonb then raise exception 'Inactive own data exposed';end if;end$$;
rollback;
-- No read call created bookings, snapshots, awards, or a monthly closure.
do $$begin if (select count(*) from public.point_transactions)<>6 or (select count(*) from public.league_season_results_v21)<>7 then raise exception 'Archive changed data';end if;end$$;
\echo Period archive: public/authenticated, isolation, boundaries, pagination, snapshots, privacy and READ ONLY passed.
