-- Rücknahme von 20261029200000_award_skip_revoke.sql: «nicht vergeben» entfernen, Übersicht (7d) und Vergeben (Etappe 13) wörtlich zurück.
-- Bricht ab, sobald «nicht vergeben» schon benutzt wurde (der Verlauf würde sonst verloren gehen). Zurückziehen bleibt wie bisher.
BEGIN;
DO $$ BEGIN
 IF to_regclass('public.card_award_skips') IS NULL THEN RAISE EXCEPTION 'Etappe 14 ist nicht eingespielt'; END IF;
 IF EXISTS (SELECT 1 FROM public.card_award_skips) THEN RAISE EXCEPTION 'Rücknahme abgebrochen: «nicht vergeben» wurde schon benutzt'; END IF;
END $$;

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
    'award',(SELECT league_private.card_award_json(a) FROM public.card_awards a WHERE a.kind=k AND a.period_start=lower(prev) AND a.revoked_at IS NULL)),
   pg_catalog.jsonb_build_object('start',lower(r),'end',upper(r)-1,'completed',false,'candidates',league_private.card_candidates(lower(r),LEAST(upper(r)-1,today)),
    'award',(SELECT league_private.card_award_json(a) FROM public.card_awards a WHERE a.kind=k AND a.period_start=lower(r) AND a.revoked_at IS NULL)))));
 END LOOP;
 RETURN pg_catalog.jsonb_build_object('today',today,'kinds',res,
  'boxers',(SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id',p.id,'display_name',p.display_name) ORDER BY pg_catalog.lower(p.display_name))
   FROM public.profiles p WHERE p.is_active AND p.archived_at IS NULL AND p.role IN ('boxer','coach')));
END;
$fn$;

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
 IF EXISTS (SELECT 1 FROM public.card_awards x WHERE x.kind=p_kind AND x.period_start=lower(r) AND x.revoked_at IS NULL) THEN
  RAISE EXCEPTION 'Für diesen Zeitraum gibt es schon eine Auszeichnung – zuerst zurücknehmen' USING ERRCODE='23505';
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

DROP FUNCTION public.staff_skip_card_award(text,date,text);
DROP FUNCTION public.staff_unskip_card_award(bigint);
DROP FUNCTION league_private.card_skip_json(public.card_award_skips,public.profiles);
DROP TABLE public.card_award_skips;
NOTIFY pgrst, 'reload schema';
COMMIT;
