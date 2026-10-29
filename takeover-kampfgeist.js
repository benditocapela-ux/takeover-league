/* Takeover League · Kampfgeist (Etappe 4): Zeichnen von Avataren, Auren, Bannern, Rahmen, Titeln und Handschuhen.
 * Alle Figuren und Muster sind eigene Designs. Die Daten (welches Item, welche Farben) kommen aus get_my_kampfgeist / get_kg_look;
 * diese Datei zeichnet nur. Texte werden immer escaped.
 */
(function(){
'use strict';
const esc=s=>String(s==null?'':s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const RANKS=[
 {r:'F',n:'Rookie',c:'#8a94a8'},{r:'E',n:'Prospect',c:'#5fb27f'},{r:'D',n:'Contender',c:'#4fa3ff'},{r:'C',n:'Challenger',c:'#b874ff'},
 {r:'B',n:'Elite Fighter',c:'#ff8a3c'},{r:'A',n:'Champion',c:'#ff5a5f'},{r:'S',n:'Legend',c:'#f2c14e'}
];
const MAX_LEVEL=99;
// Gleiche Formel wie boxer-profile.js und league_private.kg_level: EXP bis Level L = 12.5·n² + 87.5·n (n = L−1).
const expForLevel=L=>{const n=Math.max(0,Math.min(MAX_LEVEL,L)-1);return 12.5*n*n+87.5*n};
const levelOf=xp=>Math.min(MAX_LEVEL,Math.max(0,Math.floor((Math.sqrt(49+0.32*Math.max(0,Number(xp)||0))-7)/2))+1);
const rankOfLevel=L=>RANKS[Math.min(6,Math.max(0,Math.floor((L-1)/10)))];
const rankFirstLevel=i=>i*10+1, rankLastLevel=i=>i===6?MAX_LEVEL:i*10+10;
const RAR={common:['Gewöhnlich','#a3abbd'],rare:['Selten','#4fa3ff'],epic:['Episch','#b874ff'],leg:['Legendär','#ffb020'],myth:['Mythisch','#ff3d6e']};
const CATS=[['avatar','Avatare','Avatar'],['aura','Auren','Aura'],['banner','Banner','Banner'],['rahmen','Rahmen','Rahmen'],['titel','Titel','Titel'],['handschuhe','Handschuhe','Handschuhe'],['emote','Emotes','Sieger-Emote'],['einlauf','Einläufe','Einlauf']];
const COIN='<svg class="kg-coin" viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="11" fill="#ffcc33"/><circle cx="12" cy="12" r="8.2" fill="none" stroke="#b37a00" stroke-width="1.4"/><path d="M12 5.5c1.8 2.4 3.6 4 3.6 6.8a3.6 3.6 0 01-7.2 0c0-1.4.6-2.4 1.5-3.3.1 1.2.7 2 1.4 2.3-.3-2 .1-3.9.7-5.8z" fill="#ff5a1f"/></svg>';
const LOCK='<svg class="kg-lock" viewBox="0 0 24 24" aria-hidden="true"><rect x="5" y="11" width="14" height="10" rx="2" fill="currentColor"/><path d="M8 11V8a4 4 0 018 0v3" stroke="currentColor" stroke-width="2.4" fill="none"/></svg>';
const hex=c=>/^#[0-9a-fA-F]{6}$/.test(String(c||''))?c:'#888888';
function shade(h,amt){const n=parseInt(hex(h).slice(1),16),c=v=>Math.max(0,Math.min(255,v+amt));return '#'+[c(n>>16),c((n>>8)&255),c(n&255)].map(v=>v.toString(16).padStart(2,'0')).join('')}
function starPts(cx,cy,n,r1,r2,jitter){const p=[];for(let i=0;i<n*2;i++){const a=Math.PI*i/n-Math.PI/2,r=(i%2?r2:r1)*(jitter?(1+((i*37)%7-3)*.05):1);p.push((cx+Math.cos(a)*r*1.25).toFixed(1)+','+(cy+Math.sin(a)*r).toFixed(1))}return p.join(' ')}
const HAIR={
 spiky:c=>`<path d="M62 84 L54 50 L74 60 L74 30 L92 50 L100 18 L110 48 L128 28 L128 58 L148 46 L138 84 C130 66 114 58 100 58 C86 58 70 66 62 84Z" fill="${c}"/>`,
 pony:c=>`<path d="M134 66 C166 76 172 112 150 140 C152 114 146 94 130 84Z" fill="${c}"/><path d="M64 86 C60 50 84 40 100 40 C122 40 142 52 136 88 C128 66 112 58 100 58 C84 58 72 68 64 86Z" fill="${c}"/><path d="M80 52 L74 74 L90 58Z" fill="${c}"/>`,
 bob:c=>`<path d="M60 108 C52 56 80 40 100 40 C124 40 150 56 140 108 C136 84 126 70 116 64 L110 76 L104 62 L94 76 L88 62 C74 70 64 84 60 108Z" fill="${c}"/>`,
 buzz:c=>`<path d="M66 80 C66 52 86 44 100 44 C116 44 134 52 134 80 C124 64 76 64 66 80Z" fill="${c}"/>`,
 long:c=>`<path d="M62 90 C56 130 62 150 72 162 L80 104Z M138 90 C144 130 138 150 128 162 L120 104Z" fill="${c}"/><path d="M62 92 C56 52 82 38 100 38 C120 38 146 52 138 92 C132 72 118 60 104 58 L96 70 L92 58 C78 62 66 74 62 92Z" fill="${c}"/>`,
 mohawk:c=>`<path d="M68 78 C70 58 84 50 100 50 C116 50 130 58 132 78 C120 66 80 66 68 78Z" fill="${c}" opacity=".45"/><path d="M90 60 L86 26 L96 40 L100 12 L106 40 L116 24 L112 60 C104 54 96 54 90 60Z" fill="${c}"/>`,
 hood:c=>`<path d="M60 94 C56 54 80 40 100 40 C120 40 144 54 140 94 C134 70 120 56 100 56 C80 56 66 70 60 94Z" fill="${shade(c,-12)}"/><path d="M64 70 C80 52 120 52 136 70" stroke="#4fc3ff" stroke-width="1.6" fill="none" opacity=".5"/>`,
 bald:()=>`<path d="M76 58 C86 50 96 50 104 52" stroke="#fff" stroke-width="3" opacity=".25" fill="none" stroke-linecap="round"/>`,
 flame:c=>`<path d="M60 88 L44 44 L70 58 L64 20 L90 46 L100 6 L112 44 L136 16 L132 56 L158 42 L140 88 C130 66 114 58 100 58 C86 58 70 66 60 88Z" fill="${c}"/><path d="M74 70 L70 40 L88 56 L100 26 L110 54 L128 38 L126 70 C116 62 84 62 74 70Z" fill="#ffcc33" opacity=".55"/>`,
 afro:c=>`<path d="M58 100 C38 70 52 28 100 26 C148 28 162 70 142 100 C138 78 124 62 100 62 C76 62 62 78 58 100Z" fill="${c}"/><g fill="${shade(c,18)}" opacity=".5"><circle cx="70" cy="50" r="5"/><circle cx="92" cy="36" r="5"/><circle cx="116" cy="38" r="5"/><circle cx="134" cy="56" r="5"/><circle cx="60" cy="74" r="4"/><circle cx="140" cy="78" r="4"/></g>`,
 buns:c=>`<circle cx="70" cy="46" r="15" fill="${c}"/><circle cx="130" cy="46" r="15" fill="${c}"/><path d="M64 84 C62 54 82 44 100 44 C118 44 138 54 136 84 C126 66 112 60 100 60 C88 60 74 66 64 84Z" fill="${c}"/>`,
 braids:c=>`<path d="M64 86 C60 52 82 42 100 42 C118 42 140 52 136 86 C128 66 112 60 100 60 C88 60 72 66 64 86Z" fill="${c}"/><g fill="${c}"><ellipse cx="64" cy="108" rx="7" ry="9"/><ellipse cx="62" cy="124" rx="6.5" ry="8.5"/><ellipse cx="61" cy="139" rx="6" ry="8"/><ellipse cx="136" cy="108" rx="7" ry="9"/><ellipse cx="138" cy="124" rx="6.5" ry="8.5"/><ellipse cx="139" cy="139" rx="6" ry="8"/></g><path d="M100 44 L100 60" stroke="${shade(c,30)}" stroke-width="2" opacity=".5"/>`,
 undercut:c=>`<path d="M66 84 C64 70 66 64 70 60" stroke="${c}" stroke-width="6" opacity=".35" fill="none"/><path d="M134 84 C136 70 134 64 130 60" stroke="${c}" stroke-width="6" opacity=".35" fill="none"/><path d="M68 70 C66 46 90 34 112 38 C132 42 144 56 136 74 C124 62 106 58 88 64 C80 66 72 68 68 70Z" fill="${c}"/>`,
 curly:c=>`<g fill="${c}"><circle cx="72" cy="64" r="11"/><circle cx="88" cy="50" r="12"/><circle cx="106" cy="46" r="12"/><circle cx="124" cy="54" r="11"/><circle cx="134" cy="70" r="9"/><circle cx="66" cy="80" r="8"/></g><path d="M66 82 C70 66 84 58 100 58 C116 58 130 66 134 82 C124 70 76 70 66 82Z" fill="${c}"/>`
};
let gSeq=0;
// Etappe 20b: Handschuh mit Volumen (Verlauf), Naht, Knöchelpolster, Schnürung an der Manschette und Glanzlichtern.
function gloveG(g,x,y,rot,mirror){
 const base=hex(g.base),acc=hex(g.acc),cuff=hex(g.cuff),dk=shade(base,-45),id='kgg'+(++gSeq);let pat='';
 if(g.pat==='flame')pat=`<path d="M-16 6 C-14 -6 -6 -8 -4 -20 C0 -12 6 -12 4 -24 C14 -14 18 -2 14 6Z" fill="${acc}" opacity=".95"/>`;
 if(g.pat==='bolt')pat=`<path d="M4 -26 L-8 -4 L1 -4 L-6 12 L12 -10 L3 -10 L10 -26Z" fill="${acc}"/>`;
 if(g.pat==='star')pat=`<polygon points="${starPts(0,-8,5,11,4.5)}" fill="${acc}"/>`;
 if(g.pat==='crack')pat=`<path d="M-14 -24 L-6 -12 L-12 -4 L-2 4 L-6 14 M6 -28 L2 -16 L10 -8 L4 2 M14 -14 L8 -10" stroke="${acc}" stroke-width="2.2" fill="none" stroke-linecap="round" stroke-linejoin="round"/>`;
 if(g.pat==='petal')pat=`<g fill="${acc}"><circle cx="0" cy="-14" r="4"/><circle cx="-7" cy="-8" r="4"/><circle cx="7" cy="-8" r="4"/><circle cx="-4" cy="0" r="4"/><circle cx="4" cy="0" r="4"/></g><circle cx="0" cy="-7" r="2.6" fill="#fff"/>`;
 if(g.pat==='tiger')pat=`<path d="M-20 -18 L-6 -14 L-18 -10Z M-22 -2 L-4 0 L-20 4Z M18 -22 L6 -16 L16 -12Z M20 -4 L6 0 L18 4Z" fill="${acc}"/>`;
 return `<g transform="translate(${x} ${y}) rotate(${rot}) scale(${mirror?-1:1} 1)"><defs><radialGradient id="${id}" cx=".36" cy=".3" r=".85"><stop offset="0" stop-color="${shade(base,70)}"/><stop offset=".5" stop-color="${base}"/><stop offset="1" stop-color="${shade(base,-55)}"/></radialGradient><linearGradient id="${id}c" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="${shade(cuff,40)}"/><stop offset=".5" stop-color="${cuff}"/><stop offset="1" stop-color="${shade(cuff,-40)}"/></linearGradient></defs>`
  +`<path d="M-24 -6 C-26 -30 -6 -38 10 -34 C28 -30 28 -6 24 10 C20 22 -18 24 -22 10Z" fill="url(#${id})" stroke="${dk}" stroke-width="2"/>`
  +`<path d="M-21 -4 C-22 -24 -6 -31 9 -28 C23 -25 23 -6 20 7" fill="none" stroke="${shade(base,-30)}" stroke-width="1.2" stroke-dasharray="2.4 2" opacity=".75"/>`
  +`<path d="M-20 -12 C-8 -6 10 -7 22 -14" fill="none" stroke="${shade(base,-40)}" stroke-width="1.6" opacity=".6"/>`
  +`<path d="M-24 -2 C-34 0 -32 14 -20 12" fill="url(#${id})" stroke="${dk}" stroke-width="2"/>${pat}`
  +`<path d="M-14 -26 C-6 -32 6 -32 12 -28" stroke="#fff" stroke-width="3.4" opacity=".45" fill="none" stroke-linecap="round"/><ellipse cx="17" cy="-16" rx="2.6" ry="4.2" transform="rotate(25 17 -16)" fill="#fff" opacity=".4"/>`
  +`<path d="M-21 10 C-14 22 16 22 23 10 L22 26 C12 36 -12 36 -20 26Z" fill="url(#${id}c)" stroke="${dk}" stroke-width="2"/>`
  +`<path d="M-12 20 L-4 30 M-4 20 L-12 30 M4 20 L12 30 M12 20 L4 30" stroke="${shade(cuff,-60)}" stroke-width="1.4" stroke-linecap="round" opacity=".7"/><path d="M-20 25 C-10 33 12 33 22 25" fill="none" stroke="${acc}" stroke-width="2.2" opacity=".85"/></g>`;
}
function avatarSVG(a,g){
 a=a||{};const s=hex(a.skin||'#e8b48a'),sh=shade(s,-28),eye=hex(a.eye||'#ff5a1f'),hc=hex(a.hc||'#2a1616'),brow=a.brow?hex(a.brow):(a.shadow?eye:'#1a1420');
 const eyes=(a.shadow||a.glow)
  ?`<path d="M76 89 L97 88 L94 96 L80 95Z M124 89 L103 88 L106 96 L120 95Z" fill="none" stroke="${eye}" stroke-width="5" opacity=".35"/><path d="M76 89 L97 88 L94 96 L80 95Z M124 89 L103 88 L106 96 L120 95Z" fill="${eye}"/>`
  :`<path d="M78 90 L96 89 L94 95.5 L81 95.5Z M122 90 L104 89 L106 95.5 L119 95.5Z" fill="#fff"/><circle cx="90" cy="92.6" r="2.8" fill="${eye}"/><circle cx="110" cy="92.6" r="2.8" fill="${eye}"/><circle cx="91" cy="91.6" r=".9" fill="#fff"/><circle cx="111" cy="91.6" r=".9" fill="#fff"/>`;
 const hb=a.hb?`<path d="M63 74 C80 65 120 65 137 74 L137 83 C120 74 80 74 63 83Z" fill="${hex(a.hb)}"/><path d="M134 76 L160 66 L152 79 L164 88 L134 83Z" fill="${hex(a.hb)}"/>`:'';
 const hair=(HAIR[a.hair]||HAIR.buzz)(hc),marks=a.marks?hex(a.marks):'';
 return `<svg viewBox="0 0 200 200" aria-hidden="true"><path d="M12 204 C20 154 58 138 100 138 C142 138 180 154 188 204Z" fill="${sh}"/><path d="M87 116 h26 v28 h-26z" fill="${sh}"/>${a.hair==='hood'?`<path d="M48 124 C42 56 72 28 100 28 C128 28 158 56 152 124 C150 150 134 162 120 168 L80 168 C66 162 50 150 48 124Z" fill="${hc}"/>`:''}<ellipse cx="65" cy="95" rx="6" ry="10" fill="${s}"/><ellipse cx="135" cy="95" rx="6" ry="10" fill="${s}"/><ellipse cx="100" cy="90" rx="35" ry="41" fill="${s}"/><path d="M66 96 C70 122 84 131 100 131 C88 123 78 112 72 92Z" fill="${sh}" opacity=".55"/>${a.beard?`<path d="M66 100 C68 130 86 138 100 138 C114 138 132 130 134 100 C126 120 112 124 100 124 C88 124 74 120 66 100Z" fill="${hc}"/>`:''}${hair}${hb}<path d="M73 78 L97 83 L96 87.5 L74 83.5Z M127 78 L103 83 L104 87.5 L126 83.5Z" fill="${brow}"/>${eyes}<path d="M100 96 L96 108 L102 108" stroke="${sh}" stroke-width="2.2" fill="none" stroke-linejoin="round"/>${a.stache?`<path d="M82 113 C88 105 112 105 118 113 C110 111 104 114 100 114 C96 114 90 111 82 113Z" fill="${hc}"/>`:''}<path d="M90 118 Q100 121 110 117" stroke="${a.shadow?eye:'#5a2a2a'}" stroke-width="2.6" fill="none" stroke-linecap="round"/>${marks?`<path d="M70 98 L80 104 L77 114 M130 98 L120 104 L123 114 M96 62 L100 72 L104 62" stroke="${marks}" stroke-width="2.2" fill="none" stroke-linecap="round" stroke-linejoin="round"/>`:''}${a.scar?'<path d="M113 99 L125 113 M116 107 L122 104" stroke="#a0524a" stroke-width="2.2" stroke-linecap="round"/>':''}${g?gloveG(g,56,176,-14,false)+gloveG(g,144,176,14,true):''}</svg>`;
}
// Dieselben Handschuhmuster wie am Avatar, als hochwertigere Paar-Vorschau im Shop.
const gloveSVG=g=>`<svg viewBox="0 0 180 130" aria-hidden="true" class="kg-glove">
 <ellipse cx="90" cy="115" rx="70" ry="11" fill="#020812" opacity=".36"/>
 <g transform="translate(48 57) scale(1.02)">${gloveG(g||{},0,0,-16,false)}</g>
 <g transform="translate(131 57) scale(1.02)">${gloveG(g||{},0,0,18,true)}</g>
 <path d="M29 25 L39 20 M149 25 L159 20" fill="none" stroke="#fff" opacity=".36" stroke-width="2" stroke-linecap="round"/>
 </svg>`;
function auraHTML(a){
 if(!a||!a.g)return '';const g=String(a.g).split(',').map(hex).join(','),p=hex(a.p||'#ffffff');
 let h=`<div class="kg-aura kg-spin kg-blur${a.pulse?' kg-pulse':''}" style="background:conic-gradient(${g})"></div><div class="kg-aura kg-spin" style="inset:4%;background:conic-gradient(${g})"></div>`;
 for(let i=0;i<6;i++){const left=12+((i*53)%76),d=(i*.31).toFixed(2);
  h+=a.petals?`<i class="kg-petal" style="left:${left}%;top:${10+(i*17)%30}%;animation-delay:${d}s"></i>`:`<i class="kg-spark" style="left:${left}%;bottom:${18+(i*13)%20}%;background:${p};box-shadow:0 0 8px ${p};animation-delay:${d}s"></i>`}
 return h;
}
const cls=s=>String(s||'').replace(/[^a-z0-9_-]/g,'');
const frameClass=d=>d&&d.fr?' kg-fr-'+cls(d.fr):'';
// Avatar mit Aura, Handschuhen und Rahmen. look = {avatar,aura,rahmen,handschuhe} (Items mit design)
// opt.photo (Etappe 19): Profilbild statt Figur – für Boxer ohne eigene Avatar-Wahl; Aura und Rahmen bleiben.
const photoOk=u=>typeof u==='string'&&/^(https:\/\/|\.\/|\/(?!\/)|data:image\/(png|jpe?g|webp);)/.test(u);
function avatarBox(look,size,opt){
 look=look||{};const photo=opt&&photoOk(opt.photo)?opt.photo:null;const fr=look.rahmen&&look.rahmen.design,rk=fr&&fr.fr==='rank'?RANKS.find(x=>x.r===fr.rk):null;
 return `<div class="kg-ava${frameClass(fr)}" style="--s:${Number(size)||120}px${rk?';--rk:'+rk.c:''}">${auraHTML(look.aura&&look.aura.design)}<div class="kg-disc${photo?' kg-photo':''}">${photo?`<img src="${esc(photo)}" alt="" loading="lazy">`:avatarSVG(look.avatar&&look.avatar.design,look.handschuhe&&look.handschuhe.design)}</div>${rk?`<span class="kg-rkbadge">${rk.r}</span>`:''}</div>`;
}
const bannerHTML=d=>`<div class="kg-bn kg-bn-${cls(d&&d.bn||'dojo')}" aria-hidden="true"></div>`;
const titleTag=it=>it?`<span class="kg-title r-${cls(it.rarity)}">${esc(it.name)}</span>`:'';
const rankBadge=(r,size)=>{const k=RANKS.find(x=>x.r===r)||RANKS[0];return `<span class="kg-rank" style="--rk:${k.c};--sz:${Number(size)||34}px" title="Rang ${k.r} · ${esc(k.n)}">${k.r}</span>`};
// Karte: Banner, Avatar, Titel, Name, Rang/Level
function card(look,opts){
 look=look||{};opts=opts||{};const rk=RANKS.find(x=>x.r===look.rank)||RANKS[0];
 return `<div class="kg-card">${bannerHTML(look.banner&&look.banner.design)}<div class="kg-card-body">${avatarBox(look,opts.size||112,{photo:opts.photo})}<div class="kg-card-text">${titleTag(look.titel)}<b class="kg-name">${esc(opts.name||look.name||'')}</b><span class="kg-sub">${rankBadge(rk.r,26)} Rang ${rk.r} · ${esc(rk.n)} · Level ${Number(look.level)||1}</span></div></div></div>`;
}
// Emote-Sprechblase (vorgegebener Text, Form, Farbe)
let emoteSeq=0;
function emoteHTML(d,size){
 d=d||{};
 const sz=Math.max(24,Math.min(160,Number(size)||90));
 const col=hex(d.col||'#f6f0e4'),txt=String(d.txt||'');
 const kind=d.shape==='burst'?'burst':d.shape==='jag'?'jag':'cloud';
 const id='kge'+(++emoteSeq);
 const bubble=kind==='burst'
  ?`<polygon points="${starPts(50,50,12,45,32,true)}"/>`
  :kind==='jag'?`<polygon points="${starPts(50,50,9,45,34,true)}"/>`
  :'<path d="M50 9 C76 9 92 24 92 45 C92 67 74 81 50 81 C42 81 37 80 32 78 L15 92 L20 72 C11 64 8 55 8 45 C8 24 25 9 50 9Z"/>';
 // Etappe 20b: Schriftgrösse nach dem längsten Wort – Wörter werden nie mitten im Wort getrennt.
 const longest=Math.max(1,...txt.split(/\s+|(?<=-)/).map(w=>w.length));
 const fs=Math.max(7,Math.min(19,Math.round(Math.min(sz/(txt.length>13?9.1:txt.length>8?7.4:5.9),sz*.66/(longest*.66)))));
 return `<span class="kg-emote kg-emote-${kind}" style="--es:${fs}px;--kg-ec:${col};width:${sz}px;height:${sz}px" role="img" aria-label="${esc(txt)}">
  <svg viewBox="0 0 100 100" aria-hidden="true">
   <defs><linearGradient id="${id}" x1="0" y1="0" x2=".9" y2="1"><stop stop-color="#26364e"/><stop offset=".46" stop-color="#0d192d"/><stop offset="1" stop-color="#080e1d"/></linearGradient></defs>
   <g transform="translate(2.4 3.6)" fill="#02060f" opacity=".55">${bubble}</g>
   <g fill="url(#${id})" stroke="${col}" stroke-width="3.7" stroke-linejoin="round">${bubble}</g>
   <g transform="translate(50 50) scale(.9) translate(-50 -50)" fill="none" stroke="${col}" stroke-width="1.1" opacity=".6" stroke-linejoin="round">${bubble}</g>
   <path d="M24 30 Q45 15 72 24" fill="none" stroke="#fff" stroke-width="3" opacity=".27" stroke-linecap="round"/>
   <path d="M73 12 L76 19 L83 22 L76 25 L73 32 L70 25 L63 22 L70 19Z" fill="${col}" opacity=".8"/>
  </svg><b>${esc(txt)}</b></span>`;
}
// Einlauf-Vorschau (Kachel)
function einlaufPreview(d){
 d=d||{};const ic=hex(d.ic||'#f6f0e4'),w=String(d.word||'KAMPF!');
 return `<span class="kg-einlauf-pv${d.dark?' dark':''}" style="--ic:${ic}"><b style="font-size:${w.length>10?12:w.length>7?15:19}px">${esc(w)}</b></span>`;
}
// Einlauf abspielen: Vollbild, ein oder zwei Kämpfer (je mit eigenem Einlauf). Ruft done() am Ende auf.
function playEinlauf(fighters,done){
 const list=(fighters||[]).filter(Boolean).slice(0,2);if(!list.length)return;
 const reduce=window.matchMedia&&matchMedia('(prefers-reduced-motion: reduce)').matches;
 const ov=document.createElement('div');ov.className='kg-intro'+(list.length===2?' vs':'')+(reduce?' still':'');ov.setAttribute('role','dialog');ov.setAttribute('aria-modal','true');
 ov.setAttribute('aria-label','Einlauf: '+list.map(f=>f.name||'').join(' gegen '));
 ov.innerHTML=list.map((f,i)=>{const d=(f.look&&f.look.einlauf&&f.look.einlauf.design)||{};const ic=hex(d.ic||'#f6f0e4');
  const fx=(d.sparks?Array.from({length:10},(_,k)=>`<i class="kg-spark" style="left:${8+k*9}%;bottom:${10+(k*17)%40}%;background:${ic};box-shadow:0 0 8px ${ic};animation-delay:${(k*.13).toFixed(2)}s"></i>`).join(''):'')+
   (d.petals?Array.from({length:10},(_,k)=>`<i class="kg-petal" style="left:${6+k*9}%;top:${(k*13)%30}%;animation-delay:${(k*.17).toFixed(2)}s"></i>`).join(''):'');
  return `<div class="kg-intro-side s${i}${d.flash?' flash':''}${d.dark?' dark':''}" style="--ic:${ic}"><div class="kg-intro-lines"></div>${fx}
   ${avatarBox(f.look||{},list.length===2?120:170)}<b class="kg-intro-word">${esc(d.word||'KAMPF!')}</b><span class="kg-intro-name">${titleTag(f.look&&f.look.titel)}<b>${esc(f.name||'')}</b></span></div>`;
 }).join(list.length===2?'<b class="kg-intro-vs">VS</b>':'')+'<button type="button" class="kg-intro-close" aria-label="Einlauf schliessen">×</button>';
 document.body.appendChild(ov);
 const close=()=>{if(!ov.isConnected)return;ov.remove();document.removeEventListener('keydown',key);if(done)done()};
 const key=e=>{if(e.key==='Escape')close()};
 ov.addEventListener('click',close);document.addEventListener('keydown',key);
 ov.querySelector('.kg-intro-close').focus();
 setTimeout(close,reduce?2500:3400);
}
// Vorschau eines einzelnen Items (Shop-Kachel). base = aktuelles Aussehen für Aura/Rahmen/Handschuhe-Vorschau.
function preview(it,base){
 base=base||{};const d=it.design||{};
 if(it.category==='emote')return emoteHTML(d,84);
 if(it.category==='einlauf')return einlaufPreview(d);
 if(it.category==='avatar')return avatarBox({avatar:it,handschuhe:base.handschuhe},86);
 if(it.category==='aura')return avatarBox({avatar:base.avatar,aura:it},86);
 if(it.category==='rahmen')return avatarBox({avatar:base.avatar,rahmen:it},86);
 if(it.category==='handschuhe')return gloveSVG(d);
 if(it.category==='banner')return `<div class="kg-bnbox">${bannerHTML(d)}</div>`;
 if(it.category==='titel')return `<div class="kg-titlebox">${titleTag(it)}</div>`;
 return '';
}
const fmt=n=>Number(n||0).toLocaleString('de-CH');
window.TLKG={esc,RANKS,MAX_LEVEL,expForLevel,levelOf,rankOfLevel,rankFirstLevel,rankLastLevel,RAR,CATS,COIN,LOCK,avatarSVG,gloveSVG,auraHTML,avatarBox,bannerHTML,titleTag,rankBadge,card,preview,emoteHTML,einlaufPreview,playEinlauf,fmt};
})();
