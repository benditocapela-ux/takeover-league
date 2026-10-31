'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),os=require('node:os'),vm=require('node:vm');
const {assemble}=require('../tools/assemble-pages-site.cjs');
function fixture(){
 const directory=fs.mkdtempSync(path.join(os.tmpdir(),'takeover-pages-review-'));
 const result=assemble(process.cwd(),directory);
 const cleanup=()=>{if(!path.resolve(directory).startsWith(path.resolve(os.tmpdir())+path.sep+'takeover-pages-review-'))throw Error('Unexpected fixture path');fs.rmSync(directory,{recursive:true,force:true})};
 return {directory,result,cleanup};
}
function verify(f){
 assert.equal(f.result.artwork.copied,0);assert.equal(f.result.artwork.skipped,true);
 assert.ok(!fs.existsSync(path.join(f.directory,'assets/boxer-artpacks')),'no original or modular draft PNG ships');
 for(const name of ['docs','tools','tests','scripts','.env','challenges-v2-preview.html','duels-v2-preview.html','league2-preview.html'])
  assert.ok(!fs.existsSync(path.join(f.directory,name)),'not a release file: '+name);
 for(const name of ['mein-boxer.html','takeover-holo.js','takeover-mein-boxer-artpack.js','takeover-mein-boxer.css','takeover-inter.woff','takeover-barlow-condensed-700.woff','takeover-barlow-condensed-800.woff'])
  assert.deepEqual(fs.readFileSync(path.join(f.directory,name)),fs.readFileSync(name),'exact release source: '+name);
 const ctx={window:{}};vm.createContext(ctx);
 for(const name of ['takeover-mein-boxer-artpack-manifest.js','takeover-mein-boxer-modular-manifest.js'])vm.runInContext(fs.readFileSync(path.join(f.directory,name),'utf8'),ctx);
 for(const m of [ctx.window.TLBoxerArtPackManifest,ctx.window.TLBoxerModularDraftManifest]){assert.equal(m.approved,false);assert.equal(m.enabled,false)}
 assert.throws(()=>assemble(process.cwd(),f.directory),/empty/,'stale staging is rejected instead of retaining old media');
 assert.match(fs.readFileSync('.github/workflows/takeover-pages-deploy.yml','utf8'),/node tools\/assemble-pages-site.cjs _site/,'test executes the same assembler as Pages');
 return f.result;
}
if(require.main===module){const f=fixture();try{console.log('PASS isolated Pages assembly: '+JSON.stringify(verify(f)))}finally{f.cleanup()}}
module.exports={fixture,verify};
