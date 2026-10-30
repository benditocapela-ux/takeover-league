/* Takeover League · draft eight-layer art preview.
 * LOCAL-ONLY, ?art=layers. No API calls, no persistence, no production flag.
 * These first-pass masks reconstruct ONE approved original look; they contain
 * no hidden body anatomy, so the real SVG must handle ALL other outfits. */
(function(){
'use strict';
const NAMES=Object.freeze(['coatBack','body','bottom','feet','eyes','hair','coatFront','hands']);
const MAX_FILE=2*1024*1024;
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
 let urls=null,generation=0;
 const revoke=list=>{if(list)Object.values(list).forEach(url=>win.URL.revokeObjectURL(url))};
 function clear(){generation++;revoke(urls);urls=null}
 function status(){return Object.freeze({ready:!!urls,layers:urls?NAMES.length:0})}
 function render(config,pose,visibleLayers=NAMES){
  if(!urls||!compatible(config,pose))return null;
  // Only the fixed, verified slot names can select image sources.
  const enabled=new Set(visibleLayers);
  return '<div class="mb-artpack mb-draft-artpack" role="img" aria-label="Originaler Anime-Cool-Referenzlook, Ebene für Ebene überprüfbar, nur Entwurf">'+
   NAMES.filter(name=>enabled.has(name)).map((name,i)=>'<img class="mb-artpack-img" loading="eager" decoding="async" style="z-index:'+i+'" src="'+urls[name]+'" alt="" draggable="false">').join('')+'</div>';
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
   const old=urls;urls=incoming;revoke(old);
   return status();
  }catch(e){revoke(incoming);throw e}
 }
 return Object.freeze({load,clear,status,render,compatible,reference:REFERENCE});
}
window.TLBoxerDraftPreview=Object.freeze({create,compatible,NAMES,REFERENCE});
})();
