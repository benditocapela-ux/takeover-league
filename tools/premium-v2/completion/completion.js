/* Candidate compositor: combine registered items, never substitute another item's artwork. */
(function(){'use strict';
const P=window.TLPremiumProduction;let manifest,parts;
async function init(){parts=await P.init();await TLPremiumPoseRig.init();const r=await fetch('completion/manifest.json');if(!r.ok)throw Error('Missing completion registrations');manifest=await r.json();return parts}
function resolve(input){
 if(!manifest)return null;
 const c=TLHolo.normalize({...P.defaults,...input});if(!['cool','guard'].includes(c.pose_profile)){const base=resolve({...c,pose_profile:'guard'});return base?TLPremiumPoseRig.retarget(base,c):null;}
 const isolated={...c,head:'none',top:'none',hood:false,coat:'none'};
 const body=P.resolve({...isolated,hair:'afro'});if(!body)return null;
 const hair=P.resolve(isolated);if(!hair)return null;
 const head=c.head==='none'?null:P.resolve({...isolated,hair:'kurz_glatt',head:c.head});if(c.head!=='none'&&!head)return null;
 let top=c.top==='none'?null:P.resolve({...c,hair:'kurz_glatt',head:'none',coat:'none'});
 if(c.top==='jacke'&&c.pose_profile==='cool'&&manifest.pieces['top-cool-jacke'])top={pieces:[manifest.pieces['top-cool-jacke']],bodyKeep:[300,230,175,325],topSelection:{pieces:[manifest.pieces['top-cool-jacke']],bodyOcclusion:{type:'none'},requiredSources:[manifest.pieces['top-cool-jacke'].src]}};
 if(c.top!=='none'&&!top)return null;
 let coat=c.coat==='none'?null:P.resolve({...isolated,hair:'kurz_glatt',coat:['neon','drache'].includes(c.coat)?'basic':c.coat});
 if(coat&&['neon','drache'].includes(c.coat)){
  const front=manifest.pieces['coat-'+c.coat+'-'+c.pose_profile],back=manifest.pieces['coat-'+c.coat+'-back'];if(!front||!back)return null;
  coat={...coat,pieces:[back,front]};
 }
 if(c.coat!=='none'&&!coat)return null;
 const by=(s,fn)=>s?s.pieces.filter(fn):[],isHair=p=>p.slot==='hair',isTop=p=>p.slot==='top',isFront=p=>p.slot==='coatFront';
 const hideHair=c.head==='hijab'||c.top==='hoodie'&&c.hood;
 const hairPieces=hideHair?[]:by(hair,isHair),topPieces=by(top,isTop);
 const core=body.pieces.filter(p=>!['hair','hands','eyes'].includes(p.slot));
 // Coat sleeves cover garment sleeves. Restrict only the worn inner torso;
 // item-only draws retain the exact complete garment source.
 const underCoat=topPieces.map(p=>coat&&!p.id.endsWith('-up')?{...p,bodyClipRect:[300,210,175,345]}:p);
 body.pieces=[...by(coat,p=>p.slot==='coatBack'),...hairPieces.filter(p=>p.depth==='back'),...core,
  ...underCoat.filter(p=>!p.id.endsWith('-up')),...by(body,p=>p.slot==='eyes'),
  ...hairPieces.filter(p=>p.depth!=='back'),...by(coat,isFront),...by(head,p=>p.slot==='head'),
  ...underCoat.filter(p=>p.id.endsWith('-up')),...by(body,p=>p.slot==='hands')];
 body.config=c;body.ids=body.pieces.map(p=>p.id);body.topSelection=top?.topSelection;
 body.bodyKeep=coat?[315,230,145,320]:top?.bodyKeep;
 body.hairMask=head?.hairMask;body.hijabSelection=head?.hijabSelection;
 body.longHairSelection=hair.longHairSelection;
 return body;
}
async function prepare(c){const selection=resolve(c);if(!selection)return {renderer:'svg',reason:'unsupported'};try{const images=await P.loader.prepare(selection);for(const src of selection.topSelection?.requiredSources||[])if(!images[src])images[src]=await P.loader.get(src);return {renderer:'anime-draft',selection,images}}catch(e){return {renderer:'svg',reason:'load-failed',error:e.message}}}
const materialCache=new Map();let materialBytes=0;const MAX_MATERIAL_BYTES=8*1024*1024;
function material(image,p,c){const key=p.id+'|'+p.material+'|'+c.topc;let entry=materialCache.get(key);if(entry?.image===image)return entry.surface;
 const cv=document.createElement('canvas');cv.width=image.width;cv.height=image.height;const g=cv.getContext('2d');g.drawImage(image,0,0);
 if(p.id==='top-cool-jacke'){const transformed=TLPremiumMaterials.applyToPiece(cv,'top-guard-jacke',c,p.box);if(transformed!==cv){g.clearRect(0,0,cv.width,cv.height);g.drawImage(transformed,0,0)}}
 else{const pixels=g.getImageData(0,0,cv.width,cv.height),d=pixels.data;for(let i=0;i<d.length;i+=4){if(!d[i+3])continue;const r=d[i],gr=d[i+1],b=d[i+2],gold=r>gr*1.08&&gr>b*1.18&&r-b>15,lum=.2126*r+.7152*gr+.0722*b;
 if(p.material==='neon'){if(gold){d[i]=lum*.18;d[i+1]=Math.min(255,lum*1.12);d[i+2]=Math.min(255,lum*1.3)}else{d[i]=lum*.45;d[i+1]=lum*.8;d[i+2]=Math.min(255,lum*1.3)}}
 else if(p.material==='drache'&&!gold){d[i]=Math.min(255,lum*2.8);d[i+1]=lum*.2;d[i+2]=lum*.32}
 else if(p.material==='basic'&&gold){d[i]=lum;d[i+1]=Math.min(255,lum*1.02);d[i+2]=Math.min(255,lum*1.08)}}
 g.putImageData(pixels,0,0)}
 if(entry){materialBytes-=entry.bytes;materialCache.delete(key)}const bytes=cv.width*cv.height*4;if(bytes<=MAX_MATERIAL_BYTES){while(materialCache.size&&(materialCache.size>=24||materialBytes+bytes>MAX_MATERIAL_BYTES)){const oldest=materialCache.keys().next().value;materialBytes-=materialCache.get(oldest).bytes;materialCache.delete(oldest)}materialCache.set(key,{image,surface:cv,bytes});materialBytes+=bytes}return cv;
}
const neckCache=new WeakMap();
function draw(ctx,s,images,slot){const mapped={...images},pieces=s.pieces.map(p=>{
 if(p.id==='head'&&!['cool','guard'].includes(s.config.pose_profile)){const im=images[p.src];let cv=neckCache.get(im);if(!cv){cv=document.createElement('canvas');cv.width=p.uv[2];cv.height=p.uv[3];const g=cv.getContext('2d');g.drawImage(im,...p.uv,0,0,cv.width,cv.height);const fade=20*cv.height/p.box[3],gradient=g.createLinearGradient(0,cv.height-fade,0,cv.height);gradient.addColorStop(0,'#fff');gradient.addColorStop(1,'#fff0');g.globalCompositeOperation='destination-in';g.fillStyle=gradient;g.fillRect(0,0,cv.width,cv.height);neckCache.set(im,cv)}mapped['fade:head']=cv;return {...p,src:'fade:head',uv:[0,0,cv.width,cv.height]}}
 if(!p.material&&p.id!=='top-cool-jacke')return p;const src='material:'+p.id;mapped[src]=material(images[p.src],p,s.config);return {...p,src}});P.draw(ctx,{...s,pieces},mapped,slot)}
function itemFrame(s,slot){return P.itemFrame({...s,pieces:s.pieces.map(p=>({...p,box:TLPremiumPoseRig.bounds(p)}))},slot)}
window.TLPremiumCompletion=Object.freeze({init,resolve,prepare,draw,itemFrame,defaults:P.defaults,loader:P.loader});
})();
