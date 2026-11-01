'use strict';
// Deterministic transparent crop/registration exports. Original generated sources retained.
const fs=require('fs'),path=require('path'),crypto=require('crypto');
const {chromium}=require('playwright');
const root=path.resolve(__dirname,'../tools/premium-v2'),dir=path.join(root,'completion');
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
(async()=>{const pieces={},sources={};fs.mkdirSync(path.join(dir,'assets'),{recursive:true});const browser=await chromium.launch();try{const page=await browser.newPage();
for(const id of ['coat-neon-guard','coat-neon-cool','coat-drache-guard','coat-drache-cool','top-cool-jacke','coat-rig-body']){
 const source=path.join(dir,'sources',id+'.png');if(!fs.existsSync(source))continue;
 const box=id.startsWith('coat')?[155,180,475,750]:[190,210,390,345];
 const exported=await page.evaluate(async({url,box})=>{const im=new Image();im.src=url;await im.decode();const c=document.createElement('canvas');c.width=im.width;c.height=im.height;const g=c.getContext('2d');g.drawImage(im,0,0);const data=g.getImageData(0,0,c.width,c.height).data;
 let x0=c.width,y0=c.height,x1=0,y1=0;for(let y=0;y<c.height;y++)for(let x=0;x<c.width;x++)if(data[(y*c.width+x)*4+3]>8){x0=Math.min(x0,x);y0=Math.min(y0,y);x1=Math.max(x1,x);y1=Math.max(y1,y)}
 const crop=[x0,y0,x1-x0+1,y1-y0+1],out=document.createElement('canvas');out.width=box[2];out.height=box[3];out.getContext('2d').drawImage(im,...crop,0,0,box[2],box[3]);return {png:out.toDataURL('image/png').split(',')[1],crop,dimensions:[im.width,im.height]};},{url:'data:image/png;base64,'+fs.readFileSync(source).toString('base64'),box});
 const bytes=Buffer.from(exported.png,'base64');fs.writeFileSync(path.join(dir,'assets',id+'.png'),bytes);
 pieces[id]={id,slot:id.startsWith('coat')?'coatFront':'top',src:'completion/assets/'+id+'.png',uv:[0,0,box[2],box[3]],box,sha256:hash(bytes),bytes:bytes.length};sources[id]={file:'completion/sources/'+id+'.png',sha256:hash(fs.readFileSync(source)),dimensions:exported.dimensions,crop:exported.crop};console.log(id,exported.crop,box);
}
const clean=JSON.parse(fs.readFileSync(path.join(root,'production-art/manifest.json'))).pieces['coat-back-clean'];
for(const style of ['neon','drache'])pieces['coat-'+style+'-back']={...clean,id:'coat-'+style+'-back',material:style};
fs.writeFileSync(path.join(dir,'manifest.json'),JSON.stringify({version:1,enabled:false,status:'visual-validation-pending',pieces,sources},null,2)+'\n');}finally{await browser.close()}
})().catch(e=>{console.error(e);process.exitCode=1});
