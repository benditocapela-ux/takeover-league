// Statische Verträge für das Trainingsformular (27.10.2026): Pflicht-Bemerkung, Pflicht-Dauer,
// gruppierte Trainingsarten, Dauer in Meldung und Entwurf, Wettkampfsparring in der Gamification.
const fs = require('fs');
const path = require('path');
const assert = require('assert');
const root = path.join(__dirname, '..');
const read = f => fs.readFileSync(path.join(root, f), 'utf8');

const boxer = read('boxer.html');
assert.match(boxer, /<label for="notes">Bemerkung<\/label><textarea id="notes"[^>]*minlength="3"[^>]*required/, 'Bemerkung muss Pflicht sein (mind. 3 Zeichen)');
assert.doesNotMatch(boxer, /Bemerkung \(optional\)/, 'Bemerkung darf nicht mehr optional heissen');
assert.match(boxer, /<label for="techniqueMinutes">Trainingsdauer \(Minuten\)<\/label><input id="techniqueMinutes"[^>]*required/, 'Trainingsdauer muss Pflicht sein');
assert.match(boxer, /<div id="techniqueField">/, 'Dauerfeld muss immer sichtbar sein');
assert.match(boxer, /duration_minutes:Number\(saved\.techniqueMinutes\)/, 'Meldung muss duration_minutes senden');
assert.match(boxer, /technique_minutes:\/\^techniktraining\$\/i\.test\(type\.name\.trim\(\)\)\?Number\(saved\.techniqueMinutes\):null/, 'Technik-Minuten nur beim Techniktraining');
assert.match(boxer, /Bitte eine Bemerkung zum Training eingeben \(mindestens 3 Zeichen\)\./, 'deutsche Fehlermeldung Bemerkung');
assert.match(boxer, /Bitte die Trainingsdauer in Minuten angeben \(1–1440\)\./, 'deutsche Fehlermeldung Dauer');
assert.match(boxer, /function renderTrainingTypeOptions\(select,list\)\{[^\n]*createElement\('optgroup'\)/, 'Trainingsarten müssen nach Bereich gruppiert werden');
assert.match(boxer, /TRAINING_CATEGORY_ORDER=\['Wettkampf','Boxen','Athletik','Ausdauer','Erholung & Team'\]/, 'Bereichsreihenfolge');
assert.equal((boxer.match(/duration_minutes:mins\?Number\(mins\):null/g) || []).length, 2, 'beide Entwurfs-Speicherwege sichern die Dauer');
assert.match(boxer, /techniqueMinutes:r\.data\.duration_minutes\?\?r\.data\.technique_minutes/, 'Entwurf stellt die Dauer wieder her');

assert.match(boxer, /o\.dataset\.points=String\(type\.points\)/, 'Karten zeigen die Punkte');
assert.match(boxer, /function updateTrainingFavorites\(\)\{/, 'Häufig-Bereich aus dem eigenen Verlauf');
assert.match(boxer, /historyRows=r\.data\|\|\[\];updateTrainingFavorites\(\);/, 'Häufig wird nach dem Laden aktualisiert');
const cards = read('takeover-choice-cards.js');
assert.match(cards, /const FAVORITES='Häufig'/, 'Bereichs-Tasten mit Häufig');
assert.match(cards, /tab\.setAttribute\('role','tab'\)/, 'Bereichs-Tasten sind Tabs');
assert.match(cards, /attributeFilter:\['disabled','label','value','data-tl-favorites'\]/, 'Häufig reagiert auf neue Favoriten');
const css = read('takeover-redesign.css');
assert.match(css, /\.tl-choice-field\.is-grouped \.tl-choice-track\{display:grid;grid-template-columns:minmax\(0,1fr\)/, 'Gruppierte Auswahl als Liste ohne seitliches Scrollen');
assert.match(css, /\.tl-choice-presets \.tl-choice-track\{flex-wrap:wrap;overflow:visible/, 'Schnellwahl ohne seitliches Scrollen');

const coach = read('coach.html');
assert.match(coach, /Dauer: \$\{s\.duration_minutes\} Min\./, 'Trainer sieht die Trainingsdauer');

const gam = read('takeover-gamification.js');
assert.match(gam, /'wettkampfsparring':'sparring'/, 'Wettkampfsparring zählt als Sparring');

const migration = read('supabase/migrations/20261028150000_training_types_duration_notes.sql');
for (const name of ['Wettkampf', 'Trainingslager / Camp-Tag', 'Pratzentraining', 'Sandsack / Rundenarbeit', 'Schattenboxen / Heimtraining',
  'Seilspringen / Konditionszirkel', 'Alternative Ausdauer (Rad, Schwimmen, Rudern)', 'Trainingsassistenz', 'Mobilität / Regeneration']) {
  assert.ok(migration.includes(`'${name}'`), 'Migration enthält ' + name);
}
assert.match(migration, /\('Pratzentraining',35\)/, 'Pratzentraining 35 Punkte (unter Techniktraining 40)');
assert.match(migration, /BEFORE INSERT ON public\.training_submissions/, 'Pflichtprüfung nur für neue Meldungen');
console.log('PASS training form contracts: Bemerkung und Dauer Pflicht, gruppierte Arten, Dauer in Meldung/Entwurf, Wettkampfsparring');
