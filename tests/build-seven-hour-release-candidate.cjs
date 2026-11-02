'use strict';
// Offline, file-only candidate preparation. Never connects to a database or runs SQL.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'..');
const manifestPath='docs/seven-hour/release-candidate-manifest.json';
const expectedIds=['20261102084519','20261102090410','20261102093606','20261102095352','20261102095422','20261102095858','20261102101922','20261102103929'];
const lf=s=>s.replace(/\r\n/g,'\n');
const read=file=>lf(fs.readFileSync(file,'utf8'));
const digest=s=>crypto.createHash('sha256').update(s).digest('hex');
const manifestText=read(path.join(root,manifestPath)),manifest=JSON.parse(manifestText);
assert.equal(manifest.format,1);assert.equal(manifest.release_authorized,false);
assert.deepEqual(manifest.migrations.map(m=>m.id),expectedIds,'Exactly the reviewed eight migrations in order');
const files=new Map(),seen=new Set();
for(const [i,m] of manifest.migrations.entries()){
 assert.equal(m.order,i+1);for(const required of m.requires)assert.ok(seen.has(required),'Dependency comes first: '+required);seen.add(m.id);
 assert.match(m.file,new RegExp('^supabase/migrations/'+m.id+'_[a-z0-9_]+\\.sql$'));
 for(const ref of [m,m.preflight,m.postflight,m.rollback]){
  assert.match(ref.file,/^supabase\/(migrations|production-prep)\/[a-z0-9_]+\.sql$/,'Only explicit SQL source files');
  assert.match(ref.sha256_lf,/^[0-9a-f]{64}$/);
  if(files.has(ref.file))assert.equal(files.get(ref.file),ref.sha256_lf,'Conflicting duplicate reference');
  files.set(ref.file,ref.sha256_lf);
 }
 const sql=read(path.join(root,m.file));
 assert.equal((sql.match(/^\s*BEGIN;\s*$/gim)||[]).length,1,'One existing transaction per migration');
 assert.equal((sql.match(/^\s*COMMIT;\s*$/gim)||[]).length,1,'One existing commit per migration');
 assert.ok(!/^\s*\\(?:i|ir|connect|copy)\b/im.test(sql),'No psql execution directive');
}
function verifySources(){
 for(const [file,expected] of files)assert.equal(digest(read(path.join(root,file))),expected,'Reviewed source changed: '+file);
 // The older bundle intentionally selects a disjoint family. Never present it as this package.
 const older=fs.readdirSync(path.join(root,'supabase/migrations')).filter(n=>/^\d{14}_league_21_[a-z0-9_]+\.sql$/.test(n));
 assert.equal(older.length,25);assert.ok(manifest.migrations.every(m=>!older.includes(path.basename(m.file))));
}
function listFiles(dir,prefix=''){
 return fs.readdirSync(dir,{withFileTypes:true}).flatMap(e=>{
  assert.ok(!e.isSymbolicLink(),'No symlink in candidate: '+prefix+e.name);
  return e.isDirectory()?listFiles(path.join(dir,e.name),prefix+e.name+'/'):[prefix+e.name];
 });
}
function verifyPackage(dir){
 assert.ok(!fs.lstatSync(dir).isSymbolicLink(),'No symlink candidate root');
 const expected=[...files.keys(),manifestPath].sort();
 assert.deepEqual(listFiles(dir).sort(),expected,'Candidate has missing or unexpected files');
 assert.equal(fs.readFileSync(path.join(dir,manifestPath),'utf8'),manifestText,'Candidate manifest differs from reviewed manifest');
 for(const [file,hash] of files){
  const content=fs.readFileSync(path.join(dir,file),'utf8');
  assert.ok(!content.includes('\r'),'Candidate must contain exact LF files: '+file);
  assert.equal(digest(content),hash,'Candidate checksum mismatch: '+file);
 }
}
verifySources();
const args=process.argv.slice(2);
if(args.length===1&&args[0]==='--check'){
 console.log(`PASS reviewed eight-migration candidate: ${files.size} pinned SQL files; older25-migration bundle excluded; no execution`);
}else if(args.length===2&&args[0]==='--output'){
 const dir=path.resolve(args[1]);
 assert.ok(!fs.existsSync(dir),'Output must be a new directory; never overwrite an existing candidate');
 // Existing source files have BEGIN/COMMIT. Copy them separately instead of manufacturing an untested atomic bundle.
 fs.mkdirSync(dir,{recursive:true});
 for(const file of [...files.keys(),manifestPath]){
  const dest=path.join(dir,file);fs.mkdirSync(path.dirname(dest),{recursive:true});
  fs.writeFileSync(dest,read(path.join(root,file)),{flag:'wx',mode:0o600});
 }
 verifyPackage(dir);console.log('Prepared and verified offline candidate: '+dir+' (not release authorization)');
}else if(args.length===2&&args[0]==='--verify'){
 const dir=path.resolve(args[1]);verifyPackage(dir);console.log('PASS candidate matches reviewed manifest: '+dir);
}else{
 console.error('Use --check, --output <new-directory>, or --verify <candidate-directory>. No command applies SQL.');process.exitCode=2;
}
