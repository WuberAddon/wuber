# tools/audit: test audit and mutation run

Scripts for finding lines that no test protects. They break one line at a time in a SCRATCH copy of the tree (never a worktree) and run only the tests that executed that line. Each script prints its usage with --help.

| Script | What it does |
|---|---|
| gen_candidates.py | Picks mutation sites in Wuber/ (one per line: flip a comparison, return nil, negate an if, nil a local, drop a statement, swap and/or) and writes cand.json. |
| instrument.py | Puts a hit marker in front of each site in a scratch tree and patches its tests/run.lua so each test records the sites it ran. It starts one Lua process per parse check. |
| instrument_fast.py | The same as instrument.py, but with one persistent Lua process for the parse checks. The whole addon (about 32,000 sites) takes 40 s instead of hours. |
| run_mutants.py | Runs a sample of mutants against every test that ran the line (the first audit). |
| run_mutants_fast.py | Runs the whole addon's mutants. The cheapest tests run first, and the run stops at the first failure (WUBER_BAIL; --patch-bail adds it to the scratch copies). It has a time budget per mutant ("partial" = no failure within the budget) and a --full pass. Mutants run riskiest first (Net, Drive and Core; trade, invite, summon, whisper and price lines), and the run can resume. |
| prove_mutant.py | Applies one mutant in a worktree, runs the named tests, puts the file back, and prints KILLED or SURVIVED. Use it to prove that a new guard test fails with its line broken. |
| analyze.py, dupes.py, merge_*.py | Reports and the table-driven merge of near-identical tests (TEST-AUDIT, PR #59). |

## A whole-addon run
1. Copy the tree into a scratch folder N + 1 times (mut-hit, mut-1 .. mut-N), e.g. `git archive origin/main | tar -x -C <dir>`.
2. `python tools/audit/gen_candidates.py <scratch>/mut-hit cand.json 999999`, then `python tools/audit/instrument_fast.py <scratch>/mut-hit cand.json cand-ok.json`.
3. Run mut-hit's suite once in shards (`lua5.1 tests/run.lua --shard K/N`). Join tests/out/hits.*.txt into hits.tsv and defs.*.txt into defs.tsv, and list that run's FAIL names in basefail.txt. If a test reads source text and trips over a marker, its log shows "__MH(id)": leave those ids out and instrument again.
4. `python tools/audit/run_mutants_fast.py --work <scratch> --patch-bail`, then the run itself (`--budget 6 --hours H`). Every "uncovered" or "survived" row is a line no test protects.
5. For each line you guard: write the test, then `python tools/audit/prove_mutant.py <worktree> cand-ok.json <id> "<test name>"` must print KILLED.

Never run a mutant in a worktree you work in, and never run the full suite per mutant.
