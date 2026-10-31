/* Isolated authoring laboratory. Never imported by the live editor. */
(function(){'use strict';
const BASE='../../assets/boxer-artpacks/v1/modular-cool/';
function resolve(config,assets){
 const c=window.TLHolo.normalize(config),pose=c.pose_profile;
 if(!['cool','guard'].includes(pose)||c.tone!==6||c.hc!=='schwarz'||c.eye!=='braun'||c.head!=='none'||c.top!=='none'||c.hands!=='gloves'||!['schwarzgold','weiss'].includes(c.glove)||c.bottom!=='boxer'||!['schwarz','rot'].includes(c.bottomc)||c.feet!=='boots'||c.feetc!=='schwarz'||!['none','samurai'].includes(c.coat)||!['afro','kurz_glatt'].includes(c.hair)||c.aura!=='none'||c.eyefx!=='none'||c.scene!=='holo')return null;
 const white=c.glove==='weiss',guard=pose==='guard',coat=c.coat==='samurai';
 const ids=[...(coat?['coat-back']:[]),'head','lower','body-'+pose,'bottom-'+(c.bottomc==='rot'?'red':'black'),'feet','eyes','hair-'+(c.hair==='afro'?'afro':'short'),...(coat?['coat-tail','coat-'+pose]:[]),...(guard?['guard-'+(white?'white':'black')+'-0','guard-'+(white?'white':'black')+'-1']:['hands-'+(white?'white':'blackgold')])];
 const v1=[...(coat?[{slot:'coatBack',src:BASE+'coatback.png'}]:[]),{slot:'body',src:guard?'assets/v1-body.png':BASE+'body.png'},{slot:'bottom',src:BASE+'bottom-'+(c.bottomc==='rot'?'red':'black')+'.png'},{slot:'feet',src:BASE+'feet.png'},{slot:'eyes',src:BASE+'eyes.png'},{slot:'hair',src:BASE+'hair-'+(c.hair==='afro'?'afro':'short')+'.png'},...(coat?[{slot:'coatFront',src:guard?'assets/v1-coat.png':BASE+'coatfront.png'}]:[]),{slot:'hands',src:guard?'assets/v1-'+(white?'white':'black')+'.png':BASE+'hands-'+(white?'white':'blackgold')+'.png'}];
 return {pose,ids,pieces:ids.map(id=>({id,...assets.pieces[id]})),v1};
}
function draw(ctx,selection,images,mode,slot){
 ctx.clearRect(0,0,768,1216);
 if(mode==='v1'){for(const l of selection.v1)if(!slot||l.slot===slot||(slot==='coat'&&l.slot.startsWith('coat')))ctx.drawImage(images[l.src],0,0);return}
 for(const p of selection.pieces){if(slot&&p.slot!==slot&&!(slot==='coat'&&p.slot.startsWith('coat')))continue;ctx.drawImage(images['assets/'+p.atlas+'.png'],...p.uv,...p.box)}
}
const cache=new Map();
async function prepare(selection,mode){const urls=mode==='v1'?selection.v1.map(l=>l.src):[...new Set(selection.pieces.map(p=>'assets/'+p.atlas+'.png'))];const images={};for(const src of urls){if(!cache.has(src))cache.set(src,new Promise((resolve,reject)=>{const im=new Image();im.onload=()=>resolve(im);im.onerror=()=>reject(Error('Missing pilot asset: '+src));im.src=src}));images[src]=await cache.get(src)}return images}
window.TLPremiumV2Pilot=Object.freeze({resolve,draw,prepare,approved:false,enabled:false});
})();
