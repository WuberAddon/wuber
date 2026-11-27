#!/usr/bin/env python3
"""Test audit (job G): pick candidate mutation sites in Wuber/ and write candidates.json.
Usage: python tools/audit/gen_candidates.py <repo> <out.json> [count] [seed]
One mutation per site: flip a comparison, return nil, drop a statement, swap and/or.
Only single-line, bracket-balanced statements that start a statement are picked, so
the file can also be instrumented with a hit marker in front of the line (instrument.py)."""
import sys, os, re, json, random

repo, out = sys.argv[1], sys.argv[2]
count = int(sys.argv[3]) if len(sys.argv) > 3 else 3000
random.seed(int(sys.argv[4]) if len(sys.argv) > 4 else 7)

def mask(line):
    """string contents and trailing comment replaced by spaces (same length)"""
    res, i, q = [], 0, None
    while i < len(line):
        c = line[i]
        if q:
            if c == '\\' and i + 1 < len(line):
                res.append('  '); i += 2; continue
            if c == q: q = None; res.append(c)
            else: res.append(' ')
        else:
            if c in '"\'': q = c; res.append(c)
            elif line.startswith('--', i):
                res.append(' ' * (len(line) - i)); break
            else: res.append(c)
        i += 1
    return ''.join(res)

CMP = [(' == ', ' ~= '), (' ~= ', ' == '), (' <= ', ' > '), (' >= ', ' < '), (' < ', ' >= '), (' > ', ' <= ')]
BLOCK_START = re.compile(r'^(for|while|function|local\s+function|repeat|do|else|elseif|end|until)\b')

def balanced(m):
    return m.count('(') == m.count(')') and m.count('[') == m.count(']') and m.count('{') == m.count('}')

def mutations(raw, m):
    s = m.strip()
    if not s or '[[' in m or ']]' in m or '--[' in raw: return []
    if BLOCK_START.match(s) or s.startswith(')') or s.startswith('}'): return []
    if not balanced(m): return []
    res = []
    indent = raw[:len(raw) - len(raw.lstrip())]
    isif = s.startswith('if ')
    # the part of the line a comparison / and-or lives in: the whole masked line
    for a, b in CMP:
        k = m.find(a)
        if k >= 0 and not (a == ' > ' and m[k-1:k] == '-'):
            res.append(('cmp ' + a.strip() + '->' + b.strip(), raw[:k] + b + raw[k + len(a):]))
            break
    for a, b in ((' and ', ' or '), (' or ', ' and ')):
        k = m.find(a)
        if k >= 0:
            res.append(('swap ' + a.strip() + '->' + b.strip(), raw[:k] + b + raw[k + len(a):])); break
    if re.match(r'^return\s+\S', s) and not re.match(r'^return\s+nil\s*$', s) and not s.endswith(('and', 'or', ',', '+', '..', '(', '=')):
        res.append(('return -> nil', indent + 'return nil'))
        if re.match(r'^return\s+(true|false)\s*$', s):
            flip = 'false' if 'true' in s else 'true'
            res.append(('return ' + s.split()[1] + '->' + flip, indent + 'return ' + flip))
    elif isif and s.endswith(' then'):
        res.append(('if cond negated', indent + 'if not (' + s[3:-5] + ') then'))
    elif re.match(r'^local\s+[%w_,\s]+=', s.replace('%', '')) or re.match(r'^local\s+\w+\s*=\s*\S', s):
        if not s.endswith(('{', '(', ',', '=', 'function', 'and', 'or')) and 'function' not in s:
            mm = re.match(r'^(\s*local\s+\w+\s*=\s*)', raw)
            if mm: res.append(('local value -> nil', mm.group(1) + 'nil'))
    elif re.match(r'^[A-Za-z_][\w\.\:\[\]"\']*\s*(=[^=]|\()', s) and not s.endswith(('{', '(', ',', '=', 'function', 'and', 'or', 'then', 'do')):
        if 'function' not in s and not isif:
            res.append(('drop statement', indent + 'do end'))
    return res

def stmt_start(prev):
    """the previous code line ends a statement or opens a block: this line starts a statement"""
    p = prev.strip()
    return bool(re.search(r'(\bthen|\bdo|\belse|\bend|\brepeat|\)|\bnil|\btrue|\bfalse|[\w\]"\'])$', p)) and not p.endswith(('and', 'or', 'not', 'in', 'return')) and not re.search(r'[,\(\{=\+\-\*/\.\^<>~&|]$', p) and not p.endswith('..')

cands = []
for root, _, files in os.walk(os.path.join(repo, 'Wuber')):
    for f in files:
        if not f.endswith('.lua'): continue
        path = os.path.join(root, f)
        rel = os.path.relpath(path, repo).replace('\\', '/')
        lines = open(path, 'rb').read().decode('utf-8', 'replace').split('\n')
        prev = ''
        for i, raw in enumerate(lines):
            raw = raw.rstrip('\r')
            m = mask(raw)
            if m.strip() == '':
                continue
            if stmt_start(prev) or prev == '':
                for kind, new in mutations(raw, m):
                    cands.append({'file': rel, 'line': i + 1, 'kind': kind, 'old': raw, 'new': new})
            prev = m
# one random mutation per line, then a random sample of lines
byline = {}
for c in cands: byline.setdefault((c['file'], c['line']), []).append(c)
sites = [random.choice(v) for v in byline.values()]
random.shuffle(sites)
sites = sites[:count]
for n, c in enumerate(sites, 1): c['id'] = n
json.dump(sites, open(out, 'w'), indent=0)
print(len(byline), 'eligible lines;', len(sites), 'sites written to', out)
