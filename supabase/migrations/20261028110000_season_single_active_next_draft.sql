-- Saisonverwaltung vervollständigen (27.10.2026).
--  * Serverseitig nie zwei aktive Saisons (vorher nur im League Manager gesperrt).
--  * Beim Saisonabschluss wird automatisch die Folgesaison als ENTWURF vorbereitet (gleiche Länge, direkt
--    anschliessend), falls noch keine spätere Saison existiert. Aktivieren bleibt ein Admin-Schritt
--    (Owner-Entscheid 27.10.2026: «nur als Entwurf bereitlegen»).
-- Basis: season_transition_core aus 20261027120000 (öffentliche Snapshots, Hall of Fame > 0 Punkte, Mitteilungen).
-- Keine Punkte, EXP, Trainings oder bestehenden Saisonergebnisse werden verändert.
-- Produktion nur über den regulären Migrationsweg und eine separate ausdrückliche FREIGABE.
BEGIN;

CREATE OR REPLACE FUNCTION league_v21_private.season_transition_core(p_season uuid, p_action text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
declare actor public.profiles%rowtype;season public.league_seasons_v21%rowtype;n integer;
 next_start date;next_end date;next_title text;next_id uuid;suffix integer:=1;
begin
 select * into actor from public.profiles p where p.auth_user_id=(select auth.uid()) and p.is_active and p.role='admin';
 if not found then raise exception 'Only active admin' using errcode='42501';end if;
 select * into season from public.league_seasons_v21 s where s.id=p_season for update;
 if not found then raise exception 'Season not found' using errcode='22023';end if;
 if p_action='activate' then
  if season.status<>'draft' then raise exception 'Only draft seasons may be activated' using errcode='22023';end if;
  -- Nie zwei aktive Saisons gleichzeitig (vorher nur im Frontend verhindert).
  perform pg_catalog.pg_advisory_xact_lock(94712031);
  if exists(select 1 from public.league_seasons_v21 s where s.status='active' and s.id<>season.id) then
   raise exception 'Another season is already active' using errcode='23505';end if;
  update public.league_seasons_v21 set status='active' where id=season.id;
  return pg_catalog.jsonb_build_object('status','active');
 elsif p_action='close' then
  if season.status='closed' then
   return pg_catalog.jsonb_build_object('status','closed','unchanged',true);
  end if;
  if season.status<>'active' or season.ends_on>=current_date then
   raise exception 'Only elapsed active seasons may close' using errcode='22023';end if;
  -- An unreviewed timely training might still change points and ranks.
  -- Block finalization until all season trainings are reviewed.
  PERFORM 1 FROM public.training_submissions t
   JOIN public.profiles p ON p.id=t.boxer_id AND p.role='boxer'
   WHERE t.training_date BETWEEN season.starts_on AND season.ends_on
   ORDER BY t.id FOR UPDATE OF t;
  if exists(select 1 from public.training_submissions t
    where t.status='pending' and t.training_date between season.starts_on and season.ends_on
    and exists(select 1 from public.profiles p where p.id=t.boxer_id and p.role='boxer'))
  then raise exception 'Pending season trainings require coach review' using errcode='23514';end if;
  if exists(select 1 from public.league_season_results_v21 r where r.season_id=season.id)
  then raise exception 'Unexpected existing season snapshot' using errcode='23505';end if;
  -- Public snapshot: only boxers that are public right now (same rule as the leaderboard).
  insert into public.league_season_results_v21(season_id,boxer_id,boxer_name,rank_position,points,exp)
  select season.id,p.id,p.display_name,
         rank() over(order by greatest(coalesce(sum(t.points),0),0) desc,
                               greatest(coalesce(sum(t.exp),0),0) desc)::integer,
         greatest(coalesce(sum(t.points),0),0)::integer,
         greatest(coalesce(sum(t.exp),0),0)::integer
  from public.profiles p
  left join public.point_transactions t on t.boxer_id=p.id
    and t.effective_date between season.starts_on and season.ends_on
  where p.role='boxer' and p.is_active is true and p.is_listed is true and p.archived_at is null
  group by p.id,p.display_name;
  get diagnostics n=row_count;
  -- Titles only for real season performance (no title for 0 points, even on a tie).
  insert into public.league_hall_of_fame_v21(boxer_id,boxer_name,season_id,title,description)
  select r.boxer_id,r.boxer_name,season.id,
   case r.rank_position when 1 then 'Saisonmeister' when 2 then 'Vizechampion' else 'Saisonpodium' end,
   season.title||' · Platz '||r.rank_position
  from public.league_season_results_v21 r
  where r.season_id=season.id and r.rank_position<=3 and r.points>0
  on conflict(boxer_id,season_id,title) do nothing;
  update public.league_seasons_v21 set status='closed' where id=season.id;
  if league_v21_private.notifications_enabled() then
   insert into public.boxer_notifications(recipient_id,notification_type,title,message,target_path)
   select r.boxer_id,'season',
    pg_catalog.left('Saison «'||season.title||'» beendet: Platz '||r.rank_position,160),
    case when r.rank_position=1 and r.points>0 then 'Gratulation, du bist Saisonmeister! '
         when r.rank_position<=3 and r.points>0 then 'Gratulation, du stehst auf dem Saisonpodium! '
         else '' end||r.points||' Punkte in dieser Saison.',
    '/league-history.html'
   from public.league_season_results_v21 r where r.season_id=season.id;
  end if;
  -- Folgesaison automatisch als Entwurf vorbereiten (gleiche Länge, direkt anschliessend),
  -- sofern noch keine spätere Saison angelegt ist. Aktivieren bleibt ein bewusster Admin-Schritt.
  next_start:=season.ends_on+1;
  next_end:=next_start+(season.ends_on-season.starts_on);
  if not exists(select 1 from public.league_seasons_v21 s where s.id<>season.id and s.ends_on>=next_start) then
   next_title:=(case when extract(month from next_end) in (12,1,2) then 'Winter'
                     when extract(month from next_end) in (3,4,5) then 'Frühling'
                     when extract(month from next_end) in (6,7,8) then 'Sommer' else 'Herbst' end)
               ||' '||extract(year from next_end)::integer;
   while exists(select 1 from public.league_seasons_v21 s where s.title=next_title||case when suffix>1 then ' ('||suffix||')' else '' end) loop
    suffix:=suffix+1;
   end loop;
   if suffix>1 then next_title:=next_title||' ('||suffix||')';end if;
   insert into public.league_seasons_v21(title,starts_on,ends_on,status)
   values(next_title,next_start,next_end,'draft') returning id into next_id;
  end if;
  return pg_catalog.jsonb_build_object('status','closed','ranked_boxers',n,
   'next_draft',case when next_id is null then null else pg_catalog.jsonb_build_object('id',next_id,'title',next_title,'starts_on',next_start,'ends_on',next_end) end);
 end if;
 raise exception 'Invalid season action' using errcode='22023';
end$function$;

NOTIFY pgrst, 'reload schema';
COMMIT;
