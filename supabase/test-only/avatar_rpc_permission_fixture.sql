-- TEST-ONLY: minimal avatar RPC permission fixture. NOT the production function body.
create or replace function public.update_my_boxer_avatar(p_avatar_key text,p_avatar_url text)
returns void language plpgsql security definer set search_path='' as $$
begin
 if (select auth.uid()) is null then raise exception 'Login required' using errcode='42501';end if;
end;$$;
