'use strict';
// Static contracts for Etappe 20a: Deploy versioniert alle lokalen und nachgeladenen Skripte/Styles und liefert die Version
// (meta tl-release + version.json) für die einmalige Neu-Lade-Prüfung in takeover-navigation.js.
const fs=require('node:fs'),assert=require('node:assert/strict');
const wf=fs.readFileSync('.github/workflows/takeover-pages-deploy.yml','utf8'),nav=fs.readFileSync('takeover-navigation.js','utf8');
assert.match(wf,/sed -i -E "s#\(\(href\|src\)=\\"\\\.\/\[A-Za-z0-9\._-\]\+\\\.\(css\|js\)\)\\"#\\1\?v=\$\{release\}\\"#g" _site\/\*\.html/,'html links versioned');
assert.match(wf,/sed -i -E "s#\(\\\.src='\)\\\.\/\(\[A-Za-z0-9\._-\]\+\\\.js\)'#\\1\.\/\\2\?v=\$\{release\}'#g" _site\/\*\.js/,'dynamic scripts versioned');
assert.match(wf,/Unversioned dynamic script left/);
assert.match(wf,/<meta name=\\"tl-release\\" content=\\"\$\{release\}\\">/);
assert.match(wf,/printf '\{"release":"%s"\}\\n' "\$\{release\}" > _site\/version.json/);
// Jede dynamisch geladene Datei nutzt das Muster, das der Deploy versioniert
for(const f of fs.readdirSync('.').filter(f=>/\.js$/.test(f))){
 const t=fs.readFileSync(f,'utf8');
 for(const m of t.matchAll(/\.src\s*=\s*(["'`])\.\/([^"'`]+)\1/g))assert.equal(m[1],"'",f+': dynamic script must use single quotes: '+m[2]);
}
assert.match(nav,/function freshRelease\(\)/);
assert.match(nav,/\/\^\[0-9a-f\]\{7,40\}\$\/\.test\(next\)\|\|next===cur\|\|touched\|\|Date\.now\(\)-t0>5000/,'only right after opening, never after input');
assert.match(nav,/sessionStorage\.setItem\(key,next\)\}catch\(_\)\{return\}/,'no reload loop without storage');
assert.match(nav,/fetch\('\.\/version\.json\?t='\+t0,\{cache:'no-store'\}\)/);
// Seiten dürfen Skripte nicht über die exakte, unversionierte Adresse suchen
for(const f of fs.readdirSync('.').filter(f=>/\.html$/.test(f)))assert.doesNotMatch(fs.readFileSync(f,'utf8'),/script\[src="\.\/[^"]+\.js"\]/,f+' uses an exact script src selector');
console.log('PASS: Etappe 20a – Deploy versioniert Seiten-Links und nachgeladene Skripte, liefert tl-release und version.json, Seite lädt neue Version einmal und nie nach Eingaben, keine exakten Script-Selektoren');
