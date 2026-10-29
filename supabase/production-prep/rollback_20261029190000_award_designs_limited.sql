-- Rücknahme von 20261029190000_award_designs_limited.sql: Auszeichnungs-Designs wieder unbefristet (Stand Etappe 12).
-- Stellt card_design_available (Etappe 12), card_award_json, get_my_card_designs und staff_confirm_card_award (Etappe 7d) wörtlich wieder her
-- und entfernt die zwei neuen Hilfsfunktionen. Ändert keine Daten.
BEGIN;
DO $$ BEGIN
 IF to_regprocedure('league_private.card_award_until(uuid,text)') IS NULL THEN RAISE EXCEPTION 'Etappe 13 ist nicht eingespielt'; END IF;
END $$;

CREATE OR REPLACE FUNCTION league_private.card_design_available(p uuid, d public.card_designs)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $fn$
 SELECT d.is_active AND CASE d.unlock
  WHEN 'start' THEN true
  WHEN 'rank' THEN league_private.card_rank_idx(p) >= pg_catalog.array_position(ARRAY['F','E','D','C','B','A','S'],d.min_rank)-1
  WHEN 'shop' THEN EXISTS (SELECT 1 FROM public.card_design_purchases x WHERE x.profile_id=p AND x.design_key=d.key)
  WHEN 'award' THEN EXISTS (SELECT 1 FROM public.card_awards a WHERE a.profile_id=p AND a.kind=d.award_kind AND a.revoked_at IS NULL)
  WHEN 'personal' THEN EXISTS (SELECT 1 FROM public.card_personal_designs x WHERE x.profile_id=p AND x.is_active)
  ELSE false END
$fn$;

CREATE OR REPLACE FUNCTION league_private.card_award_json(a public.card_awards)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $fn$
 SELECT pg_catalog.jsonb_build_object('id',a.id,'kind',a.kind,'period_start',a.period_start,'period_end',a.period_end,
  'display_name',(SELECT p.display_name FROM public.profiles p WHERE p.id=a.profile_id),'exp',a.exp_in_period,'note',a.note,
  'awarded_at',a.awarded_at,'awarded_by',(SELECT p.display_name FROM public.profiles p WHERE p.id=a.awarded_by),
  'revoked',a.revoked_at IS NOT NULL)
$fn$;

CREATE OR REPLACE FUNCTION public.get_my_card_designs()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); ri integer; shop boolean;
BEGIN
 IF me.id IS NULL THEN RAISE EXCEPTION 'Bitte anmelden' USING ERRCODE='42501'; END IF;
 IF NOT league_private.flag_on('card_designs') AND me.role NOT IN ('admin','coach') THEN RETURN pg_catalog.jsonb_build_object('enabled',false); END IF;
 ri := league_private.card_rank_idx(me.id); shop := league_private.flag_on('kampfgeist_shop') OR me.role='admin';
 RETURN pg_catalog.jsonb_build_object('enabled',true,'preview',NOT league_private.flag_on('card_designs'),'display_name',me.display_name,
  'rank',(ARRAY['F','E','D','C','B','A','S'])[ri+1],'shop',shop,'coins',CASE WHEN shop THEN league_private.kg_balance(me.id) END,
  'look',league_private.card_look(me.id),
  'designs',(SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('key',d.key,'name',d.name,'description',d.description,'unlock',d.unlock,
     'min_rank',d.min_rank,'price',d.price,'award_kind',d.award_kind,'design',d.design,
     'available',league_private.card_design_available(me.id,d)) ORDER BY d.sort_order, d.key)
   FROM public.card_designs d WHERE d.is_active));
END;
$fn$;

CREATE OR REPLACE FUNCTION public.staff_confirm_card_award(p_kind text, p_period_start date, p_profile_id uuid, p_note text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); t public.profiles; today date := (now() AT TIME ZONE 'Europe/Zurich')::date;
 r daterange; a public.card_awards; v integer; n text; label text;
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
 INSERT INTO public.boxer_notifications(recipient_id,notification_type,title,message,target_path)
 VALUES (t.id,'achievement',label||'!','Glückwunsch! Du bist '||label||' ('||to_char(lower(r),'DD.MM.YYYY')||' – '||to_char(upper(r)-1,'DD.MM.YYYY')||'). Dein neues Karten-Design ist freigeschaltet.'||coalesce(' «'||n||'»',''),'/karten.html');
 RETURN league_private.card_award_json(a);
END;
$fn$;

REVOKE ALL ON FUNCTION league_private.card_design_available(uuid,public.card_designs), league_private.card_award_json(public.card_awards) FROM PUBLIC, anon, authenticated;
DROP FUNCTION league_private.card_award_until(uuid,text);
DROP FUNCTION league_private.card_award_window(public.card_awards);
NOTIFY pgrst, 'reload schema';
COMMIT;
