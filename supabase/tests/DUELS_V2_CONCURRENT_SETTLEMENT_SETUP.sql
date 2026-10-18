-- Disposable PostgreSQL CI ONLY. Set up a due duel for concurrent reconciliation.
INSERT INTO public.profiles(id,auth_user_id,role,is_active) VALUES
 ('00000000-0000-0000-0000-0000000000a1','10000000-0000-0000-0000-0000000000a1','boxer',true),
 ('00000000-0000-0000-0000-0000000000b2','10000000-0000-0000-0000-0000000000b2','boxer',true),
 ('00000000-0000-0000-0000-0000000000c3','10000000-0000-0000-0000-0000000000c3','coach',true);
UPDATE public.league_feature_flags SET is_enabled=true WHERE feature_key='duels';
INSERT INTO public.league_duels(id,challenger_id,opponent_id,created_by,duration_days,status,accepted_at,ends_at)
VALUES ('40000000-0000-0000-0000-000000000001',
 '00000000-0000-0000-0000-0000000000a1',
 '00000000-0000-0000-0000-0000000000b2',
 '00000000-0000-0000-0000-0000000000c3',7,'active',
 now()-interval '8 days',now()-interval '1 day');
