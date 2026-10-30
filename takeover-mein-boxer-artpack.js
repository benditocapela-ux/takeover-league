/* Takeover League · optional layered premium 2D art runtime.
 * All images share one 768x1216 transparent canvas and pose.
 * The pack is all-or-nothing per selected configuration: no misleading
 * clothing combinations, silent colour substitutions, or remote image URLs.
 * SVG remains the trusted default until the art director approves a pack.
 */
(function(){
'use strict';
const ROOT='./assets/boxer-artpacks/v1/';
const FILE=/^[a-z0-9_-]+(?:\/[a-z0-9_-]+)*\.(?:png|webp)$/;
const OWN=(o,k)=>o&&Object.prototype.hasOwnProperty.call(o,k);
const LABEL='Dein Boxer – Premium-Grafik';
function create(manifest){
 const m=manifest&&typeof manifest==='object'?manifest:{};
 const valid= m.version===1 && m.approved===true &&
  m.canvas&&m.canvas.width===768&&m.canvas.height===1216 &&
  m.poses&&typeof m.poses==='object'&&!Array.isArray(m.poses);
 const failed=new Set();
 const stats={attempted:0,matched:0};
 const loaded=new Set(),pending=new Map(),notifying=new Set();
 function choose(config,pose){
  stats.attempted++;
  if(!valid||typeof pose!=='string'||!/^[a-z0-9_-]{1,32}$/.test(pose)||!OWN(m.poses,pose))return null;
  const cfg=config||{};
  // Unsupported effects may not be silently omitted by the new art.
  if(cfg.aura!=='none'||cfg.eyefx!=='none'||(cfg.scene!=='holo'&&cfg.scene!=='none'))return null;
  const pack=m.poses[pose];
  if(!pack||typeof pack!=='object')return null;
  const hood=cfg.top==='hoodie'&&cfg.hood===true;
  const hiddenHair=cfg.head==='hijab'||hood;
  const request=[
   ['coatBack',cfg.coat, cfg.coat==='none'],
   ['body',String(cfg.tone),false],
   ['bottom',cfg.bottom+'/'+cfg.bottomc,false],
   ['feet',cfg.feet+'/'+cfg.feetc,false],
   ['top',cfg.top+'/'+cfg.topc+(cfg.top==='hoodie'?'/'+(hood?'up':'down'):''),cfg.top==='none'],
   ['eyes',cfg.eye,false],
   ['hair',cfg.hair+'/'+cfg.hc,hiddenHair],
   ['head',cfg.head+'/'+cfg.headc,cfg.head==='none'],
   ['coatFront',cfg.coat,cfg.coat==='none'],
   ['hands',cfg.hands==='gloves'?'gloves/'+cfg.glove:'wraps',false]
  ];
  const selected=[];
  for(const [slot,key,skip] of request){
   if(skip)continue;
   const group=OWN(pack,slot)?pack[slot]:null;
   if(!group||!OWN(group,key))return null;
   const name=group[key];
   if(typeof name!=='string'||!FILE.test(name))return null;
   const src=ROOT+name;
   if(failed.has(src))return null;
   selected.push({slot,src});
  }
  if(!selected.length)return null;
  stats.matched++;
  return selected;
 }
 // Atomic swap: show the original SVG until every image in this outfit
 // has finished loading. One failed layer invalidates the whole artwork.
 function prepare(config,pose,onReady){
  const layers=choose(config,pose);
  if(!layers)return false;
  const urls=[...new Set(layers.map(layer=>layer.src))];
  if(urls.every(url=>loaded.has(url)))return true;
  if(typeof window.Image!=='function')return false;
  const tasks=urls.map(url=>{
   if(loaded.has(url))return Promise.resolve(true);
   if(!pending.has(url)){
    const pic=new window.Image();
    const task=new Promise(resolve=>{
     pic.onload=()=>{loaded.add(url);resolve(true)};
     pic.onerror=()=>{failed.add(url);resolve(false)};
     pic.src=url;
    }).finally(()=>pending.delete(url));
    pending.set(url,task);
   }
   return pending.get(url);
  });
  const key=urls.join('|');
  if(typeof onReady==='function'&&!notifying.has(key)){
   notifying.add(key);
   Promise.all(tasks).then(()=>{notifying.delete(key);onReady()});
  }
  return false;
 }
 function render(config,pose){
  const layers=choose(config,pose);
  if(!layers)return null;
  const html='<span class="mb-artpack" role="img" aria-label="'+LABEL+'" data-artpack-version="1" data-artpack-pose="'+pose+'">'+
   layers.map(x=>'<img class="mb-artpack-img" data-art-slot="'+x.slot+'" src="'+x.src+'" alt="" draggable="false" decoding="async" loading="eager">').join('')+
   '</span>';
  return html;
 }
 function markFailed(url){
  if(typeof url!=='string'||!url.startsWith(ROOT))return false;
  const path=url.slice(ROOT.length);
  if(!FILE.test(path))return false;
  failed.add(url);
  return true;
 }
 return Object.freeze({render,choose,prepare,markFailed,stats});
}
window.TLBoxerArtPacks=Object.freeze({
 create,active:create(window.TLBoxerArtPackManifest)
});
})();
