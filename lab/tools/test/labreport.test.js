// node --test tools/test   (or: node tools/test/labreport.test.js)
// The sample under test/sample/WTF is real output: tests/lab.lua (Wuber's harness) writes it
// with LAB_DUMP=<dir> during a full Ritual Rides ride (four windows, four accounts).
'use strict';

const test = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const zlib = require('zlib');

const R = require('../labreport.js');
// the samples are stored as <sample>/wtf-root/Account/...; a copy named WTF is made in a temp folder
function sampleDir(src) {
  const d = fs.mkdtempSync(path.join(os.tmpdir(), 'lab-sample-'));
  fs.cpSync(path.join(src, 'wtf-root'), path.join(d, 'WTF'), { recursive: true });
  return d;
}
const C = require('../release-check.js');

const SAMPLE = sampleDir(path.join(__dirname, 'sample'));

test('parser: WoW SavedVariables syntax, safely', () => {
  const src = [
    '',
    'WuberLabDB = {',
    '\t["v"] = 1,',
    '\t["chars"] = {',
    '\t\t["Ana Smith"] = {',
    '\t\t\t["lines"] = {',
    '\t\t\t\t"1794943000.123|Ana Smith|mark|say \\"hi\\" \\\\ back\\nslash", -- [1]',
    '\t\t\t\t"1794943001.000|Ana Smith|err|\\195\\169t\\233", -- [2]',
    '\t\t\t},',
    '\t\t\t["dropped"] = -0.5e1,',
    '\t\t\t[3] = true,',
    '\t\t\tplain = nil,',
    '\t\t\t["hex"] = 0x1F,',
    '\t\t\t["long"] = [==[a]]b]==],',
    '\t\t},',
    '\t},',
    '}',
    '--[[ a block comment ]] Other = { 1, 2; 3, [4] = "four", }',
  ].join('\n');
  const g = R.parseLua(Buffer.from(src, 'utf8').toString('latin1'));
  const ana = g.WuberLabDB.chars['Ana Smith'];
  assert.strictEqual(g.WuberLabDB.v, 1);
  assert.deepStrictEqual(ana.lines[0], '1794943000.123|Ana Smith|mark|say "hi" \\ back\nslash');
  assert.ok(ana.lines[1].startsWith('1794943001.000|Ana Smith|err|é'));
  assert.strictEqual(ana.dropped, -5);
  assert.strictEqual(ana['3'], true);
  assert.strictEqual(ana.plain, undefined);
  assert.strictEqual(ana.hex, 31);
  assert.strictEqual(ana.long, 'a]]b');
  assert.deepStrictEqual(g.Other, [1, 2, 3, 'four']);
  // nothing is evaluated: code is a parse error, not run
  assert.throws(() => R.parseLua('X = os.exit(1)'), /unexpected name|expected/);
  assert.throws(() => R.parseLua('X = { "open'), /unfinished/);
});

test('finds the WTF folder from the game folder or the WTF folder', () => {
  assert.strictEqual(R.resolveWTF(SAMPLE), path.join(SAMPLE, 'WTF'));
  assert.strictEqual(R.resolveWTF(path.join(SAMPLE, 'WTF')), path.join(SAMPLE, 'WTF'));
  assert.throws(() => R.resolveWTF(path.join(SAMPLE, 'nope')), /No WTF/);
  const files = R.findFiles(path.join(SAMPLE, 'WTF'));
  assert.deepStrictEqual(files.map((f) => f.account), ['ACCOUNT2K', 'ROCKS1', 'WOW1', 'WOW2']);
});

test('report: merges four accounts, builds the ride, writes html and txt', () => {
  const out = fs.mkdtempSync(path.join(os.tmpdir(), 'labreport-'));
  const r = R.main([SAMPLE, '--out', out, '--now', '2026-11-17T22:05:00']);
  const names = Object.keys(r.data.chars).sort();
  assert.deepStrictEqual(names, ['Anita Lift', 'Farra Way', 'Hayley Cab', 'Wuber Rocks']);
  assert.strictEqual(r.data.chars['Wuber Rocks'].role, 'rider');
  assert.strictEqual(r.data.chars['Anita Lift'].role, 'driver');
  // merged by time
  for (let k = 1; k < r.data.lines.length; k++) assert.ok(r.data.lines[k].t >= r.data.lines[k - 1].t, 'sorted');
  // one ride, seen by the rider and the driver
  assert.strictEqual(r.rides.length, 1);
  const ride = r.rides[0];
  assert.deepStrictEqual([...ride.lanes.keys()].sort(), ['Anita Lift', 'Wuber Rocks']);
  const riderStages = ride.lanes.get('Wuber Rocks').map((e) => e.stage);
  assert.strictEqual(riderStages[0], 'requesting');
  assert.strictEqual(riderStages[riderStages.length - 1], 'done');
  assert.strictEqual(ride.info.final, 'done');
  assert.ok(ride.flags.some((f) => f.text === 'autoAccepted=true'));
  // files
  assert.ok(fs.existsSync(path.join(out, 'lab-20261117-2205.html')));
  const txt = fs.readFileSync(path.join(out, 'lab-latest.txt'), 'utf8');
  assert.match(txt, /Wuber Rocks \[rider\] account ROCKS1/);
  assert.match(txt, /Ride \w{6}: Wuber Rocks -> Anita Lift, Ratchet 5g, ended done/);
  assert.match(txt, /\[fail\] Looks \/ Crown over the team's heads - note: crown sits inside the cow/);
  assert.match(txt, /block ADDON_ACTION_BLOCKED addon=Wuber func=AcceptTrade\(\)/);
  assert.match(txt, /== Last 400 lines/);
  // the shared plan: merged from the four files, last write wins
  assert.match(txt, /== Plan \(\d+\/\d+ ticked\)/);
  assert.match(txt, /\[auto\] Test 2: a full ride, Wuber Rocks to your team \/ Check: Visible WTB whisper reached Anita - [\d:.]+ by Anita Lift \(whisper_wtb_in\)/);
  assert.match(txt, /\[fail\] Test 4: looks and fun \(judged by eye\) \/ On Wuber Rocks, Settings > Turn on friendly nameplates.* by Wuber Rocks \(hand\) - note: crown too small/);
  assert.match(txt, /probes: anita lift ok, farra way ok, hayley cab ok, wuber rocks no/);
  const rows = R.planRows(r.data.plan);
  assert.ok(rows.length >= 50, 'every plan step: ' + rows.length);
  const tail = txt.split('== Last 400 lines')[1].trim().split('\n');
  assert.ok(tail.length > 50 && tail.length <= 401, 'tail lines: ' + tail.length);
  const html = fs.readFileSync(path.join(out, 'lab-20261117-2205.html'), 'utf8');
  assert.match(html, /<h2>Rides \(1\)<\/h2>/);
  assert.match(html, /<h2>Plan \(\d+\/\d+ ticked\)<\/h2>/);
  assert.match(html, /crown too small/);
  assert.match(html, /class="bad"/); // errors and blocked in red
  assert.match(html, /crown sits inside the cow/);
  assert.match(html, /<th>Wuber Rocks<\/th>/); // a lane per character
  assert.ok(!/<script[^>]*src=/.test(html), 'self-contained');
});

test('report: a broken or empty file is reported, not fatal', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'labwtf-'));
  for (const [acc, body] of [['A', 'WuberLabDB = {'], ['B', 'WuberLabDB = { ["chars"] = { ["X Y"] = { ["lines"] = { "nonsense", "12.5|X Y|mark|ok" } } } }']]) {
    const sv = path.join(dir, 'WTF', 'Account', acc, 'SavedVariables');
    fs.mkdirSync(sv, { recursive: true });
    fs.writeFileSync(path.join(sv, 'WuberLab.lua'), body);
  }
  const out = path.join(dir, 'report');
  const r = R.main([dir, '--out', out]);
  assert.strictEqual(r.data.problems.length, 1);
  assert.strictEqual(r.data.lines.length, 1);
  assert.match(fs.readFileSync(path.join(out, 'lab-latest.txt'), 'utf8'), /PROBLEM: .*could not read/);
});

// a minimal zip writer (stored and deflated entries) for the release check
function zip(entries) {
  const locals = [];
  const centrals = [];
  let offset = 0;
  for (const [name, text, deflate] of entries) {
    const data = Buffer.from(text);
    const body = deflate ? zlib.deflateRawSync(data) : data;
    const nameBuf = Buffer.from(name);
    const lh = Buffer.alloc(30);
    lh.writeUInt32LE(0x04034b50, 0);
    lh.writeUInt16LE(20, 4);
    lh.writeUInt16LE(deflate ? 8 : 0, 8);
    lh.writeUInt32LE(body.length, 18);
    lh.writeUInt32LE(data.length, 22);
    lh.writeUInt16LE(nameBuf.length, 26);
    const ch = Buffer.alloc(46);
    ch.writeUInt32LE(0x02014b50, 0);
    ch.writeUInt16LE(20, 4);
    ch.writeUInt16LE(20, 6);
    ch.writeUInt16LE(deflate ? 8 : 0, 10);
    ch.writeUInt32LE(body.length, 20);
    ch.writeUInt32LE(data.length, 24);
    ch.writeUInt16LE(nameBuf.length, 28);
    ch.writeUInt32LE(offset, 42);
    locals.push(lh, nameBuf, body);
    centrals.push(ch, nameBuf);
    offset += 30 + nameBuf.length + body.length;
  }
  const cd = Buffer.concat(centrals);
  const end = Buffer.alloc(22);
  end.writeUInt32LE(0x06054b50, 0);
  end.writeUInt16LE(entries.length, 8);
  end.writeUInt16LE(entries.length, 10);
  end.writeUInt32LE(cd.length, 12);
  end.writeUInt32LE(offset, 16);
  return Buffer.concat([...locals, cd, end]);
}

test('release check: fails on Wuber Lab in a folder or a zip, passes clean ones', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'relcheck-'));
  const clean = path.join(dir, 'clean', 'Wuber');
  fs.mkdirSync(clean, { recursive: true });
  fs.writeFileSync(path.join(clean, 'Wuber.toc'), '## Interface: 16001\nCore.lua\n');
  fs.writeFileSync(path.join(clean, 'Core.lua'), 'local _, W = ...\n-- a label for the window\n');
  assert.deepStrictEqual(C.check(path.join(dir, 'clean')), []);
  // the addon folder itself
  const withLab = path.join(dir, 'withlab');
  fs.mkdirSync(path.join(withLab, 'WuberLab'), { recursive: true });
  fs.writeFileSync(path.join(withLab, 'WuberLab', 'Log.lua'), 'x');
  assert.ok(C.check(withLab).some((p) => /Wuber Lab file or folder/.test(p)));
  // a mention inside a shipped file
  const ref = path.join(dir, 'ref', 'Wuber');
  fs.mkdirSync(ref, { recursive: true });
  fs.writeFileSync(path.join(ref, 'Wuber.toc'), '## Interface: 16001\n## OptionalDeps: WuberLab\nCore.lua\n');
  const refProblems = C.check(path.join(dir, 'ref'));
  assert.ok(refProblems.some((p) => /Wuber.toc: mentions Wuber Lab \(line 2\)/.test(p)), refProblems.join('; '));
  // zips: clean, a lab folder, a deflated mention
  const zClean = path.join(dir, 'clean.zip');
  fs.writeFileSync(zClean, zip([['Wuber/', ''], ['Wuber/Wuber.toc', '## Interface: 16001\n', true], ['Wuber/Core.lua', 'print(1)', false]]));
  assert.deepStrictEqual(C.check(zClean), []);
  const zLab = path.join(dir, 'lab.zip');
  fs.writeFileSync(zLab, zip([['Wuber/Core.lua', 'x', false], ['WuberLab/WuberLab.toc', '## Title: lab', true]]));
  assert.ok(C.check(zLab).length >= 1);
  const zRef = path.join(dir, 'ref.zip');
  fs.writeFileSync(zRef, zip([['Wuber/Core.lua', 'if WuberLab then end', true]]));
  assert.ok(C.check(zRef).some((p) => /Core.lua: mentions Wuber Lab/.test(p)));
  // the real addons are clean, the lab is not
  assert.deepStrictEqual(C.check('wuber/Wuber').length === 0 || !fs.existsSync('wuber/Wuber'), true);
  assert.ok(C.check(path.join(__dirname, '..', '..', 'WuberLab')).length > 0);
});

test('plan merge: newest write wins across accounts, a reset drops older ones', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'labplan-'));
  const files = {
    A: 'WuberLabDB = { ["chars"] = {}, ["planSteps"] = { { ["id"] = "x1", ["sec"] = "S", ["text"] = "Step one" }, { ["id"] = "x2", ["sec"] = "S", ["text"] = "Step two" } }, ' +
      '["plan"] = { ["x1"] = { ["r"] = "pass", ["at"] = 100, ["who"] = "Anita Lift" }, ["x2"] = { ["r"] = "auto", ["at"] = 50, ["who"] = "Anita Lift" } } }',
    B: 'WuberLabDB = { ["chars"] = {}, ["plan"] = { ["x1"] = { ["r"] = "fail", ["at"] = 200, ["who"] = "Wuber Rocks", ["note"] = "late" }, ["_reset"] = { ["at"] = 60 } } }',
  };
  for (const [acc, body] of Object.entries(files)) {
    const sv = path.join(dir, 'WTF', 'Account', acc, 'SavedVariables');
    fs.mkdirSync(sv, { recursive: true });
    fs.writeFileSync(path.join(sv, 'WuberLab.lua'), body);
  }
  const data = R.load(R.findFiles(path.join(dir, 'WTF')));
  const rows = R.planRows(data.plan);
  assert.strictEqual(rows[0].rec.r, 'fail');
  assert.strictEqual(rows[0].rec.note, 'late');
  assert.strictEqual(rows[1].rec, null, 'older than the reset');
});

// The sample under test/sample-run/WTF is real output too: tests/lab_run.lua writes it with
// LAB_DUMP_RUN=<dir> after a whole test run on four windows (test mode, no shards).
const SAMPLE_RUN = sampleDir(path.join(__dirname, 'sample-run'));

test('test run: the four windows\' files become one plain-English run summary and the login checks', () => {
  const out = fs.mkdtempSync(path.join(os.tmpdir(), 'labrun-'));
  const r = R.main([SAMPLE_RUN, '--out', out, '--now', '2026-11-18T21:00:00']);
  assert.strictEqual(r.data.runs.length, 1, 'one run (the same run in all four files)');
  const run = r.data.runs[0];
  assert.strictEqual(run.by, 'Anita Lift');
  assert.strictEqual(run.why, 'done');
  assert.ok(run.sim, 'test mode');
  assert.strictEqual(run.fail, 0);
  assert.strictEqual(run.todo, 0);
  assert.strictEqual(run.look, 1);
  assert.ok(run.pass >= 30, 'passed: ' + run.pass);
  assert.strictEqual(run.checks[0].id, 'ride_open');
  assert.strictEqual(run.checks[run.checks.length - 1].id, 'photo_tour', 'the photo tour last');
  assert.ok(run.checks.some((c) => c.id === 'raid_one' && c.r === 'pass'), 'two summoners never took the same raider');
  for (const c of run.checks) {
    assert.ok(['pass', 'fail', 'look', 'skip', 'todo'].includes(c.r), c.id + ' ' + c.r);
    assert.ok(c.who && c.why && c.title, c.id + ': window, reason and title');
    if (c.r !== 'todo') assert.ok(c.at > 1.7e9, c.id + ': when');
  }
  const names = Object.keys(r.data.login).sort();
  assert.deepStrictEqual(names, ['Anita Lift', 'Farra Way', 'Hayley Cab', 'Wuber Rocks']);
  for (const n of names) {
    const ids = r.data.login[n].checks.map((c) => c.id);
    for (const id of ['login_wuber', 'login_channel', 'login_prefixes', 'login_flights', 'login_button', 'login_settings', 'login_versions', 'login_saved']) {
      assert.ok(ids.includes(id), `${n}: ${id}`);
    }
    assert.ok(!r.data.login[n].checks.some((c) => c.r === 'fail'), `${n}: no login fail`);
  }
  const txt = fs.readFileSync(path.join(out, 'lab-latest.txt'), 'utf8');
  assert.match(txt, /^== Test run \(the newest test run: .* started by Anita Lift, test mode \(no shards\), Wuber [\d.]+, lab [\d.]+\)$/m);
  assert.match(txt, /^It ran to the end at [\d:]+\. \d+ checks: \d+ passed, 0 failed, 1 to look at, 4 skipped, 0 not reached\.$/m);
  assert.match(txt, /^Every check that ran passed by itself\.$/m);
  assert.match(txt, /^ {2}- Earnings \(look\) \(ride_earnings\) on Anita's window: screenshot 1/m);
  assert.match(txt, /^ {2}\[pass\] raid_cast - Anita [\d.]+s - Anita summons the raider: Anita's ritual started on Wuber Rocks/m);
  assert.match(txt, /^Wuber Rocks \(login .*\): all \d+ passed, \d+ skipped$/m);
  assert.ok(txt.indexOf('== Test run') < txt.indexOf('== Characters'), 'the run comes first');
  const html = fs.readFileSync(path.join(out, 'lab-20261118-2100.html'), 'utf8');
  assert.match(html, /<h2>Test run \(\d+ passed, 0 failed, 1 to look at, 4 skipped, 0 not reached\)<\/h2>/);
  assert.match(html, /<h2>Login checks<\/h2>/);
});

test('test run: fails, steps not reached, a stopped run and older runs read plainly', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'labrun2-'));
  const runA = '{ ["sid"] = "aa1", ["by"] = "Anita Lift", ["started"] = 1795000000, ["ended"] = 1795000300, ["why"] = "done", ["wuber"] = "2.2.1", ["lab"] = "1.1.0", ' +
    '["lines"] = { "ride_open|Anita Lift|pass|open, selling at 50s|1795000010.000|4.2|Anita Lift|Anita open" } }';
  const runB = '{ ["sid"] = "bb2", ["by"] = "Wuber Rocks", ["started"] = 1795001000, ["ended"] = 1795001200, ["why"] = "stopped by the tester", ["wuber"] = "2.2.1", ["lab"] = "1.1.0", ' +
    '["lines"] = { "ride_open|Anita Lift|pass|open|1795001010.000|3.0|Anita Lift|Anita open", ' +
    '"ride_trade|Wuber Rocks|fail|put in 40s, the fare is 50s|1795001100.000|61.5|Wuber Rocks|Rider pays", ' +
    '"ride_paid|Anita Lift|todo|click the big button (it says {button})||||Anita takes the fare" } }';
  // the rider's copy of run bb2 got less far: the furthest copy wins
  const runBshort = '{ ["sid"] = "bb2", ["by"] = "Wuber Rocks", ["started"] = 1795001000, ["lines"] = { "ride_open|Anita Lift|todo|x||||Anita open", ' +
    '"ride_trade|Wuber Rocks|todo|x||||Rider pays", "ride_paid|Anita Lift|todo|x||||Anita takes the fare" } }';
  const files = {
    A: `WuberLabDB = { ["chars"] = {}, ["runs"] = { ${runA}, ${runB} }, ["login"] = { ["Anita Lift"] = { ["at"] = 1795000000, ["wuber"] = "2.2.1", ` +
      '["lines"] = { "login_channel|fail|not on Wuber\'s channel after 60 s|1795000060.000|60.0", "login_saved|pass|the marker came back|1795000005.000|0.0" } } } }',
    B: `WuberLabDB = { ["chars"] = {}, ["runs"] = { ${runBshort} } }`,
  };
  for (const [acc, body] of Object.entries(files)) {
    const sv = path.join(dir, 'WTF', 'Account', acc, 'SavedVariables');
    fs.mkdirSync(sv, { recursive: true });
    fs.writeFileSync(path.join(sv, 'WuberLab.lua'), body);
  }
  const data = R.load(R.findFiles(path.join(dir, 'WTF')));
  assert.strictEqual(data.runs.length, 2);
  const txt = R.runText(data).join('\n');
  assert.match(txt, /started by Wuber Rocks/);
  assert.match(txt, /It was stopped \(stopped by the tester\) at [\d:]+\. 3 checks: 1 passed, 1 failed, 0 to look at, 0 skipped, 1 not reached\./);
  assert.match(txt, /Failed:\n {2}- Rider pays \(ride_trade\) on Wuber Rocks's window: put in 40s, the fare is 50s \(after 61\.5 s\)/);
  assert.match(txt, /Not reached:\n {2}- Anita takes the fare \(ride_paid\) on Anita's window: click the big button/);
  assert.ok(!/Every check that ran passed/.test(txt));
  assert.match(txt, /Earlier runs:\n {2}.* by Anita Lift: 1 passed, 0 failed, 0 to look at, 0 skipped, 0 not reached$/m);
  assert.match(txt, /Anita Lift \(login .*\): 1 of 2 FAILED\n {2}FAIL login_channel: not on Wuber's channel after 60 s/);
  // nothing saved yet
  const none = R.runText({ runs: [], login: {} }).join('\n');
  assert.match(none, /No test run saved yet/);
  assert.match(none, /No login checks saved yet/);
});

test('photo tour: shots matched to Screenshots files by time (within 2 s), none twice', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'labtour-'));
  const base = Math.floor(new Date(2026, 10, 19, 14, 30, 0).getTime() / 1000);
  const sv = path.join(dir, '_forever_', 'WTF', 'Account', 'T1', 'SavedVariables');
  fs.mkdirSync(sv, { recursive: true });
  const shot = (n, id, view, at) => `{ ["n"] = ${n}, ["id"] = "${id}", ["title"] = "Title ${id}", ["view"] = "${view}", ["at"] = ${at} }`;
  fs.writeFileSync(path.join(sv, 'WuberLab.lua'), `WuberLabDB = { ["chars"] = { ["Anita Lift"] = { ["lines"] = {} } }, ["photoTour"] = { ["started"] = ${base}, ["ended"] = ${base + 20}, ["shots"] = { ` +
    [shot(1, 'rider_home', 'folded', base + 1.4), shot(2, 'rider_home', 'unfolded', base + 3.2), shot(3, 'driver_tab', 'folded', base + 5.9),
      shot(4, 'driver_tab', 'unfolded', base + 7.5), shot(5, 'late', 'folded', base + 9.5)].join(', ') + ' } } }');
  const shots = path.join(dir, '_forever_', 'Screenshots');
  fs.mkdirSync(shots);
  const mk = (at) => fs.writeFileSync(path.join(shots, R.shotName(at)), 'x');
  mk(base + 2);       // shot 1 (0.6 s off)
  mk(base + 3);       // shot 2
  mk(base + 4);       // 2.0 s from shot 2 floor(3)+... also 1 s from shot 3 (floor 5): shot 3 takes it
  mk(base + 7);       // shot 4
  fs.writeFileSync(path.join(shots, 'notashot.jpg'), 'x');
  const files = R.findFiles(path.join(dir, '_forever_', 'WTF'));
  const data = R.load(files);
  data.shotsDir = shots;
  assert.strictEqual(data.photoTour.shots.length, 5);
  const rows = R.photoRows(data.photoTour, shots);
  assert.deepStrictEqual(rows.map((r) => r.file), [R.shotName(base + 2), R.shotName(base + 3), R.shotName(base + 4), R.shotName(base + 7), null]);
  assert.strictEqual(new Set(rows.filter((r) => r.file).map((r) => r.file)).size, 4);
  assert.match(rows[0].expected, /^WoWScrnShot_\d{6}_\d{6}\.jpg$/);
  const txt = R.tourText(data).join('\n');
  assert.match(txt, /== Photo tour/);
  assert.match(txt, /5 shots, 4 with a file, 1 with no file/);
  assert.match(txt, /1 \| rider_home \| Title rider_home \| folded \| WoWScrnShot_/);
  assert.match(txt, new RegExp('5 \\| late \\| Title late \\| folded \\| no file \\(expected ' + R.shotName(base + 9.5)));
  const html = R.htmlReport(data, [], files, new Date());
  assert.match(html, /<h2>Photo tour<\/h2>/);
  assert.match(html, /no file <span class="muted">\(expected /);
  assert.match(R.textReport(data, [], files, new Date()), /== Photo tour/);
  // no Screenshots folder: every shot says no file
  data.shotsDir = path.join(dir, 'missing');
  assert.match(R.tourText(data).join('\n'), /0 with a file, 5 with no file/);
  // main() with --shots
  const r = R.main([path.join(dir, '_forever_'), '--out', path.join(dir, 'out'), '--shots', shots]);
  assert.match(fs.readFileSync(r.txtPath, 'utf8'), /4 with a file, 1 with no file/);
});

test('photo tour: falls back to the timeline lines after the last "tour start"', () => {
  const t = 1795000000;
  const L = (k, kind, text) => ({ t: t + k, char: 'A', kind, text, seq: k });
  const tour = R.findFiles ? null : null;
  const data = { photoTour: null, lines: [
    L(0, 'photo', 'tour start 2 shots'), L(1, 'photo', 'tour shot 1/2 old_a folded | Old A'),
    L(10, 'photo', 'tour start 2 shots'), L(11.25, 'photo', 'tour shot 1/2 new_a folded | New A'),
    L(13, 'mark', 'x'), L(14, 'photo', 'tour shot 2/2 new_a unfolded / New A'), L(15, 'photo', 'tour end') ] };
  const got = R.findTour({}, data.lines);
  assert.strictEqual(got.source, 'timeline');
  assert.deepStrictEqual(got.shots.map((s) => [s.n, s.id, s.view, s.title]), [[1, 'new_a', 'folded', 'New A'], [2, 'new_a', 'unfolded', 'New A']]);
  assert.strictEqual(R.findTour({}, []), null);
  assert.match(R.tourText({ photoTour: null }).join('\n'), /No photo tour saved yet/);
});

test('passive play: the sessions, their fails, and the release checklist as passive play saw it', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'labpassive-'));
  const sv = path.join(dir, '_forever_', 'WTF', 'Account', 'ROCKS1', 'SavedVariables');
  fs.mkdirSync(sv, { recursive: true });
  const t = 1795000000;
  const line = (kind, subject, r, why, at) => `"${kind}|${subject}|${r}|${why}|${at}|1.0"`;
  fs.writeFileSync(path.join(sv, 'WuberLab.lua'), `WuberLabDB = { ["chars"] = { ["Wuber Rocks"] = { ["lines"] = {} } }, ["passive"] = { ["on"] = true, ` +
    `["sessions"] = { { ["char"] = "Wuber Rocks", ["started"] = ${t}, ["ended"] = ${t + 3600}, ["wuber"] = "2.3.2-dev", ["lab"] = "1.3.0", ["taint"] = "1", ` +
    `["pass"] = 2, ["fail"] = 1, ["skip"] = 1, ["look"] = 0, ["lines"] = { ` +
    [line('ride', 'Anita Lift to Ratchet', 'pass', 'done, paid 50s', t + 100), line('trade', 'Anita Lift', 'fail', 'paid 50s; Wuber did not count it', t + 200),
      line('tour', 'Wuber 2.3.2-dev', 'pass', '69 of 69 screenshots', t + 300), line('ride', 'Anita Lift to Gadgetzan', 'skip', 'cancelled', t + 400)].join(', ') +
    ` } } }, ["release"] = { ["ride"] = { ["n"] = 2, ["pass"] = { ["at"] = ${t + 100}, ["why"] = "done, paid 50s", ["wuber"] = "2.3.2-dev", ["char"] = "Wuber Rocks" } }, ` +
    `["trade"] = { ["n"] = 1, ["fail"] = { ["at"] = ${t + 200}, ["why"] = "paid 50s; Wuber did not count it", ["wuber"] = "2.3.2-dev", ["char"] = "Wuber Rocks" } }, ` +
    `["tour"] = { ["n"] = 1, ["pass"] = { ["at"] = ${t + 300}, ["why"] = "69 of 69 screenshots", ["wuber"] = "2.3.2-dev", ["char"] = "Wuber Rocks" } } } } }`);
  const files = R.findFiles(path.join(dir, '_forever_', 'WTF'));
  const data = R.load(files);
  assert.strictEqual(data.passive.sessions.length, 1);
  assert.deepStrictEqual(data.passive.on, ['ROCKS1']);
  const txt = R.passiveText(data).join('\n');
  assert.match(txt, /== Passive play/);
  assert.match(txt, /\[x\] A real ride ended as done[^\n]*done, paid 50s/);
  assert.match(txt, /\[!\] A real trade[^\n]*FAILED last: paid 50s; Wuber did not count it/);
  assert.match(txt, /\[x\] Photo tour[^\n]*69 of 69/);
  assert.match(txt, /\[ \] A real portal click[^\n]*not seen yet/);
  assert.match(txt, /Wuber Rocks [^\n]*Wuber 2\.3\.2-dev, taint log 1: 2 passed, 1 FAILED, 1 skipped/);
  assert.match(txt, /FAIL trade Anita Lift: paid 50s; Wuber did not count it/);
  assert.match(txt, /passed: ride 1, tour 1/);
  assert.match(R.textReport(data, [], files, new Date()), /== Passive play/);
  assert.match(R.htmlReport(data, [], files, new Date()), /<h2>Passive play<\/h2>/);
  // never on: one plain line
  assert.match(R.passiveText({ passive: { on: [], sessions: [], release: {} } }).join('\n'), /Passive play was never on/);
  fs.rmSync(dir, { recursive: true, force: true });
});

test('blocked actions come from the game taint.log, listed by file and line', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'labtaint-'));
  const log = path.join(dir, 'taint.log');
  fs.writeFileSync(log, [
    '11/19 10:12:03.957  An action was blocked because of taint from Wuber - ',
    '11/19 10:12:03.957      pcall()',
    '11/19 10:12:03.957      Interface/AddOns/Wuber/Drive/Danger.lua:165 listen()',
    '11/19 10:12:03.957      Interface/AddOns/Wuber/Core/Runtime.lua:75',
    '11/19 10:13:03.957  An action was blocked because of taint from Wuber - ',
    '11/19 10:13:03.957      Interface/AddOns/Wuber/Drive/Danger.lua:165 listen()',
  ].join('\n'));
  const txt = R.blockedText({ taintLog: R.readTaintLog(log) }).join('\n');
  assert.match(txt, /2 blocked actions logged/);
  assert.match(txt, /Wuber Wuber\/Drive\/Danger\.lua:165 listen\(\): 2x, last 11\/19 10:13:03\.957/);
  assert.match(R.blockedText({ taintLog: R.readTaintLog(path.join(dir, 'none.log')) }).join('\n'), /\/console taintLog 1/);
  fs.rmSync(dir, { recursive: true, force: true });
});

// (job 105c) The sample under test/sample-auto is real output: lab/test/autocheck_test.lua (Wuber's fake game) writes the
// WuberLabDB.autoCheck of a whole "/lab auto" there.
test('auto check: the saved run reads as passed / need a look, by manual step, with each screen\'s screenshot', () => {
  const SAMPLE_AUTO = sampleDir(path.join(__dirname, 'sample-auto'));
  const files = R.findFiles(path.join(SAMPLE_AUTO, 'WTF'));
  assert.strictEqual(files.length, 1, 'the sample is there (run lab/test/autocheck_test.lua once)');
  const data = R.load(files);
  const a = data.autoCheck;
  assert.ok(a, 'autoCheck read');
  assert.ok(a.screens.length >= 100, 'every screen: ' + a.screens.length);
  assert.strictEqual(a.done, a.screens.length);
  assert.ok(a.counts.pass > 500 && a.counts.look < 60, JSON.stringify(a.counts));
  assert.strictEqual(a.steps['HUNT-72'], 'pass');
  assert.strictEqual(a.steps['REV-r25-1'], 'pass');
  // a Screenshots folder with the first two screens' files
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'labauto-'));
  const shots = path.join(dir, 'Screenshots');
  fs.mkdirSync(shots);
  for (const s of a.shots.slice(0, 2)) fs.writeFileSync(path.join(shots, R.shotName(s.at)), 'x');
  data.shotsDir = shots;
  const lines = R.autoText(data);
  const txt = lines.join('\n');
  assert.match(txt, /^== Auto check/);
  assert.match(txt, /The last run: .* Anita Lift, Wuber 2\.\d+/);
  assert.match(txt, new RegExp('Result: ' + a.counts.pass + ' passed, ' + a.counts.look + ' need a look, ' + a.counts.skip + ' skipped'));
  assert.match(txt, /Manual steps it stood in for.*: \d+ done by the game/);
  assert.match(txt, /done by the game \(passed\): .*AUD-148.*HUNT-72/);
  assert.match(txt, /\[pass\] a_wide_reset unfolded \| verify \| steps HUNT-72 \| toast, pill on Auto, page wide again/);
  assert.match(txt, /Every screen \(# \| id \| view/);
  const first = a.screens[0];
  assert.ok(lines.some((l) => l.startsWith('  ' + first.n + ' | ' + first.id + ' | ' + first.view + ' | ') && l.endsWith(R.shotName(a.shots[0].at))), 'the first screen with its file');
  assert.ok(lines.some((l) => /\| no file \(expected WoWScrnShot_\d{6}_\d{6}\.jpg\)$/.test(l)), 'a screen with no file says the expected name');
  // the same finding on many screens is one thing
  const looks = a.results.filter((r) => r.status === 'look');
  const groups = R.autoGroups(looks);
  assert.ok(groups.length <= looks.length);
  if (looks.length) assert.match(txt, new RegExp('Need a look \\(' + looks.length + ' results, ' + groups.length + ' different things\\):'));
  // in the whole report, text and html
  const whole = R.textReport(data, [], files, new Date());
  assert.ok(whole.indexOf('== Auto check') > 0 && whole.indexOf('== Auto check') < whole.indexOf('== Photo tour'), 'before the photo tour');
  const html = R.htmlReport(data, [], files, new Date());
  assert.match(html, /<h2>Auto check<\/h2>/);
  assert.match(html, /HUNT-72 pass/);
  // (job 2603) the steps the Auto check took over in 2603 are named in the lists, text and html
  const named = JSON.parse(JSON.stringify(data));
  Object.assign(named.autoCheck.steps, { 'GL-01': 'skip', 'GL-02': 'pass', 'GL-03': 'look', 'GL-04': 'pass' });
  const ntxt = R.autoText(named).join('\n');
  assert.match(ntxt, /done by the game \(passed\): .*GL-02 \(the back arrow in Settings goes back to the page before/);
  assert.match(ntxt, /NEED A LOOK: .*GL-03 \(the Ride page's portal turns smoothly/);
  assert.match(ntxt, /do these by hand\): .*GL-01 \(Options > AddOns > Wuber/);
  assert.match(R.htmlReport(named, [], files, new Date()), /GL-04 \(the Key Bindings entry/);
  assert.strictEqual(R.stepLabel('HUNT-72'), 'HUNT-72', 'an id with no name stays as it is');
  // nothing saved; a run stopped early; a step that needs a look and one skipped
  assert.match(R.autoText({ autoCheck: null }).join('\n'), /No Auto check saved yet/);
  const sv = path.join(dir, '_forever_', 'WTF', 'Account', 'T1', 'SavedVariables');
  fs.mkdirSync(sv, { recursive: true });
  fs.writeFileSync(path.join(sv, 'WuberLab.lua'), 'WuberLabDB = { ["chars"] = { ["Anita Lift"] = { ["lines"] = {} } }, ["autoCheck"] = { ["v"] = 1, ["started"] = 1795300000, ["ended"] = 1795300060, ' +
    '["char"] = "Anita Lift", ["wuber"] = "2.3.4-dev", ["lab"] = "1.2.0", ["reason"] = "a click", ["planned"] = 160, ["done"] = 2, ["minutes"] = 1, ["taintLog"] = "0", ' +
    '["counts"] = { ["pass"] = 12, ["look"] = 2, ["skip"] = 1, ["info"] = 0 }, ["steps"] = { ["HUNT-72"] = "look", ["AUD-172"] = "skip", ["AUD-148"] = "pass" }, ' +
    '["screens"] = { { ["id"] = "home", ["view"] = "folded", ["title"] = "Rider home", ["n"] = 1, ["at"] = 1795300002.5, ["pass"] = "cut offscreen overlap under buttons scrollbar", ["texts"] = 20, ["tips"] = 5, ["secure"] = 0, ["scans"] = 1 } }, ' +
    '["results"] = { { ["id"] = "home", ["view"] = "folded", ["kind"] = "tooltips", ["status"] = "look", ["detail"] = "tooltip of X: line cut: \\"abc\\"" }, ' +
    '{ ["id"] = "a_wide_reset", ["view"] = "unfolded", ["kind"] = "verify", ["status"] = "look", ["detail"] = "no toast", ["steps"] = "HUNT-72" }, ' +
    '{ ["id"] = "a_size", ["view"] = "folded", ["kind"] = "screen", ["status"] = "skip", ["detail"] = "settings didn\'t open", ["steps"] = "AUD-172" } }, ' +
    '["shots"] = { { ["n"] = 1, ["id"] = "home", ["view"] = "folded", ["at"] = 1795300002.5 } } } }');
  const d2 = R.load(R.findFiles(path.join(dir, '_forever_', 'WTF')));
  const t2 = R.autoText(d2).join('\n');
  assert.match(t2, /STOPPED EARLY \(a click\)/);
  assert.match(t2, /2 of 160 screens/);
  assert.match(t2, /NEED A LOOK: HUNT-72/);
  assert.match(t2, /not done this time \(skipped: do these by hand\): AUD-172/);
  assert.match(t2, /done by the game \(passed\): AUD-148/);
  assert.match(t2, /The taint log was OFF during the run/);
  assert.match(t2, /\[look\] tooltips \| tooltip of X: line cut: "abc" \| on 1 screen: home folded/);
  assert.match(t2, /\[skip\] a_size folded \| screen \| steps AUD-172 \| settings didn't open/);
  assert.match(t2, /1 \| home \| folded \| 6\/7 \| tooltips \|/);
});

test('game facts: one line per check with its newest answer and entry count, "not seen yet" for a passive check with none, in text, console parts and html', () => {
  const SAMPLE_FACTS = sampleDir(path.join(__dirname, 'sample-facts'));
  const files = R.findFiles(path.join(SAMPLE_FACTS, 'WTF'));
  assert.strictEqual(files.length, 1, 'the sample is there (run lab/test/gamefacts_test.lua once)');
  const data = R.load(files);
  const lines = R.factsText(data);
  const txt = lines.join('\n');
  assert.match(txt, /^== Game facts/);
  // every known check has exactly one line, in the Lab's order
  for (const [id, title] of R.FACT_IDS) {
    assert.strictEqual(lines.filter((l) => l.startsWith('  ' + id + ' | ' + title + ' | ')).length, 1, 'a line for ' + id);
  }
  assert.match(txt, /\n  L7 \| Spellbook after login \| ritual 698: .* \| 1 entry \| /);
  assert.match(txt, /\n  L10 \| Send result codes \| \d+ send result codes: .*Success/);
  assert.match(txt, /\n  L6 \| Summoner name \| summoner name: name after \d+ ms \| 1 entry/);
  assert.match(txt, /\n  L1 \| Summon state \| unit party1: status 2/);
  assert.match(txt, /\| 3 entries \| /);
  // a passive check with no entry says "not seen yet"; one that needs the moment says "not run yet"
  assert.match(txt, /\n  L12\.whisper \| Whisper name and GUID \| not seen yet\n/);
  assert.match(txt, /\n  B18 \| Can I remove\? \| not run yet\n/);
  assert.match(txt, /\n  B16 \| Flight map facts \| not run yet\n  LINE \| Test lines sent \| not run yet\n  LINE\.reply \| Reply whisper shape \| not run yet$/);
  // the whole report: after the Auto check, before the photo tour; and the html
  const whole = R.textReport(data, [], files, new Date());
  assert.ok(whole.indexOf('== Auto check') < whole.indexOf('== Game facts') && whole.indexOf('== Game facts') < whole.indexOf('== Photo tour'), 'between Auto check and the photo tour');
  const html = R.htmlReport(data, [], files, new Date());
  assert.match(html, /<h2>Game facts<\/h2>/);
  assert.match(html, /<td>L12\.whisper<\/td><td>Whisper name and GUID<\/td><td class="muted">passive<\/td><td class="muted">not seen yet<\/td><td>0<\/td>/);
  // nothing saved
  assert.match(R.factsText({ facts: {} }).join('\n'), /No Game facts saved yet/);
  assert.match(R.factsHtml({}), /No Game facts saved yet/);
  // two accounts: the newest answer wins, the entries add up, an id the report does not know is still listed
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'labfacts-'));
  for (const [acct, t, line] of [['A1', 1795300000, 'older answer'], ['A2', 1795300500, 'newer answer']]) {
    const sv = path.join(dir, '_forever_', 'WTF', 'Account', acct, 'SavedVariables');
    fs.mkdirSync(sv, { recursive: true });
    fs.writeFileSync(path.join(sv, 'WuberLab.lua'), 'WuberLabDB = { ["chars"] = { ["Anita Lift"] = { ["lines"] = {} } }, ["facts"] = { ["L6"] = { { ["t"] = ' + t +
      ', ["build"] = "1.60.1 (71037)", ["line"] = "' + line + '", ["a"] = { ["result"] = "name" } } }, ["Z9"] = { { ["t"] = ' + t + ', ["build"] = "b", ["line"] = "from a newer lab" } } } }');
  }
  const d2 = R.load(R.findFiles(path.join(dir, '_forever_', 'WTF')));
  const t2 = R.factsText(d2).join('\n');
  assert.match(t2, /\n  L6 \| Summoner name \| newer answer \| 2 entries \| /);
  assert.ok(!/older answer/.test(t2), 'the older answer is not shown');
  assert.match(t2, /\n  Z9 \| Z9 \| from a newer lab \| 2 entries \| /);
  assert.ok(!/No Game facts saved yet/.test(t2));
});


test('slide check: "== Slide check" part: not answered yet, then the answer, the build and the numbers (text, report order, html); the Game facts part does not list it twice', () => {
  assert.match(R.slideText({ facts: {} }).join('\n'), /^== Slide check .*\n+Not answered yet/);
  assert.match(R.slideHtml({}), /Not answered yet/);
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'labslide-'));
  const sv = path.join(dir, '_forever_', 'WTF', 'Account', 'A1', 'SavedVariables');
  fs.mkdirSync(sv, { recursive: true });
  const entry = (t, answer) => '{ ["t"] = ' + t + ', ["build"] = "1.60.1 (71037)", ["line"] = "move 1 (Translation, half-way): x", ["a"] = { ["answer"] = "' + answer +
    '", ["runs"] = 2, ["shots"] = { "taken", "taken", "blocked" }, ["moves"] = { { ["groupProgress"] = 0.5, ["groupPaused"] = true, ["clips"] = true, ["layoutOutside"] = 180, ' +
    '["page"] = { ["left"] = 540.5, ["right"] = 900.5 }, ["box"] = { ["left"] = 360.5, ["right"] = 720.5 } } } } }';
  fs.writeFileSync(path.join(sv, 'WuberLab.lua'), 'WuberLabDB = { ["chars"] = { ["Anita Lift"] = { ["lines"] = {} } }, ["facts"] = { ["slide"] = { ' + entry(1795300000, 'stuck') + ', ' + entry(1795300500, 'cut') + ' } } }');
  const files = R.findFiles(path.join(dir, '_forever_', 'WTF'));
  const data = R.load(files);
  const txt = R.slideText(data).join('\n');
  assert.match(txt, /\n  Answer: Cut off \(Cut off: pages may slide by Translation\)/);
  assert.match(txt, /\n  Build: 1\.60\.1 \(71037\) \| .* \| 2 entries \| runs in that session: 2/);
  assert.match(txt, /\n  Numbers: move 1 hold: group progress 0\.5, paused true, page left 540\.5 right 900\.5, box left 360\.5 right 720\.5, DoesClipChildren true, outside by layout 180/);
  assert.match(txt, /\n  Screenshots: move 1 taken, move 2 taken, move 3 blocked/);
  assert.match(txt, /\n  Before that: stuck .* : the two answers differ/);
  const whole = R.textReport(data, [], files, new Date());
  assert.ok(whole.indexOf('== Game facts') < whole.indexOf('== Slide check') && whole.indexOf('== Slide check') < whole.indexOf('== Photo tour'), 'after Game facts, before the photo tour');
  assert.ok(!/\n  slide \| slide \|/.test(whole), 'not listed twice as an unknown Game facts id');
  assert.match(R.htmlReport(data, [], files, new Date()), /<h2>Slide check<\/h2><p><b>Cut off<\/b>/);
});

// (speed job 2749) The Auto check's timing pass: WuberLabDB.autoCheck.speed -> the "Speed" section
test('speed: the timing pass reads as one row per screen change and the total memory; no pass says so', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'labspeed-'));
  const sv = path.join(dir, '_forever_', 'WTF', 'Account', 'T1', 'SavedVariables');
  fs.mkdirSync(sv, { recursive: true });
  fs.writeFileSync(path.join(sv, 'WuberLab.lua'), 'WuberLabDB = { ["chars"] = { ["Anita Lift"] = { ["lines"] = {} } }, ["autoCheck"] = { ["v"] = 1, ["started"] = 1795300000, ["ended"] = 1795300060, ' +
    '["char"] = "Anita Lift", ["counts"] = { ["pass"] = 1, ["look"] = 0, ["skip"] = 0, ["info"] = 0 }, ["screens"] = {}, ["results"] = {}, ["steps"] = {}, ["shots"] = {}, ' +
    '["speed"] = { ["v"] = 1, ["startKB"] = 2048.25, ["endKB"] = 2300.25, ["rows"] = { ' +
    '{ ["id"] = "open1", ["label"] = "open the window", ["ms"] = 12.345, ["frame"] = 48.2, ["frames"] = 60, ["kb"] = 150.4, ["kbEnd"] = 90 }, ' +
    '{ ["id"] = "close1", ["label"] = "close the window", ["ms"] = 0.5, ["frame"] = 17, ["frames"] = 60, ["kb"] = -20.6, ["kbEnd"] = -30 } } } } }');
  const data = R.load(R.findFiles(path.join(dir, '_forever_', 'WTF')));
  const txt = R.speedText(data).join('\n');
  assert.match(txt, /^== Speed/);
  assert.match(txt, /open1 \| open the window \| 12\.3 ms \| worst frame 48\.2 ms \| \+150 KB/);
  assert.match(txt, /close1 \| close the window \| 0\.5 ms \| worst frame 17\.0 ms \| -21 KB/);
  assert.match(txt, /total memory: 2048 KB at the start, 2300 KB at the end \(\+252 KB over the pass\)/);
  const whole = R.textReport(data, [], R.findFiles(path.join(dir, '_forever_', 'WTF')), new Date());
  assert.ok(whole.indexOf('== Speed') > whole.indexOf('== Auto check'), 'the Speed section follows the Auto check');
  assert.match(R.htmlReport(data, [], R.findFiles(path.join(dir, '_forever_', 'WTF')), new Date()), /<h2>Speed<\/h2>.*open1/);
  assert.match(R.speedText({ autoCheck: null }).join('\n'), /No timing pass/);
  fs.rmSync(dir, { recursive: true, force: true });
});
