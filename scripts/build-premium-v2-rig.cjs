'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {createCanvas,loadImage}=require(process.env.CANVAS_MODULE||'@napi-rs/canvas');
const dir='tools/premium-v2/rig';
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
(async()=>{
 const source=fs.readFileSync(path.join(dir,'source-arm-master-v2.png')),im=await loadImage(path.resolve(dir,'source-arm-master-v2.png'));
 const cv=createCanvas(im.width,im.height),g=cv.getContext('2d');g.drawImage(im,0,0);
 const src=g.getImageData(0,0,im.width,im.height),labels=new Int32Array(im.width*im.height),groups=[];let label=0;
 for(let index=0;index<labels.length;index++){
   if(labels[index]||!src.data[index*4+3])continue;
   label++;const queue=[index];labels[index]=label;let start=0,xmin=im.width,ymin=im.height,xmax=0,ymax=0;
   while(start<queue.length){const i=queue[start++],x=i%im.width,y=Math.floor(i/im.width);xmin=Math.min(xmin,x);xmax=Math.max(xmax,x);ymin=Math.min(ymin,y);ymax=Math.max(ymax,y);for(const n of [x>0?i-1:-1,x<im.width-1?i+1:-1,y>0?i-im.width:-1,y<im.height-1?i+im.width:-1])if(n>=0&&!labels[n]&&src.data[n*4+3]){labels[n]=label;queue.push(n)}}
   if(queue.length>10000)groups.push({label,pixels:queue.length,box:[xmin,ymin,xmax-xmin+1,ymax-ymin+1]});
 }
 groups.sort((a,b)=>a.box[0]-b.box[0]);if(groups.length!==3)throw Error('Expected exactly three disconnected authored parts: '+JSON.stringify(groups));
 const unit=im.width/1280;
 const specs=[['upper',[290,260],[244,941],.23],['forearm',[551,952],[849,382],.255],['hand',[1076,956],[1060,658],.205]].map(([id,p,d,s])=>[id,p.map(v=>v*unit),d.map(v=>v*unit),s/unit]);
 const manifest={version:2,approved:false,enabled:false,status:'Artistically pending',canvas:[450,500],shoulder:[160,180],source:{file:'source-arm-master-v2.png',sha256:hash(source),size:[im.width,im.height]},scope:'One right arm, front camera, nine combinations of shoulder/elbow -10/0/+10 degrees; no torso or outfit integration',parts:{},quality:{technicalResults:'evidence/chromium-rig.json and evidence/webkit-rig.json',artisticallyApproved:false,open:['remaining wrist join edge and rotating baked highlights','shoulder-to-torso connection not authored','elbow curvature needs full-body acceptance','no perspective change or clothing deformation']}};
 for(let i=0;i<groups.length;i++){
   const group=groups[i],[key,proximal,distal,scale]=specs[i],[x,y,w,h]=group.box;
   const c=createCanvas(w,h),ct=c.getContext('2d'),d=ct.createImageData(w,h);
   for(let yy=0;yy<h;yy++)for(let xx=0;xx<w;xx++){const si=(yy+y)*im.width+xx+x;if(labels[si]===group.label)for(let k=0;k<4;k++)d.data[(yy*w+xx)*4+k]=src.data[si*4+k]}
   ct.putImageData(d,0,0);const png=c.toBuffer('image/png');fs.writeFileSync(path.join(dir,key+'.png'),png);
   manifest.parts[key]={src:key+'.png',sha256:hash(png),sourceBox:group.box,sourcePixels:group.pixels,size:[w*scale,h*scale],scale,pivot:[(proximal[0]-x)*scale,(proximal[1]-y)*scale],distal:[(distal[0]-x)*scale,(distal[1]-y)*scale],sourceAnchor:{proximal,distal}};
 }
 fs.writeFileSync(path.join(dir,'manifest.json'),JSON.stringify(manifest,null,2)+'\n');console.log(JSON.stringify({groups,parts:manifest.parts},null,2));
})().catch(e=>{console.error(e);process.exitCode=1});
