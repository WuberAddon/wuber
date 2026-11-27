#!/usr/bin/env python3
"""Test audit (job G): find test bodies that are identical or nearly so.
A test is a top-level  test("name", function()  ...  end)  (or testOutside); its body is the text up to the
next top-level one. Usage: python tools/audit/dupes.py <repo> [threshold 0.9] > dupes.txt"""
import sys, os, re, hashlib, itertools, collections
repo = sys.argv[1]; thr = float(sys.argv[2]) if len(sys.argv) > 2 else 0.9
START = re.compile(r'^(?:test|testOutside)\(\s*(?:"((?:[^"\\]|\\.)*)"|\'((?:[^\'\\]|\\.)*)\')\s*,')
bodies = []
for root, _, fs in os.walk(os.path.join(repo, 'tests')):
    if os.sep + 'out' in root or os.sep + 'fixtures' in root: continue
    for f in fs:
        if not f.endswith('.lua'): continue
        p = os.path.join(root, f); rel = os.path.relpath(p, repo).replace('\\', '/')
        L = open(p, 'rb').read().decode('utf-8', 'replace').split('\n')
        starts = [(i, START.match(l)) for i, l in enumerate(L) if START.match(l)]
        for k, (i, m) in enumerate(starts):
            j = starts[k + 1][0] if k + 1 < len(starts) else len(L)
            name = m.group(1) or m.group(2)
            text = '\n'.join(L[i:j])
            body = text[m.end():]
            body = re.sub(r'--[^\n]*', '', body)
            body = re.sub(r'\s+', ' ', body).strip()
            bodies.append((rel, i + 1, name, body))
print('tests with a top-level body:', len(bodies))
by = collections.defaultdict(list)
for b in bodies: by[hashlib.md5(b[3].encode()).hexdigest()].append(b)
print('\n== identical bodies (after comments and spaces are gone) ==')
n = 0
for h, g in by.items():
    if len(g) > 1 and len(g[0][3]) > 80:
        n += 1
        print('-- %d tests, %d chars' % (len(g), len(g[0][3])))
        for r, l, nm, _ in g: print('   %s:%d  %s' % (r, l, nm[:110]))
print('groups:', n)
print('\n== near-identical (token shingles, Jaccard >= %.2f), bodies > 300 chars ==' % thr)
def sh(b):
    t = re.findall(r'\w+|[^\w\s]', b)
    return set(tuple(t[i:i + 5]) for i in range(max(1, len(t) - 4)))
sig = [(b, sh(b[3])) for b in bodies if len(b[3]) > 300]
# bucket by file to keep it cheap, then by first 20 shingle min-hashes across files
idx = collections.defaultdict(list)
for n_, (b, s) in enumerate(sig):
    for sh_ in sorted(s, key=lambda x: hash(x))[:6]: idx[sh_].append(n_)
seen = set(); out = []
for lst in idx.values():
    if len(lst) > 40: continue
    for a, b in itertools.combinations(lst, 2):
        if (a, b) in seen: continue
        seen.add((a, b))
        sa, sb = sig[a][1], sig[b][1]
        j = len(sa & sb) / max(1, len(sa | sb))
        if j >= thr and sig[a][0][3] != sig[b][0][3]: out.append((j, sig[a][0], sig[b][0]))
for j, a, b in sorted(out, key=lambda x: -x[0]):
    print('%.2f  %s:%d  %s\n      %s:%d  %s' % (j, a[0], a[1], a[2][:90], b[0], b[1], b[2][:90]))
print('pairs:', len(out))
