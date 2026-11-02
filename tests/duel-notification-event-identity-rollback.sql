\set ON_ERROR_STOP on
-- Run last in a disposable database; rollback intentionally retains the additive identity schema.
DO $$ BEGIN IF current_database() NOT LIKE 'league21_replay_%' THEN RAISE EXCEPTION 'Disposable database required'; END IF; END $$;
INSERT INTO public.boxer_notifications(recipient_id,notification_type,title,message,target_path,read_at,event_key)
VALUES('11111111-1111-4111-8111-111111111111','boxer_duel','Synthetic retained notice',
 'Rollback fixture only','/duels.html','2026-01-01T00:00:00Z','fixture:rollback:retained');
CREATE TEMP TABLE notice_rollback_witness AS SELECT jsonb_agg(to_jsonb(n) ORDER BY n.id) value FROM public.boxer_notifications n;
\i supabase/production-prep/rollback_20261102093606_duel_notification_event_identity.sql
DO $$ BEGIN
 IF (SELECT value FROM notice_rollback_witness) IS DISTINCT FROM
    (SELECT jsonb_agg(to_jsonb(n) ORDER BY n.id) FROM public.boxer_notifications n)
 THEN RAISE EXCEPTION 'Notice rollback changed identity, contents or read state'; END IF;
 IF position('where not exists(select 1 from public.boxer_notifications' IN
   pg_get_functiondef('league_v21_private.notify_duel_events()'::regprocedure))=0
 THEN RAISE EXCEPTION 'Notice rollback did not restore the previous writer'; END IF;
 IF to_regclass('public.boxer_notifications_recipient_event_key_uidx') IS NULL
 THEN RAISE EXCEPTION 'Notice rollback removed retained identity index'; END IF;
END $$;
DROP TABLE notice_rollback_witness;
\echo Notification writer rollback preserved event identities, message contents and read state.
