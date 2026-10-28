'use strict';
// Etappe 7b: Neuigkeiten aus gemergten Pull Requests.
// Jeder PR mit einem Abschnitt «## News» liefert 1–5 kurze Zeilen in einfacher Sprache, z. B.
//   - Neu: Im Boxervergleich siehst du die Spielerkarten nebeneinander.
//   - Verbessert: …   - Behoben: …
// PRs ohne diesen Abschnitt (rein technische Änderungen) erscheinen nicht.
// Aufruf im Deploy: node tools/build-news.cjs <prs.json von der GitHub-API> <_site/news.json>
const fs=require('node:fs');
const TYPES=[[/^(neu|new)\b/i,'neu'],[/^(verbessert|besser|improved?)\b/i,'verbessert'],[/^(behoben|fix(ed)?|korrigiert)\b/i,'behoben'],[/^(geändert|changed?)\b/i,'geaendert']];
function plain(s){
 return String(s||'').replace(/\[([^\]]*)\]\([^)]*\)/g,'$1').replace(/`([^`]*)`/g,'$1').replace(/\*\*([^*]*)\*\*/g,'$1').replace(/__([^_]*)__/g,'$1')
  .replace(/<[^>]*>/g,'').replace(/[*_~]/g,'').replace(/\s+/g,' ').trim();
}
function parseNews(body){
 const lines=String(body||'').replace(/\r/g,'').split('\n');
 const start=lines.findIndex(l=>/^#{2,3}\s*news\s*$/i.test(l.trim()));
 if(start<0)return [];
 const items=[];
 for(const raw of lines.slice(start+1)){
  const l=raw.trim();
  if(/^#{1,6}\s/.test(l))break;
  const m=l.match(/^[-*•]\s+(.*)$/);if(!m)continue;
  let text=plain(m[1]),type='info';
  for(const [re,t] of TYPES){const mm=text.match(re);if(mm){type=t;text=text.slice(mm[0].length).replace(/^\s*[:\-–]\s*/,'');break}}
  if(text.length<3)continue;
  if(text.length>220)text=text.slice(0,217).replace(/\s+\S*$/,'')+' …';
  items.push({type,text});
  if(items.length>=5)break;
 }
 return items;
}
function build(prs){
 return (Array.isArray(prs)?prs:[]).filter(p=>p&&p.merged_at&&p.base&&p.base.ref==='main')
  .map(p=>({n:p.number,date:String(p.merged_at).slice(0,10),merged_at:p.merged_at,items:parseNews(p.body)}))
  .filter(e=>e.items.length).sort((a,b)=>String(b.merged_at).localeCompare(String(a.merged_at))).slice(0,30)
  .map(({merged_at,...e})=>e);
}
if(require.main===module){
 const [,,input,output]=process.argv;
 let prs=[];try{prs=JSON.parse(fs.readFileSync(input,'utf8'))}catch(e){console.warn('Keine PR-Daten, News bleiben leer:',e.message)}
 const news=build(prs);
 fs.writeFileSync(output,JSON.stringify({generated_at:new Date().toISOString(),entries:news}));
 console.log('news.json: '+news.length+' Einträge');
}
module.exports={parseNews,build,plain};
