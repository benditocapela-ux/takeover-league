// Live editor adapter. The release builder alone opts in; authoring pages stay isolated.
export async function init(){
 if(!document.querySelector('meta[name="tl-premium-character"][content="enabled"]'))return null;
 const version=document.querySelector('meta[name=tl-premium-character]').dataset.version;
 if(!/^[a-f0-9]{16}$/.test(version))return null;
 await import('./assets/premium-character/'+version+'/runtime.js');
 const P=window.TLPremiumProduction;await P.init();
 const cache=new Map(),pending=new Set(),failed=new Set(),queue=[];
 let running=false;
 const config=(c,pose)=>window.TLHolo.normalize({...c,pose_profile:pose});
 const key=c=>JSON.stringify(c);
 function remember(k,v){cache.set(k,v);const heroes=[...cache.keys()].filter(x=>x.endsWith('|'));while(heroes.length>4)cache.delete(heroes.shift());while(cache.size>128)cache.delete(cache.keys().next().value)}
 async function pump(){if(running)return;running=true;
  try{while(queue.length){const job=queue.shift();let html=null;
   try{if(!failed.has(job.configKey)){
    const result=await P.prepare(job.c);
    if(result.renderer==='anime-draft'){
     const slot=job.slot==='glove'?'hands':job.slot;
     const frame=slot?P.itemFrame(result.selection,slot):[0,0,768,1216];
     if(frame){const full=document.createElement('canvas');full.width=768;full.height=1216;
      P.draw(full.getContext('2d'),result.selection,result.images,slot||undefined);
      const output=document.createElement('canvas'),scale=slot?Math.min(1,180/Math.max(frame[2],frame[3])):1;
      output.width=Math.max(1,Math.round(frame[2]*scale));output.height=Math.max(1,Math.round(frame[3]*scale));
      output.getContext('2d').drawImage(full,...frame,0,0,output.width,output.height);
      const url=output.toDataURL('image/png');full.width=full.height=output.width=output.height=0;
      html=slot?'<img class="mb-premium-item" src="'+url+'" alt="" decoding="sync">':'<span class="mb-artpack" role="img" aria-label="Dein Boxer – Anime" data-premium-character="anime" data-artpack-pose="'+job.c.pose_profile+'"><img class="mb-artpack-img" src="'+url+'" alt="" decoding="sync"></span>';
     }
    }else if(result.reason==='load-failed')failed.add(job.configKey);
   }}catch(e){failed.add(job.configKey)}
   remember(job.key,html);pending.delete(job.key);job.done();
  }}finally{running=false}
 }
 function request(c,pose,slot,done){const normalized=config(c,pose),ck=key(normalized),k=ck+'|'+slot;
  if(failed.has(ck)||!P.resolve(normalized))return null;
  if(cache.has(k)){const value=cache.get(k);cache.delete(k);cache.set(k,value);return value}
  if(!pending.has(k)){pending.add(k);const job={c:normalized,configKey:ck,key:k,slot,done};if(slot)queue.push(job);else queue.unshift(job);pump()}
  return null;
 }
 return Object.freeze({hero:(c,p,done)=>request(c,p,'',done),item:(c,p,s,done)=>request(c,p,s,done),stats:()=>({cached:cache.size,pending:pending.size,images:P.loader.stats()})});
}
