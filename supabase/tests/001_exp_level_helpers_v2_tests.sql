-- Run only AFTER reviewing/applying 001_exp_level_helpers_v2.sql in a test DB.
-- Read-only assertions; expected thresholds and boundary behavior.
DO $$
DECLARE
  r record;
  actual bigint;
BEGIN
  FOR r IN
    SELECT * FROM (VALUES
      (0::numeric,1::bigint),(99,1),(100,2),(224,2),(225,3),
      (374,3),(375,4),(549,4),(550,5),(749,5),(750,6),
      (1799,9),(1800,10),(2124,10),(2125,11),
      (6174,19),(6175,20),(6749,20),(6750,21),
      (515,4),(295,3),(220,2)
    ) AS t(exp, expected_level)
  LOOP
    SELECT public.league_level_from_exp_v2(r.exp) INTO actual;
    IF actual IS DISTINCT FROM r.expected_level THEN
      RAISE EXCEPTION 'Level test failed for % EXP: expected %, got %',r.exp,r.expected_level,actual;
    END IF;
  END LOOP;
  IF public.league_level_from_exp_v2(-1) IS NOT NULL THEN
    RAISE EXCEPTION 'Negative EXP should return NULL';
  END IF;
  IF public.league_level_start_exp_v2(0) IS NOT NULL THEN
    RAISE EXCEPTION 'Level 0 should return NULL';
  END IF;
  IF public.league_level_start_exp_v2(20) <> 6175 THEN
    RAISE EXCEPTION 'Level 20 threshold mismatch';
  END IF;
  RAISE NOTICE 'EXP level v2 assertions passed';
END $$;

-- Preview against existing data; NO writes.
SELECT p.display_name,
       COALESCE(SUM(t.exp),0) AS lifetime_exp,
       public.league_level_from_exp_v2(COALESCE(SUM(t.exp),0)) AS new_level
FROM public.profiles p
LEFT JOIN public.point_transactions t ON t.boxer_id = p.id
WHERE p.role = 'boxer'
GROUP BY p.id,p.display_name
ORDER BY lifetime_exp DESC,p.display_name;
