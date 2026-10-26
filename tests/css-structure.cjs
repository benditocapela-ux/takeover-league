'use strict';
// Static guard for shared stylesheets: balanced braces and existing font files.
// A single missing "}" silently disables every following rule in the browser.
const fs=require('node:fs');const assert=require('node:assert/strict');
const sheets=fs.readdirSync('.').filter(f=>f.endsWith('.css'));
for(const file of sheets){
 const css=fs.readFileSync(file,'utf8').replace(/\/\*[\s\S]*?\*\//g,'').replace(/(["'])(?:\\.|(?!\1).)*\1/g,'""');
 let depth=0,line=1;
 for(const ch of css){
  if(ch==='\n')line++;
  if(ch==='{')depth++;
  if(ch==='}'){depth--;assert.ok(depth>=0,`${file}: unexpected "}" near line ${line}`);}
 }
 assert.equal(depth,0,`${file}: ${depth} unclosed "{" block(s)`);
}
const theme=fs.readFileSync('takeover-theme.css','utf8');
const fonts=[...theme.matchAll(/url\(['"]?\.\/([^'")]+\.woff2?)['"]?\)/g)].map(m=>m[1]);
assert.ok(fonts.length>=3,'takeover-theme.css must declare the self-hosted fonts');
for(const font of fonts)assert.ok(fs.existsSync(font)&&fs.statSync(font).size>1000,`missing font file ${font}`);
assert.doesNotMatch(fs.readdirSync('.').filter(f=>f.endsWith('.html')).map(f=>fs.readFileSync(f,'utf8')).join('\n'),/fonts\.(googleapis|gstatic)\.com/,'fonts must stay self-hosted');
console.log(`PASS: ${sheets.length} stylesheets balanced, ${fonts.length} self-hosted font files present`);
