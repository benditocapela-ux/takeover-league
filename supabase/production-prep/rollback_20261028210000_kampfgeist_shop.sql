-- Rollback für 20261028210000_kampfgeist_shop.sql
-- Entfernt nur die Funktionen. Katalog, Coin-Buch, Inventar, Ausrüstung, Einstellungen und das Flag bleiben erhalten.
-- Vorher das Flag kampfgeist_shop ausschalten. Gutgeschriebene Quest-Coins bleiben als gutgeschrieben markiert (Buchung bleibt im Coin-Buch).
BEGIN;
DROP FUNCTION IF EXISTS public.admin_update_kg_settings(integer,integer);
DROP FUNCTION IF EXISTS public.admin_update_kg_item(text,integer,text,boolean);
DROP FUNCTION IF EXISTS public.admin_adjust_coins(uuid,integer,text);
DROP FUNCTION IF EXISTS public.admin_kg_overview();
DROP FUNCTION IF EXISTS public.get_kg_look(text);
DROP FUNCTION IF EXISTS public.equip_kg_item(text,text);
DROP FUNCTION IF EXISTS public.buy_kg_item(text);
DROP FUNCTION IF EXISTS public.get_my_kampfgeist(boolean);
DROP FUNCTION IF EXISTS league_private.kg_look(uuid);
DROP FUNCTION IF EXISTS league_private.kg_item_json(public.kg_items);
DROP FUNCTION IF EXISTS league_private.kg_owns(uuid,public.kg_items,integer);
DROP FUNCTION IF EXISTS league_private.kg_balance(uuid);
DROP FUNCTION IF EXISTS league_private.kg_sync(uuid);
DROP FUNCTION IF EXISTS league_private.kg_rank_of(text);
DROP FUNCTION IF EXISTS league_private.kg_rank_idx(integer);
DROP FUNCTION IF EXISTS league_private.kg_level(bigint);
DROP FUNCTION IF EXISTS league_private.kg_exp(uuid);
NOTIFY pgrst, 'reload schema';
COMMIT;
