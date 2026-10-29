-- Etappe 18 (29.10.2026, Owner-Auftrag): Bonus-EXP vom Admin für besondere Sachen (z. B. Feedbackvideo geschickt, speziell aufgefallen).
-- * public.admin_give_bonus(): nur der Admin, an aktive Boxer/Trainer (nicht sich selbst). 1–500 EXP, Grund 3–120 Zeichen.
--   Pro Bonus wählbar, ob der gleiche Betrag auch als Monatspunkte zählt. Buchung in point_transactions (Kategorie trainer_bonus,
--   wie die bisherigen Trainerboni), Datum heute (Zürich), mit Admin als Buchender. Der Boxer bekommt eine Mitteilung.
-- * public.admin_revoke_bonus(): Rücknahme mit Grund als Gegenbuchung (Kategorie adjustment, gleiche EXP/Punkte negativ);
--   nichts wird gelöscht, jede Bonusbuchung lässt sich nur einmal zurücknehmen (bonus_revocations).
-- * public.admin_list_bonuses(): die letzten Boni mit Status.
-- Bestehende Buchungen bleiben unverändert.

BEGIN;

DO $$ BEGIN
 IF to_regprocedure('league_private.active_viewer()') IS NULL OR to_regclass('public.point_transactions') IS NULL
    OR to_regclass('public.boxer_notifications') IS NULL THEN
  RAISE EXCEPTION 'Voraussetzung fehlt: Profile, Punkte-Buchungen und Mitteilungen';
 END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.bonus_revocations(
 bonus_tx_id uuid PRIMARY KEY REFERENCES public.point_transactions(id),
 revoke_tx_id uuid NOT NULL UNIQUE REFERENCES public.point_transactions(id),
 reason text NOT NULL CHECK (char_length(reason) BETWEEN 3 AND 200),
 revoked_by uuid NOT NULL REFERENCES public.profiles(id),
 revoked_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.bonus_revocations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.bonus_revocations FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.admin_give_bonus(p_profile_id uuid, p_exp integer, p_with_points boolean, p_reason text)
RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); t public.profiles; r text := pg_catalog.btrim(coalesce(p_reason,''));
 pts integer; txid uuid; today date := (now() AT TIME ZONE 'Europe/Zurich')::date;
BEGIN
 IF me.id IS NULL OR me.role<>'admin' THEN RAISE EXCEPTION 'Nur der Admin vergibt Bonus-EXP' USING ERRCODE='42501'; END IF;
 IF p_profile_id=me.id THEN RAISE EXCEPTION 'Dem eigenen Konto kannst du keinen Bonus geben' USING ERRCODE='42501'; END IF;
 SELECT * INTO t FROM public.profiles p WHERE p.id=p_profile_id AND p.is_active AND p.archived_at IS NULL AND p.role IN ('boxer','coach');
 IF NOT FOUND THEN RAISE EXCEPTION 'Bitte einen aktiven Boxer wählen' USING ERRCODE='22023'; END IF;
 IF p_exp IS NULL OR p_exp NOT BETWEEN 1 AND 500 THEN RAISE EXCEPTION 'Bonus zwischen 1 und 500 EXP' USING ERRCODE='22023'; END IF;
 IF p_with_points IS NULL THEN RAISE EXCEPTION 'Bitte angeben, ob auch Punkte zählen' USING ERRCODE='22023'; END IF;
 IF pg_catalog.char_length(r) NOT BETWEEN 3 AND 120 OR r ~ '[<>]' THEN RAISE EXCEPTION 'Bitte einen Grund angeben (3–120 Zeichen, ohne < und >)' USING ERRCODE='22023'; END IF;
 pts := CASE WHEN p_with_points THEN p_exp ELSE 0 END;
 INSERT INTO public.point_transactions(boxer_id,points,exp,category,description,effective_date,created_by)
 VALUES (t.id,pts,p_exp,'trainer_bonus','Bonus: '||r,today,me.id) RETURNING id INTO txid;
 INSERT INTO public.boxer_notifications(recipient_id,notification_type,title,message,target_path)
 VALUES (t.id,'general','Bonus: +'||p_exp||' EXP',
  r||CASE WHEN pts>0 THEN ' · auch +'||pts||' Punkte für den Monat.' ELSE '' END,'/boxer.html');
 RETURN pg_catalog.jsonb_build_object('id',txid,'display_name',t.display_name,'exp',p_exp,'points',pts,'reason',r);
END;
$fn$;

CREATE OR REPLACE FUNCTION public.admin_revoke_bonus(p_tx_id uuid, p_reason text)
RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); b public.point_transactions; r text := pg_catalog.btrim(coalesce(p_reason,''));
 rid uuid; today date := (now() AT TIME ZONE 'Europe/Zurich')::date;
BEGIN
 IF me.id IS NULL OR me.role<>'admin' THEN RAISE EXCEPTION 'Nur der Admin nimmt Boni zurück' USING ERRCODE='42501'; END IF;
 IF pg_catalog.char_length(r) NOT BETWEEN 3 AND 200 THEN RAISE EXCEPTION 'Bitte einen Grund angeben (3–200 Zeichen)' USING ERRCODE='22023'; END IF;
 SELECT * INTO b FROM public.point_transactions x WHERE x.id=p_tx_id AND x.category='trainer_bonus' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Bonus nicht gefunden' USING ERRCODE='22023'; END IF;
 IF EXISTS (SELECT 1 FROM public.bonus_revocations v WHERE v.bonus_tx_id=b.id) THEN RAISE EXCEPTION 'Dieser Bonus ist schon zurückgenommen' USING ERRCODE='23505'; END IF;
 INSERT INTO public.point_transactions(boxer_id,points,exp,category,description,effective_date,created_by)
 VALUES (b.boxer_id,-b.points,-b.exp,'adjustment','Rücknahme Bonus: '||r,today,me.id) RETURNING id INTO rid;
 INSERT INTO public.bonus_revocations(bonus_tx_id,revoke_tx_id,reason,revoked_by) VALUES (b.id,rid,r,me.id);
 RETURN pg_catalog.jsonb_build_object('id',b.id,'revoke_id',rid,'exp',-b.exp,'points',-b.points);
END;
$fn$;

CREATE OR REPLACE FUNCTION public.admin_list_bonuses(p_limit integer DEFAULT 30)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer();
BEGIN
 IF me.id IS NULL OR me.role<>'admin' THEN RAISE EXCEPTION 'Nur für den Admin' USING ERRCODE='42501'; END IF;
 RETURN coalesce((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id',x.id,'display_name',p.display_name,'exp',x.exp,'points',x.points,
   'reason',pg_catalog.regexp_replace(x.description,'^Bonus: ',''),'date',x.effective_date,'created_at',x.created_at,
   'by',(SELECT q.display_name FROM public.profiles q WHERE q.id=x.created_by),
   'revoked',v.bonus_tx_id IS NOT NULL,'revoke_reason',v.reason) ORDER BY x.created_at DESC, x.id)
  FROM (SELECT * FROM public.point_transactions t WHERE t.category='trainer_bonus' ORDER BY t.created_at DESC, t.id
        LIMIT LEAST(GREATEST(coalesce(p_limit,30),1),100)) x
  JOIN public.profiles p ON p.id=x.boxer_id
  LEFT JOIN public.bonus_revocations v ON v.bonus_tx_id=x.id),'[]'::jsonb);
END;
$fn$;

REVOKE ALL ON FUNCTION public.admin_give_bonus(uuid,integer,boolean,text), public.admin_revoke_bonus(uuid,text), public.admin_list_bonuses(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_give_bonus(uuid,integer,boolean,text), public.admin_revoke_bonus(uuid,text), public.admin_list_bonuses(integer) TO authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;
