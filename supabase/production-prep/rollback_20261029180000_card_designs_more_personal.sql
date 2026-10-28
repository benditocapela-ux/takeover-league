-- Rücknahme von 20261029180000_card_designs_more_personal.sql.
-- Bricht ab, sobald jemand ein neues Design gekauft hat oder ein eigenes Design gespeichert ist (dann zuerst mit dem Owner klären).
-- Sonst: Funktionen wie in 20261029120000 (wörtlich), neue Designs und die Freischaltart «personal» entfernt.
BEGIN;
DO $$ BEGIN
 IF EXISTS (SELECT 1 FROM public.card_design_purchases WHERE design_key IN ('comic','midnight','retro','marmor','dschungel','eiskristall','cyber','tiger','goldrausch','inferno'))
    OR (to_regclass('public.card_personal_designs') IS NOT NULL AND EXISTS (SELECT 1 FROM public.card_personal_designs)) THEN
  RAISE EXCEPTION 'Rücknahme abgebrochen: neue Designs gekauft oder eigene Designs gespeichert';
 END IF;
END $$;
DROP FUNCTION IF EXISTS public.get_my_personal_design();
DROP FUNCTION IF EXISTS public.save_my_personal_design(text,jsonb);
DROP FUNCTION IF EXISTS public.admin_list_personal_designs();
DROP FUNCTION IF EXISTS public.admin_set_personal_design(uuid,boolean);
CREATE OR REPLACE FUNCTION league_private.card_design_available(p uuid, d public.card_designs)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $fn$
 SELECT d.is_active AND CASE d.unlock
  WHEN 'start' THEN true
  WHEN 'rank' THEN league_private.card_rank_idx(p) >= pg_catalog.array_position(ARRAY['F','E','D','C','B','A','S'],d.min_rank)-1
  WHEN 'shop' THEN EXISTS (SELECT 1 FROM public.card_design_purchases x WHERE x.profile_id=p AND x.design_key=d.key)
  WHEN 'award' THEN EXISTS (SELECT 1 FROM public.card_awards a WHERE a.profile_id=p AND a.kind=d.award_kind AND a.revoked_at IS NULL)
  ELSE false END
$fn$;

CREATE OR REPLACE FUNCTION league_private.card_look(p uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE d public.card_designs;
BEGIN
 SELECT x.* INTO d FROM public.card_design_equipped e JOIN public.card_designs x ON x.key=e.design_key WHERE e.profile_id=p;
 IF d.key IS NULL OR NOT league_private.card_design_available(p,d) THEN SELECT * INTO d FROM public.card_designs WHERE key='classic'; END IF;
 RETURN pg_catalog.jsonb_build_object('key',d.key,'name',d.name,'design',d.design,
  'awards',coalesce((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('kind',a.kind,'period_start',a.period_start) ORDER BY a.period_start DESC)
    FROM public.card_awards a WHERE a.profile_id=p AND a.revoked_at IS NULL),'[]'::jsonb));
END;
$fn$;
REVOKE ALL ON FUNCTION league_private.card_design_available(uuid,public.card_designs), league_private.card_look(uuid) FROM PUBLIC, anon, authenticated;
DROP FUNCTION IF EXISTS league_private.card_personal_clean(jsonb);
DROP FUNCTION IF EXISTS league_private.card_personal_name(text);
DROP FUNCTION IF EXISTS league_private.card_patterns();
DROP TABLE IF EXISTS public.card_personal_designs;
-- Wer ein neues Design ausgewählt hatte, sieht wieder Klassisch (card_look fällt ohnehin zurück); die Auswahl wird umgestellt.
UPDATE public.card_design_equipped SET design_key='classic', updated_at=now()
 WHERE design_key IN ('stahl','kosmos','comic','midnight','retro','marmor','dschungel','eiskristall','cyber','tiger','goldrausch','inferno','eigen');
DELETE FROM public.card_designs WHERE key IN ('stahl','kosmos','comic','midnight','retro','marmor','dschungel','eiskristall','cyber','tiger','goldrausch','inferno','eigen');
ALTER TABLE public.card_designs DROP CONSTRAINT IF EXISTS card_designs_unlock_kind;
ALTER TABLE public.card_designs ADD CONSTRAINT card_designs_unlock_check CHECK (unlock IN ('start','rank','shop','award'));
NOTIFY pgrst, 'reload schema';
COMMIT;
