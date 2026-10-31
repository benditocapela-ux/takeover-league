'use strict';
// Offline authoring only. No application imports, database or network writes.
// CANVAS_MODULE may point at an existing @napi-rs/canvas installation.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {createCanvas,loadImage}=require(process.env.CANVAS_MODULE||'@napi-rs/canvas');
const source=process.argv[2];if(!source)throw Error('Usage: node scripts/build-premium-v2-pilot.cjs <four-source-png-directory>');
const dest='tools/premium-v2/assets',v1='assets/boxer-artpacks/v1/modular-cool/';
fs.mkdirSync(dest,{recursive:true});
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const canvas=()=>createCanvas(768,1216);
function crop(image,box){const [x,y,w,h]=box,c=createCanvas(w,h);c.getContext('2d').drawImage(image,x,y,w,h,0,0,w,h);return c}
function blend(a,b,start,end){const c=canvas(),g=c.getContext('2d');g.drawImage(a,0,0);const ad=g.getImageData(0,0,768,1216);g.clearRect(0,0,768,1216);g.drawImage(b,0,0);const bd=g.getImageData(0,0,768,1216);for(let y=0;y<end;y++)for(let x=0;x<768;x++){const i=(y*768+x)*4,w=y<start?1:(end-y)/(end-start),aa=ad.data[i+3]*(1-w),ba=bd.data[i+3]*w,alpha=aa+ba;for(let k=0;k<3;k++)ad.data[i+k]=alpha?Math.round((ad.data[i+k]*aa+bd.data[i+k]*ba)/alpha):0;ad.data[i+3]=Math.round(alpha)}g.putImageData(ad,0,0);return c}
function bounds(im,x0,x1){const c=createCanvas(im.width,im.height),g=c.getContext('2d');g.drawImage(im,0,0);const d=g.getImageData(0,0,c.width,c.height).data;let l=x1,t=c.height,r=0,b=0;for(let y=0;y<c.height;y++)for(let x=x0;x<x1;x++)if(d[(y*c.width+x)*4+3]>16){l=Math.min(l,x);r=Math.max(r,x);t=Math.min(t,y);b=Math.max(b,y)}return [l,t,r-l+1,b-t+1]}
(async()=>{
 const names=['body','coatback','coatfront','feet','eyes','hair-afro','hair-short','bottom-black','bottom-red','top-tank','hands-blackgold','hands-white'];
 const old={};for(const name of names)old[name]=await loadImage(v1+name+'.png');
 const raw={};for(const name of ['body','coat','black','white'])raw[name]=await loadImage(path.join(source,name+'.png'));
 const newBody=canvas(),ng=newBody.getContext('2d');ng.drawImage(raw.body,0,8,768,1216);
 // Keep head and lower body from Cool; the middle is a pose-specific key drawing.
 const upperBody=blend(newBody,old.body,230,250),body=canvas(),bg=body.getContext('2d');bg.drawImage(old.body,0,0);bg.clearRect(0,230,768,320);bg.drawImage(upperBody,0,230,768,320,0,230,768,320);
 const newCoat=canvas(),cg=newCoat.getContext('2d');cg.translate(384-16,0);cg.scale(1.1,1);cg.translate(-384,0);cg.drawImage(raw.coat,57,65,raw.coat.width*.66,raw.coat.height*.66);
 const coat=blend(old.coatfront,newCoat,490,590);
 const gloves={};const handBounds={};for(const color of ['black','white']){const c=canvas(),g=c.getContext('2d'),im=raw[color];handBounds[color]=[];for(let side=0;side<2;side++){const b=bounds(im,side?Math.floor(im.width/2):0,side?im.width:Math.floor(im.width/2));handBounds[color].push(b);const scale=112/b[3],w=b[2]*scale;const x=side?458-w*.62:315-w*.42;g.drawImage(im,...b,x,170,w,112)}gloves[color]=c}
 const pieces=[];const add=(id,img,box,slot,origin)=>pieces.push({id,slot,origin,box,canvas:crop(img,box)});
 add('head',old.body,[270,50,230,180],'body','cool-exact');
 add('lower',old.body,[155,550,465,625],'body','cool-exact');
 add('body-cool',old.body,[195,230,380,320],'body','cool-exact');
 add('body-guard',body,[195,230,380,320],'body','guard-new');
 add('coat-back',old.coatback,[165,540,460,370],'coatBack','cool-exact');
 add('coat-tail',old.coatfront,[145,590,490,350],'coatFront','cool-exact');
 add('coat-cool',old.coatfront,[195,160,390,430],'coatFront','cool-exact');
 add('coat-guard',coat,[165,160,420,430],'coatFront','guard-new');
 for(const [id,box,slot] of [['feet',[150,945,480,235],'feet'],['eyes',[330,140,100,35],'eyes'],['hair-afro',[300,40,170,145],'hair'],['hair-short',[300,40,170,145],'hair'],['bottom-black',[220,540,340,265],'bottom'],['bottom-red',[220,540,340,265],'bottom'],['top-tank',[280,240,215,335],'top'],['hands-blackgold',[230,300,310,130],'hands'],['hands-white',[230,300,310,130],'hands']])add(id,old[id],box,slot,'cool-exact');
 for(const color of ['black','white'])for(let side=0;side<2;side++)add('guard-'+color+'-'+side,gloves[color],side?[405,160,110,135]:[260,160,110,135],'hands','guard-new');
 const result={version:2,approved:false,enabled:false,base:'1a55e0516c45ee3c457fc7f073cd8e412721b83e',canvas:[768,1216],pieces:{},atlases:{},sources:{},handBounds};
 for(const group of ['shared','guard']){const list=pieces.filter(p=>(p.origin==='guard-new')===(group==='guard'));let x=2,y=2,row=0;for(const p of list){const [,,w,h]=p.box;if(x+w+2>1024){x=2;y+=row+4;row=0}p.uv=[x,y,w,h];x+=w+4;row=Math.max(row,h)}const c=createCanvas(1024,y+row+2),g=c.getContext('2d');for(const p of list){g.drawImage(p.canvas,p.uv[0],p.uv[1]);result.pieces[p.id]={slot:p.slot,origin:p.origin,atlas:group,uv:p.uv,box:p.box};}const bytes=c.toBuffer('image/png');fs.writeFileSync(dest+'/'+group+'.png',bytes);result.atlases[group]={file:group+'.png',width:c.width,height:c.height,bytes:bytes.length,sha256:hash(bytes)}}
 for(const name of Object.keys(raw)){const bytes=fs.readFileSync(path.join(source,name+'.png'));result.sources[name]={sha256:hash(bytes),size:[raw[name].width,raw[name].height]}}
 // V1 comparison uses full-canvas exports of the SAME selected components.
 // This makes visual equality measurable, without comparing different drawings.
 const bake=ids=>{const c=canvas(),g=c.getContext('2d');for(const id of ids){const p=pieces.find(p=>p.id===id);g.drawImage(p.canvas,p.box[0],p.box[1])}return c};
 for(const [file,ids] of Object.entries({'body':['head','lower','body-guard'],'coat':['coat-tail','coat-guard'],'black':['guard-black-0','guard-black-1'],'white':['guard-white-0','guard-white-1']}))fs.writeFileSync(dest+'/v1-'+file+'.png',bake(ids).toBuffer('image/png'));
 fs.writeFileSync('tools/premium-v2/pilot-assets.json',JSON.stringify(result,null,2)+'\n');
 console.log(JSON.stringify(result.atlases));
})();
