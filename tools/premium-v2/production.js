/* Isolated production laboratory. No application imports or persistence. */
(function(){'use strict';
let base,stream,art,headwear,tops,hairExpansion,wraps,hijab,longHair,ready=false;
const S=window.TLPremiumV2Streaming,loader=S.createLoader(),crops=new WeakMap();
const defaults={tone:6,hair:'afro',hc:'schwarz',eye:'braun',head:'none',headc:'schwarz',top:'none',topc:'schwarz',hood:false,bottom:'boxer',bottomc:'schwarz',hands:'gloves',glove:'schwarzgold',feet:'boots',feetc:'schwarz',coat:'samurai',aura:'none',eyefx:'none',scene:'holo',pose_profile:'guard',pose_card:'guard'};
async function init(){[base,stream,art,headwear,tops,hairExpansion,wraps,hijab,longHair]=await Promise.all(['pilot-assets.json','streaming-assets.json','production-art/manifest.json','headwear/manifest.json','tops/manifest.json','hair-expansion/manifest.json','wraps/manifest.json','headwear-hijab/manifest.json','long-hair/manifest.json'].map(async u=>{const r=await fetch(u);if(!r.ok)throw Error('Missing manifest');return r.json()}));art={...art,pieces:{...art.pieces,...hairExpansion.pieces}};ready=true;return {base,stream,art,headwear,tops};}
function resolve(input){
 if(!ready)return null;const c=TLHolo.normalize({...defaults,...input}),m=window.TLPremiumMaterials;
 if(!m||!m.hair[c.hc]||!m.eyes[c.eye]||c.tone<0||c.tone>7)return null;
 const newHair=art.pieces['hair-'+c.hair],newBottom=art.pieces['bottom-'+c.bottom],newFeet=art.pieces['feet-'+c.feet];
 const hoodUp=c.top==='hoodie'&&c.hood;
 const lh=c.head!=='hijab'&&!hoodUp?TLPremiumLongHair.resolve(c,longHair):null;
 if(c.head!=='hijab'&&!hoodUp&&!['afro','kurz_glatt','glatze'].includes(c.hair)&&!newHair&&!lh)return null;
 if(c.bottom!=='boxer'&&!newBottom||c.feet!=='boots'&&!newFeet)return null;
 if(!m.clothing&&(c.bottomc!=='schwarz'&&!(c.bottom==='boxer'&&c.bottomc==='rot')||c.feetc!=='schwarz'))return null;
 if(!m.gloves&&!['schwarzgold','weiss'].includes(c.glove))return null;
 if(c.hands==='wraps'&&(!wraps.pieces['wrap-'+c.pose_profile+'0']||!wraps.pieces['wrap-'+c.pose_profile+'1']||c.tone!==6&&!m.wrapSkin))return null;
 const hj=c.head==='hijab'?TLPremiumHijab.resolve(m.hijabMaterials&&m.clothing[c.headc]?{...c,headc:'schwarz'}:c,hijab):null;
 const hw=c.head==='none'?null:hj||TLPremiumHeadwear.resolve(m.headMaterials&&m.clothing[c.headc]?{...c,headc:'schwarz'}:c,headwear);if(c.head!=='none'&&!hw)return null;
 const hoodie=c.top==='hoodie'&&art.hoodie.poses.includes(c.pose_profile)&&c.coat==='none'&&c.head==='none'&&art.hoodie.supported?{pieces:Object.values(art.pieces).filter(p=>p.id.startsWith('top-'+c.pose_profile+'-hoodie-')&&(!p.id.endsWith('-up')||hoodUp)),bodyOcclusion:{type:'none'},requiredSources:c.pose_profile==='cool'?['hoodie/cool.png',...(hoodUp?['hoodie/guard.png']:[])]:['hoodie/guard.png']}:null;
 const jacket=c.top==='jacke'&&art.jacket.poses.includes(c.pose_profile)&&c.coat==='none'&&c.head==='none'&&!c.hood?{pieces:[art.pieces['top-guard-jacke']],bodyOcclusion:{type:'none'},requiredSources:['tops/assets/guard-jacket.png']}:null;
 const top=c.top==='none'?null:jacket||hoodie||TLPremiumTops.resolve(m.topMaterials&&m.clothing[c.topc]?{...c,topc:'schwarz'}:c,tops);if(c.top!=='none'&&!top)return null;
 if(!TLPremiumEffects.supports(c))return null;
 // Basic Cool uses a registered hidden-body mask; other poses remain unsupported by the base resolver.
 if(c.coat==='basic'&&(!art.pieces['coat-basic-'+c.pose_profile]||!art.pieces['coat-basic-back']))return null;
 const baseline=TLPremiumV2Pilot.resolve({...c,tone:6,hands:'gloves',hc:'schwarz',eye:'braun',hair:'afro',head:'none',top:'none',hood:false,coat:c.coat==='basic'?'samurai':c.coat,bottom:'boxer',bottomc:c.bottom==='boxer'&&c.bottomc==='rot'&&!m.clothing?'rot':'schwarz',feet:'boots',feetc:'schwarz',glove:m.gloves?'schwarzgold':c.glove,aura:'none',eyefx:'none',scene:'holo'},base);
 if(!baseline)return null;const selected=S.resolve(baseline,stream);if(!selected)return null;
 selected.config=c;selected.renderer='anime-draft';selected.hairMask=hw&&hw.hairMask;selected.topSelection=top;selected.hijabSelection=hj;selected.longHairSelection=lh;selected.hoodUp=hoodUp;selected.bodyKeep=jacket?art.jacket.bodyKeep:hoodie?art.hoodie.bodyKeep:c.coat==='basic'&&c.pose_profile==='cool'?art.basicCoolBodyKeep:null;
 const replace=(ids,parts)=>{const at=selected.pieces.findIndex(p=>ids.includes(p.id));if(at<0)return;selected.pieces=selected.pieces.filter(p=>!ids.includes(p.id));selected.pieces.splice(at,0,...parts);};
 const hair=hj||hoodUp||c.hair==='glatze'?[]:lh?lh.pieces.filter(p=>p.depth==='front'):newHair?[newHair]:[S.resolve({ids:[c.hair==='afro'?'hair-afro':'hair-short'],pose:c.pose_profile},stream).pieces[0]];
 replace(['hair-afro'],hair);
 if(lh)selected.pieces.unshift(...lh.pieces.filter(p=>p.depth==='back'));
 if(hw){const i=selected.pieces.findIndex(p=>p.slot==='hair');selected.pieces.splice(i<0?selected.pieces.findIndex(p=>p.slot==='eyes')+1:i+1,0,...hw.pieces);}
 if(c.coat==='samurai')replace(['coat-back'],[art.pieces['coat-back-clean']]);
 if(newBottom)replace(['bottom-black','bottom-red'],[newBottom]);
 if(newFeet)replace(['feet'],[newFeet]);
 if(top)selected.pieces.splice(selected.pieces.findIndex(p=>p.slot==='eyes'),0,...top.pieces);
 if(c.coat==='basic'){replace(['coat-back'],[art.pieces['coat-basic-back']]);replace(['coat-tail','coat-'+c.pose_profile],[art.pieces['coat-basic-'+c.pose_profile]]);}
 if(c.pose_profile==='guard'){
  if(c.coat==='samurai'&&art.pieces['coat-guard-v2'])replace(['coat-tail','coat-guard'],[art.pieces['coat-guard-v2']]);
  if((c.glove==='schwarzgold'||m.gloves)&&art.pieces['hands-master-0']&&art.pieces['hands-master-1'])replace(['guard-black-0','guard-black-1','guard-white-0','guard-white-1'],[art.pieces['hands-master-0'],art.pieces['hands-master-1']]);
 }
 if(c.hands==='wraps')replace(selected.pieces.filter(p=>p.slot==='hands').map(p=>p.id),[wraps.pieces['wrap-'+c.pose_profile+'0'],wraps.pieces['wrap-'+c.pose_profile+'1']]);
 selected.ids=selected.pieces.map(p=>p.id);return selected;
}
function crop(image,p){let map=crops.get(image);if(!map){map=new Map();crops.set(image,map)}const key=p.id+':'+p.uv.join(',');if(map.has(key))return map.get(key);const c=document.createElement('canvas');c.width=p.uv[2];c.height=p.uv[3];c.getContext('2d').drawImage(image,...p.uv,0,0,c.width,c.height);map.set(key,c);return c;}
const sleeveOcclusion=[[[180,230],[320,230],[313,280],[300,340],[290,400],[305,455],[290,480],[180,480]],[[465,230],[590,230],[590,480],[475,480],[460,455],[475,400],[465,340],[455,280]]];
function occludeSleeves(surface,p,config){if(p.id!=='body-guard'||!['samurai','basic'].includes(config.coat))return surface;const c=document.createElement('canvas');c.width=surface.width;c.height=surface.height;const g=c.getContext('2d');g.drawImage(surface,0,0);g.globalCompositeOperation='destination-out';for(const polygon of sleeveOcclusion){g.beginPath();polygon.forEach(([x,y],i)=>g[i?'lineTo':'moveTo'](x-p.box[0],y-p.box[1]));g.closePath();g.fill()}return c;}
function hideHijabEars(surface,p,selection){if(p.slot!=='body'||!selection.hijabSelection)return surface;const rects=selection.hijabSelection.bodyMask.rects.filter(([x,y,w,h])=>x<p.box[0]+p.box[2]&&x+w>p.box[0]&&y<p.box[1]+p.box[3]&&y+h>p.box[1]);if(!rects.length)return surface;const c=document.createElement('canvas');c.width=surface.width;c.height=surface.height;const g=c.getContext('2d');g.drawImage(surface,0,0);const sx=c.width/p.box[2],sy=c.height/p.box[3];for(const [x,y,w,h] of rects)g.clearRect((x-p.box[0])*sx,(y-p.box[1])*sy,w*sx,h*sy);return c;}
function keepCoveredBody(surface,p,selection){if(!selection.bodyKeep||p.id!=='body-'+selection.config.pose_profile)return surface;const c=document.createElement('canvas');c.width=surface.width;c.height=surface.height;const g=c.getContext('2d'),r=selection.bodyKeep;g.beginPath();g.rect(r[0]-p.box[0],r[1]-p.box[1],r[2],r[3]);g.clip();g.drawImage(surface,0,0);return c;}
function draw(ctx,selection,images,slot){
 if(!selection||selection.pieces.some(p=>!images[p.src]))throw Error('Incomplete outfit');
 ctx.clearRect(0,0,768,1216);
 if(['scene','aura','eyefx'].includes(slot)){TLPremiumEffects.drawSlot(ctx,selection.effectsConfig||selection.config,slot);return}
 if(!slot)TLPremiumEffects.drawBack(ctx,selection.effectsConfig||selection.config);
 let body;if(!slot&&selection.topSelection){body=document.createElement('canvas');body.width=768;body.height=1216;draw(body.getContext('2d'),selection,images,'body');}
 for(const p of selection.pieces){if(slot&&p.slot!==slot&&!(slot==='coat'&&p.slot.startsWith('coat')))continue;
  const source=crop(images[p.src],p),material=TLPremiumMaterials.applyToPiece(source,p.id,selection.config,p.box),isolated=p.slot==='hair'?TLPremiumMaterials.hairOnly(material,p.id,p.box):material,surface=keepCoveredBody(hideHijabEars(occludeSleeves(p.id==='body-'+selection.config.pose_profile&&selection.topSelection?.bodyVisibility?TLPremiumTops.maskBody(isolated,selection.topSelection,p.box):isolated,p,selection.config),p,selection),p,selection);ctx.save();if(p.slot==='hair'&&selection.hairMask&&selection.hairMask.type==='keepRect'){ctx.beginPath();ctx.rect(...selection.hairMask.rect);ctx.clip()}if(!slot&&p.bodyClipRect){ctx.beginPath();ctx.rect(...p.bodyClipRect);ctx.clip()}if(p.clipPolygon){ctx.beginPath();p.clipPolygon.forEach(([x,y],i)=>ctx[i?'lineTo':'moveTo'](x,y));ctx.closePath();ctx.clip()}if(p.transform)ctx.transform(...p.transform);ctx.drawImage(surface,p.box[0],p.box[1],p.box[2],p.box[3]);ctx.restore();if(surface!==isolated){surface.width=0;surface.height=0;}if(!slot&&p.slot==='top')TLPremiumTops.restoreArms(ctx,body,selection.topSelection,images);
 }
 if(body){body.width=0;body.height=0;}
 if(!slot)TLPremiumEffects.drawEyes(ctx,selection.effectsConfig||selection.config);
}
async function prepare(input){const selection=resolve(input);if(!selection)return {renderer:'svg',reason:'unsupported'};try{const images=await loader.prepare(selection);if(selection.topSelection)await Promise.all(selection.topSelection.requiredSources.map(async src=>{if(!images[src])images[src]=await loader.get(src)}));return {renderer:'anime-draft',selection,images}}catch(e){return {renderer:'svg',reason:'load-failed',error:e.message}}}
function itemFrame(selection,slot){if(['scene','aura','eyefx'].includes(slot)){if(slot!=='scene'&&selection.config[slot]==='none')return null;return slot==='eyefx'?[340,140,85,35]:[0,0,768,1216]}const ps=selection.pieces.filter(p=>p.slot===slot||(slot==='coat'&&p.slot.startsWith('coat')));if(!ps.length)return null;const x=Math.floor(Math.min(...ps.map(p=>p.box[0]))),y=Math.floor(Math.min(...ps.map(p=>p.box[1])));return[x,y,Math.ceil(Math.max(...ps.map(p=>p.box[0]+p.box[2])))-x,Math.ceil(Math.max(...ps.map(p=>p.box[1]+p.box[3])))-y]}
window.TLPremiumProduction=Object.freeze({init,resolve,prepare,draw,itemFrame,defaults,loader,sleeveOcclusion,approved:false,enabled:false});
})();
