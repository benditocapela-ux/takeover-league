-- Takeover League 2.0 - coach-only read API for protected audit trail.
-- STAGED: test project only, no production migration without explicit release approval.
create or replace function public.coach_training_audit_recent(p_limit integer default 50)
returns table (
  audit_id bigint,
  happened_at timestamptz,
  boxer_name text,
  changed_by_name text,
  old_status text,
  new_status text,
  old_points integer,
  new_points integer
)
language plpgsql stable security definer set search_path = ''
as $function$
begin
  if not exists (
    select 1 from public.profiles actor
    where actor.auth_user_id = (select auth.uid())
      and actor.role = 'admin' and actor.is_active is true
  ) then
    raise exception 'Only an active admin can read training audit'
      using errcode = '42501';
  end if;

  return query
  select a.id, a.changed_at, boxer.display_name::text, editor.display_name::text,
    a.old_submission ->> 'status',
    a.new_submission ->> 'status',
    nullif(a.old_transaction ->> 'points','')::integer,
    nullif(a.new_transaction ->> 'points','')::integer
  from public.training_audit a
  left join public.training_submissions s on s.id = a.submission_id
  left join public.profiles boxer on boxer.id = coalesce(
    s.boxer_id,
    nullif(a.new_submission ->> 'boxer_id','')::uuid,
    nullif(a.old_submission ->> 'boxer_id','')::uuid)
  left join public.profiles editor on editor.id = a.changed_by
  order by a.changed_at desc, a.id desc
  limit greatest(1, least(coalesce(p_limit,50),100));
end;
$function$;
revoke all on function public.coach_training_audit_recent(integer) from public, anon, authenticated;
grant execute on function public.coach_training_audit_recent(integer) to authenticated;
comment on function public.coach_training_audit_recent(integer) is
  'Admin-only filtered audit view. Does not expose training notes, weight, authentication identifiers or raw JSON snapshots.';
