-- Paginated, server-filtered coach training history.
-- Additive only: no rows, points, EXP or feature flags are changed.
BEGIN;

CREATE OR REPLACE FUNCTION public.coach_list_training_history(
 p_search text DEFAULT NULL,
 p_boxer_id uuid DEFAULT NULL,
 p_training_type_id bigint DEFAULT NULL,
 p_from date DEFAULT NULL,
 p_to date DEFAULT NULL,
 p_status text DEFAULT NULL,
 p_limit integer DEFAULT 10,
 p_offset integer DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $fn$
DECLARE
 v_limit integer := LEAST(GREATEST(COALESCE(p_limit,10),1),50);
 v_offset integer := COALESCE(p_offset,0);
 v_search text := NULLIF(pg_catalog.btrim(COALESCE(p_search,'')),'');
 v_result jsonb;
BEGIN
 IF NOT EXISTS (
  SELECT 1 FROM public.profiles actor
  WHERE actor.auth_user_id=(SELECT auth.uid())
    AND actor.role IN ('admin','coach')
    AND actor.is_active IS TRUE
 ) THEN
  RAISE EXCEPTION 'Nur aktive Trainer dürfen die Trainingshistorie lesen'
   USING ERRCODE='42501';
 END IF;

 IF p_status IS NOT NULL AND p_status NOT IN ('pending','approved','rejected') THEN
  RAISE EXCEPTION 'Ungültiger Trainingsstatus' USING ERRCODE='22023';
 END IF;
 IF p_from IS NOT NULL AND p_to IS NOT NULL AND p_from>p_to THEN
  RAISE EXCEPTION 'Das Startdatum darf nicht nach dem Enddatum liegen' USING ERRCODE='22023';
 END IF;
 IF v_offset<0 THEN
  RAISE EXCEPTION 'Der Offset darf nicht negativ sein' USING ERRCODE='22023';
 END IF;
 IF pg_catalog.length(COALESCE(v_search,''))>120 THEN
  RAISE EXCEPTION 'Die Suche darf höchstens 120 Zeichen enthalten' USING ERRCODE='22023';
 END IF;

 SELECT pg_catalog.jsonb_build_object(
  'items', COALESCE((
   SELECT pg_catalog.jsonb_agg(
    pg_catalog.jsonb_build_object(
     'id', page.id,
     'boxer_id', page.boxer_id,
     'boxer_name', page.boxer_name,
     'training_type_id', page.training_type_id,
     'training_type_name', page.training_type_name,
     'training_date', page.training_date,
     'notes', page.notes,
     'status', page.status,
     'jogging_km', page.jogging_km,
     'technique_minutes', page.technique_minutes,
     'created_at', page.created_at,
     'reviewed_at', page.reviewed_at,
     'reviewed_by', page.reviewed_by
    ) ORDER BY page.training_date DESC, page.created_at DESC, page.id DESC
   )
   FROM (
    SELECT s.id,s.boxer_id,p.display_name::text AS boxer_name,
           s.training_type_id,t.name::text AS training_type_name,
           s.training_date,s.notes,s.status,s.jogging_km,s.technique_minutes,
           s.created_at,s.reviewed_at,s.reviewed_by
    FROM public.training_submissions s
    JOIN public.profiles p ON p.id=s.boxer_id
    JOIN public.training_types t ON t.id=s.training_type_id
    WHERE (p_boxer_id IS NULL OR s.boxer_id=p_boxer_id)
      AND (p_training_type_id IS NULL OR s.training_type_id=p_training_type_id)
      AND (p_from IS NULL OR s.training_date>=p_from)
      AND (p_to IS NULL OR s.training_date<=p_to)
      AND (p_status IS NULL OR s.status=p_status)
      AND (
       v_search IS NULL OR pg_catalog.strpos(
        pg_catalog.lower(
         COALESCE(p.display_name,'') || ' ' ||
         COALESCE(t.name,'') || ' ' ||
         COALESCE(s.notes,'') || ' ' ||
         COALESCE(s.training_date::text,'') || ' ' ||
         COALESCE(s.status,'')
        ),
        pg_catalog.lower(v_search)
       )>0
      )
    ORDER BY s.training_date DESC,s.created_at DESC,s.id DESC
    LIMIT v_limit OFFSET v_offset
   ) page
  ),'[]'::jsonb),
  'total_count',(
   SELECT pg_catalog.count(*)
   FROM public.training_submissions s
   JOIN public.profiles p ON p.id=s.boxer_id
   JOIN public.training_types t ON t.id=s.training_type_id
   WHERE (p_boxer_id IS NULL OR s.boxer_id=p_boxer_id)
     AND (p_training_type_id IS NULL OR s.training_type_id=p_training_type_id)
     AND (p_from IS NULL OR s.training_date>=p_from)
     AND (p_to IS NULL OR s.training_date<=p_to)
     AND (p_status IS NULL OR s.status=p_status)
     AND (
      v_search IS NULL OR pg_catalog.strpos(
       pg_catalog.lower(
        COALESCE(p.display_name,'') || ' ' ||
        COALESCE(t.name,'') || ' ' ||
        COALESCE(s.notes,'') || ' ' ||
        COALESCE(s.training_date::text,'') || ' ' ||
        COALESCE(s.status,'')
       ),
       pg_catalog.lower(v_search)
      )>0
     )
  ),
  'limit',v_limit,
  'offset',v_offset
 ) INTO v_result;

 RETURN v_result;
END
$fn$;

REVOKE ALL ON FUNCTION public.coach_list_training_history(text,uuid,bigint,date,date,text,integer,integer)
 FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.coach_list_training_history(text,uuid,bigint,date,date,text,integer,integer)
 TO authenticated;
COMMENT ON FUNCTION public.coach_list_training_history(text,uuid,bigint,date,date,text,integer,integer)
 IS 'Server-filtered, paginated training history for active admin/coach accounts. Read-only; returns at most 50 rows and never changes points or EXP.';

-- Ensure PostgREST can discover the newly installed RPC without waiting for a cache refresh.
NOTIFY pgrst, 'reload schema';
COMMIT;
