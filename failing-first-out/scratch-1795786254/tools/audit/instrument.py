#!/usr/bin/env python3
"""Test audit (job G): in a SCRATCH copy of the tree, put a hit marker in front of every candidate line and
patch the scratch tests/run.lua + harness.lua so each test records which marked lines it ran
(tests/out/hits.<K>.txt) and which file defines it (tests/out/defs.<K>.txt). Never run on a real worktree.
Usage: python tools/audit/instrument.py <scratch tree> <cand.json> <cand-ok.json>"""
import sys, os, json, subprocess

scratch, cj, okj = sys.argv[1:4]
LUA = os.environ.get('WUBER_LUA', 'lua5.1')
cands = json.load(open(cj))

def parses(path):
    r = subprocess.run([LUA, '-e', 'assert(loadfile(%r))' % path.replace('\\', '/')], capture_output=True)
    return r.returncode == 0

byfile = {}
for c in cands: byfile.setdefault(c['file'], []).append(c)
ok = []
for rel, cs in byfile.items():
    path = os.path.join(scratch, rel)
    orig = open(path, 'rb').read().decode('utf-8', 'replace')
    lines = orig.split('\n')
    def build(sel):
        L = list(lines)
        for c in sel:
            raw = L[c['line'] - 1]
            ind = raw[:len(raw) - len(raw.lstrip())]
            L[c['line'] - 1] = ind + '__MH(%d) ' % c['id'] + raw.lstrip()
        return '\n'.join(L)
    def write_try(sel):
        open(path, 'wb').write(build(sel).encode('utf-8'))
        return parses(path)
    if write_try(cs):
        ok += cs
    else:
        good = []
        for c in cs:
            if write_try(good + [c]): good.append(c)
        ok += good
        write_try(good)
# a mutant must parse too
final = []
for c in ok:
    path = os.path.join(scratch, c['file'] + '.mut')
    L = open(os.path.join(scratch, c['file']), 'rb').read().decode('utf-8', 'replace').split('\n')
    # the instrumented file has the marker: rebuild the mutant from the line's own old text
    L[c['line'] - 1] = c['new']
    open(path, 'wb').write('\n'.join(L).encode('utf-8'))
    good = parses(path)
    os.remove(path)
    if good: final.append(c)
json.dump(final, open(okj, 'w'), indent=0)
print(len(cands), 'candidates;', len(ok), 'instrumented;', len(final), 'also parse as mutants')

# --- patch the scratch test runner
rp = os.path.join(scratch, 'tests/run.lua')
t = open(rp, 'rb').read().decode('utf-8')
head = '''__HIT_CUR, __HITS = nil, {}
local __K = (table.concat(arg or {}, " "):match("%-%-shard (%d+)/") or "0")
local __hf = io.open("tests/out/hits." .. __K .. ".txt", "wb")
local __df = io.open("tests/out/defs." .. __K .. ".txt", "wb")
function __MH(id) local c = __HIT_CUR if c then local s = __HITS[c] if not s then s = {} __HITS[c] = s end s[id] = true end end
'''
t = head + t
a = '	if H.onTestStart then H.onTestStart(name) end -- tools/coverage-map.lua: which test is running\n	local ok, err = runOne(fn)\n'
assert a in t
b = '''	if H.onTestStart then H.onTestStart(name) end
	do local di = debug.getinfo(fn, "S") __df:write(name, "\\t", tostring(di.short_src), ":", tostring(di.linedefined), "\\n") __df:flush() end
	__HITS[name] = nil __HIT_CUR = name
	local ok, err = runOne(fn)
	__HIT_CUR = nil
	do local ids = {} for id in pairs(__HITS[name] or {}) do ids[#ids + 1] = id end table.sort(ids) __hf:write(name, "\\t", table.concat(ids, ","), "\\n") __hf:flush() __HITS[name] = nil end
'''
t = t.replace(a, b)
open(rp, 'wb').write(t.encode('utf-8'))
hp = os.path.join(scratch, 'tests/harness.lua')
h = open(hp, 'rb').read().decode('utf-8')
n1 = h.count('setfenv(chunk, env)')
h = h.replace('setfenv(chunk, env)', 'rawset(env, "__MH", __MH) setfenv(chunk, env)')
open(hp, 'wb').write(h.encode('utf-8'))
print('harness patched', n1)
