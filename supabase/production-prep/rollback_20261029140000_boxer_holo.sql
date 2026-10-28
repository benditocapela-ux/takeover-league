-- RÜCKNAHME 20261029140000_boxer_holo.sql (Boxer-Holo). Bricht ab, sobald jemand Holo-Items mit Coins gekauft hat
-- (sonst wären Coins ohne Gegenwert weg). Gespeicherte Holo-Einstellungen gehen bei der Rücknahme verloren.
BEGIN;
DO $$ BEGIN
 IF to_regclass('public.holo_owned') IS NOT NULL AND EXISTS (SELECT 1 FROM public.holo_owned WHERE ledger_id IS NOT NULL) THEN
  RAISE EXCEPTION 'Rücknahme abgebrochen: Es gibt bereits Holo-Käufe mit Coins. Bitte zuerst Coins erstatten.';
 END IF;
END $$;
DROP FUNCTION IF EXISTS public.get_my_holo();
DROP FUNCTION IF EXISTS public.save_my_holo(jsonb);
DROP FUNCTION IF EXISTS public.buy_holo_item(text);
DROP FUNCTION IF EXISTS public.buy_holo_bundle(text);
DROP FUNCTION IF EXISTS public.get_holo_looks(text[]);
DROP FUNCTION IF EXISTS public.admin_grant_holo_item(uuid,text,text);
DROP FUNCTION IF EXISTS league_private.holo_item_json(uuid,public.holo_items);
DROP FUNCTION IF EXISTS league_private.holo_clean(uuid,jsonb,boolean);
DROP FUNCTION IF EXISTS league_private.holo_has(uuid,public.holo_items);
DROP FUNCTION IF EXISTS league_private.holo_reward_label(jsonb);
DROP FUNCTION IF EXISTS league_private.holo_reward_ok(uuid,jsonb);
DROP TABLE IF EXISTS public.holo_config;
DROP TABLE IF EXISTS public.holo_owned;
DROP TABLE IF EXISTS public.holo_bundles;
DROP TABLE IF EXISTS public.holo_items;
DELETE FROM public.league_feature_flags WHERE feature_key='boxer_holo';
NOTIFY pgrst, 'reload schema';
COMMIT;
