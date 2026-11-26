#!/usr/bin/env node
// Wuber Lab report (developer only). Reads every account's WuberLab SavedVariables
// (WTF\Account\*\SavedVariables\WuberLab.lua), merges all characters' timelines by time and
// writes report\lab-YYYYMMDD-HHMM.html and report\lab-latest.txt. The test run's results (the
// self-marking checks of "Start test run" and the login checks) come first, in plain English,
// and are printed to the console as well.
//
//   node labreport.js [WTF or game folder] [--out <report folder>] [--shots <Screenshots folder>] [--taint <taint.log>]
//
// Default folder: C:\Program Files (x86)\World of Warcraft\_forever_\WTF
// No npm packages. The Lua files are read by a small parser (never run).
'use strict';

const fs = require('fs');
const path = require('path');

const DEFAULT_WTF = 'C:\\Program Files (x86)\\World of Warcraft\\_forever_\\WTF';
const RED_KINDS = new Set(['err', 'werr', 'block', 'laberr']);
// (r53) W.RetryBlocked() in Wuber fires BLOCKED with no cap and no func after "Retry blocked actions" forgets the refusals: the
// Lab logs it as "W BLOCKED cap=nil func=nil". It is not a blocked action. A BLOCKED with a cap or a func still counts.
const CLEARED_RE = /\bW BLOCKED cap=nil func=nil\s*$/;
function isCleared(l) { return !!l && (l.kind === 'block' || l.kind === 'blocked') && CLEARED_RE.test(String(l.text || l.why || '')); }
function isRed(l) { return RED_KINDS.has(l.kind) && !isCleared(l); }
const TAIL_LINES = 400;

// ---------------------------------------------------------------------------
// A safe parser for WoW SavedVariables (Lua table constructors; nothing is evaluated)
// ---------------------------------------------------------------------------

class LuaParseError extends Error {}

function parseLua(src) {
  // src: a "binary" string (one char per byte); strings are decoded as UTF-8 at the end
  let i = 0;
  const n = src.length;

  function fail(msg) {
    const line = src.slice(0, i).split('\n').length;
    throw new LuaParseError(`${msg} at line ${line}`);
  }

  function longBracket() {
    // at '[': returns the level (number of '=') if this opens a long bracket, else -1
    let j = i + 1;
    let level = 0;
    while (src[j] === '=') { level++; j++; }
    return src[j] === '[' ? level : -1;
  }

  function readLong(level) {
    // at '[' of '[==['
    i += level + 2;
    if (src[i] === '\r') i++;
    if (src[i] === '\n') i++;
    const close = ']' + '='.repeat(level) + ']';
    const end = src.indexOf(close, i);
    if (end < 0) fail('unfinished long string');
    const s = src.slice(i, end);
    i = end + close.length;
    return s;
  }

  function skip() {
    for (;;) {
      while (i < n && /\s/.test(src[i])) i++;
      if (src[i] === '-' && src[i + 1] === '-') {
        i += 2;
        if (src[i] === '[') {
          const level = longBracket();
          if (level >= 0) { readLong(level); continue; }
        }
        while (i < n && src[i] !== '\n') i++;
        continue;
      }
      break;
    }
  }

  function utf8(bin) { return Buffer.from(bin, 'latin1').toString('utf8'); }

  function readString() {
    const q = src[i++];
    let out = '';
    for (;;) {
      if (i >= n) fail('unfinished string');
      const c = src[i++];
      if (c === q) break;
      if (c === '\n') fail('line break in string');
      if (c !== '\\') { out += c; continue; }
      const e = src[i++];
      switch (e) {
        case 'n': out += '\n'; break;
        case 't': out += '\t'; break;
        case 'r': out += '\r'; break;
        case 'a': out += '\x07'; break;
        case 'b': out += '\b'; break;
        case 'f': out += '\f'; break;
        case 'v': out += '\v'; break;
        case '\\': out += '\\'; break;
        case '"': out += '"'; break;
        case "'": out += "'"; break;
        case '\n': out += '\n'; break;
        case '\r': out += '\n'; if (src[i] === '\n') i++; break;
        case 'x': {
          const h = src.slice(i, i + 2);
          if (!/^[0-9a-fA-F]{2}$/.test(h)) fail('bad \\x escape');
          out += String.fromCharCode(parseInt(h, 16));
          i += 2;
          break;
        }
        case 'z': while (i < n && /\s/.test(src[i])) i++; break;
        default: {
          if (e !== undefined && /[0-9]/.test(e)) {
            let d = e;
            while (d.length < 3 && /[0-9]/.test(src[i])) d += src[i++];
            const v = parseInt(d, 10);
            if (v > 255) fail('bad decimal escape');
            out += String.fromCharCode(v);
          } else {
            fail('bad escape \\' + e);
          }
        }
      }
    }
    return utf8(out);
  }

  function readNumber() {
    const m = /^-?(0[xX][0-9a-fA-F]+|(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?)/.exec(src.slice(i, i + 64));
    if (!m) fail('bad number');
    i += m[0].length;
    const t = m[0];
    if (/0[xX]/.test(t)) return (t[0] === '-' ? -1 : 1) * parseInt(t.replace(/^-?0[xX]/, ''), 16);
    return Number(t);
  }

  function readName() {
    const m = /^[A-Za-z_][A-Za-z0-9_]*/.exec(src.slice(i, i + 256));
    if (!m) fail('expected a name');
    i += m[0].length;
    return m[0];
  }

  function readTable() {
    i++; // {
    const arr = [];
    const hash = new Map();
    let next = 1;
    for (;;) {
      skip();
      if (src[i] === '}') { i++; break; }
      let key;
      let hasKey = false;
      if (src[i] === '[' && longBracket() < 0) {
        i++;
        skip();
        key = readValue();
        skip();
        if (src[i] !== ']') fail("expected ']'");
        i++;
        skip();
        if (src[i] !== '=') fail("expected '='");
        i++;
        hasKey = true;
      } else if (/[A-Za-z_]/.test(src[i] || '')) {
        const save = i;
        const name = readName();
        skip();
        if (src[i] === '=' && src[i + 1] !== '=') {
          i++;
          key = name;
          hasKey = true;
        } else {
          i = save;
        }
      }
      skip();
      const value = readValue();
      if (hasKey) {
        if (key === null || key === undefined) fail('nil table key');
        if (typeof key === 'number' && Number.isInteger(key) && key === next && value !== null) {
          arr.push(value);
          next++;
        } else if (value !== null) {
          hash.set(key, value);
        }
      } else {
        arr.push(value);
        next++;
      }
      skip();
      if (src[i] === ',' || src[i] === ';') { i++; continue; }
      if (src[i] === '}') { i++; break; }
      fail("expected ',' or '}'");
    }
    // integer keys continuing the array part join it
    while (hash.has(next)) { arr.push(hash.get(next)); hash.delete(next); next++; }
    if (hash.size === 0) return arr;
    const obj = {};
    arr.forEach((v, k) => { obj[String(k + 1)] = v; });
    for (const [k, v] of hash) obj[String(k)] = v;
    return obj;
  }

  function readValue() {
    skip();
    const c = src[i];
    if (c === '{') return readTable();
    if (c === '"' || c === "'") return readString();
    if (c === '[') {
      const level = longBracket();
      if (level >= 0) return utf8(readLong(level));
      fail("unexpected '['");
    }
    if (c === '-' || c === '.' || /[0-9]/.test(c || '')) {
      if (c === '-' && /^-(inf|nan)/.test(src.slice(i, i + 4))) {
        i++;
        const w = readName();
        return w === 'inf' ? -Infinity : NaN;
      }
      return readNumber();
    }
    if (/[A-Za-z_]/.test(c || '')) {
      const w = readName();
      if (w === 'true') return true;
      if (w === 'false') return false;
      if (w === 'nil') return null;
      if (w === 'inf') return Infinity;
      if (w === 'nan') return NaN;
      fail('unexpected name ' + w);
    }
    fail('unexpected ' + JSON.stringify(c));
  }

  const globals = {};
  for (;;) {
    skip();
    if (i >= n) break;
    const name = readName();
    skip();
    if (src[i] !== '=') fail("expected '=' after " + name);
    i++;
    globals[name] = readValue();
    skip();
    if (src[i] === ';') i++;
  }
  return globals;
}

function parseLuaFile(file) {
  return parseLua(fs.readFileSync(file).toString('latin1'));
}

// ---------------------------------------------------------------------------
// Finding the files
// ---------------------------------------------------------------------------

function resolveWTF(arg) {
  const base = arg || DEFAULT_WTF;
  const tries = [base, path.join(base, 'WTF'), path.join(base, '_forever_', 'WTF')];
  for (const t of tries) {
    if (fs.existsSync(path.join(t, 'Account'))) return t;
  }
  throw new Error('No WTF\\Account folder found. Tried:\n  ' + tries.join('\n  ') +
    '\nGive the WTF folder as the first argument: labreport.cmd "<WoW folder>\\_forever_\\WTF"');
}

function findFiles(wtf) {
  const acc = path.join(wtf, 'Account');
  const out = [];
  for (const name of fs.readdirSync(acc).sort()) {
    const f = path.join(acc, name, 'SavedVariables', 'WuberLab.lua');
    if (fs.existsSync(f)) out.push({ account: name, file: f });
  }
  return out;
}

// ---------------------------------------------------------------------------
// Reading the timelines
// ---------------------------------------------------------------------------

const LINE_RE = /^(\d+(?:\.\d+)?)\|([^|]*)\|([^|]*)\|([\s\S]*)$/;

function asArray(v) {
  if (Array.isArray(v)) return v;
  if (v && typeof v === 'object') {
    return Object.keys(v).filter((k) => /^\d+$/.test(k)).sort((a, b) => a - b).map((k) => v[k]);
  }
  return [];
}

function load(files) {
  const chars = {};
  const lines = [];
  const problems = [];
  const plan = { entries: {}, steps: [], resetAt: 0 };
  const runs = {};
  const login = {};
  let photoTour = null;
  let autoCheck = null;        // (job 105c) the newest Auto check run (WuberLabDB.autoCheck)
  const facts = {};            // (job 129) Game facts: id -> every entry of every account (WuberLabDB.facts)
  const passive = { on: [], sessions: [], release: {} };
  const trail = [];            // the usage trail (Trail.lua): "trail" and "huh" lines
  const trailSeen = new Set(); // their raw text: the timeline and WuberLabDB.trail keep the same lines
  const trailKept = [];
  let seq = 0;
  for (const { account, file } of files) {
    let g;
    try {
      g = parseLuaFile(file);
    } catch (e) {
      problems.push(`${file}: could not read (${e.message})`);
      continue;
    }
    const db = g.WuberLabDB;
    if (!db || typeof db !== 'object' || !db.chars || typeof db.chars !== 'object') {
      problems.push(`${file}: no WuberLabDB.chars`);
      continue;
    }
    // the test plan: shared by the four characters, last write wins
    const pe = db.plan && typeof db.plan === 'object' && !Array.isArray(db.plan) ? db.plan : {};
    if (pe._reset && Number(pe._reset.at) > plan.resetAt) plan.resetAt = Number(pe._reset.at);
    for (const [key, rec] of Object.entries(pe)) {
      if (key === '_reset' || !rec || typeof rec !== 'object') continue;
      const old = plan.entries[key];
      if (!old || Number(rec.at) > Number(old.at)) plan.entries[key] = rec;
    }
    const ps = asArray(db.planSteps);
    if (ps.length > plan.steps.length) plan.steps = ps;
    // test runs: every window keeps the same run (by sid); the copy that got furthest wins
    for (const r of asArray(db.runs)) {
      if (!r || typeof r !== 'object' || !r.sid) continue;
      const run = readRun(r, account);
      const old = runs[run.sid];
      if (!old || run.todo < old.todo || (run.todo === old.todo && (run.ended || 0) > (old.ended || 0))) runs[run.sid] = run;
    }
    // photo tour: the newest saved one (by end, else start time)
    if (db.photoTour && typeof db.photoTour === 'object') {
      const got = findTour(db, []);
      if (got && (!photoTour || (got.ended || got.started) > (photoTour.ended || photoTour.started))) photoTour = got;
    }
    // (job 105c) the Auto check (AutoCheck.lua): the newest saved run
    const ac = readAuto(db.autoCheck, account);
    if (ac && (!autoCheck || (ac.ended || ac.started) > (autoCheck.ended || autoCheck.started))) autoCheck = ac;
    readFacts(db.facts, account, facts);
    // passive play (Passive.lua): every saved session, and the newest pass and fail per kind
    readPassive(db.passive, account, passive);
    // the usage trail's own copy (Trail.lua): the same lines as the timeline, kept past its cap
    if (db.trail && typeof db.trail === 'object') {
      for (const raw of asArray(db.trail.lines)) if (typeof raw === 'string') trailKept.push(raw);
    }
    // login checks: per character, the newest
    const lg = db.login && typeof db.login === 'object' && !Array.isArray(db.login) ? db.login : {};
    for (const [name, rec] of Object.entries(lg)) {
      if (!rec || typeof rec !== 'object') continue;
      const one = { name, account, at: Number(rec.at) || 0, wuber: rec.wuber, lab: rec.lab, checks: [] };
      for (const raw of asArray(rec.lines)) {
        if (typeof raw !== 'string') continue;
        const f = raw.split('|');
        one.checks.push({ id: f[0], r: f[1], why: f[2] || '', at: Number(f[3]) || 0, took: f[4] === '' ? null : Number(f[4]) });
      }
      if (!login[name] || one.at > login[name].at) login[name] = one;
    }
    for (const name of Object.keys(db.chars).sort()) {
      const c = db.chars[name] || {};
      const info = {
        name, account, file, role: c.roleOverride || c.role || null, lines: 0, dropped: Number(c.dropped) || 0,
        checks: c.checks && typeof c.checks === 'object' && !Array.isArray(c.checks) ? c.checks : {},
        steps: asArray(c.steps), selftest: c.selftest || null, sessions: c.sessions || 0, versions: c.versions || {},
        errors: 0, blocked: 0, first: null, last: null, backup: !!db.riderBackup,
      };
      chars[name] = info;
      for (const raw of asArray(c.lines)) {
        if (typeof raw !== 'string') continue;
        const m = LINE_RE.exec(raw);
        if (!m) continue;
        const l = { t: Number(m[1]), char: m[2] || name, kind: m[3], text: m[4], seq: seq++ };
        lines.push(l);
        if (TRAIL_KINDS.has(l.kind) && !trailSeen.has(raw)) {
          trailSeen.add(raw);
          trail.push(l);
        }
        info.lines++;
        if (info.first === null || l.t < info.first) info.first = l.t;
        if (info.last === null || l.t > info.last) info.last = l.t;
        if (l.kind === 'err' || l.kind === 'werr' || l.kind === 'laberr') info.errors++;
        if (isCleared(l)) info.cleared = (info.cleared || 0) + 1;
        else if (l.kind === 'block') info.blocked++;
        if (l.kind === 'login') {
          const r = /role=(\w+)/.exec(l.text);
          if (r && !c.roleOverride) info.role = r[1];
        }
      }
    }
  }
  lines.sort((a, b) => a.t - b.t || a.seq - b.seq);
  for (const [key, rec] of Object.entries(plan.entries)) {
    if (Number(rec.at) <= plan.resetAt) delete plan.entries[key];
  }
  const runList = Object.values(runs).sort((a, b) => (a.started || 0) - (b.started || 0));
  if (!photoTour) photoTour = tourFromLines(lines);
  passive.sessions.sort((a, b) => a.started - b.started);
  for (const raw of trailKept) {
    if (trailSeen.has(raw)) continue;
    const m = LINE_RE.exec(raw);
    if (!m || !TRAIL_KINDS.has(m[3])) continue;
    trailSeen.add(raw);
    trail.push({ t: Number(m[1]), char: m[2] || '?', kind: m[3], text: m[4], seq: seq++ });
  }
  trail.sort((a, b) => a.t - b.t || a.seq - b.seq);
  return { chars, lines, problems, plan, runs: runList, login, photoTour, passive, trail, autoCheck, facts };
}

// ---------------------------------------------------------------------------
// Passive play (WuberLab/Passive.lua): WuberLabDB.passive = { on, sessions = { { char, started,
// ended, wuber, lab, taint, lines = { "kind|subject|result|reason|epoch|took" }, pass, fail, skip,
// look, more } }, release = { [kind] = { n, pass = { at, why, wuber, subject, char }, fail = {...} } } }
// ---------------------------------------------------------------------------

function readPassive(pv, account, out) {
  if (!pv || typeof pv !== 'object' || Array.isArray(pv)) return;
  if (pv.on === true) out.on.push(account);
  for (const s of asArray(pv.sessions)) {
    if (!s || typeof s !== 'object') continue;
    const one = { char: s.char || '?', account, started: Number(s.started) || 0, ended: Number(s.ended) || 0, wuber: s.wuber || '?',
      lab: s.lab || '?', taint: s.taint === undefined ? '?' : String(s.taint), more: Number(s.more) || 0, lines: [] };
    for (const raw of asArray(s.lines)) {
      if (typeof raw !== 'string') continue;
      const f = raw.split('|');
      if (f[0] === 'blocked' && f[2] === 'fail' && CLEARED_RE.test(f[3] || '')) { one.cleared = (one.cleared || 0) + 1; continue; } // (r53) Retry, not a block
      one.lines.push({ kind: f[0], subject: f[1] || '', r: f[2] || '?', why: f[3] || '', at: Number(f[4]) || 0, took: f[5] ? Number(f[5]) : null });
    }
    for (const w of ['pass', 'fail', 'skip', 'look']) one[w] = Number(s[w]) || 0;
    if (one.cleared) one.fail = Math.max(0, one.fail - one.cleared);
    out.sessions.push(one);
  }
  const rel = pv.release && typeof pv.release === 'object' && !Array.isArray(pv.release) ? pv.release : {};
  for (const [kind, rec] of Object.entries(rel)) {
    if (!rec || typeof rec !== 'object') continue;
    const mine = out.release[kind] || (out.release[kind] = { n: 0 });
    mine.n += Number(rec.n) || 0;
    for (const w of ['pass', 'fail']) {
      const got = rec[w];
      if (!got || typeof got !== 'object') continue;
      if (w === 'fail' && kind === 'blocked' && CLEARED_RE.test(String(got.why || ''))) continue; // (r53) Retry, not a block
      const one = { at: Number(got.at) || 0, why: got.why || '', wuber: got.wuber || '?', subject: got.subject || '', char: got.char || '?', account };
      if (!mine[w] || one.at > mine[w].at) mine[w] = one;
    }
  }
}

// The release checklist (tools/checklist.lua in Wuber's repo) as far as passive play proved it
const PASSIVE_ITEMS = [
  ['blocked', 'No "blocked" popup across a session'],
  ['trade', 'A real trade (Wuber counted the gold)'],
  ['summon', 'A real summon click (the big button cast)'],
  ['portal', 'A real portal click (Wuber counted a helper\'s click)'],
  ['ride', 'A real ride ended as done (the rider\'s window)'],
  ['customer', 'A real rider arrived (the driver\'s window)'],
  ['crew', 'Crew sync (a crew window said hello)'],
  ['login', 'Login checks'],
  ['tour', 'Photo tour (taken by itself when idle in a city)'],
];

function passiveItems(data) {
  const rel = (data.passive && data.passive.release) || {};
  return PASSIVE_ITEMS.map(([kind, title]) => {
    const rec = rel[kind] || {};
    const p = rec.pass;
    const f = rec.fail;
    let mark = ' ';
    let text = 'not seen yet';
    if (f && (!p || f.at >= p.at)) {
      mark = '!';
      text = `FAILED last: ${f.why} (${f.char}, ${day(f.at)} ${clock(f.at).slice(0, 5)}, Wuber ${f.wuber})${p ? `; passed before at ${day(p.at)} ${clock(p.at).slice(0, 5)}` : ''}`;
    } else if (p) {
      mark = 'x';
      text = `${p.why} (${p.char}, ${day(p.at)} ${clock(p.at).slice(0, 5)}, Wuber ${p.wuber})${f ? `; failed before at ${day(f.at)} ${clock(f.at).slice(0, 5)}` : ''}`;
    }
    return { kind, title, mark, text };
  });
}

function passiveText(data) {
  const out = [];
  const pv = data.passive || { on: [], sessions: [], release: {} };
  out.push('== Passive play (/lab passive on: the lab checks normal play by itself)');
  if (!pv.sessions.length && !pv.on.length) {
    out.push('Passive play was never on (type /lab passive on in game, play, log out).');
    return out;
  }
  if (pv.on.length) out.push(`On for account${pv.on.length === 1 ? '' : 's'}: ${pv.on.join(', ')}`);
  out.push('Release checklist, as passive play saw it ([x] proved, [!] failed last, [ ] not seen yet):');
  for (const it of passiveItems(data)) out.push(`  [${it.mark}] ${it.title}: ${it.text}`);
  out.push('Sessions (newest first):');
  for (const s of pv.sessions.slice().reverse().slice(0, 8)) {
    out.push(`  ${s.char} ${day(s.started)} ${clock(s.started).slice(0, 5)}${s.ended ? '-' + clock(s.ended).slice(0, 5) : ' (not ended)'}, Wuber ${s.wuber}, ` +
      `taint log ${s.taint}: ${s.pass} passed, ${s.fail ? s.fail + ' FAILED' : '0 failed'}, ${s.skip} skipped, ${s.look} to look at${s.more ? ` (+${s.more} not listed)` : ''}`);
    for (const l of s.lines) {
      if (l.r === 'fail' || l.r === 'look') out.push(`    ${l.r === 'fail' ? 'FAIL' : 'look'} ${l.kind} ${l.subject}: ${l.why} (${clock(l.at)})`);
    }
    const counts = {};
    for (const l of s.lines) if (l.r === 'pass') counts[l.kind] = (counts[l.kind] || 0) + 1;
    const passed = Object.entries(counts).map(([k, n]) => `${k} ${n}`).join(', ');
    if (passed) out.push(`    passed: ${passed}`);
  }
  return out;
}

// ---------------------------------------------------------------------------
// Blocked actions: the game's own Logs\taint.log (read only; turn it on in game with /console taintLog 1,
// then /reload). A block looks like:
//   11/19 10:12:03.957  An action was blocked because of taint from Wuber -
//   11/19 10:12:03.957      Interface/AddOns/Wuber/Drive/Danger.lua:165 listen()
// Listed per addon file and line (the first frame of the addon's own files), newest last, with a count.
// ---------------------------------------------------------------------------

function taintLogPath(wtf) {
  return path.join(wtf, '..', 'Logs', 'taint.log');
}

function readTaintLog(file) {
  const out = { file, found: false, blocks: [], total: 0 };
  let txt;
  try { txt = fs.readFileSync(file).toString('latin1'); } catch (e) { return out; }
  out.found = true;
  let cur = null;
  const byKey = new Map();
  for (const raw of txt.split(/\r?\n/)) {
    let m = /^(\S+ \S+)\s+An action was blocked because of taint from (\S+)/.exec(raw);
    if (m) { cur = { at: m[1], addon: m[2], file: null }; out.total++; continue; }
    if (cur && /^\S+ \S+\s{2,}\S/.test(raw) && /\.lua:\d+/.test(raw)) {
      const mm = /(Interface[\\/]AddOns[\\/][^\s]+?\.lua:\d+)(?:\s+(\S+\(\)))?/.exec(raw);
      if (mm && !cur.file && mm[1].replace(/\\/g, '/').split('/')[2] === cur.addon) {
        cur.file = mm[1].replace(/\\/g, '/').replace(/^Interface\/AddOns\//, '');
        cur.fn = mm[2] || '';
        const key = cur.addon + '|' + cur.file;
        const one = byKey.get(key) || { addon: cur.addon, where: cur.file, fn: cur.fn, n: 0, last: cur.at };
        one.n++; one.last = cur.at;
        byKey.set(key, one);
      }
    }
  }
  out.blocks = Array.from(byKey.values()).sort((a, b) => b.n - a.n);
  return out;
}

function blockedText(data) {
  const t = data.taintLog;
  const out = ['== Blocked actions (the game\'s Logs\\taint.log, read only)'];
  if (!t || !t.found) {
    out.push('No taint.log found. In game type /console taintLog 1, then /reload, play, and run this report again.');
    return out;
  }
  out.push(`${t.file}: ${t.total} blocked action${t.total === 1 ? '' : 's'} logged${t.blocks.length ? '' : ' (none from an addon file we could place)'}`);
  for (const b of t.blocks.slice(0, 30)) out.push(`  ${b.addon} ${b.where}${b.fn ? ' ' + b.fn : ''}: ${b.n}x, last ${b.last}`);
  if (t.blocks.length > 30) out.push(`  (+${t.blocks.length - 30} more places)`);
  return out;
}

function passiveHtml(data) {
  const pv = data.passive || { on: [], sessions: [], release: {} };
  const h = ['<h2>Passive play</h2>'];
  if (!pv.sessions.length && !pv.on.length) {
    h.push('<p class="muted">Passive play was never on.</p>');
    return h.join('');
  }
  h.push('<table><tr><th>release checklist</th><th>passive play</th></tr>');
  for (const it of passiveItems(data)) {
    const cls = it.mark === 'x' ? 'pass' : it.mark === '!' ? 'fail' : 'todo';
    h.push(`<tr${it.mark === '!' ? ' class="bad"' : ''}><td>${esc(it.title)}</td><td><span class="pill ${cls}">${it.mark === 'x' ? 'proved' : it.mark === '!' ? 'FAILED' : 'not seen'}</span> ${esc(it.text)}</td></tr>`);
  }
  h.push('</table>');
  for (const s of pv.sessions.slice().reverse().slice(0, 8)) {
    h.push(`<h3>${esc(s.char)} <span class="muted">${esc(day(s.started))} ${clock(s.started)} &middot; Wuber ${esc(s.wuber)} &middot; ${s.pass} passed, ${s.fail} failed, ${s.skip} skipped, ${s.look} to look at</span></h3><table>`);
    for (const l of s.lines) {
      h.push(`<tr${l.r === 'fail' ? ' class="bad"' : ''}><td>${esc(l.r)}</td><td>${esc(l.kind)}</td><td>${esc(l.subject)}</td><td class="muted">${esc(l.why)}</td><td class="t">${clock(l.at)}</td></tr>`);
    }
    h.push('</table>');
  }
  return h.join('');
}

// One saved run summary: lines "id|window|result|reason|epoch|took|judge|title"
function readRun(r, account) {
  const checks = [];
  for (const raw of asArray(r.lines)) {
    if (typeof raw !== 'string') continue;
    const f = raw.split('|');
    checks.push({ id: f[0], who: f[1] || '?', r: f[2] || 'todo', why: f[3] || '', at: f[4] ? Number(f[4]) : null,
      took: f[5] ? Number(f[5]) : null, judge: f[6] || '', title: f[7] || '' });
  }
  const count = (w) => checks.filter((c) => c.r === w).length;
  return { sid: String(r.sid), by: r.by || '?', started: Number(r.started) || 0, ended: Number(r.ended) || 0, why: r.why || '',
    sim: !!r.sim, wuber: r.wuber || '?', lab: r.lab || '?', scene: r.scene || null, later: Number(r.later) || 0, account, checks,
    pass: count('pass'), fail: count('fail'), look: count('look'), skip: count('skip'), todo: count('todo') };
}

// ---------------------------------------------------------------------------
// The test run in plain English
// ---------------------------------------------------------------------------

const RESULT_WORD = { pass: 'passed', fail: 'FAILED', look: 'to look at', skip: 'skipped', todo: 'not reached' };

// first names, but "Wuber Rocks" in full (plain "Wuber" reads as the addon)
function firstName(n) {
  const first = String(n || '?').split(' ')[0];
  return first === 'Wuber' ? String(n) : first;
}

function checkName(c) { return c.title ? `${c.title} (${c.id})` : c.id; }

function runText(data) {
  const out = [];
  const runs = data.runs || [];
  if (!runs.length) {
    out.push('== Test run');
    out.push('No test run saved yet ("Start test run" in the lab\'s Tools tab, then log out or /reload).');
  } else {
    const r = runs[runs.length - 1];
    const what = r.scene === 'pretend' ? 'pretend-rider run' : r.scene ? `"${r.scene}" run` : 'test run';
    out.push(`== Test run (the newest ${what}: ${day(r.started)} ${clock(r.started).slice(0, 5)}, started by ${r.by}` +
      `${r.sim ? ', test mode (no shards)' : ''}, Wuber ${r.wuber}, lab ${r.lab})`);
    const total = r.checks.length;
    const ended = r.ended ? (r.why === 'done' ? `It ran to the end at ${clock(r.ended).slice(0, 8)}` : `It was stopped (${r.why}) at ${clock(r.ended).slice(0, 8)}`)
      : 'It had not ended when the game last saved (still going, or the game closed mid-run)';
    out.push(`${ended}. ${total} checks: ${r.pass} passed, ${r.fail} failed, ${r.look} to look at, ${r.skip} skipped, ${r.todo} not reached.` +
      (r.later ? ` ${r.later} more were left for the next run (time budget).` : ''));
    if (!r.fail && !r.todo) out.push('Every check that ran passed by itself.');
    const groups = [['fail', 'Failed'], ['look', 'To look at (a screenshot each, in _forever_\\Screenshots)'], ['todo', 'Not reached'], ['skip', 'Skipped']];
    for (const [w, head] of groups) {
      const list = r.checks.filter((c) => c.r === w);
      if (!list.length) continue;
      out.push(`${head}:`);
      for (const c of list) out.push(`  - ${checkName(c)} on ${firstName(c.who)}'s window: ${c.why}${c.took >= 1 ? ` (after ${c.took} s)` : ''}`);
    }
    out.push('Every check, in order (result, window, seconds, why):');
    for (const c of r.checks) {
      out.push(`  [${c.r}] ${c.id} - ${firstName(c.who)}${c.took !== null ? ' ' + c.took + 's' : ''} - ${c.title ? c.title + ': ' : ''}${c.why}`);
    }
    if (runs.length > 1) {
      out.push('Earlier runs:');
      for (const o of runs.slice(0, -1).reverse()) {
        out.push(`  ${day(o.started)} ${clock(o.started).slice(0, 5)} by ${o.by}${o.scene ? ' (' + o.scene + ')' : ''}: ${o.pass} passed, ${o.fail} failed, ` +
          `${o.look} to look at, ${o.skip} skipped, ${o.todo} not reached${o.why && o.why !== 'done' ? ' - stopped: ' + o.why : ''}`);
      }
    }
  }
  out.push('');
  out.push('== Login checks (automatic, a few seconds after each login)');
  const names = Object.keys(data.login || {}).sort();
  if (!names.length) out.push('No login checks saved yet.');
  for (const n of names) {
    const l = data.login[n];
    const bad = l.checks.filter((c) => c.r === 'fail');
    const skip = l.checks.filter((c) => c.r === 'skip');
    const passed = l.checks.filter((c) => c.r === 'pass').length;
    out.push(`${n} (login ${day(l.at)} ${clock(l.at).slice(0, 5)}, Wuber ${l.wuber || '?'}): ` +
      (bad.length ? `${bad.length} of ${l.checks.length} FAILED` : `all ${passed} passed`) + (skip.length ? `, ${skip.length} skipped` : ''));
    for (const c of bad) out.push(`  FAIL ${c.id}: ${c.why}`);
    for (const c of skip) out.push(`  skip ${c.id}: ${c.why}`);
  }
  return out;
}

// ---------------------------------------------------------------------------
// The photo tour: each shot of the last tour matched (by time, within 2 s) to a file in Screenshots
// ---------------------------------------------------------------------------

const SHOT_RE = /^WoWScrnShot_(\d\d)(\d\d)(\d\d)_(\d\d)(\d\d)(\d\d)\.(jpg|tga|png)$/i;
const SHOT_SLACK = 2;

// The last tour: WuberLabDB.photoTour (newest saved), else the "photo" timeline lines after the last "tour start".
function findTour(db, lines) {
  const pt = db.photoTour;
  const shots = pt && typeof pt === 'object' ? asArray(pt.shots) : [];
  const list = shots.filter((s) => s && typeof s === 'object' && Number(s.at) > 0).map((s, k) => ({
    n: Number(s.n) || k + 1, id: String(s.id || '?'), title: String(s.title || ''), view: String(s.view || ''), at: Number(s.at) }));
  if (list.length) return { started: Number(pt.started) || list[0].at, ended: Number(pt.ended) || 0, shots: list, source: 'saved tour', subset: pt.subset ? String(pt.subset) : '' };
  return tourFromLines(lines);
}

function tourFromLines(lines) {
  let start = -1;
  const photo = (lines || []).filter((l) => l.kind === 'photo');
  photo.forEach((l, k) => { if (/^tour start/.test(l.text)) start = k; });
  const out = [];
  for (const l of photo.slice(start + 1)) {
    const m = /^tour shot (\d+)\/(\d+) (\S+) (folded|unfolded)(?: [|/] (.*))?$/.exec(l.text);
    if (m) out.push({ n: Number(m[1]), id: m[3], title: m[5] || '', view: m[4], at: l.t });
  }
  if (!out.length) return null;
  return { started: start >= 0 ? photo[start].t : out[0].at, ended: 0, shots: out, source: 'timeline' };
}

function shotName(at) {
  const d = new Date(Math.floor(at) * 1000);
  return `WoWScrnShot_${pad(d.getMonth() + 1)}${pad(d.getDate())}${pad(d.getFullYear() % 100)}_${pad(d.getHours())}${pad(d.getMinutes())}${pad(d.getSeconds())}.jpg`;
}

function listShots(dir) {
  const out = [];
  let names;
  try { names = fs.readdirSync(dir); } catch (e) { return null; }
  for (const name of names) {
    const m = SHOT_RE.exec(name);
    if (!m) continue;
    out.push({ name, t: new Date(2000 + Number(m[3]), Number(m[1]) - 1, Number(m[2]), Number(m[4]), Number(m[5]), Number(m[6])).getTime() / 1000 });
  }
  return out;
}

// rows: id, title, view, expected name, file (or null). Closest pairs are matched first; a file is used once.
function photoRows(tour, dir) {
  if (!tour) return [];
  const files = (dir && listShots(dir)) || [];
  const rows = tour.shots.map((s) => ({ n: s.n, id: s.id, title: s.title, view: s.view, at: s.at, expected: shotName(s.at), file: null }));
  const pairs = [];
  rows.forEach((r, i) => files.forEach((f, j) => {
    const d = Math.abs(f.t - Math.floor(r.at));
    if (d <= SHOT_SLACK) pairs.push({ i, j, d });
  }));
  pairs.sort((a, b) => a.d - b.d || a.i - b.i);
  const usedR = new Set();
  const usedF = new Set();
  for (const p of pairs) {
    if (usedR.has(p.i) || usedF.has(p.j)) continue;
    usedR.add(p.i);
    usedF.add(p.j);
    rows[p.i].file = files[p.j].name;
  }
  return rows;
}

function tourText(data) {
  const out = ['== Photo tour'];
  const tour = data.photoTour;
  if (!tour) { out.push('No photo tour saved yet ("/lab tour" in game, then log out or /reload).'); return out; }
  const dir = data.shotsDir;
  const rows = photoRows(tour, dir);
  const got = rows.filter((r) => r.file).length;
  out.push(`The last tour (${tour.source}${tour.subset ? ', partial tour: ' + tour.subset : ''}): ${day(tour.started)} ${clock(tour.started).slice(0, 8)}, ${rows.length} shots, ${got} with a file, ${rows.length - got} with no file.` +
    (dir ? ` Screenshots folder: ${dir}` : ' No Screenshots folder was found (use --shots <folder>).'));
  out.push('  # | id | title | view | file');
  for (const r of rows) {
    out.push(`  ${r.n} | ${r.id} | ${r.title} | ${r.view} | ${r.file || 'no file (expected ' + r.expected + ')'}`);
  }
  return out;
}

// ---------------------------------------------------------------------------
// (job 105c) Auto check: WuberLabDB.autoCheck, written by /lab auto (the Lab bar's "Auto check" button).
// The game looked over Wuber's screens itself: per screen the looks that passed, every result that needs a look,
// the manual steps (STEPS-*.md ids) it stood in for, and each screen's screenshot.
// ---------------------------------------------------------------------------

const AUTO_KINDS = ['cut', 'offscreen', 'overlap', 'under', 'buttons', 'scrollbar', 'tooltips'];

function readAuto(a, account) {
  if (!a || typeof a !== 'object' || Array.isArray(a)) return null;
  const counts = a.counts && typeof a.counts === 'object' ? a.counts : {};
  const steps = a.steps && typeof a.steps === 'object' && !Array.isArray(a.steps) ? a.steps : {};
  return {
    account, v: Number(a.v) || 0, started: Number(a.started) || 0, ended: Number(a.ended) || 0, char: String(a.char || '?'),
    wuber: String(a.wuber || '?'), lab: String(a.lab || '?'), stepsFile: a.stepsFile ? String(a.stepsFile) : '', reason: a.reason ? String(a.reason) : '',
    planned: Number(a.planned) || 0, done: Number(a.done) || 0, minutes: Number(a.minutes) || 0, screen: String(a.screen || ''), window: String(a.window || ''),
    api: String(a.api || ''), noTruncated: !!a.noTruncated, subset: a.subset ? String(a.subset) : '',
    distinct: Number(a.distinct) || 0, taintLog: a.taintLog === undefined || a.taintLog === null ? '' : String(a.taintLog),
    counts: { pass: Number(counts.pass) || 0, look: Number(counts.look) || 0, skip: Number(counts.skip) || 0, info: Number(counts.info) || 0 },
    screens: asArray(a.screens).filter((s) => s && typeof s === 'object').map((s) => ({
      id: String(s.id || '?'), view: String(s.view || ''), title: String(s.title || ''), n: Number(s.n) || 0, at: Number(s.at) || 0, pass: String(s.pass || ''),
      texts: Number(s.texts) || 0, tips: Number(s.tips) || 0, secure: Number(s.secure) || 0, scans: Number(s.scans) || 1, allowed: Number(s.allowed) || 0 })),
    results: asArray(a.results).filter((r) => r && typeof r === 'object').map((r) => ({
      id: String(r.id || '?'), view: String(r.view || ''), kind: String(r.kind || '?'), status: String(r.status || '?'), detail: String(r.detail || ''),
      steps: r.steps ? String(r.steps).split(',').filter(Boolean) : [] })),
    steps: Object.fromEntries(Object.entries(steps).map(([k, v]) => [k, String(v)])),
    speed: readSpeed(a.speed),
    shots: asArray(a.shots).filter((s) => s && typeof s === 'object' && Number(s.at) > 0).map((s, k) => ({
      n: Number(s.n) || k + 1, id: String(s.id || '?'), title: '', view: String(s.view || ''), at: Number(s.at) })),
  };
}

// each screen's screenshot file (matched by time like the photo tour's): "id view" -> file name or the expected name
function autoShots(auto, dir) {
  const map = new Map();
  for (const r of photoRows({ shots: auto.shots }, dir)) map.set(r.id + ' ' + r.view, r.file || ('no file (expected ' + r.expected + ')'));
  return map;
}

function stepSort(a, b) { return a.localeCompare(b, 'en', { numeric: true }); }

// job 2603: hand steps the Auto check now answers; the report names them (the step ids are hidden in the steps files)
const STEP_NAMES = {
  'GL-01': 'Options > AddOns > Wuber > "Open Wuber settings" shows Wuber\'s settings above the game\'s Options',
  'GL-02': 'the back arrow in Settings goes back to the page before, nothing left on top',
  'GL-03': 'the Ride page\'s portal turns smoothly, anticlockwise (was "Portal turn")',
  'GL-04': 'the Key Bindings entry "Open or close Wuber" is listed and opens and closes Wuber',
};
function stepLabel(id) { return STEP_NAMES[id] ? id + ' (' + STEP_NAMES[id] + ')' : id; }

// the same finding on many screens is one thing to look at: grouped by its words without the place and size
function autoGroups(results) {
  const groups = new Map();
  for (const r of results) {
    const words = r.detail.replace(/ at -?\d+,-?\d+ \(\d+ x \d+\)/g, '').replace(/ \(\d+ x \d+\)/g, '');
    const key = r.kind + '\u0001' + words + '\u0001' + r.steps.join(',');
    if (!groups.has(key)) groups.set(key, { kind: r.kind, status: r.status, detail: r.detail, steps: r.steps, on: [] });
    groups.get(key).on.push(r);
  }
  return [...groups.values()];
}

// (speed job 2749) The Auto check's timing pass (WuberLabDB.autoCheck.speed, lab/WuberLab/AutoSpeed.lua): per screen change the Lua ms of the call,
// the worst frame in the next second and Wuber's memory change; plus Wuber's total memory.
function readSpeed(s) {
  if (!s || typeof s !== 'object' || Array.isArray(s)) return null;
  const n = (x) => (typeof x === 'number' && isFinite(x) ? x : null);
  return {
    startKB: n(s.startKB), endKB: n(s.endKB), stopped: s.stopped ? String(s.stopped) : '',
    rows: asArray(s.rows).filter((r) => r && typeof r === 'object').map((r) => ({
      id: String(r.id || '?'), label: String(r.label || ''), ms: n(r.ms), frame: n(r.frame), kb: n(r.kb), kbEnd: n(r.kbEnd), note: r.note ? String(r.note) : '' })),
  };
}
const f1 = (x) => (x === null || x === undefined ? '?' : x.toFixed(1));
const kbSigned = (x) => (x === null || x === undefined ? '?' : (x >= 0 ? '+' : '') + x.toFixed(0));

function speedText(data) {
  const out = ['== Speed (the Auto check\'s timing pass: each screen change\'s own Lua time, the worst frame in the next second, Wuber\'s memory change)'];
  const sp = data.autoCheck && data.autoCheck.speed;
  if (!sp) { out.push('No timing pass in the last Auto check (press Auto check on the Lab bar; the pass is one of its screens, a_speed).'); return out; }
  if (sp.stopped) out.push('STOPPED EARLY (' + sp.stopped + '): the changes after that were not timed.');
  out.push('Change | what | ms (the call) | worst frame ms (next 1 s) | Wuber memory KB (1 s after the change minus just before)');
  for (const r of sp.rows) {
    out.push('  ' + r.id + ' | ' + (r.label || '-') + ' | ' + f1(r.ms) + ' ms | worst frame ' + f1(r.frame) + ' ms | ' + kbSigned(r.kb) + ' KB' + (r.note ? ' | ' + r.note : ''));
  }
  out.push('Wuber\'s total memory: ' + (sp.startKB === null ? '?' : sp.startKB.toFixed(0)) + ' KB at the start, ' + (sp.endKB === null ? '?' : sp.endKB.toFixed(0)) + ' KB at the end' +
    (sp.startKB !== null && sp.endKB !== null ? ' (' + kbSigned(sp.endKB - sp.startKB) + ' KB over the pass)' : '') + '.');
  return out;
}

function speedHtml(data) {
  const h = ['<h2>Speed</h2>'];
  const sp = data.autoCheck && data.autoCheck.speed;
  if (!sp) { h.push('<p class="muted">No timing pass in the last Auto check.</p>'); return h.join(''); }
  if (sp.stopped) h.push('<p class="red">stopped early: ' + esc(sp.stopped) + '</p>');
  h.push('<table><tr><th>change</th><th>what</th><th>ms</th><th>worst frame ms</th><th>memory KB (1 s after)</th></tr>');
  for (const r of sp.rows) {
    h.push('<tr><td>' + esc(r.id) + '</td><td>' + esc(r.label) + '</td><td>' + f1(r.ms) + '</td><td>' + f1(r.frame) + '</td><td>' + kbSigned(r.kb) + '</td></tr>');
  }
  h.push('</table><p>Wuber\'s total memory: ' + (sp.startKB === null ? '?' : sp.startKB.toFixed(0)) + ' KB at the start, ' + (sp.endKB === null ? '?' : sp.endKB.toFixed(0)) + ' KB at the end</p>');
  return h.join('');
}

function autoText(data) {
  const out = ['== Auto check (the game looked over Wuber\'s screens itself: the Lab bar\'s Auto check button, /lab auto)'];
  const a = data.autoCheck;
  if (!a) { out.push('No Auto check saved yet (press Auto check on the Lab bar, wait for "Auto check: N passed", then Reload).'); return out; }
  const shots = autoShots(a, data.shotsDir);
  out.push(`The last run: ${day(a.started)} ${clock(a.started).slice(0, 8)}, ${a.char}, Wuber ${a.wuber}, lab ${a.lab}${a.subset ? ', only: ' + a.subset : ''}; ` +
    `${a.done} of ${a.planned} screens in ${a.minutes} min; game window ${a.screen}; Wuber window ${a.window}.`);
  if (a.reason) out.push(`STOPPED EARLY (${a.reason}): the screens after that were not looked at. Press Auto check again.`);
  out.push(`Result: ${a.counts.pass} passed, ${a.counts.look} need a look, ${a.counts.skip} skipped, ${a.counts.info} notes.`);
  if (a.noTruncated) out.push('Note: this game has no FontString:IsTruncated; cut text was judged by width only (one-line texts).');
  if (a.api) out.push('Game API seen: ' + a.api + '.');
  const by = { pass: [], look: [], skip: [] };
  for (const [id, st] of Object.entries(a.steps)) (by[st] || by.look).push(id);
  for (const k of Object.keys(by)) by[k].sort(stepSort);
  out.push(`Manual steps it stood in for${a.stepsFile ? ' (' + a.stepsFile + ')' : ''}: ${by.pass.length} done by the game, ${by.look.length} need a look, ${by.skip.length} not done this time.`);
  if (by.pass.length) out.push('  done by the game (passed): ' + by.pass.map(stepLabel).join(', '));
  if (by.look.length) out.push('  NEED A LOOK: ' + by.look.map(stepLabel).join(', '));
  if (by.skip.length) out.push('  not done this time (skipped: do these by hand): ' + by.skip.map(stepLabel).join(', '));
  const line = (r) => `  [${r.status}] ${r.id} ${r.view} | ${r.kind}${r.steps.length ? ' | steps ' + r.steps.join(', ') : ''} | ${r.detail || '-'} | ${shots.get(r.id + ' ' + r.view) || 'no shot'}`;
  if (a.taintLog !== '') out.push(a.taintLog === '0' ? 'The taint log was OFF during the run (blocked actions, if any, were not written to Logs\\taint.log).' : 'The taint log was on during the run: see "Blocked actions" below.');
  const looks = a.results.filter((r) => r.status === 'look');
  const groups = autoGroups(looks);
  out.push(looks.length ? `Need a look (${looks.length} results, ${groups.length} different things):` : 'Nothing needs a look.');
  for (const g of groups) {
    const where = g.on.slice(0, 4).map((r) => `${r.id} ${r.view} (${shots.get(r.id + ' ' + r.view) || 'no shot'})`).join(', ') + (g.on.length > 4 ? `, and ${g.on.length - 4} more` : '');
    out.push(`  [look] ${g.kind}${g.steps.length ? ' | steps ' + g.steps.join(', ') : ''} | ${g.detail || '-'} | on ${g.on.length} screen${g.on.length === 1 ? '' : 's'}: ${where}`);
  }
  const skips = a.results.filter((r) => r.status === 'skip');
  if (skips.length) out.push('Skipped (' + skips.length + '):');
  for (const r of skips) out.push(line(r));
  const stood = a.results.filter((r) => r.status === 'pass' && r.steps.length);
  if (stood.length) out.push('Passed, standing in for a manual step (' + stood.length + '):');
  for (const r of stood) out.push(line(r));
  const notes = a.results.filter((r) => r.status === 'info');
  if (notes.length) out.push('Notes (not verdicts) (' + notes.length + '):');
  for (const r of notes) out.push(line(r));
  out.push('Every screen (# | id | view | passed | not passed | texts | tooltips opened | secure frames left alone | file):');
  for (const s of a.screens) {
    const passed = s.pass.split(' ').filter(Boolean);
    const not = AUTO_KINDS.filter((k) => !passed.includes(k));
    out.push(`  ${s.n || '-'} | ${s.id} | ${s.view} | ${passed.length}/${AUTO_KINDS.length} | ${not.join(' ') || '-'} | ${s.texts} | ${s.tips} | ${s.secure} | ${shots.get(s.id + ' ' + s.view) || 'no shot'}`);
  }
  return out;
}

function autoHtml(data) {
  const a = data.autoCheck;
  const h = ['<h2>Auto check</h2>'];
  if (!a) { h.push('<p class="muted">No Auto check saved yet.</p>'); return h.join(''); }
  const shots = autoShots(a, data.shotsDir);
  h.push(`<p class="muted">${esc(day(a.started))} ${esc(clock(a.started))} &middot; ${esc(a.char)} &middot; Wuber ${esc(a.wuber)} &middot; ${a.done} of ${a.planned} screens in ${a.minutes} min` +
    `${a.reason ? ' &middot; <span class="red">stopped early: ' + esc(a.reason) + '</span>' : ''} &middot; ${esc(a.screen)} &middot; window ${esc(a.window)}</p>`);
  h.push(`<p><span class="green">${a.counts.pass} passed</span>, <span class="${a.counts.look ? 'red' : 'muted'}">${a.counts.look} need a look</span>, ${a.counts.skip} skipped, ${a.counts.info} notes</p>`);
  const stepIds = Object.keys(a.steps).sort(stepSort);
  if (stepIds.length) {
    h.push('<p>Manual steps it stood in for: ' + stepIds.map((id) => `<span class="${a.steps[id] === 'pass' ? 'green' : a.steps[id] === 'look' ? 'red' : 'muted'}">${esc(stepLabel(id))} ${esc(a.steps[id])}</span>`).join(', ') + '</p>');
  }
  const rows = a.results.filter((r) => r.status !== 'pass' || r.steps.length);
  if (rows.length) {
    h.push('<table><tr><th>result</th><th>screen</th><th>view</th><th>check</th><th>steps</th><th>what</th><th>screenshot</th></tr>');
    const order = { look: 0, skip: 1, pass: 2, info: 3 };
    for (const r of rows.slice().sort((x, y) => (order[x.status] ?? 9) - (order[y.status] ?? 9))) {
      h.push(`<tr${r.status === 'look' ? ' class="bad"' : ''}><td>${r.status === 'pass' ? '<span class="green">pass</span>' : esc(r.status)}</td><td>${esc(r.id)}</td><td>${esc(r.view)}</td><td>${esc(r.kind)}</td>` +
        `<td>${esc(r.steps.join(', '))}</td><td class="muted">${esc(r.detail)}</td><td>${esc(shots.get(r.id + ' ' + r.view) || '')}</td></tr>`);
    }
    h.push('</table>');
  }
  h.push('<details><summary>Every screen (' + a.screens.length + ')</summary><table><tr><th>#</th><th>id</th><th>view</th><th>title</th><th>passed</th><th>texts</th><th>tooltips</th><th>screenshot</th></tr>');
  for (const s of a.screens) {
    const n = s.pass.split(' ').filter(Boolean).length;
    h.push(`<tr${n < AUTO_KINDS.length ? ' class="bad"' : ''}><td>${s.n || ''}</td><td>${esc(s.id)}</td><td>${esc(s.view)}</td><td>${esc(s.title)}</td><td>${n}/${AUTO_KINDS.length}</td>` +
      `<td>${s.texts}</td><td>${s.tips}</td><td>${esc(shots.get(s.id + ' ' + s.view) || '')}</td></tr>`);
  }
  h.push('</table></details>');
  return h.join('');
}

// ---------------------------------------------------------------------------
// (job 129) Game facts: WuberLabDB.facts, written by GameFacts.lua (the Lab bar's "Game facts" button, /lab facts).
// What the real game answered to the open "does it do X?" questions: one line per check with its newest answer.
// ---------------------------------------------------------------------------

// id, title, kind (passive = starts by itself, instant = one press and the end of an Auto check, moment = a press at the right moment)
const FACT_IDS = [
  ['L7', 'Spellbook after login', 'passive'], ['L6', 'Summoner name', 'passive'], ['L1', 'Summon state', 'passive'],
  ['L1.table', 'C_IncomingSummon', 'passive'], ['L3.read', 'Chat lock (reading)', 'passive'], ['L5', 'Wuber channel', 'passive'],
  ['L5.notice', 'Channel notices', 'passive'], ['L12.self', 'Player name shapes', 'passive'], ['L12.whisper', 'Whisper name and GUID', 'passive'],
  ['L13.style', 'Input style', 'passive'], ['L13.blocked', 'Blocked actions', 'passive'], ['L15.wuber', 'Chat font after Wuber\'s window', 'passive'],
  ['L10', 'Send result codes', 'instant'], ['L15', 'Chat font', 'instant'], ['L16', 'Realm facts', 'instant'], ['LBL', 'Blank or cut labels', 'instant'],
  ['L4', 'Right after loading', 'moment'], ['L3.send', 'Chat lock send', 'moment'], ['L8', 'Mounted click', 'moment'],
  ['L14.wuber', 'Map opened by Wuber', 'moment'], ['L14.safe', 'Map opened the safe way', 'moment'], ['B18', 'Can I remove?', 'moment'],
  ['B16', 'Flight map facts', 'moment'], ['LINE', 'Test lines sent', 'moment'], ['LINE.reply', 'Reply whisper shape', 'moment'],
];

function readFacts(f, account, out) {
  if (!f || typeof f !== 'object' || Array.isArray(f)) return;
  for (const [id, raw] of Object.entries(f)) {
    if (!out[id]) out[id] = [];
    for (const e of asArray(raw)) {
      if (!e || typeof e !== 'object') continue;
      const entry = { t: Number(e.t) || 0, build: String(e.build || ''), line: String(e.line || ''), account };
      if (id === 'slide' && e.a && typeof e.a === 'object') entry.a = e.a; // (job 135) the Slide check's numbers
      out[id].push(entry);
    }
  }
}

// one row per known check (in the Lab's order), then any id this report does not know; newest = the latest entry by time
function factRows(data) {
  const facts = (data && data.facts) || {};
  const rows = [];
  const known = new Set();
  const row = (id, title, kind) => {
    const list = (facts[id] || []).slice().sort((a, b) => a.t - b.t);
    rows.push({ id, title, kind, count: list.length, newest: list.length ? list[list.length - 1] : null });
  };
  for (const [id, title, kind] of FACT_IDS) { known.add(id); row(id, title, kind); }
  for (const id of Object.keys(facts).sort()) if (!known.has(id) && id !== 'slide') row(id, id, 'other'); // slide has its own part
  return rows;
}

function factsText(data) {
  const out = ['== Game facts (what the real game answered: the Lab bar\'s Game facts button, /lab facts)'];
  const rows = factRows(data);
  if (!rows.some((r) => r.newest)) {
    out.push('No Game facts saved yet (play a little, press Game facts on the Lab bar, then click Reload).');
  }
  for (const r of rows) {
    const none = r.kind === 'passive' ? 'not seen yet' : 'not run yet';
    if (!r.newest) { out.push(`  ${r.id} | ${r.title} | ${none}`); continue; }
    const n = r.newest;
    out.push(`  ${r.id} | ${r.title} | ${n.line || '-'} | ${r.count} entr${r.count === 1 ? 'y' : 'ies'} | ${day(n.t)} ${clock(n.t).slice(0, 5)}${n.build ? ' | build ' + n.build : ''}`);
  }
  return out;
}

function factsHtml(data) {
  const rows = factRows(data);
  const h = ['<h2>Game facts</h2>'];
  if (!rows.some((r) => r.newest)) h.push('<p class="muted">No Game facts saved yet.</p>');
  h.push('<table><tr><th>id</th><th>check</th><th>kind</th><th>newest answer</th><th>entries</th><th>when</th></tr>');
  for (const r of rows) {
    const n = r.newest;
    const none = r.kind === 'passive' ? 'not seen yet' : 'not run yet';
    h.push(`<tr><td>${esc(r.id)}</td><td>${esc(r.title)}</td><td class="muted">${esc(r.kind)}</td>` +
      (n ? `<td>${esc(n.line || '-')}</td><td>${r.count}</td><td class="t">${esc(day(n.t))} ${esc(clock(n.t))}</td></tr>` : `<td class="muted">${none}</td><td>0</td><td></td></tr>`));
  }
  h.push('</table>');
  return h.join('');
}

// ---------------------------------------------------------------------------
// (job 135) Slide check: WuberLabDB.facts.slide, written by SlideCheck.lua (the Lab bar's "Slide check" button, /lab slide).
// Does the game cut a child frame off at a SetClipsChildren(true) parent's edge when a Translation ANIMATION moves it?
// ---------------------------------------------------------------------------
function slideEntries(data) {
  return ((data && data.facts && data.facts.slide) || []).slice().sort((a, b) => a.t - b.t);
}

function slideMeaning(answer) {
  if (answer === 'cut') return 'Cut off: pages may slide by Translation';
  if (answer === 'stuck') return 'Stuck out: keep SetPoint for the slide';
  return 'no answer';
}

// the saved file writes a list-like table as an array and a sparse one as an object: the nth of either
function slideNth(x, n) {
  if (!x || typeof x !== 'object') return undefined;
  return Array.isArray(x) ? x[n - 1] : x[String(n)];
}

function slideNumbers(a) {
  const m1 = (a && slideNth(a.moves, 1)) || null;
  if (!m1) return '';
  const p = m1.page || {};
  const b = m1.box || {};
  const bits = [`move 1 hold: group progress ${m1.groupProgress ?? '-'}, paused ${m1.groupPaused ?? '-'}`,
    `page left ${p.left ?? '-'} right ${p.right ?? '-'}`, `box left ${b.left ?? '-'} right ${b.right ?? '-'}`];
  if (m1.clips !== undefined) bits.push(`DoesClipChildren ${m1.clips}`);
  if (m1.layoutOutside !== undefined) bits.push(`outside by layout ${m1.layoutOutside}`);
  return bits.join(', ');
}

function slideText(data) {
  const out = ['== Slide check (does the game cut a Translation-animated child off at a clipping parent\'s edge: the Lab bar\'s Slide check button, /lab slide)'];
  const list = slideEntries(data);
  if (!list.length) {
    out.push('Not answered yet (press Slide check on the Lab bar, wait about 20 seconds, answer the question, then click Reload).');
    return out;
  }
  const n = list[list.length - 1];
  const a = n.a || {};
  out.push(`  Answer: ${a.answer === 'cut' ? 'Cut off' : a.answer === 'stuck' ? 'Stuck out' : '-'} (${slideMeaning(a.answer)})`);
  out.push(`  Build: ${n.build || '-'} | ${day(n.t)} ${clock(n.t).slice(0, 5)} | ${list.length} entr${list.length === 1 ? 'y' : 'ies'} | runs in that session: ${a.runs ?? '-'}`);
  const nums = slideNumbers(a);
  if (nums) out.push('  Numbers: ' + nums);
  if (a.shots) out.push(`  Screenshots: move 1 ${slideNth(a.shots, 1) ?? '-'}, move 2 ${slideNth(a.shots, 2) ?? '-'}, move 3 ${slideNth(a.shots, 3) ?? '-'}`);
  if (list.length > 1) {
    const prev = list[list.length - 2];
    const pa = prev.a || {};
    out.push(`  Before that: ${pa.answer || '-'} (build ${prev.build || '-'})${pa.answer && a.answer && pa.answer !== a.answer ? ' : the two answers differ' : ''}`);
  }
  return out;
}

function slideHtml(data) {
  const list = slideEntries(data);
  const h = ['<h2>Slide check</h2>'];
  if (!list.length) { h.push('<p class="muted">Not answered yet.</p>'); return h.join(''); }
  const n = list[list.length - 1];
  const a = n.a || {};
  h.push(`<p><b>${esc(a.answer === 'cut' ? 'Cut off' : a.answer === 'stuck' ? 'Stuck out' : '-')}</b> - ${esc(slideMeaning(a.answer))}</p>`);
  h.push(`<p class="muted">build ${esc(n.build || '-')}, ${esc(day(n.t))} ${esc(clock(n.t))}, ${list.length} entr${list.length === 1 ? 'y' : 'ies'}</p>`);
  const nums = slideNumbers(a);
  if (nums) h.push(`<p class="muted">${esc(nums)}</p>`);
  return h.join('');
}

function tourHtml(data) {
  const tour = data.photoTour;
  const h = ['<h2>Photo tour</h2>'];
  if (!tour) { h.push('<p class="muted">No photo tour saved yet.</p>'); return h.join(''); }
  const rows = photoRows(tour, data.shotsDir);
  const got = rows.filter((r) => r.file).length;
  h.push(`<p class="muted">${esc(day(tour.started))} ${esc(clock(tour.started))} &middot; ${rows.length} shots, ${got} with a file` +
    (data.shotsDir ? ' &middot; ' + esc(data.shotsDir) : ' &middot; no Screenshots folder found') + '</p>');
  h.push('<table><tr><th>#</th><th>id</th><th>title</th><th>view</th><th>file</th></tr>');
  for (const r of rows) {
    h.push(`<tr${r.file ? '' : ' class="bad"'}><td>${r.n}</td><td>${esc(r.id)}</td><td>${esc(r.title)}</td><td>${esc(r.view)}</td>` +
      `<td>${r.file ? esc(r.file) : 'no file <span class="muted">(expected ' + esc(r.expected) + ')</span>'}</td></tr>`);
  }
  h.push('</table>');
  return h.join('');
}

// ---------------------------------------------------------------------------
// Rides: the rider's "ride"/"ridef" lines and the driver's "drv" lines, by ride id
// ---------------------------------------------------------------------------

function kv(parts) {
  const o = {};
  for (const p of parts) {
    const eq = p.indexOf('=');
    if (eq > 0) o[p.slice(0, eq)] = p.slice(eq + 1);
  }
  return o;
}

function buildRides(lines) {
  const rides = new Map();
  function ride(id) {
    if (!rides.has(id)) rides.set(id, { id, lanes: new Map(), flags: [], first: Infinity, last: -Infinity, info: {} });
    return rides.get(id);
  }
  for (const l of lines) {
    if (l.kind !== 'ride' && l.kind !== 'ridef' && l.kind !== 'drv') continue;
    const parts = l.text.split(';');
    const id = parts[0];
    if (!id || id === '-' || id === '?') continue;
    const r = ride(id);
    r.first = Math.min(r.first, l.t);
    r.last = Math.max(r.last, l.t);
    if (l.kind === 'ridef') {
      r.flags.push({ t: l.t, char: l.char, text: parts.slice(1).join(' ') });
      continue;
    }
    const o = kv(parts.slice(2));
    const lane = r.lanes.get(l.char) || [];
    lane.push({ t: l.t, stage: parts[1], dt: o.dt, extra: o });
    r.lanes.set(l.char, lane);
    if (l.kind === 'ride') {
      r.info.rider = l.char;
      r.info.driver = o.drv || r.info.driver;
      r.info.dest = o.dest || r.info.dest;
      r.info.price = o.price || r.info.price;
      r.info.fake = o.fake === 'yes';
      r.info.final = parts[1];
      if (o.reason) r.info.reason = o.reason;
    } else if (!r.info.driverChar) {
      r.info.driverChar = l.char;
    }
  }
  return [...rides.values()].sort((a, b) => a.first - b.first);
}

// ---------------------------------------------------------------------------
// Formatting
// ---------------------------------------------------------------------------

function pad(n, w = 2) { return String(n).padStart(w, '0'); }
function clock(t) {
  const d = new Date(t * 1000);
  return `${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}.${pad(d.getMilliseconds(), 3)}`;
}
function day(t) {
  const d = new Date(t * 1000);
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}
function stamp(d) {
  return `${d.getFullYear()}${pad(d.getMonth() + 1)}${pad(d.getDate())}-${pad(d.getHours())}${pad(d.getMinutes())}`;
}
function esc(s) {
  return String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}
function secs(x) {
  if (x === undefined || x === null || Number.isNaN(Number(x))) return '';
  return Number(x).toFixed(1) + 's';
}
function money(c) {
  c = Number(c);
  if (!Number.isFinite(c)) return '';
  const g = Math.floor(c / 10000), s = Math.floor((c % 10000) / 100), k = c % 100;
  return [g ? g + 'g' : '', s ? s + 's' : '', k ? k + 'c' : ''].filter(Boolean).join(' ') || '0';
}

// Every step of a character: its saved step list (all steps of the role) joined with results
function checklistRows(ch) {
  const rows = [];
  const seen = new Set();
  for (const s of ch.steps) {
    if (!s || typeof s !== 'object') continue;
    seen.add(s.id);
    rows.push({ id: s.id, sec: s.sec, text: s.text, manual: !!s.manual, rec: ch.checks[s.id] || null });
  }
  for (const id of Object.keys(ch.checks).sort()) {
    if (seen.has(id)) continue;
    const rec = ch.checks[id];
    rows.push({ id, sec: (rec && rec.sec) || '?', text: (rec && rec.text) || id, manual: false, rec });
  }
  return rows;
}

// The plan's steps with their shared results: { sec, id, text, who, check, auto, rec, probes }
function planRows(plan) {
  const rows = [];
  for (const s of plan.steps) {
    if (!s || typeof s !== 'object') continue;
    const probes = Object.keys(plan.entries).filter((k) => k.startsWith(s.id + '@'))
      .map((k) => `${k.split('@')[1]} ${plan.entries[k].r}`).sort();
    rows.push({ sec: s.sec, id: s.id, text: s.text, who: s.who, check: !!s.check, auto: !!s.auto, rec: plan.entries[s.id] || null, probes });
  }
  return rows;
}

function planWord(rec) {
  if (!rec || !rec.r) return 'not done';
  return rec.r === 'auto' ? 'auto' : rec.r;
}

function resultWord(rec) {
  if (!rec || !rec.r) return 'not done';
  return rec.r === 'auto' ? 'seen' : rec.r;
}

// ---------------------------------------------------------------------------
// The text summary (for reading by the main session)
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// The usage trail (WuberLab/Trail.lua): Struggles, and a plain timeline to line up with a voice
// recording. A trail line: "HH:MM:SS <action>[ @ <screen>]"; a huh line: "HH:MM:SS <words> -- last
// 30 s: <summary>". The clock is the game's own (the PC's), so it matches the voice file's.
// ---------------------------------------------------------------------------

const TRAIL_KINDS = new Set(['trail', 'huh']);
const STRUGGLE = {
  tabHops: 3, tabSecs: 60,       // 3+ switches between the same two tabs within 60 s
  hovers: 5, hoverSecs: 20,      // 5+ hovers with no click within 20 s
  backSecs: 60,                  // a setting changed and changed back within 60 s
  reopen: 3, reopenSecs: 120,    // the same screen opened 3+ times within 2 minutes
  hoverMax: 20,                  // a hover longer than this is the cursor left over a background window, not hunting
  causeSecs: 3,                  // Wuber's own bars count as opened by the player only after a click this near
  pause: 45,                     // 45 s+ on one screen, window open, no action
  shotNear: 300,                 // a screenshot further than this from an item is not "nearest"
};

// one trail/huh line -> { t, char, kind, clock, act, verb, screen, ... }
function parseTrail(l) {
  const m = /^([0-9]{2}:[0-9]{2}:[0-9]{2}) ([\s\S]*)$/.exec(l.text);
  let rest = m ? m[2] : l.text;
  const e = { t: l.t, char: l.char, kind: l.kind, clock: m ? m[1] : clock(l.t).slice(0, 8), screen: null };
  if (l.kind === 'huh') {
    const h = /^([\s\S]*?) -- last (\d+) s: ([\s\S]*)$/.exec(rest);
    e.verb = 'huh';
    e.words = h ? h[1] : rest;
    e.summary = h ? h[3] : '';
    e.act = 'HUH: ' + e.words + (e.summary ? ' (last ' + h[2] + ' s: ' + e.summary + ')' : '');
    return e;
  }
  const at = rest.lastIndexOf(' @ ');
  if (at >= 0) { e.screen = rest.slice(at + 3); rest = rest.slice(0, at); }
  e.act = rest;
  e.verb = (/^(\S+)/.exec(rest) || [, ''])[1];
  let x;
  if (e.verb === 'tab' && (x = /^tab (.+?) \(from (.+)\)$/.exec(rest))) { e.to = x[1]; e.from = x[2]; }
  else if (e.verb === 'screen') e.target = rest.slice(7);
  else if ((e.verb === 'click' || e.verb === 'hover' || e.verb === 'type') && (x = /^\S+(?: in)? "([^"]*)"/.exec(rest))) {
    e.label = x[1];
    if (e.verb === 'hover' && (x = /" ([\d.]+)s\b/.exec(rest))) e.secs = parseFloat(x[1]);
  }
  else if (e.verb === 'setting' && (x = /^setting (\S+): ([\s\S]*)$/.exec(rest))) {
    e.key = x[1];
    e.values = x[2].replace(/ \(back\)$/, '').split(' -> ');
  } else if (e.verb === 'open' || e.verb === 'close') e.target = rest.slice(e.verb.length + 1).replace(/ \(already open\)$/, '');
  return e;
}

function trailEvents(data) {
  return (data.trail || []).map(parseTrail);
}

function span(s) {
  s = Math.round(s);
  if (s < 60) return s + ' s';
  return Math.floor(s / 60) + ' min' + (s % 60 ? ' ' + (s % 60) + ' s' : '');
}

function uniq(list, max) {
  const out = [];
  for (const x of list) if (x && !out.includes(x)) out.push(x);
  return out.length > max ? out.slice(0, max).join(', ') + ', ...' : out.join(', ');
}

// what the tester struggled with: [{ t, clock, char, kind, text }], oldest first
function trailStruggles(events) {
  const S = STRUGGLE;
  const out = [];
  const add = (e, kind, text) => out.push({ t: e.t, clock: e.clock, char: e.char, kind, text });
  const byChar = new Map();
  for (const e of events) {
    if (!byChar.has(e.char)) byChar.set(e.char, []);
    byChar.get(e.char).push(e);
  }
  for (const evs of byChar.values()) {
    // tab hopping: 3+ switches between the same two tabs within 60 s
    const tabs = evs.filter((e) => e.verb === 'tab' && e.to && e.from);
    const pairOf = (e) => [e.from, e.to].sort().join(' <-> ');
    for (let i = 0; i < tabs.length;) {
      const pair = pairOf(tabs[i]);
      let n = 0, last = i;
      for (let k = i; k < tabs.length && tabs[k].t - tabs[i].t <= S.tabSecs; k++) {
        if (pairOf(tabs[k]) === pair) { n++; last = k; }
      }
      if (n >= S.tabHops) {
        add(tabs[i], 'tab hopping', pair + ': ' + n + ' switches in ' + span(tabs[last].t - tabs[i].t));
        i = last + 1;
      } else i++;
    }
    // hover hunting: 5+ hovers with no click within 20 s
    let run = [];
    const scanRun = () => {
      for (let i = 0; i < run.length;) {
        let last = i;
        while (last + 1 < run.length && run[last + 1].t - run[i].t <= S.hoverSecs) last++;
        const n = last - i + 1;
        if (n >= S.hovers) {
          add(run[i], 'hover hunting', n + ' hovers in ' + span(run[last].t - run[i].t) + ' with no click' +
            (run[i].screen ? ' on ' + run[i].screen : '') + ': ' + uniq(run.slice(i, last + 1).map((e) => e.label), 6));
          i = last + 1;
        } else i++;
      }
      run = [];
    };
    for (const e of evs) {
      if (e.verb === 'hover') { if (!(e.secs > S.hoverMax)) run.push(e); }
      else if (e.verb === 'click' || e.verb === 'type' || e.verb === 'setting' || e.verb === 'trail') scanRun();
    }
    scanRun();
    // toggled back: a setting changed and changed back within 60 s (or within one line: a -> b -> a)
    const sets = evs.filter((e) => e.verb === 'setting' && e.key && e.values && e.values.length >= 2);
    const used = new Set();
    sets.forEach((s, i) => {
      const v = s.values;
      if (v.length >= 3 && v[0] === v[v.length - 1] && v[0] !== '?') {
        add(s, 'toggled back', s.key + ': ' + v.join(' -> ') + ' (within a second or two)');
        return;
      }
      if (used.has(i) || v[0] === '?') return;
      for (let j = i + 1; j < sets.length && sets[j].t - s.t <= S.backSecs; j++) {
        if (sets[j].key !== s.key || used.has(j)) continue;
        const w = sets[j].values;
        if (w[w.length - 1] === v[0]) {
          used.add(j);
          add(s, 'toggled back', s.key + ': ' + v[0] + ' -> ' + v[v.length - 1] + ', back to ' + w[w.length - 1] + ' after ' + span(sets[j].t - s.t));
        }
        break; // the next change of this key decides
      }
    });
    // reopening: the same screen opened 3+ times within 2 minutes
    // (Wuber's own bars - mini bar, floating button, drive window, bell, crew offer - show and hide by themselves:
    // they count only when the player clicked something just before)
    const OWN = new Set(['mini bar', 'floating button', 'drive window', 'bell', 'crew offer', 'bug report']);
    const caused = (e) => evs.some((c) => (c.verb === 'click' || c.verb === 'type' || c.verb === 'tab') && c.t <= e.t && e.t - c.t <= S.causeSecs);
    const opens = evs.filter((e) => (e.verb === 'screen' && e.target) ||
      (e.verb === 'open' && e.target && e.target !== 'window' && (!OWN.has(e.target.replace(/ \(.*$/, '')) || caused(e))));
    const byTarget = new Map();
    for (const e of opens) {
      if (!byTarget.has(e.target)) byTarget.set(e.target, []);
      byTarget.get(e.target).push(e);
    }
    for (const [target, list] of byTarget) {
      for (let i = 0; i < list.length;) {
        let last = i;
        while (last + 1 < list.length && list[last + 1].t - list[i].t <= S.reopenSecs) last++;
        const n = last - i + 1;
        if (n >= S.reopen) {
          add(list[i], 'reopening', target + ' opened ' + n + ' times in ' + span(list[last].t - list[i].t));
          i = last + 1;
        } else i++;
      }
    }
    // long pause: 45 s+ on one screen with the window open and no action (hovers are not actions)
    let open = false, last = null, where = null;
    for (const e of evs) {
      if (e.verb === 'trail') {
        last = null;
        if (!/^trail (on|resumed)/.test(e.act)) open = false;
        continue;
      }
      if (e.verb === 'hover') continue;
      if (open && last && e.t - last.t >= S.pause) {
        add(last, 'long pause', span(e.t - last.t) + ' on ' + (where || '?') + ' with the window open, then: ' + e.act);
      }
      if (e.verb === 'open' && e.target === 'window') open = true;
      if (e.verb === 'close' && e.target === 'window') open = false;
      if (e.verb === 'screen') { open = true; where = e.target; } else if (e.screen) where = e.screen;
      last = e;
    }
    // every Huh
    for (const e of evs) if (e.verb === 'huh') add(e, 'huh', '"' + e.words + '"' + (e.summary ? ' - last 30 s: ' + e.summary : ''));
  }
  out.sort((a, b) => a.t - b.t);
  return out;
}

// the screenshot file nearest in time (WoWScrnShot_MMDDYY_HHMMSS.jpg), or null
function nearestShot(t, files) {
  let best = null;
  for (const f of files || []) {
    const d = f.t - Math.floor(t);
    if (!best || Math.abs(d) < Math.abs(best.dt)) best = { name: f.name, dt: d };
  }
  return best && Math.abs(best.dt) <= STRUGGLE.shotNear ? best : null;
}

function shotWord(s) {
  if (!s) return 'no screenshot within 5 min';
  return s.name + (s.dt ? ' (' + (s.dt > 0 ? '+' : '-') + span(Math.abs(s.dt)) + ')' : '');
}

// the plain timeline: [{ clock, char, screen, act }]
function trailTimeline(events) {
  const where = new Map();
  return events.map((e) => {
    let screen = e.screen;
    if (e.verb === 'screen') screen = e.target;
    if (!screen) screen = where.get(e.char) || '-';
    if (e.verb === 'screen') where.set(e.char, e.target);
    else if (e.verb === 'close' && e.target === 'window') where.set(e.char, null);
    else if (e.verb === 'trail' && !/^trail (on|resumed)/.test(e.act)) where.set(e.char, null);
    else if (e.screen) where.set(e.char, e.screen);
    return { t: e.t, clock: e.clock, char: e.char, screen, act: e.act, huh: e.verb === 'huh' };
  });
}

function trailHeader(data, events) {
  if (!events.length) return null;
  const chars = uniq(events.map((e) => e.char), 8);
  const huhs = events.filter((e) => e.verb === 'huh').length;
  return events.length + ' trail lines (' + chars + '), ' + day(events[0].t) + ' ' + events[0].clock + ' to ' +
    events[events.length - 1].clock + ', ' + huhs + ' Huh';
}

function strugglesText(data) {
  const out = ['== Struggles (usage trail: /lab trail on, the Huh key)'];
  const events = trailEvents(data);
  if (!events.length) {
    out.push('No usage trail saved yet ("/lab trail on" in game, play, then log out or /reload).');
    return out;
  }
  const files = (data.shotsDir && listShots(data.shotsDir)) || [];
  const items = trailStruggles(events);
  out.push(trailHeader(data, events) + '. ' + items.length + ' found.' +
    (data.shotsDir ? ' Screenshots: ' + data.shotsDir : ' No Screenshots folder (use --shots <folder>).'));
  const many = new Set(events.map((e) => e.char)).size > 1;
  for (const s of items) {
    out.push('  ' + s.clock + (many ? ' ' + s.char : '') + '  ' + s.kind + ': ' + s.text + '  [' + shotWord(nearestShot(s.t, files)) + ']');
  }
  if (!items.length) out.push('  (none: no tab hopping, hover hunting, settings toggled back, reopened screens, long pauses or Huh)');
  return out;
}

function timelineText(data) {
  const events = trailEvents(data);
  const out = ['== Trail timeline (clock time | screen | action): line it up with the voice recording'];
  if (!events.length) { out.push('(no trail)'); return out; }
  const many = new Set(events.map((e) => e.char)).size > 1;
  for (const r of trailTimeline(events)) {
    out.push(r.clock + (many ? ' | ' + r.char : '') + ' | ' + r.screen + ' | ' + (r.huh ? '>>> ' : '') + r.act);
  }
  return out;
}

function trailHtml(data) {
  const events = trailEvents(data);
  const h = ['<h2>Struggles (usage trail)</h2>'];
  if (!events.length) { h.push('<p class="muted">No usage trail saved yet (/lab trail on).</p>'); return h.join(''); }
  const files = (data.shotsDir && listShots(data.shotsDir)) || [];
  const items = trailStruggles(events);
  h.push('<p class="muted">' + esc(trailHeader(data, events)) + ' &middot; ' + items.length + ' found</p>');
  h.push('<table><tr><th>time</th><th>who</th><th>what</th><th>detail</th><th>nearest screenshot</th></tr>');
  for (const s of items) {
    h.push('<tr' + (s.kind === 'huh' ? ' class="bad"' : '') + '><td>' + esc(s.clock) + '</td><td>' + esc(s.char) + '</td><td>' + esc(s.kind) +
      '</td><td>' + esc(s.text) + '</td><td>' + esc(shotWord(nearestShot(s.t, files))) + '</td></tr>');
  }
  h.push('</table>');
  h.push('<details><summary>Trail timeline (' + events.length + ' lines)</summary><table><tr><th>time</th><th>who</th><th>screen</th><th>action</th></tr>');
  for (const r of trailTimeline(events)) {
    h.push('<tr' + (r.huh ? ' class="bad"' : '') + '><td>' + esc(r.clock) + '</td><td>' + esc(r.char) + '</td><td>' + esc(r.screen) + '</td><td>' + esc(r.act) + '</td></tr>');
  }
  h.push('</table></details>');
  return h.join('');
}

function textReport(data, rides, files, when) {
  const { chars, lines, problems } = data;
  const out = [];
  out.push(`Wuber Lab report - ${when.toISOString()}`);
  out.push(`Files: ${files.length} (${files.map((f) => f.account).join(', ')})`);
  if (lines.length) out.push(`Span: ${day(lines[0].t)} ${clock(lines[0].t)} .. ${day(lines[lines.length - 1].t)} ${clock(lines[lines.length - 1].t)}, ${lines.length} lines`);
  for (const p of problems) out.push(`PROBLEM: ${p}`);
  out.push('');
  for (const l of runText(data)) out.push(l);
  out.push('');
  for (const l of autoText(data)) out.push(l);
  out.push('');
  for (const l of speedText(data)) out.push(l);
  out.push('');
  for (const l of factsText(data)) out.push(l);
  out.push('');
  for (const l of slideText(data)) out.push(l);
  out.push('');
  for (const l of tourText(data)) out.push(l);
  out.push('');
  for (const l of passiveText(data)) out.push(l);
  out.push('');
  for (const l of blockedText(data)) out.push(l);
  out.push('');
  for (const l of strugglesText(data)) out.push(l);
  out.push('(the trail timeline: trail-latest.txt and the HTML)');
  out.push('');
  out.push('== Characters');
  for (const ch of Object.values(chars)) {
    const rows = checklistRows(ch);
    const done = rows.filter((r) => r.rec && r.rec.r).length;
    const failed = rows.filter((r) => r.rec && r.rec.r === 'fail').length;
    const st = ch.selftest && asArray(ch.selftest.list);
    const stText = st ? `${st.filter((x) => x && x.ok).length}/${st.length} self-test` : 'no self-test';
    out.push(`${ch.name} [${ch.role || '?'}] account ${ch.account}: ${ch.lines} lines${ch.dropped ? ` (+${ch.dropped} dropped)` : ''}, ` +
      `${ch.errors} errors, ${ch.blocked} blocked, checklist ${done}/${rows.length}${failed ? ` (${failed} FAIL)` : ''}, ${stText}` +
      `${ch.backup ? ', rider backup kept (Restore rider!)' : ''}`);
  }
  out.push('');
  const pr = planRows(data.plan);
  const pdone = pr.filter((r) => r.rec && r.rec.r).length;
  out.push(`== Plan (${pdone}/${pr.length} ticked${data.plan.resetAt ? ', reset ' + clock(data.plan.resetAt) : ''})`);
  for (const r of pr) {
    const rec = r.rec;
    out.push(`  [${planWord(rec)}] ${r.sec} / ${r.check ? 'Check: ' : ''}${r.text.slice(0, 110)}` +
      (rec && rec.r ? ` - ${clock(Number(rec.at))} by ${rec.who || '?'}${rec.by ? ' (' + rec.by + ')' : ''}` : '') +
      (rec && rec.note ? ` - note: ${rec.note}` : '') + (r.probes.length ? ` - probes: ${r.probes.join(', ')}` : ''));
  }
  out.push('');
  out.push('== Errors and blocked actions');
  const bad = lines.filter(isRed);
  if (!bad.length) out.push('(none)');
  const clearedN = lines.filter(isCleared).length;
  if (clearedN) out.push(`blocked list cleared (Retry): ${clearedN} time${clearedN === 1 ? '' : 's'} (not a blocked action)`);
  for (const l of bad) out.push(`${clock(l.t)} ${l.char} ${l.kind} ${l.text}`);
  out.push('');
  out.push('== Rides');
  if (!rides.length) out.push('(none)');
  for (const r of rides) {
    out.push(`Ride ${r.id}${r.info.fake ? ' (FAKE)' : ''}: ${r.info.rider || '?'} -> ${r.info.driver || r.info.driverChar || '?'}, ` +
      `${r.info.dest || '?'} ${money(r.info.price)}, ended ${r.info.final || '?'}${r.info.reason ? ' (' + r.info.reason + ')' : ''}, ` +
      `${(r.last - r.first).toFixed(1)}s from ${clock(r.first)}`);
    for (const [char, evs] of r.lanes) {
      out.push(`  ${char}: ` + evs.map((e) => `${e.stage}${e.dt !== undefined ? ' +' + secs(e.dt) : ''}`).join(' > '));
    }
    if (r.flags.length) out.push('  details: ' + r.flags.map((f) => f.text).join('; '));
  }
  out.push('');
  out.push('== Checklist (fails, notes and not done)');
  for (const ch of Object.values(chars)) {
    const rows = checklistRows(ch);
    const show = rows.filter((r) => !r.rec || !r.rec.r || r.rec.r === 'fail' || r.rec.note);
    out.push(`${ch.name}: ` + (show.length ? '' : 'all done, no notes'));
    for (const r of show) {
      out.push(`  [${resultWord(r.rec)}] ${r.sec} / ${r.text}${r.rec && r.rec.note ? ' - note: ' + r.rec.note : ''}`);
    }
  }
  out.push('');
  out.push('== Self-test failures');
  let anyFail = false;
  for (const ch of Object.values(chars)) {
    const st = ch.selftest && asArray(ch.selftest.list);
    if (!st) continue;
    for (const x of st) {
      if (x && !x.ok) {
        anyFail = true;
        out.push(`${ch.name}: ${x.name}${x.detail ? ' (' + x.detail + ')' : ''}`);
      }
    }
  }
  if (!anyFail) out.push('(none)');
  out.push('');
  out.push(`== Last ${TAIL_LINES} lines (all characters, by time)`);
  for (const l of lines.slice(-TAIL_LINES)) out.push(`${clock(l.t)} ${l.char} ${l.kind} ${l.text}`);
  return out.join('\n') + '\n';
}

// ---------------------------------------------------------------------------
// The HTML report
// ---------------------------------------------------------------------------

const CSS = `
:root{--bg:#0e0916;--panel:#17101f;--line:#3a2752;--text:#f2eef7;--muted:#a99cb9;--violet:#cd7df5;--deep:#883fda;--gold:#f9c53e;--red:#ff6b6b;--green:#5fd47a}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--text);font:13px/1.45 system-ui,Segoe UI,Arial,sans-serif}
header{padding:18px 24px;border-bottom:1px solid var(--line);background:linear-gradient(90deg,#1d1030,#0e0916)}
h1{margin:0;font-size:20px;color:var(--gold)}h2{font-size:15px;margin:26px 0 10px;color:var(--violet)}
main{padding:0 24px 40px}.muted{color:var(--muted)}.red{color:var(--red)}.green{color:var(--green)}.gold{color:var(--gold)}
.cards{display:flex;flex-wrap:wrap;gap:12px}.card{background:var(--panel);border:1px solid var(--line);border-radius:10px;padding:12px 14px;min-width:230px}
.card b{font-size:14px}table{border-collapse:collapse;width:100%}th,td{text-align:left;padding:4px 8px;border-bottom:1px solid #251a35;vertical-align:top}
th{color:var(--muted);font-weight:600}tr.bad td{color:var(--red)}td.t{white-space:nowrap;color:var(--muted);font-variant-numeric:tabular-nums}
.ride{background:var(--panel);border:1px solid var(--line);border-radius:10px;padding:10px 14px;margin:10px 0}
.lane{display:flex;align-items:center;margin:6px 0}.lane .who{width:120px;color:var(--muted);flex:none}
.track{position:relative;height:26px;flex:1;background:#120c1a;border-radius:6px;overflow:hidden}
.seg{position:absolute;top:0;bottom:0;border-right:2px solid #120c1a;color:#fff;font-size:11px;padding:5px 4px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.seg.end-bad{background:#7a2330!important}.pill{display:inline-block;padding:1px 8px;border-radius:9px;font-size:11px;background:#2a1c3d;color:var(--violet)}
.pill.fail{background:#4a1820;color:var(--red)}.pill.pass{background:#183a22;color:var(--green)}.pill.seen{background:#2a1c3d;color:var(--violet)}.pill.todo{background:#221a2c;color:var(--muted)}
#tl td{font-family:Consolas,monospace;font-size:12px}#tl td.k-err,#tl td.k-werr,#tl td.k-block,#tl td.k-laberr{color:var(--red)}
#tl td.k-mark{color:var(--gold)}#tl td.k-ride,#tl td.k-drv,#tl td.k-ridef{color:var(--violet)}#tl td.k-check{color:var(--green)}
#tl td.k-msgin,#tl td.k-msgout{color:#8d84a0}.controls{display:flex;gap:14px;align-items:center;margin:8px 0;flex-wrap:wrap}
input[type=text]{background:#120c1a;border:1px solid var(--line);color:var(--text);padding:5px 8px;border-radius:6px;width:260px}
`;

const SHADES = ['#4b2580', '#5a2d99', '#6a35b3', '#7a3ecc', '#883fda', '#9750e0', '#a663e6', '#b577ec', '#c48bf1'];

function rideHtml(r) {
  const span = Math.max(1, r.last - r.first) * 1.1; // room at the right for the last stage
  const out = [];
  const title = `${r.info.rider || '?'} &rarr; ${esc(r.info.driver || r.info.driverChar || '?')} &middot; ${esc(r.info.dest || '?')} &middot; ${esc(money(r.info.price))}`;
  const final = r.info.final || '?';
  const badEnd = /declined|cancelled|timeout|failed/.test(final);
  out.push(`<div class="ride"><div><b>Ride ${esc(r.id)}</b> ${r.info.fake ? '<span class="pill fail">FAKE</span> ' : ''}${title} &middot; ` +
    `<span class="${badEnd ? 'red' : 'green'}">${esc(final)}${r.info.reason ? ' (' + esc(r.info.reason) + ')' : ''}</span> ` +
    `<span class="muted">${clock(r.first)}, ${(r.last - r.first).toFixed(1)}s</span></div>`);
  for (const [char, evs] of r.lanes) {
    out.push(`<div class="lane"><div class="who">${esc(char)}</div><div class="track">`);
    evs.forEach((e, k) => {
      const end = k + 1 < evs.length ? evs[k + 1].t : r.first + span;
      const left = ((e.t - r.first) / span) * 100;
      const width = Math.max(0.8, Math.min(100 - left, ((end - e.t) / span) * 100));
      const bad = /declined|cancelled|timeout|failed/.test(e.stage);
      const dur = k + 1 < evs.length ? (evs[k + 1].t - e.t).toFixed(1) + 's' : '';
      out.push(`<div class="seg${bad ? ' end-bad' : ''}" style="left:${left.toFixed(2)}%;width:${width.toFixed(2)}%;background:${SHADES[k % SHADES.length]}" ` +
        `title="${esc(e.stage)} at ${clock(e.t)}${dur ? ', lasted ' + dur : ''}">${esc(e.stage)} ${dur}</div>`);
    });
    out.push('</div></div>');
  }
  const stages = [];
  for (const [char, evs] of r.lanes) {
    evs.forEach((e, k) => {
      stages.push(`<tr><td>${esc(char)}</td><td>${esc(e.stage)}</td><td class="t">${clock(e.t)}</td><td>${k + 1 < evs.length ? (evs[k + 1].t - e.t).toFixed(1) + 's' : ''}</td></tr>`);
    });
  }
  out.push(`<details><summary class="muted">stages and details</summary><table><tr><th>window</th><th>stage</th><th>at</th><th>lasted</th></tr>${stages.join('')}</table>`);
  if (r.flags.length) out.push(`<p class="muted">${r.flags.map((f) => esc(clock(f.t) + ' ' + f.text)).join('<br>')}</p>`);
  out.push('</details></div>');
  return out.join('');
}

function htmlReport(data, rides, files, when) {
  const { chars, lines, problems } = data;
  const names = Object.keys(chars);
  const h = [];
  h.push(`<!DOCTYPE html><html lang="en"><head><meta charset="utf-8"><title>Wuber Lab report ${esc(stamp(when))}</title><style>${CSS}</style></head><body>`);
  h.push(`<header><h1>Wuber Lab report</h1><div class="muted">${esc(when.toString())} &middot; ${files.length} file(s) &middot; ${lines.length} lines` +
    (lines.length ? ` &middot; ${esc(day(lines[0].t))} ${clock(lines[0].t)} to ${clock(lines[lines.length - 1].t)}` : '') + `</div></header><main>`);
  for (const p of problems) h.push(`<p class="red">${esc(p)}</p>`);

  const runs = data.runs || [];
  const lastRun = runs[runs.length - 1];
  h.push(`<h2>Test run${lastRun ? ` (${lastRun.pass} passed, ${lastRun.fail} failed, ${lastRun.look} to look at, ${lastRun.skip} skipped, ${lastRun.todo} not reached)` : ''}</h2>`);
  if (!lastRun) h.push('<p class="muted">No test run saved yet.</p>');
  else {
    h.push(`<p class="muted">${esc(day(lastRun.started))} ${clock(lastRun.started)} by ${esc(lastRun.by)}${lastRun.sim ? ' &middot; test mode (no shards)' : ''} &middot; ` +
      `${esc(lastRun.why ? (lastRun.why === 'done' ? 'ran to the end' : 'stopped: ' + lastRun.why) : 'not ended')}</p>`);
    h.push('<table><tr><th>check</th><th>window</th><th>result</th><th>seconds</th><th>why</th></tr>');
    for (const c of lastRun.checks) {
      const cls = c.r === 'fail' ? 'fail' : c.r === 'pass' ? 'pass' : c.r === 'look' ? 'seen' : 'todo';
      h.push(`<tr${c.r === 'fail' ? ' class="bad"' : ''}><td>${esc(c.title || c.id)} <span class="muted">${esc(c.id)}</span></td><td>${esc(c.who)}</td>` +
        `<td><span class="pill ${cls}">${esc(RESULT_WORD[c.r] || c.r)}</span></td><td class="t">${c.took !== null ? esc(String(c.took)) : ''}</td><td>${esc(c.why)}</td></tr>`);
    }
    h.push('</table>');
  }
  const lnames = Object.keys(data.login || {}).sort();
  h.push('<h2>Login checks</h2>');
  if (!lnames.length) h.push('<p class="muted">None saved yet.</p>');
  for (const n of lnames) {
    const l = data.login[n];
    h.push(`<h3>${esc(n)} <span class="muted">${esc(day(l.at))} ${clock(l.at)}</span></h3><table>`);
    for (const c of l.checks) {
      h.push(`<tr${c.r === 'fail' ? ' class="bad"' : ''}><td>${c.r === 'pass' ? '<span class="green">ok</span>' : esc(c.r)}</td><td>${esc(c.id)}</td><td class="muted">${esc(c.why)}</td></tr>`);
    }
    h.push('</table>');
  }

  h.push(autoHtml(data));
  h.push(speedHtml(data));
  h.push(factsHtml(data));
  h.push(slideHtml(data));
  h.push(tourHtml(data));
  h.push(passiveHtml(data));
  h.push(trailHtml(data));
  h.push('<h2>Characters</h2><div class="cards">');
  for (const ch of Object.values(chars)) {
    const rows = checklistRows(ch);
    const done = rows.filter((r) => r.rec && r.rec.r).length;
    const failed = rows.filter((r) => r.rec && r.rec.r === 'fail').length;
    const st = ch.selftest && asArray(ch.selftest.list);
    const stOk = st ? st.filter((x) => x && x.ok).length : 0;
    h.push(`<div class="card"><b>${esc(ch.name)}</b> <span class="pill">${esc(ch.role || '?')}</span><br>` +
      `<span class="muted">account ${esc(ch.account)} &middot; ${ch.lines} lines${ch.dropped ? ' (+' + ch.dropped + ' dropped)' : ''}</span><br>` +
      `checklist ${done}/${rows.length}${failed ? ` <span class="red">${failed} failed</span>` : ''}<br>` +
      `<span class="${ch.errors ? 'red' : 'green'}">${ch.errors} errors</span> &middot; <span class="${ch.blocked ? 'red' : 'green'}">${ch.blocked} blocked</span><br>` +
      (st ? `self-test <span class="${stOk === st.length ? 'green' : 'red'}">${stOk}/${st.length}</span>` : '<span class="muted">no self-test</span>') +
      (ch.backup ? '<br><span class="gold">rider backup kept: Restore rider!</span>' : '') + '</div>');
  }
  h.push('</div>');

  const bad = lines.filter(isRed);
  h.push(`<h2>Errors and blocked actions (${bad.length})</h2>`);
  if (!bad.length) h.push('<p class="green">None.</p>');
  else {
    h.push('<table><tr><th>time</th><th>window</th><th>kind</th><th>what</th></tr>');
    for (const l of bad) h.push(`<tr class="bad"><td class="t">${clock(l.t)}</td><td>${esc(l.char)}</td><td>${esc(l.kind)}</td><td>${esc(l.text)}</td></tr>`);
    h.push('</table>');
  }

  h.push(`<h2>Rides (${rides.length})</h2>`);
  if (!rides.length) h.push('<p class="muted">No rides logged.</p>');
  for (const r of rides) h.push(rideHtml(r));

  const pr = planRows(data.plan);
  h.push(`<h2>Plan (${pr.filter((r) => r.rec && r.rec.r).length}/${pr.length} ticked)</h2>`);
  if (!pr.length) h.push('<p class="muted">No plan saved yet.</p>');
  else {
    h.push('<table><tr><th>section</th><th>step</th><th>result</th><th>ticked</th><th>who ticked</th><th>how</th><th>note</th></tr>');
    for (const r of pr) {
      const rec = r.rec;
      const word = planWord(rec);
      const cls = word === 'fail' ? 'fail' : word === 'pass' ? 'pass' : word === 'auto' ? 'seen' : 'todo';
      h.push(`<tr${word === 'fail' ? ' class="bad"' : ''}><td>${esc(r.sec || '')}</td><td>${r.check ? '<span class="muted">Check:</span> ' : ''}${esc(r.text || r.id)}` +
        `${r.who ? ' <span class="pill">' + esc(r.who) + '</span>' : ''}</td><td><span class="pill ${cls}">${esc(word)}</span></td>` +
        `<td class="t">${rec && rec.r ? clock(Number(rec.at)) : ''}</td><td>${esc((rec && rec.r && rec.who) || '')}</td>` +
        `<td class="muted">${esc(rec && rec.r ? (rec.by === 'hand' ? 'manual' : 'auto: ' + (rec.by || '')) : (r.probes.length ? 'probes: ' + r.probes.join(', ') : ''))}</td>` +
        `<td>${esc((rec && rec.note) || '')}</td></tr>`);
    }
    h.push('</table>');
  }

  h.push('<h2>Checklist</h2>');
  for (const ch of Object.values(chars)) {
    const rows = checklistRows(ch);
    h.push(`<h3>${esc(ch.name)} <span class="pill">${esc(ch.role || '?')}</span></h3><table><tr><th>section</th><th>step</th><th>result</th><th>time taken</th><th>how</th><th>note</th></tr>`);
    for (const r of rows) {
      const word = resultWord(r.rec);
      const cls = word === 'fail' ? 'fail' : word === 'pass' ? 'pass' : word === 'seen' ? 'seen' : 'todo';
      h.push(`<tr${word === 'fail' ? ' class="bad"' : ''}><td>${esc(r.sec || '')}</td><td>${esc(r.text || r.id)}${r.manual ? ' <span class="muted">(by eye)</span>' : ''}</td>` +
        `<td><span class="pill ${cls}">${esc(word)}</span></td><td>${r.rec && r.rec.took !== undefined ? esc(secs(r.rec.took)) : ''}</td>` +
        `<td class="muted">${esc((r.rec && r.rec.by) || '')}</td><td>${esc((r.rec && r.rec.note) || '')}</td></tr>`);
    }
    h.push('</table>');
  }

  h.push('<h2>Self-test</h2>');
  for (const ch of Object.values(chars)) {
    const st = ch.selftest && asArray(ch.selftest.list);
    if (!st) { h.push(`<p><b>${esc(ch.name)}</b> <span class="muted">no results</span></p>`); continue; }
    h.push(`<h3>${esc(ch.name)} <span class="muted">${esc(ch.selftest.source || '')} ${ch.selftest.at ? clock(ch.selftest.at) : ''}</span></h3><table>`);
    for (const x of st) {
      if (!x) continue;
      h.push(`<tr${x.ok ? '' : ' class="bad"'}><td>${x.ok ? '<span class="green">ok</span>' : 'FAIL'}</td><td>${esc(x.name)}</td><td class="muted">${esc(x.detail || '')}</td></tr>`);
    }
    h.push('</table>');
  }

  h.push(`<h2>Timeline (${lines.length} lines, one column per window)</h2>`);
  h.push('<div class="controls"><input type="text" id="q" placeholder="filter: text, kind or ride id"> ' +
    '<label><input type="checkbox" id="nod" checked> hide repeated beacons and channel noise</label> ' +
    '<label><input type="checkbox" id="onlybad"> only errors and blocked</label> <span class="muted" id="count"></span></div>');
  h.push('<table id="tl"><thead><tr><th>time</th>' + names.map((n) => `<th>${esc(n)}</th>`).join('') + '</tr></thead><tbody>');
  for (const l of lines) {
    const col = names.indexOf(l.char);
    const kindCls = 'k-' + l.kind.replace('msg<', 'msgin').replace('msg>', 'msgout').replace(/[^a-z]/g, '');
    const noise = (l.kind === 'msg<' || l.kind === 'msg>') && /^(D|Q) /.test(l.text) ? 1 : 0;
    const cells = names.map((_, k) => (k === col ? `<td class="${kindCls}"><b>${esc(l.kind)}</b> ${esc(l.text)}</td>` : '<td></td>')).join('');
    h.push(`<tr data-k="${esc(l.kind)}" data-n="${noise}"><td class="t">${clock(l.t)}</td>${cells}</tr>`);
  }
  h.push('</tbody></table>');
  h.push(`<script>
(function(){var q=document.getElementById('q'),nod=document.getElementById('nod'),ob=document.getElementById('onlybad'),c=document.getElementById('count');
var rows=[].slice.call(document.querySelectorAll('#tl tbody tr'));var red={err:1,werr:1,block:1,laberr:1};
function run(){var s=q.value.toLowerCase(),n=0;rows.forEach(function(r){var k=r.getAttribute('data-k');
var show=(!nod.checked||r.getAttribute('data-n')!=='1')&&(!ob.checked||red[k])&&(!s||r.textContent.toLowerCase().indexOf(s)>=0);
r.style.display=show?'':'none';if(show)n++;});c.textContent=n+' shown';}
q.addEventListener('input',run);nod.addEventListener('change',run);ob.addEventListener('change',run);run();})();
</script>`);
  h.push('</main></body></html>');
  return h.join('\n');
}

// ---------------------------------------------------------------------------

function main(argv) {
  let wtfArg = null;
  let outDir = path.join(__dirname, '..', 'report');
  let now = new Date();
  let shotsArg = null;
  let taintArg = null;
  for (let k = 0; k < argv.length; k++) {
    if (argv[k] === '--out') outDir = argv[++k];
    else if (argv[k] === '--shots') shotsArg = argv[++k];
    else if (argv[k] === '--taint') taintArg = argv[++k];
    else if (argv[k] === '--now') now = new Date(argv[++k]);
    else if (!wtfArg) wtfArg = argv[k];
  }
  const wtf = resolveWTF(wtfArg);
  const files = findFiles(wtf);
  if (!files.length) throw new Error(`No WuberLab.lua under ${path.join(wtf, 'Account', '*', 'SavedVariables')}. Log out or /reload in game first.`);
  const data = load(files);
  data.taintLog = readTaintLog(taintArg || taintLogPath(wtf));
  data.shotsDir = shotsArg || path.join(wtf, '..', 'Screenshots');
  const rides = buildRides(data.lines);
  fs.mkdirSync(outDir, { recursive: true });
  const htmlPath = path.join(outDir, `lab-${stamp(now)}.html`);
  const txtPath = path.join(outDir, 'lab-latest.txt');
  fs.writeFileSync(htmlPath, htmlReport(data, rides, files, now));
  fs.writeFileSync(txtPath, textReport(data, rides, files, now));
  const trailPath = path.join(outDir, 'trail-latest.txt');
  fs.writeFileSync(trailPath, [...strugglesText(data), '', ...timelineText(data), ''].join('\n'));
  return { htmlPath, txtPath, trailPath, files, data, rides };
}

module.exports = { speedText, speedHtml, readSpeed, slideText, slideHtml, factsText, factsHtml, factRows, readFacts, FACT_IDS, autoText, autoHtml, readAuto, autoGroups, stepLabel, STEP_NAMES, strugglesText, timelineText, trailStruggles, trailTimeline, trailEvents, parseTrail, nearestShot, STRUGGLE, passiveText, passiveItems, blockedText, readTaintLog, tourText, photoRows, findTour, shotName, runText, planRows, parseLua, parseLuaFile, resolveWTF, findFiles, load, buildRides, textReport, htmlReport, main };

if (require.main === module) {
  try {
    const r = main(process.argv.slice(2));
    console.log(`Read ${r.files.length} file(s), ${r.data.lines.length} lines, ${Object.keys(r.data.chars).length} character(s), ${r.rides.length} ride(s).`);
    console.log(`Wrote ${r.htmlPath}`);
    console.log(`Wrote ${r.txtPath}`);
    console.log('');
    for (const l of runText(r.data)) {
      if (/^ {2}\[/.test(l) || /^Every check, in order/.test(l)) continue; // (the full list is in the file)
      console.log(l);
    }
    console.log('');
    for (const l of autoText(r.data)) {
      if (/^Every screen \(/.test(l)) { console.log('(every screen with its screenshot: lab-latest.txt)'); break; }
      console.log(l);
    }
    console.log('');
    for (const l of speedText(r.data)) console.log(l);
    console.log('');
    for (const l of factsText(r.data)) console.log(l);
    console.log('');
    for (const l of slideText(r.data)) console.log(l);
    console.log('');
    for (const l of tourText(r.data)) console.log(l);
    console.log('');
    for (const l of passiveText(r.data)) console.log(l);
    console.log('');
    for (const l of blockedText(r.data)) console.log(l);
    console.log('');
    for (const l of strugglesText(r.data)) console.log(l);
    console.log(`Wrote ${r.trailPath} (Struggles and the trail timeline)`);
  } catch (e) {
    console.error('labreport: ' + e.message);
    process.exit(1);
  }
}
