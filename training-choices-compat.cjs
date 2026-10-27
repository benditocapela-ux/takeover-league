'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs');
const {JSDOM}=require('jsdom');
function swissDate(offset=0){
 const parts=new Intl.DateTimeFormat('en-CA',{timeZone:'Europe/Zurich',year:'numeric',month:'2-digit',day:'2-digit'}).formatToParts(new Date());
 const part=type=>parts.find(x=>x.type===type)?.value||'';
 const date=new Date(Date.UTC(Number(part('year')),Number(part('month'))-1,Number(part('day'))+offset,12));
 return [date.getUTCFullYear(),String(date.getUTCMonth()+1).padStart(2,'0'),String(date.getUTCDate()).padStart(2,'0')].join('-');
}
const dom=new JSDOM(`<!doctype html><body data-tl-screen="boxer"><form>
 <label for="date">Trainingsdatum</label><input id="date" type="date" value="${swissDate()}">
 <div id="techniqueField"><label for="techniqueMinutes">Technikminuten</label><input id="techniqueMinutes" type="number" min="1" max="1440"></div>
 </form></body>`,{runScripts:'outside-only',url:'https://example.test/boxer.html'});
const {window}=dom,doc=window.document;
window.eval(fs.readFileSync('takeover-training-choices.js','utf8'));
const date=doc.getElementById('date'),minutes=doc.getElementById('techniqueMinutes');
const dateButtons=doc.querySelectorAll('[aria-label="Schnellauswahl für Trainingsdatum"] button');
const minuteButtons=doc.querySelectorAll('[aria-label="Schnellauswahl für die Trainingsdauer"] button');
assert.equal(dateButtons.length,3);assert.equal(minuteButtons.length,5);
assert.equal(dateButtons[0].getAttribute('aria-pressed'),'true','Today should reflect the existing input value');
dateButtons[1].click();assert.equal(date.value,swissDate(-1),'Yesterday preset must use the Swiss local calendar date');
assert.equal(dateButtons[1].getAttribute('aria-pressed'),'true');
const before=date.value;dateButtons[2].click();assert.equal(date.value,before,'Custom date action must not overwrite the native date input');
minutes.value='60';minutes.dispatchEvent(new window.Event('input',{bubbles:true}));
assert.equal(minuteButtons[2].getAttribute('aria-pressed'),'true');
minuteButtons[3].click();assert.equal(minutes.value,'90','Technique preset should update the original number input');
assert.equal(minuteButtons[3].getAttribute('aria-pressed'),'true');
minutes.value='62';minutes.dispatchEvent(new window.Event('input',{bubbles:true}));
assert.ok(Array.from(minuteButtons).every(button=>button.getAttribute('aria-pressed')==='false'),'Custom values should clear preset selection');
dom.window.close();
console.log('PASS: Training date and technique-minute presets update only the existing native inputs.');
