#!/usr/bin/env python3
"""Prove a test notices a mutant: apply one mutant line in a worktree, run the named tests, put the file back.
Usage: python tools/audit/prove_mutant.py <worktree> <mutants.json> <id> "<test name filter>" [--lua lua5.1]
mutants.json: a list of {"id", "file", "line", "old", "new"} (cand-ok.json of the mutation run, or an area's spec).
Prints "KILLED <id>" (a test failed with the mutant in place), "SURVIVED <id>" (every test passed: the test does not
protect that line) or "NO TESTS <id>" (the filter matched none), then the base run's result for the same filter.
Exit 0 killed and the base passes, 1 otherwise. The file is restored even on errors; it refuses when the line on disk
is not the mutant's "old" text (the tree moved: rebuild the spec)."""
import sys, os, json, subprocess, re
if len(sys.argv) < 5 or sys.argv[1] in ('-h', '--help'):
    print(__doc__); sys.exit(0)
wt, spec, mid, filt = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4]
lua = sys.argv[sys.argv.index('--lua') + 1] if '--lua' in sys.argv else os.environ.get('WUBER_LUA', 'lua5.1')
c = next(x for x in json.load(open(spec, encoding='utf-8')) if x['id'] == mid)
path = os.path.join(wt, c['file'])
raw = open(path, 'rb').read()
L = raw.decode('utf-8').split('\n')
if L[c['line'] - 1].rstrip('\r') != c['old'].rstrip('\r'):
    print('REFUSED %d: %s:%d is not the old line any more' % (mid, c['file'], c['line'])); sys.exit(1)
env = dict(os.environ, WUBER_LAB_DIR=os.path.join(wt, 'lab', 'WuberLab'))
def run():
    r = subprocess.run([lua, 'tests/run.lua', filt], cwd=wt, env=env, capture_output=True, timeout=900)
    out = r.stdout.decode('utf-8', 'replace')
    m = re.search(r'(\d+) passed, (\d+) failed', out)
    return (int(m.group(1)), int(m.group(2))) if m else (0, 0), [l[6:].rstrip('\r') for l in out.split('\n') if l.startswith('FAIL  ')]
try:
    L[c['line'] - 1] = c['new']
    open(path, 'wb').write('\n'.join(L).encode('utf-8'))
    (p, f), fails = run()
finally:
    open(path, 'wb').write(raw)
(bp, bf), bfails = run()
word = 'NO TESTS' if p + f == 0 else ('KILLED' if f else 'SURVIVED')
print('%s %d  (%s:%d %s) mutant: %d passed, %d failed; base: %d passed, %d failed' % (word, mid, c['file'], c['line'], c['kind'] if 'kind' in c else '', p, f, bp, bf))
for n in fails[:5]: print('  mutant FAIL', n)
for n in bfails[:5]: print('  BASE FAIL', n)
sys.exit(0 if f and not bf and bp else 1)
