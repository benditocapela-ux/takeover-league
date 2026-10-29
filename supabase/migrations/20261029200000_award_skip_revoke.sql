-- Etappe 14 (29.10.2026, Owner-Auftrag): Auszeichnungen bewusst nicht vergeben oder zurückziehen.
-- * «Diesmal nicht vergeben»: Für eine abgeschlossene Woche / einen Monat / ein Jahr halten Trainer oder Admin fest, dass es keine
--   Auszeichnung gibt (optional mit Grund). Solange das gilt, kann für diesen Zeitraum nicht vergeben werden. Wer es gewählt hat
--   oder der Admin hebt es wieder auf («Doch vergeben»); der Eintrag bleibt als Verlauf gespeichert.
-- * Zurückziehen: wie bisher (staff_revoke_card_award, mit Grund, wer vergeben hat oder der Admin). Neu listet die Übersicht alle
--   kürzlich vergebenen Auszeichnungen (Wochen 70 Tage, Monate 400 Tage, Jahre 800 Tage), damit auch ältere zurückgezogen werden können.
--   Mit Etappe 13 endet das Spezial-Design beim Zurückziehen sofort; die Symbole verschwinden ebenfalls (zurückgenommen zählt nicht).
-- * Vergeben und «nicht vergeben» für denselben Zeitraum schliessen sich aus (Sperre pro Zeitraum gegen gleichzeitige Klicks).
-- Keine bestehenden Daten werden geändert.

BEGIN;

DO $$ BEGIN
 IF to_regprocedure('league_private.card_award_until(uuid,text)') IS NULL OR to_regprocedure('public.staff_revoke_card_award(bigint,text)') IS NULL
    OR to_regprocedure('public.staff_card_award_overview()') IS NULL THEN
  RAISE EXCEPTION 'Voraussetzung fehlt: Auszeichnungs-Designs befristet (20261029190000)';
 END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.card_award_skips(
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 kind text NOT NULL CHECK (kind IN ('cotw','cotm','poty')),
 period_start date NOT NULL,
 period_end date NOT NULL CHECK (period_end>=period_start),
 note text CHECK (note IS NULL OR char_length(note)<=300),
 skipped_by uuid NOT NULL REFERENCES public.profiles(id),
 skipped_at timestamptz NOT NULL DEFAULT now(),
 undone_at timestamptz,
 undone_by uuid REFERENCES public.profiles(id)
);
CREATE UNIQUE INDEX IF NOT EXISTS card_award_skips_one_active ON public.card_award_skips(kind, period_start) WHERE undone_at IS NULL;
ALTER TABLE public.card_award_skips ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.card_award_skips FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION league_private.card_skip_json(s public.card_award_skips, viewer public.profiles)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $fn$
 SELECT CASE WHEN s.id IS NULL THEN NULL ELSE pg_catalog.jsonb_build_object('id',s.id,'kind',s.kind,'period_start',s.period_start,'period_end',s.period_end,
  'note',s.note,'skipped_at',s.skipped_at,'skipped_by',(SELECT p.display_name FROM public.profiles p WHERE p.id=s.skipped_by),
  'can_undo',viewer.role='admin' OR s.skipped_by=viewer.id) END
$fn$;
REVOKE ALL ON FUNCTION league_private.card_skip_json(public.card_award_skips,public.profiles) FROM PUBLIC, anon, authenticated;

-- Trainer/Admin: «Diesmal nicht vergeben» für einen abgeschlossenen Zeitraum.
CREATE OR REPLACE FUNCTION public.staff_skip_card_award(p_kind text, p_period_start date, p_note text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); today date := (now() AT TIME ZONE 'Europe/Zurich')::date; r daterange; n text; s public.card_award_skips;
BEGIN
 IF me.id IS NULL OR me.role NOT IN ('admin','coach') THEN RAISE EXCEPTION 'Nur Trainer und Admins' USING ERRCODE='42501'; END IF;
 IF coalesce(p_kind,'') NOT IN ('cotw','cotm','poty') THEN RAISE EXCEPTION 'Unbekannte Auszeichnung' USING ERRCODE='22023'; END IF;
 IF p_period_start IS NULL THEN RAISE EXCEPTION 'Bitte einen Zeitraum wählen' USING ERRCODE='22023'; END IF;
 r := league_private.card_period(p_kind,p_period_start);
 IF lower(r)<>p_period_start THEN RAISE EXCEPTION 'Der Zeitraum muss am Wochen-, Monats- oder Jahresanfang beginnen' USING ERRCODE='22023'; END IF;
 IF upper(r)-1 >= today THEN RAISE EXCEPTION 'Erst nach Ende des Zeitraums (ab %)', to_char(upper(r),'DD.MM.YYYY') USING ERRCODE='22023'; END IF;
 IF lower(r) < today - (CASE p_kind WHEN 'cotw' THEN 70 WHEN 'cotm' THEN 400 ELSE 800 END) THEN RAISE EXCEPTION 'Dieser Zeitraum liegt zu weit zurück' USING ERRCODE='22023'; END IF;
 n := NULLIF(pg_catalog.btrim(coalesce(p_note,'')),'');
 IF n IS NOT NULL AND char_length(n)>300 THEN RAISE EXCEPTION 'Begründung höchstens 300 Zeichen' USING ERRCODE='22023'; END IF;
 PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('card_award:'||p_kind||':'||lower(r)::text));
 IF EXISTS (SELECT 1 FROM public.card_awards x WHERE x.kind=p_kind AND x.period_start=lower(r) AND x.revoked_at IS NULL) THEN
  RAISE EXCEPTION 'Für diesen Zeitraum gibt es schon eine Auszeichnung – zuerst zurückziehen' USING ERRCODE='23505';
 END IF;
 IF EXISTS (SELECT 1 FROM public.card_award_skips x WHERE x.kind=p_kind AND x.period_start=lower(r) AND x.undone_at IS NULL) THEN
  RAISE EXCEPTION 'Für diesen Zeitraum ist «nicht vergeben» schon gewählt' USING ERRCODE='23505';
 END IF;
 INSERT INTO public.card_award_skips(kind,period_start,period_end,note,skipped_by) VALUES (p_kind,lower(r),upper(r)-1,n,me.id) RETURNING * INTO s;
 RETURN league_private.card_skip_json(s,me);
END;
$fn$;

-- «Doch vergeben»: hebt «nicht vergeben» auf (wer es gewählt hat oder der Admin). Der Eintrag bleibt als Verlauf.
CREATE OR REPLACE FUNCTION public.staff_unskip_card_award(p_skip_id bigint)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); s public.card_award_skips;
BEGIN
 IF me.id IS NULL OR me.role NOT IN ('admin','coach') THEN RAISE EXCEPTION 'Nur Trainer und Admins' USING ERRCODE='42501'; END IF;
 SELECT * INTO s FROM public.card_award_skips x WHERE x.id=p_skip_id FOR UPDATE;
 IF NOT FOUND OR s.undone_at IS NOT NULL THEN RAISE EXCEPTION 'Nicht gefunden oder schon aufgehoben' USING ERRCODE='22023'; END IF;
 IF me.role<>'admin' AND s.skipped_by<>me.id THEN RAISE EXCEPTION 'Nur wer es gewählt hat oder der Admin hebt es auf' USING ERRCODE='42501'; END IF;
 UPDATE public.card_award_skips x SET undone_at=now(), undone_by=me.id WHERE x.id=s.id RETURNING * INTO s;
 RETURN pg_catalog.jsonb_build_object('id',s.id,'kind',s.kind,'period_start',s.period_start,'undone',true);
END;
$fn$;

-- Übersicht: wie 7d, dazu pro Zeitraum «nicht vergeben» (skip) und alle kürzlich vergebenen Auszeichnungen zum Zurückziehen (recent).
CREATE OR REPLACE FUNCTION public.staff_card_award_overview()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); today date := (now() AT TIME ZONE 'Europe/Zurich')::date; res jsonb := '[]'::jsonb;
 k text; r daterange; prev daterange;
BEGIN
 IF me.id IS NULL OR me.role NOT IN ('admin','coach') THEN RAISE EXCEPTION 'Nur für Trainer und Admins' USING ERRCODE='42501'; END IF;
 FOREACH k IN ARRAY ARRAY['cotw','cotm','poty'] LOOP
  r := league_private.card_period(k,today);
  prev := league_private.card_period(k,lower(r)-1);
  res := res || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object('kind',k,'periods',pg_catalog.jsonb_build_array(
   pg_catalog.jsonb_build_object('start',lower(prev),'end',upper(prev)-1,'completed',true,'candidates',league_private.card_candidates(lower(prev),upper(prev)-1),
    'award',(SELECT league_private.card_award_json(a) FROM public.card_awards a WHERE a.kind=k AND a.period_start=lower(prev) AND a.revoked_at IS NULL),
    'skip',(SELECT league_private.card_skip_json(s,me) FROM public.card_award_skips s WHERE s.kind=k AND s.period_start=lower(prev) AND s.undone_at IS NULL)),
   pg_catalog.jsonb_build_object('start',lower(r),'end',upper(r)-1,'completed',false,'candidates',league_private.card_candidates(lower(r),LEAST(upper(r)-1,today)),
    'award',(SELECT league_private.card_award_json(a) FROM public.card_awards a WHERE a.kind=k AND a.period_start=lower(r) AND a.revoked_at IS NULL),
    'skip',NULL))));
 END LOOP;
 RETURN pg_catalog.jsonb_build_object('today',today,'kinds',res,
  'boxers',(SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id',p.id,'display_name',p.display_name) ORDER BY pg_catalog.lower(p.display_name))
   FROM public.profiles p WHERE p.is_active AND p.archived_at IS NULL AND p.role IN ('boxer','coach')),
  'recent',coalesce((SELECT pg_catalog.jsonb_agg(league_private.card_award_json(a) || pg_catalog.jsonb_build_object('can_revoke',me.role='admin' OR a.awarded_by=me.id)
     ORDER BY a.period_start DESC, a.id DESC)
   FROM public.card_awards a WHERE a.revoked_at IS NULL
    AND a.period_start >= today - (CASE a.kind WHEN 'cotw' THEN 70 WHEN 'cotm' THEN 400 ELSE 800 END)),'[]'::jsonb),
  'skips',coalesce((SELECT pg_catalog.jsonb_agg(league_private.card_skip_json(s,me) ORDER BY s.period_start DESC, s.id DESC)
   FROM public.card_award_skips s WHERE s.undone_at IS NULL
    AND s.period_start >= today - (CASE s.kind WHEN 'cotw' THEN 70 WHEN 'cotm' THEN 400 ELSE 800 END)),'[]'::jsonb));
END;
$fn$;

-- Vergeben: wie Etappe 13, dazu gesperrt, solange «nicht vergeben» gilt.
CREATE OR REPLACE FUNCTION public.staff_confirm_card_award(p_kind text, p_period_start date, p_profile_id uuid, p_note text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); t public.profiles; today date := (now() AT TIME ZONE 'Europe/Zurich')::date;
 r daterange; a public.card_awards; v integer; n text; label text; w daterange;
BEGIN
 IF me.id IS NULL OR me.role NOT IN ('admin','coach') THEN RAISE EXCEPTION 'Nur Trainer und Admins vergeben Auszeichnungen' USING ERRCODE='42501'; END IF;
 IF coalesce(p_kind,'') NOT IN ('cotw','cotm','poty') THEN RAISE EXCEPTION 'Unbekannte Auszeichnung' USING ERRCODE='22023'; END IF;
 IF p_period_start IS NULL THEN RAISE EXCEPTION 'Bitte einen Zeitraum wählen' USING ERRCODE='22023'; END IF;
 r := league_private.card_period(p_kind,p_period_start);
 IF lower(r)<>p_period_start THEN RAISE EXCEPTION 'Der Zeitraum muss am Wochen-, Monats- oder Jahresanfang beginnen' USING ERRCODE='22023'; END IF;
 IF upper(r)-1 >= today THEN RAISE EXCEPTION 'Erst nach Ende des Zeitraums vergeben (ab %)', to_char(upper(r),'DD.MM.YYYY') USING ERRCODE='22023'; END IF;
 IF lower(r) < today - (CASE p_kind WHEN 'cotw' THEN 70 WHEN 'cotm' THEN 400 ELSE 800 END) THEN RAISE EXCEPTION 'Dieser Zeitraum liegt zu weit zurück' USING ERRCODE='22023'; END IF;
 SELECT * INTO t FROM public.profiles p WHERE p.id=p_profile_id AND p.is_active AND p.archived_at IS NULL AND p.role IN ('boxer','coach');
 IF NOT FOUND THEN RAISE EXCEPTION 'Bitte einen aktiven Boxer wählen' USING ERRCODE='22023'; END IF;
 IF t.id=me.id THEN RAISE EXCEPTION 'Sich selbst auszeichnen geht nicht – das macht ein anderer Trainer' USING ERRCODE='42501'; END IF;
 n := NULLIF(pg_catalog.btrim(coalesce(p_note,'')),'');
 IF n IS NOT NULL AND char_length(n)>300 THEN RAISE EXCEPTION 'Begründung höchstens 300 Zeichen' USING ERRCODE='22023'; END IF;
 PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('card_award:'||p_kind||':'||lower(r)::text));
 IF EXISTS (SELECT 1 FROM public.card_awards x WHERE x.kind=p_kind AND x.period_start=lower(r) AND x.revoked_at IS NULL) THEN
  RAISE EXCEPTION 'Für diesen Zeitraum gibt es schon eine Auszeichnung – zuerst zurücknehmen' USING ERRCODE='23505';
 END IF;
 IF EXISTS (SELECT 1 FROM public.card_award_skips x WHERE x.kind=p_kind AND x.period_start=lower(r) AND x.undone_at IS NULL) THEN
  RAISE EXCEPTION 'Für diesen Zeitraum ist «nicht vergeben» gewählt – zuerst aufheben' USING ERRCODE='23505';
 END IF;
 SELECT coalesce(sum(tx.exp),0)::integer INTO v FROM public.point_transactions tx JOIN public.training_submissions s ON s.id=tx.submission_id AND s.status='approved'
 WHERE tx.boxer_id=t.id AND tx.effective_date BETWEEN lower(r) AND upper(r)-1;
 INSERT INTO public.card_awards(kind,period_start,period_end,profile_id,exp_in_period,note,awarded_by)
 VALUES (p_kind,lower(r),upper(r)-1,t.id,v,n,me.id) RETURNING * INTO a;
 label := CASE p_kind WHEN 'cotw' THEN 'Card of the Week' WHEN 'cotm' THEN 'Card of the Month' ELSE 'Player of the Year' END;
 w := league_private.card_award_window(a);
 INSERT INTO public.boxer_notifications(recipient_id,notification_type,title,message,target_path)
 VALUES (t.id,'achievement',label||'!','Glückwunsch! Du bist '||label||' ('||to_char(lower(r),'DD.MM.YYYY')||' – '||to_char(upper(r)-1,'DD.MM.YYYY')||').'
   ||CASE WHEN today < upper(w) THEN ' Dein Spezial-Design gilt bis '||to_char(upper(w)-1,'DD.MM.YYYY')||'.' ELSE '' END
   ||coalesce(' «'||n||'»',''),'/karten.html');
 RETURN league_private.card_award_json(a);
END;
$fn$;

REVOKE ALL ON FUNCTION public.staff_skip_card_award(text,date,text), public.staff_unskip_card_award(bigint),
 public.staff_card_award_overview(), public.staff_confirm_card_award(text,date,uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.staff_skip_card_award(text,date,text), public.staff_unskip_card_award(bigint),
 public.staff_card_award_overview(), public.staff_confirm_card_award(text,date,uuid,text) TO authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;
