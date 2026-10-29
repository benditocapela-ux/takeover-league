-- Rücknahme von 20261029240000_admin_bonus_exp.sql: entfernt die drei Bonus-Funktionen. Bricht ab, sobald Boni zurückgenommen wurden
-- (die Rücknahme-Tabelle würde sonst verloren gehen). Vergebene Boni bleiben als normale Buchungen (trainer_bonus) bestehen.
BEGIN;
DO $$ BEGIN
 IF to_regclass('public.bonus_revocations') IS NULL THEN RAISE EXCEPTION 'Etappe 18 ist nicht eingespielt'; END IF;
 IF EXISTS (SELECT 1 FROM public.bonus_revocations) THEN RAISE EXCEPTION 'Rücknahme abgebrochen: es gibt schon zurückgenommene Boni'; END IF;
END $$;
DROP FUNCTION public.admin_give_bonus(uuid,integer,boolean,text);
DROP FUNCTION public.admin_revoke_bonus(uuid,text);
DROP FUNCTION public.admin_list_bonuses(integer);
DROP TABLE public.bonus_revocations;
NOTIFY pgrst, 'reload schema';
COMMIT;
