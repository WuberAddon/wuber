#!/usr/bin/env node
// Release safety check: fails (exit 1) if a release folder or .zip contains the developer-only
// Wuber Lab addon, or any file that mentions it (a TOC dependency, a hook, a comment...).
//
//   node release-check.js <release folder or .zip> [more...]
//
// No npm packages: zips are read with Node's own zlib (stored and deflated entries).
'use strict';

const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

const NEEDLE = /wuber[\s_-]?lab(?!el|or|ou)/i; // not "Wuber label"

// Every { name, data } in a zip (central directory; local headers for the data offsets).
function zipEntries(buf) {
  let eocd = -1;
  for (let i = buf.length - 22; i >= Math.max(0, buf.length - 22 - 65557); i--) {
    if (buf.readUInt32LE(i) === 0x06054b50) { eocd = i; break; }
  }
  if (eocd < 0) throw new Error('not a zip file (no end of central directory)');
  const count = buf.readUInt16LE(eocd + 10);
  let p = buf.readUInt32LE(eocd + 16);
  const out = [];
  for (let k = 0; k < count; k++) {
    if (buf.readUInt32LE(p) !== 0x02014b50) throw new Error('bad zip central directory');
    const method = buf.readUInt16LE(p + 10);
    const csize = buf.readUInt32LE(p + 20);
    const nameLen = buf.readUInt16LE(p + 28);
    const extraLen = buf.readUInt16LE(p + 30);
    const commentLen = buf.readUInt16LE(p + 32);
    const local = buf.readUInt32LE(p + 42);
    const name = buf.slice(p + 46, p + 46 + nameLen).toString('utf8');
    p += 46 + nameLen + extraLen + commentLen;
    if (buf.readUInt32LE(local) !== 0x04034b50) throw new Error('bad zip local header for ' + name);
    const start = local + 30 + buf.readUInt16LE(local + 26) + buf.readUInt16LE(local + 28);
    const raw = buf.slice(start, start + csize);
    let data = null;
    if (name.endsWith('/')) data = Buffer.alloc(0);
    else if (method === 0) data = raw;
    else if (method === 8) data = zlib.inflateRawSync(raw);
    else data = null; // unknown compression: the name is still checked, the content is reported
    out.push({ name, data, method });
  }
  return out;
}

function walk(dir, base, out) {
  for (const name of fs.readdirSync(dir).sort()) {
    const full = path.join(dir, name);
    const rel = path.relative(base, full);
    const st = fs.statSync(full);
    if (st.isDirectory()) {
      out.push({ name: rel + '/', data: Buffer.alloc(0) });
      walk(full, base, out);
    } else {
      out.push({ name: rel, data: fs.readFileSync(full) });
    }
  }
  return out;
}

// Problems found in one release (a folder or a zip): a list of strings, empty when clean.
function check(target) {
  const problems = [];
  if (!fs.existsSync(target)) return [`${target}: not found`];
  let entries;
  const st = fs.statSync(target);
  if (st.isDirectory()) {
    if (NEEDLE.test(path.basename(path.resolve(target)))) problems.push(`${target}: the folder itself is Wuber Lab`);
    entries = walk(target, target, []);
  } else if (/\.zip$/i.test(target)) {
    entries = zipEntries(fs.readFileSync(target));
  } else {
    entries = [{ name: path.basename(target), data: fs.readFileSync(target) }];
  }
  for (const e of entries) {
    if (NEEDLE.test(e.name)) problems.push(`${e.name}: a Wuber Lab file or folder`);
    if (e.data === null) {
      problems.push(`${e.name}: can't read (compression method ${e.method}); check it by hand`);
      continue;
    }
    if (e.data.length && NEEDLE.test(e.data.toString('latin1'))) {
      const text = e.data.toString('latin1').split(/\r?\n/);
      const hits = [];
      text.forEach((line, k) => { if (NEEDLE.test(line)) hits.push(k + 1); });
      problems.push(`${e.name}: mentions Wuber Lab (line ${hits.slice(0, 5).join(', ')}${hits.length > 5 ? ', ...' : ''})`);
    }
  }
  if (!entries.length) problems.push(`${target}: empty`);
  return problems;
}

module.exports = { check, zipEntries };

if (require.main === module) {
  const targets = process.argv.slice(2);
  if (!targets.length) {
    console.error('usage: node release-check.js <release folder or .zip> [more...]');
    process.exit(2);
  }
  let bad = 0;
  for (const t of targets) {
    let problems;
    try {
      problems = check(t);
    } catch (e) {
      problems = [`${t}: ${e.message}`];
    }
    if (problems.length) {
      bad++;
      console.error(`FAIL ${t}`);
      for (const p of problems) console.error('  ' + p);
    } else {
      console.log(`ok   ${t}: no Wuber Lab in it`);
    }
  }
  process.exit(bad ? 1 : 0);
}
