(function(){'use strict';
function resolve(c,m,{inspectDraft=false}={}){if((m.supportedHeads?.[c.top]&&!m.supportedHeads[c.top].includes(c.head))||(!inspectDraft&&m.supportedPoses?.[c.top]&&!m.supportedPoses[c.top].includes(c.pose_profile))||!m.poses.includes(c.pose_profile)||!(m.tops.includes(c.top)||(inspectDraft&&m.draftTops.includes(c.top)))||c.topc!=='schwarz'||c.hood||!m.allowedCoats.includes(c.coat))return null;const bodyOcclusion=c.top==='shirt'?m.bodyOcclusion[c.pose_profile==='cool'?'coolShirt':'guardShirt']:m.bodyOcclusion[c.pose_profile];const pieces=[m.pieces['top-'+c.pose_profile+'-'+c.top]];return {pieces,bodyOcclusion,bodyVisibility:c.top==='shirt'?{...m.bodyVisibility.shirt,arms:bodyOcclusion.polygons||[]}:null,requiredSources:[...new Set([...pieces.map(p=>p.src),...(bodyOcclusion.src?[bodyOcclusion.src]:[])])]};}
function draw(ctx,selection,images,{item=false}={}){for(const p of selection.pieces){ctx.save();if(p.bodyClipRect&&!item){ctx.beginPath();ctx.rect(...p.bodyClipRect);ctx.clip()}ctx.drawImage(images[p.src],...p.uv,...p.box);ctx.restore()}}
function restoreArms(ctx,registeredBody,selection,images={}){
 const mask=selection.bodyOcclusion;if(mask.type==='none')return;
 const points=mask.polygons?.flat();
 const left=points?Math.max(0,Math.floor(Math.min(...points.map(p=>p[0])))):0;
 const top=points?Math.max(0,Math.floor(Math.min(...points.map(p=>p[1])))):0;
 const region=mask.type==='restoreBodyMask'?mask.box:[left,top,Math.min(768,Math.ceil(Math.max(...points.map(p=>p[0])))+1)-left,Math.min(1216,Math.ceil(Math.max(...points.map(p=>p[1])))+1)-top];
 const [rx,ry,w,h]=region,make=()=>{const c=document.createElement('canvas');c.width=w;c.height=h;return c;};
 const mc=make(),mg=mc.getContext('2d',{willReadFrequently:true});
 if(mask.type==='restoreBodyMask'){if(!images[mask.src])throw Error('Missing pose occlusion source');mg.drawImage(images[mask.src],...mask.uv,0,0,w,h);}
 else {mg.fillStyle='#fff';mg.beginPath();for(const polygon of mask.polygons){polygon.forEach(([x,y],i)=>mg[i?'lineTo':'moveTo'](x-rx,y-ry));mg.closePath()}mg.fill();}
 const bc=make(),bg=bc.getContext('2d',{willReadFrequently:true});bg.drawImage(registeredBody,...region,0,0,w,h);
 const out=ctx.getImageData(...region),body=bg.getImageData(0,0,w,h).data,shape=mg.getImageData(0,0,w,h).data;
 // Blend coverage once. Clipped clear + clipped draw applies edge coverage twice
 // and leaves a dark seam even when the original skin is already underneath.
 for(let i=0;i<out.data.length;i+=4){const weight=shape[i+3]/255;if(!weight)continue;if(weight===1){for(let k=0;k<4;k++)out.data[i+k]=body[i+k];continue}const sa=body[i+3]/255,da=out.data[i+3]/255,alpha=sa*weight+da*(1-weight);for(let k=0;k<3;k++)out.data[i+k]=alpha?(body[i+k]*sa*weight+out.data[i+k]*da*(1-weight))/alpha:0;out.data[i+3]=alpha*255;}
 ctx.putImageData(out,rx,ry);mc.width=mc.height=bc.width=bc.height=0;
}
function maskBody(surface,selection,box=[0,0,768,1216]){if(!selection?.bodyVisibility)return surface;const v=selection.bodyVisibility,c=document.createElement('canvas');c.width=surface.width;c.height=surface.height;const g=c.getContext('2d'),sx=c.width/box[2],sy=c.height/box[3];g.drawImage(surface,0,0);g.save();g.scale(sx,sy);g.translate(-box[0],-box[1]);g.clearRect(...v.region);g.beginPath();g.rect(...v.core);for(const polygon of [...v.arms,...v.underSleeves]){polygon.forEach(([x,y],i)=>g[i?'lineTo':'moveTo'](x,y));g.closePath()}g.clip();g.beginPath();g.rect(...v.region);g.clip();g.drawImage(surface,...box);g.restore();return c;}
window.TLPremiumTops=Object.freeze({resolve,draw,restoreArms,maskBody,approved:false,enabled:false});
})();
