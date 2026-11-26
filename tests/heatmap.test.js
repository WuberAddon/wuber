// Tests for tools\heatmap.js:  node tests/heatmap.test.js (from the repo folder; run.lua runs it too)
'use strict';
const fs = require('fs');
const os = require('os');
const path = require('path');
const assert = require('assert');
const { execFileSync } = require('child_process');
const H = require('../tools/heatmap.js');

let passed = 0;

// Every temp folder a test makes is removed at the end, pass or fail (SPEC5 pending, review #30).
const temps = [];
const realMkdtemp = fs.mkdtempSync;
fs.mkdtempSync = (...args) => {
	const dir = realMkdtemp.apply(fs, args);
	temps.push(dir);
	return dir;
};
process.on('exit', () => {
	for (const dir of temps) {
		try { fs.rmSync(dir, { recursive: true, force: true }); } catch (e) { /* already gone */ }
	}
});
function test(name, fn) {
	try {
		fn();
		passed++;
		console.log('PASS  ' + name);
	} catch (e) {
		console.log('FAIL  ' + name + '\n      ' + (e.stack || e));
		process.exitCode = 1;
	}
}

// Saved variables the way the game writes them.
function saved(log, extra) {
	const lines = (list) => list.map((s, i) => `"${s.replace(/\\/g, '\\\\').replace(/"/g, '\\"')}", -- [${i + 1}]`).join('\n');
	const map = (m) => Object.entries(m).map(([k, v]) => `["${k}"] = ${v},`).join('\n');
	return `
RitualRidesDB = {
["blocklist"] = {
["agata christi"] = {
["at"] = "17 Nov",
["reason"] = "Didn't pay",
},
},
["price"] = 5000,
["pos"] = {
"TOP", -- [1]
"TOP", -- [2]
-255.7098846435547, -- [3]
-237.5075378417969, -- [4]
},
["templates"] = {
["tip"] = "Thanks for the tip, {name}! \\"5 stars\\"",
},
${extra || ''}
${log ? `["log"] = {
["v"] = 1,
["rides"] = {
${lines(log.rides || [])}
},
["asks"] = {
${lines(log.asks || [])}
},
["open"] = {
${map(log.open || {})}
},
["seen"] = {
${map(log.seen || {})}
},
${log.wreq ? `["wreq"] = {\n${map(log.wreq)}\n},` : ''}
${log.wdec ? `["wdec"] = {\n${map(log.wdec)}\n},` : ''}
${log.rivals ? `["rivals"] = {\n${map(log.rivals)}\n},` : ''}
},` : ''}
}
`;
}

const T = (y, mo, d, h, mi) => Math.floor(new Date(y, mo - 1, d, h, mi || 0).getTime() / 1000);

test('reads what the game writes', () => {
	const g = H.parseLua(saved({ rides: ['1,2,Dan,Undercity,t'], open: { '2026111719': 42 } }));
	const db = g.RitualRidesDB;
	assert.strictEqual(db.price, 5000);
	assert.deepStrictEqual(db.pos, ['TOP', 'TOP', -255.7098846435547, -237.5075378417969]);
	assert.strictEqual(db.templates.tip, 'Thanks for the tip, {name}! "5 stars"');
	assert.strictEqual(db.blocklist['agata christi'].reason, "Didn't pay");
	assert.deepStrictEqual(db.log.rides, ['1,2,Dan,Undercity,t']);
	assert.strictEqual(db.log.open['2026111719'], 42);
	const empty = H.parseLua('RitualRidesDB = {\n["log"] = {\n["rides"] = {\n},\n},\n}\nOther = nil\n');
	assert.deepStrictEqual(empty.RitualRidesDB.log.rides, []);
});

test('the three licences add up: payments summed, open time not tripled, a buyer counted once', () => {
	const wtf = fs.mkdtempSync(path.join(os.tmpdir(), 'wtf-'));
	const write = (lic, text) => {
		const dir = path.join(wtf, 'Account', lic, 'SavedVariables');
		fs.mkdirSync(dir, { recursive: true });
		fs.writeFileSync(path.join(dir, 'RitualRides.lua'), text);
	};
	const t1 = T(2026, 11, 17, 19, 10);
	const t2 = T(2026, 11, 17, 19, 40);
	const t3 = T(2026, 11, 18, 20, 5);
	write('TESTACCT2K', saved({
		rides: [`${t1},50000,Dan Miller,Undercity,t`, `${t3},60000,Eve Long,Undercity,t`],
		asks: [`${t1 - 60},match,Dan Miller,m,Undercity,wtb summon uc`],
		open: { '2026111719': 50, '2026111820': 30 }, seen: { '2026111719': 60, '2026111820': 60 },
	}));
	write('ACCOUNT#1', saved({
		rides: [`${t2},50000,Fay Reed,Undercity,t`],
		asks: [`${t1 - 59},match,Dan Miller,m,Undercity,wtb summon uc`, `${t2},elsewhere,Gus Grey,m,Undercity,LF summon to BRM`],
		open: { '2026111719': 55 }, seen: { '2026111719': 60 },
	}));
	write('ACCOUNT#2', saved(null)); // no log yet
	fs.mkdirSync(path.join(wtf, 'Account', 'SavedVariables'), { recursive: true }); // the game's own folder, no addon file
	const lic = H.readLicences(wtf);
	assert.strictEqual(lic.length, 3);
	assert.strictEqual(lic.find((l) => l.licence === 'ACCOUNT#2').hasLog, false);
	const m = H.merge(lic);
	assert.strictEqual(m.rides.length, 3);
	assert.strictEqual(m.rides.reduce((s, r) => s + r.copper, 0), 160000);
	assert.deepStrictEqual(m.rides.map((r) => r.name), ['Dan Miller', 'Fay Reed', 'Eve Long'], 'sorted by time');
	const h19 = m.hours.find((h) => h.key === '2026111719');
	assert.strictEqual(h19.open, 55, 'the most open window, not 50 + 55');
	assert.strictEqual(h19.wd, 1, 'Tuesday');
	assert.strictEqual(h19.h, 19);
	assert.strictEqual(m.asks.length, 2, 'Dan seen by two windows is one buyer');
	assert.strictEqual(m.rides[0].wd, 1);
	assert.strictEqual(m.rides[0].h, 19);
	assert.strictEqual(m.rides[0].day, '2026-11-17');

	// the whole run: report and CSV written
	const out = fs.mkdtempSync(path.join(os.tmpdir(), 'out-'));
	execFileSync(process.execPath, [path.join(__dirname, '..', 'tools', 'heatmap.js'), '--wtf', wtf, '--out', out, '--no-open']);
	const html = fs.readFileSync(path.join(out, 'wuber-report.html'), 'utf8').replace(/\r\n/g, '\n'); // a CRLF checkout of the template
	assert.ok(!html.includes('/*DATA*/null'), 'data embedded');
	const json = JSON.parse(html.match(/const DATA = (\{.*?\});\n/)[1]);
	assert.strictEqual(json.rides.length, 3);
	const csv = fs.readFileSync(path.join(out, 'rides.csv'), 'utf8').trim().split(/\r\n/);
	assert.strictEqual(csv.length, 4);
	assert.ok(csv[1].startsWith('2026-11-17,19:10,Tue,5.00,0.00,Dan Miller,Undercity,traded,'), csv[1]);
});

test('Wuber: requests are summed over the licences, rival drivers are the most any window saw', () => {
	const wtf = fs.mkdtempSync(path.join(os.tmpdir(), 'wtf-'));
	const write = (lic, text) => {
		const dir = path.join(wtf, 'Account', lic, 'SavedVariables');
		fs.mkdirSync(dir, { recursive: true });
		fs.writeFileSync(path.join(dir, 'RitualRides.lua'), text);
	};
	write('TESTACCT2K', saved({
		open: { '2026111719': 50 }, seen: { '2026111719': 60, '2026111720': 60 },
		wreq: { '2026111719': 4 }, wdec: { '2026111719': 1 }, rivals: { '2026111719': 3, '2026111720': 0 },
	}));
	write('ACCOUNT#1', saved({
		open: { '2026111719': 40 }, seen: { '2026111719': 60 },
		wreq: { '2026111719': 2 }, rivals: { '2026111719': 5 },
	}));
	write('ACCOUNT#2', saved({ open: { '2026111719': 30 }, seen: { '2026111719': 60 } })); // a 1.4.0 log: no Wuber counts
	const m = H.merge(H.readLicences(wtf));
	const h19 = m.hours.find((h) => h.key === '2026111719');
	assert.strictEqual(h19.wreq, 6, 'each request reached one window: 4 + 2');
	assert.strictEqual(h19.wdec, 1);
	assert.strictEqual(h19.rivals, 5, 'the most any window saw, not 3 + 5');
	const h20 = m.hours.find((h) => h.key === '2026111720');
	assert.strictEqual(h20.rivals, 0, 'looked, and nobody else was on');
	assert.strictEqual(h20.wreq, 0);

	const out = fs.mkdtempSync(path.join(os.tmpdir(), 'out-'));
	execFileSync(process.execPath, [path.join(__dirname, '..', 'tools', 'heatmap.js'), '--wtf', wtf, '--out', out, '--no-open']);
	const html = fs.readFileSync(path.join(out, 'wuber-report.html'), 'utf8').replace(/\r\n/g, '\n'); // a CRLF checkout of the template
	assert.ok(html.includes('id="wuber"') && html.includes('Wuber requests, by weekday and hour'), 'the Wuber requests heatmap');
	assert.ok(html.includes('id="rivals"') && html.includes('Rival drivers online, by weekday and hour'), 'the rival drivers heatmap');
	const json = JSON.parse(html.match(/const DATA = (\{.*?\});\n/)[1]);
	assert.strictEqual(json.hours.find((h) => h.key === '2026111719').wreq, 6);
});

test('the report page script is valid JavaScript, with real and demo data', () => {
	const vm = require('vm');
	const template = fs.readFileSync(path.join(__dirname, '..', 'tools', 'report-template.html'), 'utf8');
	const script = template.match(/<script>([\s\S]*)<\/script>/)[1];
	new vm.Script(script.replace('/*DATA*/null', JSON.stringify({ ...H.demo(), licences: [], generated: new Date().toISOString() })));
	const d = H.demo();
	assert.ok(d.hours.every((h) => h.wreq >= 0 && h.wdec <= h.wreq && h.rivals >= 0), 'demo hours carry Wuber counts');
});

test('a missing WTF folder says how to fix it', () => {
	assert.throws(() => H.readLicences(path.join(os.tmpdir(), 'no-such-wtf')), /--wtf/);
});

test('demo data makes a report', () => {
	const d = H.demo();
	assert.ok(d.rides.length > 20 && d.asks.length > 50 && d.hours.length > 50);
	assert.ok(d.rides.every((r) => r.copper > 0 && r.wd >= 0 && r.wd < 7 && r.h >= 0 && r.h < 24));
});

// ---------------------------------------------------------------------------
// Wuber 2.0: WuberDB.drive.log, with the old log beside it
// ---------------------------------------------------------------------------

// WuberDB the way the game writes it (only the parts the tool reads, plus noise)
function wuberSaved(log, extra) {
	const lines = (list) => list.map((s, i) => `"${s.replace(/\\/g, '\\\\').replace(/"/g, '\\"')}", -- [${i + 1}]`).join('\n');
	const map = (m) => Object.entries(m).map(([k, v]) => `["${k}"] = ${v},`).join('\n');
	return `
WuberDB = {
["rides"] = {
{
["dest"] = "Ratchet",
["price"] = 5000,
}, -- [1]
},
["chars"] = {
["Anita Lift"] = {
["drive"] = true,
["price"] = 5000,
},
},
${extra || ''}
${log ? `["drive"] = {
["v"] = 1,
["opts"] = {
["autoInvite"] = true,
["keywords"] = "summon summons",
},
["log"] = {
["v"] = 1,
["rides"] = {
${lines(log.rides || [])}
},
["team"] = {
${lines(log.team || [])}
},
["asks"] = {
${lines(log.asks || [])}
},
["open"] = {
${map(log.open || {})}
},
["seen"] = {
${map(log.seen || {})}
},
["wreq"] = {
${map(log.wreq || {})}
},
["wdec"] = {
${map(log.wdec || {})}
},
["rivals"] = {
${map(log.rivals || {})}
},
},
},` : ''}
}
`;
}

function account(wtf, name, files) {
	const dir = path.join(wtf, 'Account', name, 'SavedVariables');
	fs.mkdirSync(dir, { recursive: true });
	for (const [file, text] of Object.entries(files)) fs.writeFileSync(path.join(dir, file), text);
}

test('Wuber 2.0: reads WuberDB.drive.log and RitualRidesDB.log of every account without double counting', () => {
	const wtf = fs.mkdtempSync(path.join(os.tmpdir(), 'wtf-'));
	const t1 = T(2026, 11, 17, 19, 10);
	const t2 = T(2026, 11, 18, 20, 5);
	const t3 = T(2026, 11, 19, 21, 0);
	const old1 = `${t1},50000,Dan Miller,Undercity,t`; // the old log's 5-field line, copied by the import
	const ask1 = `${t1 - 60},match,Dan Miller,m,Undercity,wtb summon uc`;
	// Anita's account: imported (the same lines in both), then a ride after the import (6 fields) and one
	// the old addon took before it was switched off (only in its log)
	account(wtf, 'TESTACCT2K', {
		'Wuber.lua': wuberSaved({
			rides: [old1, `${t3},60000,Eve Long,Undercity,t,50000`],
			team: [`${t3},50000,Fay Reed,Undercity,farra way`],
			asks: [ask1],
			open: { '2026111719': 50, '2026111921': 40 }, seen: { '2026111719': 60, '2026111921': 60 },
			wreq: { '2026111719': 2, '2026111921': 3 }, wdec: { '2026111921': 1 }, rivals: { '2026111719': 2 },
		}),
		'RitualRides.lua': saved({
			rides: [old1, `${t2},50000,Gus Grey,Undercity,t`],
			asks: [ask1],
			open: { '2026111719': 50, '2026111820': 30 }, seen: { '2026111719': 60, '2026111820': 60 },
			wreq: { '2026111719': 2 }, rivals: { '2026111719': 3 },
		}),
	});
	// Farra's account: Wuber only (took Fay's 5g)
	account(wtf, 'ACCOUNT#1', {
		'Wuber.lua': wuberSaved({
			rides: [`${t3},50000,Fay Reed,Undercity,t,50000`],
			open: { '2026111921': 45 }, seen: { '2026111921': 60 }, wreq: { '2026111921': 1 },
		}),
	});
	// a rider's account: Wuber without a driver's log - not listed
	account(wtf, 'ACCOUNT#2', { 'Wuber.lua': wuberSaved(null) });
	const acc = H.readLicences(wtf);
	assert.deepStrictEqual(acc.map((a) => a.licence).sort(), ['ACCOUNT#1', 'TESTACCT2K']);
	const anita = acc.find((a) => a.licence === 'TESTACCT2K');
	assert.deepStrictEqual(anita.from, ['Wuber', 'old log']);
	assert.strictEqual(anita.rides.length, 3, 'the copied line once, plus one from each log');
	assert.strictEqual(anita.asks.length, 1, 'the copied ask once');
	assert.strictEqual(anita.open['2026111719'], 50, 'the same window: not 50 + 50');
	assert.strictEqual(anita.wreq['2026111719'], 2, 'the copied count once');
	assert.strictEqual(anita.rivals['2026111719'], 3, 'the larger of the two');
	const m = H.merge(acc);
	assert.strictEqual(m.rides.length, 4, 'team lines are not payments of this account');
	assert.strictEqual(m.rides.reduce((s, r) => s + r.copper, 0), 210000);
	const eve = m.rides.find((r) => r.name === 'Eve Long');
	assert.strictEqual(eve.price, 50000);
	assert.strictEqual(eve.tip, 10000, 'paid 6g for a 5g ride');
	assert.strictEqual(m.rides.find((r) => r.name === 'Dan Miller').tip, 0, 'an old line has no price: no tip');
	const h21 = m.hours.find((h) => h.key === '2026111921');
	assert.strictEqual(h21.open, 45, 'the most open window');
	assert.strictEqual(h21.wreq, 4, 'requests add up over the accounts: 3 + 1');
	assert.strictEqual(h21.wdec, 1);
	assert.strictEqual(m.hours.find((h) => h.key === '2026111820').open, 30, 'an hour only the old log has');

	const out = fs.mkdtempSync(path.join(os.tmpdir(), 'out-'));
	const said = execFileSync(process.execPath, [path.join(__dirname, '..', 'tools', 'heatmap.js'), '--wtf', wtf, '--out', out, '--no-open']).toString();
	assert.ok(/TESTACCT2K: 3 rides.*\(Wuber \+ old log\)/.test(said), said);
	const html = fs.readFileSync(path.join(out, 'wuber-report.html'), 'utf8').replace(/\r\n/g, '\n'); // a CRLF checkout of the template
	assert.ok(html.includes('<title>Wuber earnings</title>'), 'title');
	assert.ok(!/ritual rides|three warlocks/i.test(html), 'no Ritual Rides wording in the report');
	const json = JSON.parse(html.match(/const DATA = (\{.*?\});\n/)[1]);
	assert.strictEqual(json.rides.length, 4);
	const csv = fs.readFileSync(path.join(out, 'rides.csv'), 'utf8').trim().split(/\r\n/);
	assert.strictEqual(csv[0], 'date,time,weekday,gold,tip,rider,destination,how,account');
	assert.ok(csv.some((l) => l.includes(',6.00,1.00,Eve Long,')), 'the tip column');
});

test('Wuber 2.0: no driver log anywhere says what to do', () => {
	const wtf = fs.mkdtempSync(path.join(os.tmpdir(), 'wtf-'));
	account(wtf, 'RIDER', { 'Wuber.lua': wuberSaved(null) });
	const out = fs.mkdtempSync(path.join(os.tmpdir(), 'out-'));
	let err = '';
	try {
		execFileSync(process.execPath, [path.join(__dirname, '..', 'tools', 'heatmap.js'), '--wtf', wtf, '--out', out, '--no-open'], { stdio: 'pipe' });
	} catch (e) { err = String(e.stderr); }
	assert.ok(/No driver's log found/.test(err), err);
});

test('Wuber 2.0: heatmap.cmd checks for Node and runs the tool', () => {
	const cmd = fs.readFileSync(path.join(__dirname, '..', 'tools', 'heatmap.cmd'), 'utf8');
	assert.ok(/where node >nul 2>nul/.test(cmd), 'where node, quietly');
	assert.ok(cmd.includes('node "%~dp0heatmap.js" %*'));
	assert.ok(!/ritual/i.test(cmd));
});

test('Wuber 2.2: run from inside the game folder it finds the game\'s WTF (no hard-coded C: path)', () => {
	const game = fs.mkdtempSync(path.join(os.tmpdir(), 'game-'));
	try {
		const tools = path.join(game, '_forever_', 'Interface', 'AddOns', 'Wuber', 'tools');
		fs.mkdirSync(tools, { recursive: true });
		fs.mkdirSync(path.join(game, '_forever_', 'WTF', 'Account'), { recursive: true });
		assert.strictEqual(H.findWtf(tools), path.join(game, '_forever_', 'WTF'));
		const elsewhere = fs.mkdtempSync(path.join(os.tmpdir(), 'repo-'));
		try {
			assert.strictEqual(H.findWtf(elsewhere), H.DEFAULT_WTF, 'outside the game: the usual place');
		} finally {
			fs.rmSync(elsewhere, { recursive: true, force: true });
		}
	} finally {
		fs.rmSync(game, { recursive: true, force: true });
	}
});

console.log('-'.repeat(60));
console.log(process.exitCode ? 'RESULT: FAILED' : `RESULT: OK (${passed} tests)`);
