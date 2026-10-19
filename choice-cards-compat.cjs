'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs');
const {JSDOM}=require('jsdom');

async function main(){
 const html=`<!doctype html><html><body data-tl-screen="boxer">
  <form id="training">
   <label>Trainingsart<select id="kind" required>
    <option value="">Bitte wählen</option><option value="sparring">Sparring</option><option value="technique">Technik</option>
   </select></label>
   <label>Boxer<select id="boxers" multiple>
    <option value="a">Ada</option><option value="b">Bela</option><option value="c">Cem</option>
   </select></label>
  </form>
  <label>Vergleich<select id="compare" data-tl-choice="compare-left" data-tl-choice-hint="Wähle einen Boxer.">
   <option value="">Boxer auswählen</option><option value="d">Dara</option>
  </select></label>
 </body></html>`;
 const dom=new JSDOM(html,{url:'https://example.test/boxer.html',runScripts:'outside-only'});
 const {window}=dom,doc=window.document;
 window.eval(fs.readFileSync('takeover-choice-cards.js','utf8'));
 const kind=doc.getElementById('kind'),boxers=doc.getElementById('boxers'),compare=doc.getElementById('compare');
 const fieldFor=select=>{const label=select.closest('label');return label?label.nextElementSibling:select.nextElementSibling};
 assert.equal(fieldFor(kind).querySelectorAll('.tl-choice-card').length,2,'required placeholder should not become a card');
 assert.equal(kind.closest('label').querySelector('button'),null,'interactive choice buttons must remain outside the native select label');
 let changes=0;kind.addEventListener('change',()=>changes++);
 fieldFor(kind).querySelector('.tl-choice-card[data-value="sparring"]').click();
 assert.equal(kind.value,'sparring','card click must update the original select');
 assert.equal(changes,1,'card click must emit a native change event');
 assert.equal(fieldFor(kind).querySelector('.tl-choice-card[data-value="sparring"]').getAttribute('aria-pressed'),'true');
 for(const value of ['a','b','c'])fieldFor(boxers).querySelector('.tl-choice-card[data-value="'+value+'"]').click();
 assert.equal(boxers.selectedOptions.length,3,'multiple choices must preserve selectedOptions');
 assert.match(fieldFor(boxers).querySelector('.tl-choice-note').textContent,/3 Boxer ausgewählt/);
 assert.equal(fieldFor(compare).querySelectorAll('.tl-choice-card').length,1,'explicit non-form select should be enhanced');
 const hint=fieldFor(compare).querySelector('.tl-choice-hint');
 assert.equal(hint.textContent,'Wähle einen Boxer.');
 assert.equal(fieldFor(compare).querySelector('.tl-choice-track').getAttribute('aria-describedby'),hint.id,'helper text should be associated with the card group');
 const option=window.document.createElement('option');option.value='e';option.textContent='Eli';compare.add(option);
 await new Promise(resolve=>setTimeout(resolve,0));
 assert.equal(fieldFor(compare).querySelectorAll('.tl-choice-card').length,2,'dynamic options should refresh the card rail');
 compare.value='d';compare.dispatchEvent(new window.Event('change',{bubbles:true}));
 assert.equal(fieldFor(compare).querySelector('.tl-choice-card[data-value="d"]').getAttribute('aria-pressed'),'true','programmatic updates with change events should sync the cards');
 const dynamicForm=doc.createElement('form');dynamicForm.innerHTML='<label>Bearbeiten<select name="kind"><option value="individual">Individuell</option><option value="competition">Wettkampf</option></select></label>';
 doc.body.append(dynamicForm);
 await new Promise(resolve=>setTimeout(resolve,0));
 const dynamicSelect=dynamicForm.querySelector('select');
 assert.equal(fieldFor(dynamicSelect).querySelectorAll('.tl-choice-card').length,2,'selects added with dynamic forms should also be enhanced');
 const dynamicExternal=doc.createElement('select');dynamicExternal.setAttribute('data-tl-choice','manager-reward-goal');dynamicExternal.add(new window.Option('Ziel A','a'));doc.body.append(dynamicExternal);
 await new Promise(resolve=>setTimeout(resolve,0));
 assert.equal(dynamicExternal.nextElementSibling.querySelectorAll('.tl-choice-card').length,1,'dynamically inserted explicit non-form choices should be enhanced');
 dom.window.close();
 console.log('PASS: Native select values, change events, multi-select status, helper text and dynamically added forms remain synchronized.');
}
main().catch(error=>{console.error(error);process.exitCode=1});
