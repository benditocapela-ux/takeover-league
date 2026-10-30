/* Takeover League · draft eight-layer art preview.
 * LOCAL-ONLY, ?art=layers. No API calls, no persistence, no production flag.
 * These first-pass masks reconstruct ONE approved original look; they contain
 * no hidden body anatomy, so the real SVG must handle ALL other outfits. */
(function(){
'use strict';
const NAMES=Object.freeze(['coatBack','body','bottom','feet','eyes','hair','coatFront','hands']);
const MAX_FILE=2*1024*1024;
const ORIGINAL_SHA256=Object.freeze({
 coatBack:'bf5cee68e8cc19d3e7444c01882a3ea3019a6320b87270ec8d51e1197bf26e4a',
 body:'5991018fc9469342b91dbdd93dcc4ff618a70c66754cb4b3cc23779fb724bed3',
 bottom:'ca02a420022e0ecbfe79d64e1c326e119744d62f51a594c5fbd095c65c5af6f1',
 feet:'05e8cf320330df8dfb541d0f900f05121142dee8a91259093880d0e9ef404dd7',
 eyes:'a9a0a97a7a89abbdee6add40c1c3bff104e97f630c30591cf3a2c7905d72f8e8',
 hair:'7c7b3cf7cc007b5394ff00000326f53eb26554f6711e2d2f128e10f49ee1f0d4',
 coatFront:'aef43b7b888d4c591318682077d2ea5ed0f1562db5c3e1d195b131817a67cfac',
 hands:'feddacf8e8727c04e3ade21502d988e541711151a763fcffcea5c36207f45d68'
});

const REFERENCE=Object.freeze({
 tone:6,hair:'afro',hc:'schwarz',eye:'braun',head:'none',top:'none',
 coat:'samurai',bottom:'boxer',bottomc:'schwarz',feet:'boots',feetc:'schwarz',
 hands:'wraps',aura:'none',eyefx:'none',scene:'holo'
});
function compatible(cfg,pose){
 if(pose!=='cool'||!cfg)return false;
 return cfg.tone===6&&cfg.hair==='afro'&&cfg.hc==='schwarz'&&
  cfg.eye==='braun'&&cfg.head==='none'&&cfg.top==='none'&&
  cfg.coat==='samurai'&&cfg.bottom==='boxer'&&cfg.bottomc==='schwarz'&&
  cfg.feet==='boots'&&cfg.feetc==='schwarz'&&cfg.hands==='wraps'&&
  cfg.aura==='none'&&cfg.eyefx==='none'&&
  (cfg.scene==='holo'||cfg.scene==='none');
}
function create(win){
 let urls=null,generation=0,verified=null;
 const revoke=list=>{if(list)Object.values(list).forEach(url=>win.URL.revokeObjectURL(url))};
 function clear(){generation++;revoke(urls);urls=null;verified=null}
 function status(){return Object.freeze({ready:!!urls,layers:urls?NAMES.length:0,verified})}
 function render(config,pose,visibleLayers=NAMES,showAnatomy=false){
  if(!urls||!compatible(config,pose))return null;
  // Only the fixed, verified slot names can select image sources.
  // Optional cartoon-quality anatomy tracing is NEVER an approved sprite.
  const enabled=new Set(visibleLayers);
  const draft=showAnatomy&&win.TLBoxerAnatomyBlockout?.approved===false
   ?win.TLBoxerAnatomyBlockout.markup():'';
  return '<div class="mb-artpack mb-draft-artpack" role="img" aria-label="Originaler Anime-Cool-Referenzlook, Ebene für Ebene überprüfbar, nur Entwurf">'+
   draft+NAMES.filter(name=>enabled.has(name)).map((name,i)=>'<img class="mb-artpack-img" loading="eager" decoding="async" style="z-index:'+(i+1)+'" src="'+urls[name]+'" alt="" draggable="false">').join('')+'</div>';
 }
 async function load(files){
  const id=++generation;
  if(!files||files.length!==NAMES.length)throw Error('Bitte genau acht Ebenen wählen.');
  const map=new Map();
  for(const file of files){
   if(!file||typeof file.name!=='string'||!/\.png$/i.test(file.name)||
      (file.type&&file.type!=='image/png')||file.size>MAX_FILE||file.size<40)
    throw Error('Ungültige PNG-Ebene (maximal 2 MiB).');
   const name=file.name.replace(/\.png$/i,'');
   if(!NAMES.includes(name)||map.has(name))throw Error('Falscher oder doppelter Ebenenname: '+name);
   map.set(name,file);
  }
  if(NAMES.some(name=>!map.has(name)))throw Error('Ein oder mehrere Ebenennamen fehlen.');
  const incoming={};
  try{
   for(const name of NAMES)incoming[name]=win.URL.createObjectURL(map.get(name));
   await Promise.all(NAMES.map(name=>new Promise((resolve,reject)=>{
    const img=new win.Image();
    img.onload=()=>img.naturalWidth===768&&img.naturalHeight===1216?resolve():
     reject(Error(name+'.png muss 768 × 1216 Pixel gross sein.'));
    img.onerror=()=>reject(Error(name+'.png konnte nicht gelesen werden.'));
    img.src=incoming[name];
   })));
   if(id!==generation)throw Error('Überholter Ladevorgang.');
   // Exact source identification, performed locally with Web Crypto. A different
   // PNG pack can be inspected, but it is never labelled as the reference.
   let same=null;
   if(win.crypto?.subtle&&NAMES.every(name=>typeof map.get(name).arrayBuffer==='function')){
    const checks=[];
    for(const name of NAMES){
     const bytes=await map.get(name).arrayBuffer();
     const digest=await win.crypto.subtle.digest('SHA-256',bytes);
     const hex=Array.from(new Uint8Array(digest),b=>b.toString(16).padStart(2,'0')).join('');
     checks.push(hex===ORIGINAL_SHA256[name]);
    }
    same=checks.every(Boolean);
   }
   if(id!==generation)throw Error('Überholter Ladevorgang.');
   const old=urls;urls=incoming;verified=same;revoke(old);
   return status();
  }catch(e){revoke(incoming);throw e}
 }
 return Object.freeze({load,clear,status,render,compatible,reference:REFERENCE});
}
window.TLBoxerDraftPreview=Object.freeze({create,compatible,NAMES,REFERENCE});
})();
