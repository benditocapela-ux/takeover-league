'use strict';
// Coordinates are hand-marked on the unchanged body, not inferred from the
// glove bounds. These checks catch the original centred/low glove regression;
// they cannot certify drawing quality, joint anatomy or natural occlusion.
module.exports=async function glovePixels(page,base){
 return page.evaluate(async base=>{
  const width=768,height=1216;
  const load=async name=>{const i=new Image();i.src=base+'/assets/boxer-artpacks/v1/modular-cool/'+name+'.png';await i.decode();const c=document.createElement('canvas');c.width=width;c.height=height;const g=c.getContext('2d');g.drawImage(i,0,0);return g.getImageData(0,0,width,height).data};
  const masks=await Promise.all(['hands-blackgold','hands-white'].map(load));
  const alpha=(data,x,y)=>data[(y*width+x)*4+3];
  const wristPoints=[[310,374],[420,386]];
  const bareHandPoints=[[251,350],[270,350],[290,363],[302,370],[440,375],[459,381],[471,385]];
  const forearmPoints=[[360,407],[382,402],[366,399],[375,395]];
  const reports=masks.map(data=>{
   const boxes=[{left:768,top:1216,right:0,bottom:0,area:0,sx:0,sy:0},{left:768,top:1216,right:0,bottom:0,area:0,sx:0,sy:0}];
   for(let y=0;y<height;y++)for(let x=0;x<width;x++)if(alpha(data,x,y)>127){
    const b=boxes[x<380?0:1];b.left=Math.min(b.left,x);b.right=Math.max(b.right,x);b.top=Math.min(b.top,y);b.bottom=Math.max(b.bottom,y);b.area++;b.sx+=x;b.sy+=y;
   }
   const sample=points=>points.map(([x,y])=>{let min=255,max=0;for(let dy=-1;dy<=1;dy++)for(let dx=-1;dx<=1;dx++){const a=alpha(data,x+dx,y+dy);min=Math.min(min,a);max=Math.max(max,a)}return {x,y,min,max}});
   return {boxes:boxes.map(b=>({left:b.left,top:b.top,right:b.right,bottom:b.bottom,area:b.area,cx:b.sx/b.area,cy:b.sy/b.area})),wrists:sample(wristPoints),hands:sample(bareHandPoints),forearm:sample(forearmPoints)};
  });
  let intersection=0,union=0;
  for(let i=3;i<masks[0].length;i+=4){const a=masks[0][i]>127,b=masks[1][i]>127;if(a||b)union++;if(a&&b)intersection++}
  return {reports,iou:intersection/union};
 },base);
};
