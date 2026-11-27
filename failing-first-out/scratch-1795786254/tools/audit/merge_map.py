#!/usr/bin/env python3
"""Test audit (job G): old test name -> merged test name, read from the tests/**/merged_*_test.lua files merge_tests.py wrote.
Usage: python tools/audit/merge_map.py <repo> > map.tsv   (old name TAB merged name TAB merged file)"""
import sys, os, re, json
repo = sys.argv[1]
for root, _, fs in os.walk(os.path.join(repo, 'tests')):
    for f in sorted(fs):
        if not (f.startswith('merged_') and f.endswith('_test.lua')): continue
        title = None
        for l in open(os.path.join(root, f), encoding='utf-8'):
            m = re.match(r'^test\((".*"), function\(\)$', l.rstrip('\n'))
            if m: title = json.loads(m.group(1)); continue
            m = re.match(r'^\t\t\{ (".*?")(?:, .*)? \},$', l.rstrip('\n'))
            if m and title:
                try: print(json.loads(m.group(1)) + '\t' + title + '\t' + os.path.relpath(os.path.join(root, f), repo).replace(chr(92), '/'))
                except Exception: print('#BAD ' + l.strip(), file=sys.stderr)
