'use strict';
// Offline integrity contracts: no database, network, Supabase key or SQL execution.
const fs=require('node:fs'),path=require('node:path'),os=require('node:os'),assert=require('node:assert/strict'),{spawnSync}=require('node:child_process');
const root=path.resolve(__dirname,'..'),script=path.join(__dirname,'build-seven-hour-release-candidate.cjs');
const tempRoot=fs.realpathSync(os.tmpdir()),parent=fs.mkdtempSync(path.join(tempRoot,'tl-pr94-candidate-')),target=path.join(parent,'candidate');
const run=args=>spawnSync(process.execPath,[script,...args],{cwd:root,encoding:'utf8',timeout:10000});
function passed(args){const r=run(args);assert.equal(r.status,0,r.stderr||r.stdout);return r}
function rejected(args,message){const r=run(args);assert.notEqual(r.status,0,'Expected refusal: '+args);assert.match(r.stderr,message)}
try{
 passed(['--check']);passed(['--output',target]);passed(['--verify',target]);
 const manifestPath=path.join(target,'docs/seven-hour/release-candidate-manifest.json'),manifestSource=fs.readFileSync(manifestPath,'utf8'),manifest=JSON.parse(manifestSource);
 assert.equal(manifest.migrations.length,8);assert.equal(manifest.release_authorized,false);
 const migration=path.join(target,manifest.migrations[0].file),original=fs.readFileSync(migration,'utf8');
 assert.ok(!original.includes('\r'),'Exported checksums describe exact LF file bytes');
 rejected(['--output',target],/never overwrite/);assert.equal(fs.readFileSync(migration,'utf8'),original);
 fs.appendFileSync(migration,'\n-- Unexpected edit\n');rejected(['--verify',target],/checksum mismatch/);fs.writeFileSync(migration,original);
 fs.writeFileSync(migration,original.replace(/\n/g,'\r\n'));rejected(['--verify',target],/exact LF/);fs.writeFileSync(migration,original);
 const extra=path.join(target,'surprise.sql');fs.writeFileSync(extra,'SELECT 1;');rejected(['--verify',target],/missing or unexpected files/);fs.unlinkSync(extra);
 fs.writeFileSync(manifestPath,manifestSource.replace('"release_authorized": false','"release_authorized": true'));
 rejected(['--verify',target],/manifest differs/);fs.writeFileSync(manifestPath,manifestSource);
 passed(['--verify',target]);
 console.log('PASS offline candidate: eight migrations/28 SQL files, pinned hashes/LF, order/dependencies, no overwrite, tamper/extra-file/false-approval rejection');
}finally{
 // Only remove the newly created, verified direct child of the OS test-temp folder.
 const resolved=fs.realpathSync(parent);
 assert.equal(path.dirname(resolved),tempRoot);assert.ok(path.basename(resolved).startsWith('tl-pr94-candidate-'));
 fs.rmSync(resolved,{recursive:true});
}
