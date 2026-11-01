/* Boxer Experience routing contract (Takeover 3.0). Run: node --test tests/boxer-experience-routing.cjs */
'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const login=fs.readFileSync('login.html','utf8');
const nav=fs.readFileSync('takeover-navigation.js','utf8');
const shell=fs.readFileSync('takeover-app-shell.js','utf8');
const studio=fs.readFileSync('boxer.html','utf8');
const exp=fs.readFileSync('boxer-experience.html','utf8');
const publish=fs.readFileSync('.github/workflows/takeover-pages-deploy.yml','utf8');
test('Shared navigation and shell remain syntactically valid',()=>{
 assert.doesNotThrow(()=>new vm.Script(nav));
 assert.doesNotThrow(()=>new vm.Script(shell));
});
test('Successful login lands on the role home; boxers never on the old studio',()=>{
 assert.match(login,/const HOME=\{boxer:'\.\/boxer-experience\.html',coach:'\.\/coach\.html',admin:'\.\/admin\.html'\}/);
 assert.match(login,/location\.replace\(targetFor\(profile\.role\)\)/);
 assert.match(login,/if\(f==='login\.html'\|\|f==='boxer\.html'\)return null/,'next=boxer.html no longer opens the old studio');
});
test('Login deep links are allow-listed relative pages only (no open redirect)',()=>{
 assert.match(login,/\^\(\?:\\\.\\\/\)\?\(\[a-z0-9-\]\+\\\.html\)/);
});
test('Main menu and dashboard links take boxers to the new home',()=>{
 assert.match(nav,/boxer:\{href:'\.\/boxer-experience\.html',label:'Mein Takeover'/);
 assert.match(nav,/\['user','Mein Takeover','boxer-experience\.html'/);
});
test('PWA root redirects only authenticated active boxers, not explicit public sections',()=>{
 assert.match(nav,/if\(p\.error\|\|!p\.data\|\|p\.data\.is_active!==true\) return;/);
 assert.match(nav,/if\(role==='boxer'&&atHome&&!location\.hash\)\{location\.replace\('\.\/boxer-experience\.html'\);return;\}/);
});
test('Trainer/Admin menu cannot link to boxer-only experience',()=>{
 assert.match(nav,/role!=='boxer'&&href==='\.\/boxer-experience\.html'/);
});
test('Old studio deep links redirect boxers into the new views (central legacy routing)',()=>{
 assert.match(studio,/id="trainingFormCard"/,'coaches keep the canonical form on boxer.html');
 assert.match(studio,/takeover_accounts_v2/,'early guard hides the old UI while a boxer is redirected');
 assert.match(shell,/if\(page==='boxer\.html'&&state\.role==='boxer'&&redirectLegacy\(\)\)return;/);
 assert.match(shell,/trainingFormCard:'training\/eigenes'/);
});
test('New static page and its JS are included in Pages release assembly',()=>{
 const builder=fs.readFileSync('./tools/assemble-pages-site.cjs','utf8');
 assert.match(publish,/node tools\/assemble-pages-site\.cjs _site/);
 assert.match(builder,/EXTENSIONS=new Set\(\['\.html','\.js','\.css'/);
 assert.match(builder,/fs\.copyFileSync\(path\.join\(source,entry\.name\)/);
 assert.match(exp,/<script src="\.\/boxer-experience\.js" defer><\/script>/);
 assert.match(publish,/takeover-app-shell\.js/);
});
