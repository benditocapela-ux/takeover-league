'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {createCanvas,loadImage}=require(process.env.CANVAS_MODULE||'@napi-rs/canvas');
const dir='tools/premium-v2/headwear',hash=b=>crypto.createHash('sha256').update(b).digest('hex');
(async()=>{
 const manifest={version:1,approved:false,enabled:false,artStatus:'Artistically pending',canvas:[768,1216],poses:['cool','guard'],colors:['schwarz'],pieces:{},sources:{},hairMasks:{cap:{type:'keepRect',rect:[0,127,768,1089],rationale:'Retain only short-hair temple pixels beneath the cap brim. Afro and long styles are not supported.'},band:{type:'none',rationale:'Front band overlays short/afro hairline; existing hair silhouette is retained.'}},supportedHair:{cap:['kurz_glatt'],band:['kurz_glatt','afro']},openArtGates:['Cap silhouette and forehead contact need user acceptance','Band tie position and material match remain artistically pending','Other head colors, long hair, hijab and raised hoods are unsupported']};
 for(const [id,box] of [['cap',[307,43,155,94]],['band',[326,107,160,47]]]){
   const sourcePath=path.join(dir,'source-'+id+'.png'),source=fs.readFileSync(sourcePath),im=await loadImage(path.resolve(sourcePath)),c=createCanvas(im.width,im.height),g=c.getContext('2d');g.drawImage(im,0,0);const data=g.getImageData(0,0,c.width,c.height).data;let x0=c.width,y0=c.height,x1=0,y1=0;
   for(let y=0;y<c.height;y++)for(let x=0;x<c.width;x++)if(data[(y*c.width+x)*4+3]>8){x0=Math.min(x0,x);y0=Math.min(y0,y);x1=Math.max(x1,x);y1=Math.max(y1,y)}
   const rect=[x0,y0,x1-x0+1,y1-y0+1],width=384,height=Math.round(width*rect[3]/rect[2]),out=createCanvas(width,height);out.getContext('2d').drawImage(im,...rect,0,0,width,height);const png=out.toBuffer('image/png'),file=path.join(dir,'assets',id+'.png');fs.writeFileSync(file,png);
   // Preserve source aspect exactly in the displayed garment; the initial box height is a registration hint only.
   box[3]=box[2]*height/width;
   manifest.pieces[id]={id:'head-'+id+'-schwarz',slot:'head',src:'headwear/assets/'+id+'.png',uv:[0,0,width,height],box,sha256:hash(png),bytes:png.length,origin:'new-anime-draft',itemKey:id,color:'schwarz'};
   manifest.sources[id]={file:'source-'+id+'.png',sha256:hash(source),dimensions:[im.width,im.height],crop:rect};
 }
 fs.writeFileSync(path.join(dir,'manifest.json'),JSON.stringify(manifest,null,2)+'\n');console.log(JSON.stringify(manifest.pieces,null,2));
})().catch(e=>{console.error(e);process.exitCode=1});
