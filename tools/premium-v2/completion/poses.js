(function(){'use strict';let rig,sleeves,art,bodies;
const joints={
 jab:[[[285,275],[185,268],[95,260]],[[485,275],[535,420],[465,260]]],
 sieg:[[[285,275],[245,425],[265,570]],[[485,275],[560,190],[600,110]]],
 flex:[[[285,275],[170,285],[185,155]],[[485,275],[600,285],[585,155]]],
 ansage:[[[285,275],[245,425],[265,570]],[[485,275],[600,310],[690,235]]]
};
async function init(){[rig,sleeves,art,bodies]=await Promise.all(['completion/pose-assets.json','completion/sleeves.json','completion/manifest.json','completion/pose-bodies.json'].map(async u=>(await fetch(u)).json()))}
function affine(pivot,distal,start,end,mirror=false,width=1){const ux=distal[0]-pivot[0],uy=distal[1]-pivot[1],l=Math.hypot(ux,uy),u=[ux/l,uy/l],v=[-u[1],u[0]],dx=end[0]-start[0],dy=end[1]-start[1],dl=Math.hypot(dx,dy),w=(mirror?-1:1)*width,n=[-dy/dl*w,dx/dl*w];const a=dx/l*u[0]+n[0]*v[0],c=dx/l*u[1]+n[0]*v[1],b=dy/l*u[0]+n[1]*v[0],d=dy/l*u[1]+n[1]*v[1];return[a,b,c,d,start[0]-a*pivot[0]-c*pivot[1],start[1]-b*pivot[0]-d*pivot[1]]}
function crop(p,r){const sx=p.uv[2]/p.box[2],sy=p.uv[3]/p.box[3];return {...p,uv:[p.uv[0]+(r[0]-p.box[0])*sx,p.uv[1]+(r[1]-p.box[1])*sy,r[2]*sx,r[3]*sy],box:r}}
function retarget(s,c){if(!rig||!bodies?.poses[c.pose_profile])return null;
 const clothes=[],hands=[],originalHands=s.pieces.filter(p=>p.slot==='hands'),style=c.coat!=='none'?'coat':['shirt','hoodie','jacke'].includes(c.top)?c.top:null;
 (bodies.poses[c.pose_profile]?.anchors||joints[c.pose_profile]).forEach(([shoulder,elbow,wrist],side)=>{for(const [key,start,end]of [['upper',shoulder,elbow],['forearm',elbow,wrist]]){const part=rig.parts[key];
 const sleeve=style&&sleeves.parts[style+'-'+key];if(sleeve)clothes.push({id:style==='coat'?'coat-rig-'+key+'-'+side:'top-guard-'+(style==='hoodie'?'hoodie-arm':style),slot:style==='coat'?'coatFront':'top',src:sleeve.src,uv:sleeve.uv,box:[0,0,...sleeve.size],material:style==='coat'?c.coat:undefined,transform:affine(part.pivot,part.distal,start,end,side===1,1.05)})}
 const p=originalHands[side],w=p.box[2],h=p.box[3],direction=[wrist[0]-elbow[0],wrist[1]-elbow[1]],len=Math.hypot(...direction),reach=c.pose_profile==='sieg'&&side===1?45:70,tip=[wrist[0]+direction[0]/len*reach,wrist[1]+direction[1]/len*reach];hands.push({...p,box:[0,0,w,h],transform:affine([w/2,h-10],[w/2,15],wrist,tip,false,.85)});
 });
 const body=[{...bodies.poses[c.pose_profile].piece,...(c.coat!=='none'||['hoodie','jacke'].includes(c.top)?{clipPolygon:[[315,210],[455,210],[480,310],[480,550],[290,550],[290,310]]}:{})}],lower=s.pieces.filter(p=>['lower'].includes(p.id)||['bottom','feet'].includes(p.slot)),head=s.pieces.filter(p=>p.id==='head'||['eyes','hair','head'].includes(p.slot));
 const top=s.pieces.filter(p=>p.slot==='top').map(p=>p.id.endsWith('-up')?p:{...p,bodyClipRect:undefined,clipPolygon:[[300,210],[475,210],[485,285],[475,350],[480,550],[290,550],[300,350],[285,285]]});
 let coat=[];if(c.coat!=='none'){
 const master=art.pieces['coat-rig-body'];if(!master)return null;
 coat=[...s.pieces.filter(p=>p.slot==='coatBack'),{...master,material:c.coat}];
 if(c.coat!=='samurai'){coat[coat.length-1]=crop(coat[coat.length-1],[155,180,475,360]);coat.push(...s.pieces.filter(p=>p.slot==='coatFront'&&p.box[1]+p.box[3]>540).map(p=>crop(p,[p.box[0],540,p.box[2],p.box[1]+p.box[3]-540])))}
 }
 const pieces=[...coat.filter(p=>p.slot==='coatBack'),...head.filter(p=>p.depth==='back'),...body,...lower,...top.filter(p=>!p.id.endsWith('-up')),...coat.filter(p=>p.slot==='coatFront'),...clothes,...head.filter(p=>p.depth!=='back'),...top.filter(p=>p.id.endsWith('-up')),...hands];
 return {...s,effectsConfig:{...c,pose_profile:'guard'},pieces,ids:pieces.map(p=>p.id),config:c,topSelection:c.top==='none'?null:{bodyOcclusion:{type:'none'},requiredSources:[]},bodyKeep:null,pose:c.pose_profile};
}
function bounds(p){if(!p.transform)return p.box;const [a,b,c,d,e,f]=p.transform,[x,y,w,h]=p.box,points=[[x,y],[x+w,y],[x,y+h],[x+w,y+h]].map(([x,y])=>[a*x+c*y+e,b*x+d*y+f]),xs=points.map(p=>p[0]),ys=points.map(p=>p[1]);return[Math.min(...xs),Math.min(...ys),Math.max(...xs)-Math.min(...xs),Math.max(...ys)-Math.min(...ys)]}
window.TLPremiumPoseRig=Object.freeze({init,retarget,bounds,joints});})();
