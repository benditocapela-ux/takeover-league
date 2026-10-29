/* Takeover League · Boxer-Holo (Etappe 9).
 * Zeichnet den eigenen Boxer als SVG: Körper, Frisuren für alle Haartypen, Kleidung, Mäntel, Auren, Spezial-Augen,
 * Hintergründe und Posen. Alle Werte gehen nur als Schlüssel in feste Tabellen; Unbekanntes fällt auf den Standard zurück.
 * Es wird nie freier Text oder eine Farbe aus Daten in das SVG geschrieben.
 */
(function(){
'use strict';
const INK='#1a1020';
const DEF={tone:2,hair:'kurz_glatt',hc:'schwarz',eye:'braun',eyefx:'none',head:'none',headc:'schwarz',top:'none',hood:false,topc:'grau',bottom:'boxer',bottomc:'rot',hands:'wraps',glove:'rot',feet:'boots',feetc:'weiss',coat:'none',aura:'none',scene:'holo',pose_profile:'guard',pose_card:'guard'};
const TONES=[['#fbe3d2','#e8b8a2'],['#f6d0b4','#e0a98c'],['#eab995','#cc9270'],['#d39b72','#b07650'],['#b07a52','#8c5a38'],['#8a5638','#683e25'],['#6a3f28','#4e2c1a'],['#4a2a1b','#341c11']];
const HC={schwarz:['#221c26','#0e0a12','#5d4f72'],braun:['#5a3420','#2e180c','#a8714a'],dunkelbraun:['#3a2216','#1c0f08','#7a5038'],blond:['#e8c46a','#b8913a','#fff0b8'],rot:['#b8322a','#6a1410','#f08a6a'],silber:['#d8dce8','#8e98b4','#ffffff'],blau:['#2f6bff','#12256e','#9cc0ff'],pink:['#ff7ac0','#a3286a','#ffd0ea']};
const EYE={braun:['#7a4a22','#2a1408','#c89a6a'],hasel:['#9a7a32','#3a2a08','#e0c88a'],gruen:['#3a9a5a','#0b4a26','#b8f0c8'],blau:['#3a8ad8','#0b2a5e','#c8e4ff'],grau:['#8a96a8','#2e3644','#e0e6ee'],gold:['#f2c14e','#6e4a00','#fff1b8'],orange:['#ff6a2a','#7a1606','#ffd27a'],violett:['#9b5cff','#2e1166','#e2c8ff']};
const EFX={kristall:['#9ff0ff','#0b4a6e','#ffffff','#4fd8ff'],glut:['#ff3b2f','#3a0604','#ffb03a','#ffd23a'],stern:['#ffe14f','#6e4a00','#fff8c8','#ffffff'],mond:['#c8c2ff','#1c1450','#ffffff','#9b5cff']};
const CL={schwarz:['#24222c','#0e0d12','#f2c14e'],weiss:['#eef0f5','#b8bfcc','#c0162f'],grau:['#7a8194','#4a5062','#eef0f5'],rot:['#c0162f','#6e0a1a','#ffffff'],blau:['#1f4fc8','#0e2468','#ffffff'],gruen:['#1f8a5a','#0c4a2e','#ffffff'],lila:['#6a2bd6','#3a127a','#ffffff'],gold:['#f2c14e','#a4781c','#24222c']};
const GL={rot:['#e0263a','#8e0f1e','#f6f2ea'],weiss:['#f4f4f6','#b8bfcc','#c0162f'],schwarzgold:['#2a2830','#0c0b10','#f2c14e'],eisblau:['#4fd8ff','#1a7aa8','#ffffff'],glut:['#ff6a1f','#a3220f','#ffd23a']};
const LABEL={
 hc:{schwarz:'Schwarz',braun:'Braun',dunkelbraun:'Dunkelbraun',blond:'Blond',rot:'Rot',silber:'Silber',blau:'Blau',pink:'Pink'},
 eye:{braun:'Braun',hasel:'Haselnuss',gruen:'Grün',blau:'Blau',grau:'Grau',gold:'Gold',orange:'Orange',violett:'Violett'},
 col:{schwarz:'Schwarz',weiss:'Weiss',grau:'Grau',rot:'Rot',blau:'Blau',gruen:'Grün',lila:'Lila',gold:'Gold'}
};
// Hilfen für Frisuren (Kopf-Koordinaten 0–200, Gesicht 62–138 × 46–158)
const f1=n=>Math.round(n*10)/10;
function bumpy(cx,cy,rx,ry,n,amp){
 let d='';for(let i=0;i<=n;i++){const a=Math.PI*2*i/n-Math.PI/2,x=cx+Math.cos(a)*rx,y=cy+Math.sin(a)*ry;
  if(!i){d='M'+f1(x)+' '+f1(y);continue}
  const m=a-Math.PI/n,qx=cx+Math.cos(m)*rx*(1+amp),qy=cy+Math.sin(m)*ry*(1+amp);d+=' Q'+f1(qx)+' '+f1(qy)+' '+f1(x)+' '+f1(y)}
 return d+'Z';
}
const circ=(x,y,r)=>'M'+f1(x-r)+' '+f1(y)+' a'+r+' '+r+' 0 1 0 '+f1(2*r)+' 0 a'+r+' '+r+' 0 1 0 '+f1(-2*r)+' 0Z';
function arcCircles(cx,cy,rx,ry,a0,a1,n,r){let d='';for(let i=0;i<n;i++){const a=(a0+(a1-a0)*i/(n-1))*Math.PI/180;d+=circ(cx+Math.cos(a)*rx,cy+Math.sin(a)*ry,r)}return d}
function strands(xs,y0,y1,bend){return xs.map((x,i)=>{const s=(i%2?1:-1)*bend;return 'M'+x+' '+y0[i%y0.length]+' C'+(x+s)+' '+f1(y0[i%y0.length]+(y1-y0[i%y0.length])*.35)+' '+(x-s)+' '+f1(y0[i%y0.length]+(y1-y0[i%y0.length])*.7)+' '+(x+s*.5)+' '+(y1+(i%3)*6)}).join(' ')}
const CAP='M60 94 C58 58 80 42 100 42 C120 42 142 58 140 94 C132 72 118 62 100 62 C82 62 68 72 60 94Z';
const HAIR={
 kurz_glatt:{back:'M60 96 C56 58 78 42 100 42 C124 42 146 58 140 96 C134 74 120 62 100 62 C80 62 66 74 60 96Z',front:'M60 94 C58 60 80 44 104 44 C128 44 144 60 140 92 L134 76 C124 68 110 64 96 66 C84 70 74 80 68 98 L64 100Z',hi:'M84 52 C96 46 116 46 128 54 L124 57 C112 51 98 51 87 55Z'},
 stachel:{back:'M54 102 L36 74 L56 76 L44 42 L70 56 L70 22 L92 44 L102 10 L114 40 L136 20 L134 52 L160 42 L146 74 L166 80 L144 104 C144 70 124 50 100 50 C76 50 56 70 54 102Z',front:'M58 98 C58 64 78 48 100 48 C124 48 142 64 142 98 L134 78 L130 100 L120 70 L112 96 L102 64 L94 94 L84 68 L78 98 L70 76 L64 104Z',hi:'M76 62 C86 54 104 52 118 56 L114 60 C102 57 90 59 80 66Z M86 72 L90 60 L93 74Z M110 68 L115 58 L117 72Z'},
 lang_glatt:{back:'M50 100 C46 56 74 36 100 36 C128 36 156 56 150 100 C156 140 160 170 158 196 L138 176 L134 204 L116 182 L100 210 L84 182 L66 204 L62 176 L42 196 C40 170 44 140 50 100Z',front:'M58 104 C54 62 78 42 100 42 C126 42 148 62 142 104 L136 84 L130 108 L122 76 L112 100 L106 70 L96 98 L90 72 L80 102 L74 82 L66 112Z',front2:'M60 96 L53 158 L64 138 L67 112Z M140 96 L147 158 L136 138 L133 112Z',hi:'M72 64 C86 52 112 50 128 58 L124 63 C110 57 90 58 76 68Z'},
 undercut:{back:'M62 92 C60 62 80 46 100 46 C120 46 140 62 138 92 C132 76 120 68 100 68 C80 68 68 76 62 92Z',backOpacity:.55,front:'M64 84 C60 48 92 28 124 36 C146 42 154 62 140 84 L134 66 L124 80 L120 60 L108 76 L104 58 L94 74 L88 58 L78 78 L72 64Z',hi:'M90 40 C104 34 122 36 134 44 L130 48 C118 41 104 40 92 45Z'},
 buzz:{back:'M62 90 C60 58 80 44 100 44 C120 44 140 58 138 90 C130 72 118 64 100 64 C82 64 70 72 62 90Z',backOpacity:.8,hi:'M84 50 C94 46 108 46 118 50 L116 53 C106 50 94 50 86 53Z'},
 glatze:{hi:'M80 56 C88 49 104 48 116 52 L113 56 C104 53 92 53 84 59Z',hiSkin:true},
 dutts:{back:circ(69,44,17)+' '+circ(131,44,17)+' M60 96 C58 60 80 46 100 46 C120 46 142 60 140 96 C130 76 116 66 100 66 C84 66 70 76 60 96Z',front:'M60 96 C58 64 80 50 100 50 C122 50 142 64 140 96 L132 80 L124 98 L114 74 L104 92 L96 72 L86 94 L76 76 L68 100Z',hi:'M62 40 C66 34 74 32 80 34 L78 37 C73 36 68 38 65 42Z M120 34 C126 32 134 34 138 40 L135 42 C132 38 127 36 122 37Z'},
 zopf:{back:CAP+' M134 66 C164 70 178 108 166 152 C160 130 150 112 136 98Z',front:'M62 90 C62 60 82 48 100 48 C120 48 138 60 138 90 C128 72 114 66 100 66 C86 66 72 72 62 90Z',front2:circ(140,70,6),hi:'M80 56 C92 50 110 50 122 56 L119 59 C108 54 93 54 83 59Z M148 96 C154 110 156 124 154 138'},
 bob:{back:'M56 120 C46 60 76 40 100 40 C124 40 154 60 144 120 C140 132 130 134 126 128 L128 96 L72 96 L74 128 C70 134 60 132 56 120Z',front:'M62 96 C60 60 80 46 100 46 C120 46 140 60 138 96 L130 94 L126 84 L118 94 L110 84 L100 94 L90 84 L82 94 L74 84 L70 96Z',hi:'M74 60 C88 50 112 50 126 58 L123 62 C110 55 90 55 77 64Z'},
 wellig:{back:'M52 100 C46 58 74 38 100 38 C126 38 154 58 148 100 C156 116 146 128 152 144 C156 160 142 168 140 176 C130 168 136 156 132 146 L68 146 C64 156 70 168 60 176 C58 168 44 160 48 144 C54 128 44 116 52 100Z',front:'M60 100 C58 62 80 44 100 44 C124 44 144 62 140 100 C136 86 128 80 120 84 C112 72 100 70 92 78 C84 72 72 76 68 90 C64 92 62 96 60 100Z',hi:'M72 62 C86 50 112 48 128 58 L124 62 C110 54 90 54 76 66Z'},
 locken:{back:'M58 100 C54 60 78 40 100 40 C122 40 146 60 142 100 C134 80 120 70 100 70 C80 70 66 80 58 100Z '+arcCircles(100,84,46,44,160,380,13,13),front:circ(76,66,10)+' '+circ(90,58,11)+' '+circ(106,57,11)+' '+circ(121,63,10)+' '+circ(132,74,8)+' '+circ(68,78,8),tex:'M72 62 q4 -4 7 0 M88 54 q4 -4 7 0 M104 53 q4 -4 7 0 M118 60 q4 -4 7 0 M50 90 q4 -4 7 0 M144 88 q4 -4 7 0',hi:''},
 afro:{back:bumpy(100,72,68,60,28,.07),front:'M62 94 C62 72 80 62 100 62 C120 62 138 72 138 94 C130 82 116 76 100 76 C84 76 70 82 62 94Z',tex:'M66 36 q4 -4 8 0 M92 22 q4 -4 8 0 M118 26 q4 -4 8 0 M144 42 q4 -4 8 0 M44 66 q4 -4 8 0 M150 70 q4 -4 8 0 M78 48 q4 -4 8 0 M104 40 q4 -4 8 0 M128 48 q4 -4 8 0 M40 96 q4 -4 8 0 M152 98 q4 -4 8 0',hi:'M70 30 C84 20 112 18 130 26 L126 30 C110 24 88 25 74 34Z'},
 afro_puffs:{back:bumpy(64,44,26,24,14,.08)+' '+bumpy(136,44,26,24,14,.08)+' '+CAP,tex:'M100 44 L100 64 M56 36 q4 -4 7 0 M66 50 q4 -4 7 0 M128 36 q4 -4 7 0 M138 50 q4 -4 7 0',hi:'M52 28 C58 22 68 20 76 22 L74 26 C67 24 60 26 55 31Z M124 22 C132 20 142 22 148 28 L145 31 C140 26 133 24 126 26Z'},
 locs:{back:CAP,strands:strands([50,58,66,134,142,150,74,126],[88,74,66],196,5),fstrands:'M67 68 C63 86 63 106 65 128 M79 60 C77 68 77 76 78 83 M121 60 C123 68 123 76 122 83 M133 68 C137 86 137 106 135 128',w:9,hi:'M80 50 C92 44 110 44 122 50'},
 box_braids:{back:CAP,strands:strands([48,55,62,69,131,138,145,152],[92,82,74],214,3),fstrands:'M68 64 L64 132 M80 58 L79 83 M120 58 L121 83 M132 64 L136 132',w:6,dash:true,hi:''},
 cornrows:{back:CAP,front:'M62 92 C60 58 80 44 100 44 C120 44 140 58 138 92 C130 74 116 66 100 66 C84 66 70 74 62 92Z',tex:'M70 86 C70 66 80 52 92 46 M82 74 C84 60 92 50 100 46 M100 66 L100 44 M118 74 C116 60 108 50 100 46 M130 86 C130 66 120 52 108 46',dash:true,hi:''},
 twists:{back:CAP,strands:strands([52,60,68,76,124,132,140,148],[70,60,54],130,4),fstrands:'M70 66 C66 74 66 82 68 88 M84 56 C82 64 82 72 84 80 M116 56 C118 64 118 72 116 80 M130 66 C134 74 134 82 132 88',w:8,dash:true,hi:''},
 high_top:{back:'M64 94 L64 38 C64 24 76 16 100 16 C124 16 136 24 136 38 L136 94 C128 76 116 68 100 68 C84 68 72 76 64 94Z',front2:'M62 96 L62 74 C62 70 64 66 66 64 L66 92Z M138 96 L138 74 C138 70 136 66 134 64 L134 92Z',tex:'M72 30 h3 M84 24 h3 M98 22 h3 M112 24 h3 M124 30 h3 M78 42 h3 M92 38 h3 M106 38 h3 M120 42 h3',hi:'M70 22 C82 16 118 16 130 22 L127 26 C114 21 86 21 73 26Z'}
};
const TOPS={
 tank:{d:'M86 104 C92 100 98 100 100 104 C104 120 136 120 140 104 C142 100 148 100 154 104 C160 122 158 148 152 182 L88 182 C82 148 80 122 86 104Z',shade:'M140 106 C150 104 156 120 154 150 L152 182 L142 182 C148 150 148 124 140 106Z'},
 shirt:{d:'M78 102 C96 96 144 96 162 102 C168 108 168 118 164 128 C160 148 154 164 152 184 L88 184 C86 164 80 148 76 128 C72 118 72 108 78 102Z',shade:'M150 104 C160 106 168 114 164 128 C160 148 154 164 152 184 L142 184 C148 156 154 126 150 104Z',detail:'M106 100 C110 110 130 110 134 100',sleeve:'short'},
 hoodie:{d:'M76 102 C96 94 144 94 164 102 C170 110 170 120 166 130 C162 150 158 170 156 196 L84 196 C82 170 78 150 74 130 C70 120 70 110 76 102Z',shade:'M150 104 C162 108 170 116 166 130 C162 150 158 170 156 196 L144 196 C150 160 156 128 150 104Z',detail:'M112 112 L110 138 M128 112 L130 138 M84 184 L156 184',pocket:'M96 158 L144 158 L150 184 L90 184Z',sleeve:'full',w:21},
 jacke:{d:'M76 102 C96 94 144 94 164 102 C170 110 170 120 166 130 C162 150 158 168 156 190 L84 190 C82 168 78 150 74 130 C70 120 70 110 76 102Z',shade:'M150 104 C162 108 170 116 166 130 C162 150 158 168 156 190 L144 190 C150 158 156 128 150 104Z',detail:'M120 104 L120 190 M104 98 L120 112 L136 98 M86 112 L84 186 M154 112 L156 186',sleeve:'full',stripe:true}
};
const BOTTOMS={
 boxer:{d:'M86 172 L154 172 L162 232 L128 238 L120 212 L112 238 L78 232Z',band:'M86 172 L154 172 L155 185 L85 185Z',stripe:'M152 188 L159 230 M88 188 L81 230',shade:'M138 186 L156 186 L162 232 L146 234Z'},
 kurz:{d:'M86 172 L154 172 L158 216 L126 220 L120 200 L114 220 L82 216Z',band:'M86 172 L154 172 L154 182 L86 182Z',stripe:'M150 184 L154 214',shade:'M138 184 L154 184 L158 216 L144 218Z'},
 jogger:{d:'M86 172 L154 172 L158 232 L154 304 L132 306 L124 212 L116 212 L108 306 L86 304 L82 232Z',band:'M86 172 L154 172 L154 184 L86 184Z M86 296 L108 296 L108 308 L86 308Z M132 296 L154 296 L154 308 L132 308Z',stripe:'M114 186 L112 198 M126 186 L128 198',shade:'M140 186 L156 186 L158 232 L154 304 L144 304 L148 234Z'},
 track:{d:'M86 172 L154 172 L158 232 L154 310 L132 310 L124 212 L116 212 L108 310 L86 310 L82 232Z',band:'M86 172 L154 172 L154 182 L86 182Z',stripe:'M151 186 L155 232 L151 306 M89 186 L85 232 L89 306',shade:'M140 186 L156 186 L158 232 L154 310 L144 310 L148 234Z'}
};
const FEET={
 boots:{d:'M84 296 L110 296 L110 330 L118 342 L74 342 L80 330Z M130 296 L156 296 L160 330 L166 342 L122 342 L130 330Z',lace:'M88 306 L106 306 M88 314 L106 314 M88 322 L106 322 M134 306 L152 306 M134 314 L152 314 M134 322 L152 322',sole:'M74 338 L118 338 L118 344 L74 344Z M122 338 L166 338 L166 344 L122 344Z'},
 sneaker:{d:'M86 316 L110 316 L112 330 L122 336 L122 344 L74 344 L76 330Z M130 316 L154 316 L162 330 L168 336 L168 344 L120 344 L124 330Z',lace:'M92 324 L106 322 M94 330 L108 328 M136 324 L150 322 M138 330 L152 328',sole:'M74 340 L122 340 L122 346 L74 346Z M120 340 L168 340 L168 346 L120 346Z'}
};
const COATS={
 basic:{c:'#3a4054',a:'#9aa3b0',body:'M74 100 L108 98 L104 290 L70 282 C66 220 66 150 74 100Z M166 100 L132 98 L136 290 L170 282 C174 220 174 150 166 100Z',trim:'M104 98 L120 114 L136 98 M80 200 L100 200 M140 200 L160 200'},
 samurai:{c:'#26306e',a:'#f2c14e',short:true,body:'M76 102 L106 100 L102 186 L80 190 C74 160 70 126 76 102Z M164 102 L134 100 L138 186 L160 190 C166 160 170 126 164 102Z M86 176 L154 176 L154 188 L86 188Z',trim:'M106 100 L102 186 M134 100 L138 186 M80 120 C86 116 92 116 96 120'},
 neon:{c:'#141a2e',a:'#3ef0ff',body:'M72 100 L108 98 L104 250 L68 244 C64 200 64 150 72 100Z M168 100 L132 98 L136 250 L172 244 C176 200 176 150 168 100Z',trim:'M100 104 L98 246 M140 104 L142 246 M70 170 L104 170 M136 170 L170 170'},
 drache:{c:'#8e0f1e',a:'#f2c14e',body:'M74 100 L108 98 L104 290 L70 282 C66 220 66 150 74 100Z M166 100 L132 98 L136 290 L170 282 C174 220 174 150 166 100Z',trim:'M104 98 L120 118 L136 98 M84 150 C96 140 92 126 86 120 M150 150 C140 170 156 190 146 210 C138 226 150 240 144 256 M76 270 L102 276 M138 276 L164 270'}
};
// Etappe 20b: Detail-Ebenen der Items (Nähte, Bündchen, Logos, Muster, Glanz) – nur feste Formen, Farben aus den Paletten oben.
const W='#ffffff';
const XTOP={
 tank:c=>`<path d="M88 106 C94 102 98 102 100 105 C104 121 136 121 140 105 C142 102 146 102 152 106" fill="none" stroke="${c[2]}" stroke-width="3.2" stroke-linecap="round"/><path d="M89 179 L151 179" stroke="${c[2]}" stroke-width="3"/>`
  +`<g transform="translate(131 140)"><circle r="7.5" fill="${c[1]}" stroke="${c[2]}" stroke-width="1.6"/><path d="M-3.6 -1 C-3.6 -4.4 0 -5.4 2.4 -3.8 C4.4 -2.2 4.2 2.2 1.6 3.4 L-2.6 3.4 C-3.6 2.4 -3.6 1.2 -3.6 -1Z" fill="${c[2]}"/></g>`
  +`<path d="M96 124 C98 146 98 164 96 178 M144 124 C142 146 142 164 144 178" fill="none" stroke="${c[1]}" stroke-width="1.4" opacity=".6"/>`,
 shirt:c=>`<path d="M104 100 C110 113 130 113 136 100" fill="none" stroke="${c[1]}" stroke-width="5" stroke-linecap="round"/><path d="M104 100 C110 113 130 113 136 100" fill="none" stroke="${INK}" stroke-width="1" opacity=".5"/>`
  +`<path d="M108 128 L132 128 L132 140 C132 148 126 152 120 155 C114 152 108 148 108 140Z" fill="${c[2]}" opacity=".92" stroke="${c[1]}" stroke-width="1.4"/><path d="M112.5 133 h8 M116.5 133 v12 M123.5 133 v12 h6" fill="none" stroke="${c[0]}" stroke-width="2.4" stroke-linecap="square"/>`
  +`<path d="M90 179 L150 179" stroke="${c[1]}" stroke-width="1.6" stroke-dasharray="3 2.4"/>`,
 hoodie:c=>`<circle cx="110" cy="139" r="2.6" fill="${c[2]}" stroke="${INK}" stroke-width="1"/><circle cx="130" cy="139" r="2.6" fill="${c[2]}" stroke="${INK}" stroke-width="1"/>`
  +`<path d="M84 185 L156 185 L156 196 L84 196Z" fill="${c[1]}" stroke="${INK}" stroke-width="1.6"/><path d="M84 190.5 L156 190.5" stroke="${c[0]}" stroke-width="5" stroke-dasharray="1.4 2.4" opacity=".55"/>`
  +`<path d="M96 158 C108 154 132 154 144 158" fill="none" stroke="${W}" stroke-width="1.6" opacity=".25"/><g transform="translate(103 128)"><path d="M-6 -5 L6 -5 L6 2 C6 6 2 8 0 9 C-2 8 -6 6 -6 2Z" fill="${c[2]}" opacity=".9"/><path d="M-3 -2 L3 -2 M0 -2 L0 5" stroke="${c[0]}" stroke-width="1.6"/></g>`,
 jacke:c=>`<path d="M104 98 L108 90 L132 90 L136 98 L130 102 L110 102Z" fill="${c[1]}" stroke="${INK}" stroke-width="1.6" stroke-linejoin="round"/>`
  +`<path d="M120 104 L120 182" stroke="${c[1]}" stroke-width="4.4"/><path d="M120 104 L120 182" stroke="#c9ced8" stroke-width="2.6" stroke-dasharray="1.4 1.8"/><rect x="117" y="112" width="6" height="10" rx="1.6" fill="#d8dce6" stroke="${INK}" stroke-width="1.2"/>`
  +`<path d="M91 158 L104 154 M149 158 L136 154" stroke="${c[2]}" stroke-width="2" stroke-linecap="round"/><path d="M84 182 L156 182 L156 190 L84 190Z" fill="${c[1]}" stroke="${INK}" stroke-width="1.4"/><path d="M84 186 L156 186" stroke="${c[0]}" stroke-width="4" stroke-dasharray="1.4 2.2" opacity=".55"/>`
};
const XBOT={
 boxer:c=>`<path d="M94 186 L85 186 L79 231 L91 233Z M146 186 L155 186 L161 231 L149 233Z" fill="${c[2]}" opacity=".95" stroke="${INK}" stroke-width="1.2" stroke-linejoin="round"/>`
  +`<path d="M95 186 L91 233 M145 186 L149 233" stroke="${c[1]}" stroke-width="1.6"/><path d="M79 230 L112 236 M128 236 L161 230" stroke="${c[2]}" stroke-width="3.2" stroke-linecap="round"/>`
  +`<text x="120" y="182.3" text-anchor="middle" font-family="Arial,Helvetica,sans-serif" font-weight="800" font-size="8.4" letter-spacing="1.6" fill="${c[0]}">TAKEOVER</text>`
  +`<path d="M100 192 C102 206 104 216 106 228 M134 192 C134 204 136 214 140 226" fill="none" stroke="${W}" stroke-width="3.4" opacity=".28" stroke-linecap="round"/>`,
 kurz:c=>`<path d="M154 216 L150 204 L146 217 M86 216 L90 204 L94 217" fill="none" stroke="${INK}" stroke-width="1.6" stroke-linejoin="round"/><path d="M82 215 L114 219 M126 219 L158 215" stroke="${c[2]}" stroke-width="2.6" stroke-linecap="round"/>`
  +`<path d="M116 182 C114 190 112 194 110 196 M124 182 C126 190 128 194 130 196" fill="none" stroke="${W}" stroke-width="1.6" stroke-linecap="round"/><path d="M100 190 C102 200 104 206 106 212" fill="none" stroke="${W}" stroke-width="3" opacity=".22" stroke-linecap="round"/>`,
 jogger:c=>`<path d="M86 298 L108 298 M86 302 L108 302 M132 298 L154 298 M132 302 L154 302" stroke="${c[0]}" stroke-width="1" opacity=".6"/><path d="M116 184 C115 192 114 196 112 200 M124 184 C125 192 126 196 128 200" fill="none" stroke="${c[2]}" stroke-width="1.6" stroke-linecap="round"/>`
  +`<path d="M90 190 C96 198 98 206 98 214 M150 190 C144 198 142 206 142 214" fill="none" stroke="${c[1]}" stroke-width="1.8"/><path d="M92 262 C98 258 104 258 108 262 M134 262 C138 258 146 258 150 262 M90 276 C96 272 102 272 108 276" fill="none" stroke="${c[1]}" stroke-width="1.4" opacity=".7"/>`,
 track:c=>`<path d="M146 186 L150 232 L146 306 M94 186 L90 232 L94 306" fill="none" stroke="${c[2]}" stroke-width="2.2"/><path d="M155.5 186 L159.5 232 L155.5 306 M84.5 186 L80.5 232 L84.5 306" fill="none" stroke="${c[2]}" stroke-width="1.6" opacity=".7"/>`
  +`<path d="M152 296 L153 308 M88 296 L87 308" stroke="#d8dce6" stroke-width="2" stroke-dasharray="1.2 1.2"/><path d="M96 200 C94 240 96 270 98 300" fill="none" stroke="${W}" stroke-width="2.6" opacity=".18" stroke-linecap="round"/>`
};
const XFEET={
 boots:c=>`<path d="M84 296 L110 296 L110 303 L84 303Z M130 296 L156 296 L156.6 303 L130 303Z" fill="${c[1]}" stroke="${INK}" stroke-width="1.4"/>`
  +`<path d="M79 335 C88 331 100 329.5 113 330 M125 330 C138 329.5 150 331 161 335" fill="none" stroke="${c[2]}" stroke-width="3.2" stroke-linecap="round"/>`
  +`<g fill="${INK}"><circle cx="88" cy="306" r="1.2"/><circle cx="106" cy="306" r="1.2"/><circle cx="88" cy="314" r="1.2"/><circle cx="106" cy="314" r="1.2"/><circle cx="134" cy="306" r="1.2"/><circle cx="152" cy="306" r="1.2"/><circle cx="134" cy="314" r="1.2"/><circle cx="152" cy="314" r="1.2"/></g>`
  +`<path d="M76 342 h4 M84 342 h4 M92 342 h4 M100 342 h4 M108 342 h4 M124 342 h4 M132 342 h4 M140 342 h4 M148 342 h4 M156 342 h4" stroke="#9aa0ad" stroke-width="1.6"/><path d="M86 300 L86 330" stroke="${W}" stroke-width="2.4" opacity=".35" stroke-linecap="round"/>`,
 sneaker:c=>`<path d="M76 334 L122 334 L122 340 L74 340Z M120 334 L168 334 L168 340 L120 340Z" fill="#f4f5f8" stroke="${INK}" stroke-width="1.2"/><path d="M75 334 C78 328 84 326 92 327 L92 334Z M121 334 C124 328 130 326 138 327 L138 334Z" fill="${c[2]}" opacity=".9"/>`
  +`<path d="M86 316 L86 326 M130 316 L130 326" stroke="${c[1]}" stroke-width="3"/><path d="M88 320 C94 318 100 318 104 320" fill="none" stroke="${W}" stroke-width="2" opacity=".35"/>`
};
// Mäntel: Revers, Gürtel, Muster
function wave(x0,x1,y,r,col){let d='';for(let x=x0;x+2*r<=x1;x+=2*r)d+=`M${x} ${y} a${r} ${r} 0 0 1 ${2*r} 0 `;return `<path d="${d}" fill="none" stroke="${col}" stroke-width="1.3" opacity=".75"/>`}
const XCOAT={
 basic:(c,a)=>`<path d="M108 98 C112 120 110 140 104 162 L99 158 C103 136 104 118 101 99Z M132 98 C128 120 130 140 136 162 L141 158 C137 136 136 118 139 99Z" fill="${a}" stroke="${INK}" stroke-width="1.4" stroke-linejoin="round"/>`
  +`<path d="M71 196 L106 198 L105 207 L71 205Z M134 198 L169 196 L169 205 L135 207Z" fill="${a}" stroke="${INK}" stroke-width="1.4"/><path d="M104 200 C112 198 116 206 110 212 C104 216 100 208 104 200Z" fill="${a}" stroke="${INK}" stroke-width="1.4"/><path d="M106 210 L100 242 L106 242 L111 212Z" fill="${a}" stroke="${INK}" stroke-width="1.2"/>`
  +`<path d="M80 230 L98 232 M142 232 L160 230" stroke="${a}" stroke-width="1.6" opacity=".7"/><path d="M78 120 C76 170 76 230 78 270" fill="none" stroke="${W}" stroke-width="3" opacity=".14" stroke-linecap="round"/>`,
 samurai:(c,a)=>wave(80,104,184,4,a)+wave(84,100,177,4,a)+wave(136,160,184,4,a)+wave(140,156,177,4,a)
  +`<g fill="none" stroke="${a}" stroke-width="1.6"><circle cx="90" cy="132" r="6"/><circle cx="150" cy="132" r="6"/><path d="M90 127 L90 137 M85.5 134.5 L94.5 129.5 M85.5 129.5 L94.5 134.5 M150 127 L150 137 M145.5 134.5 L154.5 129.5 M145.5 129.5 L154.5 134.5"/></g>`
  +`<path d="M104 146 C112 152 128 152 136 146" fill="none" stroke="${a}" stroke-width="2.4"/><circle cx="114" cy="152" r="2.6" fill="${a}"/><circle cx="126" cy="152" r="2.6" fill="${a}"/>`,
 neon:(c,a)=>`<path d="M100 104 L98 246 M140 104 L142 246 M70 170 L104 170 M136 170 L170 170" fill="none" stroke="${a}" stroke-width="9" opacity=".18" stroke-linecap="round"/>`
  +`<g fill="${a}"><circle cx="98" cy="246" r="2.6"/><circle cx="142" cy="246" r="2.6"/><circle cx="70" cy="170" r="2.4"/><circle cx="170" cy="170" r="2.4"/><circle cx="104" cy="170" r="2"/><circle cx="136" cy="170" r="2"/></g>`
  +`<path d="M80 120 L92 120 L96 128 M160 120 L148 120 L144 128 M78 210 L90 210 L94 202 M162 210 L150 210 L146 202" fill="none" stroke="${a}" stroke-width="1.4" opacity=".8"/><path d="M98 100 L94 84 L108 94Z M142 100 L146 84 L132 94Z" fill="${c}" stroke="${a}" stroke-width="1.6" stroke-linejoin="round"/>`,
 drache:(c,a)=>{let sc='';for(let r=0;r<4;r++){const y=216+r*14;sc+=wave(74+(r%2)*4,102,y,4,a)+wave(138+(r%2)*4,166,y,4,a)}
  return sc+`<path d="M70 282 L76 268 L82 284 L88 270 L94 286 L100 272 L104 290 Z M136 290 L140 272 L146 286 L152 270 L158 284 L164 268 L170 282Z" fill="${a}" stroke="${INK}" stroke-width="1.2" stroke-linejoin="round"/><path d="M76 280 L80 272 L84 282 M152 282 L156 272 L160 280" fill="none" stroke="#ff6a1f" stroke-width="1.6"/>`
  +`<path d="M94 102 C92 94 100 90 104 96 C106 88 114 88 116 96 L124 96 C126 88 134 88 136 96 C140 90 148 94 146 102 C140 108 100 108 94 102Z" fill="#f6efe0" stroke="${INK}" stroke-width="1.4" stroke-linejoin="round"/>`
  +`<path d="M148 152 L160 142 L157 150 L166 149 L156 156 L151 157Z" fill="${a}" stroke="${INK}" stroke-width="1.1" stroke-linejoin="round"/><circle cx="155" cy="150" r="1.1" fill="#ff3b2f"/><path d="M144 256 L140 264 L146 262" fill="none" stroke="${a}" stroke-width="2" stroke-linecap="round"/>`}
};
// Handschuh-Stil je Variante (Glanz, Muster, Leuchten)
const XGLOVE={
 rot:(g)=>`<path d="M6 -4 L15 -4 M6 0 L13 0" stroke="#fff" stroke-width="2.2" stroke-linecap="round" opacity=".9"/>`,
 weiss:(g)=>`<path d="M-17 -12.5 L-2 -12.5 M-17 12.5 L-2 12.5" stroke="${g[2]}" stroke-width="2.6"/><circle cx="10" cy="-1" r="3.4" fill="${g[2]}" opacity=".9"/>`,
 schwarzgold:(g)=>`<path d="M-4 -12 C0 -16.5 10 -17.5 17 -14 C25 -10 27 -1 25 6 C23 13.5 14 17 5 16" fill="none" stroke="${g[2]}" stroke-width="1.4" stroke-dasharray="2 2"/><rect x="-17" y="-12.5" width="15" height="6" fill="${g[2]}" opacity=".95"/><path d="M-12 -4 L-6 4 M-6 -4 L-12 4" stroke="${g[2]}" stroke-width="1.4"/>`,
 eisblau:(g)=>`<circle cx="6" cy="0" r="19" fill="#4fd8ff" opacity=".14"/><path d="M8 -10 L8 8 M0 -2 L16 -2 M2 -8 L14 4 M14 -8 L2 4" stroke="#ffffff" stroke-width="1.3" opacity=".85" stroke-linecap="round"/>`,
 glut:(g)=>`<circle cx="6" cy="0" r="19" fill="#ff6a1f" opacity=".15"/><path d="M2 10 C-2 2 4 -2 4 -10 C8 -4 10 -6 10 -12 C16 -4 18 4 12 10Z" fill="${g[2]}" opacity=".95"/><path d="M6 10 C4 6 7 3 8 -1 C10 3 12 6 10 10Z" fill="#fff6c8"/>`
};
const POSE={
 guard:{L:[[78,110],[66,150],[96,106]],R:[[162,110],[174,150],[146,108]],m:'M92 134 C97 136.5 103 136.5 109 132.5'},
 jab:{L:[[78,110],[50,108],[24,104]],R:[[162,110],[174,150],[146,106]],m:'M93 134 L108 133'},
 sieg:{L:[[78,110],[66,150],[72,184]],R:[[162,110],[182,76],[188,42]],m:'M92 132 C96 140 104 140 108 132'},
 cool:{L:[[78,110],[70,150],[134,142]],R:[[162,110],[170,150],[106,138]],m:'M92 134 C97 136.5 103 136.5 109 132.5'},
 flex:{L:[[78,110],[46,104],[58,70]],R:[[162,110],[194,104],[182,70]],m:'M92 132 C96 139 104 139 108 132'},
 ansage:{L:[[78,110],[66,150],[74,186]],R:[[162,110],[196,120],[222,102]],m:'M92 133 C97 136 103 136 109 131'}
};
function star(cx,cy,n,r1,r2){const q=[];for(let i=0;i<n*2;i++){const a=Math.PI*i/n-Math.PI/2,r=i%2?r2:r1;q.push((i?'L':'M')+f1(cx+Math.cos(a)*r)+' '+f1(cy+Math.sin(a)*r))}return q.join(' ')+'Z'}
const PUP={none:'M81.5 107.2 A3.1 4.4 0 1 0 87.7 107.2 A3.1 4.4 0 1 0 81.5 107.2Z',stern:star(84.6,107,5,5.4,2.3),kristall:'M84.6 100.6 L89 107 L84.6 113.4 L80.2 107Z',glut:'M84.6 100 C88.6 104 89 108 87.6 111 C86.6 113 82.6 113 81.6 111 C80.6 108.6 81.6 106.4 83.4 105 C83.2 106.8 84.2 107.6 85 107.2 C86 104.8 85.6 102.4 84.6 100Z',mond:'M86.8 101.6 A5 5.6 0 1 0 86.8 112.6 A4 4.6 0 1 1 86.8 101.6Z'};
const pick=(map,k,d)=>Object.prototype.hasOwnProperty.call(map,k)?map[k]:map[d];
const oneOf=(v,list,d)=>list.includes(v)?v:d;
function normalize(c){
 c=c&&typeof c==='object'?c:{};const o=Object.assign({},DEF);
 const t=Number(c.tone);if(Number.isInteger(t)&&t>=0&&t<=7)o.tone=t;
 o.hair=oneOf(c.hair,Object.keys(HAIR),DEF.hair);o.hc=oneOf(c.hc,Object.keys(HC),DEF.hc);o.eye=oneOf(c.eye,Object.keys(EYE),DEF.eye);
 o.eyefx=oneOf(c.eyefx,['none',...Object.keys(EFX)],'none');o.head=oneOf(c.head,['none','cap','band','hijab'],'none');
 for(const k of ['headc','topc','bottomc','feetc'])o[k]=oneOf(c[k],Object.keys(CL),DEF[k]);
 o.top=oneOf(c.top,['none',...Object.keys(TOPS)],'none');o.hood=c.hood===true;o.bottom=oneOf(c.bottom,Object.keys(BOTTOMS),DEF.bottom);
 o.hands=oneOf(c.hands,['wraps','gloves'],DEF.hands);o.glove=oneOf(c.glove,Object.keys(GL),DEF.glove);o.feet=oneOf(c.feet,Object.keys(FEET),DEF.feet);
 o.coat=oneOf(c.coat,['none',...Object.keys(COATS)],'none');o.aura=oneOf(c.aura,['none','flamme','sakura','blitz','schatten'],'none');
 o.scene=oneOf(c.scene,['holo','dojo','neon','arena'],DEF.scene);
 o.pose_profile=oneOf(c.pose_profile,Object.keys(POSE),'guard');o.pose_card=oneOf(c.pose_card,Object.keys(POSE),'guard');
 return o;
}
let uidN=0;
// Farben mischen (nur feste Hex-Werte aus den Tabellen oben – nie aus Daten)
const hx=v=>[1,3,5].map(i=>parseInt(v.slice(i,i+2),16));
const mix=(a,b,t)=>{const A=hx(a),B=hx(b);return '#'+A.map((x,i)=>Math.round(x+(B[i]-x)*t).toString(16).padStart(2,'0')).join('')};
const lite=(c,t)=>mix(c,'#ffffff',t),dark=(c,t)=>mix(c,'#000000',t);
// Glied (Ober-/Unterarm) als verjüngte Form mit runden Enden
function limb(a,b,wa,wb){
 const dx=b[0]-a[0],dy=b[1]-a[1],l=Math.hypot(dx,dy)||1,nx=-dy/l,ny=dx/l;
 return `M${f1(a[0]+nx*wa)} ${f1(a[1]+ny*wa)} L${f1(b[0]+nx*wb)} ${f1(b[1]+ny*wb)} A${wb} ${wb} 0 0 0 ${f1(b[0]-nx*wb)} ${f1(b[1]-ny*wb)} L${f1(a[0]-nx*wa)} ${f1(a[1]-ny*wa)} A${wa} ${wa} 0 0 0 ${f1(a[0]+nx*wa)} ${f1(a[1]+ny*wa)}Z`;
}
// svg(config, {pose, scene:'none'|..., holo:false, label}) → SVG-Text
function svg(cfg,opts){
 opts=opts||{};const c=normalize(cfg),u='tlh'+(++uidN);
 const pose=pick(POSE,opts.pose||c.pose_profile,'guard'),scene=opts.scene==='none'?'none':oneOf(opts.scene||c.scene,['holo','dojo','neon','arena'],'holo');
 const holo=opts.holo!==false,holoc='#4fd8ff';
 const [skin,sd]=TONES[c.tone],hc=HC[c.hc],fx=c.eyefx!=='none'?EFX[c.eyefx]:null,ev=fx||EYE[c.eye];
 const hijab=c.head==='hijab',cap=c.head==='cap',band=c.head==='band';
 const top=c.top!=='none'?TOPS[c.top]:null,hoodUp=!!(top&&c.top==='hoodie'&&c.hood),hoodDown=!!(top&&c.top==='hoodie'&&!c.hood);
 const co=c.coat!=='none'?COATS[c.coat]:null,tc=CL[c.topc],bc=CL[c.bottomc],fc=CL[c.feetc],hd=CL[c.headc],gv=GL[c.glove];
 const bt=BOTTOMS[c.bottom],ft=FEET[c.feet],H=HAIR[c.hair],gloves=c.hands==='gloves';
 const showHair=!hijab,clipY=hoodUp?104:cap?64:null;
 const p=(d,a)=>d?`<path d="${d}" ${a}/>`:'';
 const clipA=clipY!==null?` clip-path="url(#${u}cl)"`:'';
 const G=k=>`url(#${u}${k})`;
 // Verläufe: Licht von links oben, Schatten rechts unten
 const lg=(k,col,a,b)=>`<linearGradient id="${u}${k}" x1="0" y1="0" x2="1" y2=".35"><stop offset="0" stop-color="${lite(col,a||.3)}"/><stop offset=".48" stop-color="${col}"/><stop offset="1" stop-color="${dark(col,b||.32)}"/></linearGradient>`;
 const skinD=dark(sd,.12),rim=holo?holoc:'#ffffff';
 const arm=pts=>{const [s,e,w]=pts,dx=w[0]-e[0],dy=w[1]-e[1],len=Math.hypot(dx,dy)||1,ux=dx/len,uy=dy/len,ang=f1(Math.atan2(dy,dx)*180/Math.PI);
  const wr=[f1(w[0]-ux*12),f1(w[1]-uy*12)],mid=[f1((s[0]+e[0])/2),f1((s[1]+e[1])/2)];
  return {s,e,w,wr,mid,t:`translate(${f1(w[0]+ux*6)} ${f1(w[1]+uy*6)}) rotate(${ang})`,
   tsl:top&&top.sleeve?(top.sleeve==='short'?[s,mid]:[s,e,wr]):null,csl:co?(co.short?[s,e]:[s,e,wr]):null}};
 // Handschuh: glänzend, Manschette mit Streifen, Daumennaht, Glanzlichter
 const hand=(a,thumbUp)=>gloves
  ?`<g transform="${a.t}"><rect x="-17" y="-12.5" width="15" height="25" rx="5" fill="${G('gc')}" stroke="${INK}" stroke-width="2"/><path d="M-15 -4 L-4 -4 M-15 4 L-4 4" stroke="${gv[1]}" stroke-width="2.2" opacity=".75"/>`
   +`<path d="M-4 -12 C0 -16.5 10 -17.5 17 -14 C25 -10 27 -1 25 6 C23 13.5 14 17 5 16 C-1 15.5 -5 11 -5 4 L-5 -6 C-5 -9 -4.5 -11 -4 -12Z" fill="${G('gv')}" stroke="${INK}" stroke-width="2.4" stroke-linejoin="round"/>`
   +`<path d="M-4 6 C3 14 15 14.5 23 7 C21 13 13 16.5 5 16 C-1 15.5 -4.5 11.5 -4 6Z" fill="${gv[1]}" opacity=".85"/>`
   +`<path d="M14 -13 C18 -7 19 1 16 9" fill="none" stroke="${gv[1]}" stroke-width="1.6" opacity=".7"/>`
   +`<ellipse cx="2" cy="${thumbUp?-10:10}" rx="8" ry="5" fill="${G('gv')}" stroke="${INK}" stroke-width="2"/>`
   +`<path d="M1 -9 C6 -13 14 -13 19 -8" fill="none" stroke="#fff" stroke-width="3.2" stroke-linecap="round" opacity=".8"/><ellipse cx="20" cy="-3" rx="2.2" ry="3.4" fill="#fff" opacity=".55"/>${XGLOVE[c.glove](gv)}</g>`
  :`<g transform="${a.t}"><path d="M-2 -10 C8 -12 15 -8 15 0 C15 8 8 12 -2 10Z" fill="${G('sk')}" stroke="${INK}" stroke-width="2.2"/><path d="M10 -6 L14 -4 M11 0 L15 1 M10 5 L13 7" stroke="${skinD}" stroke-width="1.6" stroke-linecap="round"/>`
   +`<rect x="-13" y="-10" width="15" height="20" rx="3.5" fill="#f6f2ea" stroke="${INK}" stroke-width="1.8"/><path d="M-10 -10 L-5 10 M-5 -10 L0 10 M0 -10 L3 6" stroke="#c9c2b4" stroke-width="1.4"/><path d="M-13 -3 L2 -3" stroke="#fff" stroke-width="2" opacity=".8"/></g>`;
 const sleeve=(pts,col,w,stripe,cuff)=>{if(!pts)return '';let d='';for(let i=0;i<pts.length-1;i++)d+=`<path d="${limb(pts[i],pts[i+1],w/2,w/2-1.5)}" fill="${col}" stroke="${INK}" stroke-width="2" stroke-linejoin="round"/>`;
  if(cuff&&pts.length===3){const [e,w2]=[pts[1],pts[2]],dx=w2[0]-e[0],dy=w2[1]-e[1],l=Math.hypot(dx,dy)||1,q=[f1(w2[0]-dx/l*6),f1(w2[1]-dy/l*6)];d+=`<path d="${limb(q,w2,w/2-1.2,w/2-1.5)}" fill="${cuff}" stroke="${INK}" stroke-width="1.6"/>`}
  return d+(stripe?`<path d="M${pts.map(q=>q.join(' ')).join(' L')}" fill="none" stroke="${stripe}" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>`:'')};
 const armSvg=(a,thumbUp)=>{
  const up=limb(a.s,a.e,12,9.6),lo=limb(a.e,a.wr,9.8,8);
  const dx=a.e[0]-a.s[0],dy=a.e[1]-a.s[1],ang=f1(Math.atan2(dy,dx)*180/Math.PI),bx=f1(a.s[0]+dx*.48),by=f1(a.s[1]+dy*.48);
  return `<path d="${up}" fill="${G('sk')}" stroke="${INK}" stroke-width="2.2"/><path d="${lo}" fill="${G('sk')}" stroke="${INK}" stroke-width="2.2"/>`
   +`<ellipse cx="${bx}" cy="${by}" rx="9" ry="5.6" transform="rotate(${ang} ${bx} ${by})" fill="#fff" opacity=".13"/>`
   +(!a.tsl&&!a.csl?`<path d="M${a.s[0]-9} ${a.s[1]-3} C${a.s[0]-5} ${a.s[1]-10} ${a.s[0]+5} ${a.s[1]-10} ${a.s[0]+9} ${a.s[1]-3}" fill="none" stroke="#fff" stroke-width="2.2" opacity=".25" stroke-linecap="round"/>`:'')
   +sleeve(a.tsl,G('tc'),(top&&top.w||19)+2,top&&top.stripe?tc[2]:null,top&&top.sleeve==='full'?tc[1]:null)
   +sleeve(a.csl,G('co'),co?(co.short?25:22):0,null,co?co.a:null)
   +hand(a,thumbUp)};
 const eye=mirror=>`<g${mirror?' transform="translate(200 0) scale(-1 1)"':''}><path d="M71.5 102 C77 98 88 97.5 95.5 100.5 C95 106 93 111 88 113 C81 114.5 75 112 71.5 107Z" fill="#fff"/><path d="M71.5 102 C77 98 88 97.5 95.5 100.5 L95 103 C88 100.5 78 101 72 105Z" fill="#000" opacity=".12"/><ellipse cx="84" cy="106" rx="7" ry="8.6" fill="url(#${u}i)"/>${fx?`<circle cx="84" cy="106" r="7.6" fill="none" stroke="${fx[3]}" stroke-width="1.6" opacity=".95"/><circle cx="84" cy="106" r="11" fill="${fx[3]}" opacity=".18"/>`:''}<path d="${PUP[c.eyefx]||PUP.none}" fill="${ev[1]}"/><circle cx="${mirror?86.6:81.4}" cy="102.8" r="2.8" fill="#fff"/><circle cx="${mirror?80.6:87.4}" cy="110.2" r="1.3" fill="#fff"/><path d="M70 99 C75 93 87 92 96 97 L97 100.6 C88 96.6 77 97.6 71.5 102.6Z M70.5 99.5 L64 96.5 L71.5 102.6Z" fill="${INK}"/><path d="M68 87.5 C76 84 88 85.6 97 91 L96 94 C88 90 77 88.6 69 91Z" fill="${c.hair==='glatze'?dark(sd,.35):hc[1]}" stroke="${INK}" stroke-width="1.2" stroke-linejoin="round"/></g>`;
 const strandSvg=(d,w,dash)=>d?`<path d="${d}" fill="none" stroke="${INK}" stroke-width="${w+3.4}" stroke-linecap="round"/><path d="${d}" fill="none" stroke="url(#${u}h)" stroke-width="${w}" stroke-linecap="round"${dash?' stroke-dasharray="5 2.2"':''}/><path d="${d}" fill="none" stroke="${hc[2]}" stroke-width="1.5" stroke-linecap="round" opacity=".55"/>`:'';
 const scenes={
  dojo:`<rect width="240" height="380" fill="#efe2c4"/><rect width="240" height="300" fill="url(#${u}dj)"/><path d="M0 0 H240 V300 H0Z M60 0 V300 M120 0 V300 M180 0 V300 M0 75 H240 M0 150 H240 M0 225 H240" fill="none" stroke="#8a5a32" stroke-width="5"/><rect y="292" width="240" height="88" fill="#6b4224"/><path d="M0 312 H240 M0 334 H240 M0 358 H240" stroke="#4a2b14" stroke-width="2"/><rect y="292" width="240" height="10" fill="#000" opacity=".18"/>`,
  neon:`<rect width="240" height="380" fill="url(#${u}n)"/><circle cx="168" cy="96" r="44" fill="#ffd27a" opacity=".25"/><circle cx="168" cy="96" r="34" fill="#ffd27a" opacity=".85"/><path d="M0 260 V170 H26 V130 H52 V190 H70 V110 H100 V200 H120 V150 H148 V96 H170 V180 H196 V140 H222 V200 H240 V260Z" fill="#160f33"/><path d="M32 140 h6 M32 152 h6 M76 122 h8 M76 136 h8 M154 110 h6 M154 124 h6 M202 152 h8 M202 166 h8" stroke="#3ef0ff" stroke-width="3"/><rect y="260" width="240" height="120" fill="#0b0820"/><path d="M0 290 H240 M0 330 H240" stroke="#ff3ea5" stroke-width="1.5" opacity=".6"/><path d="M0 300 L120 268 L240 300" fill="none" stroke="#3ef0ff" stroke-width="1" opacity=".35"/>`,
  arena:`<rect width="240" height="380" fill="#0a0e1c"/><path d="M40 0 L0 260 H110Z M200 0 L130 260 H240Z" fill="url(#${u}sp)"/><rect y="290" width="240" height="90" fill="#1d2a4a"/><ellipse cx="120" cy="320" rx="120" ry="34" fill="#fff" opacity=".06"/><path d="M0 200 H240" stroke="#e0263a" stroke-width="5"/><path d="M0 232 H240" stroke="#f4f4f6" stroke-width="5"/><path d="M0 264 H240" stroke="#2f6bff" stroke-width="5"/><rect x="6" y="190" width="10" height="110" fill="#c4cad6"/><rect x="224" y="190" width="10" height="110" fill="#c4cad6"/>`,
  holo:`<path d="M40 352 L120 18 L200 352Z" fill="url(#${u}c)" opacity=".55"/><g fill="${holoc}"><circle cx="70" cy="300" r="1.6" opacity=".7"/><circle cx="168" cy="250" r="1.3" opacity=".6"/><circle cx="58" cy="210" r="1.1" opacity=".5"/><circle cx="182" cy="320" r="1.8" opacity=".7"/><circle cx="150" cy="160" r="1.1" opacity=".45"/><circle cx="88" cy="120" r="1" opacity=".4"/></g>`
   +`<ellipse cx="120" cy="352" rx="96" ry="19" fill="${holoc}" opacity=".12"/><ellipse cx="120" cy="352" rx="84" ry="15" fill="${holoc}" opacity=".22"/><ellipse cx="120" cy="352" rx="84" ry="15" fill="none" stroke="${holoc}" stroke-width="2.5" opacity=".95"/><ellipse cx="120" cy="352" rx="66" ry="11" fill="none" stroke="#bff4ff" stroke-width="1" opacity=".7"/><ellipse cx="120" cy="352" rx="50" ry="8" fill="none" stroke="${holoc}" stroke-width="1.5" stroke-dasharray="6 5" opacity=".8"/><path d="M36 352 L36 366 C36 376 204 376 204 366 L204 352" fill="url(#${u}pl)" stroke="#2a3350" stroke-width="2"/><path d="M40 362 C80 370 160 370 200 362" fill="none" stroke="${holoc}" stroke-width="1.2" opacity=".5"/>`
 };
 const auras={
  flamme:`<path d="M58 344 C28 284 48 232 38 182 C58 202 62 170 54 130 C74 150 78 110 74 70 C92 92 98 50 120 12 C142 50 148 92 166 70 C162 110 166 150 186 130 C178 170 182 200 202 182 C192 232 212 284 182 344Z" fill="#ff4a12" opacity=".45"/><path d="M66 344 C42 290 60 244 50 200 C66 214 70 186 64 150 C82 166 86 130 84 96 C100 116 104 80 120 44 C136 80 140 116 156 96 C154 130 158 166 176 150 C170 186 174 214 190 200 C180 244 198 290 174 344Z" fill="#ff8a1f" opacity=".5"/><path d="M76 344 C56 296 70 256 64 214 C80 230 84 200 80 168 C96 184 100 150 98 120 C110 140 114 110 120 82 C126 110 130 140 142 120 C140 150 144 184 160 168 C156 200 160 230 176 214 C170 256 184 296 164 344Z" fill="#ffd23a" opacity=".55"/>`,
  blitz:`<ellipse cx="120" cy="190" rx="100" ry="172" fill="#4fd8ff" opacity=".1"/><ellipse cx="120" cy="190" rx="80" ry="150" fill="#4fd8ff" opacity=".08"/><path d="M46 60 L30 120 L50 118 L28 196 M196 44 L212 110 L192 108 L214 176 M40 230 L22 280 L42 278 L26 336 M202 220 L222 268 L204 270 L218 330" fill="none" stroke="#4fd8ff" stroke-width="12" stroke-linecap="round" stroke-linejoin="round" opacity=".3"/><path d="M46 60 L30 120 L50 118 L28 196 M196 44 L212 110 L192 108 L214 176 M40 230 L22 280 L42 278 L26 336 M202 220 L222 268 L204 270 L218 330" fill="none" stroke="#bff4ff" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/><path d="M46 60 L30 120 L50 118 L28 196 M196 44 L212 110 L192 108 L214 176" fill="none" stroke="#fff" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round"/>`,
  sakura:`<ellipse cx="120" cy="190" rx="100" ry="172" fill="#ff9ad0" opacity=".16"/><g fill="#ffc2e2" stroke="#d25a96" stroke-width="1.2"><path d="M36 74 C42 70 46 76 40 82 C34 84 30 78 36 74Z"/><path d="M206 60 C212 58 214 66 208 70 C202 72 200 64 206 60Z"/><path d="M22 164 C28 160 32 168 26 172 C20 174 18 168 22 164Z"/><path d="M216 154 C222 150 226 158 220 162 C214 166 210 158 216 154Z"/><path d="M40 254 C46 250 50 258 44 262 C38 266 34 258 40 254Z"/><path d="M204 244 C210 240 214 248 208 252 C202 256 198 248 204 244Z"/><path d="M60 26 C64 22 70 28 64 32 C58 34 56 28 60 26Z"/><path d="M184 312 C190 308 194 316 188 320 C182 324 178 316 184 312Z"/></g><g fill="#fff" opacity=".6"><circle cx="38" cy="77" r="1.2"/><circle cx="208" cy="64" r="1.2"/><circle cx="218" cy="157" r="1.2"/></g>`,
  schatten:`<path d="M70 346 C40 300 70 270 50 230 C40 200 70 190 60 150 C54 120 80 100 76 70 C96 96 110 60 104 30 C124 56 150 50 150 20 C166 60 150 90 172 110 C190 130 170 160 186 190 C200 220 176 240 194 280 C206 310 186 330 172 346Z" fill="#5a2bb0" opacity=".5"/><path d="M88 346 C70 310 88 286 76 250 C70 226 92 210 86 180 C100 196 108 170 104 150 C118 170 132 160 134 134 C148 160 140 184 156 200 C166 222 150 240 162 270 C170 300 156 326 152 346Z" fill="#14081f" opacity=".6"/><g fill="#c49bff" opacity=".7"><circle cx="64" cy="120" r="1.5"/><circle cx="178" cy="150" r="1.5"/><circle cx="96" cy="60" r="1.2"/><circle cx="160" cy="260" r="1.5"/></g>`
 };
 const label=opts.label?` role="img" aria-label="${String(opts.label).replace(/[&<>"']/g,'')}"`:' aria-hidden="true"';
 // Beine: verjüngt mit Knie und Wade
 const legs=`<path d="M84 230 C82 254 86 270 88 284 C86 298 88 312 90 324 L110 324 C111 310 113 296 112 282 C114 266 114 250 112 234Z" fill="${G('sk')}" stroke="${INK}" stroke-width="2"/><path d="M128 234 C126 250 126 266 128 282 C127 296 129 310 130 324 L150 324 C152 312 154 298 152 284 C154 270 158 254 156 230Z" fill="${G('sk')}" stroke="${INK}" stroke-width="2"/>`
  +`<path d="M146 238 C152 256 150 274 148 284 C150 298 150 312 149 322 L142 322 C144 300 146 270 146 238Z" fill="${skinD}" opacity=".35"/><path d="M90 284 C94 280 104 280 108 284 M132 284 C136 280 146 280 150 284" fill="none" stroke="${skinD}" stroke-width="1.6" stroke-linecap="round" opacity=".7"/><path d="M90 246 C90 262 92 272 94 280" fill="none" stroke="#fff" stroke-width="2.4" opacity=".18" stroke-linecap="round"/>`;
 // Oberkörper: Brust, Bauch, Schultern, Schlüsselbein
 const torso=`<path d="M78 102 C96 96 144 96 162 102 C168 108 168 118 164 128 C160 148 154 162 150 176 L90 176 C86 162 80 148 76 128 C72 118 72 108 78 102Z" fill="${G('sk')}" stroke="${INK}" stroke-width="2"/>`
  +`<path d="M162 102 C168 108 168 118 164 128 C160 148 154 162 150 176 L140 176 C148 150 154 124 150 104Z" fill="${skinD}" opacity=".45"/>`
  +`<path d="M94 116 C102 110 114 112 119 122 C114 132 100 133 92 127Z M146 116 C138 110 126 112 121 122 C126 132 140 133 148 127Z" fill="${skinD}" opacity=".28"/>`
  +`<path d="M94 116 C102 111 112 112 117 119 M126 117 C130 112 140 111 146 116" fill="none" stroke="#fff" stroke-width="2.2" opacity=".22" stroke-linecap="round"/>`
  +`<path d="M93 128 C102 135 114 134 119 127 M121 127 C126 134 138 135 147 128" fill="none" stroke="${skinD}" stroke-width="2" stroke-linecap="round" opacity=".8"/>`
  +`<path d="M108 138 h11 v9 h-11Z M121 138 h11 v9 h-11Z M109 150 h10 v9 h-10Z M121 150 h10 v9 h-10Z M110 162 h9 v8 h-9Z M121 162 h9 v8 h-9Z" fill="${skinD}" opacity=".16"/><path d="M120 134 L120 172" stroke="${skinD}" stroke-width="1.8" opacity=".7" stroke-linecap="round"/>`
  +`<path d="M98 140 C102 152 104 162 104 172 M142 140 C138 152 136 162 136 172" fill="none" stroke="${skinD}" stroke-width="1.6" opacity=".55" stroke-linecap="round"/>`
  +`<path d="M98 106 C106 104 114 106 118 108 M122 108 C126 106 134 104 142 106" fill="none" stroke="${skinD}" stroke-width="1.6" opacity=".6" stroke-linecap="round"/>`;
 const fab=(k,d,col,extra)=>p(d,`fill="${G(k)}" stroke="${INK}" stroke-width="2" stroke-linejoin="round"${extra||''}`);
 return `<svg class="tlh" viewBox="0 0 240 380"${label} style="overflow:${scene==='holo'||scene==='none'?'visible':'hidden'}"><defs>`
  +`<linearGradient id="${u}i" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${ev[1]}"/><stop offset=".55" stop-color="${ev[0]}"/><stop offset="1" stop-color="${ev[2]}"/></linearGradient>`
  +`<linearGradient id="${u}h" x1="0" y1="0" x2=".4" y2="1"><stop offset="0" stop-color="${lite(hc[0],.12)}"/><stop offset=".55" stop-color="${hc[0]}"/><stop offset="1" stop-color="${hc[1]}"/></linearGradient>`
  +lg('sk',skin,.22,.18)+lg('tc',tc[0])+lg('bc',bc[0],.35,.35)+lg('fc',fc[0],.25,.3)+lg('hd',hd[0])+(co?lg('co',co.c,.25,.35):'')+lg('gc',gv[2],.3,.25)
  +`<radialGradient id="${u}gv" cx=".38" cy=".32" r=".8"><stop offset="0" stop-color="${lite(gv[0],.45)}"/><stop offset=".45" stop-color="${gv[0]}"/><stop offset="1" stop-color="${gv[1]}"/></radialGradient>`
  +(scene==='holo'?`<linearGradient id="${u}c" x1="0" y1="1" x2="0" y2="0"><stop offset="0" stop-color="${holoc}" stop-opacity=".6"/><stop offset="1" stop-color="${holoc}" stop-opacity="0"/></linearGradient><linearGradient id="${u}pl" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#1c2540"/><stop offset="1" stop-color="#0a0f1d"/></linearGradient>`:'')
  +(scene==='neon'?`<linearGradient id="${u}n" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#2a0f5a"/><stop offset=".7" stop-color="#ff3ea5"/><stop offset="1" stop-color="#ff9a5a"/></linearGradient>`:'')
  +(scene==='dojo'?`<radialGradient id="${u}dj" cx=".5" cy=".35" r=".8"><stop offset="0" stop-color="#fff6dc"/><stop offset="1" stop-color="#d9c49a"/></radialGradient>`:'')
  +(scene==='arena'?`<radialGradient id="${u}sp" cx=".5" cy="0" r="1"><stop offset="0" stop-color="#fff" stop-opacity=".35"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></radialGradient>`:'')
  +(holo?`<pattern id="${u}s" width="3" height="3" patternUnits="userSpaceOnUse"><rect width="3" height="1" fill="${holoc}"/></pattern>`:'')
  +(clipY!==null?`<clipPath id="${u}cl"><rect x="-40" y="${clipY}" width="280" height="400"/></clipPath>`:'')
  +`</defs>`+(scene!=='none'?scenes[scene]:'')
  +(c.aura!=='none'?`<g class="tlh-aura">${auras[c.aura]}</g>`:'')
  +`<ellipse cx="120" cy="345" rx="${scene==='holo'?46:56}" ry="7" fill="#000" opacity="${scene==='holo'?.35:.28}"/>`
  +`<g class="tlh-fig"><g transform="translate(60 -6) scale(0.6)">`
  +(band?`<path d="M134 82 L170 66 L160 84 L174 96 L136 92Z" fill="${G('hd')}" stroke="${INK}" stroke-width="3" stroke-linejoin="round"/>`:'')
  +(showHair?p(H.back,`fill="url(#${u}h)" stroke="${INK}" stroke-width="3.4" stroke-linejoin="round"${H.backOpacity?` opacity="${H.backOpacity}"`:''}${clipA}`)+(H.strands?`<g${clipA}>${strandSvg(H.strands,H.w||8,H.dash)}</g>`:''):'')
  +(hijab?`<path d="M44 120 C38 54 70 28 100 28 C130 28 162 54 156 120 C158 150 150 170 140 182 L60 182 C50 170 42 150 44 120Z" fill="${G('hd')}" stroke="${INK}" stroke-width="3.4"/>`:'')
  +(hoodUp?`<path d="M48 110 C40 50 70 26 100 26 C130 26 160 50 152 110 C150 140 136 160 120 168 L80 168 C64 160 50 140 48 110Z" fill="${G('tc')}" stroke="${INK}" stroke-width="3.4"/>`:'')
  +`</g>`
  +`<path d="M110 80 L130 80 L132 106 L108 106Z" fill="${G('sk')}" stroke="${INK}" stroke-width="1.6"/><path d="M110 84 L130 84 L130 96 C124 100 116 100 110 96Z" fill="${skinD}" opacity=".7"/><path d="M98 104 C104 98 110 96 112 92 L112 104Z M142 104 C136 98 130 96 128 92 L128 104Z" fill="${G('sk')}"/>`
  +torso+legs
  +fab('bc',bt.d,bc[0])+p(bt.band,`fill="${c.bottom==='boxer'?bc[2]:bc[1]}" stroke="${INK}" stroke-width="1.6"`)+(c.bottom==='track'?'':p(bt.stripe,`fill="none" stroke="${bc[2]}" stroke-width="4" stroke-linecap="round"`))+p(bt.shade,'fill="#000" opacity=".22"')+XBOT[c.bottom](bc)
  +(c.bottom==='boxer'||c.bottom==='kurz'?`<path d="M96 192 C98 206 100 214 102 224" fill="none" stroke="#fff" stroke-width="3" opacity=".22" stroke-linecap="round"/><path d="M114 176 h12" stroke="${bc[0]}" stroke-width="3" stroke-linecap="round" opacity=".9"/>`:`<path d="M94 196 C92 230 94 260 96 290" fill="none" stroke="#fff" stroke-width="2.6" opacity=".16" stroke-linecap="round"/><path d="M110 222 C112 240 110 260 112 280 M136 222 C134 240 136 260 134 280" fill="none" stroke="${bc[1]}" stroke-width="1.6" opacity=".6"/>`)
  +fab('fc',ft.d,fc[0])+p(ft.lace,`fill="none" stroke="${fc[2]}" stroke-width="2.4" stroke-linecap="round"`)+p(ft.sole,`fill="#f2f2f5" stroke="${INK}" stroke-width="1.4"`)+XFEET[c.feet](fc)
  +`<path d="M80 334 C90 330 100 330 108 334 M126 334 C136 330 148 330 158 334" fill="none" stroke="#fff" stroke-width="2" opacity=".35" stroke-linecap="round"/>`
  +(top?fab('tc',top.d,tc[0])+p(top.shade,'fill="#000" opacity=".22"')+p(top.detail,`fill="none" stroke="${tc[2]}" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"`)+p(top.pocket,`fill="${tc[1]}" stroke="${INK}" stroke-width="1.6"`)+XTOP[c.top](tc)
     +`<path d="M98 120 C104 140 104 160 100 176 M142 120 C136 140 136 160 140 176" fill="none" stroke="${tc[1]}" stroke-width="1.6" opacity=".55" stroke-linecap="round"/><path d="M88 112 C90 130 94 150 96 170" fill="none" stroke="#fff" stroke-width="3" opacity=".14" stroke-linecap="round"/>`:'')
  +(hoodDown?`<path d="M96 98 C104 110 136 110 144 98 C150 106 142 117 120 117 C98 117 90 106 96 98Z" fill="${tc[1]}" stroke="${INK}" stroke-width="2"/>`:'')
  +(co?fab('co',co.body,co.c)+p(co.trim,`fill="none" stroke="${co.a}" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round"`)+p(co.body,`fill="none" stroke="${co.a}" stroke-width="1" opacity=".35"`)+XCOAT[c.coat](co.c,co.a):'')
  +`<g transform="translate(60 -6) scale(0.6)">`
  +`<ellipse cx="62" cy="106" rx="5.5" ry="9.5" fill="${skin}" stroke="${INK}" stroke-width="2.6"/><ellipse cx="138" cy="106" rx="5.5" ry="9.5" fill="${sd}" stroke="${INK}" stroke-width="2.6"/>`
  +`<path d="M62 92 C62 60 80 46 100 46 C120 46 138 60 138 92 C138 116 130 133 117 146 L104 157 C101.5 159 98.5 159 96 157 L83 146 C70 133 62 116 62 92Z" fill="${G('sk')}" stroke="${INK}" stroke-width="3.4" stroke-linejoin="round"/><path d="M138 92 C138 116 130 133 117 146 L104 157 C113 140 123 123 127 100Z" fill="${skinD}" opacity=".45"/>`
  +`<ellipse cx="78" cy="124" rx="8" ry="5" fill="#ff7a7a" opacity=".16"/><ellipse cx="122" cy="124" rx="8" ry="5" fill="#ff7a7a" opacity=".12"/><path d="M74 70 C80 62 90 58 98 58" fill="none" stroke="#fff" stroke-width="3" opacity=".2" stroke-linecap="round"/>`
  +(showHair&&c.hair!=='glatze'?`<path d="M64 94 C80 103 120 103 136 94 L136 103 C120 111 80 111 64 103Z" fill="${sd}" opacity=".5"/>`:'')
  +eye(false)+eye(true)
  +`<path d="M101 112 C102 117 104 121 103 124 C101 126 98 126 96.5 124.5" fill="none" stroke="${skinD}" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/><path d="M98 114 C98 118 97.6 120 97 122" stroke="#fff" stroke-width="1.6" opacity=".35" stroke-linecap="round"/>`
  +`<path d="${pose.m}" fill="none" stroke="#4a1a22" stroke-width="2.8" stroke-linecap="round"/><path d="M95 138.5 C99 140.5 103 140.5 106 138.5" fill="none" stroke="${skinD}" stroke-width="1.6" opacity=".55" stroke-linecap="round"/>`
  +(band?`<path d="M62 80 C80 72 120 72 138 80 L138 90 C120 82 80 82 62 90Z" fill="${G('hd')}" stroke="${INK}" stroke-width="2.6"/><path d="M66 81 C82 75 118 75 134 81" fill="none" stroke="#fff" stroke-width="1.6" opacity=".35"/><path d="M63 85.5 C80 78 120 78 137 85.5" fill="none" stroke="${hd[2]}" stroke-width="1.6" stroke-dasharray="4 3"/><path d="M134 82 L170 66 L160 84 L174 96 L136 92Z" fill="none" stroke="${hd[2]}" stroke-width="1.4" opacity=".6"/>`:'')
  +(showHair?p(H.front,`fill="url(#${u}h)" stroke="${INK}" stroke-width="3.2" stroke-linejoin="round"`)+p(H.front2,`fill="url(#${u}h)" stroke="${INK}" stroke-width="3" stroke-linejoin="round"`)
   +(H.fstrands&&!hoodUp&&!cap?strandSvg(H.fstrands,(H.w||8)-1,H.dash):'')
   +p(H.tex,`fill="none" stroke="${H.dash?hc[2]:hc[1]}" stroke-width="2" stroke-linecap="round"${H.dash?' stroke-dasharray="3 2"':''} opacity=".8"`)
   +(H.hi&&!cap&&!hoodUp?p(H.hi,H.hiSkin?'fill="#fff" opacity=".35"':`fill="${hc[2]}" opacity=".9"`):''):'')
  +(hijab?`<path d="M60 108 C56 66 78 46 100 46 C122 46 144 66 140 108" fill="none" stroke="${INK}" stroke-width="13" stroke-linecap="round"/><path d="M60 108 C56 66 78 46 100 46 C122 46 144 66 140 108" fill="none" stroke="${hd[0]}" stroke-width="8.5" stroke-linecap="round"/><path d="M64 136 C80 160 120 160 136 136 L156 178 C130 198 70 198 44 178Z" fill="${G('hd')}" stroke="${INK}" stroke-width="3"/><path d="M76 162 C92 170 108 170 124 162" fill="none" stroke="${hd[1]}" stroke-width="3"/><path d="M58 70 C66 52 82 40 98 38" fill="none" stroke="#fff" stroke-width="3" opacity=".22" stroke-linecap="round"/>`:'')
  +(cap?`<path d="M58 80 C56 42 80 30 100 30 C120 30 144 42 142 80 C122 72 78 72 58 80Z" fill="${G('hd')}" stroke="${INK}" stroke-width="3.2" stroke-linejoin="round"/><path d="M100 30 L100 74" stroke="${hd[1]}" stroke-width="2.4"/><path d="M52 80 C78 70 122 70 148 80 C156 88 140 96 100 94 C60 96 44 88 52 80Z" fill="${hd[1]}" stroke="${INK}" stroke-width="3.2" stroke-linejoin="round"/><path d="M84 46 C92 40 104 40 112 44" stroke="#fff" stroke-width="3" fill="none" opacity=".4" stroke-linecap="round"/><circle cx="100" cy="31" r="3.4" fill="${hd[1]}" stroke="${INK}" stroke-width="1.6"/><path d="M80 38 C76 52 76 64 78 74 M120 38 C124 52 124 64 122 74" fill="none" stroke="${hd[1]}" stroke-width="2" opacity=".8"/><circle cx="100" cy="55" r="8" fill="${hd[2]}" stroke="${INK}" stroke-width="1.6"/><path d="M96 52 h8 M100 52 v8" stroke="${hd[0]}" stroke-width="2.4"/><circle cx="84" cy="50" r="1.4" fill="${INK}"/><circle cx="116" cy="50" r="1.4" fill="${INK}"/><path d="M56 82 C80 76 120 76 144 82" fill="none" stroke="#fff" stroke-width="2" opacity=".3"/>`:'')
  +(hoodUp?`<path d="M56 120 C48 62 76 36 100 36 C124 36 152 62 144 120" fill="none" stroke="${INK}" stroke-width="15" stroke-linecap="round"/><path d="M56 120 C48 62 76 36 100 36 C124 36 152 62 144 120" fill="none" stroke="${tc[1]}" stroke-width="10" stroke-linecap="round"/>`:'')
  +`</g>`
  +armSvg(arm(pose.R),false)+armSvg(arm(pose.L),true)
  +`</g>`+(holo?`<rect class="tlh-scan" x="30" y="0" width="180" height="350" fill="url(#${u}s)" opacity=".12"/>`:'')+`</svg>`;
}
window.TLHolo={svg,normalize,DEF,LABEL,TONES,HC,EYE,CL,GL,HAIR_KEYS:Object.keys(HAIR),POSES:Object.keys(POSE)};
})();
