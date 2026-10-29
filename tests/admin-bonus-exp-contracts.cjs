'use strict';
// Static contracts for Etappe 18: Bonus-EXP vom Admin (wahlweise mit Monatspunkten), Rücknahme als Gegenbuchung, Liste.
const fs=require('node:fs'),assert=require('node:assert/strict');
const read=f=>fs.readFileSync(f,'utf8');
const id='20261029240000_admin_bonus_exp';
const sql=read('supabase/migrations/'+id+'.sql'),code=sql.replace(/--[^\n]*/g,'');
for(const f of ['preflight','postflight','rollback'])assert.ok(fs.existsSync('supabase/production-prep/'+f+'_'+id+'.sql'),f);
const fn=n=>code.slice(code.indexOf('CREATE OR REPLACE FUNCTION public.'+n),code.indexOf('$fn$;',code.indexOf('CREATE OR REPLACE FUNCTION public.'+n))+5);
const give=fn('admin_give_bonus'),rev=fn('admin_revoke_bonus'),list=fn('admin_list_bonuses');
for(const f of [give,rev,list]){assert.match(f,/SECURITY DEFINER SET search_path=''/);assert.match(f,/me\.role<>'admin'[^;]*ERRCODE='42501'/,'admin only')}
// Vergabe: Grenzen, Kategorie wie bisherige Trainerboni, Punkte nur wenn gewählt, Mitteilung
assert.match(give,/p_profile_id=me\.id[^;]*ERRCODE='42501'/,'not to oneself');
assert.match(give,/p\.is_active AND p\.archived_at IS NULL AND p\.role IN \('boxer','coach'\)/);
assert.match(give,/p_exp NOT BETWEEN 1 AND 500/);assert.match(give,/p_with_points IS NULL/);assert.match(give,/NOT BETWEEN 3 AND 120 OR r ~ '\[<>\]'/);
assert.match(give,/pts := CASE WHEN p_with_points THEN p_exp ELSE 0 END;/);
assert.match(give,/VALUES \(t\.id,pts,p_exp,'trainer_bonus','Bonus: '\|\|r,today,me\.id\)/);
assert.match(give,/boxer_notifications\(recipient_id,notification_type,title,message,target_path\)[\s\S]*'general','Bonus: \+'\|\|p_exp\|\|' EXP'/);
// Rücknahme: nur Boni, nur einmal, Gegenbuchung statt Löschen
assert.match(rev,/x\.category='trainer_bonus' FOR UPDATE/);assert.match(rev,/ERRCODE='23505'/);
assert.match(rev,/VALUES \(b\.boxer_id,-b\.points,-b\.exp,'adjustment','Rücknahme Bonus: '\|\|r,today,me\.id\)/);
assert.match(code,/bonus_tx_id uuid PRIMARY KEY REFERENCES public\.point_transactions\(id\)/,'only once per bonus');
assert.match(code,/ALTER TABLE public\.bonus_revocations ENABLE ROW LEVEL SECURITY;\s*REVOKE ALL ON public\.bonus_revocations FROM PUBLIC, anon, authenticated;/);
assert.match(list,/LEAST\(GREATEST\(coalesce\(p_limit,30\),1\),100\)/);assert.match(list,/ORDER BY x\.created_at DESC, x\.id/);
assert.doesNotMatch(code,/UPDATE public\.|DELETE FROM|TRUNCATE|DROP /i,'no changes to existing data');
assert.match(code,/REVOKE ALL ON FUNCTION public\.admin_give_bonus\(uuid,integer,boolean,text\), public\.admin_revoke_bonus\(uuid,text\), public\.admin_list_bonuses\(integer\) FROM PUBLIC, anon;/);
const rb=read('supabase/production-prep/rollback_'+id+'.sql');
assert.match(rb,/IF EXISTS \(SELECT 1 FROM public\.bonus_revocations\) THEN RAISE EXCEPTION/,'rollback guarded');
assert.doesNotMatch(rb,/point_transactions/,'rollback keeps bookings');
// Frontend: nur Admin-Verwaltung im Shop, nur RPCs, Vorlagen, Hilfe
const shop=read('shop.html'),help=read('takeover-help.js'),css=read('takeover-redesign.css');
assert.match(shop,/\['bonus','Bonus-EXP'\]/);assert.match(shop,/BONUS_REASONS=\['Feedbackvideo geschickt','Speziell aufgefallen'/);
assert.match(shop,/rpc\('admin_give_bonus',\{p_profile_id:f\.who\.value,p_exp:Number\(f\.exp\.value\),p_with_points:f\.pts\.checked,p_reason:f\.reason\.value\}\)/);
assert.match(shop,/rpc\('admin_revoke_bonus',\{p_tx_id:f\.dataset\.id,p_reason:f\.reason\.value\}\)/);
assert.match(shop,/w\.role!=='admin'/,'admins not offered');
assert.doesNotMatch(shop,/\.from\('point_transactions'\)/);
assert.match(help,/Bonus-EXP geben/);assert.match(help,/Konten bzw\. Bonus-EXP/);
assert.match(css,/Etappe 18: Bonus-EXP/);
console.log('PASS: Etappe 18 – Bonus-EXP nur Admin (nicht sich selbst), 1–500 EXP, Grund geprüft, Punkte pro Bonus wählbar, Buchung trainer_bonus + Mitteilung, Rücknahme einmal als Gegenbuchung, keine Datenänderung, Rücknahme geschützt, Shop/Hilfe angepasst');
