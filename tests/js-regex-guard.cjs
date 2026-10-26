'use strict';
// Static guard: a doubled backslash inside a JavaScript regex literal (e.g. /^\\d{4}/)
// matches a literal backslash instead of a digit. That silently broke the
// training calendar, streak and 7/30-day counters in boxer.html.
const fs=require('node:fs');const assert=require('node:assert/strict');
const files=fs.readdirSync('.').filter(f=>/\.(html|js)$/.test(f));
const pattern=/(^|[=(,:!&|?;{}\s])\/(?![/*])(?:[^/\n\\]|\\.)*?\\\\[dDsSwWb](?:[^/\n\\]|\\.)*\/[gimsuy]*\.(?:test|exec)\(|(^|[=(,:!&|?;{}\s])\/\^\\\\[dDsSwWb]/m;
const hits=[];
for(const file of files){
 fs.readFileSync(file,'utf8').split('\n').forEach((line,i)=>{if(pattern.test(line))hits.push(`${file}:${i+1}`)});
}
assert.deepEqual(hits,[],'Regex literal with doubled backslash (matches "\\" instead of a character class): '+hits.join(', '));
// The training insights date filter must accept real ISO dates.
const boxer=fs.readFileSync('boxer.html','utf8');
const m=boxer.match(/row\.status==='approved'&&(\/[^\n]*?\/)\.test\(row\.training_date/);
assert.ok(m,'training insights date filter not found');
assert.ok(new Function('return '+m[1])().test('2026-10-26'),'training insights date filter must match YYYY-MM-DD');
console.log(`PASS: ${files.length} HTML/JS files without doubled-backslash regex literals; insights date filter accepts ISO dates`);
