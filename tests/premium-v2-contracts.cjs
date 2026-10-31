'use strict';
const fs=require('node:fs'),assert=require('node:assert/strict'),vm=require('node:vm'),crypto=require('node:crypto');
const {inventory,matrix}=require('../scripts/inventory-premium-v2.cjs');
assert.equal(inventory.configKeys.length,21);assert.equal(inventory.catalogue.length,58);assert.equal(inventory.bundles.length,3);assert.equal(matrix.length,1800);
for(const item of inventory.catalogue)for(const pose of inventory.domains.pose_profile)assert.ok(matrix.some(r=>r.slot===item.slot&&r.value===item.value&&r.pose===pose));
const a=JSON.parse(fs.readFileSync('tools/premium-v2/pilot-assets.json'));for(const v of Object.values(a.atlases)){const b=fs.readFileSync('tools/premium-v2/assets/'+v.file);assert.equal(b.length,v.bytes);assert.equal(crypto.createHash('sha256').update(b).digest('hex'),v.sha256)}
for(const p of Object.values(a.pieces)){assert.ok(p.uv[0]>=0&&p.uv[1]>=0&&p.uv[0]+p.uv[2]<=a.atlases[p.atlas].width&&p.uv[1]+p.uv[3]<=a.atlases[p.atlas].height);assert.deepEqual(p.uv.slice(2),p.box.slice(2),'atlas crop is unscaled')}
const q=JSON.parse(fs.readFileSync('tools/premium-v2/quality-gates.json'));assert.equal(q.productionReady,false);assert.equal(q.massProductionAllowed,false);
const ctx={window:{}};for(const file of ['takeover-mein-boxer-artpack-manifest.js','takeover-mein-boxer-modular-manifest.js'])vm.runInNewContext(fs.readFileSync(file,'utf8'),ctx);for(const m of Object.values(ctx.window))assert.ok(m.approved===false&&m.enabled===false);
assert.doesNotMatch(fs.readFileSync('mein-boxer.html','utf8'),/premium-v2|TLPremiumV2Pilot/,'production editor cannot load the laboratory');
const source=fs.readFileSync('tools/premium-v2/pilot.js','utf8')+fs.readFileSync('tools/premium-v2/index.html','utf8');assert.doesNotMatch(source,/supabase|\.rpc\(|localStorage|sessionStorage/,'no persistence or purchase interface');
const {assemble}=require('../tools/assemble-pages-site.cjs'),os=require('node:os'),path=require('node:path');const out=fs.mkdtempSync(path.join(os.tmpdir(),'premium-v2-isolation-'));const report=assemble(process.cwd(),out);assert.equal(report.artwork.copied,0);assert.equal(fs.existsSync(path.join(out,'tools/premium-v2')),false);console.log('PASS V2: complete repository inventory, atlas integrity, release exclusion, unchanged disabled manifests and explicit quality NO-GO');
