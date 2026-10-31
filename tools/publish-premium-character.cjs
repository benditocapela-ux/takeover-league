'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const modules=['pilot.js','streaming.js','materials.js','headwear/headwear.js','tops/tops.js','effects.js','headwear-hijab/hijab.js','long-hair/long-hair.js','production.js'];
const manifests=['pilot-assets.json','streaming-assets.json','production-art/manifest.json','headwear/manifest.json','tops/manifest.json','hair-expansion/manifest.json','wraps/manifest.json','headwear-hijab/manifest.json','long-hair/manifest.json'];
function publish(source,destination){
 const release=JSON.parse(fs.readFileSync(path.join(source,'tools/premium-character-release.json')));
 if(!release.enabled)return {enabled:false,files:0};
 if(release.deploymentAuthorized!==true)throw Error('Premium deployment not authorized');
 const root=path.join(source,'tools/premium-v2');
 const files=new Map(),json=new Map();
 function walk(v){if(typeof v==='string'&&/\.png$/.test(v)){
  let src=path.resolve(root,v);if(!fs.existsSync(src))src=path.resolve(root,'assets',v);
  const real=fs.realpathSync(src),local=real.startsWith(fs.realpathSync(root)+path.sep),legacy=real.startsWith(fs.realpathSync(path.join(source,'assets'))+path.sep);
  if(!local&&!legacy)throw Error('Asset outside approved sources '+v);
  const name=(local?path.relative(root,real):'legacy/'+path.relative(path.join(source,'assets'),real)).replace(/\\/g,'/');files.set(name,real);return name;
 }if(Array.isArray(v))return v.map(walk);if(v&&typeof v==='object')return Object.fromEntries(Object.entries(v).map(([k,x])=>[k,['source','sources','provenance'].includes(k)?x:walk(x)]));return v}
 for(const m of manifests)json.set(m,walk(JSON.parse(fs.readFileSync(path.join(root,m)))));
 // The evaluated renderer is unchanged. Only its two relative network roots
 // are bound to the release directory; no authoring pages are shipped.
 let bundle='';
 for(const file of modules){let code=fs.readFileSync(path.join(root,file),'utf8');
  if(file==='streaming.js'){
   const from='new URL(src, location.href)';if(!code.includes(from))throw Error('Streaming root contract changed');
   code=code.replace(from,"new URL(src, new URL('./assets/premium-character/'+document.querySelector('meta[name=tl-premium-character]').dataset.version+'/', document.baseURI))");
  }
  if(file==='production.js')code="{const fetch=(url)=>window.fetch(new URL(url,new URL('./assets/premium-character/'+document.querySelector('meta[name=tl-premium-character]').dataset.version+'/',document.baseURI)));\n"+code+'\n}';
  bundle+='\n'+code;
 }
 const hash=crypto.createHash('sha256').update(bundle).update(JSON.stringify([...json]));for(const src of files.values())hash.update(fs.readFileSync(src));
 const version=hash.digest('hex').slice(0,16),out=path.join(destination,'assets/premium-character',version);
 fs.mkdirSync(out,{recursive:true});
 for(const [file,src] of files){const dest=path.join(out,file);fs.mkdirSync(path.dirname(dest),{recursive:true});fs.copyFileSync(src,dest)}
 for(const [file,data] of json){const dest=path.join(out,file);fs.mkdirSync(path.dirname(dest),{recursive:true});fs.writeFileSync(dest,JSON.stringify(data))}
 fs.writeFileSync(path.join(out,'runtime.js'),bundle);
 fs.writeFileSync(path.join(out,'release.json'),JSON.stringify(release));
 const page=path.join(destination,'mein-boxer.html');
 fs.writeFileSync(page,fs.readFileSync(page,'utf8').replace('</head>','<meta name="tl-premium-character" content="enabled" data-version="'+version+'"></head>'));
 return {enabled:true,version,files:files.size+json.size+2};
}
module.exports={publish,modules,manifests};
