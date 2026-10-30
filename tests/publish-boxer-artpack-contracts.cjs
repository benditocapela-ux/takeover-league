'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {publish}=require('../tools/publish-boxer-artpack.cjs');
const pagesWorkflow=fs.readFileSync('.github/workflows/takeover-pages-deploy.yml','utf8');
assert.ok(pagesWorkflow.includes("node tools/assemble-pages-site.cjs _site")&&
 fs.readFileSync('tools/assemble-pages-site.cjs','utf8').includes('publish(loadManifest('),
 'GitHub Pages release must actually invoke the artwork copier');
assert.ok(pagesWorkflow.includes("'assets/boxer-artpacks/v1/**'"),
 'changing sprites must trigger an approved release build on main');
assert.ok(pagesWorkflow.includes("branches: [main]"),
 'artifact shipping must retain the existing main-only deployment guard');

const root=fs.mkdtempSync(path.join(os.tmpdir(),'takeover-art-release-'));
const src=path.join(root,'source'),target=path.join(root,'_site');
const png=(w=768,h=1216)=>{
 const b=Buffer.alloc(33);Buffer.from([137,80,78,71,13,10,26,10]).copy(b,0);
 b.writeUInt32BE(13,8);b.write('IHDR',12);b.writeUInt32BE(w,16);
 b.writeUInt32BE(h,20);b[24]=8;b[25]=6;return b;
};
try{
 const file='body/approved.png',unused='reference/unapproved.png';
 fs.mkdirSync(path.join(src,'body'),{recursive:true});
 fs.mkdirSync(path.join(src,'reference'),{recursive:true});
 fs.writeFileSync(path.join(src,file),png());
 fs.writeFileSync(path.join(src,unused),png());
 const layers={body:{'6':file},bottom:{boxer:file},feet:{boots:file},
  eyes:{braun:file},hands:{wraps:file}};
 const manifest={version:1,approved:false,enabled:false,
  canvas:{width:768,height:1216},poses:{cool:layers}};
 const output=path.join(target,'assets/boxer-artpacks/v1',file);
 const hidden=path.join(target,'assets/boxer-artpacks/v1',unused);
 assert.equal(publish(manifest,src,target).skipped,true,'draft can be validated without publishing');
 assert.ok(!fs.existsSync(output),'unapproved reference art is not publicly copied');
 assert.equal(publish({...manifest,poses:{}},src,target).copied,0,
  'empty disabled manifest is safe without art assets');
 assert.throws(()=>publish({...manifest,enabled:true},src,target),/cannot be enabled before approval/,
  'unsafe launch flag must fail the release');
 const approved={...manifest,approved:true};
 const published=publish(approved,src,target);
 assert.equal(published.copied,1,'shared sprite path is copied only once');
 assert.equal(published.bytes,33);
 assert.deepEqual(fs.readFileSync(output),png(),'exact bytes are preserved');
 assert.equal(fs.existsSync(hidden),false,'unreferenced images never ship');
 assert.throws(()=>publish({...approved,poses:{cool:{...layers,eyes:{braun:'body/unknown.png'}}}},src,target),
  /ENOENT/,'missing artwork fails the Pages build');
 const escaped={...approved,poses:{cool:{...layers,eyes:{braun:'../reference/unapproved.png'}}}};
 assert.throws(()=>publish(escaped,src,target),/Invalid asset path/,'path traversal is denied');
 const linked='body/linked/outside.png',outside=path.join(root,'outside');
 fs.mkdirSync(outside);fs.writeFileSync(path.join(outside,'outside.png'),png());
 // Directory junctions exercise the same realpath escape on Windows without
 // requiring privileged file-symlink creation; Unix uses a directory symlink.
 fs.symlinkSync(outside,path.join(src,'body/linked'),process.platform==='win32'?'junction':'dir');
 assert.throws(()=>publish({...approved,poses:{cool:{...layers,eyes:{braun:linked}}}},src,target),
  /symlink escapes/,'linked artwork cannot leak private files');
}finally{fs.rmSync(root,{recursive:true,force:true});}
console.log('PASS: release publishes only approved, present, safe referenced art and omits drafts');
