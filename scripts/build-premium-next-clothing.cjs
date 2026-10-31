'use strict';
// Reproducible crop/registration export. No generative redraw, colour change or source mutation.
const fs=require('fs'),path=require('path'),crypto=require('crypto'),assert=require('assert/strict');
const {createCanvas,loadImage}=require(process.env.CANVAS_MODULE||'@napi-rs/canvas');
const root=path.resolve(__dirname,'../tools/premium-v2'),manifest=JSON.parse(fs.readFileSync(path.join(root,'production-art/manifest.json'))),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const sharedHood=['src','uv','box','sha256','bytes'];for(const key of sharedHood)assert.deepEqual(manifest.pieces['top-cool-hoodie-up'][key],manifest.pieces['top-guard-hoodie-up'][key],'exact shared raised hood: '+key);
(async()=>{for(const id of ['top-cool-hoodie-torso','top-guard-jacke']){const p=manifest.pieces[id],source=path.join(root,p.source);assert.equal(sha(fs.readFileSync(source)),p.sourceSha256,'retained source hash');const im=await loadImage(source),c=createCanvas(p.uv[2],p.uv[3]);c.getContext('2d').drawImage(im,...p.sourceCrop,0,0,c.width,c.height);const bytes=c.toBuffer('image/png');assert.equal(sha(bytes),p.sha256,'reproducible registered export');assert.equal(bytes.length,p.bytes);if(process.argv.includes('--write'))fs.writeFileSync(path.join(root,p.src),bytes);console.log('PASS',id,p.sha256)}})().catch(e=>{console.error(e);process.exitCode=1});
