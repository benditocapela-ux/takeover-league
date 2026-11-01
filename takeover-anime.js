/* Takeover League · Anime-Darstellung überall (Holo im Profil, Podium, FUT-Cards, Mein Takeover, Kacheln).
 * Jede Holo-Grafik entsteht über TLHolo.svg. Dieses Skript merkt sich dabei Ausrüstung und Pose am SVG
 * (data-tl-anime) und ersetzt danach den Inhalt durch die freigegebene Anime-Grafik desselben Renderers wie
 * im Boxer-Editor (takeover-premium-character.js). Das SVG behält Grösse, Rahmen und CSS; nur die Zeichnung wechselt.
 * Unterstützt der Renderer eine Kombination nicht oder ist die Freigabe aus, bleibt das SVG (bisheriger Fallback).
 * takeover-holo.js bleibt unverändert (Prüfsummen der Premium-Verträge). Muss vor takeover-holo.js geladen werden.
 */
(function(){
 'use strict';
 if(window.__tlAnime)return;window.__tlAnime=true;
 const page=(location.pathname.split('/').pop()||'index.html').toLowerCase();
 if(page==='mein-boxer.html')return; // der Editor nutzt den Renderer direkt
 const meta=()=>document.querySelector('meta[name="tl-premium-character"][content="enabled"]');

 function wrap(lib){
  if(!lib||typeof lib.svg!=='function'||lib.__tlAnime)return lib;
  const orig=lib.svg;
  const poses=new Set(lib.POSES||[]);
  const svg=function(cfg,opts){
   const out=orig.apply(this,arguments);
   try{
    if(opts&&(opts.layered||opts.premium||opts.anime===false))return out;
    const c=lib.normalize(cfg),want=(opts&&opts.pose)||c.pose_profile,pose=poses.has(want)?want:'guard';
    return out.replace('<svg class="tlh"','<svg class="tlh" data-tl-anime="'+encodeURIComponent(JSON.stringify(c))+'" data-tl-pose="'+pose+'"');
   }catch(_){return out}
  };
  try{return Object.assign({},lib,{svg,__tlAnime:true})}catch(_){return lib}
 }
 let current=wrap(window.TLHolo);
 try{Object.defineProperty(window,'TLHolo',{configurable:true,enumerable:true,get(){return current},set(v){current=wrap(v)}})}catch(_){}

 let api=null,loading=null;
 function load(){
  if(!loading)loading=import(new URL('./takeover-premium-character.js',document.baseURI).href)
   .then(m=>m.init()).then(a=>(api=a)).catch(e=>{console.warn('Anime-Darstellung nicht verfügbar; SVG bleibt aktiv',e);return null});
  return loading;
 }
 const seen=new WeakSet(),waiters=new Map();
 function upgrade(node){
  if(seen.has(node))return;seen.add(node);
  let cfg;try{cfg=JSON.parse(decodeURIComponent(node.getAttribute('data-tl-anime')))}catch(_){return}
  const pose=node.getAttribute('data-tl-pose')||'guard';
  const attempt=()=>{
   if(!api||!node.isConnected||node.getAttribute('data-tl-anime-done'))return;
   // Gleiche Ausrüstung mehrfach auf der Seite (z. B. eigenes Holo und Podium): alle warten auf dieselbe Berechnung.
   const k=JSON.stringify(cfg)+'|'+pose;
   const html=api.hero(cfg,pose,()=>{const list=waiters.get(k)||[];waiters.delete(k);list.forEach(f=>f())});
   if(!html){if(!waiters.has(k))waiters.set(k,[]);waiters.get(k).push(attempt);return}
   const m=/src="(data:image\/png;base64,[^"]+)"/.exec(html);if(!m)return;
   const ns='http://www.w3.org/2000/svg',img=document.createElementNS(ns,'image');
   img.setAttribute('href',m[1]);img.setAttribute('x','0');img.setAttribute('y','0');img.setAttribute('width','240');img.setAttribute('height','380');
   img.setAttribute('preserveAspectRatio','xMidYMid meet');
   node.replaceChildren(img);node.style.overflow='visible';
   node.setAttribute('data-tl-anime-done','1');node.classList.add('tlh-anime');
  };
  load().then(a=>{if(a)attempt()});
 }
 function scan(root){
  if(root.nodeType!==1&&root.nodeType!==9)return;
  if(root.matches&&root.matches('svg.tlh[data-tl-anime]'))upgrade(root);
  if(root.querySelectorAll)root.querySelectorAll('svg.tlh[data-tl-anime]:not([data-tl-anime-done])').forEach(upgrade);
 }
 function start(){
  if(!meta())return; // nur in der freigegebenen Veröffentlichung (der Build setzt die Meta-Angabe)
  scan(document);
  new MutationObserver(list=>{for(const r of list)for(const n of r.addedNodes)scan(n)}).observe(document.documentElement,{childList:true,subtree:true});
 }
 if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',start,{once:true});else start();
})();
