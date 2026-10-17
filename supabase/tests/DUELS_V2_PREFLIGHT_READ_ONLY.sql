-- Takeover League 2.0: READ-ONLY schema compatibility preflight.
-- Do not run on production until owner approval. No writes or DDL.
-- Intended to be checked BEFORE review migrations 007-010.
BEGIN READ ONLY;

-- Required tables and columns; any missing row means a migration assumption is false.
WITH required(table_name,column_name) AS (
 VALUES
 ('profiles','id'),('profiles','auth_user_id'),('profiles','role'),
 ('profiles','is_active'),('profiles','display_name'),
 ('training_submissions','id'),('training_submissions','boxer_id'),
 ('training_submissions','status'),('training_submissions','training_date'),
 ('training_submissions','created_at'),
 ('point_transactions','id'),('point_transactions','boxer_id'),
 ('point_transactions','submission_id'),('point_transactions','points'),
 ('point_transactions','exp'),('point_transactions','category'),
 ('point_transactions','description'),('point_transactions','effective_date'),
 ('point_transactions','created_by'),
 ('league_feature_flags','feature_key'),('league_feature_flags','is_enabled')
)
SELECT r.table_name,r.column_name,
       CASE WHEN c.column_name IS NULL THEN 'MISSING' ELSE 'OK' END AS result,
       c.data_type,c.udt_name,c.is_nullable
FROM required r
LEFT JOIN information_schema.columns c
 ON c.table_schema='public'
 AND c.table_name=r.table_name AND c.column_name=r.column_name
ORDER BY r.table_name,r.column_name;

-- Existing category check must retain all existing accepted values.
SELECT con.conname,pg_get_constraintdef(con.oid) AS definition
FROM pg_constraint con
JOIN pg_class rel ON rel.oid=con.conrelid
JOIN pg_namespace n ON n.oid=rel.relnamespace
WHERE n.nspname='public' AND rel.relname='point_transactions'
 AND con.contype='c' ORDER BY con.conname;

-- Confirm whether point_transactions.created_by references profiles.id,
-- and whether training submission transaction IDs are unique.
SELECT con.conname,con.contype,pg_get_constraintdef(con.oid) AS definition
FROM pg_constraint con
JOIN pg_class rel ON rel.oid=con.conrelid
JOIN pg_namespace n ON n.oid=rel.relnamespace
WHERE n.nspname='public' AND rel.relname='point_transactions'
 AND con.contype IN ('f','u','p')
ORDER BY con.conname;

-- Existing role and transaction categories (counts only, no personal data).
SELECT role,count(*) AS profiles FROM public.profiles GROUP BY role ORDER BY role;
SELECT category,count(*) AS transactions
FROM public.point_transactions GROUP BY category ORDER BY category;
SELECT status,count(*) AS submissions
FROM public.training_submissions GROUP BY status ORDER BY status;

-- Flag structure and existing flags.
SELECT feature_key,is_enabled FROM public.league_feature_flags
ORDER BY feature_key;

ROLLBACK;
