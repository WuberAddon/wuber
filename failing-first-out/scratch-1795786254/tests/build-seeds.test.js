// node tests/build-seeds.test.js : the starter list tool against a sample WTF folder
'use strict';
const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const B = require('../tools/build-seeds.js');

const WTF = path.join(__dirname, 'fixtures', 'seeds', 'WTF');
const NOW = 1763420000; // the sample's clock (time()); Old Timer is 39 days older
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'wuber-seeds-'));
const core = path.join(tmp, 'Core.lua');
fs.copyFileSync(path.join(__dirname, '..', 'Wuber', 'Core', 'Base.lua'), core);
let n = 0;
const t = (name, fn) => { fn(); n++; console.log('PASS  ' + name); };

const { lists } = B.main([WTF, '--core', core, '--now', String(NOW)]);
t('drivers from the directory and seen lists, per ruleset, latest first', () => {
  assert.deepStrictEqual(lists['EU-PvE'], ['Bob Stone', 'Dan Driver']);
  assert.deepStrictEqual(lists['EU-PvP'], ['Pvp Lock']);
});
t('no founders, nobody older than 14 days, nobody who opted out, no bad names, no unknown ruleset', () => {
  const all = Object.values(lists).flat();
  for (const bad of ['Anita Lift', 'Old Timer', 'Shy Lock', 'Nowhere Man', 'Evil" Name']) assert.ok(!all.includes(bad), bad);
});
t('a record without a ruleset takes the account\'s (Dan, ACCOUNT1 = EU-PvE); without one at all it is skipped (Nowhere Man)', () => {
  assert.ok(lists['EU-PvE'].includes('Dan Driver'));
});
const text = fs.readFileSync(core, 'utf8');
t('Core.lua rewritten between the markers, the rest unchanged', () => {
  assert.ok(text.includes('\t["EU-PvE"] = { "Bob Stone", "Dan Driver" },'), text.slice(text.indexOf(B.BEGIN), text.indexOf(B.END)));
  assert.ok(text.includes('\t["EU-PvP"] = { "Pvp Lock" },'));
  assert.ok(text.includes('\t["US-HC"] = {},'), 'rulesets already listed stay, empty');
  const orig = fs.readFileSync(path.join(__dirname, '..', 'Wuber', 'Core', 'Base.lua'), 'utf8');
  assert.strictEqual(text.slice(0, text.indexOf(B.BEGIN)), orig.slice(0, orig.indexOf(B.BEGIN)));
  assert.strictEqual(text.slice(text.indexOf(B.END)), orig.slice(orig.indexOf(B.END)));
});
t('running it again changes nothing', () => {
  B.main([WTF, '--core', core, '--now', String(NOW)]);
  assert.strictEqual(fs.readFileSync(core, 'utf8'), text);
});
t('the opt-out wins when it is the newest record, and only then', () => {
  const f = path.join(tmp, 'Opt.lua');
  fs.writeFileSync(f, 'WuberDB = { ["seenDrivers"] = { ["x y"] = { ["name"] = "X Y", ["at"] = ' + (NOW - 10) + ', ["ruleset"] = "EU-PvE", ["unlisted"] = true } },'
    + ' ["directory"] = { ["x y"] = { ["name"] = "X Y", ["lastSeen"] = ' + (NOW - 100) + ', ["ruleset"] = "EU-PvE" }, ["z q"] = { ["name"] = "Z Q", ["lastSeen"] = ' + (NOW - 5) + ', ["ruleset"] = "EU-PvE" } } }');
  assert.deepStrictEqual(B.collect([f], { now: NOW }), { 'EU-PvE': ['Z Q'] });
});
console.log(`\n${n} passed, 0 failed`);
