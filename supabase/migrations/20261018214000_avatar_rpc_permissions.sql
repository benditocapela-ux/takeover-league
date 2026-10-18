-- Narrow anon SECURITY DEFINER execution. Does not change function body or boxer privileges.
do $body$
begin
 if to_regprocedure('public.update_my_boxer_avatar(text,text)') is null then
  raise exception 'Required avatar RPC is absent; review environment before migration';
 end if;
 execute 'REVOKE ALL ON FUNCTION public.update_my_boxer_avatar(text,text) FROM PUBLIC,anon';
 execute 'GRANT EXECUTE ON FUNCTION public.update_my_boxer_avatar(text,text) TO authenticated';
end;
$body$;
