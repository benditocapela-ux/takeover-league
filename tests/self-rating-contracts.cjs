'use strict';
// Static contracts for Etappe 10 (Selbsteinschätzung alle 14 Tage, Trainer gibt frei oder passt an).
const fs=require('node:fs'),assert=require('node:assert/strict');
const read=f=>fs.readFileSync(f,'utf8');
const sql=read('supabase/migrations/20261029160000_self_rating.sql'),code=sql.replace(/--[^\n]*/g,'');
const rollback=read('supabase/production-prep/rollback_20261029160000_self_rating.sql');
const bew=read('bewertung.html'),coach=read('coach.html'),boxer=read('boxer.html'),help=read('takeover-help.js'),css=read('takeover-redesign.css');
for(const f of ['preflight','postflight'])assert.ok(fs.existsSync('supabase/production-prep/'+f+'_20261029160000_self_rating.sql'),f);
// Datenbank: Flag aus, Tabelle gesperrt, alle Funktionen mit leerem search_path, Clients nur über RPCs
assert.match(code,/'self_rating','Selbsteinschätzung[^']*',false\)/,'flag starts off');
assert.match(code,/REVOKE ALL ON public\.rating_self_reviews FROM PUBLIC, anon, authenticated;/);
assert.match(code,/CREATE UNIQUE INDEX IF NOT EXISTS rating_self_reviews_one_pending ON public\.rating_self_reviews\(boxer_id\) WHERE status='pending'/);
const fns=[...code.matchAll(/CREATE OR REPLACE FUNCTION (public|league_private)\.([a-z_]+)\([^)]*\)\s*RETURNS[^$]*?\$fn\$/g)];
assert.equal(fns.length,6);
for(const f of fns)assert.match(f[0],/SET search_path=''/,f[2]);
for(const f of fns.filter(f=>f[1]==='public'))assert.match(f[0],/SECURITY DEFINER/,f[2]);
assert.match(code,/REVOKE ALL ON FUNCTION public\.get_my_self_rating\(\)[\s\S]*FROM PUBLIC, anon;/);
assert.match(code,/\+ 14/,'14 days');assert.match(code,/AT TIME ZONE 'Europe\/Zurich'/);
assert.match(code,/flag_on\('self_rating'\) AND league_private\.flag_on\('coach_ratings'\)/,'boxers need both flags');
assert.match(code,/rating_scores_valid\(p_scores,20\)/);assert.match(code,/rating_scores_valid\(sc,20\)/);
// Bestehende Bewertungen und staff_rate_boxer bleiben unberührt; nur neue Bewertungen per INSERT
const top=sql.replace(/\$fn\$[\s\S]*?\$fn\$/g,'').replace(/--[^\n]*/g,'');
assert.doesNotMatch(top,/UPDATE public\.boxer_ratings|DELETE FROM|TRUNCATE/i);
assert.doesNotMatch(code,/UPDATE public\.boxer_ratings|DELETE FROM public\.boxer_ratings|FUNCTION public\.staff_rate_boxer|FUNCTION public\.get_my_performance/);
assert.match(code,/INSERT INTO public\.boxer_ratings\(boxer_id,rated_by,scores,note,scale\) VALUES \(t\.id,me\.id,sc,n,20\)/);
assert.match(code,/r\.boxer_id=me\.id THEN RAISE EXCEPTION 'Deine eigene Selbsteinschätzung gibt ein anderer Trainer frei'/);
assert.match(rollback,/EXISTS \(SELECT 1 FROM public\.rating_self_reviews\)[\s\S]*Rücknahme abgebrochen/);
assert.doesNotMatch(rollback.replace(/--[^\n]*/g,''),/boxer_ratings/,'rollback never touches ratings');
// Oberfläche: nur vorgesehene RPCs, keine Browser-Dialoge, Texte escaped, Ablehnen mit zweitem Klick
assert.doesNotMatch(bew,/confirm\(|alert\(|prompt\(/);
assert.match(bew,/data-act="self-save"/);assert.match(bew,/t\.dataset\.confirm='1';t\.textContent='Wirklich ablehnen\?'/);
for(const x of ['P.esc(edit.boxerNote)','P.esc(s.last.coach_note)','P.esc(s.last.decided_by)','P.esc(r.display_name)'])assert.ok(bew.includes(x),x);
assert.match(bew,/rpc\('submit_self_rating',\{p_scores:edit\.draft,p_note:edit\.note\|\|null\}\)/);
assert.match(bew,/rpc\('staff_decide_self_rating',\{p_id:edit\.id,p_decision:decision,p_scores:decision==='adjust'\?edit\.draft:null,p_note:edit\.note\|\|null\}\)/);
assert.match(coach,/rpc\('staff_list_self_ratings'\)/);assert.match(coach,/el\.textContent=/);assert.doesNotMatch(coach.slice(coach.indexOf('async function loadSelfRatingNotice'),coach.indexOf('async function load(clearStatus')),/innerHTML/);
assert.match(coach,/id="selfRatingNotice" class="self-rating-notice"/,'not a .notice (layout moves .notice to the end)');
assert.match(boxer,/'arena\.html','bewertung\.html'\]\)/,'notification link to bewertung.html allowed');
assert.match(help,/alle 14 Tage selbst ein/);assert.match(help,/Selbsteinschätzungen der Boxer stehen oben/);
assert.match(css,/\.self-rating-notice\[hidden\]\{display:none\}/);
console.log('PASS: Selbsteinschätzung – Flag aus, Tabelle gesperrt, 14 Tage, beide Flags für Boxer, bestehende Bewertungen unberührt, eigene Freigabe verboten, Oberfläche nur mit vorgesehenen RPCs, escaped, Ablehnen mit zweitem Klick');
