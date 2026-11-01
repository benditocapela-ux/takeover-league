'use strict';
// Shared bone coordinates only. Skin is pose-specific; no stretched torso fallback.
const fs=require('fs'),path=require('path');
const root=path.resolve(__dirname,'../tools/premium-v2');
const rig=JSON.parse(fs.readFileSync(path.join(root,'rig/manifest.json')));
fs.writeFileSync(path.join(root,'completion/pose-assets.json'),JSON.stringify({version:1,enabled:false,parts:Object.fromEntries(['upper','forearm'].map(k=>[k,{pivot:rig.parts[k].pivot,distal:rig.parts[k].distal}]))},null,2)+'\n');
