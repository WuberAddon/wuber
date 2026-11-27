#!/usr/bin/env python3
"""Test audit (job G): find tests of one file whose bodies are the same except for string literals and merge each
group into ONE table-driven test in a NEW file (every case keeps its own assertions; a failing case is named).
Usage: python tools/audit/merge_tests.py <repo> [--apply] [--min-chars 150] [--files tests/winners/x_test.lua,...]
Dry run lists the groups. --apply writes tests/<folder>/merged_<name>_test.lua and removes the originals.
Only files whose top level is the winners preamble ("local T = ...", "local test, eq, ok = ...") and tests;
other top-level code means a helper the new file would not have, so that file is skipped."""
import sys, os, re, collections

repo = sys.argv[1]
apply_ = '--apply' in sys.argv
minc = int(sys.argv[sys.argv.index('--min-chars') + 1]) if '--min-chars' in sys.argv else 150
only = sys.argv[sys.argv.index('--files') + 1].split(',') if '--files' in sys.argv else None
START = re.compile(r'^test\(\s*(?:"((?:[^"\\]|\\.)*)"|\'((?:[^\'\\]|\\.)*)\')\s*,\s*function\(\)\s*$')
def unq(s): return re.sub(r'\\(.)', lambda m: {'n': '\n'}.get(m.group(1), m.group(1)), s)
def lq(s): return '"' + s.replace('\\', '\\\\').replace('"', '\\"') + '"' 

def split_strings(body):
    """-> (skeleton text with each string literal as \0, [literal text, ...]); comments dropped; None if a long bracket is used"""
    if '[[' in body or '[=' in body: return None
    out, lits, i, n = [], [], 0, len(body)
    while i < n:
        c = body[i]
        if c in '"\'':
            j = i + 1
            while j < n and body[j] != c:
                j += 2 if body[j] == '\\' else 1
            lits.append(body[i:j + 1]); out.append('\0'); i = j + 1
        elif body.startswith('--', i):
            while i < n and body[i] != '\n': i += 1
        else:
            out.append(c); i += 1
    return re.sub(r'\s+', ' ', ''.join(out)).strip(), lits

def blocks(lines):
    res, i = [], 0
    while i < len(lines):
        m = START.match(lines[i])
        if m:
            j = i
            while j < len(lines) and lines[j].rstrip() != 'end)': j += 1
            k = i
            while k > 0 and lines[k - 1].startswith('-- gap'): k -= 1   # the "-- gap ..." comment above belongs to it
            res.append({'name': unq(m.group(1) if m.group(1) is not None else m.group(2)), 'start': k, 'first': i, 'end': j, 'body': '\n'.join(lines[i + 1:j])})
            i = j + 1
        else: i += 1
    return res

def clean_top(lines, bl):
    inside = set()
    for b in bl: inside.update(range(b['start'], b['end'] + 1))
    pre = []
    for i, l in enumerate(lines):
        if i in inside or not l.strip() or l.startswith('--'): continue
        if l.startswith('local T = ...') or l.startswith('local test, eq, ok'): pre.append(l); continue
        return None
    return pre

def common_prefix(names):
    ws = [n.split(' ') for n in names]
    k = 0
    while all(len(w) > k for w in ws) and len(set(w[k] for w in ws)) == 1: k += 1
    return ' '.join(ws[0][:k])

total_removed = total_added = 0
for root, _, fs in os.walk(os.path.join(repo, 'tests')):
    for f in sorted(fs):
        if not f.endswith('_test.lua') or f.startswith('merged_'): continue
        path = os.path.join(root, f); rel = os.path.relpath(path, repo).replace('\\', '/')
        if only and rel not in only: continue
        text = open(path, 'rb').read().decode('utf-8')
        lines = text.split('\n')
        bl = blocks(lines)
        if len(bl) < 2: continue
        pre = clean_top(lines, bl)
        if pre is None: continue
        groups = collections.defaultdict(list)
        for b in bl:
            s = split_strings(b['body'])
            if s and len(s[0]) >= minc:
                b['skel'], b['lits'] = s
                groups[s[0]].append(b)
        gl = [g for g in groups.values() if len(g) >= 2]
        if not gl: continue
        newname = 'merged_' + f
        out = ['-- Merged table-driven tests (test audit): each group below was %s near-identical tests of %s, the same body with different' % ('several', rel),
               '-- literals. One body, one table of cases; every case keeps its own assertions and a failing case is named in the message.'] + pre + ['']
        drop = set()
        for g in gl:
            nl = len(g[0]['lits'])
            varying = [k for k in range(nl) if len(set(b['lits'][k] for b in g)) > 1]
            pfx = common_prefix([b['name'] for b in g])
            title = (pfx.rstrip(' :') if len(pfx) > 45 else g[0]['name']) + ' (%d cases)' % len(g)
            # the skeleton body, varying literals read from the case table
            b0 = g[0]['body']
            toks, lits = [], []
            def sub(body):
                res, i, n, k = [], 0, len(body), 0
                while i < n:
                    c = body[i]
                    if c in '"\'':
                        j = i + 1
                        while j < n and body[j] != c: j += 2 if body[j] == '\\' else 1
                        if k in varying: res.append('C[%d]' % (varying.index(k) + 1))
                        else: res.append(body[i:j + 1])
                        k += 1; i = j + 1
                    else:
                        res.append(c); i += 1
                return ''.join(res)
            body = sub(b0)
            body = '\n'.join(('\t' + l if l.strip() else l) for l in body.split('\n'))
            out.append('-- from %s: %s' % (rel, '; '.join('line %d' % (b['first'] + 1) for b in g)))
            out.append('test(%s, function()' % lq(title))
            out.append('\tlocal failed = {}')
            out.append('\tlocal cases = {')
            for b in g:
                out.append('\t\t{ %s },' % ', '.join([lq(b['name'])] + [b['lits'][k] for k in varying]))
            out.append('\t}')
            out.append('\tfor _, case in ipairs(cases) do')
            out.append('\t\tlocal C = { select(2, unpack(case)) }')
            out.append('\t\tlocal good, err = pcall(function()')
            out.append(body)
            out.append('\t\tend)')
            out.append('\t\tif not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end')
            out.append('\tend')
            out.append('\tif #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\\n" .. table.concat(failed, "\\n"), 0) end')
            out.append('end)')
            out.append('')
            for b in g: drop.update(range(b['start'], b['end'] + 1))
            total_removed += len(g); total_added += 1
            print('%-48s %d tests -> 1  (%d varying literals)  %s' % (rel, len(g), len(varying), title[:70]))
        if apply_:
            keep = [l for i, l in enumerate(lines) if i not in drop]
            # collapse the blank lines the removal left
            res = []
            for l in keep:
                if not l.strip() and res and not res[-1].strip(): continue
                res.append(l)
            open(path, 'wb').write('\n'.join(res).encode('utf-8'))
            open(os.path.join(root, newname), 'wb').write('\n'.join(out).encode('utf-8'))
print('removed %d tests, added %d table-driven tests' % (total_removed, total_added))
