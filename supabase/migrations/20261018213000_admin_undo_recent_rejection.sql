-- Only reverses a recently REJECTED training. Never alters points/EXP or already approved results.
-- Deliberately does not attempt to undo duels, achievements, settled challenges, or approved submissions.
create or replace function public.admin_undo_recent_rejection(p_submission_id uuid)
returns jsonb language plpgsql security definer set search_path = ''
as $body$
declare
 actor public.profiles%rowtype;
 training public.training_submissions%rowtype;
 restored public.training_submissions%rowtype;
begin
 select * into actor from public.profiles p
 where p.auth_user_id=(select auth.uid()) and p.role='admin' and p.is_active=true;
 if not found then raise exception 'Only active admin' using errcode='42501'; end if;
 if p_submission_id is null then raise exception 'Submission required' using errcode='22023';end if;
 select * into training from public.training_submissions s
 where s.id=p_submission_id for update;
 if not found then raise exception 'Training not found' using errcode='22023';end if;
 if training.status<>'rejected' or training.reviewed_by is distinct from actor.id
    or training.reviewed_at is null or training.reviewed_at < now()-interval '15 minutes'
    or training.reviewed_at > now()+interval '1 minute'
 then raise exception 'Only own recent rejections can be undone' using errcode='42501';end if;
 if exists(select 1 from public.point_transactions t
  where t.submission_id=training.id)
 then raise exception 'Training has an existing ledger, use audited admin correction' using errcode='42501';end if;
 update public.training_submissions s
 set status='pending',reviewed_by=null,reviewed_at=null
 where s.id=training.id and s.status='rejected'
 returning * into restored;
 if not found then raise exception 'Concurrent modification' using errcode='40001';end if;
 insert into public.training_audit(submission_id,changed_by,old_submission,new_submission,old_transaction,new_transaction)
 values(training.id,actor.id,to_jsonb(training),to_jsonb(restored),
   (select to_jsonb(t) from public.point_transactions t where t.submission_id=training.id limit 1),
   (select to_jsonb(t) from public.point_transactions t where t.submission_id=training.id limit 1));
 return pg_catalog.jsonb_build_object('submission_id',training.id,'status','pending','undo','rejection_only');
end;
$body$;
revoke all on function public.admin_undo_recent_rejection(uuid) from public,anon,authenticated;
grant execute on function public.admin_undo_recent_rejection(uuid) to authenticated;
comment on function public.admin_undo_recent_rejection(uuid) is 'Undo only own 15-minute rejected submissions with zero rewards; approved/rewarded actions require separately audited correction.';
