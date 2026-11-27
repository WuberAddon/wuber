// node --test tools/test   (or: node tools/test/labreport-cleared.test.js)
// r53 item 5: "W BLOCKED cap=nil func=nil" is W.RetryBlocked() (Retry blocked actions), not a blocked action.
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const R = require('../labreport.js');

test('a BLOCKED with no cap and no func is not counted; one with a cap or func still is', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'labcleared-'));
  const sv = path.join(dir, 'WTF', 'Account', 'A', 'SavedVariables');
  fs.mkdirSync(sv, { recursive: true });
  const body = 'WuberLabDB = { ["chars"] = { ["Ana Smith"] = { ["lines"] = {' +
    '"1794943000.100|Ana Smith|block|W BLOCKED cap=nil func=nil",' +
    '"1794943001.100|Ana Smith|block|W BLOCKED cap=nil func=nil",' +
    '"1794943002.100|Ana Smith|block|W BLOCKED cap=\\"chat\\" func=SendChatMessage",' +
    '"1794943003.100|Ana Smith|block|ADDON_ACTION_BLOCKED addon=Wuber func=AcceptTrade()"' +
    '} } }, ["passive"] = { ["sessions"] = { { ["char"] = "Ana Smith", ["started"] = 1794943000, ["ended"] = 1794943100, ["wuber"] = "2.4.2", ["lab"] = "1", ["taint"] = "1", ' +
    '["pass"] = 1, ["fail"] = 3, ["skip"] = 0, ["look"] = 0, ["lines"] = {' +
    '"blocked|Wuber|fail|W BLOCKED cap=nil func=nil|1794943000.100|",' +
    '"blocked|Wuber|fail|W BLOCKED cap=nil func=nil|1794943001.100|",' +
    '"blocked|Wuber|fail|W BLOCKED cap=\\"chat\\" func=SendChatMessage|1794943002.100|" } } },' +
    ' ["release"] = { ["blocked"] = { ["n"] = 1, ["fail"] = { ["at"] = 1794943001, ["why"] = "W BLOCKED cap=nil func=nil", ["wuber"] = "2.4.2", ["subject"] = "Wuber", ["char"] = "Ana Smith" } } } } }';
  fs.writeFileSync(path.join(sv, 'WuberLab.lua'), body);
  const data = R.load(R.findFiles(path.join(dir, 'WTF')));
  const ch = (Array.isArray(data.chars) ? data.chars.find((c) => c.name === 'Ana Smith') : data.chars['Ana Smith']);
  assert.strictEqual(ch.blocked, 2, 'only the two real blocks count');
  assert.strictEqual(ch.cleared, 2);
  const files = R.findFiles(path.join(dir, 'WTF'));
  const txt = R.textReport(data, [], files, new Date());
  assert.ok(!/FAIL blocked Wuber: W BLOCKED cap=nil func=nil/.test(txt), 'no FAIL line for the cleared list');
  assert.ok(/FAIL blocked Wuber: W BLOCKED cap="chat"/.test(txt), 'a real one still fails');
  assert.ok(/blocked list cleared \(Retry\): 2 times/.test(txt), 'shown as an info line');
  assert.ok(!/block W BLOCKED cap=nil func=nil/.test(txt.split('== Rides')[0].split('== Errors and blocked actions')[1] || ''), 'not in the errors list');
  const sess = data.passive.sessions[0];
  assert.strictEqual(sess.fail, 1);
  assert.strictEqual(data.passive.release.blocked.fail, undefined, 'the release checklist does not fail on it');
});
