-- Run after the existing points-preview schema fixture, only in a disposable DB.
\set ON_ERROR_STOP on
DO $$ BEGIN IF current_database() NOT LIKE 'league21_replay_%' THEN RAISE EXCEPTION 'Disposable database required'; END IF; END $$;
\i supabase/migrations/20261102095352_duel_staff_queue_readonly.sql
\i tests/duel-staff-queue-transaction.sql
\echo Staff duel queue schema suite passed.
