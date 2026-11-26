#!/usr/bin/env node
// build-seeds.js: rewrites the starter list (W.SEEDS in Wuber/Core/Base.lua, between the
// "-- BEGIN SEEDS" and "-- END SEEDS" lines) from the author's saved variables.
//
//   node tools/build-seeds.js [WTF folder] [--core path/to/Core/Base.lua] [--now epoch] [--days 14] [--max 30] [--dry-run]
//
// Reads WTF/Account/<account>/SavedVariables/Wuber.lua for every account: the founder
// directory (WuberDB.directory[key] = { name, lastSeen, dest, ruleset }) and the drivers each
// client heard (WuberDB.seenDrivers[key] = { name, at, ruleset, unlisted }). Keeps drivers
// seen in the last 14 days, never the founders (always in on their own ruleset, added by
// Core/Base.lua itself), never anyone who opted out ("List me in Wuber's starter list" off: the
// newest record says unlisted), and writes one list per ruleset ("EU-PvE", "US-PvP"...),
// the latest seen first, 30 at most each. Records without a ruleset take the account's
// WuberDB.ruleset (the ruleset at its last login); if that is unknown too, they are skipped.
// No npm packages; the Lua files are read by a small parser (never run).

'use strict';
const fs = require('fs');
const path = require('path');

const DEFAULT_WTF = 'C:\\Program Files (x86)\\World of Warcraft\\_forever_\\WTF';
const DEFAULT_CORE = path.join(__dirname, '..', 'Wuber', 'Core', 'Base.lua');
const BEGIN = '-- BEGIN SEEDS (tools/build-seeds.js)';
const END = '-- END SEEDS';
const FOUNDERS = new Set(['anita lift', 'farra way', 'hayley cab', 'wuber rocks']);
const NAME = /^[\p{L}][\p{L}'-]* [\p{L}][\p{L}'-]*$/u;

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

function keyOf(name) {
  return String(name).toLowerCase().replace(/[\s-]+/g, ' ').trim();
}

// WTF folder -> the Wuber.lua files under Account/*/SavedVariables (also a file given directly)
function findFiles(wtf) {
  if (fs.existsSync(wtf) && fs.statSync(wtf).isFile()) return [wtf];
  const tries = [wtf, path.join(wtf, 'WTF'), path.join(wtf, '_forever_', 'WTF')];
  const base = tries.find((t) => fs.existsSync(path.join(t, 'Account')));
  if (!base) throw new Error('No WTF\\Account folder found. Tried:\n  ' + tries.join('\n  '));
  const out = [];
  for (const acc of fs.readdirSync(path.join(base, 'Account'))) {
    const f = path.join(base, 'Account', acc, 'SavedVariables', 'Wuber.lua');
    if (fs.existsSync(f)) out.push(f);
  }
  return out;
}

// every record { key, name, at, ruleset, unlisted } from one WuberDB
function records(db) {
  const out = [];
  if (!db || typeof db !== 'object') return out;
  const fallback = typeof db.ruleset === 'string' ? db.ruleset : null;
  const take = (list, atField) => {
    if (!list || typeof list !== 'object' || Array.isArray(list)) return;
    for (const [k, e] of Object.entries(list)) {
      if (!e || typeof e !== 'object') continue;
      const name = typeof e.name === 'string' ? e.name.trim() : '';
      const at = Number(e[atField]);
      if (!name || !Number.isFinite(at)) continue;
      out.push({ key: keyOf(k), name, at, ruleset: typeof e.ruleset === 'string' ? e.ruleset : fallback, unlisted: e.unlisted === true });
    }
  };
  take(db.directory, 'lastSeen');
  take(db.seenDrivers, 'at');
  return out;
}

// { ruleset: [names] } from the files
function collect(files, opts) {
  const now = opts.now;
  const since = now - (opts.days || 14) * 86400;
  const newest = new Map();
  for (const f of files) {
    let globals;
    try {
      globals = parseLuaFile(f);
    } catch (err) {
      console.warn('skipped ' + f + ': ' + err.message);
      continue;
    }
    for (const r of records(globals.WuberDB)) {
      const old = newest.get(r.key);
      if (!old || r.at > old.at || (r.at === old.at && r.unlisted)) newest.set(r.key, r);
    }
  }
  const by = {};
  for (const r of newest.values()) {
    if (r.unlisted || FOUNDERS.has(r.key) || r.at < since || r.at > now + 86400) continue;
    if (!r.ruleset || !/^(EU|US)-[A-Za-z]+$/.test(r.ruleset) || !NAME.test(r.name)) continue;
    (by[r.ruleset] = by[r.ruleset] || []).push(r);
  }
  const lists = {};
  for (const [rs, list] of Object.entries(by)) {
    list.sort((a, b) => b.at - a.at || a.key.localeCompare(b.key));
    lists[rs] = list.slice(0, opts.max || 30).map((r) => r.name);
  }
  return lists;
}

function luaString(s) {
  return '"' + String(s).replace(/\\/g, '\\\\').replace(/"/g, '\\"') + '"';
}

// Core.lua's text with the block between the markers rewritten (rulesets already listed stay, emptied)
function rewrite(core, lists) {
  const b = core.indexOf(BEGIN);
  const e = core.indexOf(END, b);
  if (b < 0 || e < 0) throw new Error('Core.lua has no "' + BEGIN + '" ... "' + END + '" block');
  const old = core.slice(b, e);
  const names = [];
  for (const m of old.matchAll(/\["((?:EU|US)-[A-Za-z]+)"\]/g)) if (!names.includes(m[1])) names.push(m[1]);
  for (const rs of Object.keys(lists).sort()) if (!names.includes(rs)) names.push(rs);
  const lines = [BEGIN, 'W.SEEDS = {'];
  for (const rs of names) {
    const l = lists[rs] || [];
    lines.push('\t[' + luaString(rs) + '] = {' + (l.length ? ' ' + l.map(luaString).join(', ') + ' ' : '') + '},');
  }
  lines.push('}', '');
  const eol = core.includes('\r\n') ? '\r\n' : '\n';
  return core.slice(0, b) + lines.join(eol) + core.slice(e);
}

function main(argv) {
  const opts = { now: Math.floor(Date.now() / 1000), days: 14, max: 30, core: DEFAULT_CORE, dry: false, wtf: null };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--core') opts.core = argv[++i];
    else if (a === '--now') opts.now = Number(argv[++i]);
    else if (a === '--days') opts.days = Number(argv[++i]);
    else if (a === '--max') opts.max = Number(argv[++i]);
    else if (a === '--dry-run') opts.dry = true;
    else opts.wtf = a;
  }
  const files = findFiles(opts.wtf || DEFAULT_WTF);
  const lists = collect(files, opts);
  const core = fs.readFileSync(opts.core, 'utf8');
  const next = rewrite(core, lists);
  const total = Object.values(lists).reduce((n, l) => n + l.length, 0);
  if (opts.dry) {
    process.stdout.write(next.slice(next.indexOf(BEGIN), next.indexOf(END) + END.length) + '\n');
  } else if (next !== core) {
    fs.writeFileSync(opts.core, next);
  }
  console.log(`${files.length} saved variables file(s), ${total} driver(s) in ${Object.keys(lists).length} ruleset(s)` +
    (opts.dry ? ' (dry run)' : (next !== core ? ', Core.lua updated' : ', Core.lua unchanged')));
  return { files, lists };
}

module.exports = { parseLua, records, collect, rewrite, main, BEGIN, END };

if (require.main === module) {
  try {
    main(process.argv.slice(2));
  } catch (err) {
    console.error(err.message);
    process.exit(1);
  }
}
