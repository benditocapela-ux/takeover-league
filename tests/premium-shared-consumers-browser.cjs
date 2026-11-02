'use strict';
// Real published compositor: different profile poses may request the same displayed card pose.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),os=require('node:os'),http=require('node:http');
const root=path.join(__dirname,'..'),out=fs.mkdtempSync(path.join(os.tmpdir(),'premium-consumers-'));
require('../tools/assemble-pages-site.cjs').assemble(root,out);
const meta=fs.readFileSync(path.join(out,'index.html'),'utf8').match(/<meta name="tl-premium-character"[^>]+>/)[0];
const mime={'.js':'text/javascript','.json':'application/json','.png':'image/png','.svg':'image/svg+xml','.css':'text/css'};
const server=http.createServer((req,res)=>{
 const pathname=new URL(req.url,'http://local').pathname;
 if(pathname==='/consumer-fixture.html'){res.setHeader('Content-Type','text/html');return res.end('<!doctype html><html><head>'+meta+'<script src="takeover-anime.js"></script><script src="takeover-holo.js"></script></head><body></body></html>')}
 const file=path.resolve(out,'.'+pathname);if(!file.startsWith(out+path.sep)){res.writeHead(403);return res.end()}
 fs.readFile(file,(err,data)=>{if(err){res.writeHead(404);return res.end()}res.setHeader('Content-Type',mime[path.extname(file)]||'application/octet-stream');res.end(data)});
});
(async()=>{
 await new Promise(r=>server.listen(0,'127.0.0.1',r));const base='http://127.0.0.1:'+server.address().port;
 try{for(const engine of (process.env.BROWSER||'chromium,webkit').split(',')){
  const browser=await require('playwright')[engine].launch();
  try{
   const page=await browser.newPage(),errors=[],external=[];page.on('pageerror',e=>errors.push(e.message));
   await page.route('**/*',route=>{const u=route.request().url();if(u.startsWith(base)||/^(data:|blob:)/.test(u))return route.continue();external.push(u);return route.abort()});
   await page.goto(base+'/consumer-fixture.html');
   await page.evaluate(()=>{
    const look={tone:6,hair:'afro',hc:'schwarz',eye:'braun',top:'none',coat:'samurai',bottom:'boxer',bottomc:'schwarz',hands:'gloves',glove:'schwarzgold',feet:'boots',feetc:'schwarz',pose_card:'guard'};
    document.body.innerHTML=['cool','guard'].map((profile,i)=>'<div id="figure-'+i+'">'+TLHolo.svg({...look,pose_profile:profile},{pose:'guard',scene:'none'})+'</div>').join('');
   });
   await page.waitForSelector('#figure-0 [data-tl-anime-done="1"]',{timeout:60000});
   await page.waitForSelector('#figure-1 [data-tl-anime-done="1"]',{timeout:5000});
   const figures=await page.locator('svg.tlh-anime image').evaluateAll(nodes=>nodes.map(n=>n.getAttribute('href')));
   assert.equal(figures.length,2);assert.equal(figures[0],figures[1],'equal displayed outfits share exactly the same finished pixels');
   assert.deepEqual(errors,[]);assert.deepEqual(external,[]);
   console.log('PASS '+engine+': both profile/card consumers upgrade to identical Anime artwork from one shared render');
  }finally{await browser.close()}
 }}finally{await new Promise(r=>server.close(r));fs.rmSync(out,{recursive:true,force:true})}
})().catch(e=>{console.error(e);process.exitCode=1});
