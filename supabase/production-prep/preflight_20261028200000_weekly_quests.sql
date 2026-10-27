-- Read-only Preflight vor 20261028200000_weekly_quests.sql (ändert nichts).
SELECT 'Voraussetzung Etappe 2 (group_of, require_staff, week_monday, training_plans)' AS check_name,
  to_regprocedure('league_private.group_of(uuid)') IS NOT NULL AND to_regprocedure('league_private.require_staff()') IS NOT NULL
  AND to_regprocedure('league_private.week_monday(date)') IS NOT NULL AND to_regclass('public.training_plans') IS NOT NULL AS ok
UNION ALL SELECT 'league_duels mit challenger/opponent/accepted_at/status', (SELECT count(*) FROM information_schema.columns WHERE table_schema='public'
   AND table_name='league_duels' AND column_name IN ('challenger_id','opponent_id','accepted_at','status'))=4
UNION ALL SELECT 'training_submissions mit duration/technique/jogging', (SELECT count(*) FROM information_schema.columns WHERE table_schema='public'
   AND table_name='training_submissions' AND column_name IN ('duration_minutes','technique_minutes','jogging_km'))=3
UNION ALL SELECT 'Trainingsarten für Quests vorhanden', (SELECT count(*) FROM public.training_types WHERE is_active AND name IN ('Techniktraining',
   'Mobilität / Regeneration','Schattenboxen / Heimtraining','Seilspringen / Konditionszirkel','Joggen'))=5
   AND EXISTS (SELECT 1 FROM public.training_types WHERE category='Boxen')
UNION ALL SELECT 'Kategorie challenge_exp erlaubt', (SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conrelid='public.point_transactions'::regclass
   AND conname='point_transactions_category_check') LIKE '%challenge_exp%'
UNION ALL SELECT 'Neue Tabellen noch nicht vorhanden', to_regclass('public.quest_definitions') IS NULL AND to_regclass('public.quest_claims') IS NULL
UNION ALL SELECT 'Flag weekly_quests nicht eingeschaltet', NOT EXISTS (SELECT 1 FROM public.league_feature_flags WHERE feature_key='weekly_quests' AND is_enabled)
UNION ALL SELECT 'Keine Quest-Buchungen vorhanden', NOT EXISTS (SELECT 1 FROM public.point_transactions WHERE description LIKE 'Quest-Belohnung:%')
UNION ALL SELECT 'Keine gleichnamigen RPCs', NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public'
   AND p.proname IN ('get_my_quests','claim_quest','staff_quest_overview','admin_list_quests','admin_update_quest'));
-- Referenzwerte (vor und nach der Migration identisch): SELECT count(*) FROM public.training_submissions WHERE status='approved'; SELECT count(*), sum(exp) FROM public.point_transactions;
