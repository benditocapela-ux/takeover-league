const fs=require('node:fs');
const assert=require('node:assert/strict');
const {JSDOM}=require('jsdom');
const html=fs.readFileSync('index.html','utf8');

// Protect the existing league look and bottom navigation against a redesign.
for(const original of [
 '--bg:#0b1220','--surface:#172235','--gold:#e8b953',
 'THE TAKEOVER 🥊','id="podium"','id="ranking"','id="levels"','id="history"',
 '🏆 Podium','📊 Ranking','🥊 Levels','📜 History','👤 Dashboard',
 'id="podium-content"','id="ranking-content"','id="levels-content"','id="history-content"'
]) assert.ok(html.includes(original),'Legacy UI changed: '+original);
assert.ok(!html.includes('href="./features.html"'),'Stale coming-soon navigation remains');
assert.match(html,/takeover-menu-panel/);
assert.match(html,/takeover-menu-backdrop/);
assert.match(html,/takeover-menu-open/);
assert.match(html,/\.bottom button\.nav\[data-tab\]/,'Tab listener must ignore drawer trigger / ordinary links');
const dom=new JSDOM(html,{url:'https://benditocapela-ux.github.io/takeover-league/',runScripts:'outside-only'});
const {window}=dom,doc=window.document;
const script=Array.from(doc.scripts).map(s=>s.textContent).find(s=>s.includes('setupTakeoverMenu()'));
assert.ok(script,'Menu event handlers missing');
let switched=null;
window.switchTab=tab=>{switched=tab};
window.eval(script);
const button=doc.getElementById('takeover-menu-open');
const panel=doc.getElementById('takeover-menu-panel');
const backdrop=doc.getElementById('takeover-menu-backdrop');
assert.equal(button.getAttribute('aria-expanded'),'false');
assert.equal(panel.getAttribute('aria-hidden'),'true');
assert.equal(backdrop.hidden,true);
button.click();
assert.equal(button.getAttribute('aria-expanded'),'true');
assert.equal(panel.getAttribute('aria-hidden'),'false');
assert.equal(backdrop.hidden,false);
assert.ok(doc.body.classList.contains('takeover-menu-visible'));
assert.equal(panel.querySelector('a[href="./challenges.html"]').getAttribute('href'),'./challenges.html');
assert.equal(panel.querySelector('a[href="./duels.html"]').getAttribute('href'),'./duels.html');
assert.equal(panel.querySelector('a[href="./awards.html"]').getAttribute('href'),'./awards.html');
assert.equal(panel.querySelector('a[href="./boxer.html"]').getAttribute('href'),'./boxer.html');
assert.equal(panel.querySelector('a[href="./coach.html"]').getAttribute('href'),'./coach.html');
panel.querySelector('[data-menu-tab="levels"]').click();
assert.equal(switched,'levels');
assert.equal(button.getAttribute('aria-expanded'),'false');
assert.equal(backdrop.hidden,true);
button.click();
doc.dispatchEvent(new window.KeyboardEvent('keydown',{key:'Escape',bubbles:true}));
assert.equal(backdrop.hidden,true);
button.click();
backdrop.click();
assert.equal(panel.getAttribute('aria-hidden'),'true');
assert.equal(doc.querySelectorAll('.bottom button.nav[data-tab]').length,4);
assert.equal(doc.querySelectorAll('.bottom .nav').length,6);
console.log('PASS: Original league palette + tabs preserved; menu, links, keyboard and close controls work.');
