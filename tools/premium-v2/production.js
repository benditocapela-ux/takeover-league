/* Isolated production laboratory. No application imports or persistence. */
(function(){'use strict';
let base,stream,art,headwear,ready=false;
const S=window.TLPremiumV2Streaming,loader=S.createLoader(),crops=new WeakMap();
const defaults={tone:6,hair:'afro',hc:'schwarz',eye:'braun',head:'none',headc:'schwarz',top:'none',topc:'schwarz',hood:false,bottom:'boxer',bottomc:'schwarz',hands:'gloves',glove:'schwarzgold',feet:'boots',feetc:'schwarz',coat:'samurai',aura:'none',eyefx:'none',scene:'holo',pose_profile:'guard',pose_card:'guard'};
async function init(){[base,stream,art,headwear]=await Promise.all(['pilot-assets.json','streaming-assets.json','production-art/manifest.json','headwear/manifest.json'].map(async u=>{const r=await fetch(u);if(!r.ok)throw Error('Missing manifest');return r.json()}));ready=true;return {base,stream,art,headwear};}
function resolve(input){
 if(!ready)return null;const c=TLHolo.normalize({...defaults,...input}),m=window.TLPremiumMaterials;
 if(!m||!m.hair[c.hc]||!m.eyes[c.eye]||c.tone<0||c.tone>7)return null;
 const newHair=art.pieces['hair-'+c.hair],newBottom=art.pieces['bottom-'+c.bottom],newFeet=art.pieces['feet-'+c.feet];
 if(!['afro','kurz_glatt','glatze'].includes(c.hair)&&!newHair)return null;
 if(c.bottom!=='boxer'&&!newBottom||c.feet!=='boots'&&!newFeet)return null;
 if(!m.clothing&&(c.bottomc!=='schwarz'&&!(c.bottom==='boxer'&&c.bottomc==='rot')||c.feetc!=='schwarz'))return null;
 if(!m.gloves&&!['schwarzgold','weiss'].includes(c.glove))return null;
 const hw=c.head==='none'?null:TLPremiumHeadwear.resolve(c,headwear);if(c.head!=='none'&&!hw)return null;
 const baseline=TLPremiumV2Pilot.resolve({...c,tone:6,hc:'schwarz',eye:'braun',hair:'afro',head:'none',bottom:'boxer',bottomc:c.bottom==='boxer'&&c.bottomc==='rot'&&!m.clothing?'rot':'schwarz',feet:'boots',feetc:'schwarz',glove:m.gloves?'schwarzgold':c.glove},base);
 if(!baseline)return null;const selected=S.resolve(baseline,stream);if(!selected)return null;
 selected.config=c;selected.renderer='anime-draft';selected.hairMask=hw&&hw.hairMask;
 const replace=(ids,parts)=>{const at=selected.pieces.findIndex(p=>ids.includes(p.id));if(at<0)return;selected.pieces=selected.pieces.filter(p=>!ids.includes(p.id));selected.pieces.splice(at,0,...parts);};
 const hair=c.hair==='glatze'?[]:newHair?[newHair]:[S.resolve({ids:[c.hair==='afro'?'hair-afro':'hair-short'],pose:c.pose_profile},stream).pieces[0]];
 replace(['hair-afro'],hair);
 if(hw){const i=selected.pieces.findIndex(p=>p.slot==='hair');selected.pieces.splice(i<0?selected.pieces.findIndex(p=>p.slot==='eyes')+1:i+1,0,...hw.pieces);}
 if(newBottom)replace(['bottom-black','bottom-red'],[newBottom]);
 if(newFeet)replace(['feet'],[newFeet]);
 if(c.pose_profile==='guard'){
  if(c.coat==='samurai'&&art.pieces['coat-guard-v2'])replace(['coat-tail','coat-guard'],[art.pieces['coat-guard-v2']]);
  if((c.glove==='schwarzgold'||m.gloves)&&art.pieces['hands-master-0']&&art.pieces['hands-master-1'])replace(['guard-black-0','guard-black-1','guard-white-0','guard-white-1'],[art.pieces['hands-master-0'],art.pieces['hands-master-1']]);
 }
 selected.ids=selected.pieces.map(p=>p.id);return selected;
}
function crop(image,p){let map=crops.get(image);if(!map){map=new Map();crops.set(image,map)}const key=p.id+':'+p.uv.join(',');if(map.has(key))return map.get(key);const c=document.createElement('canvas');c.width=p.uv[2];c.height=p.uv[3];c.getContext('2d').drawImage(image,...p.uv,0,0,c.width,c.height);map.set(key,c);return c;}
const sleeveOcclusion=[[[180,230],[320,230],[313,280],[300,340],[290,400],[305,455],[290,480],[180,480]],[[465,230],[590,230],[590,480],[475,480],[460,455],[475,400],[465,340],[455,280]]];
function occludeSleeves(surface,p,config){if(p.id!=='body-guard'||config.coat!=='samurai')return surface;const c=document.createElement('canvas');c.width=surface.width;c.height=surface.height;const g=c.getContext('2d');g.drawImage(surface,0,0);g.globalCompositeOperation='destination-out';for(const polygon of sleeveOcclusion){g.beginPath();polygon.forEach(([x,y],i)=>g[i?'lineTo':'moveTo'](x-p.box[0],y-p.box[1]));g.closePath();g.fill()}return c;}
function draw(ctx,selection,images,slot){
 if(!selection||selection.pieces.some(p=>!images[p.src]))throw Error('Incomplete outfit');
 ctx.clearRect(0,0,768,1216);
 for(const p of selection.pieces){if(slot&&p.slot!==slot&&!(slot==='coat'&&p.slot.startsWith('coat')))continue;
  const source=crop(images[p.src],p),material=TLPremiumMaterials.applyToPiece(source,p.id,selection.config,p.box),isolated=p.slot==='hair'?TLPremiumMaterials.hairOnly(material,p.id,p.box):material,surface=occludeSleeves(isolated,p,selection.config);ctx.save();if(p.slot==='hair'&&selection.hairMask&&selection.hairMask.type==='keepRect'){ctx.beginPath();ctx.rect(...selection.hairMask.rect);ctx.clip()}ctx.drawImage(surface,p.box[0],p.box[1],p.box[2],p.box[3]);ctx.restore();
 }
}
async function prepare(input){const selection=resolve(input);if(!selection)return {renderer:'svg',reason:'unsupported'};try{return {renderer:'anime-draft',selection,images:await loader.prepare(selection)}}catch(e){return {renderer:'svg',reason:'load-failed',error:e.message}}}
function itemFrame(selection,slot){const ps=selection.pieces.filter(p=>p.slot===slot||(slot==='coat'&&p.slot.startsWith('coat')));if(!ps.length)return null;const x=Math.floor(Math.min(...ps.map(p=>p.box[0]))),y=Math.floor(Math.min(...ps.map(p=>p.box[1])));return[x,y,Math.ceil(Math.max(...ps.map(p=>p.box[0]+p.box[2])))-x,Math.ceil(Math.max(...ps.map(p=>p.box[1]+p.box[3])))-y]}
window.TLPremiumProduction=Object.freeze({init,resolve,prepare,draw,itemFrame,defaults,loader,sleeveOcclusion,approved:false,enabled:false});
})();
