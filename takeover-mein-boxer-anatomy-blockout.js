/* Takeover League · editable anatomy blockout v0.
 * Explicitly NOT production art, animation or an approved outfit.
 * Derived from the 768×1216 cool-pose measurements. Never loaded by normal mode.
 * Drawn behind the eight original approved-reference raster masks, so the
 * unpainted shoulders, flanks, robe-hidden shorts, and legs can be traced. */
(function(){
 'use strict';
 function markup(){
  return `<svg class="mb-draft-underpaint" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 768 1216" width="768" height="1216" aria-hidden="true" focusable="false">
  <defs>
   <radialGradient id="tla-skin" cx="46%" cy="22%" r="78%"><stop stop-color="#dca06a"/><stop offset=".3" stop-color="#b9713b"/><stop offset=".7" stop-color="#824226"/><stop offset="1" stop-color="#441e18"/></radialGradient>
   <linearGradient id="tla-edge"><stop stop-color="#2b1413"/><stop offset=".23" stop-color="#9b522f"/><stop offset=".56" stop-color="#c78b58"/><stop offset=".83" stop-color="#98512c"/><stop offset="1" stop-color="#321919"/></linearGradient>
   <linearGradient id="tla-abs"><stop stop-color="#4e261b"/><stop offset=".35" stop-color="#b5713e"/><stop offset=".7" stop-color="#cf955f"/><stop offset="1" stop-color="#512a20"/></linearGradient>
   <linearGradient id="tla-shorts"><stop stop-color="#1e2631"/><stop offset=".58" stop-color="#0e121f"/><stop offset="1" stop-color="#050915"/></linearGradient>
   <linearGradient id="tla-leg"><stop stop-color="#2d1818"/><stop offset=".35" stop-color="#a55c30"/><stop offset=".65" stop-color="#c78750"/><stop offset=".85" stop-color="#9d4c28"/><stop offset="1" stop-color="#311817"/></linearGradient>
  </defs>
  <!-- ANATOMY BLOCKOUT: illustrative tracing layer, not finished art -->
  <path d="M315 250 C284 252 264 267 243 279 C213 291 192 319 189 359 C185 389 192 411 205 433 C215 453 235 473 261 478 L289 494 Q317 518 377 524 Q431 524 473 498 L505 481 C533 473 552 448 570 419 C579 395 583 365 568 334 C557 307 537 287 510 275 C481 257 465 254 442 249 L416 277 Q379 296 346 277Z" fill="url(#tla-skin)" stroke="#422522" stroke-width="6"/>
  <path d="M321 263 C291 255 256 267 230 297 C214 317 203 344 203 375 C207 405 223 417 247 423 C271 420 300 398 319 365 C333 333 344 300 321 263Z" fill="url(#tla-edge)" stroke="#3f221a" stroke-width="5"/>
  <path d="M437 261 C473 258 509 271 537 301 Q564 332 565 367 C566 398 546 418 513 428 C483 416 463 397 448 367 Q426 308 437 261Z" fill="url(#tla-edge)" stroke="#3f221a" stroke-width="5"/>
  <path d="M314 272 Q274 293 251 349 Q232 388 254 410 M457 274 Q510 307 533 358 Q542 386 518 405" stroke="#f1b67c" stroke-opacity=".5" stroke-width="9" stroke-linecap="round" fill="none"/>
  <path d="M304 301 C329 293 349 290 378 292 C402 291 428 296 457 309 Q442 339 426 355 C415 372 404 375 380 372 Q356 375 343 363 Q324 339 304 301Z" fill="url(#tla-abs)" stroke="#5e2d1e" stroke-width="4"/>
  <path d="M381 296 L381 405 M321 328 Q341 358 364 352 M437 327 Q418 358 395 351" fill="none" stroke="#592e22" stroke-opacity=".7" stroke-width="5" stroke-linecap="round"/>
  <path d="M299 383 Q323 378 346 388 Q362 404 376 409 Q401 402 423 388 Q452 373 472 382 L473 467 Q419 499 380 501 Q320 500 285 465Z" fill="url(#tla-abs)" stroke="#5c3526" stroke-width="3"/>
  <path d="M307 419 Q337 433 365 429 M393 428 Q427 430 457 416 M326 457 Q351 467 368 462 M393 464 Q425 467 446 454 M381 407 V490" stroke="#5a291d" stroke-opacity=".7" stroke-width="5" fill="none"/>
  <path d="M220 360 C211 402 225 440 260 462 Q284 472 306 459 L338 438 L328 405 L282 420 Q261 422 249 394 L248 367Z" fill="url(#tla-edge)" stroke="#45231c" stroke-width="4"/>
  <path d="M536 357 C553 395 535 438 502 461 Q483 476 459 463 L427 440 L438 405 L478 420 Q500 421 508 390 L511 369Z" fill="url(#tla-edge)" stroke="#45231c" stroke-width="4"/>
  <path d="M290 475 Q380 481 468 475 L486 525 L499 690 L534 785 C519 803 496 813 466 807 L442 783 Q421 785 382 775 Q348 781 326 782 L302 808 Q269 807 245 786 L263 683 L275 522Z" fill="url(#tla-shorts)" stroke="#1f2430" stroke-width="5"/>
  <path d="M286 483 Q378 493 473 481 L474 535 Q378 548 276 531Z" fill="#0a0d16" stroke="#cba14f" stroke-width="6"/>
  <path d="M265 541 L246 766 Q270 783 297 781 L315 581 M482 538 L524 772 Q501 787 474 787 L445 574" stroke="#b98835" stroke-opacity=".68" stroke-width="10" fill="none"/>
  <path d="M253 778 Q281 785 313 787 C313 830 305 869 302 920 C300 940 293 962 272 984 L242 980 C236 949 232 906 234 866 Q234 819 253 778Z" fill="url(#tla-leg)" stroke="#39201a" stroke-width="5"/>
  <path d="M445 789 Q478 783 507 781 C522 826 530 874 528 921 Q528 951 511 985 L482 986 C460 963 457 941 450 909 Q445 862 445 789Z" fill="url(#tla-leg)" stroke="#39201a" stroke-width="5"/>
  </svg>`;
 }
 window.TLBoxerAnatomyBlockout=Object.freeze({markup,version:0,approved:false});
})();
