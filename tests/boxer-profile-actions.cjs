const assert=require('node:assert/strict');
const fs=require('node:fs');
const {JSDOM}=require('jsdom');
const read=p=>fs.readFileSync(p,'utf8');
const index=read('index.html'),profile=read('boxer-profile.html'),
 src=read('boxer-profile.js'),duels=read('duels.html'),challenges=read('challenges.html');
const migration=read('supabase/migrations/20261018170000_private_boxer_challenge_assignment.sql');
const deploy=read('.github/workflows/takeover-pages-deploy.yml');

assert.match(index,/href="\.\/boxer-profile\.html\?name=\$\{safe\(encodeURIComponent\(e.name\)\)\}"/,
 'Monthly ranking rows must link to public boxer profile');
assert.match(index,/href="\.\/boxer-profile\.html\?name=\$\{safe\(encodeURIComponent\(b.name\)\)\}"/,
 'Level rows must link to public boxer profile');
assert.match(index,/class="rank-row league-boxer-link"/,'Clickable athlete row needs accessible link markup');
assert.match(index,/aria-label="Profil von \$\{safe\(/);
assert.match(profile,/takeover-navigation\.js/);
assert.match(profile,/id="duelAction"/);
assert.match(profile,/id="challengeAction"[^>]+hidden/);
assert.match(profile,/id="monthlyPoints"/);
assert.match(profile,/id="totalXp"/);
assert.match(profile,/id="profilePhoto"/);
assert.doesNotMatch(profile,/weight|gewicht|email|passwort/i,'Do not show private fields on public profile');
assert.match(src,/get_public_levels/);
assert.match(src,/get_public_leaderboard/);
assert.match(src,/get_public_boxer_avatars/);
assert.match(src,/\.select\('role,is_active'\)/,
 'Only verified authenticated Coach/Admin profiles may see assignment actions');
assert.doesNotMatch(src,/\bservice_role\b|\bsb_secret_/i,'No service role secrets in public client');
assert.match(duels,/requestedOpponent/);
assert.match(duels,/matches.length===1/,'Duel deep-link must reject duplicate opponent display names');
assert.match(duels,/Gegner wählen/,'Duel invitation must require opponent selection');
assert.match(challenges,/id="targetedAssignment"/);
assert.match(challenges,/league_assign_personal_challenge/);
assert.match(challenges,/league_personal_challenge_roster/);
assert.match(challenges,/targetedSection.hidden=true/,'Targeted form must default hidden');
assert.match(challenges,/confirm\('Persönliche Challenge für /,
 'Require explicit confirmation before trainer starts assignment');
assert.match(migration,/CREATE TABLE public\.league_coach_challenge_targets/);
assert.match(migration,/ALTER TABLE public\.league_coach_challenge_targets ENABLE ROW LEVEL SECURITY/);
assert.match(migration,/REVOKE ALL ON TABLE public\.league_coach_challenge_targets/);
assert.match(migration,/league_private\.coach_v2_actor/);
assert.match(migration,/NOT EXISTS \(SELECT 1 FROM public\.league_coach_challenge_targets t/);
assert.match(migration,/Personal challenge belongs to another boxer/);
assert.match(migration,/REVOKE ALL ON FUNCTION public\.league_assign_personal_challenge/);
assert.match(migration,/NOTIFY pgrst, 'reload schema'/);
assert.match(deploy,/test -s _site\/boxer-profile\.js/);
assert.match(deploy,/for page in .*boxer-profile/);

const sample={
 levels:[{boxer_name:'Boxer Alpha',lifetime_exp:325},{boxer_name:'Boxer Beta',lifetime_exp:0}],
 ranking:[{boxer_name:'Boxer Alpha',monthly_points:95,rank_position:1,lifetime_exp:325}],
 avatars:[{boxer_name:'Boxer Alpha',avatar_key:'avatar-01',avatar_url:null}]
};
async function checkCase(name,rows,expected){
 const dom=new JSDOM(profile,{
   url:'https://benditocapela-ux.github.io/takeover-league/boxer-profile.html?name='+encodeURIComponent(name),
   runScripts:'outside-only'
 });
 const {window}=dom,doc=window.document;
 window.fetch=async url=>({
   ok:true,
   json:async()=>{
    const key=url.includes('get_public_levels')?'levels':url.includes('get_public_leaderboard')?'ranking':'avatars';
    return rows[key];
   }
 });
 window.console.warn=()=>{};
 window.eval(src);
 for(let n=0;n<15;n++){
   await new Promise(resolve=>setTimeout(resolve,0));
   if(doc.querySelector('#profileCard').hidden===expected.visible || doc.querySelector('#status').classList.contains('error'))break;
 }
 assert.equal(doc.querySelector('#profileCard').hidden,!expected.visible,'Incorrect public profile visibility');
 if(expected.visible){
   assert.equal(doc.querySelector('#profileName').textContent,name);
   assert.equal(doc.querySelector('#monthlyPoints').textContent,'95');
   assert.equal(doc.querySelector('#totalXp').textContent,'325');
   assert.equal(doc.querySelector('#duelAction').getAttribute('href'),'./duels.html?opponent='+encodeURIComponent(name));
   assert.equal(doc.querySelector('#challengeAction').hidden,true,'Anon must not see coach-only assignment');
   assert.equal(doc.querySelectorAll('#profilePhoto img').length,1,'Public-safe avatar should render');
 }else{
   assert.match(doc.querySelector('#status').textContent,expected.message);
   assert.equal(doc.querySelector('#challengeAction').hidden,true);
 }
 dom.window.close();
}
(async()=>{
 await checkCase('Boxer Alpha',sample,{visible:true});
 await checkCase('Unknown',sample,{visible:false,message:/nicht gefunden/});
 await checkCase('Boxer Alpha',{...sample,levels:[sample.levels[0],{...sample.levels[0]}]},
   {visible:false,message:/mehrfach/});
 await checkCase('Boxer Alpha',{...sample,ranking:[...sample.ranking,{...sample.ranking[0]}]},
   {visible:false,message:/nicht eindeutig/});
 console.log('PASS: Ranking/Levels profile routes, public-only stats, safe name collisions, and role-gated coach/duel actions.');
})().catch(err=>{console.error(err);process.exitCode=1});
