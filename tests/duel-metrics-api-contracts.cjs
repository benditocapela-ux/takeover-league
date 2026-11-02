'use strict';
// Bridge real PostgreSQL API JSON to the browser's validators, using existing rollback fixtures.
// Requires a disposable replay database with metric migration; never accepts a managed project.
const fs=require('node:fs'),cp=require('node:child_process'),vm=require('node:vm'),assert=require('node:assert/strict');
if(!/^league21_replay_/.test(process.env.PGDATABASE||''))throw Error('PGDATABASE must explicitly name a disposable league21_replay_ database');
const context={window:{}};vm.createContext(context);for(const file of ['takeover-duel-metrics.js','takeover-duel-close.js'])vm.runInContext(fs.readFileSync(file,'utf8'),context);
const proofs=[];
for(const [file,keys] of [['tests/duel-metric-contracts-transaction.sql',['metric.jog','metric.count']],['tests/duel-metric-ranked-transaction.sql',['rankmetric.duel']]]){
 let sql=fs.readFileSync(file,'utf8');const items=keys.map(key=>`public.duel_v3_list('staff','all',20,NULL,NULL,NULL,current_setting('${key}')::uuid)->'items'->0`).join(',');
 const previews=keys.map(key=>`public.duel_v3_close_preview(current_setting('${key}')::uuid)`).join(',');
 const output=`RESET ROLE; SELECT set_config('request.jwt.claim.sub','cccccccc-cccc-4ccc-8ccc-cccccccccccc',true); SET LOCAL ROLE authenticated;
 SELECT jsonb_build_object('options',public.duel_v3_options(),'items',jsonb_build_array(${items}),'previews',jsonb_build_array(${previews}));
 `;
 assert.ok(/\nROLLBACK;/.test(sql),'fixture is rolled back');sql=sql.replace(/\nROLLBACK;/,'\n'+output+'\nROLLBACK;');
 const result=cp.spawnSync(process.env.PSQL||'psql',['-X','-q','-t','-A','-v','ON_ERROR_STOP=1'],{input:sql,encoding:'utf8',maxBuffer:8*1024*1024});
 assert.equal(result.status,0,result.stderr);const record=JSON.parse(result.stdout.split(/\r?\n/).find(line=>line.startsWith('{"items"')||line.startsWith('{"options"')||line.startsWith('{"previews"'))||'null');
 assert.ok(record,'actual API JSON emitted');assert.equal(context.window.TLDuelMetrics.validOptions(record.options),true,'actual options/revisions/type labels');
 for(let index=0;index<record.items.length;index++){const item=record.items[index];assert.equal(context.window.TLDuelMetrics.validItem(item),true,'actual list: '+JSON.stringify(item));assert.equal(context.window.TLDuelClose.validatePreview(record.previews[index],item),true,'actual preview: '+JSON.stringify(record.previews[index]))}
 proofs.push({file,...record});console.log('PASS actual PostgreSQL -> UI contract: '+file+' ('+record.items.length+' contracts)');
}
fs.mkdirSync('output/continuation/duel-metrics',{recursive:true});fs.writeFileSync('output/continuation/duel-metrics/actual-postgres-api.json',JSON.stringify(proofs,null,2));
