-- Read-only Postflight nach 20261028230000_club_schedule_tiers.sql (ändert nichts).
SELECT 'Stufen 60/15/15 und 40/12/12, Pflicht nur Wettkämpfer' AS check_name,
 (EXISTS (SELECT 1 FROM public.club_tiers WHERE tier='pflicht' AND exp=60 AND coins=15 AND pass_points=15 AND required_groups='{wettkampf}')
  AND EXISTS (SELECT 1 FROM public.club_tiers WHERE tier='ergaenzung' AND exp=40 AND coins=12 AND pass_points=12))::text AS ok
UNION ALL SELECT 'Stundenplan: 5 Einheiten Mo/Di/Mi/Do/Sa, 3 Pflicht', ((SELECT string_agg(dow::text||coalesce(tier,'-'),',' ORDER BY dow) FROM public.club_schedule)='1pflicht,2ergaenzung,3pflicht,4ergaenzung,6pflicht')::text
UNION ALL SELECT 'Vereinsarten markiert, Technisches Sparring inaktiv (30)', ((SELECT count(*) FROM public.training_types WHERE club_only)=5
  AND EXISTS (SELECT 1 FROM public.training_types WHERE name='Technisches Sparring' AND NOT is_active AND points=30))::text
UNION ALL SELECT 'Punktwerte der Trainingsarten unverändert', ((SELECT string_agg(name||'='||points,',' ORDER BY name) FROM public.training_types WHERE name IN ('Reguläres Boxtraining','Techniktraining','Pratzentraining','Sprint-Intervalle'))
  ='Pratzentraining=35,Reguläres Boxtraining=50,Sprint-Intervalle=40,Techniktraining=40')::text
UNION ALL SELECT 'Noch keine Einstufungen', (NOT EXISTS (SELECT 1 FROM public.training_submissions WHERE club_tier IS NOT NULL))::text
UNION ALL SELECT 'Neue Tabellen RLS, keine direkten Rechte', ((SELECT count(*) FROM pg_class WHERE relname IN ('club_tiers','club_schedule') AND relrowsecurity)=2
  AND NOT EXISTS (SELECT 1 FROM information_schema.role_table_grants WHERE table_schema='public' AND table_name IN ('club_tiers','club_schedule') AND grantee IN ('anon','authenticated','PUBLIC')))::text
UNION ALL SELECT '6 RPCs SECURITY DEFINER, nicht für anon', ((SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.prosecdef
  AND p.proconfig @> ARRAY['search_path=""'] AND p.proname IN ('staff_open_club_session','staff_update_gym_session','staff_set_training_tier','staff_training_tiers','get_club_schedule','admin_save_club_slot'))=6
  AND NOT has_function_privilege('anon','public.staff_update_gym_session(bigint,bigint,text)','EXECUTE') AND NOT has_function_privilege('anon','public.get_club_schedule()','EXECUTE'))::text
UNION ALL SELECT 'Hilfs- und Aktivierungsfunktionen gesperrt', (NOT has_function_privilege('authenticated','league_private.activate_club_tiers(uuid)','EXECUTE')
  AND NOT has_function_privilege('authenticated','league_private.apply_training_value(uuid,uuid,text,jsonb)','EXECUTE'))::text
UNION ALL SELECT 'Einreich-Schutz aktiv', EXISTS (SELECT 1 FROM pg_trigger WHERE tgname='league_training_insert_guard' AND tgrelid='public.training_submissions'::regclass)::text
UNION ALL SELECT 'Pflicht-Quest nur Wettkämpfer', EXISTS (SELECT 1 FROM public.quest_definitions WHERE key='pflicht' AND metric='pflicht_days' AND only_groups='{wettkampf}')::text
UNION ALL SELECT 'Referenz Trainings approved', (SELECT count(*)::text FROM public.training_submissions WHERE status='approved')
UNION ALL SELECT 'Referenz point_transactions n/exp/points', (SELECT count(*)||' / '||coalesce(sum(exp),0)||' / '||coalesce(sum(points),0) FROM public.point_transactions)
UNION ALL SELECT 'Flags gym_training / weekly_quests aus', (NOT EXISTS (SELECT 1 FROM public.league_feature_flags WHERE feature_key IN ('gym_training','weekly_quests') AND is_enabled))::text;
