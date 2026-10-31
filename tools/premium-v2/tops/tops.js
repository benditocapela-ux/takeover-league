(function(){'use strict';
function resolve(c,m,{inspectDraft=false}={}){if(!m.poses.includes(c.pose_profile)||!(m.tops.includes(c.top)||(inspectDraft&&m.draftTops.includes(c.top)))||c.topc!=='schwarz'||c.hood||!m.allowedCoats.includes(c.coat))return null;const bodyOcclusion=c.top==='shirt'&&c.pose_profile==='cool'?m.bodyOcclusion.coolShirt:m.bodyOcclusion[c.pose_profile];const pieces=[m.pieces['top-'+c.pose_profile+'-'+c.top]];return {pieces,bodyOcclusion,requiredSources:[...new Set([...pieces.map(p=>p.src),...(bodyOcclusion.src?[bodyOcclusion.src]:[])])]};}
function draw(ctx,selection,images,{item=false}={}){for(const p of selection.pieces){ctx.save();if(p.bodyClipRect&&!item){ctx.beginPath();ctx.rect(...p.bodyClipRect);ctx.clip()}ctx.drawImage(images[p.src],...p.uv,...p.box);ctx.restore()}}
function restoreArms(ctx,registeredBody,selection,images={}){const mask=selection.bodyOcclusion;if(mask.type==='none')return;if(mask.type==='restoreBodyMask'){
if(!images[mask.src])throw Error('Missing pose occlusion source');
const region=mask.box,[rx,ry,w,h]=region,make=()=>{const c=document.createElement('canvas');c.width=w;c.height=h;return c};
const mc=make(),mg=mc.getContext('2d');mg.drawImage(images[mask.src],...mask.uv,0,0,w,h);
const bc=make(),bg=bc.getContext('2d');bg.drawImage(registeredBody,...region,0,0,w,h);
const out=ctx.getImageData(...region),body=bg.getImageData(0,0,w,h).data,shape=mg.getImageData(0,0,w,h).data;
for(let i=0;i<out.data.length;i+=4){const weight=shape[i+3]/255;if(!weight)continue;if(weight===1){for(let k=0;k<4;k++)out.data[i+k]=body[i+k];continue}const sa=body[i+3]/255,da=out.data[i+3]/255,alpha=sa*weight+da*(1-weight);for(let k=0;k<3;k++)out.data[i+k]=alpha?(body[i+k]*sa*weight+out.data[i+k]*da*(1-weight))/alpha:0;out.data[i+3]=alpha*255}
ctx.putImageData(out,rx,ry);return}ctx.save();ctx.beginPath();for(const polygon of mask.polygons){ctx.moveTo(...polygon[0]);for(const point of polygon.slice(1))ctx.lineTo(...point);ctx.closePath()}ctx.clip();ctx.clearRect(0,0,768,1216);ctx.drawImage(registeredBody,0,0);ctx.restore();}
window.TLPremiumTops=Object.freeze({resolve,draw,restoreArms,approved:false,enabled:false});
})();
