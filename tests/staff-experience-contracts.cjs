'use strict';
// The staff redesign changes the real coach/admin pages, not preview routes.
// No authenticated RPCs, original DOM hook IDs or privilege checks may be removed.
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs');
const read=f=>fs.readFileSync(f,'utf8');
const coach=read('coach.html'),admin=read('admin.html'),css=read('takeover-staff-experience.css');
test('Both live role pages use the same navy/gold system as Boxer Experience',()=>{
 for(const [path,s] of [['coach',coach],['admin',admin]]){
  assert.match(s,/takeover-staff-experience\.css/,'missing shared staff theme: '+path);
  assert.match(s,new RegExp('data-tl-screen="'+path+'"'));
  assert.match(s,/class="tl-screen-ribbon"/);
  assert.match(s,/data-stf-global-menu/,'full Takeover menu must remain accessible');
 }
 assert.match(css,/#f2c14e/);
 assert.match(css,/linear-gradient/);
 assert.match(css,/safe-area-inset-bottom/);
 assert.match(css,/prefers-reduced-motion:reduce/);
 assert.match(css,/:focus-visible/);
});
test('Coach keeps six real views, actions, feedback and mobile dock',()=>{
 assert.match(coach,/COACH_VIEWS=\[\['home','Start','🏠','start'\],\['review','Prüfen','✅','bestaetigen'\],\['gym','Gym','🏟️','gym'\],\['boxers','Boxer','👥','boxer'\],\['history','Historie','🗓️','historie'\],\['more','Mehr','☰','mehr'\]\]/);
 for(const rpc of ['staff_review_training','staff_correct_training','staff_list_trainings','staff_send_feedback','staff_record_training']){
  assert.ok(coach.includes("'"+rpc+"'"),'coach RPC missing: '+rpc);
 }
 assert.match(css,/body\[data-tl-screen="coach"\] \.cv2-tabs\{[\s\S]*?position:fixed/);
 assert.match(css,/body\[data-tl-screen="coach"\] \.tl-global-bottom/);
 assert.match(coach,/document\.querySelector\('\[data-stf-global-menu\]'\)/);
 assert.match(css,/\.cv2-actions button\{min-height:50px;/);
});
test('Admin still authorizes server-side before showing data',()=>{
 assert.match(admin,/profile\.data\.role!=='admin'\|\|profile\.data\.is_active!==true/);
 assert.match(admin,/try\{await mustBeAdmin\(\);await load\(\);openStaffPanel\('profiles'\)/);
 assert.match(admin,/if\(!admin\)return/);
 assert.match(admin,/id="adminContent" class="hidden"/);
});
test('Admin has three functional dock views and global app menu',()=>{
 assert.deepEqual([...admin.matchAll(/data-staff-target="([^"]+)"/g)].map(x=>x[1]),['profiles','security','audit']);
 assert.deepEqual([...admin.matchAll(/<div class="panel" data-staff-pane="([^"]+)"/g)].map(x=>x[1]),['profiles','security','audit']);
 assert.match(admin,/function openStaffPanel\(key/);
 assert.match(admin,/panel\.hidden=panel\.dataset\.staffPane!==key/);
 assert.match(admin,/data-stf-global-menu/);
});
test('Admin search and 10-row incremental paging use existing real data',()=>{
 assert.match(admin,/adminSearch='',adminShown=10/);
 assert.match(admin,/function renderProfileRows\(\)/);
 assert.match(admin,/const shown=visible\.slice\(0,adminShown\)/);
 assert.match(admin,/adminShown\+=10/);
 assert.match(admin,/data-staff-search/);
 assert.match(admin,/data-staff-more hidden/);
 assert.match(admin,/renderProfileRows\(\)/);
 assert.match(admin,/showArchived/);
 assert.match(admin,/archiveById\.has\(row\.id\)/);
});
test('Admin role actions, archive, visibility and audit are still wired',()=>{
 for(const rpc of ['admin_list_profiles','admin_list_profile_archive_state','admin_set_profile_role','admin_set_profile_active','admin_set_profile_listed','admin_set_profile_email','admin_archive_profile','admin_restore_profile']){
  assert.ok(admin.includes("'"+rpc+"'"),'admin RPC missing: '+rpc);
 }
 assert.match(admin,/loadAudit\(\)/);
 assert.match(admin,/profile_admin_audit/);
 assert.match(admin,/navigator\.clipboard\.writeText/);
 assert.match(admin,/if\(question&&!confirm\(question\)\)return/);
});
test('No added inline script blocks, duplicate IDs or sensitive SQL on click',()=>{
 for(const s of [coach,admin]){
  const ids=[...s.matchAll(/\bid="([^"]+)"/g)].map(m=>m[1]);
  assert.equal(new Set(ids).size,ids.length);
 }
 assert.equal((coach.match(/<script\b/g)||[]).length,7); // +2 Takeover 3.0: takeover-account.js, takeover-app-shell.js
 assert.equal((admin.match(/<script\b/g)||[]).length,5);
 assert.doesNotMatch(css,/display:none!important;\s*\/\* admin permission/);
});
