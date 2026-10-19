'use strict';
const fs=require('node:fs');const assert=require('node:assert/strict');
const html=fs.readFileSync('boxer.html','utf8'),coach=fs.readFileSync('coach.html','utf8'),theme=fs.readFileSync('takeover-theme.css','utf8');
assert.match(html,/takeover-theme\.css/);assert.match(html,/studio/i);assert.match(html,/id="studioPanelOverview"/i);
assert.match(html,/\['boxer','coach'\]\.includes\(profile\.role\)/);
assert.match(coach,/db\.rpc\('coach_list_boxers'\)/);
assert.match(coach,/!\['admin','coach'\]\.includes\(p\.role\)/);
assert.match(theme,/--gold/);
console.log('PASS: Design foundation and coach/boxer Studio access remain intact');
