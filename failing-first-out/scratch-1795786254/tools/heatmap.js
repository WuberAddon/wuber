#!/usr/bin/env node
// Wuber earnings heatmap: reads the driver's earnings log (WuberDB.drive.log) from every
// account's saved variables - and the old summon log (RitualRidesDB.log) if it is still
// there - and writes report\wuber-report.html (and report\rides.csv), then opens the report.
//
// Each account is one game window. Inside an account the two logs are one: Wuber 2.0 copied
// the old log over once, so a ride or ask line found in both is counted once, and an hour's
// minutes or counts are the larger of the two. Across accounts payments add up, an hour is as
// open as its most open window, a buyer several windows saw is one buyer, Wuber requests add
// up (each reaches one window) and rival drivers are the most any window saw.
//
//   tools\heatmap.cmd                     the usual way (double-click; finds the game's WTF
//                                         itself when run from inside the game folder)
//   node tools\heatmap.js --wtf "<WoW folder>\_forever_\WTF"
//   node tools\heatmap.js --demo          made-up data, to see what the report looks like
//   node tools\heatmap.js --no-open       write the files without opening the browser
//
// The game writes saved variables when you log out or type /reload, so do one of those
// first to include the latest rides.

'use strict';
const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');

const ROOT = path.resolve(__dirname, '..');
const DEFAULT_WTF = 'C:\\Program Files (x86)\\World of Warcraft\\_forever_\\WTF';

// The game's WTF folder: when the tool runs from inside the game (Interface\AddOns\Wuber\tools
// or any folder under the game's _forever_), the WTF beside that Interface folder; else the
// usual install place. --wtf always wins.
function findWtf(start) {
	let dir = path.resolve(start || __dirname);
	for (let i = 0; i < 8; i++) {
		const wtf = path.join(dir, 'WTF');
		if (fs.existsSync(path.join(wtf, 'Account'))) return wtf;
		const up = path.dirname(dir);
		if (up === dir) break;
		dir = up;
	}
	return DEFAULT_WTF;
}

// ---------------------------------------------------------------------------
// A reader for the Lua that the game writes into SavedVariables
// ---------------------------------------------------------------------------

function parseLua(src) {
	let i = 0;
	const n = src.length;
	const fail = (what) => { throw new Error(`${what} at character ${i}`); };
	function skip() {
		for (;;) {
			while (i < n && /\s/.test(src[i])) i++;
			if (src.startsWith('--', i)) {
				const m = /^--\[(=*)\[/.exec(src.slice(i, i + 20));
				if (m) {
					const end = src.indexOf(']' + m[1] + ']', i);
					i = end < 0 ? n : end + m[1].length + 2;
				} else {
					while (i < n && src[i] !== '\n') i++;
				}
				continue;
			}
			return;
		}
	}
	function str() {
		const q = src[i++];
		let out = '';
		while (i < n && src[i] !== q) {
			let c = src[i++];
			if (c === '\\') {
				c = src[i++];
				if (c === 'n') out += '\n';
				else if (c === 't') out += '\t';
				else if (c === 'r') out += '\r';
				else if (c === '\n') out += '\n';
				else if (/\d/.test(c)) {
					let d = c;
					while (d.length < 3 && /\d/.test(src[i])) d += src[i++];
					out += String.fromCharCode(parseInt(d, 10));
				} else out += c;
			} else out += c;
		}
		if (src[i] !== q) fail('unfinished string');
		i++;
		return out;
	}
	function longStr() {
		const m = /^\[(=*)\[/.exec(src.slice(i, i + 20));
		const close = ']' + m[1] + ']';
		const end = src.indexOf(close, i);
		if (end < 0) fail('unfinished long string');
		let s = src.slice(i + m[0].length, end);
		if (s.startsWith('\n')) s = s.slice(1);
		i = end + close.length;
		return s;
	}
	function value() {
		skip();
		const c = src[i];
		if (c === '{') return table();
		if (c === '"' || c === "'") return str();
		if (c === '[' && /^\[=*\[/.test(src.slice(i, i + 20))) return longStr();
		for (const [word, v] of [['true', true], ['false', false], ['nil', null]]) {
			if (src.startsWith(word, i) && !/\w/.test(src[i + word.length] || '')) {
				i += word.length;
				return v;
			}
		}
		const m = /^-?(?:0[xX][0-9a-fA-F]+|(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?|inf|nan)/.exec(src.slice(i, i + 80));
		if (!m) fail('unexpected ' + JSON.stringify(src.slice(i, i + 12)));
		i += m[0].length;
		const t = m[0];
		if (/inf$/.test(t)) return t.startsWith('-') ? -Infinity : Infinity;
		if (/nan$/.test(t)) return NaN;
		return Number(t);
	}
	function table() {
		i++; // {
		const map = {};
		const list = [];
		let keyed = false;
		for (;;) {
			skip();
			if (src[i] === '}') { i++; break; }
			let key;
			if (src[i] === '[' && !/^\[=*\[/.test(src.slice(i, i + 20))) {
				i++;
				key = value();
				skip();
				if (src[i] !== ']') fail('expected ]');
				i++;
				skip();
				if (src[i] !== '=') fail('expected =');
				i++;
			} else {
				const m = /^([A-Za-z_]\w*)\s*=(?!=)/.exec(src.slice(i, i + 200));
				if (m) {
					key = m[1];
					i += m[0].length;
				}
			}
			const v = value();
			if (key === undefined) list.push(v);
			else { map[String(key)] = v; keyed = true; }
			skip();
			if (src[i] === ',' || src[i] === ';') i++;
		}
		if (!keyed) return list;
		list.forEach((v, k) => { map[String(k + 1)] = v; });
		return map;
	}
	const globals = {};
	for (;;) {
		skip();
		if (i >= n) break;
		const m = /^([A-Za-z_]\w*)\s*=/.exec(src.slice(i, i + 200));
		if (!m) fail('expected a name');
		i += m[0].length;
		globals[m[1]] = value();
	}
	return globals;
}

// ---------------------------------------------------------------------------
// Reading every licence
// ---------------------------------------------------------------------------

const asList = (v) => Array.isArray(v) ? v : (v && typeof v === 'object' ? Object.keys(v).sort((a, b) => a - b).map((k) => v[k]) : []);

const isHourMap = (m) => m && typeof m === 'object' && !Array.isArray(m);
const hourMap = (m) => isHourMap(m) ? m : {};
const lines = (v) => asList(v).filter((s) => typeof s === 'string');

// one account's two logs as one: lines once each (in order), hours at the larger value
function joinLogs(logs) {
	const out = { rides: [], asks: [], open: {}, seen: {}, wreq: {}, wdec: {}, rivals: {} };
	for (const kind of ['rides', 'asks']) {
		const seen = new Set();
		for (const log of logs) {
			for (const line of lines(log[kind])) {
				if (seen.has(line)) continue;
				seen.add(line);
				out[kind].push(line);
			}
		}
	}
	for (const kind of ['open', 'seen', 'wreq', 'wdec', 'rivals']) {
		for (const log of logs) {
			for (const [key, v] of Object.entries(hourMap(log[kind]))) {
				const n = Number(v) || 0;
				out[kind][key] = key in out[kind] ? Math.max(out[kind][key], n) : n;
			}
		}
	}
	return out;
}

function readFile(file, global, name) {
	if (!fs.existsSync(file)) return undefined;
	try {
		return parseLua(fs.readFileSync(file, 'utf8'))[global] || null;
	} catch (e) {
		console.warn(`  skipped ${path.basename(file)} of ${name}: could not read it (${e.message})`);
		return undefined;
	}
}

function readLicences(wtf) {
	const accounts = path.join(wtf, 'Account');
	if (!fs.existsSync(accounts)) throw new Error(`No WTF\\Account folder at ${wtf}. Pass the right one with --wtf "<path to WTF>".`);
	const out = [];
	for (const name of fs.readdirSync(accounts)) {
		const dir = path.join(accounts, name, 'SavedVariables');
		const wFile = path.join(dir, 'Wuber.lua');
		const rFile = path.join(dir, 'RitualRides.lua');
		const wdb = readFile(wFile, 'WuberDB', name);
		const rdb = readFile(rFile, 'RitualRidesDB', name);
		if (wdb === undefined && rdb === undefined) continue;
		const wlog = wdb && wdb.drive && isHourMap(wdb.drive.log) ? wdb.drive.log : null;
		const rlog = rdb && isHourMap(rdb.log) ? rdb.log : null;
		if (wdb !== undefined && !wlog && rdb === undefined) continue; // a rider's Wuber: nothing to read
		const log = joinLogs([wlog, rlog].filter(Boolean));
		const files = [wdb !== undefined && wFile, rdb !== undefined && rFile].filter(Boolean);
		out.push({
			licence: name,
			file: files[0],
			files,
			modified: new Date(Math.max(...files.map((f) => fs.statSync(f).mtime.getTime()))),
			...log,
			hasLog: !!(wlog || rlog),
			from: [wlog && 'Wuber', rlog && 'old log'].filter(Boolean),
			price: (rdb && rdb.price) || null,
			dest: (rdb && rdb.dest) || null,
		});
	}
	return out;
}

// ---------------------------------------------------------------------------
// Putting the three together
// ---------------------------------------------------------------------------

const pad = (v) => String(v).padStart(2, '0');
const dayKey = (d) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
const weekday = (d) => (d.getDay() + 6) % 7; // Monday 0 .. Sunday 6

function stamp(at) {
	const d = new Date(at * 1000);
	return { at, day: dayKey(d), wd: weekday(d), h: d.getHours() };
}

function merge(licences) {
	const rides = [];
	const asks = [];
	const hours = new Map(); // "YYYYMMDDHH" -> { open, seen, wreq, wdec, rivals }
	const blank = () => ({ open: 0, seen: 0, wreq: 0, wdec: 0, rivals: null });
	for (const L of licences) {
		for (const line of L.rides) {
			const p = line.split(',');
			const at = Number(p[0]);
			if (!at) continue;
			// (Wuber 2.0 adds a 6th field: the price charged; a tip is copper - price)
			const price = Number(p[5]) || 0;
			const copper = Number(p[1]) || 0;
			rides.push({ ...stamp(at), copper, name: p[2] || '', dest: p[3] || '', how: p[4] || 't', price, tip: price > 0 ? Math.max(0, copper - price) : 0, licence: L.licence });
		}
		for (const line of L.asks) {
			const p = line.split(',');
			const at = Number(p[0]);
			if (!at) continue;
			asks.push({ ...stamp(at), want: p[1] || '', name: p[2] || '', where: p[3] || 'o', dest: p[4] || '', text: p.slice(5).join(',') });
		}
		// the three windows run side by side: an hour is as open as its most open window
		for (const [kind, map] of [['open', L.open], ['seen', L.seen]]) {
			for (const [key, minutes] of Object.entries(map)) {
				if (!/^\d{10}$/.test(key)) continue;
				const h = hours.get(key) || blank();
				h[kind] = Math.max(h[kind], Math.min(60, Number(minutes) || 0));
				hours.set(key, h);
			}
		}
		// a Wuber request reaches one window: the windows' counts add up
		for (const kind of ['wreq', 'wdec']) {
			for (const [key, n] of Object.entries(L[kind] || {})) {
				if (!/^\d{10}$/.test(key)) continue;
				const h = hours.get(key) || blank();
				h[kind] += Math.max(0, Number(n) || 0);
				hours.set(key, h);
			}
		}
		// every window sees the same network: the most any of them saw
		for (const [key, n] of Object.entries(L.rivals || {})) {
			if (!/^\d{10}$/.test(key)) continue;
			const h = hours.get(key) || blank();
			h.rivals = Math.max(h.rivals == null ? 0 : h.rivals, Math.max(0, Number(n) || 0));
			hours.set(key, h);
		}
	}
	// a buyer seen by two or three windows is one buyer
	asks.sort((a, b) => a.at - b.at);
	const lastBy = new Map();
	const uniqueAsks = [];
	for (const a of asks) {
		const k = a.name.toLowerCase() + '|' + a.text.toLowerCase();
		const last = lastBy.get(k);
		if (last !== undefined && a.at - last <= 120) continue;
		lastBy.set(k, a.at);
		uniqueAsks.push(a);
	}
	const hourList = [...hours.entries()].sort().map(([key, v]) => {
		const d = new Date(Number(key.slice(0, 4)), Number(key.slice(4, 6)) - 1, Number(key.slice(6, 8)), Number(key.slice(8, 10)));
		return { key, day: dayKey(d), wd: weekday(d), h: d.getHours(), open: v.open, seen: Math.max(v.seen, v.open), wreq: v.wreq, wdec: v.wdec, rivals: v.rivals };
	});
	rides.sort((a, b) => a.at - b.at);
	return { rides, asks: uniqueAsks, hours: hourList };
}

// ---------------------------------------------------------------------------
// Made-up data for --demo
// ---------------------------------------------------------------------------

function demo() {
	let seed = 7;
	const rand = () => ((seed = (seed * 16807) % 2147483647) / 2147483647);
	const rides = [];
	const asks = [];
	const hours = [];
	const now = new Date();
	now.setMinutes(0, 0, 0);
	const busy = (wd, h) => {
		let b = 0.15;
		if (h >= 18 && h <= 22) b = 0.9;
		else if (h >= 12 && h <= 17) b = 0.45;
		else if (h >= 9 && h <= 11) b = 0.25;
		else if (h <= 1) b = 0.35;
		if (wd >= 4) b *= 1.35; // Friday to Sunday
		if (wd === 1 && h >= 19 && h <= 22) b *= 1.3; // a raid night
		return b;
	};
	const names = ['Mortok', 'Zulja', 'Grimbash', 'Thalia', 'Vexxa', 'Brokk', 'Senna', 'Orgrim', 'Kazra', 'Duvok', 'Ilyana', 'Rothgar'];
	const places = ['Undercity', 'Orgrimmar', 'Thunder Bluff', 'Ratchet', 'Booty Bay', 'Tarren Mill'];
	for (let back = 21 * 24; back >= 1; back--) {
		const d = new Date(now.getTime() - back * 3600000);
		const wd = weekday(d);
		const h = d.getHours();
		const key = `${d.getFullYear()}${pad(d.getMonth() + 1)}${pad(d.getDate())}${pad(h)}`;
		const playing = (h >= 17 && h <= 23) || (wd >= 5 && h >= 11) || rand() < 0.08;
		if (!playing) continue;
		const open = rand() < 0.75 ? Math.round(30 + rand() * 30) : 0;
		const b = busy(wd, h);
		const wreq = open ? Math.round(b * 6 * rand()) : 0;
		hours.push({ key, day: dayKey(d), wd, h, open, seen: 60, wreq, wdec: Math.round(wreq * 0.2 * rand()), rivals: Math.round(b * 4 * (0.5 + rand())) });
		const buyers = Math.round(b * 40 * (0.6 + rand() * 0.8));
		for (let k = 0; k < buyers; k++) {
			const at = Math.floor(d.getTime() / 1000) + Math.floor(rand() * 3600);
			const r = rand();
			const want = r < 0.45 ? 'match' : r < 0.8 ? 'elsewhere' : r < 0.95 ? 'noplace' : 'unclear';
			const place = want === 'match' ? 'Undercity' : places[1 + Math.floor(rand() * 5)];
			asks.push({ ...stamp(at), want, name: names[Math.floor(rand() * names.length)], where: 'm', dest: 'Undercity', text: want === 'noplace' ? 'wtb summon pst' : `wtb summon ${place.toLowerCase()}` });
			if (want === 'match' && open && rand() < (open / 60) * 0.8) {
				const paid = rand() < 0.15 ? 6000 : 5000;
				rides.push({ ...stamp(at + 300), price: 5000, tip: paid - 5000, copper: paid, name: names[Math.floor(rand() * names.length)], dest: 'Undercity', how: 't', licence: 'TESTACCT2K' });
			}
		}
	}
	rides.sort((a, b) => a.at - b.at);
	asks.sort((a, b) => a.at - b.at);
	return { rides, asks, hours };
}

// ---------------------------------------------------------------------------
// Writing the report
// ---------------------------------------------------------------------------

function csv(rides) {
	const q = (s) => /[",\n]/.test(s) ? '"' + s.replace(/"/g, '""') + '"' : s;
	const lines = ['date,time,weekday,gold,tip,rider,destination,how,account'];
	const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
	for (const r of rides) {
		const d = new Date(r.at * 1000);
		lines.push([r.day, `${pad(d.getHours())}:${pad(d.getMinutes())}`, days[r.wd], (r.copper / 10000).toFixed(2), ((r.tip || 0) / 10000).toFixed(2), q(r.name), q(r.dest), r.how === 'm' ? 'marked' : 'traded', q(r.licence || '')].join(','));
	}
	return lines.join('\r\n') + '\r\n';
}

function main() {
	const args = process.argv.slice(2);
	const opt = (name) => { const k = args.indexOf(name); return k >= 0 ? (args[k + 1] || '') : null; };
	const isDemo = args.includes('--demo');
	const wtf = opt('--wtf') || findWtf(__dirname);
	const outDir = opt('--out') || path.join(ROOT, 'report');

	let data;
	let licences = [];
	if (isDemo) {
		data = demo();
		licences = [{ licence: 'demo data', hasLog: true }];
		console.log('Made-up demo data (21 days).');
	} else {
		licences = readLicences(wtf);
		if (licences.length === 0) throw new Error(`No driver's log found under ${path.join(wtf, 'Account')}. Have you driven with Wuber, and logged out or typed /reload since?`);
		data = merge(licences);
		for (const L of licences) {
			const wreq = Object.values(L.wreq || {}).reduce((t, n) => t + (Number(n) || 0), 0);
			console.log(`  ${L.licence}: ${L.rides.length} rides, ${L.asks.length} buyers seen, ${wreq} Wuber requests, ${Object.keys(L.open).length} hours logged${L.hasLog ? ' (' + L.from.join(' + ') + ')' : ' (no log yet: drive a while, then /reload)'}`);
		}
	}

	const payload = {
		generated: new Date().toISOString(),
		generatedText: new Date().toLocaleString('en-GB', { weekday: 'short', day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' }),
		demo: isDemo,
		licences: licences.map((L) => ({ licence: L.licence, hasLog: L.hasLog, modified: L.modified ? L.modified.toISOString() : null })),
		...data,
	};
	const template = fs.readFileSync(path.join(__dirname, 'report-template.html'), 'utf8');
	const json = JSON.stringify(payload).replace(/</g, '\\u003c');
	const html = template.replace('/*DATA*/null', json);
	fs.mkdirSync(outDir, { recursive: true });
	const name = isDemo ? 'wuber-report-demo.html' : 'wuber-report.html';
	const file = path.join(outDir, name);
	fs.writeFileSync(file, html);
	if (!isDemo) fs.writeFileSync(path.join(outDir, 'rides.csv'), csv(data.rides));
	const total = data.rides.reduce((s, r) => s + r.copper, 0) / 10000;
	console.log(`${data.rides.length} rides, ${total.toFixed(1)}g, ${data.asks.length} buyers seen.`);
	console.log(`Report: ${file}`);
	if (!args.includes('--no-open') && process.platform === 'win32') exec(`start "" "${file}"`);
}

if (require.main === module) {
	try {
		main();
	} catch (e) {
		console.error('Wuber heatmap: ' + e.message);
		process.exit(1);
	}
}

module.exports = { parseLua, merge, readLicences, readAccounts: readLicences, joinLogs, demo, csv, findWtf, DEFAULT_WTF };
