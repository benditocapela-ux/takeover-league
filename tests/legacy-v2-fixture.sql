-- Nachbau der alten V2-Strukturen aus der Produktion (Stand 28.10.2026, ausgelesen aus dem Katalog).
-- Tabellen, Prüfregeln, Indizes, RLS-Regeln und Rechte 1:1; die 16 alten Funktionen als Platzhalter mit gleicher
-- Signatur, gleichen Einstellungen und gleichen Rechten (nur postgres und service_role dürfen sie ausführen).
-- Wird vom Test tests/legacy-v2-archive-schema.sql und zum Vorbereiten des Testprojekts genutzt. Keine Produktionsdatei.

CREATE TABLE public.league_seasons (
 id uuid DEFAULT gen_random_uuid() NOT NULL,
 name text NOT NULL,
 description text DEFAULT ''::text NOT NULL,
 starts_on date NOT NULL,
 ends_on date NOT NULL,
 status text DEFAULT 'draft'::text NOT NULL,
 created_by uuid,
 created_at timestamp with time zone DEFAULT now() NOT NULL,
 updated_at timestamp with time zone DEFAULT now() NOT NULL,
 CONSTRAINT league_seasons_name_key UNIQUE (name),
 CONSTRAINT league_seasons_pkey PRIMARY KEY (id),
 CONSTRAINT league_seasons_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id),
 CONSTRAINT league_seasons_dates_valid CHECK ((ends_on >= starts_on)),
 CONSTRAINT league_seasons_description_check CHECK ((char_length(description) <= 4000)),
 CONSTRAINT league_seasons_name_check CHECK (((char_length(btrim(name)) >= 1) AND (char_length(btrim(name)) <= 120))),
 CONSTRAINT league_seasons_status_check CHECK ((status = ANY (ARRAY['draft'::text, 'scheduled'::text, 'active'::text, 'completed'::text, 'cancelled'::text])))
);
CREATE INDEX idx_league_seasons_dates ON public.league_seasons USING btree (starts_on, ends_on);
ALTER TABLE public.league_seasons ENABLE ROW LEVEL SECURITY;
CREATE POLICY coach_v3_league_seasons_select_enabled ON public.league_seasons AS PERMISSIVE FOR SELECT TO authenticated USING ((public.is_league_coach() AND ((EXISTS ( SELECT 1 FROM public.league_feature_flags WHERE ((league_feature_flags.feature_key = 'seasons'::text) AND league_feature_flags.is_enabled))) AND ((status = ANY (ARRAY['scheduled'::text, 'active'::text, 'completed'::text])) OR public.is_league_coach()))));
CREATE POLICY league_seasons_select_enabled ON public.league_seasons AS PERMISSIVE FOR SELECT TO authenticated USING (((EXISTS ( SELECT 1 FROM public.league_feature_flags WHERE ((league_feature_flags.feature_key = 'seasons'::text) AND league_feature_flags.is_enabled))) AND ((status = ANY (ARRAY['scheduled'::text, 'active'::text, 'completed'::text])) OR public.is_league_admin())));
GRANT SELECT ON public.league_seasons TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.league_seasons TO service_role;

CREATE TABLE public.league_challenges (
 id uuid DEFAULT gen_random_uuid() NOT NULL,
 created_by uuid NOT NULL,
 title text NOT NULL,
 description text DEFAULT ''::text NOT NULL,
 starts_on date NOT NULL,
 ends_on date NOT NULL,
 challenge_type text DEFAULT 'participation'::text NOT NULL,
 target_value numeric(12,2),
 status text DEFAULT 'draft'::text NOT NULL,
 created_at timestamp with time zone DEFAULT now() NOT NULL,
 updated_at timestamp with time zone DEFAULT now() NOT NULL,
 CONSTRAINT league_challenges_pkey PRIMARY KEY (id),
 CONSTRAINT league_challenges_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id),
 CONSTRAINT league_challenges_challenge_type_check CHECK ((challenge_type = ANY (ARRAY['participation'::text, 'training_count'::text, 'jogging_km'::text, 'technique_minutes'::text, 'custom'::text]))),
 CONSTRAINT league_challenges_date_order CHECK ((ends_on >= starts_on)),
 CONSTRAINT league_challenges_description_check CHECK ((char_length(description) <= 4000)),
 CONSTRAINT league_challenges_status_check CHECK ((status = ANY (ARRAY['draft'::text, 'scheduled'::text, 'active'::text, 'completed'::text, 'cancelled'::text]))),
 CONSTRAINT league_challenges_target_value_check CHECK (((target_value IS NULL) OR (target_value > (0)::numeric))),
 CONSTRAINT league_challenges_title_check CHECK (((char_length(btrim(title)) >= 1) AND (char_length(btrim(title)) <= 120)))
);
CREATE INDEX idx_league_challenges_dates ON public.league_challenges USING btree (starts_on, ends_on);
ALTER TABLE public.league_challenges ENABLE ROW LEVEL SECURITY;
CREATE POLICY coach_v3_league_challenges_select_enabled ON public.league_challenges AS PERMISSIVE FOR SELECT TO authenticated USING ((public.is_league_coach() AND ((EXISTS ( SELECT 1 FROM public.league_feature_flags WHERE ((league_feature_flags.feature_key = 'league_challenges'::text) AND league_feature_flags.is_enabled))) AND ((status = ANY (ARRAY['scheduled'::text, 'active'::text, 'completed'::text])) OR public.is_league_coach()))));
CREATE POLICY league_challenges_select_enabled ON public.league_challenges AS PERMISSIVE FOR SELECT TO authenticated USING (((EXISTS ( SELECT 1 FROM public.league_feature_flags WHERE ((league_feature_flags.feature_key = 'league_challenges'::text) AND league_feature_flags.is_enabled))) AND ((status = ANY (ARRAY['scheduled'::text, 'active'::text, 'completed'::text])) OR public.is_league_admin())));
GRANT SELECT ON public.league_challenges TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.league_challenges TO service_role;

CREATE TABLE public.boxer_coach_goals (
 id uuid DEFAULT gen_random_uuid() NOT NULL,
 boxer_id uuid NOT NULL,
 coach_id uuid NOT NULL,
 title text NOT NULL,
 description text DEFAULT ''::text NOT NULL,
 target_date date,
 status text DEFAULT 'planned'::text NOT NULL,
 created_at timestamp with time zone DEFAULT now() NOT NULL,
 updated_at timestamp with time zone DEFAULT now() NOT NULL,
 CONSTRAINT boxer_coach_goals_pkey PRIMARY KEY (id),
 CONSTRAINT boxer_coach_goals_boxer_id_fkey FOREIGN KEY (boxer_id) REFERENCES public.profiles(id),
 CONSTRAINT boxer_coach_goals_coach_id_fkey FOREIGN KEY (coach_id) REFERENCES public.profiles(id),
 CONSTRAINT boxer_coach_goals_description_check CHECK ((char_length(description) <= 4000)),
 CONSTRAINT boxer_coach_goals_status_check CHECK ((status = ANY (ARRAY['planned'::text, 'in_progress'::text, 'completed'::text, 'cancelled'::text]))),
 CONSTRAINT boxer_coach_goals_title_check CHECK (((char_length(btrim(title)) >= 1) AND (char_length(btrim(title)) <= 120)))
);
CREATE INDEX idx_boxer_coach_goals_boxer ON public.boxer_coach_goals USING btree (boxer_id, created_at DESC);
ALTER TABLE public.boxer_coach_goals ENABLE ROW LEVEL SECURITY;
CREATE POLICY coach_goals_insert_enabled ON public.boxer_coach_goals AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((EXISTS ( SELECT 1 FROM public.league_feature_flags WHERE ((league_feature_flags.feature_key = 'coach_goals'::text) AND league_feature_flags.is_enabled))) AND public.is_league_admin() AND (EXISTS ( SELECT 1 FROM public.profiles p WHERE ((p.id = boxer_coach_goals.coach_id) AND (p.auth_user_id = ( SELECT auth.uid() AS uid)) AND (p.role = 'admin'::text) AND p.is_active))) AND (EXISTS ( SELECT 1 FROM public.profiles p WHERE ((p.id = boxer_coach_goals.boxer_id) AND (p.role = 'boxer'::text) AND p.is_active)))));
CREATE POLICY coach_goals_select_enabled ON public.boxer_coach_goals AS PERMISSIVE FOR SELECT TO authenticated USING (((EXISTS ( SELECT 1 FROM public.league_feature_flags WHERE ((league_feature_flags.feature_key = 'coach_goals'::text) AND league_feature_flags.is_enabled))) AND (public.is_league_admin() OR (EXISTS ( SELECT 1 FROM public.profiles p WHERE ((p.id = boxer_coach_goals.boxer_id) AND (p.auth_user_id = ( SELECT auth.uid() AS uid)) AND (p.role = 'boxer'::text) AND p.is_active))))));
CREATE POLICY coach_v3_boxer_coach_goals_update ON public.boxer_coach_goals AS PERMISSIVE FOR UPDATE TO authenticated USING ((public.is_league_coach() AND (EXISTS ( SELECT 1 FROM public.profiles a WHERE ((a.auth_user_id = ( SELECT auth.uid() AS uid)) AND a.is_active AND (a.role = ANY (ARRAY['admin'::text, 'coach'::text])) AND (a.id = boxer_coach_goals.coach_id)))) AND (EXISTS ( SELECT 1 FROM public.league_feature_flags f WHERE ((f.feature_key = 'coach_goals'::text) AND f.is_enabled))))) WITH CHECK ((public.is_league_coach() AND (EXISTS ( SELECT 1 FROM public.profiles a WHERE ((a.auth_user_id = ( SELECT auth.uid() AS uid)) AND a.is_active AND (a.role = ANY (ARRAY['admin'::text, 'coach'::text])) AND (a.id = boxer_coach_goals.coach_id)))) AND (EXISTS ( SELECT 1 FROM public.league_feature_flags f WHERE ((f.feature_key = 'coach_goals'::text) AND f.is_enabled)))));
CREATE POLICY coach_v3_coach_goals_insert_enabled ON public.boxer_coach_goals AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((public.is_league_coach() AND ((EXISTS ( SELECT 1 FROM public.league_feature_flags WHERE ((league_feature_flags.feature_key = 'coach_goals'::text) AND league_feature_flags.is_enabled))) AND public.is_league_coach() AND (EXISTS ( SELECT 1 FROM public.profiles p WHERE ((p.id = boxer_coach_goals.coach_id) AND (p.auth_user_id = ( SELECT auth.uid() AS uid)) AND (p.role = ANY (ARRAY['admin'::text, 'coach'::text])) AND p.is_active))) AND (EXISTS ( SELECT 1 FROM public.profiles p WHERE ((p.id = boxer_coach_goals.boxer_id) AND (p.role = 'boxer'::text) AND p.is_active))))));
CREATE POLICY coach_v3_coach_goals_select_enabled ON public.boxer_coach_goals AS PERMISSIVE FOR SELECT TO authenticated USING ((public.is_league_coach() AND ((EXISTS ( SELECT 1 FROM public.league_feature_flags WHERE ((league_feature_flags.feature_key = 'coach_goals'::text) AND league_feature_flags.is_enabled))) AND (public.is_league_coach() OR (EXISTS ( SELECT 1 FROM public.profiles p WHERE ((p.id = boxer_coach_goals.boxer_id) AND (p.auth_user_id = ( SELECT auth.uid() AS uid)) AND (p.role = 'boxer'::text) AND p.is_active)))))));
GRANT INSERT, SELECT ON public.boxer_coach_goals TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.boxer_coach_goals TO service_role;

CREATE TABLE public.boxer_duels (
 id uuid DEFAULT gen_random_uuid() NOT NULL,
 created_by uuid NOT NULL,
 challenger_id uuid NOT NULL,
 opponent_id uuid NOT NULL,
 title text NOT NULL,
 description text DEFAULT ''::text NOT NULL,
 duel_type text DEFAULT 'training_count'::text NOT NULL,
 starts_on date NOT NULL,
 ends_on date NOT NULL,
 target_value numeric(12,2),
 challenger_progress numeric(12,2) DEFAULT 0 NOT NULL,
 opponent_progress numeric(12,2) DEFAULT 0 NOT NULL,
 status text DEFAULT 'draft'::text NOT NULL,
 winner_id uuid,
 created_at timestamp with time zone DEFAULT now() NOT NULL,
 updated_at timestamp with time zone DEFAULT now() NOT NULL,
 CONSTRAINT boxer_duels_pkey PRIMARY KEY (id),
 CONSTRAINT boxer_duels_challenger_id_fkey FOREIGN KEY (challenger_id) REFERENCES public.profiles(id),
 CONSTRAINT boxer_duels_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id),
 CONSTRAINT boxer_duels_opponent_id_fkey FOREIGN KEY (opponent_id) REFERENCES public.profiles(id),
 CONSTRAINT boxer_duels_winner_id_fkey FOREIGN KEY (winner_id) REFERENCES public.profiles(id),
 CONSTRAINT boxer_duels_challenger_progress_check CHECK ((challenger_progress >= (0)::numeric)),
 CONSTRAINT boxer_duels_date_order CHECK ((ends_on >= starts_on)),
 CONSTRAINT boxer_duels_description_check CHECK ((char_length(description) <= 4000)),
 CONSTRAINT boxer_duels_distinct_boxers CHECK ((challenger_id <> opponent_id)),
 CONSTRAINT boxer_duels_duel_type_check CHECK ((duel_type = ANY (ARRAY['training_count'::text, 'jogging_km'::text, 'technique_minutes'::text, 'custom'::text]))),
 CONSTRAINT boxer_duels_opponent_progress_check CHECK ((opponent_progress >= (0)::numeric)),
 CONSTRAINT boxer_duels_status_check CHECK ((status = ANY (ARRAY['draft'::text, 'invited'::text, 'accepted'::text, 'active'::text, 'completed'::text, 'declined'::text, 'cancelled'::text]))),
 CONSTRAINT boxer_duels_target_value_check CHECK (((target_value IS NULL) OR (target_value > (0)::numeric))),
 CONSTRAINT boxer_duels_title_check CHECK (((char_length(btrim(title)) >= 1) AND (char_length(btrim(title)) <= 120))),
 CONSTRAINT boxer_duels_winner_participant CHECK (((winner_id IS NULL) OR ((winner_id = challenger_id) OR (winner_id = opponent_id))))
);
CREATE INDEX idx_boxer_duels_opponent ON public.boxer_duels USING btree (opponent_id, created_at DESC);
CREATE INDEX idx_boxer_duels_status_dates ON public.boxer_duels USING btree (status, starts_on, ends_on);
CREATE INDEX idx_boxer_duels_challenger ON public.boxer_duels USING btree (challenger_id, created_at DESC);
ALTER TABLE public.boxer_duels ENABLE ROW LEVEL SECURITY;
CREATE POLICY boxer_duels_select_enabled ON public.boxer_duels AS PERMISSIVE FOR SELECT TO authenticated USING (((EXISTS ( SELECT 1 FROM public.league_feature_flags WHERE ((league_feature_flags.feature_key = 'boxer_duels'::text) AND league_feature_flags.is_enabled))) AND (public.is_league_admin() OR (EXISTS ( SELECT 1 FROM public.profiles p WHERE ((p.id = ANY (ARRAY[boxer_duels.challenger_id, boxer_duels.opponent_id])) AND (p.auth_user_id = ( SELECT auth.uid() AS uid)) AND (p.role = 'boxer'::text) AND p.is_active))))));
CREATE POLICY coach_v3_boxer_duels_select_enabled ON public.boxer_duels AS PERMISSIVE FOR SELECT TO authenticated USING ((public.is_league_coach() AND ((EXISTS ( SELECT 1 FROM public.league_feature_flags WHERE ((league_feature_flags.feature_key = 'boxer_duels'::text) AND league_feature_flags.is_enabled))) AND (public.is_league_coach() OR (EXISTS ( SELECT 1 FROM public.profiles p WHERE ((p.id = ANY (ARRAY[boxer_duels.challenger_id, boxer_duels.opponent_id])) AND (p.auth_user_id = ( SELECT auth.uid() AS uid)) AND (p.role = 'boxer'::text) AND p.is_active)))))));
GRANT SELECT ON public.boxer_duels TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.boxer_duels TO service_role;

CREATE TABLE public.boxer_palmares (
 id uuid DEFAULT gen_random_uuid() NOT NULL,
 boxer_id uuid NOT NULL,
 title text NOT NULL,
 event_name text DEFAULT ''::text NOT NULL,
 achievement_type text DEFAULT 'other'::text NOT NULL,
 result text DEFAULT ''::text NOT NULL,
 achievement_date date,
 description text DEFAULT ''::text NOT NULL,
 created_by uuid,
 created_at timestamp with time zone DEFAULT now() NOT NULL,
 CONSTRAINT boxer_palmares_pkey PRIMARY KEY (id),
 CONSTRAINT boxer_palmares_boxer_id_fkey FOREIGN KEY (boxer_id) REFERENCES public.profiles(id),
 CONSTRAINT boxer_palmares_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id),
 CONSTRAINT boxer_palmares_achievement_type_check CHECK ((achievement_type = ANY (ARRAY['fight'::text, 'tournament'::text, 'title'::text, 'medal'::text, 'other'::text]))),
 CONSTRAINT boxer_palmares_description_check CHECK ((char_length(description) <= 4000)),
 CONSTRAINT boxer_palmares_event_name_check CHECK ((char_length(event_name) <= 160)),
 CONSTRAINT boxer_palmares_result_check CHECK ((char_length(result) <= 160)),
 CONSTRAINT boxer_palmares_title_check CHECK (((char_length(btrim(title)) >= 1) AND (char_length(btrim(title)) <= 160)))
);
CREATE INDEX idx_boxer_palmares_boxer_date ON public.boxer_palmares USING btree (boxer_id, achievement_date DESC, created_at DESC);
ALTER TABLE public.boxer_palmares ENABLE ROW LEVEL SECURITY;
CREATE POLICY boxer_palmares_select_enabled ON public.boxer_palmares AS PERMISSIVE FOR SELECT TO authenticated USING (((EXISTS ( SELECT 1 FROM public.league_feature_flags f WHERE ((f.feature_key = 'palmares'::text) AND f.is_enabled))) AND (EXISTS ( SELECT 1 FROM public.profiles p WHERE ((p.auth_user_id = ( SELECT auth.uid() AS uid)) AND p.is_active AND ((p.role = 'admin'::text) OR (p.id = boxer_palmares.boxer_id)))))));
GRANT SELECT ON public.boxer_palmares TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.boxer_palmares TO service_role;

CREATE TABLE public.boxer_public_profile_details (
 boxer_id uuid NOT NULL,
 headline text DEFAULT ''::text NOT NULL,
 biography text DEFAULT ''::text NOT NULL,
 boxing_style text DEFAULT ''::text NOT NULL,
 favorite_quote text DEFAULT ''::text NOT NULL,
 is_published boolean DEFAULT false NOT NULL,
 created_at timestamp with time zone DEFAULT now() NOT NULL,
 updated_at timestamp with time zone DEFAULT now() NOT NULL,
 CONSTRAINT boxer_public_profile_details_pkey PRIMARY KEY (boxer_id),
 CONSTRAINT boxer_public_profile_details_boxer_id_fkey FOREIGN KEY (boxer_id) REFERENCES public.profiles(id) ON DELETE CASCADE,
 CONSTRAINT boxer_public_profile_details_biography_check CHECK ((char_length(biography) <= 1500)),
 CONSTRAINT boxer_public_profile_details_boxing_style_check CHECK ((char_length(boxing_style) <= 80)),
 CONSTRAINT boxer_public_profile_details_favorite_quote_check CHECK ((char_length(favorite_quote) <= 240)),
 CONSTRAINT boxer_public_profile_details_headline_check CHECK ((char_length(headline) <= 120))
);
ALTER TABLE public.boxer_public_profile_details ENABLE ROW LEVEL SECURITY;
CREATE POLICY public_profile_details_owner_or_admin_enabled ON public.boxer_public_profile_details AS PERMISSIVE FOR SELECT TO authenticated USING (((EXISTS ( SELECT 1 FROM public.league_feature_flags f WHERE ((f.feature_key = 'public_boxer_profiles'::text) AND f.is_enabled))) AND (EXISTS ( SELECT 1 FROM public.profiles p WHERE ((p.auth_user_id = ( SELECT auth.uid() AS uid)) AND p.is_active AND ((p.role = 'admin'::text) OR (p.id = boxer_public_profile_details.boxer_id)))))));
GRANT SELECT ON public.boxer_public_profile_details TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.boxer_public_profile_details TO service_role;

CREATE TABLE public.league_challenge_participants (
 id uuid DEFAULT gen_random_uuid() NOT NULL,
 challenge_id uuid NOT NULL,
 boxer_id uuid NOT NULL,
 progress_value numeric(12,2) DEFAULT 0 NOT NULL,
 status text DEFAULT 'joined'::text NOT NULL,
 joined_at timestamp with time zone DEFAULT now() NOT NULL,
 completed_at timestamp with time zone,
 CONSTRAINT league_challenge_participants_challenge_id_boxer_id_key UNIQUE (challenge_id, boxer_id),
 CONSTRAINT league_challenge_participants_pkey PRIMARY KEY (id),
 CONSTRAINT league_challenge_participants_boxer_id_fkey FOREIGN KEY (boxer_id) REFERENCES public.profiles(id),
 CONSTRAINT league_challenge_participants_challenge_id_fkey FOREIGN KEY (challenge_id) REFERENCES public.league_challenges(id),
 CONSTRAINT league_challenge_participants_progress_value_check CHECK ((progress_value >= (0)::numeric)),
 CONSTRAINT league_challenge_participants_status_check CHECK ((status = ANY (ARRAY['joined'::text, 'completed'::text, 'withdrawn'::text])))
);
CREATE INDEX idx_league_challenge_participants_boxer ON public.league_challenge_participants USING btree (boxer_id, challenge_id);
ALTER TABLE public.league_challenge_participants ENABLE ROW LEVEL SECURITY;
CREATE POLICY coach_v3_league_challenge_participants_select_enabled ON public.league_challenge_participants AS PERMISSIVE FOR SELECT TO authenticated USING ((public.is_league_coach() AND ((EXISTS ( SELECT 1 FROM public.league_feature_flags WHERE ((league_feature_flags.feature_key = 'league_challenges'::text) AND league_feature_flags.is_enabled))) AND (public.is_league_coach() OR (EXISTS ( SELECT 1 FROM public.profiles p WHERE ((p.id = league_challenge_participants.boxer_id) AND (p.auth_user_id = ( SELECT auth.uid() AS uid)) AND (p.role = 'boxer'::text) AND p.is_active)))))));
CREATE POLICY league_challenge_participants_select_enabled ON public.league_challenge_participants AS PERMISSIVE FOR SELECT TO authenticated USING (((EXISTS ( SELECT 1 FROM public.league_feature_flags WHERE ((league_feature_flags.feature_key = 'league_challenges'::text) AND league_feature_flags.is_enabled))) AND (public.is_league_admin() OR (EXISTS ( SELECT 1 FROM public.profiles p WHERE ((p.id = league_challenge_participants.boxer_id) AND (p.auth_user_id = ( SELECT auth.uid() AS uid)) AND (p.role = 'boxer'::text) AND p.is_active))))));
GRANT SELECT ON public.league_challenge_participants TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.league_challenge_participants TO service_role;

CREATE TABLE public.league_hall_of_fame (
 id uuid DEFAULT gen_random_uuid() NOT NULL,
 boxer_id uuid NOT NULL,
 season_id uuid,
 title text NOT NULL,
 description text DEFAULT ''::text NOT NULL,
 award_category text DEFAULT 'special'::text NOT NULL,
 awarded_on date DEFAULT CURRENT_DATE NOT NULL,
 created_by uuid,
 created_at timestamp with time zone DEFAULT now() NOT NULL,
 CONSTRAINT league_hall_of_fame_pkey PRIMARY KEY (id),
 CONSTRAINT league_hall_of_fame_boxer_id_fkey FOREIGN KEY (boxer_id) REFERENCES public.profiles(id),
 CONSTRAINT league_hall_of_fame_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id),
 CONSTRAINT league_hof_season_fk FOREIGN KEY (season_id) REFERENCES public.league_seasons(id),
 CONSTRAINT league_hall_of_fame_award_category_check CHECK ((award_category = ANY (ARRAY['season_winner'::text, 'milestone'::text, 'special'::text, 'legacy'::text]))),
 CONSTRAINT league_hall_of_fame_description_check CHECK ((char_length(description) <= 4000)),
 CONSTRAINT league_hall_of_fame_title_check CHECK (((char_length(btrim(title)) >= 1) AND (char_length(btrim(title)) <= 120)))
);
CREATE INDEX idx_league_hof_season ON public.league_hall_of_fame USING btree (season_id);
CREATE INDEX idx_league_hof_boxer_date ON public.league_hall_of_fame USING btree (boxer_id, awarded_on DESC);
ALTER TABLE public.league_hall_of_fame ENABLE ROW LEVEL SECURITY;
CREATE POLICY league_hof_select_enabled ON public.league_hall_of_fame AS PERMISSIVE FOR SELECT TO authenticated USING (((EXISTS ( SELECT 1 FROM public.league_feature_flags WHERE ((league_feature_flags.feature_key = 'hall_of_fame'::text) AND league_feature_flags.is_enabled))) AND (EXISTS ( SELECT 1 FROM public.profiles p WHERE ((p.auth_user_id = ( SELECT auth.uid() AS uid)) AND p.is_active)))));
GRANT SELECT ON public.league_hall_of_fame TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.league_hall_of_fame TO service_role;

CREATE TABLE public.league_season_results (
 id uuid DEFAULT gen_random_uuid() NOT NULL,
 season_id uuid NOT NULL,
 boxer_id uuid NOT NULL,
 rank_position integer,
 season_points integer DEFAULT 0 NOT NULL,
 season_exp integer DEFAULT 0 NOT NULL,
 approved_trainings integer DEFAULT 0 NOT NULL,
 calculated_at timestamp with time zone,
 CONSTRAINT league_season_results_season_id_boxer_id_key UNIQUE (season_id, boxer_id),
 CONSTRAINT league_season_results_pkey PRIMARY KEY (id),
 CONSTRAINT league_season_results_boxer_id_fkey FOREIGN KEY (boxer_id) REFERENCES public.profiles(id),
 CONSTRAINT league_season_results_season_id_fkey FOREIGN KEY (season_id) REFERENCES public.league_seasons(id),
 CONSTRAINT league_season_results_approved_trainings_check CHECK ((approved_trainings >= 0)),
 CONSTRAINT league_season_results_rank_position_check CHECK (((rank_position IS NULL) OR (rank_position > 0))),
 CONSTRAINT league_season_results_season_exp_check CHECK ((season_exp >= 0)),
 CONSTRAINT league_season_results_season_points_check CHECK ((season_points >= 0))
);
CREATE INDEX idx_league_season_results_boxer ON public.league_season_results USING btree (boxer_id, season_id);
CREATE INDEX idx_league_season_results_rank ON public.league_season_results USING btree (season_id, rank_position);
ALTER TABLE public.league_season_results ENABLE ROW LEVEL SECURITY;
CREATE POLICY coach_v3_league_season_results_select_enabled ON public.league_season_results AS PERMISSIVE FOR SELECT TO authenticated USING ((public.is_league_coach() AND ((EXISTS ( SELECT 1 FROM public.league_feature_flags WHERE ((league_feature_flags.feature_key = 'seasons'::text) AND league_feature_flags.is_enabled))) AND (public.is_league_coach() OR (EXISTS ( SELECT 1 FROM public.profiles p WHERE ((p.id = league_season_results.boxer_id) AND (p.auth_user_id = ( SELECT auth.uid() AS uid)) AND (p.role = 'boxer'::text) AND p.is_active)))))));
CREATE POLICY league_season_results_select_enabled ON public.league_season_results AS PERMISSIVE FOR SELECT TO authenticated USING (((EXISTS ( SELECT 1 FROM public.league_feature_flags WHERE ((league_feature_flags.feature_key = 'seasons'::text) AND league_feature_flags.is_enabled))) AND (public.is_league_admin() OR (EXISTS ( SELECT 1 FROM public.profiles p WHERE ((p.id = league_season_results.boxer_id) AND (p.auth_user_id = ( SELECT auth.uid() AS uid)) AND (p.role = 'boxer'::text) AND p.is_active))))));
GRANT SELECT ON public.league_season_results TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.league_season_results TO service_role;

-- Die 16 alten Funktionen (Platzhalter mit gleicher Signatur, gleichen Einstellungen und gleichen Rechten wie in der Produktion).
DO $fx$
DECLARE s text;
BEGIN
 FOREACH s IN ARRAY ARRAY[
  'boxer_join_league_challenge(p_challenge_id uuid)',
  'boxer_respond_duel_invite(p_duel_id uuid, p_accept boolean)',
  'coach_add_boxer_palmares(p_boxer_id uuid, p_title text, p_event_name text, p_achievement_type text, p_result text, p_achievement_date date, p_description text)',
  'coach_add_hall_of_fame_entry(p_boxer_id uuid, p_title text, p_description text, p_award_category text, p_season_id uuid, p_awarded_on date)',
  'coach_award_season_hall_of_fame(p_season_id uuid)',
  'coach_create_boxer_duel(p_challenger_id uuid, p_opponent_id uuid, p_title text, p_description text, p_duel_type text, p_starts_on date, p_ends_on date, p_target_value numeric)',
  'coach_create_league_challenge(p_title text, p_description text, p_starts_on date, p_ends_on date, p_challenge_type text, p_target_value numeric)',
  'coach_create_league_season(p_name text, p_starts_on date, p_ends_on date, p_description text)',
  'coach_finalize_boxer_duel(p_duel_id uuid)',
  'coach_finalize_league_season(p_season_id uuid)',
  'coach_set_boxer_duel_status(p_duel_id uuid, p_new_status text)',
  'coach_set_goal_status(p_goal_id uuid, p_new_status text)',
  'coach_set_league_challenge_status(p_challenge_id uuid, p_new_status text)',
  'coach_set_league_season_status(p_season_id uuid, p_new_status text)',
  'get_boxer_duel_score(p_duel_id uuid)',
  'get_league_challenge_progress(p_challenge_id uuid, p_boxer_id uuid)'] LOOP
  EXECUTE 'CREATE FUNCTION public.'||s||' RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public, pg_temp AS $b$'
   ||' BEGIN IF NOT EXISTS (SELECT 1 FROM public.league_feature_flags WHERE feature_key=''boxer_duels'' AND is_enabled) THEN'
   ||' RAISE EXCEPTION ''Altfunktion gesperrt''; END IF; RETURN ''{}''::jsonb; END $b$';
  EXECUTE 'REVOKE ALL ON FUNCTION public.'||split_part(s,'(',1)||'('||regexp_replace(split_part(s,'(',2),'p_[a-z_]+ ','','g')||' FROM PUBLIC, anon, authenticated';
  EXECUTE 'GRANT EXECUTE ON FUNCTION public.'||split_part(s,'(',1)||'('||regexp_replace(split_part(s,'(',2),'p_[a-z_]+ ','','g')||' TO service_role';
 END LOOP;
END $fx$;

INSERT INTO public.league_feature_flags(feature_key,display_name,is_enabled) VALUES
 ('boxer_duels','Boxer-Duelle',false),('coach_goals','Coach-Ziele',false),('hall_of_fame','Hall of Fame',false),
 ('league_challenges','Liga-Challenges',false),('palmares','Palmarès',false),('public_boxer_profiles','Öffentliche Boxerprofile',false),
 ('seasons','Saisons',false)
ON CONFLICT (feature_key) DO NOTHING;
