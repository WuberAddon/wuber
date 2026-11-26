#!/usr/bin/env python3
"""Test audit (job G): read the mutant CSV(s) and say which tests catch what.
Usage: python tools/audit/analyze.py --hits hits.tsv --basefail basefail.txt --defs defs.tsv mutants.csv [more.csv] > analysis.json-ish text
Prints: status counts, per-file counts, unique kills per test, tests exposed to mutants that never killed one,
groups of tests that always fail together, and the surviving mutants (covered but not caught; never run)."""
import sys, csv, json, collections, argparse
ap = argparse.ArgumentParser()
ap.add_argument('--hits'); ap.add_argument('--basefail'); ap.add_argument('--defs'); ap.add_argument('--json')
ap.add_argument('csv', nargs='+')
a = ap.parse_args()
csv.field_size_limit(10**9)
rows = []
for p in a.csv:
    for r in csv.reader(open(p, encoding='utf-8')):
        if len(r) >= 7 and r[0].isdigit(): rows.append(r)
basefail = set(l.rstrip('\n') for l in open(a.basefail, encoding='utf-8'))
hit = collections.defaultdict(list)
for l in open(a.hits, encoding='utf-8'):
    n, _, ids = l.rstrip('\n').partition('\t')
    if n in basefail: continue
    for i in ids.split(','):
        if i: hit[int(i)].append(n)
defs = {}
for l in open(a.defs, encoding='utf-8'):
    n, _, s = l.rstrip('\n').partition('\t'); defs[n] = s.rsplit(':', 1)[0]
st = collections.Counter(r[4] for r in rows)
print('mutants:', len(rows), dict(st))
byfile = collections.defaultdict(collections.Counter)
for r in rows: byfile[r[1].rsplit(':', 1)[0]][r[4]] += 1
print('files with a mutant:', len(byfile))
kills = collections.Counter(); unique = collections.Counter(); exposed = collections.Counter()
sig = collections.defaultdict(set)
for r in rows:
    mid = int(r[0]); killers = [k for k in r[5].split(' | ') if k] if r[4] == 'killed' else []
    for n in hit.get(mid, []): exposed[n] += 1
    for k in killers:
        kills[k] += 1; sig[k].add(mid)
    if len(killers) == 1: unique[killers[0]] += 1
print('\n== tests that are the ONLY kill of a mutant (unique kills) ==', len(unique))
for n, c in unique.most_common(): print('%3d  %s  [%s]' % (c, n[:110], defs.get(n, '?')))
never = [n for n in exposed if kills[n] == 0]
print('\n== exposed to at least one mutant, killed none: %d of %d exposed tests ==' % (len(never), len(exposed)))
for n in sorted(never, key=lambda n: -exposed[n])[:60]: print('%3d  %s  [%s]' % (exposed[n], n[:110], defs.get(n, '?')))
g = collections.defaultdict(list)
for n, ids in sig.items():
    if len(ids) >= 2: g[frozenset(ids)].append(n)
print('\n== tests that killed the same set of 2+ mutants (always fail together in this sample) ==')
for ids, ns in sorted(g.items(), key=lambda x: -len(x[1])):
    if len(ns) > 1:
        print('-- %d tests, %d mutants' % (len(ns), len(ids)))
        for n in ns: print('     %s  [%s]' % (n[:110], defs.get(n, '?')))
print('\n== survivors: covered by tests, nobody noticed (by number of tests that ran the line) ==')
for r in sorted([r for r in rows if r[4] == 'survived'], key=lambda r: -int(r[3])): print('%4s tests  %-48s %s' % (r[3], r[1], r[2]))
print('\n== survivors: the line ran in no test at all ==')
for r in [r for r in rows if r[4] == 'uncovered']: print('     %-48s %s' % (r[1], r[2]))
if a.json:
    json.dump({'rows': rows, 'kills': kills, 'unique': unique, 'exposed': exposed}, open(a.json, 'w'))
