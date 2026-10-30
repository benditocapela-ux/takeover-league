'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
(async()=>{
 const paths=[],revoke=[];
 const known={
  coatBack:'bf5cee68e8cc19d3e7444c01882a3ea3019a6320b87270ec8d51e1197bf26e4a',
  body:'5991018fc9469342b91dbdd93dcc4ff618a70c66754cb4b3cc23779fb724bed3',
  bottom:'ca02a420022e0ecbfe79d64e1c326e119744d62f51a594c5fbd095c65c5af6f1',
  feet:'05e8cf320330df8dfb541d0f900f05121142dee8a91259093880d0e9ef404dd7',
  eyes:'a9a0a97a7a89abbdee6add40c1c3bff104e97f630c30591cf3a2c7905d72f8e8',
  hair:'7c7b3cf7cc007b5394ff00000326f53eb26554f6711e2d2f128e10f49ee1f0d4',
  coatFront:'aef43b7b888d4c591318682077d2ea5ed0f1562db5c3e1d195b131817a67cfac',
  hands:'feddacf8e8727c04e3ade21502d988e541711151a763fcffcea5c36207f45d68'
 };
 const names=Object.keys(known);
 let broken=null;
 class FakeImage{
  set src(u){this.url=u;queueMicrotask(()=>{this.naturalWidth=768;this.naturalHeight=1216;this.onload?.()})}
 }
 class FakeFile{
  constructor(parts,name,options){this.name=name;this.type=options.type;this.bytes=parts[0];this.size=this.bytes.byteLength}
  arrayBuffer(){return Promise.resolve(this.bytes)}
 }
 let created=0;
 const encode=hex=>Uint8Array.from(hex.match(/../g).map(h=>parseInt(h,16))).buffer;
 const win={
  Image:FakeImage,File:FakeFile,
  crypto:{subtle:{digest:async(_algo,bytes)=>{
   const name=new Uint8Array(bytes)[0];
   const key=names[name];
   return encode(broken===key?'0'.repeat(64):known[key]);
  }}},
  fetch:async(url,opts)=>{
   paths.push({url,opts});
   const base=url.split('/').pop().replace(/\.png$/,'');
   const name=names.find(n=>n.toLowerCase()===base);
   if(!name||broken===name&&opts.cache==='no-store'&&broken==='coatFront')
    return {ok:false,status:404};
   const buf=new Uint8Array(160);buf[0]=names.indexOf(name);
   return {ok:true,arrayBuffer:async()=>buf.buffer};
  },
  URL:{createObjectURL:f=>'blob:reference/'+f.name+'/'+(++created),revokeObjectURL:u=>revoke.push(u)}
 };
 const ctx={window:win};vm.createContext(ctx);
 vm.runInContext(fs.readFileSync('takeover-mein-boxer-draft-layers.js','utf8'),ctx);
 const kit=win.TLBoxerDraftPreview.create(win);
 assert.equal(kit.status().ready,false);
 const loaded=await kit.loadInstalled();
 assert.equal(loaded.ready,true);
 assert.equal(loaded.verified,true,'only exactly matched original PNGs qualify');
 assert.equal(paths.length,8);
 assert.equal(paths.every(p=>p.url.startsWith('./assets/boxer-artpacks/v1/cool/')&&
  p.opts.mode==='same-origin'&&p.opts.cache==='no-store'),true);
 assert.ok(paths.some(p=>p.url.endsWith('/coatfront.png')),
  'GitHub asset names are lowercase; local file labels preserve original layer keys');
 const composed=kit.render(kit.reference,'cool');
 assert.equal((composed.match(/mb-artpack-img/g)||[]).length,8);
 broken='hair';
 await assert.rejects(kit.loadInstalled(),/Prüfsumme stimmt nicht.*hair\.png/,
  'tampered content must never replace the previously verified drawing');
 assert.equal(kit.status().verified,true);
 assert.equal(kit.status().ready,true,'previous verified art is preserved');
 assert.equal(created,8,'bad repo art must never create additional object URLs');
 broken='coatFront';
 await assert.rejects(kit.loadInstalled(),/Originalebene noch nicht im Branch/,
  'missing asset must fail cleanly');
 assert.equal(kit.status().ready,true);
 kit.clear();
 assert.equal(revoke.length,8,'all loaded local URLs are cleaned up');
 const html=fs.readFileSync('mein-boxer.html','utf8');
 assert.ok(html.includes('data-draft-repo="1"'));
 assert.ok(html.includes('await draftPack.loadInstalled()'));
 assert.ok(html.includes('if(fromRepo&&draftReview&&draftPack)'));
 assert.ok(!html.includes('draftPack.loadInstalled();'), 'no automatic import outside user click handler');
 console.log('PASS: one-click local branch import verifies all eight SHA hashes and never exposes corrupt art');
})().catch(e=>{console.error(e);process.exitCode=1});
