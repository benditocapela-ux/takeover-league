-- PREPARED ONLY: allow coach role for V2 challenge administration.
-- Existing profiles and their roles remain unchanged.
BEGIN;
DO $$
DECLARE c record;
BEGIN
 SELECT conname,pg_get_constraintdef(oid) AS definition INTO c
 FROM pg_constraint WHERE conrelid='public.profiles'::regclass
 AND contype='c' AND pg_get_constraintdef(oid) LIKE '%role%'
 LIMIT 1;
 IF c.conname IS NULL OR c.definition NOT LIKE '%boxer%'
 OR c.definition NOT LIKE '%admin%' THEN
  RAISE EXCEPTION 'Unexpected profiles role constraint; abort';
 END IF;
 EXECUTE format('ALTER TABLE public.profiles DROP CONSTRAINT %I',c.conname);
END $$;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_role_check
CHECK (role IN ('boxer','admin','coach'));
COMMIT;
-- Verification: SELECT role,count(*) FROM public.profiles GROUP BY role;
