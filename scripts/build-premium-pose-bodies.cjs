'use strict';
const fs=require('fs'),path=require('path'),crypto=require('crypto'),{chromium}=require('playwright');
const root=path.resolve(__dirname,'../tools/premium-v2/completion'),hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const registration={
 jab:{sx:.6,tx:18,y:[[0,0],[250,210],[630,550],[1000,900]],anchors:[[[440,285],[310,300],[145,300]],[[760,310],[820,460],[730,280]]]},
 sieg:{sx:.65,tx:59,y:[[0,0],[375,210],[735,550],[1000,800]],anchors:[[[330,445],[280,630],[215,820]],[[625,385],[750,285],[815,110]]]},
 flex:{sx:.65,tx:59,y:[[0,0],[250,210],[640,550],[1000,900]],anchors:[[[340,300],[105,310],[240,140]],[[660,300],[895,310],[760,140]]]},
 ansage:{sx:.56,tx:174,y:[[0,0],[250,210],[640,550],[1000,900]],anchors:[[[200,315],[145,530],[90,735]],[[560,320],[700,350],[880,280]]]}
};
(async()=>{const browser=await chromium.launch();try{const page=await browser.newPage(),report={version:1,enabled:false,poses:{}};for(const [pose,reg]of Object.entries(registration)){const bytes=fs.readFileSync(path.join(root,'sources','body-'+pose+'.png'));
const r=await page.evaluate(async({url,reg})=>{const im=new Image();im.src=url;await im.decode();const c=document.createElement('canvas');c.width=768;c.height=800;const g=c.getContext('2d'),mapY=y=>{for(let i=1;i<reg.y.length;i++)if(y<=reg.y[i][0]){const a=reg.y[i-1],b=reg.y[i];return a[1]+(y-a[0])/(b[0]-a[0])*(b[1]-a[1])}return 800},anchors=reg.anchors.map(side=>side.map(([x,y])=>[x*reg.sx+reg.tx,mapY(y)]));
g.fillStyle='#fff';g.fillRect(0,210,768,340);
for(const [shoulder,elbow,wrist]of anchors){for(const [a,b,radius]of [[shoulder,elbow,65],[elbow,wrist,48]]){const dx=b[0]-a[0],dy=b[1]-a[1],len=Math.hypot(dx,dy),nx=-dy/len*radius,ny=dx/len*radius;g.beginPath();g.moveTo(a[0]+nx,a[1]+ny);g.lineTo(b[0]+nx,b[1]+ny);g.lineTo(b[0]-nx,b[1]-ny);g.lineTo(a[0]-nx,a[1]-ny);g.closePath();g.fill()}g.beginPath();g.moveTo(elbow[0]+52,elbow[1]);g.arc(...elbow,52,0,Math.PI*2);g.fill()}const paint=document.createElement('canvas');paint.width=768;paint.height=800;const pg=paint.getContext('2d');
for(let i=1;i<reg.y.length;i++){const a=reg.y[i-1],b=reg.y[i];pg.drawImage(im,0,a[0],im.width,b[0]-a[0],reg.tx,a[1],im.width*reg.sx,b[1]-a[1])}
g.globalCompositeOperation='source-in';g.drawImage(paint,0,0);return {png:c.toDataURL().split(',')[1],anchors};},{url:'data:image/png;base64,'+bytes.toString('base64'),reg});
const png=Buffer.from(r.png,'base64'),file='body-'+pose+'.png';fs.writeFileSync(path.join(root,'assets',file),png);report.poses[pose]={piece:{id:'body-guard',slot:'body',src:'completion/assets/'+file,uv:[0,0,768,800],box:[0,0,768,800],sha256:hash(png)},anchors:r.anchors,source:{file:'completion/sources/'+file,sha256:hash(bytes),registration:reg}};console.log(pose,r.anchors)}fs.writeFileSync(path.join(root,'pose-bodies.json'),JSON.stringify(report,null,2)+'\n');}finally{await browser.close()}})().catch(e=>{console.error(e);process.exitCode=1});
