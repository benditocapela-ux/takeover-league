'use strict';
/* Report the exact first-wave anime asset slots needed for Takeover League.
 * This is a planning report, not an approval. It reads the actual Holo keys.
 * Run: node scripts/report-boxer-artpack.cjs [--json]
 */
const fs=require('node:fs'),vm=require('node:vm');
const runScript=(file,ctx)=>vm.runInNewContext(fs.readFileSync(file,'utf8'),ctx,{timeout:2000});
function requirements(H,pose='cool'){
 const def=H.normalize({...H.DEF,tone:6,hair:'afro',hc:'schwarz',eye:'braun',
  top:'shirt',topc:'schwarz',bottom:'boxer',bottomc:'schwarz',
  feet:'boots',feetc:'schwarz',coat:'samurai',hands:'wraps'});
 const first=[
  ['coatBack','samurai'],['body','6'],['bottom','boxer/schwarz'],
  ['feet','boots/schwarz'],['top','shirt/schwarz'],['eyes','braun'],
  ['hair','afro/schwarz'],['coatFront','samurai'],['hands','wraps']
 ];
 const expand=[
  ...H.TONES.map((_,i)=>['body',String(i)]),
  ...H.HAIR_KEYS.map(h=>['hair',h+'/schwarz']),
  ...Object.keys(H.EYE).map(k=>['eyes',k]),
  ...['tank','shirt','hoodie','jacke'].map(k=>['top',k+'/schwarz'+(k==='hoodie'?'/down':'')]),
  ['top','hoodie/schwarz/up'],
  ...['boxer','kurz','jogger','track'].map(k=>['bottom',k+'/schwarz']),
  ...['boots','sneaker'].map(k=>['feet',k+'/schwarz']),
  ...['cap','band','hijab'].map(k=>['head',k+'/schwarz']),
  ['hands','wraps'],['hands','gloves/schwarzgold'],
  ['coatBack','samurai'],['coatFront','samurai']
 ];
 const dedupe=items=>[...new Map(items.map(([slot,key])=>[slot+':'+key,{slot,key}])).values()];
 return {pose,reference:def,first:dedupe(first),expansion:dedupe(expand)};
}
function report(manifest,H){
 const wants=requirements(H);
 const group=manifest&&manifest.poses&&manifest.poses[wants.pose]||{};
 const tally=items=>{
  const list=items.map(({slot,key})=>({
   slot,key,
   path:group[slot]&&Object.prototype.hasOwnProperty.call(group[slot],key)?group[slot][key]:null
  }));
  return {total:list.length,present:list.filter(x=>typeof x.path==='string'&&x.path.length>0).length,
   missing:list.filter(x=>!x.path)};
 };
 return {approved:manifest?.approved===true,pose:wants.pose,
  reference:tally(wants.first),expansion:tally(wants.expansion),
  catalogue:{skinTones:H.TONES.length,hairstyles:H.HAIR_KEYS.length,eyeColours:Object.keys(H.EYE).length},
  note:'A listed file path is not proof of image dimensions, transparency or visual alignment. Run validate-boxer-artpack.cjs before approval.'};
}
if(require.main===module){
 const ctx={window:{}};
 runScript('takeover-holo.js',ctx);
 runScript('takeover-mein-boxer-artpack-manifest.js',ctx);
 const r=report(ctx.window.TLBoxerArtPackManifest,ctx.window.TLHolo);
 if(process.argv.includes('--json'))console.log(JSON.stringify(r,null,2));
 else{
  console.log('TAKEOVER · Premium anime art-pack coverage · pose '+r.pose);
  console.log('Freigabe: '+(r.approved?'ja':'nein (SVG-Fallback aktiv)'));
  console.log('Referenz-Boxer: '+r.reference.present+'/'+r.reference.total+' Ebenen zugeordnet');
  console.log('Erste Ausbauwelle: '+r.expansion.present+'/'+r.expansion.total+' Varianten zugeordnet');
  console.log('Editor bietet '+r.catalogue.skinTones+' Hauttöne, '+r.catalogue.hairstyles+
   ' Frisuren und '+r.catalogue.eyeColours+' Augenfarben.');
  for(const item of r.reference.missing)console.log('  FEHLT '+r.pose+'/'+item.slot+'/'+item.key);
  console.log('Hinweis: '+r.note);
 }
}
module.exports={requirements,report};
