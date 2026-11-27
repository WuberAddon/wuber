#!/usr/bin/env python3
"""Mutation run over the whole addon: one mutant at a time in scratch copies, each against only the tests that
ran its line (from instrument_fast.py's hit run), cheapest tests first, stopping at the first failure.
Usage: python tools/audit/run_mutants_fast.py --work <dir with mut-1..mut-N> --cand cand-ok.json --hits hits.tsv
         --basefail basefail.txt --defs defs.tsv --times tests/fixtures/test-times.txt --out mutants.csv
         [--budget 20] [--full] [--workers 6] [--hours 1] [--order risk|id] [--ids file]
--budget: seconds of (estimated) test time a mutant gets in this pass; --full: every test that ran the line.
Row: id, file:line, kind, ntests, status (killed / survived / partial / uncovered), killed_by, seconds, tests run.
"partial" = no failure in the tests run, but more tests ran the line (a later --full pass decides).
The scratch copies' tests/run.lua must stop at the first FAIL when WUBER_BAIL is set (--patch-bail does it).
Resumable: ids already in --out are skipped. Never point --work at a real worktree."""
import re, sys, os, json, csv, subprocess, threading, time, argparse
ap = argparse.ArgumentParser()
for f in ('work', 'cand', 'hits', 'basefail', 'defs', 'times', 'out', 'ids'): ap.add_argument('--' + f)
ap.add_argument('--budget', type=float, default=20.0); ap.add_argument('--full', action='store_true')
ap.add_argument('--workers', type=int, default=6); ap.add_argument('--hours', type=float, default=1.0)
ap.add_argument('--order', default='risk'); ap.add_argument('--timeout', type=int, default=300)
ap.add_argument('--patch-bail', action='store_true'); ap.add_argument('--lua', default=os.environ.get('WUBER_LUA', 'lua5.1'))
a = ap.parse_args()
csv.field_size_limit(10**9)

if a.patch_bail:
    for k in range(1, a.workers + 1):
        rp = os.path.join(a.work, 'mut-%d' % k, 'tests', 'run.lua')
        t = open(rp, 'rb').read().decode('utf-8')
        old = 'print("FAIL  " .. name .. "\\n      " .. tostring(err):gsub("\\n", "\\n      "))'
        if 'WUBER_BAIL' not in t:
            assert old in t, 'run.lua FAIL line not found'
            t = t.replace(old, old + ' if os.getenv("WUBER_BAIL") then io.stdout:flush() os.exit(1) end')
            open(rp, 'wb').write(t.encode('utf-8'))
    print('bail patched'); sys.exit(0)

cands = {c['id']: c for c in json.load(open(a.cand))}
basefail = set(l.strip() for l in open(a.basefail, encoding='utf-8'))
hit = {}
for l in open(a.hits, encoding='utf-8'):
    n, _, ids = l.rstrip('\n').partition('\t')
    if n in basefail: continue
    for i in ids.split(','):
        if i: hit.setdefault(int(i), []).append(n)
cost = {}
for l in open(a.times, encoding='utf-8'):
    t, _, n = l.rstrip('\n').partition('\t')
    try: cost[n] = float(t)
    except ValueError: pass
part = {}
for l in open(a.defs, encoding='utf-8'):
    n, _, src = l.rstrip('\n').partition('\t')
    p = src.rsplit(':', 1)[0].replace('\\', '/')
    part[n] = 'run' if p == 'tests/run.lua' else (p[6:-4] if p.startswith('tests/') and p.endswith('.lua') else '')

DIRW = {'Net': 3.0, 'Drive': 3.0, 'Core': 2.5, 'UI': 1.5, 'Theme': 0.7, 'FX': 0.5}
HOT = re.compile(r'trade|money|gold|invite|summon|pay|price|founder|secure|whisper|send|queue|accept|raid|group|party|ban|block|taint|combat', re.I)
def risk(c):
    d = c['file'].split('/')[1] if '/' in c['file'] else ''
    r = DIRW.get(d, 1.0)
    if HOT.search(c['file']): r += 1.5
    if HOT.search(c['old']): r += 1.0
    if c['kind'].startswith(('cmp', 'if cond', 'return')): r += 0.5
    return r
def run_out_ids(p):
    s = set()
    if p and os.path.exists(p):
        for r in csv.reader(open(p, encoding='utf-8')):
            if r and r[0].isdigit(): s.add(int(r[0]))
    return s
done = run_out_ids(a.out)
if a.ids: ids = [int(x) for x in open(a.ids).read().split() if x.strip()]
else:
    ids = sorted(cands, key=(lambda i: (-risk(cands[i]), i)) if a.order == 'risk' else (lambda i: i))
queue = [i for i in ids if i not in done]
deadline = time.time() + a.hours * 3600
lock = threading.Lock()
outf = open(a.out, 'a', newline='', encoding='utf-8'); w = csv.writer(outf)

def worker(k):
    d = os.path.join(a.work, 'mut-%d' % k)
    env = dict(os.environ, WUBER_LAB_DIR=os.path.join(d, 'lab', 'WuberLab'), WUBER_BAIL='1')
    nf = os.path.join(d, 'tests', 'out', 'names.txt'); os.makedirs(os.path.dirname(nf), exist_ok=True)
    while True:
        with lock:
            if not queue or time.time() > deadline: return
            i = queue.pop(0)
        c = cands[i]; names = sorted(set(hit.get(i, [])), key=lambda n: cost.get(n, 0.5))
        t0 = time.time(); ran = 0
        if not names:
            status, killed = 'uncovered', []
        else:
            sel, tot = [], 0.0
            for n in names:
                if sel and not a.full and tot + cost.get(n, 0.5) > a.budget: break
                sel.append(n); tot += cost.get(n, 0.5)
            path = os.path.join(d, c['file']); raw = open(path, 'rb').read()
            L = raw.decode('utf-8').split('\n'); L[c['line'] - 1] = c['new']
            open(path, 'wb').write('\n'.join(L).encode('utf-8'))
            try:
                open(nf, 'w', encoding='utf-8').write('\n'.join(sel) + '\n')
                parts = sorted(set(part.get(n, '') for n in sel))
                cmd = [a.lua, 'tests/run.lua', '--names=tests/out/names.txt']
                if parts and '' not in parts: cmd.append('--files=' + ','.join(parts))
                r = subprocess.run(cmd, cwd=d, env=env, capture_output=True, timeout=a.timeout)
                out = r.stdout.decode('utf-8', 'replace')
                killed = [l[6:].rstrip('\r') for l in out.split('\n') if l.startswith('FAIL  ')]
                ran = out.count('\nPASS  ') + out.startswith('PASS  ') + len(killed)
                if killed: status = 'killed'
                elif r.returncode != 0: status, killed = 'killed', ['<runner crashed: exit %d>' % r.returncode]
                elif ran < len(sel) and len(cmd) > 3:
                    status, killed = 'error', ['<only %d of %d tests ran>' % (ran, len(sel))]
                else:
                    status = 'survived' if len(sel) == len(names) else 'partial'
            except subprocess.TimeoutExpired:
                status, killed = 'killed', ['<timeout>']
            finally:
                open(path, 'wb').write(raw)
        with lock:
            w.writerow([i, '%s:%d' % (c['file'], c['line']), c['kind'], len(names), status, ' | '.join(killed[:3]), round(time.time() - t0, 1), ran]); outf.flush()

ts = [threading.Thread(target=worker, args=(k,)) for k in range(1, a.workers + 1)]
[t.start() for t in ts]; [t.join() for t in ts]
print('left in queue:', len(queue))
