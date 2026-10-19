-- TEST PROJECT ONLY! Not a production migration or Pages artifact.
-- Clones existing production function definitions WITHOUT touching production.
-- Must NOT be executed on production: requires the test-only sentinel table.
BEGIN;
DO $sentinel$ BEGIN
 IF to_regclass('public.league_test_boxers') IS NULL THEN
  RAISE EXCEPTION 'TEST-ONLY bootstrap: league_test_boxers sentinel missing';
 END IF;
END $sentinel$;
CREATE OR REPLACE FUNCTION public._notify_training_decision()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
 IF NEW.status NOT IN ('approved','rejected') OR NEW.status IS NOT DISTINCT FROM OLD.status THEN
  RETURN NEW;
 END IF;
 IF NOT EXISTS (SELECT 1 FROM public.league_feature_flags WHERE feature_key='notifications' AND is_enabled=true) THEN
  RETURN NEW;
 END IF;
 IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id=NEW.boxer_id AND role='boxer' AND is_active=true) THEN
  RETURN NEW;
 END IF;
 INSERT INTO public.boxer_notifications(recipient_id,notification_type,title,message,target_path)
 VALUES (
  NEW.boxer_id,
  CASE WHEN NEW.status='approved' THEN 'training_approved' ELSE 'training_rejected' END,
  CASE WHEN NEW.status='approved' THEN 'Training bestaetigt' ELSE 'Training abgelehnt' END,
  CASE WHEN NEW.status='approved' THEN 'Dein Training vom '||to_char(NEW.training_date,'DD.MM.YYYY')||' wurde bestaetigt.'
       ELSE 'Dein Training vom '||to_char(NEW.training_date,'DD.MM.YYYY')||' wurde abgelehnt.' END,
  '/boxer.html'
 );
 RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public._sync_one_auto_bonus(p_boxer_id uuid, p_code text, p_start date, p_end date, p_points integer, p_actor uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
 v_award public.automatic_bonus_awards%rowtype;
 v_tx uuid;
begin
 select * into v_award from public.automatic_bonus_awards
 where boxer_id=p_boxer_id and bonus_code=p_code and period_start=p_start
 for update;

 if not found then
   if p_points=0 then return; end if;
   insert into public.point_transactions
     (boxer_id,points,exp,category,description,effective_date,created_by)
   values (p_boxer_id,p_points,p_points,'automatic_bonus',p_code,p_end,p_actor)
   returning id into v_tx;
   insert into public.automatic_bonus_awards
     (boxer_id,bonus_code,period_start,period_end,points,exp,transaction_id)
   values (p_boxer_id,p_code,p_start,p_end,p_points,p_points,v_tx);
 else
   if v_award.points=p_points and v_award.exp=p_points
      and v_award.period_end=p_end then return; end if;
   if v_award.transaction_id is null then
     insert into public.point_transactions
       (boxer_id,points,exp,category,description,effective_date,created_by)
     values (p_boxer_id,p_points,p_points,'automatic_bonus',p_code,p_end,p_actor)
     returning id into v_tx;
   else
     v_tx:=v_award.transaction_id;
     update public.point_transactions
     set points=p_points,exp=p_points,effective_date=p_end
     where id=v_tx and boxer_id=p_boxer_id and category='automatic_bonus';
     if not found then raise exception 'Bonus ledger mismatch'; end if;
   end if;
   update public.automatic_bonus_awards
   set points=p_points,exp=p_points,period_end=p_end,transaction_id=v_tx
   where id=v_award.id;
 end if;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.admin_edit_training(p_submission_id uuid, p_boxer_id uuid, p_training_type_id bigint, p_training_date date, p_notes text, p_status text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
 v_admin public.profiles%rowtype;
 v_old public.training_submissions%rowtype;
 v_new public.training_submissions%rowtype;
 v_old_tx jsonb;
 v_new_tx jsonb;
 v_points integer;
 v_tx_id uuid;
BEGIN
 SELECT * INTO v_admin FROM public.profiles
 WHERE auth_user_id=(SELECT auth.uid()) AND role='admin' AND is_active=true;
 IF NOT FOUND THEN RAISE EXCEPTION 'Nur aktive Admins dürfen Trainings bearbeiten'; END IF;
 IF p_status NOT IN ('pending','approved','rejected') OR p_status IS NULL THEN
  RAISE EXCEPTION 'Ungültiger Status';
 END IF;
 IF p_boxer_id IS NULL OR p_training_type_id IS NULL OR p_training_date IS NULL THEN
  RAISE EXCEPTION 'Boxer, Trainingsart und Datum sind erforderlich';
 END IF;
 PERFORM 1 FROM public.profiles WHERE id=p_boxer_id AND role='boxer';
 IF NOT FOUND THEN RAISE EXCEPTION 'Boxer nicht gefunden'; END IF;
 SELECT points INTO v_points FROM public.training_types
 WHERE id=p_training_type_id AND is_active=true;
 IF NOT FOUND OR v_points IS NULL OR v_points<0 THEN
  RAISE EXCEPTION 'Trainingsart ungültig oder inaktiv';
 END IF;

 SELECT * INTO v_old FROM public.training_submissions
 WHERE id=p_submission_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Training nicht gefunden'; END IF;

 SELECT id INTO v_tx_id FROM public.point_transactions
 WHERE submission_id=p_submission_id ORDER BY created_at LIMIT 1 FOR UPDATE;
 SELECT to_jsonb(t) INTO v_old_tx FROM public.point_transactions t WHERE id=v_tx_id;
 IF (SELECT count(*) FROM public.point_transactions WHERE submission_id=p_submission_id)>1 THEN
  RAISE EXCEPTION 'Mehrere Punktebuchungen vorhanden: manuelle Prüfung erforderlich';
 END IF;

 UPDATE public.training_submissions SET
 boxer_id=p_boxer_id, training_type_id=p_training_type_id,
 training_date=p_training_date, notes=p_notes,
 status=p_status,
 reviewed_by=CASE WHEN p_status='pending' THEN null ELSE v_admin.id END,
 reviewed_at=CASE WHEN p_status='pending' THEN null ELSE now() END
 WHERE id=p_submission_id RETURNING * INTO v_new;

 IF v_tx_id IS NOT NULL THEN
  UPDATE public.point_transactions SET
   boxer_id=p_boxer_id,
   points=CASE WHEN p_status='approved' THEN v_points ELSE 0 END,
   exp=CASE WHEN p_status='approved' THEN v_points ELSE 0 END,
   effective_date=p_training_date,
   created_by=v_admin.id,
   description=CASE WHEN p_status='approved' THEN 'Training (admin-korrigiert)' ELSE 'Training (widerrufen)' END
  WHERE id=v_tx_id;
 ELSIF p_status='approved' THEN
  INSERT INTO public.point_transactions
  (boxer_id,submission_id,points,exp,category,description,effective_date,created_by)
  VALUES (p_boxer_id,p_submission_id,v_points,v_points,'training',
          'Training (admin-korrigiert)',p_training_date,v_admin.id)
  RETURNING id INTO v_tx_id;
 END IF;
 SELECT to_jsonb(t) INTO v_new_tx FROM public.point_transactions t WHERE id=v_tx_id;
 INSERT INTO public.training_audit
 (submission_id,changed_by,old_submission,new_submission,old_transaction,new_transaction)
 VALUES (p_submission_id,v_admin.id,to_jsonb(v_old),to_jsonb(v_new),v_old_tx,v_new_tx);

 -- Recalculate both sides of a transfer, and the affected dates/streaks.
 PERFORM public.recalculate_boxer_bonuses(v_old.boxer_id);
 IF v_old.boxer_id IS DISTINCT FROM p_boxer_id THEN
   PERFORM public.recalculate_boxer_bonuses(p_boxer_id);
 END IF;

 RETURN jsonb_build_object('status',p_status,
  'points',CASE WHEN p_status='approved' THEN v_points ELSE 0 END);
END;
$function$
;

CREATE OR REPLACE FUNCTION public.admin_edit_training_details(p_submission_id uuid, p_boxer_id uuid, p_training_type_id bigint, p_training_date date, p_notes text, p_status text, p_jogging_km numeric, p_technique_minutes integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_result jsonb;
begin
  -- Eingaben kontrollieren
  if p_jogging_km is not null
     and (p_jogging_km < 0 or p_jogging_km > 1000) then
    raise exception 'Ungültige Joggingdistanz';
  end if;

  if p_technique_minutes is not null
     and (p_technique_minutes < 0 or p_technique_minutes > 1440) then
    raise exception 'Ungültige Technikminuten';
  end if;

  -- Bestehende Adminfunktion inklusive Punkte,
  -- EXP, Audit und Bonusberechnung ausführen
  v_result := public.admin_edit_training(
    p_submission_id,
    p_boxer_id,
    p_training_type_id,
    p_training_date,
    p_notes,
    p_status
  );

  -- Zusätzliche Trainingsdetails speichern
  update public.training_submissions
  set
    jogging_km = p_jogging_km,
    technique_minutes = p_technique_minutes
  where id = p_submission_id;

  return v_result;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.recalculate_boxer_bonuses(p_boxer_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_admin_id uuid;
  v_is_internal boolean;
  v_start date;
  v_last date;
  v_week date;
  v_month date;
  v_day date;
  v_code text;
  v_points int;
  v_eligible boolean;
  v_prior_ok boolean;
  v_days int;
  v_count int;
  v_wanted int;
  v_award_id uuid;
  v_transaction_id uuid;
  v_period_end date;
  v_period_start date;
  v_is_month boolean;
  v_record record;
  v_changes int := 0;
begin
  -- SECURITY: only admin can call this RPC. The automatic trigger can also
  -- call it inside the transaction when executed as a security-definer owner.
  select id into v_admin_id
  from public.profiles
  where auth_user_id = (select auth.uid())
    and role = 'admin' and is_active = true
  limit 1;

  if v_admin_id is null then
    raise exception 'Nur aktive Admins dürfen Boni neu berechnen';
  end if;

  perform 1 from public.profiles where id=p_boxer_id and role='boxer';
  if not found then raise exception 'Boxer nicht gefunden'; end if;

  -- Serialize all bonus calculations for the same boxer.
  perform pg_advisory_xact_lock(hashtextextended(p_boxer_id::text, 47813));

  select date_trunc('week',min(training_date))::date
  into v_start
  from public.training_submissions where boxer_id=p_boxer_id;
  select greatest(current_date,max(training_date))
  into v_last
  from public.training_submissions where boxer_id=p_boxer_id;

  -- If all trainings were moved away, existing awards still need revocation.
  select case when v_start is null then min(period_start)
              when min(period_start) is null then v_start
              else least(v_start,min(period_start)) end into v_start
  from public.automatic_bonus_awards where boxer_id=p_boxer_id;
  if v_start is null then return jsonb_build_object('changes',0); end if;
  select greatest(coalesce(v_last,current_date),coalesce(max(period_end),current_date)) into v_last
  from public.automatic_bonus_awards where boxer_id=p_boxer_id;

  -- Week-based bonuses; loop through every week so previous-week streaks work.
  v_week := date_trunc('week',v_start)::date;
  while v_week <= v_last loop
    v_period_start:=v_week;
    v_period_end:=v_week+6;
    v_is_month:=false;

    for v_code,v_points in
      select * from (values
        ('perfect_attendance',10),('interval_warrior',20),
        ('on_fire',30),('iron_discipline',50),
        ('unbreakable',100),('complete_fighter',30)
      ) as r(code,pts)
    loop
      v_eligible:=false;
      if v_code='perfect_attendance' then
        select count(distinct extract(isodow from training_date))=3 into v_eligible
        from public.training_submissions
        where boxer_id=p_boxer_id and status='approved'
          and training_date between v_week and v_week+6
          and extract(isodow from training_date) in (1,3,6);
      elsif v_code='interval_warrior' then
        select count(*)>=2 into v_eligible
        from public.training_submissions s
        join public.training_types t on t.id=s.training_type_id
        where s.boxer_id=p_boxer_id and s.status='approved'
          and s.training_date between v_week and v_week+6
          and t.name='Sprint-Intervalle';
      elsif v_code='on_fire' then
        select
          (select count(distinct extract(isodow from training_date))=3
           from public.training_submissions
           where boxer_id=p_boxer_id and status='approved'
             and training_date between v_week and v_week+6
             and extract(isodow from training_date) in (1,3,6))
          and
          (select count(distinct extract(isodow from training_date))=3
           from public.training_submissions
           where boxer_id=p_boxer_id and status='approved'
             and training_date between v_week-7 and v_week-1
             and extract(isodow from training_date) in (1,3,6))
        into v_eligible;
      elsif v_code='iron_discipline' then
        select
          (select count(distinct training_date)>=4
           from public.training_submissions where boxer_id=p_boxer_id
           and status='approved' and training_date between v_week and v_week+6)
          and
          (select count(distinct training_date)>=4
           from public.training_submissions where boxer_id=p_boxer_id
           and status='approved' and training_date between v_week-7 and v_week-1)
        into v_eligible;
      elsif v_code='unbreakable' then
        select bool_and(day_count>=3) into v_eligible from (
          select count(distinct s.training_date) as day_count
          from generate_series(0,3) k(n)
          left join public.training_submissions s
            on s.boxer_id=p_boxer_id and s.status='approved'
           and s.training_date between (v_week-(k.n*7))
                                   and (v_week-(k.n*7)+6)
          group by k.n
        ) q;
      elsif v_code='complete_fighter' then
        select count(distinct t.name)=4 into v_eligible
        from public.training_submissions s
        join public.training_types t on t.id=s.training_type_id
        where s.boxer_id=p_boxer_id and s.status='approved'
          and s.training_date between v_week and v_week+6
          and t.name in ('Reguläres Boxtraining','Sparring',
                         'Krafttraining','Sprint-Intervalle');
      end if;
      v_wanted:=case when coalesce(v_eligible,false) then v_points else 0 end;
      perform public._sync_one_auto_bonus(
        p_boxer_id,v_code,v_period_start,v_period_end,v_wanted,v_admin_id);
    end loop;
    v_week:=v_week+7;
  end loop;

  -- Month-based Road Warrior
  v_month:=date_trunc('month',v_start)::date;
  while v_month <= v_last loop
    v_period_end:=(v_month+interval '1 month - 1 day')::date;
    select count(*)>=8 into v_eligible
    from public.training_submissions s
    join public.training_types t on t.id=s.training_type_id
    where s.boxer_id=p_boxer_id and s.status='approved'
      and s.training_date between v_month and v_period_end
      and t.name='Joggen';
    v_wanted:=case when v_eligible then 20 else 0 end;
    perform public._sync_one_auto_bonus(
      p_boxer_id,'road_warrior',v_month,v_period_end,v_wanted,v_admin_id);
    v_month:=(v_month+interval '1 month')::date;
  end loop;
  return jsonb_build_object('status','ok','boxer_id',p_boxer_id);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.review_training(p_submission_id uuid, p_decision text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_admin public.profiles%rowtype;
  v_submission public.training_submissions%rowtype;
  v_points integer;
BEGIN
  SELECT * INTO v_admin
  FROM public.profiles
  WHERE auth_user_id = (SELECT auth.uid())
    AND role = 'admin' AND is_active = true;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Nur aktive Admins dürfen Trainings prüfen.';
  END IF;

  IF p_decision IS NULL OR p_decision NOT IN ('approved','rejected') THEN
    RAISE EXCEPTION 'Ungültige Entscheidung.';
  END IF;

  SELECT * INTO v_submission
  FROM public.training_submissions
  WHERE id = p_submission_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Training nicht gefunden.'; END IF;
  IF v_submission.status <> 'pending' THEN
    RAISE EXCEPTION 'Dieses Training wurde bereits bearbeitet.';
  END IF;

  IF p_decision = 'approved' THEN
    SELECT points INTO v_points FROM public.training_types
    WHERE id = v_submission.training_type_id;
    IF v_points IS NULL OR v_points < 0 THEN
      RAISE EXCEPTION 'Kein gültiger Punktewert für diese Trainingsart.';
    END IF;
    INSERT INTO public.point_transactions
      (boxer_id,submission_id,points,exp,category,description,effective_date,created_by)
    VALUES
      (v_submission.boxer_id,v_submission.id,v_points,v_points,'training',
       'Bestätigtes Training',v_submission.training_date,v_admin.id);
  END IF;

  UPDATE public.training_submissions
  SET status = p_decision, reviewed_by = v_admin.id, reviewed_at = now()
  WHERE id = v_submission.id;

  -- This runs under the same authenticated admin request, in one transaction.
  PERFORM public.recalculate_boxer_bonuses(v_submission.boxer_id);

  RETURN jsonb_build_object(
    'submission_id',v_submission.id,
    'status',p_decision,
    'points_awarded',CASE WHEN p_decision='approved' THEN v_points ELSE 0 END
  );
END;
$function$
;
DO $sentinel$ BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname='trg_notify_training_decision' AND tgrelid='public.training_submissions'::regclass) THEN
 CREATE TRIGGER trg_notify_training_decision AFTER UPDATE OF status
 ON public.training_submissions FOR EACH ROW
 WHEN (NEW.status IS DISTINCT FROM OLD.status)
 EXECUTE FUNCTION public._notify_training_decision();
 END IF;
END $sentinel$;
DO $seed$
DECLARE test_user uuid;
BEGIN
 IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE role='coach' AND is_active AND auth_user_id IS NOT NULL) THEN
  SELECT p.id INTO test_user FROM public.profiles p
  JOIN auth.users au ON au.id=p.auth_user_id
  WHERE p.role='boxer' AND p.is_active ORDER BY p.id LIMIT 1;
  IF test_user IS NULL THEN RAISE EXCEPTION 'No linked active test boxer to promote to coach'; END IF;
  UPDATE public.profiles SET role='coach' WHERE id=test_user;
 END IF;
END $seed$;
COMMIT;
