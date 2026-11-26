# How to run the tests

Wuber has a fake copy of the game's API (`tests/harness.lua`), so the addon is tested without starting the game. Run all commands from the repository root or your worktree.

## What you need

- **Lua 5.1** (not LuaJIT; LuaJIT changes table order and random numbers, so tests differ). Put `lua5.1` on your `PATH`, or set `WUBER_LUA` to its full path.
- **Python 3** (for `scrub-check.py` and helper scripts).
- **Git Bash on Windows** for `tools/suite-par.sh` and `tools/quick-check.sh` (not WSL's `bash`, which cannot see Windows Lua).

## The five commands

1. **Static checks** (syntax, globals, locals/upvalues, forbidden calls, bytecode — run after every change):

       lua5.1 tools/check.lua

   Pass: prints `check: <N> files, <M> modules, 0 failures` and exits `0`.

2. **Filtered tests** (run only matching tests while working):

       lua5.1 tests/run.lua "<text>"

   Pass: prints `PASS` lines and `<N> passed, 0 failed, ...` and exits `0`.

3. **Full test suite** (run once before a pull request):

       WUBER_LUA=lua5.1 bash tools/suite-par.sh .

   This splits the suite across parallel shards (default: your core count, at most `16`; pass a number such as `4` after `.` to set it). To run serially on any machine, use `lua5.1 tests/run.lua`.

   Pass: prints `<N> passed, 0 failed, 0 pending, 0 skipped` and `suite-par: <K> shards, <s> s, exit 0`.

4. **Layout check** (checks screens for clipping and covered buttons):

       lua5.1 tools/layout-check.lua

   Pass: prints `0 problems` and `layout-check: result 0 (clean)`, and exits `0`. Use `--screen <id>` to check a single screen.

5. **Scrub check** (checks that no personal data is in the tree):

       python scrub-check.py . --patterns scrub-patterns.public.txt

   Pass: prints `0 hits` and exits `0`.

## Running one test by name

Pass any substring of the test name to `tests/run.lua`:

    lua5.1 tests/run.lua "map pins"

Only tests whose name contains that text run; the rest are listed as skipped.

While working, `bash tools/quick-check.sh` runs only the tests a change touches (it does not replace the full suite before a pull request).

## Where failures are written

- `tools/check.lua`, `tests/run.lua`, `tools/layout-check.lua` and `scrub-check.py` print failures directly to standard output.
- `tools/suite-par.sh` writes each shard's output to `tests/out/shard-K.log` and the joined summary (every failure, counts, transcript check and report) to `tests/out/join.log`.
- Run outputs and transcripts live under `tests/out/` (not committed). To summarize a long log in about 10 lines, run:

      python tools/log-digest.py tests/out/join.log
