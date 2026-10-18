'use strict';
// Prepare a one-transaction SQL release candidate WITHOUT applying it.
// Usage: node tests/build-league-21-release.cjs --check
//        node tests/build-league-21-release.cjs --output /secure/path/league-21.sql
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const dir=path.join(__dirname,'..','supabase','migrations');
const names=fs.readdirSync(dir).filter(n=>/^\d{14}_league_21_[a-z0-9_]+\.sql$/.test(n)).sort();
assert.equal(names.length,25,'Expected all 25 Takeover 2.1 migrations');
assert.match(names[0],/seasons_goals_history_foundation/);
assert.match(names[names.length-1],/scoring_ledger_completeness/);
const migrations=names.map(name=>{
 const s=fs.readFileSync(path.join(dir,name),'utf8');
 assert.ok(s.length>50,'Empty migration: '+name);
 assert.ok(!/^\s*(BEGIN|COMMIT|ROLLBACK)\s*;/im.test(s),'Nested transaction: '+name);
 assert.ok(!/^\s*\\(ir|i|connect|copy)\b/im.test(s),'psql directive: '+name);
 return '-- BEGIN '+name+'\n'+s+'\n-- END '+name;
});
const preflight=[
 "DO $before$ BEGIN",
 " IF to_regclass('public.profiles') IS NULL OR to_regclass('public.training_submissions') IS NULL",
 " OR to_regclass('public.point_transactions') IS NULL OR to_regclass('public.league_duels') IS NULL",
 " THEN RAISE EXCEPTION 'V2 baseline is missing'; END IF;",
 " IF to_regclass('public.league_boxer_goals_v21') IS NOT NULL",
 " OR to_regclass('public.league_arena_duels_v21') IS NOT NULL",
 " THEN RAISE EXCEPTION 'V2.1 already installed, bundle replay forbidden'; END IF;",
 " IF to_regprocedure('public.duel_v2_reconcile(uuid)') IS NULL",
 " THEN RAISE EXCEPTION 'V2 duel reconciler missing'; END IF;",
 " IF NOT EXISTS(SELECT 1 FROM public.profiles WHERE role='admin' AND is_active)",
 " THEN RAISE EXCEPTION 'Missing active admin'; END IF;",
 " IF EXISTS(SELECT 1 FROM public.training_submissions s WHERE s.status='approved'",
 " AND NOT EXISTS(SELECT 1 FROM public.point_transactions t WHERE t.submission_id=s.id",
 " AND t.boxer_id=s.boxer_id AND t.category IN ('training','legacy_import')))",
 " THEN RAISE EXCEPTION 'Approved training lacks a score ledger'; END IF;",
 " IF EXISTS(SELECT 1 FROM public.point_transactions WHERE submission_id IS NOT NULL",
 " AND category IN ('training','legacy_import') GROUP BY submission_id HAVING count(*)>1)",
 " THEN RAISE EXCEPTION 'Duplicate score ledger'; END IF;",
 "END $before$;"
].join('\n');
const postflight=[
 "DO $after$ DECLARE n integer; BEGIN",
 " SELECT count(*) INTO n FROM pg_class c JOIN pg_namespace ns ON ns.oid=c.relnamespace",
 " WHERE ns.nspname='public' AND c.relkind='r' AND c.relname LIKE '%_v21';",
 " IF n<>17 THEN RAISE EXCEPTION 'Expected 17 new tables, found %',n; END IF;",
 " IF EXISTS(SELECT 1 FROM pg_class c JOIN pg_namespace ns ON ns.oid=c.relnamespace",
 " WHERE ns.nspname='public' AND c.relkind='r' AND c.relname LIKE '%_v21'",
 " AND (NOT c.relrowsecurity OR has_table_privilege('anon',c.oid,'INSERT,UPDATE,DELETE')",
 " OR has_table_privilege('authenticated',c.oid,'INSERT,UPDATE,DELETE')))",
 " THEN RAISE EXCEPTION 'Insecure new table'; END IF;",
 " IF EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace ns ON ns.oid=p.pronamespace",
 " WHERE ns.nspname='public' AND p.proname LIKE 'league_v21_%'",
 " AND (p.prosecdef OR has_function_privilege('anon',p.oid,'EXECUTE')))",
 " THEN RAISE EXCEPTION 'Insecure new public RPC'; END IF;",
 " IF (SELECT count(*) FROM pg_proc p JOIN pg_namespace ns ON ns.oid=p.pronamespace",
 " WHERE ns.nspname='public' AND p.proname LIKE 'league_v21_%')<15",
 " THEN RAISE EXCEPTION 'Missing release RPCs'; END IF;",
 "END $after$;"
].join('\n');
const sql=[
 "-- TAKEOVER LEAGUE 2.1 – NOT FOR EXECUTION UNTIL EXPRESS GO LIVE",
 "-- Generated from source migrations, no backup or login test implied.",
 "-- Entire file must run within ONE connection; never split statements among sessions.",
 'BEGIN;',
 "SET LOCAL lock_timeout = '10s';",
 "SET LOCAL statement_timeout = '120s';",
 preflight,...migrations,postflight,'COMMIT;',''
].join('\n\n');
const args=process.argv.slice(2);
if(args.length===1 && args[0]==='--check'){
 assert.equal((sql.match(/^-- BEGIN \d{14}_league_21_/gm)||[]).length,25);
 assert.equal((sql.match(/^-- END \d{14}_league_21_/gm)||[]).length,25);
 console.log('PASS: 25 SQL migrations, guarded transaction, no execution');
}else if(args.length===2 && args[0]==='--output'){
 const output=path.resolve(args[1]);
 assert.ok(!output.startsWith(dir+path.sep),'Do not write into migration source directory');
 fs.writeFileSync(output,sql,{flag:'wx',mode:0o600});
 console.log('Prepared release candidate: '+output);
}else{
 console.error('Use --check or --output /secure/path/league-21.sql');
 process.exitCode=2;
}
