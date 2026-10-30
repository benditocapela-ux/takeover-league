'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),
 path=require('node:path'),os=require('node:os'),
 {execFileSync}=require('node:child_process'),vm=require('node:vm');
const {NAMES,digest,readAll,importPack}=require('../scripts/import-original-cool-artpack.cjs');
const {validate}=require('../scripts/validate-boxer-artpack.cjs');
const root=fs.mkdtempSync(path.join(os.tmpdir(),'takeover-original-import-'));
try{
 const sources=path.join(root,'src'),repo=path.join(root,'repo'),zip=path.join(root,'original.zip');
 fs.mkdirSync(sources);fs.mkdirSync(repo);
 const expected={};
 for(const name of NAMES){
  const buf=Buffer.alloc(50);Buffer.from('89504e470d0a1a0a','hex').copy(buf);
  buf.writeUInt32BE(13,8);buf.write('IHDR',12);buf.writeUInt32BE(768,16);
  buf.writeUInt32BE(1216,20);buf[24]=8;buf[25]=6;
  buf.write(name,33); // unique fixture bytes, not production raster data
  fs.writeFileSync(path.join(sources,name+'.png'),buf);
  expected[name]=digest(buf);
 }
 execFileSync('zip',['-j','-q',zip,...NAMES.map(name=>path.join(sources,name+'.png'))]);
 fs.writeFileSync(path.join(repo,'takeover-mein-boxer-artpack-manifest.js'),
  "window.TLBoxerArtPackManifest={version:1,approved:false,enabled:false,poses:{}};");
 assert.equal(readAll(zip,expected).size,8);
 assert.throws(()=>readAll(zip),/SHA-256 reference mismatch/,
  'only the exact original reference is accepted by default');
 const dry=importPack(zip,repo,{expected,dryRun:true});
 assert.equal(dry.dryRun,true);
 assert.equal(fs.existsSync(path.join(repo,'assets')),false,'dry-run never writes');
 const result=importPack(zip,repo,{expected});
 assert.equal(result.files,8);
 const ctx={window:{}};vm.createContext(ctx);
 vm.runInContext(fs.readFileSync(path.join(repo,'takeover-mein-boxer-artpack-manifest.js'),'utf8'),ctx);
 const manifest=ctx.window.TLBoxerArtPackManifest;
 assert.equal(manifest.approved,false);
 assert.equal(manifest.enabled,false);
 assert.equal(manifest.poses.cool.hair['afro/schwarz'],'cool/hair.png');
 assert.equal(manifest.poses.cool.coatFront.samurai,'cool/coatFront.png');
 assert.equal(validate(manifest,path.join(repo,'assets/boxer-artpacks/v1')).checked,8,
  'draft copied assets pass existing file header/byte validator');
 assert.equal(importPack(zip,repo,{expected}).files,8,'repeated identical import safe');
 const changed=path.join(repo,'assets/boxer-artpacks/v1/cool/body.png');
 fs.appendFileSync(changed,'tampered');
 assert.throws(()=>importPack(zip,repo,{expected}),/Different artwork already exists/,
  'existing edits must never be overwritten');
 fs.writeFileSync(path.join(repo,'takeover-mein-boxer-artpack-manifest.js'),
  'window.TLBoxerArtPackManifest={version:1,approved:true,enabled:true,poses:{}};');
 assert.throws(()=>importPack(zip,repo,{expected}),/Expected empty, unapproved/,
  'import must not touch a released manifest');
 console.log('PASS: original art ZIP importer, sha-checks, dry-run, safe idempotency and release protection');
}finally{fs.rmSync(root,{recursive:true,force:true})}
