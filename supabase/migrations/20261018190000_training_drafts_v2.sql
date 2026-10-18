-- Takeover League 2.0: private per-boxer resumable training draft.
-- Prepared for review. TEST project only until separately approved production rollout.
create table public.training_drafts_v2 (
  boxer_id uuid primary key references public.profiles(id) on delete cascade,
  training_type_id bigint references public.training_types(id),
  training_date date,
  notes text not null default '' check (char_length(notes) <= 500),
  jogging_km numeric check (jogging_km is null or jogging_km between 0 and 1000),
  technique_minutes integer check (technique_minutes is null or technique_minutes between 0 and 1440),
  updated_at timestamptz not null default now()
);
alter table public.training_drafts_v2 enable row level security;
revoke all on public.training_drafts_v2 from public, anon;
grant select,insert,update,delete on public.training_drafts_v2 to authenticated;
create policy training_drafts_v2_boxer_owns
on public.training_drafts_v2 for all to authenticated
using (exists (
  select 1 from public.profiles p
  where p.id = boxer_id and p.auth_user_id=(select auth.uid())
    and p.role='boxer' and p.is_active=true
))
with check (exists (
  select 1 from public.profiles p
  where p.id = boxer_id and p.auth_user_id=(select auth.uid())
    and p.role='boxer' and p.is_active=true
));
comment on table public.training_drafts_v2 is
  'Private boxer-owned draft only; never awards points or EXP. Approvals use existing review_training RPC.';
