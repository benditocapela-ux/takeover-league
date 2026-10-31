'use strict';
// Release-only artwork copier. Public GitHub Pages must never serve unapproved
// draft images, unreferenced files, or development art/reference folders.
// Run from the repository root during Pages build:
//   node tools/publish-boxer-artpack.cjs _site
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const {validate}=require('../scripts/validate-boxer-artpack.cjs');
const ROOT='assets/boxer-artpacks/v1';
const MANIFEST='takeover-mein-boxer-artpack-manifest.js';
function loadManifest(file=MANIFEST){
 const context={window:{}};
 vm.runInNewContext(fs.readFileSync(file,'utf8'),context,{timeout:1000});
 const result=context.window.TLBoxerArtPackManifest;
 if(!result||typeof result!=='object')throw Error('Missing boxer artpack manifest');
 return result;
}
function publish(manifest,sourceRoot,destinationRoot){
 const result=validate(manifest,sourceRoot);
 // Validate draft assets in CI but NEVER include them in the public site.
 if(manifest.approved!==true)return {copied:0,skipped:true,bytes:0};
 if(result.skipped)throw Error('Approved artpack unexpectedly skipped validation');
 const names=new Set();
 for(const pose of Object.values(manifest.poses)){
  for(const variants of Object.values(pose)){
   for(const name of Object.values(variants))names.add(name);
  }
 }
 const baseReal=fs.realpathSync(sourceRoot);
 const files=[];
 for(const name of names){
  const src=path.resolve(sourceRoot,name);
  const real=fs.realpathSync(src);
  if(!real.startsWith(baseReal+path.sep))throw Error('Artwork symlink escapes source directory: '+name);
  if(!fs.statSync(real).isFile())throw Error('Artwork is not a file: '+name);
  files.push({name,src:real});
 }
 // Validate everything BEFORE copying any image.
 let bytes=0;
 for(const file of files){
  const output=path.join(destinationRoot,ROOT,file.name);
  fs.mkdirSync(path.dirname(output),{recursive:true});
  fs.copyFileSync(file.src,output);
  bytes+=fs.statSync(output).size;
 }
 return {copied:files.length,skipped:false,bytes};
}
if(require.main===module){
 const destination=process.argv[2]||'_site';
 const result=publish(loadManifest(),path.resolve(ROOT),path.resolve(destination));
 console.log(result.skipped
  ?'SKIP: unapproved premium artwork omitted from public release'
  :'PASS: '+result.copied+' approved artwork files copied to public release');
}
module.exports={loadManifest,publish};
