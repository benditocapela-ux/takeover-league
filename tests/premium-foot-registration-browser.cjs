'use strict';
// Real published compositor: source-preserving shoe registration, ankle fit and tile parity.
const fs=require('node:fs'),path=require('node:path'),http=require('node:http'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'..'),out=path.join(root,'output/foot-qa');
fs.mkdirSync(out,{recursive:true});const site=fs.mkdtempSync(path.join(out,'site-')),build=require('../tools/assemble-pages-site.cjs').assemble(root,site);
const server=http.createServer((req,res)=>{
 const name=new URL(req.url,'http://local').pathname.slice(1);
 if(name==='fixture.html'){const meta=fs.readFileSync(path.join(site,'mein-boxer.html'),'utf8').match(/<meta name="tl-premium-character"[^>]*>/)[0];res.setHeader('Content-Type','text/html');return res.end('<!doctype html><html><head>'+meta+'<script src="./takeover-holo.js"></script></head><body><script type="module">window.adapter=await(await import("./takeover-premium-character.js")).init();document.body.dataset.ready="true"</script></body></html>')}
 const file=path.resolve(site,name);if(!file.startsWith(site+path.sep)){res.writeHead(403);return res.end()}
 fs.readFile(file,(e,b)=>{if(e){res.writeHead(404);return res.end()}res.setHeader('Content-Type',({'.js':'text/javascript','.json':'application/json','.html':'text/html','.png':'image/png','.css':'text/css'})[path.extname(file)]||'application/octet-stream');res.end(b)});
});
(async()=>{await new Promise(r=>server.listen(0,'127.0.0.1',r));const base='http://127.0.0.1:'+server.address().port,report={version:build.premium.version,engines:[]};try{
 for(const engine of (process.env.BROWSER||'chromium,webkit').split(',')){
  const browser=await require('playwright')[engine].launch();try{
   const page=await browser.newPage(),errors=[],requests=[];page.on('pageerror',e=>errors.push(e.message));page.on('request',r=>requests.push(r.url()));
   await page.goto(base+'/fixture.html');await page.waitForFunction(()=>document.body.dataset.ready==='true');
   await page.evaluate(async()=>{const c={...TLPremiumCompletion.defaults,pose_profile:'guard',coat:'none',top:'none',feet:'sneaker'};await TLPremiumCompletion.prepare(c);await new Promise((resolve,reject)=>{const timer=setTimeout(()=>reject(Error('Shoe preview timeout')),15000),ready=()=>{if(adapter.item(c,'guard','feet',ready)){clearTimeout(timer);resolve()}};ready()})});
   assert.equal(requests.filter(u=>u.endsWith('/production-art/feet-sneaker.png')).length,1,'both registered shoes and their tile share one source load');
   const result=await page.evaluate(async()=>{
    const P=TLPremiumCompletion,cv=document.createElement('canvas');cv.width=768;cv.height=1216;const g=cv.getContext('2d',{willReadFrequently:true}),rows=[],evidence=[];
    const digest=async()=>Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',g.getImageData(0,0,768,1216).data))).join(',');
    const ankleRow=1050,sourceAnkles=[[155,10],[313,10]];
    const base=await P.prepare({...P.defaults,pose_profile:'guard',coat:'none',top:'none',feet:'boots'});P.draw(g,base.selection,base.images,'body');
    const d=g.getImageData(0,ankleRow,768,1).data,bodyAnkles=[0,1].map(side=>{const xs=[];for(let x=side*384;x<(side+1)*384;x++)if(d[x*4+3]>240)xs.push(x);if(!xs.length)throw Error('Missing bare ankle');return [(xs[0]+xs.at(-1))/2,ankleRow]});
    const config={...P.defaults,pose_profile:'guard',coat:'none',top:'none',feet:'sneaker'},fitted=await P.prepare(config),parts=fitted.selection.pieces.filter(p=>p.slot==='feet');
    if(parts.length!==2)throw Error('Shoes must have independent ankle registrations');
    const offsets=parts.map((p,i)=>{const a=sourceAnkles[i],registered=[p.box[0]+(a[0]-p.uv[0])*p.box[2]/p.uv[2],p.box[1]+(a[1]-p.uv[1])*p.box[3]/p.uv[3]],previous=[155+a[0],1040+a[1]];if(p.transform){const [aa,b,c,d,e,f]=p.transform,[x,y]=registered;registered[0]=aa*x+c*y+e;registered[1]=b*x+d*y+f;}return {body:bodyAnkles[i],source:a,registered,previous,error:Math.hypot(registered[0]-bodyAnkles[i][0],registered[1]-bodyAnkles[i][1]),previousError:Math.hypot(previous[0]-bodyAnkles[i][0],previous[1]-bodyAnkles[i][1])}});
    // Every source pixel belongs to exactly one crop or transparent space; no painted shoe detail is discarded.
    const im=fitted.images[parts[0].src],src=document.createElement('canvas');src.width=im.naturalWidth;src.height=im.naturalHeight;const sg=src.getContext('2d');sg.drawImage(im,0,0);const pixels=sg.getImageData(0,0,src.width,src.height).data;
    for(let y=0;y<src.height;y++)for(let x=0;x<src.width;x++)if(pixels[(y*src.width+x)*4+3]){const count=parts.filter(p=>x>=p.uv[0]&&x<p.uv[0]+p.uv[2]&&y>=p.uv[1]&&y<p.uv[1]+p.uv[3]).length;if(count!==1)throw Error('Lost or duplicated shoe pixel '+x+','+y)}
    async function delivered(s,images,slot,frame,max=180){const full=document.createElement('canvas');full.width=768;full.height=1216;P.draw(full.getContext('2d'),s,images,slot);const target=document.createElement('canvas'),scale=Math.min(1,max/Math.max(frame[2],frame[3]));target.width=Math.round(frame[2]*scale);target.height=Math.round(frame[3]*scale);target.getContext('2d').drawImage(full,...frame,0,0,target.width,target.height);return target.toDataURL()}
    async function rgba(url){const im=new Image();im.src=url;await im.decode();const c=document.createElement('canvas');c.width=im.naturalWidth;c.height=im.naturalHeight;const t=c.getContext('2d');t.drawImage(im,0,0);return {width:c.width,height:c.height,data:t.getImageData(0,0,c.width,c.height).data}}
    for(const pose of ['cool','guard','jab','sieg','flex','ansage'])for(const feet of ['boots','sneaker'])for(const feetc of ['schwarz','weiss','rot']){
     const c={...config,pose_profile:pose,feet,feetc},r=await P.prepare(c);if(r.renderer!=='anime-draft')throw Error('Missing outfit');
     P.draw(g,r.selection,r.images,'feet');const hash=await digest(),frame=P.itemFrame(r.selection,'feet');
     // Below the shoe collar there must be no bare heel/toe showing through.
     P.draw(g,r.selection,r.images,'body');const heel=g.getImageData(0,1100,768,100).data;
     P.draw(g,r.selection,r.images,'feet');const covered=g.getImageData(0,1100,768,100).data;
     let exposedHeel=0;const exposed=[];for(let i=3;i<heel.length;i+=4)if(heel[i]>240&&covered[i]<16){exposedHeel++;exposed.push([Math.floor(i/4)%768,1100+Math.floor(i/4/768)])}const exposedBounds=exposed.length?[Math.min(...exposed.map(p=>p[0])),Math.min(...exposed.map(p=>p[1])),Math.max(...exposed.map(p=>p[0])),Math.max(...exposed.map(p=>p[1]))]:null;
     const expected=await delivered(r.selection,r.images,'feet',frame),html=await new Promise((resolve,reject)=>{const timer=setTimeout(()=>reject(Error('Tile timeout')),15000),ready=()=>{const html=adapter.item(c,pose,'feet',ready);if(html){clearTimeout(timer);resolve(html)}};ready()}),actual=/src="([^"]+)"/.exec(html)[1],a=await rgba(expected),b=await rgba(actual);
     if(a.width!==b.width||a.height!==b.height||a.data.some((v,i)=>v!==b.data[i]))throw Error('Shoe tile differs '+pose+'/'+feet+'/'+feetc);
     for(const bottom of ['boxer','kurz','jogger','track'])for(const coat of ['none','samurai','basic']){const mix=await P.prepare({...c,bottom,coat});if(mix.renderer!=='anime-draft')throw Error('Missing combination');P.draw(g,mix.selection,mix.images,'feet');if(await digest()!==hash)throw Error('Shoe registration changed with trousers/coat')}
     if(feet==='sneaker'&&exposedHeel)throw Error('Bare heel/toes outside shoe: '+exposedHeel);
     rows.push({pose,feet,feetc,exposedHeel,exposedBounds,itemParity:true,outfits:12,digest:hash});
     if(pose==='guard'&&feetc==='schwarz'){
      const old={...r.selection,pieces:r.selection.pieces.filter(p=>p.slot!=='feet').map(p=>p.id==='lower'?{...p,bodyClipRect:undefined}:p)};old.pieces.push(...(feet==='sneaker'?[{...parts[0],uv:[0,0,475,135],box:[155,1040,475,135],transform:undefined,itemBounds:undefined}]:r.selection.pieces.filter(p=>p.slot==='feet')));
      for(const [phase,s]of [['before',old],['after',r.selection]]){P.draw(g,s,r.images);const crop=document.createElement('canvas');crop.width=540;crop.height=330;crop.getContext('2d').drawImage(cv,125,875,540,330,0,0,540,330);const zoom=document.createElement('canvas');zoom.width=1080;zoom.height=660;const z=zoom.getContext('2d');z.imageSmoothingEnabled=false;z.drawImage(crop,0,0,1080,660);evidence.push({name:feet+'-'+phase,png:crop.toDataURL(),zoom:zoom.toDataURL()})}
     }
    }
    return {bodyAnkles,offsets,rows,evidence};
   });
   console.log(engine+' exposed heel pixels: '+JSON.stringify(result.rows.filter(r=>r.feet==='sneaker'&&r.feetc==='schwarz').map(r=>({pose:r.pose,pixels:r.exposedHeel,bounds:r.exposedBounds}))));
   assert.deepEqual(errors,[]);for(const offset of result.offsets){assert.ok(offset.error<=5,'shoe cuff at bare ankle: '+JSON.stringify(offset));assert.ok(offset.error<offset.previousError/5)}
   const sourceRequests=requests.filter(u=>u.endsWith('/production-art/feet-sneaker.png'));
   assert.equal(new Set(sourceRequests).size,1,'bounded-cache eviction may reload the same source, never a second per-shoe asset');
   for(const e of result.evidence){fs.writeFileSync(path.join(out,engine+'-'+e.name+'-100.png'),Buffer.from(e.png.split(',')[1],'base64'));fs.writeFileSync(path.join(out,engine+'-'+e.name+'-200.png'),Buffer.from(e.zoom.split(',')[1],'base64'))}
   report.engines.push({engine,offsets:result.offsets,cases:result.rows.length,outfits:result.rows.reduce((n,r)=>n+r.outfits,0),exactTiles:result.rows.length,initialHeroAndTileSourceRequests:1,totalSourceRequestsWithCacheEviction:sourceRequests.length,rows:result.rows});console.log('PASS '+engine+': 432 outfit combinations, 36 exact shoe tiles; ankle offsets '+result.offsets.map(o=>o.error.toFixed(2)).join('/')+' px');
  }finally{await browser.close()}
 }
 fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2)+'\n');
}finally{server.close()}})().catch(e=>{console.error(e);server.close();process.exitCode=1});
