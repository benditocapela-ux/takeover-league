-- Admins may inspect drafts and personal targets, public viewers still cannot.
drop policy if exists "Admin reads season drafts" on public.league_seasons_v21;
create policy "Admin reads season drafts" on public.league_seasons_v21 for select to authenticated using(
 exists(select 1 from public.profiles p where p.auth_user_id=(select auth.uid()) and p.is_active and p.role='admin')
);
drop policy if exists "Admin reads global drafts" on public.league_global_challenges_v21;
create policy "Admin reads global drafts" on public.league_global_challenges_v21 for select to authenticated using(
 exists(select 1 from public.profiles p where p.auth_user_id=(select auth.uid()) and p.is_active and p.role='admin')
);
