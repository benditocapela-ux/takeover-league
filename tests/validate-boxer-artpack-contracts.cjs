'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {meta,validate}=require('../scripts/validate-boxer-artpack.cjs');
const makePng=(w,h,type=6)=>{
 const b=Buffer.alloc(33);
 Buffer.from([137,80,78,71,13,10,26,10]).copy(b,0);
 b.writeUInt32BE(13,8);b.write('IHDR',12,'ascii');
 b.writeUInt32BE(w,16);b.writeUInt32BE(h,20);b[24]=8;b[25]=type;
 return b;
};
const makeWebp=(w,h,flag=0x10)=>{
 const b=Buffer.alloc(30);b.write('RIFF',0);b.writeUInt32LE(22,4);
 b.write('WEBP',8);b.write('VP8X',12);b.writeUInt32LE(10,16);
 b[20]=flag;b.writeUIntLE(w-1,24,3);b.writeUIntLE(h-1,27,3);
 return b;
};
assert.deepEqual(meta(makePng(768,1216),'asset.png'),{width:768,height:1216,alpha:true,animated:false});
assert.equal(meta(makePng(768,1216,2),'asset.png').alpha,false);
assert.deepEqual(meta(makeWebp(768,1216),'asset.webp'),{width:768,height:1216,alpha:true,animated:false});
assert.equal(meta(makeWebp(768,1216,0),'asset.webp').alpha,false);
assert.equal(meta(makeWebp(768,1216,0x12),'asset.webp').animated,true);
assert.throws(()=>meta(Buffer.from('not a real file'),'asset.webp'),/Invalid WEBP/);
const root=fs.mkdtempSync(path.join(os.tmpdir(),'takeover-artpack-'));
try{
 fs.mkdirSync(path.join(root,'body'),{recursive:true});
 fs.writeFileSync(path.join(root,'body/test.png'),makePng(768,1216));
 fs.writeFileSync(path.join(root,'body/opaque.png'),makePng(768,1216,2));
 fs.writeFileSync(path.join(root,'body/small.png'),makePng(400,500));
 const required={body:{'6':'body/test.png'},bottom:{boxer:'body/test.png'},feet:{boots:'body/test.png'},
  eyes:{braun:'body/test.png'},hands:{wraps:'body/test.png'}};
 const approved={version:1,approved:true,canvas:{width:768,height:1216},poses:{cool:required}};
 assert.equal(validate(approved,root).checked,1);
 assert.equal(validate(approved,root).maxOutfitBytes,5*33,'worst-case outfit cost counts each displayed slot');
 assert.equal(validate({...approved,approved:false},root).skipped,false,
  'draft artwork is checked before release approval');
 assert.equal(validate({...approved,approved:false,poses:{}},root).skipped,true,
  'an empty and disabled draft has no files to validate');
 assert.throws(()=>validate({...approved,approved:false,enabled:true},root),/cannot be enabled before approval/,
  'the deployment validator refuses unsafe release flags');
 assert.throws(()=>validate({...approved,poses:{cool:{...required,body:{'6':'body/small.png'}}}},root),/Wrong dimensions/);
 assert.throws(()=>validate({...approved,approved:false,poses:{cool:{...required,body:{'6':'body/small.png'}}}},root),
  /Wrong dimensions/,'draft artwork must fail dimension checks before approval');
 assert.throws(()=>validate({...approved,poses:{cool:{...required,body:{'6':'body/opaque.png'}}}},root),/transparency/);
 assert.throws(()=>validate({...approved,poses:{cool:{...required,body:{'6':'..\/escape.png'}}}},root),/Invalid asset path/);
 assert.throws(()=>validate({...approved,poses:{cool:{...required,eyes:{}}}},root),/Missing required layer group/);
 // Each asset is below the individual 2 MiB cap but the complete costume
 // must also be lightweight enough for a mobile browser.
 const slots=['coatBack','body','bottom','feet','top','eyes','hair','head','coatFront','hands'];
 const expensive={};
 for(let i=0;i<slots.length;i++){
  const name='body/heavy'+i+'.png';
  fs.writeFileSync(path.join(root,name),Buffer.concat([
   makePng(768,1216),Buffer.alloc(768*1024)
  ]));
  expensive[slots[i]]={one:name};
 }
 assert.throws(()=>validate({...approved,poses:{cool:expensive}},root),
  /Outfit exceeds mobile 6 MiB image budget/,'nine or ten art layers must have a total mobile budget');
}finally{fs.rmSync(root,{recursive:true,force:true});}
console.log('PASS: artpack checks dimensions, transparency flags, size, safe paths and manifest completeness');
