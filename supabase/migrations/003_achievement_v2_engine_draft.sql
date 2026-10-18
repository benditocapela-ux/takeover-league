-- Takeover League 2.0 Achievement Engine – REVIEW DRAFT ONLY
-- Requires 002_achievement_v2_schema_draft.sql. DO NOT RUN ON LIVE DATABASE.
-- TODO before production: verify execution permissions, RLS, concurrency, historical
-- correction semantics, feature flag and complete rollback in an isolated test DB.

CREATE OR REPLACE FUNCTION public.recalculate_boxer_achievements_v2(p_boxer_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $fn$
DECLARE
  v_flag boolean;
  v_stats record;
  v_def record;
  v_earned boolean;
  v_exp integer;
  v_tx uuid;
  v_old_earned boolean;
  v_old_exp integer;
BEGIN
  SELECT is_enabled INTO v_flag FROM public.league_feature_flags
  WHERE feature_key='achievements';
  IF v_flag IS DISTINCT FROM true THEN RETURN; END IF;

  -- Serialize award reconciliation for a boxer; no untrusted direct EXECUTE grant.
  PERFORM 1 FROM public.profiles
  WHERE id=p_boxer_id AND role='boxer' AND is_active=true FOR UPDATE;
  IF NOT FOUND THEN RETURN; END IF;

  SELECT
    count(*)::bigint AS sessions,
    count(DISTINCT training_date)::bigint AS days,
    COALESCE(sum(jogging_km) FILTER (WHERE training_type_id=6),0)::numeric AS km,
    COALESCE(sum(technique_minutes) FILTER (WHERE training_type_id=3),0)::bigint AS minutes,
    count(*) FILTER (WHERE training_type_id=5)::bigint AS sprints,
    count(*) FILTER (WHERE training_type_id=2)::bigint AS sparring,
    count(*) FILTER (WHERE training_type_id=4)::bigint AS strength,
    LEAST(
      count(*) FILTER (WHERE training_type_id=1),
      count(*) FILTER (WHERE training_type_id=2),
      count(*) FILTER (WHERE training_type_id=3),
      count(*) FILTER (WHERE training_type_id=4),
      count(*) FILTER (WHERE training_type_id=5),
      count(*) FILTER (WHERE training_type_id=6)
    )::bigint AS complete
  INTO v_stats
  FROM public.training_submissions
  WHERE boxer_id=p_boxer_id AND status='approved';

  FOR v_def IN
    SELECT d.id,d.code,
      CASE WHEN d.code LIKE 'training_%' THEN v_stats.sessions
           WHEN d.code LIKE 'consistent_%' THEN v_stats.days
           WHEN d.code LIKE 'road_%' THEN v_stats.km
           WHEN d.code LIKE 'flash_%' THEN v_stats.sprints
           WHEN d.code LIKE 'technician_%' THEN v_stats.minutes
           WHEN d.code LIKE 'fighter_%' THEN v_stats.sparring
           WHEN d.code LIKE 'engine_%' THEN v_stats.strength
           WHEN d.code LIKE 'complete_%' THEN v_stats.complete
           ELSE 0 END AS progress,
      split_part(d.code,'_',2)::numeric AS threshold,
      CASE
        WHEN d.code IN ('training_10','consistent_10','road_25','flash_5',
          'technician_300','fighter_5','engine_10','complete_1') THEN 25
        WHEN d.code IN ('training_25','consistent_25','road_75','flash_15',
          'technician_900','fighter_15','engine_25','complete_3') THEN 60
        WHEN d.code IN ('training_50','consistent_60','road_150','flash_30',
          'technician_1800','fighter_30','engine_50','complete_7') THEN 125
        ELSE 250 END AS reward
    FROM public.achievement_definitions d
    WHERE d.is_active=true
      AND d.code ~ '^(training|consistent|road|flash|technician|fighter|engine|complete)_[0-9]+$'
    ORDER BY d.code
  LOOP
    v_earned := v_def.progress >= v_def.threshold;
    v_exp := CASE WHEN v_earned THEN v_def.reward ELSE 0 END;

    INSERT INTO public.achievement_exp_ledger(boxer_id,achievement_id,exp_amount,is_earned)
    VALUES(p_boxer_id,v_def.id,v_def.reward,false)
    ON CONFLICT(boxer_id,achievement_id) DO NOTHING;

    SELECT transaction_id,is_earned,exp_amount INTO v_tx,v_old_earned,v_old_exp
    FROM public.achievement_exp_ledger
    WHERE boxer_id=p_boxer_id AND achievement_id=v_def.id FOR UPDATE;

    -- Preserve transaction identity across revocation and re-earning.
    IF v_tx IS NULL AND v_earned THEN
      INSERT INTO public.point_transactions
        (boxer_id,submission_id,points,exp,category,description,effective_date)
      VALUES (p_boxer_id,NULL,0,v_def.reward,'achievement_exp',
              'Achievement: '||v_def.code,current_date)
      RETURNING id INTO v_tx;
    ELSIF v_tx IS NOT NULL AND v_old_earned IS DISTINCT FROM v_earned THEN
      UPDATE public.point_transactions
      SET exp=v_exp,points=0
      WHERE id=v_tx AND boxer_id=p_boxer_id AND category='achievement_exp';
      IF NOT FOUND THEN
        RAISE EXCEPTION 'Achievement transaction integrity failure: %',v_tx;
      END IF;
    END IF;

    UPDATE public.achievement_exp_ledger
    SET transaction_id=v_tx,is_earned=v_earned,exp_amount=v_def.reward,
        last_reconciled_at=now()
    WHERE boxer_id=p_boxer_id AND achievement_id=v_def.id;

    IF v_earned THEN
      INSERT INTO public.boxer_achievements
        (boxer_id,achievement_id,source_key,metadata)
      VALUES(p_boxer_id,v_def.id,'achievement_v2',
        jsonb_build_object('reward_exp',v_def.reward,'threshold',v_def.threshold))
      ON CONFLICT(boxer_id,achievement_id) DO NOTHING;
    ELSE
      DELETE FROM public.boxer_achievements
      WHERE boxer_id=p_boxer_id AND achievement_id=v_def.id;
    END IF;
  END LOOP;
END
$fn$;

CREATE OR REPLACE FUNCTION public._award_achievements_on_approval()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $fn$
BEGIN
  IF TG_OP='UPDATE' THEN
    IF OLD.boxer_id IS DISTINCT FROM NEW.boxer_id THEN
      PERFORM public.recalculate_boxer_achievements_v2(OLD.boxer_id);
    END IF;
    PERFORM public.recalculate_boxer_achievements_v2(NEW.boxer_id);
  ELSE
    PERFORM public.recalculate_boxer_achievements_v2(NEW.boxer_id);
  END IF;
  RETURN NEW;
END
$fn$;

-- Existing trigger only fires on status changes. Include metric, type, date, and boxer edits.
DROP TRIGGER IF EXISTS trg_auto_achievements_approved ON public.training_submissions;
CREATE TRIGGER trg_auto_achievements_approved
AFTER INSERT OR UPDATE OF status,boxer_id,training_type_id,training_date,jogging_km,technique_minutes
ON public.training_submissions FOR EACH ROW
EXECUTE FUNCTION public._award_achievements_on_approval();

-- CRITICAL: Do not enable the flag until production review is complete.
-- Backfill is a separate explicitly approved operation.
