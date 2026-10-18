-- Sanitized public settled duel history. Training submissions, ledger and private data remain hidden.
create table if not exists public.league_public_duel_history_v21(
 duel_id uuid primary key references public.league_duels(id) on delete restrict,
 challenger_id uuid not null references public.profiles(id),
 opponent_id uuid not null references public.profiles(id),
 challenger_name text not null,
 opponent_name text not null,
 challenger_score integer not null check(challenger_score>=0),
 opponent_score integer not null check(opponent_score>=0),
 winner_id uuid references public.profiles(id),
 settled_at timestamptz not null,
 updated_at timestamptz not null default now()
);
create index if not exists league_public_duel_history_v21_pair_idx on public.league_public_duel_history_v21(challenger_id,opponent_id);
alter table public.league_public_duel_history_v21 enable row level security;
revoke all on public.league_public_duel_history_v21 from public,anon,authenticated;
grant select on public.league_public_duel_history_v21 to anon,authenticated;
drop policy if exists "Only sanitized settled duel results are public" on public.league_public_duel_history_v21;
create policy "Only sanitized settled duel results are public" on public.league_public_duel_history_v21
for select to anon,authenticated using(true);
create or replace function league_v21_private.sync_public_duel_history()
returns trigger language plpgsql security definer set search_path='' as $f$
begin
 if new.status='settled' and new.settled_at is not null then
  insert into public.league_public_duel_history_v21(
   duel_id,challenger_id,opponent_id,challenger_name,opponent_name,
   challenger_score,opponent_score,winner_id,settled_at)
  select new.id,new.challenger_id,new.opponent_id,p1.display_name,p2.display_name,
   new.challenger_score,new.opponent_score,new.winner_id,new.settled_at
  from public.profiles p1 join public.profiles p2 on p2.id=new.opponent_id
  where p1.id=new.challenger_id
  on conflict(duel_id) do update
  set challenger_name=excluded.challenger_name,opponent_name=excluded.opponent_name,
   challenger_score=excluded.challenger_score,opponent_score=excluded.opponent_score,
   winner_id=excluded.winner_id,settled_at=excluded.settled_at,updated_at=now();
 else
  delete from public.league_public_duel_history_v21 where duel_id=new.id;
 end if;
 return new;
end$f$;
revoke all on function league_v21_private.sync_public_duel_history() from public,anon,authenticated;
drop trigger if exists league_v21_public_duel_history on public.league_duels;
create trigger league_v21_public_duel_history after update on public.league_duels
for each row when (
 old.status is distinct from new.status or old.challenger_score is distinct from new.challenger_score
 or old.opponent_score is distinct from new.opponent_score or old.winner_id is distinct from new.winner_id
) execute function league_v21_private.sync_public_duel_history();
-- Backfill only already-finalized public game scores; no reward or training changes.
insert into public.league_public_duel_history_v21(
 duel_id,challenger_id,opponent_id,challenger_name,opponent_name,
 challenger_score,opponent_score,winner_id,settled_at)
select d.id,d.challenger_id,d.opponent_id,p1.display_name,p2.display_name,
 d.challenger_score,d.opponent_score,d.winner_id,d.settled_at
from public.league_duels d join public.profiles p1 on p1.id=d.challenger_id
join public.profiles p2 on p2.id=d.opponent_id
where d.status='settled' and d.settled_at is not null
on conflict(duel_id) do nothing;
