-- Takeover League 2.0: read-only, owner-gated history of training changes.
-- The audit table remains nonselectable from public clients.
create or replace function public.league_training_audit_recent(p_boxer_id uuid default null)
returns table(submission_id uuid,changed_at timestamptz,boxer_id uuid,old_status text,new_status text)
language plpgsql stable security definer set search_path = ''
as $function$
declare v_actor public.profiles%rowtype;
begin
 if (select auth.uid()) is null then raise exception 'Authentication required' using errcode='28000';end if;
 select * into v_actor from public.profiles where auth_user_id=(select auth.uid()) and is_active=true
 and role in ('boxer','admin','coach');
 if v_actor.id is null then raise exception 'Active league profile required' using errcode='42501';end if;
 if v_actor.role='boxer' and p_boxer_id is not null and p_boxer_id<>v_actor.id then
  raise exception 'Other boxer history forbidden' using errcode='42501';end if;
 return query
 select a.submission_id,a.changed_at,s.boxer_id,
 a.old_submission->>'status',a.new_submission->>'status'
 from public.training_audit a
 join public.training_submissions s on s.id=a.submission_id
 where (v_actor.role in ('coach','admin') or s.boxer_id=v_actor.id)
 and (p_boxer_id is null or s.boxer_id=p_boxer_id)
 order by a.changed_at desc,a.id desc
 limit 100;
end
$function$;
revoke all on function public.league_training_audit_recent(uuid) from public,anon;
grant execute on function public.league_training_audit_recent(uuid) to authenticated;
