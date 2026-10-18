-- Public achievement BADGE PROJECTION – no EXP or private workout disclosure.
-- Staged, opt-in 2.1. Core achievement / EXP ledger remain private.
create table if not exists public.league_public_badges_v21(
 boxer_id uuid not null references public.profiles(id) on delete cascade,
 achievement_id uuid not null references public.achievement_definitions(id) on delete cascade,
 boxer_name text not null,
 title text not null,
 icon_key text,
 earned_at timestamptz not null,
 primary key(boxer_id,achievement_id)
);
create index if not exists league_public_badges_v21_name_idx on public.league_public_badges_v21(boxer_name);
alter table public.league_public_badges_v21 enable row level security;
revoke all on public.league_public_badges_v21 from public,anon,authenticated;
grant select on public.league_public_badges_v21 to anon,authenticated;
drop policy if exists "Earned badge projection is public" on public.league_public_badges_v21;
create policy "Earned badge projection is public" on public.league_public_badges_v21 for select to anon,authenticated using(true);
create or replace function league_v21_private.sync_public_badges_core()
returns trigger language plpgsql security definer set search_path='' as $f$
declare boxer uuid;
begin
 boxer:=case when TG_OP='DELETE' then OLD.boxer_id else NEW.boxer_id end;
 if TG_OP='DELETE' then
  delete from public.league_public_badges_v21
  where boxer_id=OLD.boxer_id and achievement_id=OLD.achievement_id;
 else
  insert into public.league_public_badges_v21(boxer_id,achievement_id,boxer_name,title,icon_key,earned_at)
  select NEW.boxer_id,NEW.achievement_id,p.display_name,d.title,d.icon_key,NEW.earned_at
  from public.profiles p join public.achievement_definitions d on d.id=NEW.achievement_id
  where p.id=NEW.boxer_id and p.is_active and p.role='boxer' and d.is_active
  on conflict(boxer_id,achievement_id)
  do update set boxer_name=excluded.boxer_name,title=excluded.title,icon_key=excluded.icon_key,earned_at=excluded.earned_at;
 end if;
 return case when TG_OP='DELETE' then OLD else NEW end;
end$f$;
revoke all on function league_v21_private.sync_public_badges_core() from public,anon,authenticated;
drop trigger if exists league_v21_badge_projection on public.boxer_achievements;
create trigger league_v21_badge_projection after insert or update or delete on public.boxer_achievements
for each row execute function league_v21_private.sync_public_badges_core();
-- One-time snapshot (no POINT / EXP mutation).
insert into public.league_public_badges_v21(boxer_id,achievement_id,boxer_name,title,icon_key,earned_at)
select ba.boxer_id,ba.achievement_id,p.display_name,d.title,d.icon_key,ba.earned_at
from public.boxer_achievements ba
join public.profiles p on p.id=ba.boxer_id and p.role='boxer' and p.is_active
join public.achievement_definitions d on d.id=ba.achievement_id and d.is_active
on conflict(boxer_id,achievement_id) do nothing;
