(function(){'use strict';
 function resolve(c,manifest){
   if(!manifest.poses.includes(c.pose_profile)||c.headc!=='schwarz'||c.hood||!manifest.supportedHair[c.head]?.includes(c.hair))return null;
   return {pieces:[manifest.pieces[c.head]],hairMask:manifest.hairMasks[c.head],head:c.head};
 }
 function maskHair(image,mask){const c=document.createElement('canvas');c.width=768;c.height=1216;const g=c.getContext('2d');g.save();if(mask.type==='keepRect'){g.beginPath();g.rect(...mask.rect);g.clip()}g.drawImage(image,0,0);g.restore();return c;}
 function draw(ctx,selection,images,{clear=false}={}){if(clear)ctx.clearRect(0,0,ctx.canvas.width,ctx.canvas.height);for(const p of selection.pieces)ctx.drawImage(images[p.src],...p.uv,...p.box);}
 window.TLPremiumHeadwear=Object.freeze({resolve,maskHair,draw,approved:false,enabled:false});
})();
