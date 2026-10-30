'use strict';
/* Import the eight exact approved-reference cool-pose PNGs; never enable production.
 * Usage: node scripts/import-original-cool-artpack.cjs /path/to/original.zip [--dry-run]
 * Requires system unzip, no npm dependencies.
 */
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),
 {execFileSync}=require('node:child_process'),vm=require('node:vm');
const SHA=Object.freeze({
 coatBack:'bf5cee68e8cc19d3e7444c01882a3ea3019a6320b87270ec8d51e1197bf26e4a',
 body:'5991018fc9469342b91dbdd93dcc4ff618a70c66754cb4b3cc23779fb724bed3',
 bottom:'ca02a420022e0ecbfe79d64e1c326e119744d62f51a594c5fbd095c65c5af6f1',
 feet:'05e8cf320330df8dfb541d0f900f05121142dee8a91259093880d0e9ef404dd7',
 eyes:'a9a0a97a7a89abbdee6add40c1c3bff104e97f630c30591cf3a2c7905d72f8e8',
 hair:'7c7b3cf7cc007b5394ff00000326f53eb26554f6711e2d2f128e10f49ee1f0d4',
 coatFront:'aef43b7b888d4c591318682077d2ea5ed0f1562db5c3e1d195b131817a67cfac',
 hands:'feddacf8e8727c04e3ade21502d988e541711151a763fcffcea5c36207f45d68'
});
const NAMES=Object.freeze(Object.keys(SHA)),PREFIX='assets/boxer-artpacks/v1/cool/',MAX_FILE=2*1024*1024;
const digest=d=>crypto.createHash('sha256').update(d).digest('hex');
function readAll(zip,expected=SHA){
 const listing=execFileSync('unzip',['-Z1',zip],{encoding:'utf8',maxBuffer:2*1024*1024})
  .split(/\r?\n/).filter(Boolean);
 const found=new Map();
 for(const name of NAMES){
  const entries=[PREFIX+name+'.png',name+'.png'].filter(x=>listing.includes(x));
  if(entries.length!==1)throw Error('Missing or ambiguous PNG '+name+'.png');
  const data=execFileSync('unzip',['-p',zip,entries[0]],{maxBuffer:MAX_FILE+1024});
  if(data.length<33||data.length>MAX_FILE)throw Error('Invalid PNG size: '+name);
  if(!data.subarray(0,8).equals(Buffer.from('89504e470d0a1a0a','hex'))||
   data.toString('ascii',12,16)!=='IHDR'||data.readUInt32BE(16)!==768||
   data.readUInt32BE(20)!==1216||data[25]!==6)
   throw Error('Layer must be 768x1216 RGBA PNG: '+name);
  if(digest(data)!==expected[name])throw Error('SHA-256 reference mismatch: '+name);
  found.set(name,data);
 }
 return found;
}
function manifestText(){
 const m={version:1,approved:false,enabled:false,canvas:{width:768,height:1216},
  poses:{cool:{
   coatBack:{samurai:'cool/coatback.png'},body:{'6':'cool/body.png'},
   bottom:{'boxer/schwarz':'cool/bottom.png'},
   feet:{'boots/schwarz':'cool/feet.png'},eyes:{braun:'cool/eyes.png'},
   hair:{'afro/schwarz':'cool/hair.png'},coatFront:{samurai:'cool/coatfront.png'},
   hands:{wraps:'cool/hands.png'}
  }}};
 return "/* Original cool reference only; NOT approved. */\n(function(){'use strict';window.TLBoxerArtPackManifest=Object.freeze("+
  JSON.stringify(m,null,2)+");})();\n";
}
function importPack(zip,root=process.cwd(),opts={}){
 const pack=readAll(zip,opts.expected||SHA); // all hashes before any mutation
 const manifestFile=path.join(root,'takeover-mein-boxer-artpack-manifest.js');
 const ctx={window:{}};
 vm.runInNewContext(fs.readFileSync(manifestFile,'utf8'),ctx,{timeout:1000});
 const old=ctx.window.TLBoxerArtPackManifest;
 if(!old||old.approved!==false||old.enabled!==false)
  throw Error('Expected empty, unapproved, disabled artpack manifest');
 const known=Object.keys(old.poses||{}).length!==0;
 if(known&&fs.readFileSync(manifestFile,'utf8')!==manifestText())
  throw Error('Existing draft manifest differs from exact original cool import');
 const dest=path.join(root,PREFIX);
 for(const [name,data] of pack){
  const file=path.join(dest,name.toLowerCase()+'.png');
  if(fs.existsSync(file)&&digest(fs.readFileSync(file))!==digest(data))
   throw Error('Different artwork already exists: '+file);
 }
 const bytes=[...pack.values()].reduce((s,d)=>s+d.length,0);
 if(!opts.dryRun){
  fs.mkdirSync(dest,{recursive:true});
  for(const [name,data] of pack)fs.writeFileSync(path.join(dest,name.toLowerCase()+'.png'),data);
  fs.writeFileSync(manifestFile,manifestText());
 }
 return {files:pack.size,bytes,dryRun:!!opts.dryRun,approved:false,enabled:false};
}
if(require.main===module){
 try{
  const zip=process.argv[2];
  if(!zip||!zip.toLowerCase().endsWith('.zip'))
   throw Error('Usage: node scripts/import-original-cool-artpack.cjs original.zip [--dry-run]');
  const r=importPack(path.resolve(zip),process.cwd(),
   {dryRun:process.argv.includes('--dry-run')});
  console.log((r.dryRun?'CHECK':'IMPORTED')+': '+r.files+' verified images, '+
   Math.round(r.bytes/1024)+' KiB; approved=false, enabled=false');
  if(!r.dryRun)console.log('Next: node scripts/validate-boxer-artpack.cjs');
 }catch(e){console.error('FAIL: '+e.message);process.exitCode=1}
}
module.exports={NAMES,SHA,PREFIX,digest,readAll,manifestText,importPack};
