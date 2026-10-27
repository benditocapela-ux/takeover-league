-- Trainingsarten erweitern, Trainingsdauer und Bemerkung ab sofort Pflicht (27.10.2026, Owner-Auftrag).
--  * 9 neue Trainingsarten; «Sparring» heisst neu «Wettkampfsparring» (gleiche ID, gleiche Punkte).
--  * Bereiche (category) und Reihenfolge (sort_order) für eine gruppierte Auswahl im Formular.
--  * Neue Spalte duration_minutes (Trainingsdauer) für Meldungen und private Entwürfe.
--  * Pflicht ab heute, nur für NEUE Meldungen (BEFORE INSERT): Bemerkung mit mindestens 3 Zeichen und
--    Trainingsdauer 1–1440 Minuten. Bestehende Trainings, Punkte, EXP und Bestätigungen bleiben unverändert.
--  * Techniktraining: Die Trainingsdauer zählt zugleich als Technik-Minuten (keine doppelte Eingabe).
--  * Die Bonusregel «complete_fighter» erkannte Sparring am Namen; sie wird auf den neuen Namen nachgeführt,
--    damit kein bestehender Bonus bei einer Neuberechnung verloren geht.
-- Produktion nur über den regulären Migrationsweg und eine separate ausdrückliche FREIGABE.
BEGIN;

-- ---------------------------------------------------------------------------
-- Bereiche und Reihenfolge
-- ---------------------------------------------------------------------------
ALTER TABLE public.training_types ADD COLUMN IF NOT EXISTS category text;
ALTER TABLE public.training_types ADD COLUMN IF NOT EXISTS sort_order integer;
GRANT SELECT (category, sort_order) ON public.training_types TO authenticated;

-- ---------------------------------------------------------------------------
-- Sparring → Wettkampfsparring (gleiche ID und Punkte, Historie zeigt den neuen Namen)
-- ---------------------------------------------------------------------------
UPDATE public.training_types SET name='Wettkampfsparring'
 WHERE name='Sparring' AND NOT EXISTS (SELECT 1 FROM public.training_types WHERE name='Wettkampfsparring');

-- Bonusregeln, die Sparring am Namen erkennen, auf den neuen Namen nachführen (genau ein Vorkommen erwartet).
DO $bonus$
DECLARE fn text; def text; hits integer;
BEGIN
 FOREACH fn IN ARRAY ARRAY['public.recalculate_boxer_bonuses(uuid)','league_private.coach_training_bonus_refresh(uuid)'] LOOP
  IF to_regprocedure(fn) IS NULL THEN CONTINUE; END IF;
  def := pg_get_functiondef(to_regprocedure(fn));
  hits := (SELECT count(*) FROM regexp_matches(def, '''Sparring''', 'g'));
  IF hits = 0 AND position('''Wettkampfsparring''' IN def) > 0 THEN CONTINUE; END IF;  -- bereits nachgeführt
  IF hits <> 1 THEN RAISE EXCEPTION 'Unerwartete Definition von %: % Vorkommen von ''Sparring''', fn, hits; END IF;
  EXECUTE replace(def, '''Sparring''', '''Wettkampfsparring''');
 END LOOP;
END
$bonus$;

-- ---------------------------------------------------------------------------
-- Neue Trainingsarten (IDs fortlaufend; bestehende Namen werden nicht verändert)
-- ---------------------------------------------------------------------------
DO $types$
DECLARE r record;
BEGIN
 FOR r IN SELECT * FROM (VALUES
   ('Wettkampf',100),('Trainingslager / Camp-Tag',80),('Pratzentraining',35),('Sandsack / Rundenarbeit',30),
   ('Schattenboxen / Heimtraining',20),('Seilspringen / Konditionszirkel',20),
   ('Alternative Ausdauer (Rad, Schwimmen, Rudern)',20),('Trainingsassistenz',30),('Mobilität / Regeneration',15)
  ) v(name,points) LOOP
  IF NOT EXISTS (SELECT 1 FROM public.training_types t WHERE t.name=r.name) THEN
   INSERT INTO public.training_types(id,name,points,is_active)
   VALUES ((SELECT coalesce(max(id),0)+1 FROM public.training_types), r.name, r.points, true);
  ELSE
   -- Nach einem Rollback deaktivierte (weil schon genutzte) Arten wieder freischalten.
   UPDATE public.training_types t SET is_active=true WHERE t.name=r.name AND NOT t.is_active;
  END IF;
 END LOOP;
END
$types$;

UPDATE public.training_types t SET category=v.category, sort_order=v.sort_order
FROM (VALUES
 ('Wettkampf','Wettkampf',10),('Trainingslager / Camp-Tag','Wettkampf',20),('Wettkampfsparring','Wettkampf',30),
 ('Reguläres Boxtraining','Boxen',110),('Techniktraining','Boxen',120),('Pratzentraining','Boxen',130),
 ('Sandsack / Rundenarbeit','Boxen',140),('Schattenboxen / Heimtraining','Boxen',150),
 ('Sprint-Intervalle','Athletik',210),('Krafttraining','Athletik',220),('Seilspringen / Konditionszirkel','Athletik',230),
 ('Joggen','Ausdauer',310),('Alternative Ausdauer (Rad, Schwimmen, Rudern)','Ausdauer',320),
 ('Trainingsassistenz','Erholung & Team',410),('Mobilität / Regeneration','Erholung & Team',420)
) v(name,category,sort_order)
WHERE t.name=v.name;

-- ---------------------------------------------------------------------------
-- Trainingsdauer
-- ---------------------------------------------------------------------------
ALTER TABLE public.training_submissions ADD COLUMN IF NOT EXISTS duration_minutes integer;
ALTER TABLE public.training_drafts_v2 ADD COLUMN IF NOT EXISTS duration_minutes integer;
DO $chk$ BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='training_duration_minutes_valid') THEN
  ALTER TABLE public.training_submissions ADD CONSTRAINT training_duration_minutes_valid
   CHECK (duration_minutes IS NULL OR duration_minutes BETWEEN 1 AND 1440);
 END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='training_draft_duration_minutes_valid') THEN
  ALTER TABLE public.training_drafts_v2 ADD CONSTRAINT training_draft_duration_minutes_valid
   CHECK (duration_minutes IS NULL OR duration_minutes BETWEEN 1 AND 1440);
 END IF;
END $chk$;
GRANT SELECT (duration_minutes), INSERT (duration_minutes) ON public.training_submissions TO authenticated;
GRANT SELECT (duration_minutes), INSERT (duration_minutes), UPDATE (duration_minutes) ON public.training_drafts_v2 TO authenticated;

-- ---------------------------------------------------------------------------
-- Pflichtangaben für neue Meldungen (ab heute; bestehende Zeilen und Admin-Korrekturen unberührt)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION league_v21_private.require_training_details()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $fn$
begin
 NEW.notes := btrim(coalesce(NEW.notes,''));
 if char_length(NEW.notes) < 3 then
  raise exception 'Bitte eine Bemerkung zum Training eingeben (mindestens 3 Zeichen).' using errcode='23514';
 end if;
 if NEW.duration_minutes is null or NEW.duration_minutes not between 1 and 1440 then
  raise exception 'Bitte die Trainingsdauer in Minuten angeben (1–1440).' using errcode='23514';
 end if;
 if NEW.technique_minutes is null
    and exists (select 1 from public.training_types t where t.id=NEW.training_type_id and t.name='Techniktraining') then
  NEW.technique_minutes := NEW.duration_minutes;
 end if;
 return NEW;
end$fn$;
REVOKE ALL ON FUNCTION league_v21_private.require_training_details() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS league_v21_require_training_details ON public.training_submissions;
CREATE TRIGGER league_v21_require_training_details
 BEFORE INSERT ON public.training_submissions
 FOR EACH ROW EXECUTE FUNCTION league_v21_private.require_training_details();

NOTIFY pgrst, 'reload schema';
COMMIT;
