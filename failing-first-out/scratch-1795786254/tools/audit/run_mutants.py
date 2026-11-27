#!/usr/bin/env python3
"""Test audit (job G): run a sample of single-line mutants, each only against the tests that ran the mutated line.
Usage: python tools/audit/run_mutants.py --work <dir with mut-1..mut-N clean copies> --cand cand-ok.json --hits hits.tsv
         --basefail basefail.txt --out mutants.csv [--sample sample.json | --n 220 --zero 30 --maxhit 150] [--hours 2] [--only-ids sample.json]
--hits: lines "<test name>\t<id,id,...>" (tools/audit/instrument.py's run). Tests that already fail on the
unmutated tree (--basefail, one name a line) are left out. Row: id, file:line, change, ntests, status, killed_by."""
import re, sys, os, json, csv, random, subprocess, threading, time, argparse

ap = argparse.ArgumentParser()
ap.add_argument('--work'); ap.add_argument('--cand'); ap.add_argument('--hits'); ap.add_argument('--basefail')
ap.add_argument('--out'); ap.add_argument('--sample'); ap.add_argument('--n', type=int, default=220)
ap.add_argument('--zero', type=int, default=30); ap.add_argument('--maxhit', type=int, default=150)
ap.add_argument('--hours', type=float, default=2.0); ap.add_argument('--workers', type=int, default=4)
ap.add_argument('--seed', type=int, default=11); ap.add_argument('--timeout', type=int, default=420)
ap.add_argument('--lua', default=os.environ.get('WUBER_LUA', 'lua5.1'))
ap.add_argument('--times', help='times.txt (seconds TAB name) of an unmutated run'); ap.add_argument('--defs', help='defs.tsv: test name TAB file:line')
ap.add_argument('--skip', help='a mutants csv whose ids are left out of the sample (an earlier batch)')
ap.add_argument('--rename', help='merge-map.tsv (old name, merged name, merged file): after a merge, run the merged test where an old one ran')
ap.add_argument('--only', help='csv of an earlier run: re-run only these mutant ids')
ap.add_argument('--maxcost', type=float, default=60.0, help='skip sites whose tests add up to more seconds than this')
a = ap.parse_args()

cands = {c['id']: c for c in json.load(open(a.cand))}
basefail = set(l.rstrip('\n') for l in open(a.basefail, encoding='utf-8')) if a.basefail else set()
hit = {}
for l in open(a.hits, encoding='utf-8'):
    l = l.rstrip('\n')
    if '\t' not in l: continue
    name, ids = l.split('\t', 1)
    if name in basefail: continue
    for i in ids.split(','):
        if i: hit.setdefault(int(i), []).append(name)

cost, part = {}, {}
if a.times:
    for l in open(a.times, encoding='utf-8'):
        t, _, n = l.rstrip('\n').partition('\t')
        try: cost[n] = cost.get(n, 0) + float(t)
        except ValueError: pass
if a.defs:
    for l in open(a.defs, encoding='utf-8'):
        n, _, src = l.rstrip('\n').partition('\t')
        p = src.rsplit(':', 1)[0].replace('\\', '/')
        if p == 'tests/run.lua': part[n] = 'run'
        elif p.startswith('tests/') and p.endswith('.lua'): part[n] = p[6:-4]
rename = {}
if a.rename:
    for l in open(a.rename, encoding='utf-8'):
        o, _, rest = l.rstrip('\n').partition('\t'); nn, _, fl = rest.partition('\t')
        rename[o] = nn; part[nn] = fl[6:-4]
    for i in list(hit): hit[i] = list(dict.fromkeys(rename.get(n, n) for n in hit[i]))
def sitecost(i): return sum(cost.get(n, 0.5) for n in hit.get(i, []))
if a.only:
    sample = [int(r[0]) for r in csv.reader(open(a.only, encoding='utf-8')) if r and r[0].isdigit()]
elif a.sample:
    sample = json.load(open(a.sample))
else:
    random.seed(a.seed)
    ids = list(cands)
    if a.skip:
        gone = set(int(r[0]) for r in csv.reader(open(a.skip, encoding='utf-8')) if r and r[0].isdigit())
        ids = [i for i in ids if i not in gone]
    zero = [i for i in ids if i not in hit]
    mid = [i for i in ids if i in hit and len(hit[i]) <= a.maxhit and sitecost(i) <= a.maxcost]
    random.shuffle(zero); random.shuffle(mid)
    pick, seen = [], set()
    for i in mid:   # one per file first, so every module is represented
        f = cands[i]['file']
        if f not in seen: seen.add(f); pick.append(i)
    for i in mid:
        if len(pick) >= a.n - a.zero: break
        if i not in pick: pick.append(i)
    pick = pick[:a.n - a.zero] + zero[:a.zero]
    random.shuffle(pick)
    sample = pick
    json.dump(sample, open(a.out + '.sample.json', 'w'))

deadline = time.time() + a.hours * 3600
lock = threading.Lock()
done = set()
if os.path.exists(a.out):
    for r in csv.reader(open(a.out, encoding='utf-8')):
        if r and r[0].isdigit(): done.add(int(r[0]))
queue = [i for i in sample if i not in done]
outf = open(a.out, 'a', newline='', encoding='utf-8')
w = csv.writer(outf)

def worker(k):
    d = os.path.join(a.work, 'mut-%d' % k)
    env = dict(os.environ, WUBER_LAB_DIR=os.path.join(d, 'lab', 'WuberLab'))
    while True:
        with lock:
            if not queue or time.time() > deadline: return
            i = queue.pop(0)
        c = cands[i]
        path = os.path.join(d, c['file'])
        raw = open(path, 'rb').read()
        names = hit.get(i, [])
        t0 = time.time()
        if not names:
            status, killed = 'uncovered', []
        else:
            L = raw.decode('utf-8').split('\n')
            L[c['line'] - 1] = c['new']
            open(path, 'wb').write('\n'.join(L).encode('utf-8'))
            nf = os.path.join(d, 'tests', 'out', 'names.txt')
            os.makedirs(os.path.dirname(nf), exist_ok=True)
            open(nf, 'w', encoding='utf-8').write('\n'.join(names) + '\n')
            try:
                parts = sorted(set(part.get(n, '') for n in names))
                cmd = [a.lua, 'tests/run.lua', '--names=tests/out/names.txt']
                if parts and '' not in parts: cmd.append('--files=' + ','.join(parts))
                r = subprocess.run(cmd, cwd=d, env=env, capture_output=True, timeout=a.timeout)
                out = r.stdout.decode('utf-8', 'replace')
                m = re.search(r'(\d+) passed, (\d+) failed', out)
                if len(cmd) > 3 and (not m or int(m.group(1)) + int(m.group(2)) < len(set(names))):  # a part was not loaded: the full load
                    r = subprocess.run(cmd[:3], cwd=d, env=env, capture_output=True, timeout=a.timeout)
                    out = r.stdout.decode('utf-8', 'replace')
                killed = [l[6:] for l in out.split('\n') if l.startswith('FAIL  ')]
                status = 'killed' if killed else 'survived'
                if r.returncode != 0 and not killed: status, killed = 'killed', ['<runner crashed: exit %d>' % r.returncode]
            except subprocess.TimeoutExpired:
                status, killed = 'killed', ['<timeout>']
            finally:
                open(path, 'wb').write(raw)
        with lock:
            w.writerow([i, '%s:%d' % (c['file'], c['line']), c['kind'], len(names), status, ' | '.join(k.rstrip('\r') for k in killed), round(time.time() - t0, 1)])
            outf.flush()

ts = [threading.Thread(target=worker, args=(k,)) for k in range(1, a.workers + 1)]
[t.start() for t in ts]; [t.join() for t in ts]
print('done; left in queue:', len(queue))
