-- Duelle: Mitteilungen vervollständigen (27.10.2026).
-- Der Mitteilungstyp 'boxer_duel' war vorgesehen, aber Duelle erzeugten keine Mitteilungen.
-- Neu (per Trigger, ohne Änderung der Duell-RPCs):
--  * Einladung → Gegner; Annahme/Ablehnung → Herausforderer; Wertung → beide (Sieg/Niederlage/Unentschieden).
-- Nur wenn der Schalter 'notifications' aktiv ist. Keine Punkte, EXP oder Duelldaten werden verändert.
-- Produktion nur über den regulären Migrationsweg und eine separate ausdrückliche FREIGABE.
BEGIN;
CREATE OR REPLACE FUNCTION league_v21_private.notify_duel_events()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $fn$
declare ch text; op text;
begin
 if not league_v21_private.notifications_enabled() then return NEW; end if;
 if TG_OP='UPDATE' and NEW.status is not distinct from OLD.status then return NEW; end if;
 select display_name into ch from public.profiles where id=NEW.challenger_id;
 select display_name into op from public.profiles where id=NEW.opponent_id;
 if TG_OP='INSERT' and NEW.status='pending' then
  insert into public.boxer_notifications(recipient_id,notification_type,title,message,target_path)
  values(NEW.opponent_id,'boxer_duel',pg_catalog.left('Duell-Einladung von '||coalesce(ch,'einem Boxer'),160),
   'Duell über '||NEW.duration_days||' Tage. Nimm die Einladung innerhalb von 48 Stunden an oder lehne sie ab.','/duels.html');
 elsif TG_OP='UPDATE' and NEW.status='active' and OLD.status='pending' then
  insert into public.boxer_notifications(recipient_id,notification_type,title,message,target_path)
  values(NEW.challenger_id,'boxer_duel',pg_catalog.left(coalesce(op,'Dein Gegner')||' hat dein Duell angenommen',160),
   'Das Duell läuft jetzt '||NEW.duration_days||' Tage. Jedes bestätigte Training zählt.','/duels.html');
 elsif TG_OP='UPDATE' and NEW.status='declined' and OLD.status='pending' then
  insert into public.boxer_notifications(recipient_id,notification_type,title,message,target_path)
  values(NEW.challenger_id,'boxer_duel',pg_catalog.left(coalesce(op,'Dein Gegner')||' hat dein Duell abgelehnt',160),
   'Du kannst jederzeit einen anderen Gegner herausfordern.','/duels.html');
 elsif TG_OP='UPDATE' and NEW.status='settled' then
  insert into public.boxer_notifications(recipient_id,notification_type,title,message,target_path)
  select r.id,'boxer_duel',
   pg_catalog.left(case when NEW.winner_id is null then 'Duell gegen '||r.other||': Unentschieden'
        when NEW.winner_id=r.id then 'Duell gegen '||r.other||' gewonnen'
        else 'Duell gegen '||r.other||' verloren' end,160),
   'Endstand '||NEW.challenger_score||' : '||NEW.opponent_score||' Trainingspunkte.'||
    case when NEW.winner_id is not null and NEW.winner_id<>r.id then ' Revanche? In den Duellen kannst du direkt erneut herausfordern.' else '' end,
   '/duels.html'
  from (values (NEW.challenger_id,coalesce(op,'Gegner')),(NEW.opponent_id,coalesce(ch,'Gegner'))) r(id,other)
  where not exists(select 1 from public.boxer_notifications n where n.recipient_id=r.id and n.notification_type='boxer_duel'
    and n.title like 'Duell gegen %' and n.created_at>=coalesce(NEW.settled_at,now())-interval '1 minute' and n.message like 'Endstand %');
 end if;
 return NEW;
end$fn$;
REVOKE ALL ON FUNCTION league_v21_private.notify_duel_events() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS league_v21_notify_duel_events ON public.league_duels;
CREATE TRIGGER league_v21_notify_duel_events
 AFTER INSERT OR UPDATE OF status ON public.league_duels
 FOR EACH ROW EXECUTE FUNCTION league_v21_private.notify_duel_events();
COMMIT;
