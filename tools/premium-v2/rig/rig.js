/* Bounded authoring experiment: one arm, nine tiny angle combinations, no editor integration. */
(function(root){
  'use strict';
  const radians = degrees => degrees * Math.PI / 180;
  const rotate = (point, angle) => [point[0]*Math.cos(angle)-point[1]*Math.sin(angle), point[0]*Math.sin(angle)+point[1]*Math.cos(angle)];
  const plus = (a,b) => [a[0]+b[0],a[1]+b[1]];
  const minus = (a,b) => [a[0]-b[0],a[1]-b[1]];
  function pose(manifest, shoulderDegrees=0, elbowDegrees=0){
    if(![-10,0,10].includes(shoulderDegrees)||![-10,0,10].includes(elbowDegrees))throw Error('Only the nine bounded prototype states are supported');
    const a=radians(shoulderDegrees),b=radians(shoulderDegrees+elbowDegrees);
    const shoulder=manifest.shoulder;
    const elbow=plus(shoulder,rotate(minus(manifest.parts.upper.distal,manifest.parts.upper.pivot),a));
    const wrist=plus(elbow,rotate(minus(manifest.parts.forearm.distal,manifest.parts.forearm.pivot),b));
    const forearmAxis=minus(manifest.parts.forearm.distal,manifest.parts.forearm.pivot),handAxis=minus(manifest.parts.hand.distal,manifest.parts.hand.pivot);
    const handAngle=b+Math.atan2(forearmAxis[0],-forearmAxis[1])-Math.atan2(handAxis[0],-handAxis[1]);
    return {shoulder,elbow,wrist,upperAngle:a,forearmAngle:b,handAngle,shoulderDegrees,elbowDegrees};
  }
  function draw(ctx,manifest,images,shoulderDegrees=0,elbowDegrees=0,markers=false){
    ctx.clearRect(0,0,manifest.canvas[0],manifest.canvas[1]);
    const p=pose(manifest,shoulderDegrees,elbowDegrees);
    for(const [key,anchor,angle] of [['upper',p.shoulder,p.upperAngle],['forearm',p.elbow,p.forearmAngle],['hand',p.wrist,p.handAngle]]){
      const part=manifest.parts[key];ctx.save();ctx.translate(...anchor);ctx.rotate(angle);ctx.drawImage(images[key],-part.pivot[0],-part.pivot[1],part.size[0],part.size[1]);ctx.restore();
    }
    if(markers){ctx.fillStyle='#40e2ff';for(const point of [p.shoulder,p.elbow,p.wrist]){ctx.beginPath();ctx.arc(...point,3,0,Math.PI*2);ctx.fill();}}
    return p;
  }
  async function load(manifest){const pairs=await Promise.all(Object.entries(manifest.parts).map(async([key,part])=>{const image=new Image();image.src=part.src;await image.decode();return [key,image]}));return Object.fromEntries(pairs);}
  root.TLPremiumArmRig=Object.freeze({pose,draw,load,approved:false,enabled:false});
})(typeof window==='undefined'?globalThis:window);
