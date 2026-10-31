'use strict';
// Shared by the real Pages workflow and isolated release-safety tests.
// No network, publication, flag mutation or deletion. Require fresh staging so
// a second build cannot accidentally retain previously copied draft media.
const fs=require('node:fs'),path=require('node:path');
const {loadManifest,publish}=require('./publish-boxer-artpack.cjs');
const EXTENSIONS=new Set(['.html','.js','.css','.svg','.png','.woff','.webmanifest']);
const PREVIEWS=new Set(['challenges-v2-preview.html','duels-v2-preview.html','league2-preview.html']);
function assemble(sourceRoot,destinationRoot){
 const source=fs.realpathSync(sourceRoot),destination=path.resolve(destinationRoot);
 if(destination===source)throw Error('Staging must differ from the repository');
 fs.mkdirSync(destination,{recursive:true});
 if(fs.lstatSync(destination).isSymbolicLink()||fs.readdirSync(destination).length)
  throw Error('Pages staging must be an empty, non-symlink directory');
 let rootFiles=0,avatarFiles=0;
 for(const entry of fs.readdirSync(source,{withFileTypes:true})){
  if(!entry.isFile()||!EXTENSIONS.has(path.extname(entry.name))||PREVIEWS.has(entry.name))continue;
  fs.copyFileSync(path.join(source,entry.name),path.join(destination,entry.name));rootFiles++;
 }
 function avatars(from,to){
  fs.mkdirSync(to,{recursive:true});
  for(const entry of fs.readdirSync(from,{withFileTypes:true})){
   if(entry.isSymbolicLink())throw Error('Avatar symlinks are not release assets');
   const src=path.join(from,entry.name),dst=path.join(to,entry.name);
   if(entry.isDirectory())avatars(src,dst);
   else if(entry.isFile()){fs.copyFileSync(src,dst);avatarFiles++}
  }
 }
 avatars(path.join(source,'avatars'),path.join(destination,'avatars'));
 const artwork=publish(loadManifest(path.join(source,'takeover-mein-boxer-artpack-manifest.js')),
  path.join(source,'assets/boxer-artpacks/v1'),destination);
 return {rootFiles,avatarFiles,artwork};
}
if(require.main===module)console.log(JSON.stringify(assemble(process.cwd(),process.argv[2]||'_site')));
module.exports={assemble};
