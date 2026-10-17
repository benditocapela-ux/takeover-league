-- Takeover League 2.0 / additive EXP-level helpers (DEVELOPMENT ONLY)
-- Does not replace get_boxer_exp_level_rank, alter balances or touch existing tables.
-- Review and explicitly approve before executing against any Supabase database.
-- Formula: threshold(level) = 100*(level-1) + 25*(level-1)*(level-2)/2.
-- SECURITY INVOKER (default); no table reads, no SECURITY DEFINER.
BEGIN;

CREATE OR REPLACE FUNCTION public.league_level_start_exp_v2(p_level bigint)
RETURNS numeric
LANGUAGE sql
IMMUTABLE
STRICT
PARALLEL SAFE
SET search_path = public, pg_temp
AS $$
  SELECT CASE
    WHEN p_level < 1 THEN NULL::numeric
    ELSE 100::numeric * (p_level - 1)::numeric
       + 25::numeric * (p_level - 1)::numeric * (p_level - 2)::numeric / 2
  END;
$$;

CREATE OR REPLACE FUNCTION public.league_level_from_exp_v2(p_exp numeric)
RETURNS bigint
LANGUAGE plpgsql
IMMUTABLE
STRICT
PARALLEL SAFE
SET search_path = public, pg_temp
AS $$
DECLARE
  v_level numeric;
BEGIN
  IF p_exp < 0 THEN
    RETURN NULL;
  END IF;

  -- n = level - 1, solve 12.5*n^2 + 87.5*n <= exp.
  v_level := floor((sqrt(49::numeric + (8::numeric / 25) * p_exp) - 7) / 2) + 1;
  IF v_level > 9223372036854775807::numeric THEN
    RAISE EXCEPTION 'EXP value exceeds supported bigint level range';
  END IF;
  RETURN v_level::bigint;
END;
$$;

-- Intentionally do NOT replace existing RPCs or modify any point_transactions.
COMMIT;
