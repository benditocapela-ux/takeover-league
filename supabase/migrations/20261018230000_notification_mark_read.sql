-- User-visible inbox read acknowledgement. Existing notifications table/producer is preserved.
-- Additive; TEST only until explicit GO LIVE approval.
create or replace function public.mark_my_notification_read(p_notification_id uuid)
returns boolean
language plpgsql volatile security definer
set search_path=''
as $func$
declare v_actor uuid; v_updated uuid;
begin
 if p_notification_id is null then
  raise exception 'Notification id required' using errcode='22023';
 end if;
 select p.id into v_actor from public.profiles p
 where p.auth_user_id=(select auth.uid()) and p.is_active is true and p.role='boxer';
 if v_actor is null then
  raise exception 'Only active boxer' using errcode='42501';
 end if;
 if not exists(select 1 from public.league_feature_flags f
     where f.feature_key='notifications' and f.is_enabled is true) then
  raise exception 'Notifications are disabled' using errcode='42501';
 end if;
 update public.boxer_notifications n
 set read_at=coalesce(n.read_at,now())
 where n.id=p_notification_id and n.recipient_id=v_actor
 returning n.id into v_updated;
 return v_updated is not null;
end
$func$;
revoke all on function public.mark_my_notification_read(uuid) from PUBLIC, anon, authenticated;
grant execute on function public.mark_my_notification_read(uuid) to authenticated;
comment on function public.mark_my_notification_read(uuid) is
 'Read acknowledgement on the requesting active boxer own inbox only, not an admin mutation or reward.';
