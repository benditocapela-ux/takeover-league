'use strict';
// Validate approved local Boxer ArtPack files without installing image packages.
// Run: node scripts/validate-boxer-artpack.cjs
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const ROOT=path.resolve('assets/boxer-artpacks/v1');
const MANIFEST='takeover-mein-boxer-artpack-manifest.js';
const PATH=/^[a-z0-9_-]+(?:\/[a-z0-9_-]+)*\.(?:png|webp)$/;
const EXPECTED_WIDTH=768,EXPECTED_HEIGHT=1216;
const MAX_FILE=2*1024*1024;
// The mobile hero displays up to ten full-resolution transparent layers.
// The upper bound is deliberately lower than ten independent 2 MiB files.
const MAX_OUTFIT=6*1024*1024;
function meta(data,filename){
 if(filename.endsWith('.png')){
  if(data.length<26||!data.subarray(0,8).equals(Buffer.from([137,80,78,71,13,10,26,10])))throw Error('Invalid PNG header');
  if(data.toString('ascii',12,16)!=='IHDR')throw Error('Missing PNG IHDR');
  const width=data.readUInt32BE(16),height=data.readUInt32BE(20),type=data[25];
  // RGBA and grayscale+alpha; paletted images require a tRNS chunk.
  const alpha=type===6||type===4||(type===3&&data.includes(Buffer.from('tRNS')));
  return {width,height,alpha,animated:false};
 }
 if(filename.endsWith('.webp')){
  if(data.length<30||data.toString('ascii',0,4)!=='RIFF'||data.toString('ascii',8,12)!=='WEBP')throw Error('Invalid WEBP container');
  const kind=data.toString('ascii',12,16);
  if(kind==='VP8X'){
   const flag=data[20],width=1+data.readUIntLE(24,3),height=1+data.readUIntLE(27,3);
   return {width,height,alpha:!!(flag&0x10),animated:!!(flag&0x02)};
  }
  if(kind==='VP8L'&&data[20]===0x2f){
   const v=data.readUInt32LE(21);
   return {width:1+(v&0x3fff),height:1+((v>>>14)&0x3fff),alpha:!!(v&0x10000000),animated:false};
  }
  throw Error('Unsupported opaque or unextended WebP (use transparent WebP)');
 }
 throw Error('Unsupported image format');
}
function validate(manifest,root=ROOT){
 if(manifest.version!==1||manifest.canvas?.width!==EXPECTED_WIDTH||manifest.canvas?.height!==EXPECTED_HEIGHT)throw Error('Canvas must be 768 x 1216');
 if(manifest.enabled===true&&manifest.approved!==true)throw Error('Live artwork cannot be enabled before approval');
 const poses=manifest.poses||{};
 if(!poses||typeof poses!=='object'||Array.isArray(poses))throw Error('Invalid artpack poses');
 if(Object.keys(poses).length===0){
  if(manifest.approved===true)throw Error('Approved manifest has no poses');
  return {skipped:true,checked:0,totalBytes:0,maxOutfitBytes:0};
 }
 // Draft artwork is validated BEFORE approving it. Release flags are not
 // required to check new image files, so reviewers can catch mistakes early.
 const paths=new Set();
 for(const [pose,groups] of Object.entries(poses)){
  if(!/^[a-z0-9_-]{1,32}$/.test(pose))throw Error('Unsafe pose key: '+pose);
  if(!groups||typeof groups!=='object')throw Error('Invalid pose: '+pose);
  for(const required of ['body','bottom','feet','eyes','hands']){
   if(!groups[required]||!Object.keys(groups[required]).length)throw Error('Missing required layer group '+pose+':'+required);
  }
  for(const [slot,variants] of Object.entries(groups)){
   if(!['coatBack','body','bottom','feet','top','eyes','hair','head','coatFront','hands'].includes(slot))throw Error('Unknown art slot: '+slot);
   if(!variants||typeof variants!=='object')throw Error('Invalid slot: '+slot);
   for(const [key,file] of Object.entries(variants)){
    if(!key||typeof file!=='string'||!PATH.test(file))throw Error('Invalid asset path for '+pose+'/'+slot+'/'+key);
    paths.add(file);
   }
  }
 }
 let totalBytes=0;
 const sizes=new Map();
 for(const file of paths){
  const full=path.resolve(root,file);
  if(!full.startsWith(path.resolve(root)+path.sep))throw Error('Path outside asset root: '+file);
  const data=fs.readFileSync(full);
  if(data.length>MAX_FILE)throw Error('Asset exceeds 2 MiB: '+file);
  const m=meta(data,file);totalBytes+=data.length;sizes.set(file,data.length);
  if(m.width!==EXPECTED_WIDTH||m.height!==EXPECTED_HEIGHT)throw Error('Wrong dimensions '+file+': '+m.width+'x'+m.height);
  if(!m.alpha)throw Error('Image has no transparency channel: '+file);
  if(m.animated)throw Error('Animated asset not permitted: '+file);
 }
 // Conservative worst-case bound: largest variant of each visible art slot.
 // Actual outfits may hide hair or a coat; overestimating is intentional.
 let maxOutfitBytes=0;
 for(const groups of Object.values(poses)){
  let bytes=0;
  for(const variants of Object.values(groups)){
   const sizesForSlot=Object.values(variants).map(file=>sizes.get(file));
   bytes+=Math.max(0,...sizesForSlot);
  }
  if(bytes>MAX_OUTFIT)throw Error('Outfit exceeds mobile 6 MiB image budget: '+bytes+' bytes');
  maxOutfitBytes=Math.max(maxOutfitBytes,bytes);
 }
 return {skipped:false,checked:paths.size,totalBytes,maxOutfitBytes};
}
if(require.main===module){
 const context={window:{}};
 vm.runInNewContext(fs.readFileSync(MANIFEST,'utf8'),context,{timeout:1000});
 const result=validate(context.window.TLBoxerArtPackManifest||{});
 console.log(result.skipped?'SKIP: no artpack poses yet; SVG remains active':
  'PASS: '+result.checked+' transparent, aligned image layers ('+Math.round(result.totalBytes/1024)+' KiB total; up to '+Math.round(result.maxOutfitBytes/1024)+' KiB per outfit)');
}
module.exports={meta,validate};
