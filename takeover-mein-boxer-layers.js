/* Takeover League · Mein Boxer · Layered 2.5D art kit (preview-only).
 * Layers follow the active boxer config and are real vector geometry:
 * material texture -> garment stitching -> hair highlights -> ambient edge.
 * No imported images, no network fetch, no SVG <image> or HTML from users.
 */
(function(){
'use strict';
const color=(v)=>/^#[0-9a-fA-F]{6}$/.test(v||'')?v:'#f2c14e';
function render(cfg,paint){
 const id=paint.id,top=paint.top,bottom=paint.bottom,feet=paint.feet,coat=paint.coat;
 const hasTop=cfg.top!=='none'&&!!paint.paths.top;
 const hasCoat=cfg.coat!=='none'&&!!paint.paths.coat;
 const hasLongPants=['jogger','track'].includes(cfg.bottom);
 const hairColor=color(paint.hair[2]);
 const gold=color(coat?coat.a:top[2]);
 const ink='#080d18';
 const prefix='tl-layer-';
 const defs=[
 '<linearGradient id="'+id+'-cloth" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#fff9d9" stop-opacity=".23"/><stop offset=".27" stop-color="#fff" stop-opacity="0"/><stop offset=".62" stop-color="#000" stop-opacity=".07"/><stop offset="1" stop-color="#000" stop-opacity=".43"/></linearGradient>',
 '<linearGradient id="'+id+'-metal" x1="0" y1="0" x2="1" y2=".8"><stop offset="0" stop-color="#fff6ca"/><stop offset=".2" stop-color="'+gold+'"/><stop offset=".52" stop-color="#75501c"/><stop offset=".75" stop-color="'+gold+'"/><stop offset="1" stop-color="#fff1bc"/></linearGradient>',
 '<linearGradient id="'+id+'-skin" x1="0" y1="0" x2=".92" y2="1"><stop offset="0" stop-color="#fff8dc" stop-opacity=".27"/><stop offset=".4" stop-color="'+color(paint.skin)+'" stop-opacity=".08"/><stop offset="1" stop-color="'+color(paint.shade)+'" stop-opacity=".41"/></linearGradient>',
 '<linearGradient id="'+id+'-hair" x1="0" y1="0" x2="1" y2=".9"><stop offset="0" stop-color="'+hairColor+'" stop-opacity=".35"/><stop offset=".5" stop-color="#fff" stop-opacity=".07"/><stop offset="1" stop-color="#000" stop-opacity=".25"/></linearGradient>',
 '<clipPath id="'+id+'-bottom"><path d="'+paint.paths.bottom+'"/></clipPath>',
 '<clipPath id="'+id+'-feet"><path d="'+paint.paths.feet+'"/></clipPath>'
 ];
 if(hasTop)defs.push('<clipPath id="'+id+'-top"><path d="'+paint.paths.top+'"/></clipPath>');
 if(hasCoat)defs.push('<clipPath id="'+id+'-coat"><path d="'+paint.paths.coat+'"/></clipPath>');
 if(paint.paths.hair&&cfg.head!=='hijab'&&!cfg.hood)defs.push('<clipPath id="'+id+'-hairclip"><path d="'+paint.paths.hair+'"/></clipPath>');
 const outfit=[];
 if(hasTop)outfit.push('<g class="'+prefix+'shirt" clip-path="url(#'+id+'-top)">'+
    '<rect x="65" y="90" width="110" height="126" fill="url(#'+id+'-cloth)"/>'+
    '<path d="M92 111 Q98 122 97 143 M146 111 Q140 122 143 143 M97 166 Q119 173 143 167" fill="none" stroke="#fff" stroke-opacity=".14" stroke-width="2"/>'+
    '<path d="M98 120 Q105 125 110 123 M131 123 Q138 125 143 120" fill="none" stroke="'+color(top[2])+'" stroke-opacity=".34" stroke-width="1.3"/>'+
   '</g>');
 outfit.push('<g class="'+prefix+'bottom" clip-path="url(#'+id+'-bottom)">'+
   '<rect x="72" y="170" width="100" height="154" fill="url(#'+id+'-cloth)"/>'+
   '<path d="M83 182 L79 244 M158 182 L162 244" fill="none" stroke="url(#'+id+'-metal)" stroke-width="1.8" opacity=".75"/>'+
   '<path d="M93 195 Q120 202 146 195" fill="none" stroke="#fff" stroke-width="1.5" stroke-opacity=".12"/>'+
   (hasLongPants?'<path d="M89 245 L89 306 M151 245 L151 306" fill="none" stroke="'+color(bottom[2])+'" stroke-width="1.4" opacity=".6"/>':'')+
   '</g>');
 outfit.push('<g class="'+prefix+'shoes" clip-path="url(#'+id+'-feet)">'+
   '<rect x="68" y="288" width="102" height="64" fill="url(#'+id+'-cloth)"/>'+
   '<path d="M85 306 L106 306 M134 306 L154 306 M83 325 L107 325 M132 325 L157 325" stroke="url(#'+id+'-metal)" stroke-width="1.6" opacity=".87" stroke-linecap="round"/>'+
   '<path d="M77 341 L118 341 M123 341 L165 341" fill="none" stroke="'+color(feet[2])+'" stroke-width="2" stroke-opacity=".75"/>'+
   '</g>');
 if(hasCoat)outfit.push('<g class="'+prefix+'coat" clip-path="url(#'+id+'-coat)">'+
  '<rect x="55" y="89" width="132" height="218" fill="url(#'+id+'-cloth)"/>'+
  '<path d="M77 121 Q84 130 81 164 L81 257 M164 121 Q157 132 159 164 L160 257" fill="none" stroke="#fff7d3" stroke-opacity=".22" stroke-width="2.4"/>'+
  '<path d="M76 272 L96 278 M144 278 L164 272" fill="none" stroke="url(#'+id+'-metal)" stroke-width="2.3"/>'+
  '<path d="M84 197 L92 192 L100 197 M156 197 L148 192 L140 197" fill="none" stroke="'+gold+'" stroke-width="1.4" opacity=".7"/>'+
  '</g>');
 // Hair is rendered inside the original head transform; retain original style keys.
 const hair=(paint.paths.hair&&cfg.head!=='hijab'&&!cfg.hood)?'<g class="'+prefix+'hair" clip-path="url(#'+id+'-hairclip)">'+
   '<rect x="36" y="4" width="130" height="110" fill="url(#'+id+'-hair)"/>'+
   '<path d="M61 57 Q77 35 96 41 M101 35 Q117 32 136 52 M72 74 Q94 58 119 64" stroke="'+hairColor+'" stroke-width="2.3" opacity=".3" fill="none"/>'+
   '</g>':'';
 const ambient='<g class="'+prefix+'ambient" aria-hidden="true">'+
   '<path d="M88 99 Q98 94 104 100 M136 100 Q145 94 154 99" stroke="#fff1c0" stroke-width="1.8" stroke-opacity=".23" fill="none"/>'+
   '<ellipse cx="120" cy="343" rx="49" ry="5" fill="'+gold+'" opacity=".09"/>'+
   '</g>';
 return {defs:defs.join(''),outfit:'<g class="'+prefix+'outfit">'+outfit.join('')+'</g>'+ambient,hair};
}
window.TLStudioLayers=Object.freeze({render,version:1});
})();