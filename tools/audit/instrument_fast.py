#!/usr/bin/env python3
"""Mutation run: instrument.py with one persistent Lua process for the parse checks (instrument.py starts
one Lua process per check, which takes hours for the whole addon's ~32,000 sites on Windows).
Same output and same runner patch as instrument.py.
Usage: python tools/audit/instrument_fast.py <scratch tree> <cand.json> <cand-ok.json>   (WUBER_LUA = Lua 5.1)
Never run on a real worktree: it rewrites the scratch tree's Wuber/ files and tests/run.lua."""
import sys, os, json, subprocess

if len(sys.argv) < 4 or sys.argv[1] in ('-h', '--help'):
    print(__doc__); sys.exit(0)
scratch, cj, okj = sys.argv[1:4]
LUA = os.environ.get('WUBER_LUA', 'lua5.1')
cands = json.load(open(cj))
CHECK = r'''
io.stdout:setvbuf("no")
while true do
  local n = io.read("*l")
  if not n then break end
  local src = io.read(tonumber(n))
  local f = loadstring(src)
  io.write(f and "1\n" or "0\n")
end
'''
p = subprocess.Popen([LUA, '-e', CHECK], stdin=subprocess.PIPE, stdout=subprocess.PIPE)
def parses(text):
    b = text.encode('utf-8')
    p.stdin.write(b'%d\n' % len(b)); p.stdin.write(b); p.stdin.flush()
    return p.stdout.readline().strip() == b'1'

byfile = {}
for c in cands: byfile.setdefault(c['file'], []).append(c)
ok, final = [], []
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
    # a mutant must parse on the plain file
    cs = [c for c in cs if parses('\n'.join(lines[:c['line'] - 1] + [c['new']] + lines[c['line']:]))]
    if parses(build(cs)):
        good = cs
    else:
        good = []
        for c in cs:
            if parses(build([c])): good.append(c)
        while good and not parses(build(good)):   # pairs that only fail together: drop from the end
            good.pop()
    open(path, 'wb').write(build(good).encode('utf-8'))
    ok += good
p.stdin.close(); p.wait()
json.dump(ok, open(okj, 'w'), indent=0)
print(len(cands), 'candidates;', len(ok), 'instrumented and parse as mutants')

rp = os.path.join(scratch, 'tests/run.lua')
t = open(rp, 'rb').read().decode('utf-8')
head = '''__HIT_CUR, __HITS = nil, {}
local __K = (table.concat(arg or {}, " "):match("%-%-shard (%d+)/") or "0")
local __hf = io.open("tests/out/hits." .. __K .. ".txt", "wb")
local __df = io.open("tests/out/defs." .. __K .. ".txt", "wb")
function __MH(id) local c = __HIT_CUR if c then local s = __HITS[c] if not s then s = {} __HITS[c] = s end s[id] = true end end
'''
t = head + t
a = '\tif H.onTestStart then H.onTestStart(name) end -- tools/coverage-map.lua: which test is running\n\tlocal ok, err = runOne(fn)\n'
if a not in t: a = a.replace('\n', '\r\n')
assert a in t, 'run.lua hook line not found'
b = '''\tif H.onTestStart then H.onTestStart(name) end
\tdo local di = debug.getinfo(fn, "S") __df:write(name, "\\t", tostring(di.short_src), ":", tostring(di.linedefined), "\\n") __df:flush() end
\t__HITS[name] = nil __HIT_CUR = name
\tlocal ok, err = runOne(fn)
\t__HIT_CUR = nil
\tdo local ids = {} for id in pairs(__HITS[name] or {}) do ids[#ids + 1] = id end table.sort(ids) __hf:write(name, "\\t", table.concat(ids, ","), "\\n") __hf:flush() __HITS[name] = nil end
'''
t = t.replace(a, b)
open(rp, 'wb').write(t.encode('utf-8'))
hp = os.path.join(scratch, 'tests/harness.lua')
h = open(hp, 'rb').read().decode('utf-8')
n1 = h.count('setfenv(chunk, env)')
h = h.replace('setfenv(chunk, env)', 'rawset(env, "__MH", __MH) setfenv(chunk, env)')
open(hp, 'wb').write(h.encode('utf-8'))
print('harness patched', n1)
