-- VORSCHAU der Umwertung (ändert nichts): führt die Aktivierung in einer Transaktion aus, vergleicht pro Boxer
-- EXP, Level, Rang und Saisonpunkte vorher/nachher und bricht dann mit dem Ergebnis ab (alles wird zurückgerollt).
DO $preview$
DECLARE adm uuid; res jsonb; rows text;
BEGIN
 SELECT id INTO adm FROM public.profiles WHERE role='admin' AND is_active AND archived_at IS NULL ORDER BY id LIMIT 1;
 CREATE TEMP TABLE pv_before ON COMMIT DROP AS
  SELECT p.id, p.display_name, coalesce(sum(t.exp),0)::integer exp,
   coalesce(sum(t.points) FILTER (WHERE t.effective_date BETWEEN z.starts_on AND z.ends_on),0)::integer season
  FROM public.profiles p LEFT JOIN public.point_transactions t ON t.boxer_id=p.id
  LEFT JOIN LATERAL (SELECT starts_on, ends_on FROM public.league_seasons_v21 WHERE status='active' LIMIT 1) z ON true
  WHERE p.role IN ('boxer','coach') AND p.is_active AND p.archived_at IS NULL GROUP BY p.id, p.display_name;
 res := league_private.activate_club_tiers(adm);
 SELECT string_agg(format('%s: EXP %s→%s (Level %s→%s, Rang %s→%s) · Saisonpunkte %s→%s', b.display_name, b.exp, a.exp,
   league_private.kg_level(b.exp), league_private.kg_level(a.exp),
   (ARRAY['F','E','D','C','B','A','S'])[league_private.kg_rank_idx(league_private.kg_level(b.exp))+1],
   (ARRAY['F','E','D','C','B','A','S'])[league_private.kg_rank_idx(league_private.kg_level(a.exp))+1], b.season, a.season), E'\n' ORDER BY a.exp-b.exp DESC, b.display_name)
 INTO rows
 FROM pv_before b JOIN LATERAL (SELECT coalesce(sum(t.exp),0)::integer exp,
   coalesce(sum(t.points) FILTER (WHERE t.effective_date BETWEEN z.starts_on AND z.ends_on),0)::integer season
   FROM public.point_transactions t LEFT JOIN LATERAL (SELECT starts_on, ends_on FROM public.league_seasons_v21 WHERE status='active' LIMIT 1) z ON true
   WHERE t.boxer_id=b.id) a ON true;
 RAISE EXCEPTION E'VORSCHAU (zurückgerollt) %\n%', res, rows;
END
$preview$;
