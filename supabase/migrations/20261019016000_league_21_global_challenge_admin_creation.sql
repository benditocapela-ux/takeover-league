-- Admin-only global challenge publishing. No EXP payout and no direct table grants.
create or replace function league_v21_private.global_create_core(
 p_title text,p_description text,p_metric text,p_target numeric,
 p_starts timestamptz,p_ends timestamptz,p_publish boolean)
returns uuid language plpgsql security definer set search_path='' as $f$
declare actor public.profiles%rowtype;result uuid;
begin
 select * into actor from public.profiles p where p.auth_user_id=(select auth.uid()) and p.is_active and p.role='admin';
 if not found then raise exception 'Only active admin' using errcode='42501';end if;
 if p_title is null or length(trim(p_title)) not between 3 and 120
 or length(coalesce(p_description,''))>1000
 or p_metric not in ('training_sessions','jogging_km','technique_minutes')
 or p_target is null or p_target<=0 or p_target>1000000
 or p_starts is null or p_ends is null or p_ends<=p_starts or p_ends>p_starts+interval '90 days'
 then raise exception 'Invalid challenge fields' using errcode='22023';end if;
 if coalesce(p_publish,false) and p_ends<=now() then raise exception 'Cannot publish expired challenge' using errcode='22023';end if;
 insert into public.league_global_challenges_v21(title,description,metric,target_value,starts_at,ends_at,status,created_by)
 values(trim(p_title),coalesce(trim(p_description),''),p_metric,p_target,p_starts,p_ends,
        case when p_publish then 'active' else 'draft' end,actor.id)
 returning id into result;
 return result;
end$f$;
revoke all on function league_v21_private.global_create_core(text,text,text,numeric,timestamptz,timestamptz,boolean)
from public,anon,authenticated;
grant execute on function league_v21_private.global_create_core(text,text,text,numeric,timestamptz,timestamptz,boolean) to authenticated;
create or replace function public.league_v21_admin_create_global_challenge(
 p_title text,p_description text,p_metric text,p_target numeric,
 p_starts timestamptz,p_ends timestamptz,p_publish boolean default false)
returns uuid language sql volatile security invoker set search_path=''
as $f$
 select league_v21_private.global_create_core(p_title,p_description,p_metric,p_target,p_starts,p_ends,p_publish)
$f$;
revoke all on function public.league_v21_admin_create_global_challenge(text,text,text,numeric,timestamptz,timestamptz,boolean)
from public,anon,authenticated;
grant execute on function public.league_v21_admin_create_global_challenge(text,text,text,numeric,timestamptz,timestamptz,boolean) to authenticated;
