'use strict';
// Registration/export only. Art changes are authored by Imagegen; Cool sources stay untouched.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {createCanvas,loadImage}=require(process.env.CANVAS_MODULE||'@napi-rs/canvas');
const dir='tools/premium-v2/production-art',src=dir+'/sources';
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
function bounds(im,x0=0,x1=im.width){const c=createCanvas(im.width,im.height),g=c.getContext('2d');g.drawImage(im,0,0);const d=g.getImageData(0,0,c.width,c.height).data;let l=x1,t=c.height,r=-1,b=-1;for(let y=0;y<c.height;y++)for(let x=x0;x<x1;x++)if(d[(y*c.width+x)*4+3]>16){l=Math.min(l,x);r=Math.max(r,x);t=Math.min(t,y);b=Math.max(b,y)}if(r<l)throw Error('Empty source');return[l,t,r-l+1,b-t+1]}
(async()=>{fs.mkdirSync(dir,{recursive:true});const out={version:1,base:'02414c9a3fd538198aa7b7c948b980fa6df27825',approved:false,enabled:false,artisticStatus:'Artistically pending',canvas:[768,1216],pieces:{},sources:{}};
 const add=async(id,name,slot,box,half)=>{const file=src+'/'+name+'.png';if(!fs.existsSync(file))return;const raw=fs.readFileSync(file),im=await loadImage(path.resolve(file)),b=bounds(im,half===1?Math.floor(im.width/2):0,half===0?Math.floor(im.width/2):im.width),c=createCanvas(box[2],box[3]);c.getContext('2d').drawImage(im,...b,0,0,c.width,c.height);const bytes=c.toBuffer('image/png'),target=dir+'/'+id+'.png';fs.writeFileSync(target,bytes);out.sources[name]={file:'production-art/sources/'+name+'.png',sha256:hash(raw),width:im.width,height:im.height};out.pieces[id]={id,slot,origin:'production-art-draft',src:'production-art/'+id+'.png',uv:[0,0,c.width,c.height],box,bytes:bytes.length,sha256:hash(bytes),source:name,sourceCrop:b,status:'Artwork draft',approved:false,enabled:false};};
 await add('coat-guard-v2','coat-guard','coatFront',[155,180,475,750]);
 await add('hands-master-0','gloves-guard','hands',[280,170,85,112],0);await add('hands-master-1','gloves-guard','hands',[405,170,85,112],1);
 await add('hair-stachel','hair-stachel','hair',[318,38,137,105]);
 await add('hair-undercut','hair-undercut','hair',[324,47,120,97]);
 await add('hair-buzz','hair-buzz','hair',[326,63,117,79]);
 await add('bottom-jogger','bottom-jogger','bottom',[215,545,350,505]);
 await add('bottom-kurz','bottom-kurz','bottom',[230,545,320,220]);
 await add('bottom-track','bottom-track','bottom',[215,545,350,505]);
 await add('feet-sneaker','feet-sneaker','feet',[155,1040,475,135]);
 fs.writeFileSync(dir+'/manifest.json',JSON.stringify(out,null,2)+'\n');console.log(JSON.stringify({pieces:Object.keys(out.pieces),bytes:Object.values(out.pieces).reduce((s,p)=>s+p.bytes,0)}));
})();
