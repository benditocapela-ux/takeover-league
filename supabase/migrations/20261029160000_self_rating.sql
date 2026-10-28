-- Etappe 10 (28.10.2026, Owner-Auftrag): Selbsteinschätzung der Boxer, Freigabe durch den Trainer.
-- * Boxer schätzen sich alle 14 Tage selbst ein: dieselben 25 Kriterien wie die Coach-Bewertung, Regler 1–20, optional ein Kommentar.
--   Gezählt wird ab dem Kalendertag der letzten Selbsteinschätzung (Europe/Zurich), egal wie sie entschieden wurde.
-- * Jede Selbsteinschätzung wartet auf einen Trainer: freigeben (wird so zur Bewertung), anpassen (Trainer ändert Noten,
--   seine Version wird zur Bewertung) oder ablehnen (keine neue Bewertung). Erst dann ändert sich die Spielerkarte.
-- * Trainer und Admins bekommen beim Einreichen eine Mitteilung, der Boxer nach der Entscheidung.
-- * Neues Feature-Flag self_rating (AUS). Boxer brauchen self_rating und coach_ratings. Trainer und Admins sehen und
--   entscheiden auch bei ausgeschaltetem Flag (Vorschau).
-- Bestehende Bewertungen, Punkte, EXP und Trainings bleiben unverändert. staff_rate_boxer bleibt unverändert.
BEGIN;

DO $$ BEGIN
 IF to_regclass('public.boxer_ratings') IS NULL OR to_regclass('public.boxer_notifications') IS NULL
    OR to_regprocedure('league_private.rating_scores_valid(jsonb,integer)') IS NULL OR to_regprocedure('league_private.rating_summary(jsonb,integer)') IS NULL
    OR to_regprocedure('league_private.rating_row(uuid,integer)') IS NULL OR to_regprocedure('league_private.active_viewer()') IS NULL
    OR to_regprocedure('league_private.flag_on(text)') IS NULL THEN
  RAISE EXCEPTION 'Voraussetzung fehlt: Coach-Bewertung 1–20 (20261029090000), Mitteilungen';
 END IF;
END $$;

INSERT INTO public.league_feature_flags(feature_key,display_name,is_enabled)
VALUES ('self_rating','Selbsteinschätzung (alle 2 Wochen, Trainer gibt frei)',false) ON CONFLICT(feature_key) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.rating_self_reviews(
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 boxer_id uuid NOT NULL REFERENCES public.profiles(id),
 scores jsonb NOT NULL CHECK (jsonb_typeof(scores)='object'),
 scale smallint NOT NULL DEFAULT 20 CHECK (scale=20),
 note text CHECK (note IS NULL OR char_length(note) BETWEEN 1 AND 600),
 status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','adjusted','declined')),
 created_at timestamptz NOT NULL DEFAULT now(),
 decided_by uuid REFERENCES public.profiles(id),
 decided_at timestamptz,
 coach_note text CHECK (coach_note IS NULL OR char_length(coach_note) BETWEEN 1 AND 600),
 rating_id bigint REFERENCES public.boxer_ratings(id),
 CHECK ((status='pending') = (decided_at IS NULL)),
 CHECK ((status='pending') = (decided_by IS NULL)),
 CHECK ((status IN ('approved','adjusted')) = (rating_id IS NOT NULL)),
 CHECK (decided_by IS NULL OR decided_by<>boxer_id)
);
CREATE INDEX IF NOT EXISTS rating_self_reviews_boxer_idx ON public.rating_self_reviews(boxer_id, created_at DESC, id DESC);
CREATE UNIQUE INDEX IF NOT EXISTS rating_self_reviews_one_pending ON public.rating_self_reviews(boxer_id) WHERE status='pending';
ALTER TABLE public.rating_self_reviews ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.rating_self_reviews FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Hilfsfunktionen (nicht aufrufbar für Clients)
CREATE OR REPLACE FUNCTION league_private.self_review_state(p_boxer uuid)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $fn$
 WITH last AS (SELECT r.* FROM public.rating_self_reviews r WHERE r.boxer_id=p_boxer ORDER BY r.created_at DESC, r.id DESC LIMIT 1),
 nx AS (SELECT ((SELECT l.created_at FROM last l) AT TIME ZONE 'Europe/Zurich')::date + 14 AS d)
 SELECT pg_catalog.jsonb_build_object(
  'pending',(SELECT pg_catalog.jsonb_build_object('id',l.id,'created_at',l.created_at,'scores',l.scores,'scale',l.scale,'note',l.note,
     'overall',(league_private.rating_summary(l.scores,l.scale)->>'overall')::integer) FROM last l WHERE l.status='pending'),
  'last',(SELECT pg_catalog.jsonb_build_object('id',l.id,'status',l.status,'created_at',l.created_at,'decided_at',l.decided_at,
     'decided_by',(SELECT p.display_name FROM public.profiles p WHERE p.id=l.decided_by),'coach_note',l.coach_note,
     'overall',(league_private.rating_summary(l.scores,l.scale)->>'overall')::integer) FROM last l WHERE l.status<>'pending'),
  'next_allowed_on',(SELECT d FROM nx),
  'can_submit',NOT EXISTS (SELECT 1 FROM last l WHERE l.status='pending')
     AND ((SELECT d FROM nx) IS NULL OR (now() AT TIME ZONE 'Europe/Zurich')::date >= (SELECT d FROM nx)))
$fn$;

CREATE OR REPLACE FUNCTION league_private.self_review_notify_path(p_id bigint)
RETURNS text LANGUAGE sql IMMUTABLE SET search_path='' AS $fn$ SELECT '/bewertung.html?selbst='||p_id::text $fn$;

REVOKE ALL ON FUNCTION league_private.self_review_state(uuid), league_private.self_review_notify_path(bigint) FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Boxer: eigener Stand
CREATE OR REPLACE FUNCTION public.get_my_self_rating()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); on_ boolean;
BEGIN
 IF me.id IS NULL THEN RAISE EXCEPTION 'Bitte anmelden' USING ERRCODE='42501'; END IF;
 IF me.role NOT IN ('boxer','coach') THEN RETURN pg_catalog.jsonb_build_object('enabled',false,'reason','role'); END IF;
 on_ := league_private.flag_on('self_rating') AND league_private.flag_on('coach_ratings');
 IF NOT on_ THEN RETURN pg_catalog.jsonb_build_object('enabled',false,'reason','flag'); END IF;
 RETURN pg_catalog.jsonb_build_object('enabled',true,'interval_days',14) || league_private.self_review_state(me.id);
END;
$fn$;

-- Boxer: Selbsteinschätzung einreichen (alle 14 Tage, nur eine offene)
CREATE OR REPLACE FUNCTION public.submit_self_rating(p_scores jsonb, p_note text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); st jsonb; n text; new_id bigint; ov integer; cnt integer;
BEGIN
 IF me.id IS NULL THEN RAISE EXCEPTION 'Bitte anmelden' USING ERRCODE='42501'; END IF;
 IF me.role NOT IN ('boxer','coach') THEN RAISE EXCEPTION 'Selbst einschätzen können sich Boxer mit ihrem eigenen Konto' USING ERRCODE='42501'; END IF;
 IF NOT (league_private.flag_on('self_rating') AND league_private.flag_on('coach_ratings')) THEN
  RAISE EXCEPTION 'Die Selbsteinschätzung ist noch nicht freigeschaltet' USING ERRCODE='42501';
 END IF;
 PERFORM 1 FROM public.profiles p WHERE p.id=me.id FOR UPDATE;  -- ein Einreichen zur Zeit pro Konto
 IF NOT league_private.rating_scores_valid(p_scores,20) THEN RAISE EXCEPTION 'Bitte alle 25 Noten von 1 bis 20 vergeben' USING ERRCODE='22023'; END IF;
 n := NULLIF(pg_catalog.btrim(coalesce(p_note,'')),'');
 IF n IS NOT NULL AND pg_catalog.char_length(n)>600 THEN RAISE EXCEPTION 'Der Kommentar darf höchstens 600 Zeichen haben' USING ERRCODE='22023'; END IF;
 st := league_private.self_review_state(me.id);
 IF st->'pending' IS NOT NULL AND st->'pending'<>'null'::jsonb THEN
  RAISE EXCEPTION 'Deine letzte Selbsteinschätzung wartet noch auf deinen Trainer' USING ERRCODE='55000';
 END IF;
 IF NOT (st->>'can_submit')::boolean THEN
  RAISE EXCEPTION 'Die nächste Selbsteinschätzung ist ab % möglich', pg_catalog.to_char((st->>'next_allowed_on')::date,'DD.MM.YYYY') USING ERRCODE='55000';
 END IF;
 INSERT INTO public.rating_self_reviews(boxer_id,scores,scale,note) VALUES (me.id,p_scores,20,n) RETURNING id INTO new_id;
 ov := (league_private.rating_summary(p_scores,20)->>'overall')::integer;
 INSERT INTO public.boxer_notifications(recipient_id,notification_type,title,message,target_path)
 SELECT s.id,'general',pg_catalog.left('Selbsteinschätzung von '||me.display_name,160),
  pg_catalog.left(me.display_name||' hat sich selbst eingeschätzt (Gesamt '||ov||'). Bitte anpassen oder freigeben.',2000),
  league_private.self_review_notify_path(new_id)
 FROM public.profiles s WHERE s.role IN ('admin','coach') AND s.is_active AND s.archived_at IS NULL AND s.id<>me.id;
 GET DIAGNOSTICS cnt = ROW_COUNT;
 RETURN pg_catalog.jsonb_build_object('id',new_id,'overall',ov,'notified',cnt,'next_allowed_on',(now() AT TIME ZONE 'Europe/Zurich')::date + 14);
END;
$fn$;

-- Trainer: offene Selbsteinschätzungen mit aktueller Bewertung zum Vergleich
CREATE OR REPLACE FUNCTION public.staff_list_self_ratings()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer();
BEGIN
 IF me.id IS NULL OR me.role NOT IN ('admin','coach') THEN RAISE EXCEPTION 'Nur für Trainer und Admins' USING ERRCODE='42501'; END IF;
 RETURN coalesce((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
   'id',r.id,'boxer_id',p.id,'display_name',p.display_name,'created_at',r.created_at,'scores',r.scores,'scale',r.scale,'note',r.note,
   'overall',(league_private.rating_summary(r.scores,r.scale)->>'overall')::integer,'is_self',p.id=me.id,
   'current',(SELECT pg_catalog.jsonb_build_object('scores',b.scores,'scale',b.scale,'created_at',b.created_at,
      'overall',(league_private.rating_summary(b.scores,b.scale)->>'overall')::integer) FROM league_private.rating_row(p.id,0) b WHERE b.id IS NOT NULL))
   ORDER BY r.created_at, r.id)
  FROM public.rating_self_reviews r JOIN public.profiles p ON p.id=r.boxer_id
  WHERE r.status='pending' AND p.is_active AND p.archived_at IS NULL),'[]'::jsonb);
END;
$fn$;

-- Trainer: freigeben (approve), anpassen (adjust, mit eigenen Noten) oder ablehnen (decline)
CREATE OR REPLACE FUNCTION public.staff_decide_self_rating(p_id bigint, p_decision text, p_scores jsonb DEFAULT NULL, p_note text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); r public.rating_self_reviews; t public.profiles; n text; sc jsonb;
 rid bigint; before integer; ov integer; st text;
BEGIN
 IF me.id IS NULL OR me.role NOT IN ('admin','coach') THEN RAISE EXCEPTION 'Nur aktive Trainer und Admins dürfen entscheiden' USING ERRCODE='42501'; END IF;
 IF p_decision IS NULL OR p_decision NOT IN ('approve','adjust','decline') THEN RAISE EXCEPTION 'Unbekannte Entscheidung' USING ERRCODE='22023'; END IF;
 SELECT * INTO r FROM public.rating_self_reviews x WHERE x.id=p_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Diese Selbsteinschätzung gibt es nicht' USING ERRCODE='22023'; END IF;
 IF r.status<>'pending' THEN RAISE EXCEPTION 'Diese Selbsteinschätzung ist schon entschieden' USING ERRCODE='55000'; END IF;
 IF r.boxer_id=me.id THEN RAISE EXCEPTION 'Deine eigene Selbsteinschätzung gibt ein anderer Trainer frei' USING ERRCODE='42501'; END IF;
 SELECT * INTO t FROM public.profiles p WHERE p.id=r.boxer_id FOR UPDATE;
 IF NOT t.is_active OR t.archived_at IS NOT NULL OR t.role NOT IN ('boxer','coach') THEN RAISE EXCEPTION 'Der Boxer ist nicht mehr aktiv' USING ERRCODE='22023'; END IF;
 n := NULLIF(pg_catalog.btrim(coalesce(p_note,'')),'');
 IF n IS NOT NULL AND pg_catalog.char_length(n)>600 THEN RAISE EXCEPTION 'Der Kommentar darf höchstens 600 Zeichen haben' USING ERRCODE='22023'; END IF;
 before := (SELECT (league_private.rating_summary(b.scores,b.scale)->>'overall')::integer FROM league_private.rating_row(t.id,0) b WHERE b.id IS NOT NULL);
 IF p_decision='decline' THEN
  UPDATE public.rating_self_reviews SET status='declined', decided_by=me.id, decided_at=now(), coach_note=n WHERE id=r.id;
  st := 'declined';
 ELSE
  sc := CASE WHEN p_decision='approve' THEN r.scores ELSE p_scores END;
  IF NOT league_private.rating_scores_valid(sc,20) THEN RAISE EXCEPTION 'Bitte alle 25 Noten von 1 bis 20 vergeben' USING ERRCODE='22023'; END IF;
  st := CASE WHEN p_decision='approve' OR sc=r.scores THEN 'approved' ELSE 'adjusted' END;
  INSERT INTO public.boxer_ratings(boxer_id,rated_by,scores,note,scale) VALUES (t.id,me.id,sc,n,20) RETURNING id INTO rid;
  UPDATE public.rating_self_reviews SET status=st, decided_by=me.id, decided_at=now(), coach_note=n, rating_id=rid WHERE id=r.id;
  ov := (league_private.rating_summary(sc,20)->>'overall')::integer;
 END IF;
 -- Mitteilungen an die Trainer zu dieser Selbsteinschätzung sind erledigt
 UPDATE public.boxer_notifications SET read_at=now()
 WHERE target_path=league_private.self_review_notify_path(r.id) AND read_at IS NULL AND recipient_id<>t.id;
 INSERT INTO public.boxer_notifications(recipient_id,notification_type,title,message,target_path)
 VALUES (t.id,'coach_feedback',
  CASE st WHEN 'approved' THEN 'Deine Selbsteinschätzung ist freigegeben' WHEN 'adjusted' THEN 'Dein Trainer hat deine Selbsteinschätzung angepasst'
   ELSE 'Deine Selbsteinschätzung wurde nicht übernommen' END,
  pg_catalog.left(CASE WHEN st='declined' THEN 'Deine Spielerkarte bleibt, wie sie ist.' ELSE 'Neue Gesamtwertung: '||ov||'.' END
   ||coalesce(' Kommentar von '||me.display_name||': '||n,''),2000),'/bewertung.html');
 RETURN pg_catalog.jsonb_build_object('id',r.id,'status',st,'boxer',t.display_name,'rating_id',rid,'previous_overall',before,'overall',ov);
END;
$fn$;

REVOKE ALL ON FUNCTION public.get_my_self_rating(), public.submit_self_rating(jsonb,text), public.staff_list_self_ratings(),
 public.staff_decide_self_rating(bigint,text,jsonb,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_self_rating(), public.submit_self_rating(jsonb,text), public.staff_list_self_ratings(),
 public.staff_decide_self_rating(bigint,text,jsonb,text) TO authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
