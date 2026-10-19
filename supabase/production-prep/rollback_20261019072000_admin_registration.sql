-- NON-DESTRUCTIVE emergency rollback. Requires explicit new FREIGEBEN.
-- Never remove profiles, emails, point history, audit, or visibility filters.
BEGIN;
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user();
DROP FUNCTION IF EXISTS public.admin_list_profiles();
DROP FUNCTION IF EXISTS public.admin_set_profile_role(uuid,text);
DROP FUNCTION IF EXISTS public.admin_set_profile_active(uuid,boolean);
DROP FUNCTION IF EXISTS public.admin_set_profile_listed(uuid,boolean);
DROP FUNCTION IF EXISTS public.admin_set_profile_email(uuid,text);
-- Deliberately retain public RPC is_listed checks to avoid publishing private accounts.
COMMIT;
