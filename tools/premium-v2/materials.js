/* Isolated authoring material renderer; no live editor import or network side effects. */
(function(root){'use strict';
const skinMid=[[246,220,199],[240,206,179],[230,190,155],[220,170,130],[208,151,106],[196,133,88],[185,112,64],[131,74,40]];
const hair={schwarz:['#221c26','#0e0a12','#5d4f72'],braun:['#5a3420','#2e180c','#a8714a'],dunkelbraun:['#3a2216','#1c0f08','#7a5038'],blond:['#e8c46a','#b8913a','#fff0b8'],rot:['#b8322a','#6a1410','#f08a6a'],silber:['#d8dce8','#8e98b4','#ffffff'],blau:['#2f6bff','#12256e','#9cc0ff'],pink:['#ff7ac0','#a3286a','#ffd0ea']};
const eyes={braun:['#7a4a22','#2a1408','#c89a6a'],hasel:['#9a7a32','#3a2a08','#e0c88a'],gruen:['#3a9a5a','#0b4a26','#b8f0c8'],blau:['#3a8ad8','#0b2a5e','#c8e4ff'],grau:['#8a96a8','#2e3644','#e0e6ee'],gold:['#f2c14e','#6e4a00','#fff1b8'],orange:['#ff6a2a','#7a1606','#ffd27a'],violett:['#9b5cff','#2e1166','#e2c8ff']};
const gloves={rot:['#e0263a','#8e0f1e','#f6f2ea'],weiss:['#f4f4f6','#b8bfcc','#c0162f'],schwarzgold:['#2a2830','#0c0b10','#f2c14e'],eisblau:['#4fd8ff','#1a7aa8','#ffffff'],glut:['#ff6a1f','#a3220f','#ffd23a']};
const clothing={schwarz:['#24222c','#0e0d12','#f2c14e'],weiss:['#eef0f5','#b8bfcc','#c0162f'],grau:['#7a8194','#4a5062','#eef0f5'],rot:['#c0162f','#6e0a1a','#ffffff'],blau:['#1f4fc8','#0e2468','#ffffff'],gruen:['#1f8a5a','#0c4a2e','#ffffff'],lila:['#6a2bd6','#3a127a','#ffffff'],gold:['#f2c14e','#a4781c','#24222c']};
const glovePart=id=>id==='hands-blackgold'||id.startsWith('hands-master-')||id.startsWith('guard-black-');
const bottomPart=id=>['bottom-black','bottom-jogger','bottom-kurz','bottom-track'].includes(id)||id.startsWith('bottom-master-');
const feetPart=id=>id==='feet'||id==='feet-sneaker'||id.startsWith('feet-master-');
const hex=s=>[1,3,5].map(i=>parseInt(s.slice(i,i+2),16));
const mix=(a,b,t)=>a.map((v,i)=>v+(b[i]-v)*Math.min(1,Math.max(0,t)));
function ramp(v,points){for(let i=1;i<points.length;i++)if(v<=points[i][0])return mix(points[i-1][1],points[i][1],(v-points[i-1][0])/(points[i][0]-points[i-1][0]));return points.at(-1)[1]}
const ellipse=(x,y,cx,cy,rx,ry)=>((x-cx)/rx)**2+((y-cy)/ry)**2<=1;
function masks(r,g,b,a,x,y,id){
 if(!a)return [0,0,0,0];
 const body=['body','head','lower','body-cool','body-guard'].includes(id),eye=id==='eyes';
 const warm=r>g*1.08&&g>b*1.07&&r-b>12;
 const iris=(ellipse(x,y,356.5,157.5,5.8,7.4)||ellipse(x,y,405.3,157.6,5.8,7.4))&&warm&&r>48;
 // The source's underwear and neutral face lines are not skin material. Protection is
 // based on registered source coordinates AND chroma, not a global image filter.
 const afroSkin=id==='hair-afro'&&y>=(x<338?143:x<380?137:x<405?133:x<428?139:145);
 const skin=(body||eye||afroSkin)&&warm&&!iris&&r>35?1:0;
 const gold=r>g*1.08&&g>b*1.18&&r-b>15;
 const leather=(glovePart(id)||bottomPart(id)||feetPart(id))&&!gold?1:0;
 return [skin,eye&&iris?1:0,id.startsWith('hair-')&&!afroSkin?1:0,leather];
}
function transformPixels(data,width,height,id,config={},box=[0,0,width,height]){
 const out=new Uint8ClampedArray(data),tone=config.tone===undefined?6:Number(config.tone),hc=config.hc||'schwarz',ec=config.eye||'braun';
 if(!Number.isInteger(tone)||tone<0||tone>7||!hair[hc]||!eyes[ec]||(config.glove&&!gloves[config.glove])||(config.bottomc&&!clothing[config.bottomc])||(config.feetc&&!clothing[config.feetc]))throw Error('Unsupported material variant');
 const hp=hair[hc].map(hex),ep=eyes[ec].map(hex),target=skinMid[tone],source=skinMid[6];
 const materialKey=glovePart(id)?config.glove||'schwarzgold':bottomPart(id)?config.bottomc||'schwarz':feetPart(id)?config.feetc||'schwarz':null,materialPalette=materialKey&&(glovePart(id)?gloves:clothing)[materialKey].map(hex);
 for(let y=0;y<height;y++)for(let x=0;x<width;x++){
  const i=(y*width+x)*4,r=data[i],g=data[i+1],b=data[i+2],a=data[i+3];if(!a)continue;
  const m=masks(r,g,b,a,box[0]+x,box[1]+y,id);let rgb=[r,g,b];
  if(m[0]&&tone!==6){const lum=.2126*r+.7152*g+.0722*b,mid=.2126*source[0]+.7152*source[1]+.0722*source[2];rgb=ramp(lum,[[0,[0,0,0]],[25,target.map((v,k)=>v*[.14,.095,.07][k])],[60,target.map((v,k)=>v*[.55,.43,.36][k])],[mid,target],[220,mix(target,[255,248,236],.82)],[255,[255,255,255]]]);}
  if(m[1]&&ec!=='braun')rgb=ramp(.2126*r+.7152*g+.0722*b,[[0,[0,0,0]],[28,ep[1]],[95,ep[0]],[210,ep[2]],[255,[255,255,255]]]);
  if(m[2]&&hc!=='schwarz')rgb=ramp(.2126*r+.7152*g+.0722*b,[[0,[3,3,5]],[18,mix([3,3,5],hp[1],.55)],[55,hp[0]],[150,hp[2]],[255,[255,247,229]]]);
  if(m[3]&&materialKey&&!['schwarz','schwarzgold'].includes(materialKey)){const [base,shade]=materialPalette;rgb=ramp(.2126*r+.7152*g+.0722*b,[[0,[0,0,0]],[7,[7,7,8]],[24,mix([0,0,0],shade,.78)],[60,base],[180,mix(base,[255,255,255],.65)],[255,[255,255,255]]]);}
  out[i]=rgb[0];out[i+1]=rgb[1];out[i+2]=rgb[2];
 }
 return out;
}
let imageKeys=new WeakMap(),nextImage=0,hits=0,misses=0,bytes=0;const cache=new Map(),MAX_BYTES=8*1024*1024,MAX_ENTRIES=24;
function clear(){cache.clear();imageKeys=new WeakMap();bytes=0;hits=0;misses=0;}
function stats(){return {entries:cache.size,bytes,hits,misses,maxEntries:MAX_ENTRIES,maxBytes:MAX_BYTES};}
// Registered bottom contour of the existing Afro curl mass. Face/ears/brows are
// owned by the body, not by this equipment part. Independent of recoloured RGB.
const afroEdge=[[300,135],[318,137],[322,140],[326,141],[332,146],[336,149],[339,141],[342,132],[344,128],[347,128],[350,126],[353,128],[355,133],[358,134],[360,132],[362,127],[367,126],[369,130],[370,135],[373,135],[376,131],[379,126],[383,128],[386,129],[389,128],[391,133],[394,135],[396,134],[399,128],[402,127],[406,128],[409,131],[410,135],[413,134],[415,131],[417,127],[420,128],[423,131],[425,134],[428,139],[430,143],[433,145],[436,145],[440,140],[445,137],[450,135],[470,135]];
function afroBottom(x){for(let i=1;i<afroEdge.length;i++)if(x<=afroEdge[i][0]){const a=afroEdge[i-1],b=afroEdge[i];return a[1]+(b[1]-a[1])*(x-a[0])/(b[0]-a[0]);}return 135;}
function isolateHairPixels(data,width,height,id,box=[0,0,width,height]){
 const out=new Uint8ClampedArray(data);if(id!=='hair-afro')return out;
 for(let y=0;y<height;y++)for(let x=0;x<width;x++){const i=(y*width+x)*4+3,keep=Math.max(0,Math.min(1,afroBottom(box[0]+x)-(box[1]+y)+.5));out[i]=Math.round(data[i]*keep);}return out;
}
function hairOnly(image,id,box,canvasFactory){
 if(id!=='hair-afro')return image;
 if(!imageKeys.has(image))imageKeys.set(image,++nextImage);const key=['hairOnly-v1',imageKeys.get(image),...(box||[])].join(':');if(cache.has(key)){const item=cache.get(key);cache.delete(key);cache.set(key,item);hits++;return item.canvas;}misses++;
 const width=image.naturalWidth||image.width,height=image.naturalHeight||image.height,cv=canvasFactory?canvasFactory(width,height):document.createElement('canvas');cv.width=width;cv.height=height;const g=cv.getContext('2d',{willReadFrequently:true});g.drawImage(image,0,0);const p=g.getImageData(0,0,width,height);p.data.set(isolateHairPixels(p.data,width,height,id,box));g.putImageData(p,0,0);const cost=width*height*4;if(cost<=MAX_BYTES){while(cache.size&&(cache.size>=MAX_ENTRIES||bytes+cost>MAX_BYTES)){const oldest=cache.keys().next().value;bytes-=cache.get(oldest).bytes;cache.delete(oldest);}cache.set(key,{canvas:cv,bytes:cost});bytes+=cost;}return cv;
}
function applyToPiece(image,id,config={},box,canvasFactory){
 const tone=config.tone===undefined?6:Number(config.tone),hc=config.hc||'schwarz',eye=config.eye||'braun';
 if(!Number.isInteger(tone)||tone<0||tone>7||!hair[hc]||!eyes[eye]||(config.glove&&!gloves[config.glove])||(config.bottomc&&!clothing[config.bottomc])||(config.feetc&&!clothing[config.feetc]))throw Error('Unsupported material variant');
 const skinPart=['body','head','lower','body-cool','body-guard','eyes','hair-afro'].includes(id);
 const garmentChanged=glovePart(id)&&config.glove&&config.glove!=='schwarzgold'||bottomPart(id)&&config.bottomc&&config.bottomc!=='schwarz'||feetPart(id)&&config.feetc&&config.feetc!=='schwarz';
 if((!skinPart||tone===6)&&(!id.startsWith('hair-')||hc==='schwarz')&&(id!=='eyes'||eye==='braun')&&!garmentChanged)return image;
 if(!imageKeys.has(image))imageKeys.set(image,++nextImage);const key=[imageKeys.get(image),id,tone,hc,eye,config.glove,config.bottomc,config.feetc,...(box||[])].join(':');
 if(cache.has(key)){const item=cache.get(key);cache.delete(key);cache.set(key,item);hits++;return item.canvas;}misses++;
 const width=image.naturalWidth||image.width,height=image.naturalHeight||image.height;
 const cv=canvasFactory?canvasFactory(width,height):document.createElement('canvas');cv.width=width;cv.height=height;
 const g=cv.getContext('2d',{willReadFrequently:true});g.drawImage(image,0,0);const pixels=g.getImageData(0,0,width,height);pixels.data.set(transformPixels(pixels.data,width,height,id,config,box));g.putImageData(pixels,0,0);const cost=width*height*4;if(cost<=MAX_BYTES){while(cache.size&&(cache.size>=MAX_ENTRIES||bytes+cost>MAX_BYTES)){const oldest=cache.keys().next().value;bytes-=cache.get(oldest).bytes;cache.delete(oldest);}cache.set(key,{canvas:cv,bytes:cost});bytes+=cost;}return cv;
}
const api=Object.freeze({approved:false,enabled:false,status:'Artistically pending',skinMid,hair,eyes,gloves,clothing,masks,transformPixels,applyToPiece,hairOnly,isolateHairPixels,afroEdge,clear,stats});
if(typeof module!=='undefined'&&module.exports)module.exports=api;else root.TLPremiumMaterials=api;
})(typeof window!=='undefined'?window:globalThis);
