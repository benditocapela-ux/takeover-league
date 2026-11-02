-- Fresh disposable local database only. Run from repository root with psql -X -v ON_ERROR_STOP=1.
-- This replays real migrations against a synthetic foundation; it is not a Supabase login E2E test.
\set ON_ERROR_STOP on
\i tests/league-21-productionlike-baseline.sql
\i tests/league-21-migration-apply-disposable.sql
ALTER TABLE public.profiles ADD COLUMN archived_at timestamptz;
\i supabase/migrations/20261018211000_duel_v2_live_scores.sql
-- Minimal notification table matching the trigger's existing dependency. No real inbox data.
CREATE TABLE public.boxer_notifications(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),recipient_id uuid NOT NULL REFERENCES public.profiles(id),
 notification_type text NOT NULL,title text NOT NULL,message text NOT NULL,target_path text,
 created_at timestamptz NOT NULL DEFAULT now(),read_at timestamptz);
ALTER TABLE public.boxer_notifications ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.boxer_notifications FROM PUBLIC,anon,authenticated;
CREATE FUNCTION league_v21_private.notifications_enabled() RETURNS boolean
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path=''
 AS $$ SELECT EXISTS(SELECT 1 FROM public.league_feature_flags WHERE feature_key='notifications' AND is_enabled) $$;
REVOKE ALL ON FUNCTION league_v21_private.notifications_enabled() FROM PUBLIC,anon,authenticated;
INSERT INTO public.league_feature_flags(feature_key,display_name,is_enabled) VALUES('notifications','Fixture notifications',true);
\i supabase/migrations/20261028130000_duel_notifications.sql
\i supabase/migrations/20261102084519_duel_points_shared_preview_close.sql
\i tests/duel-points-preview-transaction.sql
-- Existing underdog and missing-ledger tests remain meaningful regression coverage.
\i tests/league-21-duel-underdog-transaction.sql
\i tests/league-21-duel-missing-ledger-transaction.sql
\echo Duel shared points / closure preview schema suite passed.
