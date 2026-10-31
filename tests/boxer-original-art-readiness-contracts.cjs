'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {report}=require('./boxer-original-art-readiness.cjs');
const {NAMES}=require('../scripts/import-original-cool-artpack.cjs');
const dir=fs.mkdtempSync(path.join(os.tmpdir(),'takeover-art-readiness-'));
try{
 const manifest=path.join(dir,'takeover-mein-boxer-artpack-manifest.js');
 const putManifest=poses=>fs.writeFileSync(manifest,
  'window.TLBoxerArtPackManifest='+JSON.stringify({
   version:1,approved:false,enabled:false,
   canvas:{width:768,height:1216},poses
  })+';');
 putManifest({});
 const pending=report(dir);
 assert.equal(pending.state,'PENDING');
 assert.equal(pending.count,0,'zero committed PNGs is explicitly unfinished');
 const base=path.join(dir,'assets/boxer-artpacks/v1/cool');
 fs.mkdirSync(base,{recursive:true});
 fs.writeFileSync(path.join(base,'body.png'),Buffer.from('not a real PNG'));
 assert.throws(()=>report(dir),/Partial original raster package: 1\/8/,
  'a partial sprite upload cannot pass CI even with release flags disabled');
 for(const name of NAMES)fs.writeFileSync(path.join(base,name.toLowerCase()+'.png'),Buffer.from('fake'));
 assert.throws(()=>report(dir),/Original raster SHA-256 mismatch/,
  'a full set of invented images cannot masquerade as approved-reference sprites');
 fs.rmSync(base,{recursive:true,force:true});
 putManifest({cool:{body:{'6':'cool/body.png'}}});
 assert.throws(()=>report(dir),/manifest paths without actual PNG/,
  'dangling draft references are a failing CI state');
 putManifest({});
 fs.writeFileSync(manifest,
  'window.TLBoxerArtPackManifest={version:1,approved:true,enabled:false,poses:{}};');
 assert.throws(()=>report(dir),/approved:false/,
  'reference reviewer cannot silently set a release approval');
 console.log('PASS: original art CI distinguishes pending, partial, fake, dangling and unapproved-only states');
}finally{fs.rmSync(dir,{recursive:true,force:true})}
