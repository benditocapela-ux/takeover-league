'use strict';
// Acceptance gate for the eight ORIGINAL user-approved reference PNGs.
// Missing artwork is explicitly PENDING in GitHub Actions, not advertised as
// tested. Once any sprite is committed the entire set MUST validate.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const {NAMES,SHA,digest}=require('../scripts/import-original-cool-artpack.cjs');
const {validate}=require('../scripts/validate-boxer-artpack.cjs');
function report(root=process.cwd(),opts={}){
 const base=path.join(root,'assets/boxer-artpacks/v1');
 const dir=path.join(base,'cool');
 const present=NAMES.filter(n=>fs.existsSync(path.join(dir,n.toLowerCase()+'.png')));
 const context={window:{}};
 vm.runInNewContext(fs.readFileSync(path.join(root,'takeover-mein-boxer-artpack-manifest.js'),'utf8'),
  context,{timeout:1000});
 const manifest=context.window.TLBoxerArtPackManifest;
 if(!manifest||manifest.approved!==false||manifest.enabled!==false)
  throw Error('PR original reference must remain approved:false and enabled:false');
 const poses=manifest.poses||{};
 if(present.length===0){
  if(Object.keys(poses).length!==0)throw Error('Draft has manifest paths without actual PNG files');
  return {state:'PENDING',count:0,totalBytes:0,
   message:'Eight original raster layers still need to be committed to the PR. Unit tests cannot replace visual asset verification.'};
 }
 if(present.length!==NAMES.length)
  throw Error('Partial original raster package: '+present.length+'/8 present');
 const files=NAMES.map(name=>{
  const full=path.join(dir,name.toLowerCase()+'.png'),data=fs.readFileSync(full);
  if(digest(data)!==SHA[name])throw Error('Original raster SHA-256 mismatch: '+name);
  return {name,bytes:data.length};
 });
 if(!poses.cool||Object.keys(poses).length!==1)
  throw Error('Expected exactly one draft original cool-pose manifest');
 const keys=poses.cool;
 for(const [slot,key,filename] of [
  ['coatBack','samurai','coatback.png'],
  ['body','6','body.png'],
  ['bottom','boxer/schwarz','bottom.png'],
  ['feet','boots/schwarz','feet.png'],
  ['eyes','braun','eyes.png'],
  ['hair','afro/schwarz','hair.png'],
  ['coatFront','samurai','coatfront.png'],
  ['hands','wraps','hands.png']
 ]){
  if(keys[slot]?.[key]!=='cool/'+filename)
   throw Error('Incorrect manifest mapping '+slot+' '+key);
 }
 const validated=validate(manifest,base);
 if(validated.checked!==8)throw Error('Validator did not verify all eight raster files');
 return {state:'VERIFIED',count:8,totalBytes:files.reduce((n,f)=>n+f.bytes,0),
  message:'Original SHA-256 sprite pack and disabled draft manifest are complete. Actual independent outfits still require retouching.'};
}
if(require.main===module){
 try{
  const r=report();
  const message='Original Cool Sprite Art: '+r.state+' ('+r.count+'/8, '+r.totalBytes+' bytes). '+r.message;
  console.log(message);
  if(process.env.GITHUB_STEP_SUMMARY)
   fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY,
    '\n### Mein Boxer – original raster art readiness\n\n'+message+'\n');
 }catch(e){console.error('FAIL: '+e.message);process.exitCode=1}
}
module.exports={report};
