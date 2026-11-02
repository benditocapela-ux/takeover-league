-- Read-only points-duel queue for active staff. No scoring, payout or snapshot changes.
-- Dependency: 20261102084519_duel_points_shared_preview_close.sql and profiles.archived_at.
BEGIN;
CREATE INDEX IF NOT EXISTS league_duels_staff_cursor_idx ON public.league_duels(invited_at DESC,id DESC);

CREATE OR REPLACE FUNCTION league_v21_private.duel_staff_queue_core(
 p_state text,p_limit integer,p_before timestamptz,p_before_id uuid,p_search text,p_duel_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=''
AS $fn$
DECLARE actor uuid; wanted text:=coalesce(p_state,'due'); page_limit integer:=least(greatest(coalesce(p_limit,20),1),20);
 needle text:=btrim(coalesce(p_search,'')); observed_at timestamptz:=statement_timestamp(); result jsonb;
BEGIN
 SELECT id INTO actor FROM public.profiles WHERE auth_user_id=(SELECT auth.uid())
  AND is_active AND archived_at IS NULL AND role IN ('coach','admin');
 IF actor IS NULL THEN RAISE EXCEPTION 'Only active staff may read the duel queue' USING errcode='42501'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.league_feature_flags WHERE feature_key='duels' AND is_enabled)
 THEN RAISE EXCEPTION 'Duels are not enabled' USING errcode='42501'; END IF;
 IF wanted NOT IN ('all','open','due','ready','closed') OR length(needle)>80
  OR (p_before IS NULL)<>(p_before_id IS NULL)
  OR (p_before IS NOT NULL AND NOT isfinite(p_before))
  OR (p_duel_id IS NOT NULL AND p_before IS NOT NULL)
 THEN RAISE EXCEPTION 'Invalid queue filter or cursor' USING errcode='22023'; END IF;

 WITH base AS MATERIALIZED (
  SELECT d.*,c.display_name::text challenger_name,o.display_name::text opponent_name,
   ((d.status='pending' AND d.expires_at>observed_at) OR
    (d.status='active' AND d.ends_at>observed_at)) is_open,
   (d.status IN ('active','awaiting_reviews') AND d.ends_at<=observed_at) is_due
  FROM public.league_duels d
  JOIN public.profiles c ON c.id=d.challenger_id JOIN public.profiles o ON o.id=d.opponent_id
  -- This additive guard is order-independent with the later metric-routing column.
  -- Missing routing column means legacy points; every explicitly non-points row is excluded.
  WHERE coalesce(to_jsonb(d)->>'scoring_metric','points')='points'
   AND (p_duel_id IS NULL OR d.id=p_duel_id)
   AND (needle='' OR strpos(lower(c.display_name),lower(needle))>0 OR strpos(lower(o.display_name),lower(needle))>0)
 ), readiness AS MATERIALIZED (
  SELECT b.id,(league_v21_private.duel_close_preview_core(b.id,observed_at)->>'can_close')::boolean ready
  FROM base b WHERE b.is_due
 ), classified AS MATERIALIZED (
  SELECT b.*,r.ready FROM base b LEFT JOIN readiness r ON r.id=b.id
 ), counts AS (
  SELECT jsonb_build_object('all',count(*),'open',count(*) FILTER(WHERE is_open),
   'due',count(*) FILTER(WHERE is_due),'ready',count(*) FILTER(WHERE ready),
   'closed',count(*) FILTER(WHERE status='settled')) value FROM classified
 ), candidates AS MATERIALIZED (
  SELECT * FROM classified WHERE
   (wanted='all' OR wanted='open' AND is_open OR wanted='due' AND is_due
    OR wanted='ready' AND ready OR wanted='closed' AND status='settled')
   AND (p_before IS NULL OR (invited_at,id)<(p_before,p_before_id))
  ORDER BY invited_at DESC,id DESC LIMIT page_limit+1
 ), page AS MATERIALIZED (
  SELECT * FROM candidates ORDER BY invited_at DESC,id DESC LIMIT page_limit
 )
 SELECT jsonb_build_object(
  'items',coalesce((SELECT jsonb_agg(jsonb_build_object(
   'id',id,'challenger_id',challenger_id,'challenger_name',challenger_name,
   'opponent_id',opponent_id,'opponent_name',opponent_name,'status',status,
   'duration_days',duration_days,'invited_at',invited_at,'expires_at',expires_at,
   'accepted_at',accepted_at,'ends_at',ends_at,'settled_at',settled_at,
   'challenger_score',challenger_score,'opponent_score',opponent_score,'winner_id',winner_id,
   'close_ready',ready) ORDER BY invited_at DESC,id DESC) FROM page),'[]'::jsonb),
  'next_cursor',CASE WHEN (SELECT count(*) FROM candidates)>page_limit THEN
    (SELECT jsonb_build_object('before',invited_at,'before_id',id) FROM page ORDER BY invited_at,id LIMIT 1) END,
  'counts',(SELECT value FROM counts),'state',wanted,'search',needle,
  'duel_id',p_duel_id,'metric','points','limit',page_limit,'as_of',observed_at
 ) INTO result;
 RETURN result;
END $fn$;
REVOKE ALL ON FUNCTION league_v21_private.duel_staff_queue_core(text,integer,timestamptz,uuid,text,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION league_v21_private.duel_staff_queue_core(text,integer,timestamptz,uuid,text,uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.duel_v2_staff_queue(
 p_state text DEFAULT 'due',p_limit integer DEFAULT 20,p_before timestamptz DEFAULT NULL,
 p_before_id uuid DEFAULT NULL,p_search text DEFAULT NULL,p_duel_id uuid DEFAULT NULL)
RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER SET search_path=''
AS $fn$ SELECT league_v21_private.duel_staff_queue_core(p_state,p_limit,p_before,p_before_id,p_search,p_duel_id) $fn$;
REVOKE ALL ON FUNCTION public.duel_v2_staff_queue(text,integer,timestamptz,uuid,text,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.duel_v2_staff_queue(text,integer,timestamptz,uuid,text,uuid) TO authenticated;
COMMENT ON FUNCTION public.duel_v2_staff_queue(text,integer,timestamptz,uuid,text,uuid) IS
 'Staff-only read-only points queue, max20/keyset; counts match search/id before pagination. Open=unexpired invite or future active, due=ended active/awaiting, ready=shared preview can_close, closed=settled. Ready is a subset of due, not a payout promise.';
NOTIFY pgrst,'reload schema';
COMMIT;
