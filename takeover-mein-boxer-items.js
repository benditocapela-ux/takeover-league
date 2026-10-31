/* Takeover League · Mein Boxer · isolated equipment miniatures, art pass 2.
 * Lightweight SVG game-item illustrations; no raster embeds and no remote requests.
 * Slots/colours are finite and drawn from the same keys as the editable boxer.
 * Only the "Mein Boxer" editor loads this optional module.
 */
(function(){
'use strict';
let uid=0;
const ALLOWED={
 head:new Set(['none','cap','band','hijab']),
 top:new Set(['none','tank','shirt','hoodie','jacke']),
 bottom:new Set(['boxer','kurz','jogger','track']),
 hands:new Set(['wraps','gloves']),
 feet:new Set(['boots','sneaker']),
 glove:new Set(['rot','weiss','schwarzgold','eisblau','glut']),
 coat:new Set(['none','basic','samurai','neon','drache'])
};
const PALETTE={
 schwarz:['#292a34','#0b0e19','#f2c14e'],
 weiss:['#eff3f8','#8c9cb4','#dbb75a'],
 grau:['#81899c','#394157','#e5c56c'],
 rot:['#d22d40','#641020','#f8c46a'],
 blau:['#326bd5','#12245f','#f3ce7c'],
 gruen:['#30956d','#0f493e','#ffd473'],
 lila:['#8134da','#321462','#ffca78'],
 gold:['#e5b54a','#80551c','#fff0aa']
};
const GLOVES={
 rot:['#d72d41','#6d111e','#ffe0a3'],
 weiss:['#e9eff7','#879ab5','#f2c14e'],
 schwarzgold:['#302b30','#090d17','#ffd66f'],
 eisblau:['#47c9f4','#14617e','#e5faff'],
 glut:['#eb6429','#78200c','#ffe478']
};
const MANTLES={
 basic:['#222a39','#0b0e16','#d5af67'],
 samurai:['#1d2536','#090d16','#f2c14e'],
 neon:['#161d32','#080d18','#4fd8ff'],
 drache:['#61202a','#220f1a','#f2c14e']
};
const safe=(s,fallback)=>/^#[0-9a-fA-F]{6}$/.test(String(s||''))?s:fallback;
function supports(field,value){
 const slot=field==='coatPick'?'coat':field;
 return !!(ALLOWED[slot]&&ALLOWED[slot].has(String(value)));
}
function mainShape(slot,value,accent,base,edge,id){
 const p=(d,fill,stroke,sw)=>'<path d="'+d+'" fill="'+(fill||'none')+'"'+(stroke?' stroke="'+stroke+'" stroke-width="'+(sw||2)+'" stroke-linejoin="round" stroke-linecap="round"':'')+'/>';
 const crown='<path d="M-12 -4 L-6 1 L0 -8 L6 1 L12 -4 L9 8 L-9 8Z" fill="'+accent+'" opacity=".95"/><path d="M-9 10 H9" stroke="'+accent+'" stroke-width="2"/>';
 const trim=p('M-25 8 Q0 15 25 8','none',accent,2.3);
 if(value==='none')return '<circle cx="65" cy="55" r="25" fill="#12243a" stroke="#4a678b" stroke-width="1.5"/>'+p('M49 55 H81','none','#8ca2bc',3)+p('M65 39 V71','none','#8ca2bc',3);
 if(slot==='head'){
  if(value==='cap')return '<g transform="translate(0 0)">'+p('M28 64 Q28 25 61 22 Q100 21 103 63 L100 76 Q61 83 29 72Z','url(#'+id+'cloth)','#080d1a',3)+p('M27 69 Q67 57 109 69 Q118 74 108 80 Q68 88 23 78 Q15 74 27 69Z','url(#'+id+'metal)','#090f1b',2)+p('M34 47 Q62 25 91 47','none','#fff4c3',2.5)+'<g transform="translate(65 53) scale(.55)">'+crown+'</g><path d="M40 76 Q70 81 98 75" stroke="'+accent+'" stroke-width="2" fill="none"/></g>';
  if(value==='band')return '<g transform="translate(0 4)">'+p('M15 48 Q65 32 115 48 L113 74 Q65 60 17 74Z','url(#'+id+'cloth)','#090d19',3)+p('M19 53 Q65 40 111 53','none',accent,2)+p('M20 69 Q65 55 110 69','none',accent,2)+'<text x="65" y="62" fill="#e8d5ad" font-size="12" font-family="Arial, sans-serif" font-weight="900" text-anchor="middle">TAKEOVER</text></g>';
  return '<g>'+p('M28 95 Q14 67 27 37 Q38 12 64 14 Q95 12 105 41 Q118 68 102 98 L83 103 L77 75 Q66 67 55 76 L50 105Z','url(#'+id+'cloth)','#090e18',3)+p('M40 65 Q35 27 66 25 Q95 25 91 65','none',edge,9)+p('M40 65 Q35 27 66 25 Q95 25 91 65','none',accent,1.6)+p('M26 90 Q65 108 105 90','none',accent,2.4)+'</g>';
 }
 if(slot==='top'){
  const sleeves=value==='tank'?'M40 28 L45 33 L40 47 L33 39Z M90 28 L85 33 L90 47 L97 39Z':'M39 26 L16 37 L11 63 L29 70 L40 51Z M91 26 L114 37 L119 63 L101 70 L90 51Z';
  const body=value==='tank'?'M45 23 L55 28 Q65 34 75 28 L85 23 L90 38 L87 98 L43 98 L40 38Z':'M40 28 Q52 21 55 27 Q65 34 75 27 Q78 21 90 28 L95 50 L87 101 L43 101 L35 50Z';
  let art=p(sleeves,'url(#'+id+'cloth)','#080d16',3)+p(body,'url(#'+id+'cloth)','#080d16',3);
  art+=p('M45 40 L47 91 M85 40 L83 91','none',edge,2.2)+p('M43 94 Q65 98 87 94','none',accent,2.2);
  if(value==='hoodie'||value==='jacke'){
   art+=p('M39 28 Q44 13 59 16 Q65 19 71 16 Q88 13 92 28 L82 41 Q65 31 48 41Z','url(#'+id+'edge)','#090e16',3);
   art+=p('M62 36 L62 101','none',accent,value==='jacke'?3:1.3);
   if(value==='hoodie')art+=p('M56 36 L55 59 M72 36 L74 59','none','#e2d9c3',2);
   if(value==='jacke')art+=p('M48 73 H57 M69 73 H82','none',accent,2);
  }else if(value==='tank')art+=p('M55 27 Q65 38 75 27','none',accent,2);
  art+='<g transform="translate(65 65) scale(.53)">'+crown+'</g>';
  art+=p('M28 52 L32 54 M98 54 L102 52','none',accent,2);
  return art;
 }
 if(slot==='bottom'){
  const isLong=value==='jogger'||value==='track';
  const shape=isLong?'M35 18 L95 18 L99 50 L91 108 L70 108 L65 51 L60 108 L39 108 L31 50Z':'M34 22 L96 22 L103 89 L73 94 L65 63 L57 94 L26 89Z';
  let art=p(shape,'url(#'+id+'cloth)','#070c17',3)+p('M34 25 Q65 31 96 25 L95 36 Q65 32 35 36Z','url(#'+id+'edge)','#090e18',2.2);
  art+=p(isLong?'M36 39 L40 104 M94 39 L90 104':'M31 40 L29 85 M99 40 L101 85','none',accent,3.2);
  art+=p('M44 41 Q54 45 60 50 M84 41 Q76 45 70 50','none','#fff3cb',1.7);
  if(isLong){art+=p('M39 103 H60 M70 103 H91','none',accent,2.5);}
  art+='<g transform="translate(65 29) scale(.28)">'+crown+'</g>';
  return art;
 }
 if(slot==='hands'||slot==='glove'){
  if(value==='wraps'){
   return '<g transform="translate(0 1)">'+p('M26 35 Q35 21 53 32 L66 51 L57 83 Q38 87 28 72Z','url(#'+id+'cloth)','#0b1019',3)+p('M76 50 L89 30 Q108 25 112 42 L106 77 Q93 91 79 81Z','url(#'+id+'cloth)','#0b1019',3)+p('M30 44 L61 60 M28 54 L60 70 M75 65 L108 45 M78 76 L107 56','none','#eee6d8',6)+p('M30 44 L61 60 M75 65 L108 45','none',accent,1.5)+'</g>';
  }
  const left='<g transform="translate(33 30) rotate(-22 23 32)">'+p('M11 29 Q-2 8 21 2 Q42 -3 54 16 Q63 39 43 57 L19 58 Q8 50 11 29Z','url(#'+id+'cloth)','#0b0e19',3)+p('M10 41 L43 44 L42 68 L11 66Z','url(#'+id+'edge)','#0b0e19',2.6)+p('M16 18 Q28 6 41 14','none','#fff8e3',3)+p('M17 47 L39 49','none',accent,2.8)+'<g transform="translate(27 30) scale(.34)">'+crown+'</g></g>';
  const right='<g transform="translate(69 19) rotate(20 23 32)">'+p('M11 29 Q-2 8 21 2 Q42 -3 54 16 Q63 39 43 57 L19 58 Q8 50 11 29Z','url(#'+id+'cloth)','#0b0e19',3)+p('M10 41 L43 44 L42 68 L11 66Z','url(#'+id+'edge)','#0b0e19',2.6)+p('M16 18 Q28 6 41 14','none','#fff8e3',3)+p('M17 47 L39 49','none',accent,2.8)+'</g>';
  return '<g>'+left+right+'</g>';
 }
 if(slot==='feet'){
  const boot=value==='boots';
  const shoe='M10 20 L39 18 L42 62 L58 74 L61 93 Q57 102 45 102 L10 101 L5 91 L8 71Z';
  let a='';
  for(const offset of [6,69]){
   a+='<g transform="translate('+offset+' 0) scale(.83)">'+p(shoe,'url(#'+id+'cloth)','#080d18',3)+p('M10 90 L58 91','none',accent,4)+p('M14 95 L57 96','none','#e5e6ed',2);
   if(boot)a+=p('M16 28 L34 27 L35 75 M19 36 L35 35 M19 46 L35 45 M19 56 L35 55','none',accent,2.5);
   else a+=p('M12 61 Q23 56 41 65 M15 72 Q29 68 43 75','none',accent,2.2);
   a+='</g>';
  }
  return a;
 }
 if(slot==='coat'){
  let a=p('M42 18 Q53 11 65 20 Q77 11 89 18 L102 104 L72 108 L65 50 L58 108 L28 104Z','url(#'+id+'cloth)','#090d17',3.5);
  a+=p('M43 18 L60 30 L56 105 M87 18 L70 30 L74 105','none',accent,3.6);
  a+=p('M42 20 L27 36 L17 71 L34 75 L47 45 M88 20 L103 36 L113 71 L96 75 L83 45','none',edge,13);
  a+=p('M42 20 L27 36 L17 71 M88 20 L103 36 L113 71','none',accent,3);
  a+=p('M45 70 L84 70 M36 96 L56 100 M73 100 L94 96','none',accent,2);
  a+='<g transform="translate(65 45) scale(.5)">'+crown+'</g>';
  if(value==='drache')a+=p('M37 85 Q49 75 44 61 Q59 75 53 90','none',accent,2.4);
  return a;
 }
 return '';
}
function svg(field,value,config){
 const slot=field==='coatPick'?'coat':field;
 if(!supports(field,value))return '';
 const c=config||{},id='mbi'+(++uid);
 let palette=PALETTE.schwarz;
 if(slot==='head')palette=PALETTE[c.headc]||palette;
 if(slot==='top')palette=PALETTE[c.topc]||palette;
 if(slot==='bottom')palette=PALETTE[c.bottomc]||palette;
 if(slot==='feet')palette=PALETTE[c.feetc]||palette;
 if(slot==='glove'||slot==='hands'&&value==='gloves')palette=GLOVES[c.glove]||GLOVES.schwarzgold;
 if(slot==='coat'&&value!=='none')palette=MANTLES[value]||MANTLES.basic;
 const base=safe(palette[0],'#262b35'),edge=safe(palette[1],'#10131d'),accent=safe(palette[2],'#f2c14e');
 const defs='<defs><linearGradient id="'+id+'cloth" x1=".1" y1="0" x2=".9" y2="1"><stop stop-color="'+accent+'" stop-opacity=".68"/><stop offset=".12" stop-color="'+base+'"/><stop offset=".56" stop-color="'+base+'"/><stop offset=".89" stop-color="'+edge+'"/><stop offset="1" stop-color="#080b13"/></linearGradient><linearGradient id="'+id+'edge" x1="0" y1="0" x2=".9" y2=".9"><stop stop-color="#fff4be"/><stop offset=".3" stop-color="'+accent+'"/><stop offset=".8" stop-color="'+edge+'"/><stop offset="1" stop-color="#f2d07e"/></linearGradient></defs>';
 const art=mainShape(slot,value,accent,base,edge,id);
 return '<svg class="mb-item-svg" viewBox="0 0 130 116" xmlns="http://www.w3.org/2000/svg" aria-hidden="true" focusable="false">'+defs+'<ellipse cx="65" cy="105" rx="46" ry="6" fill="#050b13" opacity=".6"/>'+art+'</svg>';
}
// Reuse the runtime's selected PNG URLs and registration; no new image requests
// beyond the shared loader and the browser cache, no independent thumbnails.
function png(item){
 if(!item||item.state!=='ready')return '';
 const [x,y,w,h]=item.frame;
 if(![x,y,w,h].every(Number.isFinite)||w<=0||h<=0)return '';
 if(!item.layers.every(l=>/^\.\/assets\/boxer-artpacks\/v1\/[a-z0-9_/-]+\.(png|webp)$/.test(l.src)))return '';
 return '<span class="mb-item-png" style="--item-ratio:'+(w/h)+';aspect-ratio:'+w+'/'+h+'">'+item.layers.map(l=>'<img src="'+l.src+'" alt="" data-item-art-slot="'+l.slot+'" decoding="sync" draggable="false" style="left:'+(-x/w*100)+'%;top:'+(-y/h*100)+'%;width:'+(768/w*100)+'%;height:'+(1216/h*100)+'%">').join('')+'</span>';
}
window.TLGearArt=Object.freeze({svg,supports,png});
})();
