-- TEST-ONLY fixture for Supabase isolated TEST project. Do not deploy to production.
create table if not exists public.boxer_notifications (
 id uuid primary key default gen_random_uuid(),
 recipient_id uuid not null references public.profiles(id),
 notification_type text not null,
 title text not null,
 message text not null,
 target_path text,
 created_at timestamptz not null default now(),
 read_at timestamptz
);
alter table public.boxer_notifications enable row level security;
revoke all on public.boxer_notifications from public,anon,authenticated;
grant select on public.boxer_notifications to authenticated;
drop policy if exists boxer_notifications_select_enabled on public.boxer_notifications;
create policy boxer_notifications_select_enabled
 on public.boxer_notifications for select to authenticated
 using (
  exists (select 1 from public.league_feature_flags f where f.feature_key='notifications' and f.is_enabled)
  and exists (select 1 from public.profiles p where p.id=recipient_id and p.auth_user_id=(select auth.uid()) and p.is_active)
 );
