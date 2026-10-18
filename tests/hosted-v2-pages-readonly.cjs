// Read-only Pages deployment probe. Does not publish or edit anything.
const assert=require('node:assert/strict');
const fs=require('node:fs');
const base='https://benditocapela-ux.github.io/takeover-league/';
const checks=['','login.html','boxer.html','coach.html'];
(async()=>{
 const results=[];
 for(const path of checks){
  try{
   const response=await fetch(base+path,{method:'GET',redirect:'follow',signal:AbortSignal.timeout(12000)});
   const txt=response.ok?await response.text():'';
   const match=response.ok&&(/Takeover League|takeover-league/i.test(txt));
   results.push({path:path||'index.html',status:response.status,match});
  }catch(e){results.push({path:path||'index.html',status:'unreachable',match:false})}
 }
 const ready=results.every(x=>x.status===200&&x.match);
 const summary=['### Hosted GitHub Pages status (read-only)',
  ...results.map(x=>'- '+x.path+': HTTP '+x.status+'; expected content '+(x.match?'found':'not confirmed')),
  'Site accessible: '+(ready?'YES':'NO/UNKNOWN'),
  'This probe does not validate custom domains or change deployment settings.',''].join('\n');
 console.log(summary);
 if(process.env.GITHUB_STEP_SUMMARY)fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY,summary+'\n');
 // Diagnostic only: a custom domain or newly configured Pages site may differ.
 // Keep this as an explicit release gate to check manually, not a CI deployment.
 assert.ok(results.length===checks.length);
})().catch(e=>{console.error(e);process.exitCode=1});
