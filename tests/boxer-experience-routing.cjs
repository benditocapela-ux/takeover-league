/* Boxer Experience activation contract. Run: node --test tests/boxer-experience-routing.cjs */
'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const login=fs.readFileSync('login.html','utf8');
const nav=fs.readFileSync('takeover-navigation.js','utf8');
const studio=fs.readFileSync('boxer.html','utf8');
const exp=fs.readFileSync('boxer-experience.html','utf8');
const expJs=fs.readFileSync('boxer-experience.js','utf8');
const publish=fs.readFileSync('.github/workflows/takeover-pages-deploy.yml','utf8');
test('Shared navigation remains syntactically valid',()=>{
 assert.doesNotThrow(()=>new vm.Script(nav));
});
test('Successful boxer login lands on Boxer Experience',()=>{
 assert.match(login,/profile\?\.role==='boxer'&&profile\?\.is_active\?'\.\/boxer-experience\.html'/);
 assert.match(login,/if\(profile\.role==='boxer'\)\{location\.replace\(next==='boxer\.html'\?'\.\/boxer\.html':'\.\/boxer-experience\.html'\);return;\}/);
 assert.match(login,/next==='boxer-experience\.html'/);
});
test('Explicit login deep links to the old training studio remain available',()=>{
 assert.match(login,/next==='boxer\.html'/);
 assert.match(login,/next==='boxer\.html'\?'\.\/boxer\.html'/);
 assert.match(studio,/id="trainingFormCard"/);
});
test('Coach and admin logins retain their existing destinations',()=>{
 assert.match(login,/if\(profile\.role==='admin'\)\{location\.replace\('\.\/coach\.html'\)/);
 assert.match(login,/if\(profile\.role==='coach'\)\{location\.replace\('\.\/coach\.html'\)/);
});
test('Main menu and dashboard links take boxers to new home',()=>{
 assert.match(nav,/boxer:\{href:'\.\/boxer-experience\.html',label:'Mein Takeover'/);
 assert.match(nav,/\['user','Mein Takeover','boxer-experience\.html'/);
 assert.match(nav,/const boxerLink=panel\.querySelector\('a\[href="\.\/boxer-experience\.html"\]'\)/);
 assert.match(nav,/\.\/boxer-experience\.html','\.\/boxer\.html'/);
});
test('PWA root redirects only authenticated active boxers, not explicit public sections',()=>{
 assert.match(nav,/if\(p\.error\|\|!p\.data\|\|p\.data\.is_active!==true\) return;/);
 assert.match(nav,/if\(role==='boxer'&&atHome&&!location\.hash\)\{location\.replace\('\.\/boxer-experience\.html'\);return;\}/);
 assert.match(nav,/if\(ROLE_NAV\[role\]\) applyDashboardLink\(role\)/);
});
test('Trainer/Admin menu cannot link to boxer-only experience',()=>{
 assert.match(nav,/role!=='boxer'&&href==='\.\/boxer-experience\.html'/);
});
test('Legacy boxer studio remains discoverable; training deep links are preserved',()=>{
 assert.match(studio,/data-tl-experience-link href="\.\/boxer-experience\.html" hidden/);
 assert.match(studio,/if\(profile\.role==='boxer'\)\{const newView=document\.querySelector/);
 assert.match(expJs,/\.\/boxer\.html#trainingFormCard/);
 assert.match(exp,/href="\.\/boxer\.html"/);
});
test('New static page and its JS are included in Pages release assembly',()=>{
 const builder=fs.readFileSync('./tools/assemble-pages-site.cjs','utf8');
 assert.match(publish,/node tools\/assemble-pages-site\.cjs _site/);
 assert.match(builder,/EXTENSIONS=new Set\(\['\.html','\.js','\.css'/);
 assert.match(builder,/fs\.copyFileSync\(path\.join\(source,entry\.name\)/);
 assert.match(exp,/<script src="\.\/boxer-experience\.js" defer><\/script>/);
});
