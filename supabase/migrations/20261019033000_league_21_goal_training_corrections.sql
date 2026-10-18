-- Keep personal goal rewards consistent after admin corrections even if status stays approved.
-- Transfers, dates and quantitative metrics can modify BOTH the former and the new owner's progress.
-- Only active admin reviewers trigger privileged reconciliation; bulk legacy imports use bounded admin RPC.
create or replace function league_v21_private.goal_after_training_review()
returns trigger language plpgsql security definer set search_path='' as $f$
declare actor public.profiles%rowtype; g record;
begin
 if (OLD.status IS DISTINCT FROM NEW.status
      or OLD.boxer_id IS DISTINCT FROM NEW.boxer_id
      or OLD.training_date IS DISTINCT FROM NEW.training_date
      or OLD.jogging_km IS DISTINCT FROM NEW.jogging_km
      or OLD.technique_minutes IS DISTINCT FROM NEW.technique_minutes) is false
    or (OLD.status<>'approved' and NEW.status<>'approved') then return NEW;end if;
 select * into actor from public.profiles p
 where p.auth_user_id=(select auth.uid()) and p.is_active and p.role='admin';
 if not found then return NEW; end if;
 -- Reconcile both owners/windows. A transfer must revoke previous goal EXP
 -- and award the new owner only if their approved progress qualifies.
 for g in select x.id from public.league_boxer_goals_v21 x
   where x.metric<>'custom' and x.status in ('active','completed')
     and (
      (OLD.status='approved' and x.boxer_id=OLD.boxer_id
       and OLD.training_date between x.starts_on and x.ends_on)
      or
      (NEW.status='approved' and x.boxer_id=NEW.boxer_id
       and NEW.training_date between x.starts_on and x.ends_on)
     )
   order by x.id
 loop
   perform league_v21_private.complete_and_reward_goal_core(g.id);
 end loop;
 return NEW;
end$f$;
revoke all on function league_v21_private.goal_after_training_review() from public,anon,authenticated;
drop trigger if exists league_v21_goal_after_training_review on public.training_submissions;
create trigger league_v21_goal_after_training_review
after update of status,boxer_id,training_date,jogging_km,technique_minutes
on public.training_submissions
for each row
execute function league_v21_private.goal_after_training_review();
